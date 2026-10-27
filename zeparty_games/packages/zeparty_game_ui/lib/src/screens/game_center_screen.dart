import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/coin_badge.dart';
import '../widgets/game_card.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';
import 'achievements_screen.dart';
import 'game_details_screen.dart';
import 'history_screen.dart';
import 'leaderboard_screen.dart';
import 'room_screen.dart';
import 'settings_sheet.dart';
import 'store_screen.dart';
import 'wallet_screen.dart';

/// ZeParty Gaming Lobby: featured game hero, all games grid, quick links.
class GameCenterScreen extends StatefulWidget {
  const GameCenterScreen({super.key, this.initialGameId});
  final String? initialGameId;

  @override
  State<GameCenterScreen> createState() => _GameCenterScreenState();
}

class _GameCenterScreenState extends State<GameCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SessionScope.read(context);
      s.refreshCatalog();
      s.wallet.refreshBalance();
      s.invites.listen(_onInvite);
      s.socket.roomStream.listen((room) {
        // Matchmaking or an accepted invite can put us in a room from elsewhere.
        if (room != null && mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).push(RoomScreen.route(room.roomId));
        }
      });
    });
  }

  void _onInvite(Map<String, dynamic> m) {
    if (!mounted) return;
    final s = SessionScope.read(context);
    final game = s.entry(m['gameId'] as String)?.title ?? m['gameId'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      content: Text('${m['fromName']} invited you to $game'),
      action: SnackBarAction(
        label: 'JOIN',
        textColor: ZpColors.gold,
        onPressed: () => s.socket.joinRoom(m['roomId'] as String, inviteCode: m['inviteCode'] as String?),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final catalog = s.catalog;
    final featured = catalog.where((g) => g.featured && g.isAvailable).toList();
    final online = s.socket.status == SocketStatus.connected;
    return Scaffold(
      body: ZpBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            color: ZpColors.gold,
            backgroundColor: ZpColors.panel,
            onRefresh: () async {
              await s.refreshCatalog();
              await s.wallet.refreshBalance();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.md, ZpSpace.lg, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ZEPARTY', style: t.labelSmall?.copyWith(color: ZpColors.gold, letterSpacing: 4)),
                              Text('Game Center', style: t.headlineLarge),
                            ],
                          ),
                        ),
                        _StatusDot(online: online),
                        const SizedBox(width: ZpSpace.sm),
                        ListenableBuilder(listenable: s.wallet, builder: (_, _) => CoinBadge(coins: s.wallet.coins, onTap: () => Navigator.of(context).push(WalletScreen.route()))),
                        const SizedBox(width: ZpSpace.sm),
                        ZpIconButton(icon: Icons.tune_rounded, onPressed: () => SettingsSheet.show(context), tooltip: 'Settings'),
                      ],
                    ),
                  ),
                ),
                if (!s.catalogLoaded && online)
                  const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(ZpSpace.lg), child: ZpSkeleton(height: 240)))
                else if (featured.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: ZpSectionHeader('Featured')),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 260,
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 0.88),
                        itemCount: featured.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.sm),
                          child: GameCard(entry: featured[i], featured: true, online: online, onPlay: () => _open(context, featured[i])),
                        ).animate().fadeIn(delay: (80 * i).ms).slideX(begin: 0.1, end: 0),
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: ZpSectionHeader('All games', trailing: Text('${s.onlineUsers} online', style: t.labelSmall)),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisSpacing: ZpSpace.md, crossAxisSpacing: ZpSpace.sm, childAspectRatio: 0.74),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => GameCard(entry: catalog[i], online: online, onPlay: () => _open(context, catalog[i])).animate().fadeIn(delay: (40 * i).ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                      childCount: catalog.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: ZpSectionHeader('Your party')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg),
                    child: Wrap(
                      spacing: ZpSpace.md,
                      runSpacing: ZpSpace.md,
                      children: [
                        _QuickLink(icon: Icons.storefront_rounded, label: 'Store', onTap: () => Navigator.of(context).push(StoreScreen.route())),
                        _QuickLink(icon: Icons.emoji_events_rounded, label: 'Leaderboards', onTap: () => Navigator.of(context).push(LeaderboardScreen.route('ludo_royale'))),
                        _QuickLink(icon: Icons.military_tech_rounded, label: 'Achievements', onTap: () => Navigator.of(context).push(AchievementsScreen.route())),
                        _QuickLink(icon: Icons.history_rounded, label: 'History', onTap: () => Navigator.of(context).push(HistoryScreen.route())),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: ZpSpace.xxl)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, GameCatalogEntry e) {
    if (!e.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.title} is coming soon')));
      return;
    }
    Navigator.of(context).push(GameDetailsScreen.route(e.gameId));
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: online ? 'Connected' : 'Offline',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: online ? ZpColors.success : ZpColors.danger, boxShadow: [BoxShadow(color: (online ? ZpColors.success : ZpColors.danger).withValues(alpha: 0.6), blurRadius: 8)]),
        ),
      );
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ZpPanel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
        radius: ZpRadius.md,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: ZpColors.gold, size: 20),
          const SizedBox(width: ZpSpace.sm),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ]),
      );
}
