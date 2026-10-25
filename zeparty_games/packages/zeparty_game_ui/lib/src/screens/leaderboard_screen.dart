import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.gameId});
  final String gameId;
  static Route<void> route(String gameId) => MaterialPageRoute(builder: (_) => LeaderboardScreen(gameId: gameId));
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _weekly = false;
  late String _gameId = widget.gameId;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = SessionScope.read(context).api.leaderboard(_gameId, weekly: _weekly));

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final games = s.catalog.where((g) => g.isAvailable).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboards')),
      body: ZpBackdrop(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.sm, ZpSpace.lg, 0),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _gameId,
                  items: [for (final g in games) DropdownMenuItem(value: g.gameId, child: Text(g.title))],
                  onChanged: (v) {
                    if (v == null) return;
                    _gameId = v;
                    _load();
                  },
                  dropdownColor: ZpColors.panel,
                ),
              ),
              const SizedBox(width: ZpSpace.md),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('All time')), ButtonSegment(value: true, label: Text('Weekly'))],
                selected: {_weekly},
                onSelectionChanged: (v) {
                  _weekly = v.first;
                  _load();
                },
                style: SegmentedButton.styleFrom(selectedBackgroundColor: ZpColors.gold, selectedForegroundColor: ZpColors.obsidian, foregroundColor: ZpColors.textSecondary),
              ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const ZpLoading();
                if (snap.hasError) return ZpError(message: '${snap.error}', onRetry: _load);
                final entries = (snap.data!['entries'] as List<dynamic>).cast<Map<String, dynamic>>();
                final me = snap.data!['me'] as Map<String, dynamic>?;
                if (entries.isEmpty) return const ZpEmpty(icon: Icons.emoji_events_outlined, title: 'No ranked players yet', message: 'Finish a match to appear here.');
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(ZpSpace.lg),
                  children: [
                    if (me != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: ZpSpace.md),
                        child: ZpPanel(
                          glow: true,
                          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
                          child: Row(children: [
                            Text('#${me['rank']}', style: t.headlineSmall?.copyWith(color: ZpColors.goldLight)),
                            const SizedBox(width: ZpSpace.md),
                            Expanded(child: Text('You', style: t.titleMedium)),
                            Text('${me['wins']} W  ${me['matches']} P', style: t.labelMedium),
                            const SizedBox(width: ZpSpace.md),
                            Text('${me['score']}', style: t.titleMedium?.copyWith(color: ZpColors.goldLight)),
                          ]),
                        ),
                      ),
                    for (final (i, e) in entries.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: ZpSpace.sm),
                        child: ZpPanel(
                          blur: false,
                          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
                          radius: ZpRadius.md,
                          borderColor: e['userId'] == s.userId ? ZpColors.gold : null,
                          child: Row(children: [
                            SizedBox(
                              width: 40,
                              child: e['rank'] <= 3
                                  ? Icon(Icons.workspace_premium_rounded, color: [ZpColors.goldLight, const Color(0xFFC0C0C0), const Color(0xFFCD7F32)][(e['rank'] as int) - 1])
                                  : Text('#${e['rank']}', style: t.titleMedium?.copyWith(color: ZpColors.textSecondary)),
                            ),
                            Expanded(child: Text(e['userId'] as String, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${e['wins']} W', style: t.labelMedium),
                            const SizedBox(width: ZpSpace.md),
                            Text('${e['score']}', style: t.titleMedium?.copyWith(color: ZpColors.goldLight)),
                          ]),
                        ),
                      ).animate().fadeIn(delay: (30 * i).ms).slideX(begin: 0.05, end: 0),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
