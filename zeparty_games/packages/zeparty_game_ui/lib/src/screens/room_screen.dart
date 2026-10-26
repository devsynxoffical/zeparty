import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/overlays.dart';
import '../widgets/zp_avatar.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';
import 'game_shell.dart';

/// Waiting room + player ready screen. Transitions into the game shell when
/// the server starts the match, and returns here after results for rematch.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId});
  final String roomId;
  static Route<void> route(String roomId) => MaterialPageRoute(builder: (_) => RoomScreen(roomId: roomId));

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  StreamSubscription<RoomState?>? _roomSub;
  StreamSubscription<Map<String, dynamic>>? _stateSub;
  StreamSubscription<ServerError>? _errSub;
  RoomState? _room;
  bool _inGame = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final s = SessionScope.read(context);
    _room = s.socket.currentRoom;
    _roomSub = s.socket.roomStream.listen((r) {
      if (!mounted) return;
      if (r == null) {
        Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == 'game_details');
        return;
      }
      setState(() => _room = r);
    });
    _stateSub = s.socket.gameStateStream.listen((m) {
      if (!mounted || _inGame) return;
      final room = _room;
      if (room == null || m['roomId'] != room.roomId) return;
      _enterGame(m);
    });
    _errSub = s.socket.errorStream.listen((e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    });
    // If a match is already running (rejoin), ask for the state.
    if (_room?.status == RoomStatus.playing) s.socket.resync();
  }

  String _friendly(ServerError e) => switch (e.code) {
        'players_not_ready' => 'Waiting for: ${e.message.split(': ').last}',
        'not_enough_players' => 'Need more players to start',
        'not_host' => 'Only the host can do that',
        _ => e.message,
      };

  Future<void> _enterGame(Map<String, dynamic> stateMsg) async {
    final s = SessionScope.read(context);
    final room = _room!;
    _inGame = true;
    setState(() => _starting = false);
    final mySeat = stateMsg['yourSeat'] as int?;
    final ctx = GameSessionContext(
      session: s.session,
      room: room,
      mySeat: mySeat,
      matchId: stateMsg['matchId'] as String,
      initialState: stateMsg['state'] as Map<String, dynamic>,
      initialVersion: stateMsg['version'] as int,
      initialSeq: stateMsg['seq'] as int,
      deadline: stateMsg['deadline'] as int?,
    );
    await Navigator.of(context).push(GameShell.route(ctx));
    _inGame = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _stateSub?.cancel();
    _errSub?.cancel();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave room?'),
        content: const Text('You can rejoin with the room id while it is open.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && mounted) SessionScope.read(context).socket.leaveRoom().ignore();
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final room = _room;
    if (room == null) {
      return const Scaffold(body: ZpLoading(label: 'Joining room'));
    }
    final me = room.playerById(s.userId);
    final isHost = room.hostUserId == s.userId;
    final entry = s.entry(room.gameId);
    final everyoneReady = room.players.where((p) => p.userId != room.hostUserId).every((p) => p.ready);
    final enough = room.players.length >= room.minPlayers;
    final canStart = isHost && everyoneReady && enough;
    final votes = room.rematchVotes;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(entry?.title ?? room.gameId),
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () async {
            if (await _confirmLeave() && context.mounted) Navigator.of(context).pop();
          }),
        ),
        body: ZpBackdrop(
          image: entry == null ? null : LudoAssets.backgrounds['imperial_palace'],
          dim: 0.55,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: ZpSpace.md),
                    _RoomCodeCard(room: room),
                    const SizedBox(height: ZpSpace.lg),
                    PlayerDisconnectedBanner(players: room.players),
                    Expanded(
                      child: Center(
                        child: Wrap(
                          spacing: ZpSpace.xl,
                          runSpacing: ZpSpace.xl,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var i = 0; i < room.maxPlayers; i++)
                              _Seat(
                                player: room.playerBySeat(i),
                                seat: i,
                                isHost: room.playerBySeat(i)?.userId == room.hostUserId,
                                isMe: room.playerBySeat(i)?.userId == s.userId,
                                votedRematch: room.playerBySeat(i) != null && votes.contains(room.playerBySeat(i)!.userId),
                                canKick: isHost && room.playerBySeat(i) != null && room.playerBySeat(i)!.userId != s.userId,
                                onKick: () => s.socket.kick(room.playerBySeat(i)!.userId),
                                onInvite: () => _invite(context),
                              ).animate().fadeIn(delay: (60 * i).ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                          ],
                        ),
                      ),
                    ),
                    if (room.spectators.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: ZpSpace.sm),
                        child: Text('${room.spectators.length} watching', style: t.labelSmall),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(ZpSpace.lg),
                      child: ZpPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (votes.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: ZpSpace.md), child: Text('Rematch: ${votes.length}/${room.players.length} ready', style: t.titleSmall, textAlign: TextAlign.center)),
                            if (me == null)
                              Text('You are spectating', style: t.titleMedium, textAlign: TextAlign.center)
                            else if (isHost)
                              ZpButton(
                                label: enough ? (everyoneReady ? 'Start match' : 'Waiting for players') : 'Need ${room.minPlayers - room.players.length} more',
                                icon: Icons.play_arrow_rounded,
                                expand: true,
                                loading: _starting,
                                onPressed: canStart && !_starting
                                    ? () {
                                        setState(() => _starting = true);
                                        s.socket.startMatch().ignore();
                                      }
                                    : null,
                              )
                            else
                              ZpButton(
                                label: me.ready ? 'Ready' : 'Tap when ready',
                                icon: me.ready ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                kind: me.ready ? ZpButtonKind.primary : ZpButtonKind.secondary,
                                expand: true,
                                onPressed: () => s.socket.setReady(!me.ready),
                              ),
                            const SizedBox(height: ZpSpace.md),
                            Row(children: [
                              Expanded(child: ZpButton(label: 'Invite', kind: ZpButtonKind.ghost, icon: Icons.person_add_alt_1_rounded, expand: true, compact: true, onPressed: () => _invite(context))),
                              const SizedBox(width: ZpSpace.sm),
                              Expanded(child: ZpButton(label: 'Share code', kind: ZpButtonKind.ghost, icon: Icons.ios_share_rounded, expand: true, compact: true, onPressed: () {
                                Clipboard.setData(ClipboardData(text: 'Room ${room.roomId}${room.inviteCode != null ? ' code ${room.inviteCode}' : ''}'));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                              })),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (s.socket.status != SocketStatus.connected) ReconnectingOverlay(status: s.socket.status),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context) async {
    final s = SessionScope.read(context);
    final room = _room!;
    final friends = await s.host.pickFriendsToInvite();
    if (friends.isNotEmpty) {
      for (final f in friends) {
        await s.socket.invite(room.roomId, f.userId);
        await s.host.notify(toUserId: f.userId, title: 'Game invite', body: '${s.me.displayName} invited you to ${s.entry(room.gameId)?.title ?? room.gameId}', data: {'roomId': room.roomId, 'inviteCode': room.inviteCode ?? ''});
      }
      return;
    }
    if (!context.mounted) return;
    final ctrl = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invite by user id'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'User id'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Invite')),
        ],
      ),
    );
    if (id != null && id.isNotEmpty) await s.socket.invite(room.roomId, id);
  }
}

class _RoomCodeCard extends StatelessWidget {
  const _RoomCodeCard({required this.room});
  final RoomState room;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZpPanel(
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.xl, vertical: ZpSpace.md),
      radius: ZpRadius.pill,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(room.isPrivate ? Icons.lock_rounded : Icons.public_rounded, size: 16, color: ZpColors.gold),
        const SizedBox(width: ZpSpace.sm),
        Text('ROOM ', style: t.labelSmall),
        Text(room.roomId, style: t.titleMedium?.copyWith(color: ZpColors.goldLight, letterSpacing: 2)),
        if (room.inviteCode != null) ...[
          const SizedBox(width: ZpSpace.md),
          Text('CODE ', style: t.labelSmall),
          Text(room.inviteCode!, style: t.titleMedium?.copyWith(color: ZpColors.goldLight, letterSpacing: 2)),
        ],
      ]),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.player, required this.seat, required this.isHost, required this.isMe, required this.votedRematch, required this.canKick, required this.onKick, required this.onInvite});
  final RoomPlayer? player;
  final int seat;
  final bool isHost;
  final bool isMe;
  final bool votedRematch;
  final bool canKick;
  final VoidCallback onKick;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = player;
    final color = ZpColors.seat(seat);
    if (p == null) {
      return GestureDetector(
        onTap: onInvite,
        child: SizedBox(
          width: 110,
          child: Column(children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.4), width: 2, strokeAlign: BorderSide.strokeAlignInside), color: color.withValues(alpha: 0.08)),
              child: Icon(Icons.person_add_alt_1_rounded, color: color.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 6),
            Text('Open seat', style: t.labelMedium?.copyWith(color: ZpColors.textMuted)),
          ]),
        ),
      );
    }
    return SizedBox(
      width: 110,
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          ZpAvatar(player: p, size: 72, seatColor: color, highlight: isMe, showName: false),
          if (isHost)
            const Positioned(top: -8, left: 0, right: 0, child: Icon(Icons.workspace_premium_rounded, color: ZpColors.gold, size: 22)),
          if (canKick)
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: onKick,
                child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: ZpColors.panelRaised, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 14, color: ZpColors.textSecondary)),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Text(p.displayName, style: t.titleSmall?.copyWith(color: isMe ? ZpColors.goldLight : ZpColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          !p.connected
              ? 'Reconnecting'
              : votedRematch
                  ? 'Rematch'
                  : isHost
                      ? 'Host'
                      : p.ready
                          ? 'Ready'
                          : 'Not ready',
          style: t.labelSmall?.copyWith(color: !p.connected ? ZpColors.danger : (p.ready || isHost || votedRematch) ? ZpColors.success : ZpColors.textMuted),
        ),
      ]),
    );
  }
}

extension on Future<void> {
  void ignore() {}
}
