import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../widgets/overlays.dart';
import '../widgets/zp_states.dart';
import 'results_screen.dart';
import 'settings_sheet.dart';

/// Hosts a game module: loading screen with asset preload, the game widget,
/// reconnection and disconnect overlays, pause menu, and the results overlay.
class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.context});
  final GameSessionContext context;
  static Route<void> route(GameSessionContext ctx) => PageRouteBuilder(
        pageBuilder: (_, _, _) => GameShell(context: ctx),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child)),
        transitionDuration: const Duration(milliseconds: 500),
      );

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late final SocketGameChannel _channel;
  ZePartyGameModule? _module;
  bool _loaded = false;
  double _progress = 0;
  bool _paused = false;
  MatchResult? _result;
  RoomState? _room;
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    final s = SessionScope.read(context);
    _room = widget.context.room;
    _channel = SocketGameChannel(socket: s.socket, roomId: widget.context.room.roomId, matchId: widget.context.matchId);
    _module = GameModuleRegistry.instance.resolve(widget.context.room.gameId);
    _subs.add(_channel.results.listen((r) => setState(() => _result = r)));
    _subs.add(s.socket.roomStream.listen((r) {
      if (!mounted) return;
      if (r == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _room = r);
      // Rematch accepted by everyone: server starts a new match and sends game.state;
      // RoomScreen below us handles entering it, so pop this shell.
      if (_result != null && r.status == RoomStatus.playing && r.matchId != widget.context.matchId) Navigator.of(context).pop();
    }));
    _subs.add(s.host.hostCloseRequests.listen((_) => _leave()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _preload());
  }

  Future<void> _preload() async {
    final m = _module;
    if (m == null) {
      setState(() => _loaded = true);
      return;
    }
    await ZpAssets.precache(context, m.preloadAssets, onProgress: (d, t) {
      if (mounted) setState(() => _progress = d / t);
    });
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _leave() {
    SessionScope.read(context).socket.leaveRoom();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final m = _module;
    final room = _room ?? widget.context.room;
    final entry = s.entry(room.gameId);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _paused = !_paused);
      },
      child: Scaffold(
        backgroundColor: ZpColors.obsidian,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!_loaded)
              _LoadingScreen(title: entry?.title ?? room.gameId, artwork: entry?.artwork, progress: _progress)
            else if (m == null)
              ZpError(title: 'Game module missing', message: 'No Flutter module registered for ${room.gameId}. Call GameModuleRegistry.instance.register(...) at startup.', onRetry: _leave)
            else
              _GameHost(
                builder: (ctx) => m.buildGame(ctx, widget.context, _channel),
                onPause: () => setState(() => _paused = true),
                players: room.players,
              ),
            if (s.socket.status != SocketStatus.connected && _result == null) ReconnectingOverlay(status: s.socket.status, onLeave: _leave),
            if (_paused && _result == null)
              PauseOverlay(
                spectator: widget.context.isSpectator,
                onResume: () => setState(() => _paused = false),
                onSettings: () => SettingsSheet.show(context),
                onLeave: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Leave the match?'),
                      content: Text(widget.context.isSpectator ? 'You can rejoin as a spectator at any time.' : 'Leaving forfeits your seat. Other players continue.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                      ],
                    ),
                  );
                  if (ok == true) _leave();
                },
              ),
            if (_result != null)
              ResultsScreen(
                result: _result!,
                room: room,
                rematchVotes: room.rematchVotes,
                onRematch: () => s.socket.voteRematch(),
                onLeave: _leave,
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the game widget and provides the pause control via an inherited hook.
class _GameHost extends StatelessWidget {
  const _GameHost({required this.builder, required this.onPause, required this.players});
  final WidgetBuilder builder;
  final VoidCallback onPause;
  final List<RoomPlayer> players;
  @override
  Widget build(BuildContext context) => GameShellScope(
        onPause: onPause,
        players: players,
        child: Builder(builder: builder),
      );
}

/// Lets game modules open the shell's pause menu and read live room players.
class GameShellScope extends InheritedWidget {
  const GameShellScope({super.key, required this.onPause, required this.players, required super.child});
  final VoidCallback onPause;
  final List<RoomPlayer> players;
  static GameShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GameShellScope>();
  @override
  bool updateShouldNotify(GameShellScope old) => old.players != players;
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen({required this.title, required this.artwork, required this.progress});
  final String title;
  final String? artwork;
  final double progress;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Stack(fit: StackFit.expand, children: [
      if (artwork != null) Image(image: ZpAssets.image(artwork!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x990B0A0F), Color(0xFF0B0A0F)]))),
      SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(title, style: t.displayMedium?.copyWith(fontSize: 32), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Preparing the chamber', style: t.bodyMedium),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 6, color: ZpColors.gold, backgroundColor: ZpColors.gold.withValues(alpha: 0.15)),
            ),
          ),
          const SizedBox(height: 56),
        ]),
      ),
    ]);
  }
}
