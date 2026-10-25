import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../model/card.dart';
import 'card_component.dart';
import 'card_painter.dart';
import 'layout.dart';

/// My hand: a fanned arc along the bottom. Playable cards are raised and glow,
/// unplayable ones are dimmed and lowered, the selected card lifts further. When
/// the fan is wider than the arena it scrolls horizontally by dragging.
class HandComponent extends PositionComponent with DragCallbacks {
  HandComponent({required this.art, required this.onCardTap}) : super(position: Vector2.zero(), size: Vector2(ArenaLayout.worldW, ArenaLayout.worldH), priority: 40);

  final CardArt art;
  final void Function(CcCard card) onCardTap;

  final List<CardComponent> cards = [];
  String? selectedId;
  double _scroll = 0;
  double _maxScroll = 0;
  bool interactive = false;

  static const double _spacingMax = 96;
  static const double _spacingMin = 46;

  @override
  bool containsLocalPoint(Vector2 point) => point.y > ArenaLayout.handBaseY - ArenaLayout.cardH;

  CardComponent? byId(String id) => cards.where((c) => c.card?.id == id).firstOrNull;

  double _spacing(int n) => n <= 1 ? _spacingMax : (ArenaLayout.worldW * 0.86 / (n - 1)).clamp(_spacingMin, _spacingMax);

  /// Target transform of slot [i] for a hand of [n] cards.
  ({Vector2 pos, double angle}) slot(int i, int n, {bool raised = false, bool selected = false}) {
    final spacing = _spacing(n);
    final x = (i - (n - 1) / 2) * spacing - _scroll;
    // Project onto the arc: angle from the arc centre.
    final theta = x / ArenaLayout.handArcRadius;
    final cx = ArenaLayout.handArcCenter.x + math.sin(theta) * ArenaLayout.handArcRadius;
    final cy = ArenaLayout.handArcCenter.y - math.cos(theta) * ArenaLayout.handArcRadius;
    final baseShift = ArenaLayout.handBaseY - (ArenaLayout.handArcCenter.y - ArenaLayout.handArcRadius);
    var lift = raised ? -34.0 : 0.0;
    if (selected) lift -= 70;
    final dir = Vector2(math.sin(theta), -math.cos(theta));
    final pos = Vector2(cx, cy + baseShift) + dir * -lift;
    return (pos: pos, angle: theta);
  }

  /// Reconcile the displayed cards with the authoritative hand, keeping existing
  /// components for cards that are still there. Returns true if anything changed.
  bool setHand(List<CcCard> hand, {required Set<String> playable, String? drawnCardId, bool animate = true}) {
    var changed = false;
    final byIdNow = {for (final c in cards) c.card!.id: c};
    final next = <CardComponent>[];
    for (final card in hand) {
      var comp = byIdNow.remove(card.id);
      if (comp == null) {
        comp = CardComponent(card: card, faceUp: true, art: art, onTap: _onTap, position: ArenaLayout.drawPilePos.clone());
        add(comp);
        changed = true;
      }
      next.add(comp);
    }
    for (final gone in byIdNow.values) {
      gone.removeFromParent();
      changed = true;
    }
    cards
      ..clear()
      ..addAll(next);
    if (selectedId != null && byId(selectedId!) == null) selectedId = null;
    for (final c in cards) {
      c.playable = playable.contains(c.card!.id) && interactive;
      c.glowStrength = c.playable ? 1 : 0;
      c.dim = interactive && !c.playable ? 0.55 : (interactive ? 0 : 0.15);
      c.selected = c.card!.id == selectedId;
      c.glowColor = c.card!.id == drawnCardId ? Colors.white : null;
    }
    _clampScroll();
    layout(animate: animate);
    return changed;
  }

  void _clampScroll() {
    final n = cards.length;
    final width = n <= 1 ? 0.0 : (n - 1) * _spacing(n);
    _maxScroll = math.max(0, (width - ArenaLayout.worldW * 0.86) / 2);
    _scroll = _scroll.clamp(-_maxScroll, _maxScroll);
  }

  /// Move every card to its slot (animated or instant) and fix draw order.
  void layout({bool animate = true}) {
    final n = cards.length;
    for (var i = 0; i < n; i++) {
      final c = cards[i];
      if (c.busy) continue;
      final s = slot(i, n, raised: c.playable, selected: c.selected);
      c.priority = 40 + i + (c.selected ? 50 : 0);
      if (!animate || c.isLoaded == false) {
        c.position.setFrom(s.pos);
        c.angle = s.angle;
      } else if ((c.position - s.pos).length > 0.5 || (c.angle - s.angle).abs() > 0.001) {
        c.flyTo(s.pos, angleTo: s.angle, duration: 0.22, arc: 0, curve: Curves.easeOut);
      }
    }
  }

  /// Detach a card from the fan (for the play animation). The caller owns it after.
  CardComponent? detach(String id) {
    final c = byId(id);
    if (c == null) return null;
    cards.remove(c);
    c.removeFromParent();
    if (selectedId == id) selectedId = null;
    _clampScroll();
    layout();
    return c;
  }

  /// Insert a card component that flew in from the pile; it is already positioned.
  void attach(CardComponent c, int index) {
    cards.insert(index.clamp(0, cards.length), c);
    c.busy = false;
    if (c.parent != this) {
      c.removeFromParent();
      add(c);
    }
    _clampScroll();
    layout();
  }

  void select(String? id) {
    selectedId = id;
    for (final c in cards) {
      c.selected = c.card!.id == id;
    }
    layout();
  }

  void _onTap(CardComponent c) {
    if (!interactive) return;
    onCardTap(c.card!);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_maxScroll <= 0) return;
    _scroll = (_scroll - event.localDelta.x).clamp(-_maxScroll, _maxScroll);
    layout(animate: false);
  }

  /// A card the drawing player just received: fly from the draw pile and reveal.
  Future<void> animateDraw(CcCard card, int index) async {
    final comp = CardComponent(card: card, faceUp: false, art: art, onTap: _onTap, position: ArenaLayout.drawPilePos.clone(), scale: 1);
    comp.priority = 200;
    comp.busy = true;
    add(comp);
    final n = cards.length + 1;
    final s = slot(index.clamp(0, n - 1), n);
    final fly = comp.flyTo(s.pos, angleTo: s.angle, duration: 0.5, arc: 160);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await comp.flipTo(true);
    await fly;
    attach(comp, index);
  }
}
