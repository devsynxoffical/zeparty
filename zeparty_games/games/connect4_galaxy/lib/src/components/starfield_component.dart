import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'galaxy_palette.dart';

/// Procedural deep-space layer behind the grid: static nebula clouds recorded
/// once into a Picture, twinkling stars and slow drifting dust motes. Honours
/// the graphics budget: on low quality or "reduce effects" the layer is static.
class StarfieldComponent extends PositionComponent {
  StarfieldComponent({required Vector2 size, int seed = 7}) : _rng = math.Random(seed), super(size: size, priority: -10);

  final math.Random _rng;
  ui.Picture? _nebula;
  final List<_Star> _stars = [];
  final List<_Mote> _motes = [];
  double _t = 0;

  bool get _animated => GraphicsSettings.instance.current.ambientAnimation && !GraphicsSettings.instance.reduceEffects;

  @override
  Future<void> onLoad() async {
    final q = GraphicsSettings.instance.current;
    final starCount = switch (q) { GraphicsQuality.low => 70, GraphicsQuality.medium => 130, GraphicsQuality.high => 190 };
    for (var i = 0; i < starCount; i++) {
      _stars.add(_Star(
        pos: Offset(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
        radius: 0.6 + _rng.nextDouble() * (i % 9 == 0 ? 2.6 : 1.3),
        phase: _rng.nextDouble() * math.pi * 2,
        speed: 0.6 + _rng.nextDouble() * 1.8,
        tint: i % 7 == 0 ? GalaxyPalette.starWarm : (i % 5 == 0 ? GalaxyPalette.starCool : Colors.white),
      ));
    }
    final moteCount = _animated ? 28 : 0;
    for (var i = 0; i < moteCount; i++) {
      _motes.add(_Mote(
        pos: Offset(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
        vel: Offset((_rng.nextDouble() - 0.5) * 8, -4 - _rng.nextDouble() * 10),
        radius: 1.5 + _rng.nextDouble() * 3,
        alpha: 0.15 + _rng.nextDouble() * 0.35,
        tint: i.isEven ? GalaxyPalette.blue : GalaxyPalette.gold,
      ));
    }
    _nebula = _recordNebula();
  }

  ui.Picture _recordNebula() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = size.x;
    final h = size.y;
    void cloud(Offset center, double r, Color color, double alpha) {
      c.drawCircle(
        center,
        r,
        Paint()
          ..shader = ui.Gradient.radial(center, r, [color.withValues(alpha: alpha), color.withValues(alpha: alpha * 0.35), color.withValues(alpha: 0)], [0, 0.45, 1])
          ..blendMode = BlendMode.screen,
      );
    }

    cloud(Offset(w * 0.18, h * 0.22), w * 0.55, GalaxyPalette.nebulaViolet, 0.42);
    cloud(Offset(w * 0.82, h * 0.72), w * 0.6, GalaxyPalette.nebulaBlue, 0.38);
    cloud(Offset(w * 0.62, h * 0.18), w * 0.32, GalaxyPalette.nebulaTeal, 0.22);
    cloud(Offset(w * 0.3, h * 0.85), w * 0.3, GalaxyPalette.nebulaRose, 0.18);
    // Faint band of the galaxy running diagonally.
    final band = Path()
      ..moveTo(-w * 0.1, h * 0.75)
      ..quadraticBezierTo(w * 0.5, h * 0.35, w * 1.1, h * 0.15)
      ..lineTo(w * 1.1, h * 0.32)
      ..quadraticBezierTo(w * 0.5, h * 0.55, -w * 0.1, h * 0.95)
      ..close();
    c.drawPath(band, Paint()..color = Colors.white.withValues(alpha: 0.035)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06));
    return rec.endRecording();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_animated) return;
    _t += dt;
    for (final m in _motes) {
      var p = m.pos + m.vel * dt;
      if (p.dy < -10) p = Offset(_rng.nextDouble() * size.x, size.y + 10);
      if (p.dx < -10) p = Offset(size.x + 10, p.dy);
      if (p.dx > size.x + 10) p = Offset(-10, p.dy);
      m.pos = p;
    }
  }

  @override
  void render(Canvas canvas) {
    final nebula = _nebula;
    if (nebula != null) canvas.drawPicture(nebula);
    final starPaint = Paint();
    for (final s in _stars) {
      final tw = _animated ? 0.55 + 0.45 * math.sin(_t * s.speed + s.phase) : 0.8;
      starPaint.color = s.tint.withValues(alpha: tw);
      canvas.drawCircle(s.pos, s.radius, starPaint);
      if (s.radius > 2.2) {
        // Cross flare for the few bright stars.
        starPaint.color = s.tint.withValues(alpha: tw * 0.35);
        final l = s.radius * 4;
        canvas.drawRect(Rect.fromCenter(center: s.pos, width: l, height: 0.8), starPaint);
        canvas.drawRect(Rect.fromCenter(center: s.pos, width: 0.8, height: l), starPaint);
      }
    }
    for (final m in _motes) {
      canvas.drawCircle(m.pos, m.radius, Paint()..color = m.tint.withValues(alpha: m.alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }
}

class _Star {
  _Star({required this.pos, required this.radius, required this.phase, required this.speed, required this.tint});
  final Offset pos;
  final double radius;
  final double phase;
  final double speed;
  final Color tint;
}

class _Mote {
  _Mote({required this.pos, required this.vel, required this.radius, required this.alpha, required this.tint});
  Offset pos;
  final Offset vel;
  final double radius;
  final double alpha;
  final Color tint;
}

/// Static starfield painter for the Flutter background when `galaxy.webp` is missing.
class StarfieldPainter extends CustomPainter {
  const StarfieldPainter({this.seed = 11});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [GalaxyPalette.spaceTop, GalaxyPalette.spaceMid, GalaxyPalette.spaceBottom], [0, 0.55, 1]),
    );
    void cloud(Offset c, double r, Color color, double a) {
      canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, [color.withValues(alpha: a), color.withValues(alpha: 0)])..blendMode = BlendMode.screen);
    }

    cloud(Offset(size.width * 0.15, size.height * 0.2), size.width * 0.7, GalaxyPalette.nebulaViolet, 0.4);
    cloud(Offset(size.width * 0.9, size.height * 0.65), size.width * 0.8, GalaxyPalette.nebulaBlue, 0.35);
    cloud(Offset(size.width * 0.55, size.height * 0.9), size.width * 0.5, GalaxyPalette.nebulaRose, 0.16);
    final p = Paint();
    for (var i = 0; i < 260; i++) {
      final o = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final r = 0.4 + rng.nextDouble() * (i % 13 == 0 ? 2.2 : 1.1);
      p.color = (i % 6 == 0 ? GalaxyPalette.starWarm : Colors.white).withValues(alpha: 0.35 + rng.nextDouble() * 0.6);
      canvas.drawCircle(o, r, p);
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter old) => old.seed != seed;
}
