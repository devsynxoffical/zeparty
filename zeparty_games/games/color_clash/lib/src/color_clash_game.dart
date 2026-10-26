import 'dart:async' as async;
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'color_clash_assets.dart';
import 'color_clash_audio.dart';
import 'components/arena_component.dart';
import 'components/card_component.dart';
import 'components/card_painter.dart';
import 'components/fx.dart';
import 'components/hand_component.dart';
import 'components/layout.dart';
import 'components/opponent_fan.dart';
import 'components/pile_component.dart';
import 'model/card.dart';
import 'model/color_clash_view.dart';

/// UI-facing notification the HUD renders as a toast.
class CcNotice {
  const CcNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// The Flame scene for Color Clash. World is 1000 x 1500 units (portrait).
///
/// Authority model: this class never decides an outcome. It submits actions through
/// [GameChannel], queues server updates and animates their events in order, then
/// snaps every visual to the authoritative view. [displayState] is the last fully
/// animated view; [latestState] is the newest known view (HUD timers).
class ColorClashGame extends FlameGame {
  ColorClashGame({required this.session, required this.channel});

  final GameSessionContext session;
  final GameChannel channel;

  late final ArenaComponent arena;
  late final DrawPileComponent drawPile;
  late final DiscardPileComponent discard;
  late final HandComponent hand;
  late final Fx fx;
  late CardArt art;
  final Map<int, OpponentFanComponent> fans = {};

  final ValueNotifier<CcView?> displayState = ValueNotifier(null);
  final ValueNotifier<CcView?> latestState = ValueNotifier(null);
  final ValueNotifier<CcNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  /// Wild card waiting for a colour choice (HUD shows the picker while non-null).
  final ValueNotifier<CcCard?> pendingWild = ValueNotifier(null);
  final ValueNotifier<String?> selectedCardId = ValueNotifier(null);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingTimeout;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    camera = CameraComponent.withFixedResolution(world: world, width: ArenaLayout.worldW, height: ArenaLayout.worldH);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final initial = CcView.fromJson(session.initialState);
    _version = session.initialVersion;
    final q = GraphicsSettings.instance.current;

    // Every image is optional: a missing file falls back to procedural drawing. The
    // bundle manifest is consulted first so a missing key never touches the asset
    // channel, and all loads are issued together (sequential awaits stall under the
    // widget test binding).
    var available = <String>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      available = manifest.listAssets().toSet();
    } catch (_) {
      available = {};
    }
    Future<ui.Image?> img(String logical) async {
      final key = ZpAssets.key(logical, quality: q);
      if (available.isNotEmpty && !available.contains(key)) return null;
      try {
        return await images.load(key);
      } catch (_) {
        return null;
      }
    }

    final faceKeys = ColorClashAssets.faces.entries.toList();
    final symbolKeys = ColorClashAssets.symbols.entries.toList();
    final loaded = await Future.wait<ui.Image?>([
      img(ColorClashAssets.particles),
      img(ColorClashAssets.cardBack),
      for (final e in faceKeys) img(e.value),
      for (final e in symbolKeys) img(e.value),
    ]);
    final particles = loaded[0];
    final back = loaded[1];
    final faces = <CcColor, ui.Image>{};
    for (var i = 0; i < faceKeys.length; i++) {
      final im = loaded[2 + i];
      if (im != null) faces[CcColor.parse(faceKeys[i].key)] = im;
    }
    final symbols = <CcKind, ui.Image>{};
    for (var i = 0; i < symbolKeys.length; i++) {
      final im = loaded[2 + faceKeys.length + i];
      if (im != null) symbols[CcKind.parse(symbolKeys[i].key)] = im;
    }
    art = CardArt(back: back, faces: faces, symbols: symbols);
    fx = Fx(sheet: particles == null ? null : SpriteSheet(image: particles, srcSize: Vector2(particles.width / 3, particles.height / 2)), unit: ArenaLayout.cardW);

    arena = ArenaComponent();
    world.add(arena);
    world.add(fx.ambientMotes(Vector2(ArenaLayout.worldW, ArenaLayout.worldH)));
    drawPile = DrawPileComponent(art: art, onTap: requestDraw);
    discard = DiscardPileComponent(art: art);
    world.add(drawPile);
    world.add(discard);
    hand = HandComponent(art: art, onCardTap: onCardTap);
    world.add(hand);

    final opp = opponentSeats(initial);
    for (var i = 0; i < opp.length; i++) {
      final f = OpponentFanComponent(seat: opp[i], art: art, position: ArenaLayout.opponentAnchor(i, opp.length));
      fans[opp[i]] = f;
      world.add(f);
    }

    _snap(initial);
    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(ColorClashAudio.instance.init());
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    _pendingTimeout?.cancel();
    super.onRemove();
  }

  /// Seats shown around the table (everyone but me), in turn order after my seat.
  List<int> opponentSeats(CcView v) {
    final order = v.seats.map((s) => s.seat).toList();
    if (mySeat == null) return order;
    final idx = order.indexOf(mySeat!);
    if (idx == -1) return order;
    return [...order.sublist(idx + 1), ...order.sublist(0, idx)];
  }

  /// World position of a seat's hand (mine is the bottom arc).
  Vector2 seatPos(int seat) => seat == mySeat ? Vector2(ArenaLayout.worldW / 2, ArenaLayout.handBaseY) : (fans[seat]?.position.clone() ?? ArenaLayout.tableCenter.clone());

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  bool get _canAct {
    final s = displayState.value;
    return s != null && !isSpectator && !busy.value && !awaitingServer.value && s.isMyTurn;
  }

  void onCardTap(CcCard card) {
    final s = displayState.value;
    if (s == null || !_canAct) return;
    if (!s.isPlayable(card.id)) {
      _notify(const CcNotice('That card does not match', icon: Icons.block_rounded, color: ZpColors.danger));
      hand.select(null);
      selectedCardId.value = null;
      return;
    }
    if (selectedCardId.value == card.id) {
      unawaited(requestPlay(card));
      return;
    }
    selectedCardId.value = card.id;
    hand.select(card.id);
    ColorClashAudio.instance.play('ui_tap');
  }

  /// Play [card]; wild cards without a colour open the picker first.
  Future<void> requestPlay(CcCard card, {CcColor? color}) async {
    final s = displayState.value;
    if (s == null || !_canAct || !s.isPlayable(card.id)) return;
    if (card.kind.isWild && color == null) {
      pendingWild.value = card;
      return;
    }
    pendingWild.value = null;
    await _submit({'type': 'play', 'cardId': card.id, if (color != null) 'color': color.name});
  }

  void chooseColor(CcColor color) {
    final card = pendingWild.value;
    if (card == null) return;
    unawaited(requestPlay(card, color: color));
  }

  void cancelWild() {
    pendingWild.value = null;
  }

  Future<void> requestDraw() async {
    final s = displayState.value;
    if (s == null || !_canAct || !s.canDraw) return;
    await _submit({'type': 'draw'});
  }

  Future<void> requestPass() async {
    final s = displayState.value;
    if (s == null || !_canAct || !s.canPass) return;
    await _submit({'type': 'pass'});
  }

  Future<void> requestDeclare() async {
    final s = displayState.value;
    if (s == null || isSpectator || awaitingServer.value || !s.canDeclare) return;
    await _submit({'type': 'declare'});
  }

  Future<void> requestCatch(int target) async {
    final s = displayState.value;
    if (s == null || isSpectator || awaitingServer.value || !s.catchTargets.contains(target)) return;
    await _submit({'type': 'catch', 'target': target});
  }

  Future<void> _submit(Map<String, dynamic> action) async {
    awaitingServer.value = true;
    _pendingTimeout?.cancel();
    _pendingTimeout = async.Timer(const Duration(seconds: 4), () {
      if (awaitingServer.value) {
        awaitingServer.value = false;
        channel.resync();
      }
    });
    try {
      await channel.submit(action, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      _notify(CcNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('illegal_card')) return 'That card does not match';
    if (s.contains('prism_surge_blocked')) return 'Prism Surge only without a matching colour';
    if (s.contains('color_required')) return 'Choose a colour';
    if (s.contains('version_mismatch')) return 'Syncing with the table';
    if (s.contains('wrong_phase')) return 'Not now';
    if (s.contains('no_catch')) return 'Too late to catch';
    if (s.contains('not_final_card')) return 'Declare with one card left';
    return 'Action rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = CcView.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    final s = CcView.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    awaitingServer.value = false;
    busy.value = false;
    pendingWild.value = null;
    _pendingTimeout?.cancel();
    _snap(s);
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    busy.value = true;
    try {
      while (_queue.isNotEmpty) {
        final u = _queue.removeFirst();
        await _animate(u);
      }
    } finally {
      busy.value = false;
      _draining = false;
    }
  }

  Future<void> _animate(GameUpdate u) async {
    final next = CcView.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      switch (e.type) {
        case 'card_played':
          await _animatePlay(e, prev);
        case 'card_drawn':
          await _animateDraw(e, next);
        case 'direction_flipped':
          final dir = e.payload['direction'] as int? ?? next.direction;
          arena.spinBurst(dir);
          ColorClashAudio.instance.play('action');
          _notify(CcNotice(e.payload['actsAsSkip'] == true ? 'Flip: turn skipped' : 'Direction flipped', icon: Icons.swap_horiz_rounded, color: ZpColors.info));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        case 'turn_skipped':
          final victim = e.seat;
          if (victim != null) world.add(fx.ringPulse(seatPos(victim), color: ZpColors.danger));
          _notify(CcNotice('${_name(prev, victim)} skipped', icon: Icons.block_rounded, color: ZpColors.danger));
        case 'surge':
          final victim = e.seat;
          final by = e.payload['by'] as int?;
          final count = e.payload['count'] as int? ?? 2;
          if (victim != null) {
            world.add(fx.surgePulse(by == null ? ArenaLayout.discardPos.clone() : seatPos(by), seatPos(victim), color: ZpColors.goldLight));
            world.add(fx.burst(seatPos(victim), color: ZpColors.goldLight, count: 16));
          }
          ColorClashAudio.instance.play('action');
          final pending = e.payload['pending'] == true;
          _notify(CcNotice(pending ? 'Surge +$count on ${_name(prev, victim)}: stack or draw' : '${_name(prev, victim)} draws $count', icon: Icons.bolt_rounded, color: ZpColors.goldLight));
          await Future<void>.delayed(const Duration(milliseconds: 220));
        case 'echo_active':
          final n = e.payload['number'];
          world.add(fx.echoWaves(ArenaLayout.discardPos.clone(), color: CcColor.wild.color));
          ColorClashAudio.instance.play('action');
          _notify(CcNotice('Echo: play a $n or draw', icon: Icons.graphic_eq_rounded, color: CcColor.wild.color));
          await Future<void>.delayed(const Duration(milliseconds: 250));
        case 'declared':
          ColorClashAudio.instance.play('last_card');
          world.add(fx.ringPulse(seatPos(e.seat ?? -1), color: ZpColors.goldLight, radius: 2));
          _notify(CcNotice(e.seat == mySeat ? 'Last card declared' : '${_name(prev, e.seat)}: last card!', icon: Icons.campaign_rounded, color: ZpColors.goldLight));
        case 'caught':
          final by = e.payload['by'] as int?;
          world.add(fx.burst(seatPos(e.seat ?? -1), color: ZpColors.danger));
          _notify(CcNotice('${_name(prev, by)} caught ${_name(prev, e.seat)}', icon: Icons.front_hand_rounded, color: ZpColors.danger));
        case 'passed':
          if (e.seat != mySeat) _notify(CcNotice('${_name(prev, e.seat)} passed', icon: Icons.redo_rounded));
        case 'pile_reshuffled':
          _notify(const CcNotice('Draw pile reshuffled', icon: Icons.shuffle_rounded));
        case 'turn_timeout':
          _notify(CcNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(CcNotice('${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'round_won':
          final pts = e.payload['points'];
          ColorClashAudio.instance.play('victory');
          world.add(fx.confetti(Vector2(ArenaLayout.worldW, ArenaLayout.worldH), accent: next.currentColor.color));
          _notify(CcNotice('${_name(prev, e.seat)} wins the round, +$pts', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        case 'round_started':
          _notify(CcNotice('Round ${e.payload['round']}', icon: Icons.style_rounded, color: ZpColors.goldLight));
        case 'turn_changed':
          if (e.seat == mySeat) ColorClashAudio.instance.play('ui_tap');
          if (e.seat == mySeat && next.pendingDraw > 0) _notify(CcNotice('Surge +${next.pendingDraw} on you: stack or draw', icon: Icons.bolt_rounded, color: ZpColors.goldLight));
        case 'match_finished':
          break;
      }
    }
    _version = u.version;
    awaitingServer.value = false;
    _pendingTimeout?.cancel();
    _snap(next);
  }

  Future<void> _animatePlay(SequencedEvent e, CcView? prev) async {
    final seat = e.seat;
    final cardJson = e.payload['card'];
    if (seat == null || cardJson is! Map<String, dynamic>) return;
    final card = CcCard.fromJson(cardJson);
    final chosen = e.payload['chosenColor'] as String?;
    CardComponent? comp;
    if (seat == mySeat) {
      comp = hand.detach(card.id);
      selectedCardId.value = null;
    }
    final from = seatPos(seat);
    comp ??= CardComponent(card: card, faceUp: seat == mySeat, art: art, position: from, scale: seat == mySeat ? 1 : OpponentFanComponent.miniScale);
    comp.priority = 300;
    comp.busy = true;
    if (comp.parent != world) {
      comp.removeFromParent();
      world.add(comp);
    }
    final fan = fans[seat];
    if (fan != null && fan.count > 0) {
      fan.count -= 1;
      fan.flash();
    }
    ColorClashAudio.instance.play(card.isNumber ? 'card_play' : 'action');
    final fly = comp.flyTo(ArenaLayout.discardPos.clone(), angleTo: 0, duration: 0.45, arc: 120);
    if (seat != mySeat) {
      unawaited(comp.scaleTo(1, duration: 0.4));
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await comp.flipTo(true);
    }
    await fly;
    comp.removeFromParent();
    discard.push(card);
    final color = chosen != null ? CcColor.parse(chosen) : (card.color.isWild ? discard.currentColor : card.color);
    discard.currentColor = color;
    arena.currentColor = color;
    if (card.kind.isWild) {
      arena.colorWash(color.color);
      world.add(fx.burst(ArenaLayout.discardPos.clone(), color: color.color, count: 30));
      _notify(CcNotice('${_name(prev, seat)} chose ${color.label}', icon: Icons.palette_rounded, color: color.color));
    } else if (card.isNumber) {
      world.add(fx.ringPulse(ArenaLayout.discardPos.clone(), color: color.color, radius: 0.8));
    }
  }

  Future<void> _animateDraw(SequencedEvent e, CcView next) async {
    final seat = e.seat;
    final count = e.payload['count'] as int? ?? 1;
    if (seat == null) return;
    ColorClashAudio.instance.play('card_draw');
    if (seat == mySeat && next.myHand != null) {
      // My new cards are whatever the authoritative hand has that I am not showing yet.
      final shown = hand.cards.map((c) => c.card!.id).toSet();
      final fresh = <(int, CcCard)>[];
      for (var i = 0; i < next.myHand!.length; i++) {
        final c = next.myHand![i];
        if (!shown.contains(c.id)) fresh.add((i, c));
      }
      for (final (i, c) in fresh) {
        await hand.animateDraw(c, i);
      }
      drawPile.count = next.drawCount;
      return;
    }
    final fan = fans[seat];
    for (var i = 0; i < count; i++) {
      final comp = CardComponent(faceUp: false, art: art, position: ArenaLayout.drawPilePos.clone(), scale: 1);
      comp.priority = 300;
      world.add(comp);
      unawaited(comp.scaleTo(OpponentFanComponent.miniScale, duration: 0.35));
      final target = fan?.cardSlot(fan.count) ?? seatPos(seat);
      await comp.flyTo(target, angleTo: 0, duration: 0.35, arc: 100);
      comp.removeFromParent();
      if (fan != null) {
        fan.count += 1;
        fan.flash();
      }
      drawPile.count = (drawPile.count - 1).clamp(0, 999);
    }
  }

  String _name(CcView? s, int? seat) => seat == mySeat ? 'You' : (s?.seatOrNull(seat)?.displayName ?? 'Player');
  void _notify(CcNotice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  /// Snap every visual to the authoritative view.
  void _snap(CcView s) {
    displayState.value = s;
    drawPile.count = s.drawCount;
    discard.count = s.discardCount;
    discard.currentColor = s.currentColor;
    if (discard.top?.id != s.topCard?.id) discard.setTop(s.topCard);
    arena.currentColor = s.currentColor;
    arena.direction = s.direction;
    for (final seat in s.seats) {
      final f = fans[seat.seat];
      if (f == null) continue;
      f.count = seat.handCount;
      f.active = s.turnSeat == seat.seat && !s.finished;
      f.declared = seat.declared;
      f.forfeited = seat.forfeited;
      f.catchable = s.catchTargets.contains(seat.seat);
    }
    final myTurn = s.isMyTurn && !isSpectator;
    hand.interactive = myTurn;
    drawPile.enabled = myTurn && s.canDraw;
    if (s.myHand != null) {
      hand.setHand(s.myHand!, playable: s.playable.toSet(), drawnCardId: s.drawnCardId);
    } else {
      hand.setHand(const [], playable: const {});
    }
    if (selectedCardId.value != null && !s.isPlayable(selectedCardId.value!)) {
      selectedCardId.value = null;
      hand.select(null);
    }
  }
}
