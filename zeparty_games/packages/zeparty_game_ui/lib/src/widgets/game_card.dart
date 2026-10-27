import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import 'zp_panel.dart';

/// Game Center card: artwork, title, players, activity, theme accent and a
/// press-tilt interaction. Coming-soon games render dimmed with a ribbon.
class GameCard extends StatefulWidget {
  const GameCard({super.key, required this.entry, required this.onPlay, this.featured = false, this.online = false});
  final GameCatalogEntry entry;
  final VoidCallback onPlay;
  final bool featured;
  final bool online;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  Offset _tilt = Offset.zero;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final t = Theme.of(context).textTheme;
    final available = e.isAvailable;
    return GestureDetector(
      onTapDown: (d) => setState(() {
        _down = true;
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final local = d.localPosition;
          _tilt = Offset((local.dx / box.size.width - 0.5) * 2, (local.dy / box.size.height - 0.5) * 2);
        }
      }),
      onTapCancel: () => setState(() {
        _down = false;
        _tilt = Offset.zero;
      }),
      onTapUp: (_) {
        setState(() {
          _down = false;
          _tilt = Offset.zero;
        });
        HapticFeedback.lightImpact();
        widget.onPlay();
      },
      child: AnimatedContainer(
        duration: ZpDurations.fast,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015)
          ..rotateX(-_tilt.dy * 0.08)
          ..rotateY(_tilt.dx * 0.08)
          ..scaleByDouble(_down ? 0.97 : 1.0, _down ? 0.97 : 1.0, 1, 1),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZpRadius.lg),
            boxShadow: [
              BoxShadow(color: e.accent.withValues(alpha: available ? 0.25 : 0.05), blurRadius: 28, offset: const Offset(0, 12)),
              const BoxShadow(color: Color(0x80000000), blurRadius: 16, offset: Offset(0, 8)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ZpRadius.lg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [e.accent.withValues(alpha: 0.5), ZpColors.panel]))),
                Image(
                  image: ZpAssets.image(e.artwork),
                  fit: BoxFit.cover,
                  color: available ? null : Colors.black.withValues(alpha: 0.55),
                  colorBlendMode: available ? null : BlendMode.darken,
                  errorBuilder: (_, _, _) => _ArtPlaceholder(accent: e.accent, kind: e.kind),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.center, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE60B0A0F)])),
                ),
                Positioned(
                  left: widget.featured ? ZpSpace.md : ZpSpace.sm,
                  right: widget.featured ? ZpSpace.md : ZpSpace.sm,
                  bottom: widget.featured ? ZpSpace.md : ZpSpace.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.title, style: (widget.featured ? t.headlineSmall : t.titleMedium)?.copyWith(color: ZpColors.ivory, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 8, color: Colors.black)]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(e.tagline, style: t.bodySmall?.copyWith(color: ZpColors.champagne.withValues(alpha: 0.8), fontSize: widget.featured ? 12 : 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: ZpSpace.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: ZpChip(
                                e.minPlayers == e.maxPlayers ? '${e.maxPlayers} players' : '${e.minPlayers}-${e.maxPlayers} players',
                                icon: Icons.people_alt_rounded,
                              ),
                            ),
                          ),
                          if (widget.featured && widget.online && available) ...[
                            const SizedBox(width: ZpSpace.sm),
                            ZpChip(e.onlineRooms > 0 ? '${e.onlineRooms} open' : 'Online', icon: Icons.circle, color: ZpColors.success),
                          ],
                          const SizedBox(width: 4),
                          if (available)
                            Container(
                              width: widget.featured ? 40 : 34,
                              height: widget.featured ? 40 : 34,
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ZpColors.goldGradient),
                              child: Icon(Icons.play_arrow_rounded, color: ZpColors.obsidian, size: widget.featured ? 24 : 20),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!available)
                  Positioned(
                    top: 14,
                    right: -28,
                    child: Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: ZpColors.gold,
                        alignment: Alignment.center,
                        child: Text('SOON', style: t.labelSmall?.copyWith(color: ZpColors.obsidian, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                if (widget.featured)
                  const Positioned(
                    top: ZpSpace.md,
                    left: ZpSpace.md,
                    child: ZpChip('Featured', icon: Icons.star_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Procedural placeholder for games whose key art is not generated yet. Draws
/// a themed emblem so the card still reads as a designed object.
class _ArtPlaceholder extends StatelessWidget {
  const _ArtPlaceholder({required this.accent, required this.kind});
  final Color accent;
  final GameKind kind;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _EmblemPainter(accent, kind));
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter(this.accent, this.kind);
  final Color accent;
  final GameKind kind;
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = RadialGradient(center: const Alignment(0, -0.3), radius: 1.1, colors: [accent.withValues(alpha: 0.55), ZpColors.obsidian]).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = size.shortestSide * 0.26;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ZpColors.gold.withValues(alpha: 0.7);
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r * 0.7, ring..strokeWidth = 1.5);
    final fill = Paint()..color = accent.withValues(alpha: 0.9);
    switch (kind) {
      case GameKind.turnBased:
        for (var i = 0; i < 4; i++) {
          final a = i * 1.5708;
          canvas.drawCircle(c + Offset.fromDirection(a, r * 0.42), r * 0.14, fill);
        }
      case GameKind.physicsShot:
        canvas.drawCircle(c, r * 0.3, fill);
        canvas.drawLine(c + Offset(-r * 0.9, r * 0.9), c + Offset(-r * 0.25, r * 0.25), ring..strokeWidth = 4);
      case GameKind.physicsRealtime:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: r * 1.1, height: r * 0.5), const Radius.circular(6)), fill);
    }
  }

  @override
  bool shouldRepaint(covariant _EmblemPainter old) => old.accent != accent || old.kind != kind;
}
