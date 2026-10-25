import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  static Route<void> route() => MaterialPageRoute(builder: (_) => const HistoryScreen());
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future = SessionScope.read(context).api.matchHistory();

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Match history')),
      body: ZpBackdrop(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const ZpLoading();
            if (snap.hasError) return ZpError(message: '${snap.error}', onRetry: () => setState(() => _future = s.api.matchHistory()));
            final matches = snap.data!;
            if (matches.isEmpty) return const ZpEmpty(icon: Icons.history_rounded, title: 'No matches yet', message: 'Your finished matches appear here.');
            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(ZpSpace.lg),
              itemCount: matches.length,
              itemBuilder: (_, i) {
                final m = matches[i];
                final won = (m['winnerIds'] as List<dynamic>).contains(s.userId);
                final parts = (m['participants'] as List<dynamic>).cast<Map<String, dynamic>>();
                final mine = parts.where((p) => p['userId'] == s.userId).firstOrNull;
                final entry = s.entry(m['gameId'] as String);
                return Padding(
                  padding: const EdgeInsets.only(bottom: ZpSpace.sm),
                  child: ZpPanel(
                    blur: false,
                    radius: ZpRadius.md,
                    padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
                    borderColor: won ? ZpColors.gold.withValues(alpha: 0.6) : null,
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: (won ? ZpColors.gold : ZpColors.panelRaised).withValues(alpha: won ? 0.2 : 1)),
                        child: Icon(won ? Icons.emoji_events_rounded : Icons.sports_esports_rounded, color: won ? ZpColors.goldLight : ZpColors.textSecondary),
                      ),
                      const SizedBox(width: ZpSpace.md),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(entry?.title ?? m['gameId'] as String, style: t.titleMedium),
                          Text('${parts.length} players  ${_when(m['startedAt'] as String)}', style: t.labelSmall),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(won ? 'WIN' : (m['status'] == 'completed' ? _ordinal(mine?['placement'] as int?) : (m['status'] as String).toUpperCase()), style: t.titleSmall?.copyWith(color: won ? ZpColors.goldLight : ZpColors.textSecondary)),
                        Text('${mine?['score'] ?? 0} pts', style: t.labelSmall),
                      ]),
                    ]),
                  ),
                ).animate().fadeIn(delay: (30 * i).ms);
              },
            );
          },
        ),
      ),
    );
  }

  static String _ordinal(int? n) => switch (n) { null => 'ongoing', 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };
  static String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }
}
