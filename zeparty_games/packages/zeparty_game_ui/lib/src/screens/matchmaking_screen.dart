import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import 'room_screen.dart';

/// Matchmaking: pick a table size, queue, animated search, auto-enter room.
class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({super.key, required this.gameId});
  final String gameId;
  static Route<void> route(String gameId) => MaterialPageRoute(builder: (_) => MatchmakingScreen(gameId: gameId));

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  int? _tableSize;
  bool _searching = false;
  int _elapsed = 0;
  Timer? _timer;
  StreamSubscription<RoomState?>? _sub;

  @override
  void initState() {
    super.initState();
    final s = SessionScope.read(context);
    _sub = s.socket.roomStream.listen((room) {
      if (room != null && mounted && _searching) {
        _timer?.cancel();
        Navigator.of(context).pushReplacement(RoomScreen.route(room.roomId));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    if (_searching) SessionScope.read(context).socket.leaveMatchmaking();
    super.dispose();
  }

  Future<void> _start() async {
    final s = SessionScope.read(context);
    setState(() {
      _searching = true;
      _elapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));
    await s.socket.joinMatchmaking(widget.gameId, tableSize: _tableSize);
  }

  Future<void> _cancel() async {
    final s = SessionScope.read(context);
    _timer?.cancel();
    setState(() => _searching = false);
    await s.socket.leaveMatchmaking();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final e = s.entry(widget.gameId);
    final t = Theme.of(context).textTheme;
    final sizes = [for (var n = e?.minPlayers ?? 2; n <= (e?.maxPlayers ?? 4); n++) n];
    _tableSize ??= sizes.last;
    return Scaffold(
      appBar: AppBar(title: const Text('Quick match')),
      body: ZpBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ZpSpace.xl),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(alignment: Alignment.center, children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ZpColors.gold.withValues(alpha: 0.5), width: 1.5)),
                      ).animate(onPlay: (c) => _searching ? c.repeat() : c.stop()).scale(begin: const Offset(0.2, 0.2), end: const Offset(1, 1), duration: 2400.ms, delay: (800 * i).ms).fadeOut(duration: 2400.ms, delay: (800 * i).ms),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: ZpColors.goldGradient, boxShadow: [BoxShadow(color: ZpColors.gold.withValues(alpha: 0.5), blurRadius: 40)]),
                      child: Icon(_searching ? Icons.radar_rounded : Icons.bolt_rounded, color: ZpColors.obsidian, size: 52),
                    ),
                  ]),
                ),
                const SizedBox(height: ZpSpace.xl),
                Text(_searching ? 'Finding players' : (e?.title ?? widget.gameId), style: t.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: ZpSpace.sm),
                Text(
                  _searching ? 'Searching for ${_elapsed}s. A table of $_tableSize fills first; after 20 s we start with the minimum.' : 'We pair you with players looking for the same table size.',
                  style: t.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (!_searching) ...[
                  Text('TABLE SIZE', style: t.labelSmall?.copyWith(letterSpacing: 2)),
                  const SizedBox(height: ZpSpace.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final n in sizes)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: ChoiceChip(
                            label: Text('$n players'),
                            selected: _tableSize == n,
                            selectedColor: ZpColors.gold,
                            labelStyle: TextStyle(color: _tableSize == n ? ZpColors.obsidian : ZpColors.textPrimary, fontWeight: FontWeight.w600),
                            backgroundColor: ZpColors.panelRaised,
                            side: const BorderSide(color: ZpColors.divider),
                            onSelected: (_) => setState(() => _tableSize = n),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: ZpSpace.xl),
                  ZpButton(label: 'Find match', icon: Icons.search_rounded, expand: true, onPressed: _start),
                ] else
                  ZpButton(label: 'Cancel', kind: ZpButtonKind.ghost, expand: true, onPressed: _cancel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
