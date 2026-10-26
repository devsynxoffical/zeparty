import 'dart:math' as math;

import 'package:flame/components.dart';

/// Shared geometry for the arena. The Flame world is [worldW] x [worldH] units and
/// the Flutter HUD overlays avatars using the same normalised anchors, so both
/// layers agree on where each seat sits around the table.
class ArenaLayout {
  ArenaLayout._();

  static const double worldW = 1000;
  static const double worldH = 1500;

  static final Vector2 tableCenter = Vector2(500, 600);
  static const double tableRx = 400;
  static const double tableRy = 230;

  static const double cardW = 150;
  static const double cardH = cardW / 0.68;

  static final Vector2 drawPilePos = Vector2(405, 600);
  static final Vector2 discardPos = Vector2(595, 600);

  /// Centre of my hand arc (below the visible area so the fan curves upward).
  static final Vector2 handArcCenter = Vector2(500, 2150);
  static const double handArcRadius = 820;
  static const double handBaseY = 1330;

  /// Opponents are placed clockwise around the upper half of the table, in seat
  /// order starting from the seat after mine. `index` is 0-based among opponents.
  static Vector2 opponentAnchor(int index, int count) {
    if (count <= 0) return tableCenter.clone();
    // Angles run from the left side (just below horizontal) over the top to the right.
    const start = math.pi * 1.12;
    const end = math.pi * 1.88;
    final t = count == 1 ? 0.5 : index / (count - 1);
    final a = start + (end - start) * t;
    return Vector2(tableCenter.x + math.cos(a) * (tableRx + 40), tableCenter.y + math.sin(a) * (tableRy + 150));
  }

  /// Avatar position for an opponent, pushed outward from the fan.
  static Vector2 opponentAvatar(int index, int count) {
    final fan = opponentAnchor(index, count);
    final dir = (fan - tableCenter)..normalize();
    return fan + dir * 120;
  }

  /// Normalised (0..1) anchor for the Flutter overlay.
  static Vector2 normalised(Vector2 world) => Vector2(world.x / worldW, world.y / worldH);
}
