import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_wallet/zeparty_game_wallet.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/coin_badge.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';
import 'wallet_screen.dart';

/// Cosmetic store grouped by category. Purchase goes through the server with
/// an idempotency key; equip is per game and category.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.gameId});
  final String? gameId;
  static Route<void> route({String? gameId}) => MaterialPageRoute(builder: (_) => StoreScreen(gameId: gameId));

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => SessionScope.read(context).wallet.refreshAll(gameId: widget.gameId ?? 'ludo_royale'));
  }

  Future<void> _buy(Cosmetic c) async {
    final w = SessionScope.read(context).wallet;
    setState(() => _busyId = c.cosmeticId);
    final r = await w.purchase(c);
    if (!mounted) return;
    setState(() => _busyId = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.ok ? 'Purchased ${c.name}' : r.message)));
    if (r.ok) await w.equip(c);
  }

  Future<void> _equip(Cosmetic c) async {
    final w = SessionScope.read(context).wallet;
    setState(() => _busyId = c.cosmeticId);
    try {
      await w.equip(c);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final w = s.wallet;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmetic store'),
        actions: [ListenableBuilder(listenable: w, builder: (_, _) => Padding(padding: const EdgeInsets.only(right: ZpSpace.md), child: CoinBadge(coins: w.coins, onTap: () => Navigator.of(context).push(WalletScreen.route()))))],
      ),
      body: ZpBackdrop(
        child: ListenableBuilder(
          listenable: w,
          builder: (context, _) {
            if (w.loading && w.cosmetics.isEmpty) return const ZpLoading(label: 'Opening the store');
            if (w.error != null && w.cosmetics.isEmpty) return ZpError(message: '${w.error}', onRetry: () => w.refreshAll(gameId: widget.gameId));
            final items = w.cosmetics.where((c) => c.enabled && (widget.gameId == null || c.gameId == widget.gameId || c.gameId == 'common')).toList();
            if (items.isEmpty) return const ZpEmpty(icon: Icons.storefront_outlined, title: 'Nothing here yet');
            final groups = <String, List<Cosmetic>>{};
            for (final c in items) {
              groups.putIfAbsent('${c.gameId}|${c.category}', () => []).add(c);
            }
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: ZpSpace.xxl),
              children: [
                for (final entry in groups.entries) ...[
                  ZpSectionHeader(_title(entry.key, s)),
                  SizedBox(
                    height: 236,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg),
                      itemCount: entry.value.length,
                      separatorBuilder: (_, _) => const SizedBox(width: ZpSpace.md),
                      itemBuilder: (_, i) {
                        final c = entry.value[i];
                        final owned = w.owns(c);
                        final equipped = w.equippedFor(c.gameId, c.category) == c.cosmeticId || (c.isFree && w.equippedFor(c.gameId, c.category) == null && i == 0);
                        return _CosmeticCard(
                          cosmetic: c,
                          owned: owned,
                          equipped: equipped,
                          busy: _busyId == c.cosmeticId,
                          canAfford: w.coins >= c.price,
                          onAction: equipped ? null : () => owned ? _equip(c) : _buy(c),
                        ).animate().fadeIn(delay: (50 * i).ms).slideX(begin: 0.08, end: 0);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: ZpSpace.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg),
                  child: Text('Coins are earned by playing, finishing achievements and daily rewards. They have no cash value and cannot be withdrawn or wagered.', style: t.bodySmall, textAlign: TextAlign.center),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _title(String key, SessionController s) {
    final parts = key.split('|');
    final game = parts[0] == 'common' ? 'Profile' : (s.entry(parts[0])?.title ?? parts[0]);
    final cat = switch (parts[1]) { 'board' => 'Board skins', 'dice' => 'Dice', 'token' => 'Token sets', 'frame' => 'Avatar frames', 'reaction' => 'Reactions', _ => parts[1] };
    return '$game: $cat';
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({required this.cosmetic, required this.owned, required this.equipped, required this.busy, required this.canAfford, required this.onAction});
  final Cosmetic cosmetic;
  final bool owned;
  final bool equipped;
  final bool busy;
  final bool canAfford;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: 170,
      child: ZpPanel(
        padding: EdgeInsets.zero,
        glow: equipped,
        borderColor: equipped ? ZpColors.gold : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(ZpRadius.lg)),
                child: Container(
                  color: ZpColors.charcoal,
                  padding: const EdgeInsets.all(ZpSpace.md),
                  child: cosmetic.previewAsset == null
                      ? const Icon(Icons.auto_awesome_rounded, color: ZpColors.gold, size: 40)
                      : Image(image: ZpAssets.image(_preview(cosmetic.previewAsset!)), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: ZpColors.textMuted)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(ZpSpace.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cosmetic.name, style: t.titleSmall?.copyWith(color: ZpColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (equipped)
                  const ZpChip('Equipped', icon: Icons.check_rounded, color: ZpColors.success)
                else
                  ZpButton(
                    label: owned ? 'Equip' : (cosmetic.isFree ? 'Free' : '${cosmetic.price}'),
                    icon: owned || cosmetic.isFree ? null : Icons.monetization_on_rounded,
                    compact: true,
                    expand: true,
                    loading: busy,
                    kind: owned ? ZpButtonKind.secondary : (canAfford ? ZpButtonKind.primary : ZpButtonKind.ghost),
                    onPressed: onAction,
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Seed data references .webp without tier suffix; ZpAssets adds the tier.
  static String _preview(String p) => p;
}
