import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'games_bootstrap.dart';

/// In-room game picker: the ten premium multiplayer games. Tapping a game
/// opens its lobby full screen on top of the live / party room, which keeps
/// running (voice stays connected, the floating room overlay takes over).
class GameCenterSheet extends StatelessWidget {
  const GameCenterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GameCenterSheet(),
    );
  }

  Future<void> _openGame(BuildContext context, GameCatalogEntry entry) async {
    HapticFeedback.selectionClick();
    // Resolve the root navigator before closing the sheet: this context is
    // unmounted once the sheet pops.
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context);
    await GamesBootstrap.openGame(rootContext, entry.gameId);
  }

  @override
  Widget build(BuildContext context) {
    final games = kBuiltInCatalog.where((g) => GamesBootstrap.gameIds.contains(g.gameId)).toList();
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Color(0xFF0B0A0F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sports_esports_rounded, color: Color(0xFFD4AF37), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Play Games in Room',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Multiplayer tables with friends. Voice stays on while you play.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: games.length,
                itemBuilder: (context, i) => _GameTile(entry: games[i], onTap: () => _openGame(context, games[i])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.entry, required this.onTap});
  final GameCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final players = entry.minPlayers == entry.maxPlayers ? '${entry.maxPlayers} players' : '${entry.minPlayers}-${entry.maxPlayers} players';
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [entry.accent.withValues(alpha: 0.55), const Color(0xFF15131C)],
                ),
              ),
            ),
            Image(
              image: ZpAssets.image(entry.artwork),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE60B0A0F)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 6, color: Colors.black)]),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, color: Colors.white70, size: 12),
                      const SizedBox(width: 4),
                      Text(players, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.accent.withValues(alpha: 0.9),
                  boxShadow: [BoxShadow(color: entry.accent.withValues(alpha: 0.5), blurRadius: 8)],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
