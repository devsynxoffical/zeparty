import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';
import 'leaderboard_screen.dart';
import 'matchmaking_screen.dart';
import 'room_screen.dart';
import 'store_screen.dart';

/// Game details: artwork hero, description, rules summary, create / join / quick match.
class GameDetailsScreen extends StatefulWidget {
  const GameDetailsScreen({super.key, required this.gameId});
  final String gameId;
  static Route<void> route(String gameId) => MaterialPageRoute(builder: (_) => GameDetailsScreen(gameId: gameId));

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  List<RoomSummary> _rooms = const [];
  bool _loadingRooms = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final s = SessionScope.read(context);
    try {
      final rooms = await s.api.rooms(gameId: widget.gameId);
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {}
    if (mounted) setState(() => _loadingRooms = false);
  }

  Future<void> _create({required bool private}) async {
    final s = SessionScope.read(context);
    setState(() => _busy = true);
    try {
      await s.socket.createRoom(widget.gameId, isPrivate: private);
      final room = await s.socket.roomStream.firstWhere((r) => r != null).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      Navigator.of(context).push(RoomScreen.route(room!.roomId));
    } on ServerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create room')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinByCode() async {
    final roomCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join room'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room ID'), textCapitalization: TextCapitalization.characters),
          const SizedBox(height: ZpSpace.md),
          TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Invite code (private rooms)'), textCapitalization: TextCapitalization.characters),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Join')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _join(roomCtrl.text.trim().toUpperCase(), codeCtrl.text.trim().toUpperCase());
  }

  Future<void> _join(String roomId, [String? code]) async {
    final s = SessionScope.read(context);
    setState(() => _busy = true);
    try {
      await s.socket.joinRoom(roomId, inviteCode: code == null || code.isEmpty ? null : code);
      if (!mounted) return;
      Navigator.of(context).push(RoomScreen.route(roomId));
    } on ServerError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e.code))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String code) => switch (code) {
        'room_not_found' => 'Room not found',
        'room_full' => 'Room is full',
        'invite_required' => 'This room needs an invite code',
        'match_in_progress' => 'Match already started',
        _ => code,
      };

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = s.entry(widget.gameId);
    final t = Theme.of(context).textTheme;
    if (e == null) return const Scaffold(body: ZpError(message: 'Unknown game'));
    final rules = e.rules;
    return Scaffold(
      body: ZpBackdrop(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: ZpColors.obsidian,
              leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  Image(image: ZpAssets.image(e.artwork), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: e.accent.withValues(alpha: 0.4))),
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x660B0A0F), Colors.transparent, Color(0xFF0B0A0F)]))),
                  Positioned(
                    left: ZpSpace.lg,
                    right: ZpSpace.lg,
                    bottom: ZpSpace.lg,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.theme.toUpperCase(), style: t.labelSmall?.copyWith(color: ZpColors.gold, letterSpacing: 3)),
                      Text(e.title, style: t.displayMedium?.copyWith(fontSize: 34)),
                    ]).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(ZpSpace.lg),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Wrap(spacing: ZpSpace.sm, runSpacing: ZpSpace.sm, children: [
                    ZpChip('${e.minPlayers}-${e.maxPlayers} players', icon: Icons.people_alt_rounded),
                    if (e.turnTimeoutSeconds != null) ZpChip('${e.turnTimeoutSeconds}s turns', icon: Icons.timer_rounded),
                    if ((e.rewards['winCoins'] ?? 0) > 0) ZpChip('+${e.rewards['winCoins']} win', icon: Icons.monetization_on_rounded, color: ZpColors.goldLight),
                    if ((e.rewards['participationCoins'] ?? 0) > 0) ZpChip('+${e.rewards['participationCoins']} play', icon: Icons.monetization_on_rounded, color: ZpColors.textSecondary),
                  ]),
                  const SizedBox(height: ZpSpace.lg),
                  Text(e.description, style: t.bodyLarge),
                  const SizedBox(height: ZpSpace.xl),
                  Row(children: [
                    Expanded(child: ZpButton(label: 'Quick match', icon: Icons.bolt_rounded, onPressed: _busy ? null : () => Navigator.of(context).push(MatchmakingScreen.route(e.gameId)), expand: true)),
                  ]),
                  const SizedBox(height: ZpSpace.md),
                  Row(children: [
                    Expanded(child: ZpButton(label: 'Create room', kind: ZpButtonKind.secondary, icon: Icons.add_rounded, onPressed: _busy ? null : () => _create(private: false), expand: true, loading: _busy)),
                    const SizedBox(width: ZpSpace.md),
                    Expanded(child: ZpButton(label: 'Private', kind: ZpButtonKind.secondary, icon: Icons.lock_rounded, onPressed: _busy ? null : () => _create(private: true), expand: true)),
                  ]),
                  const SizedBox(height: ZpSpace.md),
                  Row(children: [
                    Expanded(child: ZpButton(label: 'Join by code', kind: ZpButtonKind.ghost, icon: Icons.vpn_key_rounded, onPressed: _busy ? null : _joinByCode, expand: true)),
                    const SizedBox(width: ZpSpace.md),
                    Expanded(child: ZpButton(label: 'Cosmetics', kind: ZpButtonKind.ghost, icon: Icons.palette_rounded, onPressed: () => Navigator.of(context).push(StoreScreen.route(gameId: e.gameId)), expand: true)),
                  ]),
                  if (rules.isNotEmpty) ...[
                    const ZpSectionHeader('Rules'),
                    ZpPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final r in _describeRules(rules))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: ZpColors.gold)),
                                const SizedBox(width: ZpSpace.sm),
                                Expanded(child: Text(r, style: t.bodyMedium)),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                  ZpSectionHeader('Open rooms', trailing: TextButton(onPressed: () => Navigator.of(context).push(LeaderboardScreen.route(e.gameId)), child: const Text('Leaderboard'))),
                  if (_loadingRooms)
                    const ZpSkeleton(height: 64)
                  else if (_rooms.isEmpty)
                    const ZpEmpty(icon: Icons.meeting_room_outlined, title: 'No open rooms', message: 'Create one and invite friends, or start a quick match.')
                  else
                    for (final r in _rooms)
                      Padding(
                        padding: const EdgeInsets.only(bottom: ZpSpace.sm),
                        child: ZpPanel(
                          onTap: _busy ? null : () => _join(r.roomId),
                          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
                          radius: ZpRadius.md,
                          child: Row(children: [
                            const Icon(Icons.meeting_room_rounded, color: ZpColors.gold),
                            const SizedBox(width: ZpSpace.md),
                            Expanded(child: Text('Room ${r.roomId}', style: t.titleMedium)),
                            Text('${r.playerCount}/${r.maxPlayers}', style: t.labelMedium),
                            const SizedBox(width: ZpSpace.sm),
                            const Icon(Icons.chevron_right_rounded, color: ZpColors.textMuted),
                          ]),
                        ),
                      ),
                  const SizedBox(height: ZpSpace.xxl),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _describeRules(Map<String, dynamic> r) {
    final out = <String>[];
    if (r['unlockRoll'] != null) out.add('Roll a ${r['unlockRoll']} to bring a token out of the palace.');
    if (r['extraTurnOnSix'] == true) out.add('A six grants an extra roll.');
    if (r['threeSixesForfeit'] == true) out.add('Three sixes in a row forfeit the turn.');
    if (r['extraTurnOnCapture'] == true) out.add('Capturing a rival grants an extra roll.');
    if (r['safeSquares'] == 'stars_and_starts') out.add('Start squares and star squares are safe from capture.');
    if (r['exactHomeEntry'] == true) out.add('Tokens need an exact roll to reach home.');
    if (r['extraTurnOnHome'] == true) out.add('Bringing a token home grants an extra roll.');
    if (r['maxTokens'] != null) out.add('${r['maxTokens']} tokens per player, first to bring them all home wins.');
    return out;
  }
}
