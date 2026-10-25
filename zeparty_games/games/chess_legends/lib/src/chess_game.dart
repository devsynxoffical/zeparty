import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'chess_assets.dart';
import 'chess_audio.dart';
import 'components/board_component.dart';
import 'components/fx.dart';
import 'components/piece_component.dart';
import 'components/piece_painter.dart';
import 'model/board_fen.dart' as fen;
import 'model/chess_state.dart';

/// Visual configuration chosen from equipped cosmetics.
class ChessCosmetics {
  const ChessCosmetics({this.board = 'obsidian', this.pieces = 'crystal'});
  final String board;
  final String pieces;
}

/// HUD notification (toast).
class ChessNotice {
  const ChessNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// A move awaiting the promotion choice from the picker overlay.
typedef PendingPromotion = ({String from, String to});

/// Flame scene for Chess Legends. World = 8 cells of 100 units plus a 36 unit frame.
///
/// Authority: the client never generates moves. Legal targets come from the
/// server view (`legalMoves`), moves are submitted through [GameChannel], and
/// every server update is animated from its events then snapped to its FEN.
class ChessGame extends FlameGame {
  ChessGame({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final ChessCosmetics cosmetics;

  static const double cellSize = 100;
  static const double borderSize = 36;
  static const double boardSize = cellSize * 8 + borderSize * 2;

  late final BoardComponent board;
  late final Fx fx;
  late final PieceStyle pieceStyle = PieceStyle.byId(cosmetics.pieces);
  final PieceSprites pieceSprites = {};
  /// Square -> piece component, always mirroring [displayState] after animation.
  final Map<String, PieceComponent> pieces = {};

  final ValueNotifier<ChessState?> displayState = ValueNotifier(null);
  final ValueNotifier<ChessState?> latestState = ValueNotifier(null);
  final ValueNotifier<ChessNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<String?> selected = ValueNotifier(null);
  final ValueNotifier<PendingPromotion?> pendingPromotion = ValueNotifier(null);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  PieceComponent? _dragged;
  bool _finaleShown = false;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  /// 'w' or 'b' for the local player, null for spectators.
  String? get myColor {
    final s = displayState.value ?? latestState.value;
    return s?.seatOrNull(mySeat)?.color;
  }

  bool get flipped => myColor == 'b';

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    camera = CameraComponent.withFixedResolution(world: world, width: boardSize, height: boardSize);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final initial = ChessState.fromJson(session.initialState);
    _version = session.initialVersion;
    latestState.value = initial;
    final q = GraphicsSettings.instance.current;

    Future<ui.Image?> tryImg(String logical) async {
      try {
        return await images.load(ZpAssets.key(logical, quality: q));
      } catch (_) {
        return null;
      }
    }

    // Issue every load at once (one await) so the scene comes up in a single
    // round trip; each load is individually guarded and falls back to procedural art.
    final tex = ChessAssets.boardTextures[cosmetics.board] ?? ChessAssets.boardTextures['obsidian']!;
    final types = ChessAssets.pieceNames.keys.toList();
    final results = await Future.wait<ui.Image?>([
      tryImg(tex.$1),
      tryImg(tex.$2),
      tryImg(ChessAssets.particles),
      for (final t in types) ...[tryImg(ChessAssets.piece(t, white: true)), tryImg(ChessAssets.piece(t, white: false))],
    ]);
    final darkTex = results[0] ?? results[1];
    final lightTex = results[1];
    final particles = results[2];
    for (var i = 0; i < types.length; i++) {
      final w = results[3 + i * 2];
      final b = results[4 + i * 2];
      if (w != null) pieceSprites[types[i].toUpperCase()] = Sprite(w);
      if (b != null) pieceSprites[types[i]] = Sprite(b);
    }

    fx = Fx(sheet: particles == null ? null : SpriteSheet(image: particles, srcSize: Vector2(particles.width / 3, particles.height / 2)), cellSize: cellSize);
    final mine = initial.seatOrNull(mySeat)?.color;
    board = BoardComponent(
      skin: BoardSkin.resolve(cosmetics.board, darkTexture: darkTex, lightTexture: lightTex),
      cell: cellSize,
      border: borderSize,
      flipped: mine == 'b',
      onSquareTap: onSquareTapped,
      onDragBegin: _onDragBegin,
      onDragMove: _onDragMove,
      onDragFinish: _onDragFinish,
    );
    world.add(board);
    world.add(fx.ambientDust(Vector2.all(boardSize)));

    _syncPieces(initial);
    displayState.value = initial;
    _refreshHighlights(initial);
    if (initial.finished) _showFinale(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(ChessAudio.instance.init());
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onRemove();
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  bool get canInteract {
    final s = displayState.value;
    return s != null && !isSpectator && !s.finished && s.turnSeat == mySeat && !awaitingServer.value && !busy.value && pendingPromotion.value == null;
  }

  bool _isMine(String? piece) => piece != null && fen.isWhitePiece(piece) == (myColor == 'w');

  /// Tap-tap input: select an own piece with legal moves, then tap a target.
  void onSquareTapped(String square) {
    if (!canInteract) return;
    final s = displayState.value!;
    final sel = selected.value;
    if (sel != null && sel != square && s.isLegal(sel, square)) {
      attemptMove(sel, square);
      return;
    }
    final piece = s.placement.at(square);
    if (_isMine(piece) && s.legalTargets(square).isNotEmpty && sel != square) {
      selected.value = square;
      ChessAudio.instance.play('ui_tap');
    } else {
      selected.value = null;
    }
    _refreshHighlights(s);
  }

  bool _onDragBegin(String square) {
    if (!canInteract) return false;
    final s = displayState.value!;
    final p = pieces[square];
    if (p == null || !_isMine(p.piece) || s.legalTargets(square).isEmpty) return false;
    selected.value = square;
    _dragged = p
      ..lifted = true
      ..priority = 40;
    _refreshHighlights(s);
    return true;
  }

  void _onDragMove(Vector2 worldPoint) {
    final p = _dragged;
    if (p == null) return;
    p.position = worldPoint;
  }

  void _onDragFinish(String? target) {
    final p = _dragged;
    _dragged = null;
    if (p == null) return;
    p.lifted = false;
    final s = displayState.value;
    final from = p.square;
    if (s != null && target != null && target != from && s.isLegal(from, target)) {
      // Park the piece on the target while the server confirms; a rejection snaps it back.
      p.snapTo(from, board.squareCenter(target));
      attemptMove(from, target);
    } else {
      p.snapTo(from, board.squareCenter(from));
      if (target == from) return; // treated as a tap-select
      selected.value = null;
      if (s != null) _refreshHighlights(s);
    }
  }

  /// Routes through the promotion picker when a pawn reaches the last rank.
  void attemptMove(String from, String to) {
    final s = displayState.value;
    if (s == null) return;
    final piece = s.placement.at(from);
    final lastRank = fen.rankOf(to) == (myColor == 'w' ? 7 : 0);
    if (piece != null && piece.toLowerCase() == 'p' && lastRank) {
      pendingPromotion.value = (from: from, to: to);
      _refreshHighlights(s);
      return;
    }
    unawaited(requestMove(from, to));
  }

  void choosePromotion(String piece) {
    final p = pendingPromotion.value;
    pendingPromotion.value = null;
    if (p == null) return;
    unawaited(requestMove(p.from, p.to, promotion: piece));
  }

  void cancelPromotion() {
    final p = pendingPromotion.value;
    pendingPromotion.value = null;
    selected.value = null;
    final s = displayState.value;
    if (p != null) pieces[p.from]?.snapTo(p.from, board.squareCenter(p.from));
    if (s != null) _refreshHighlights(s);
  }

  Future<void> requestMove(String from, String to, {String? promotion}) async {
    final s = displayState.value;
    if (s == null || isSpectator || s.turnSeat != mySeat || s.finished || awaitingServer.value) return;
    if (!s.isLegal(from, to)) {
      _notify(const ChessNotice('Illegal move', icon: Icons.block_rounded, color: ZpColors.danger));
      return;
    }
    awaitingServer.value = true;
    selected.value = null;
    board.highlights
      ..selected = null
      ..legal = const []
      ..captures = const [];
    final action = <String, dynamic>{'type': 'move', 'from': from, 'to': to};
    if (promotion != null) action['promotion'] = promotion;
    try {
      await channel.submit(action, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      pieces[from]?.snapTo(from, board.squareCenter(from));
      _notify(ChessNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
      if (e.toString().contains('version_mismatch')) channel.resync();
    }
  }

  Future<void> _simple(String type) async {
    final s = displayState.value;
    if (s == null || isSpectator || s.finished) return;
    try {
      await channel.submit({'type': type}, version: _version);
    } catch (e) {
      _notify(ChessNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
    }
  }

  Future<void> resign() => _simple('resign');
  Future<void> offerDraw() => _simple('offer_draw');
  Future<void> acceptDraw() => _simple('accept_draw');
  Future<void> declineDraw() => _simple('decline_draw');

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('illegal_move')) return 'Illegal move';
    if (s.contains('version_mismatch')) return 'Syncing with the hall';
    if (s.contains('offer_pending')) return 'Offer already pending';
    if (s.contains('match_finished')) return 'The game is over';
    return 'Action rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = ChessState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    final s = ChessState.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    awaitingServer.value = false;
    busy.value = false;
    selected.value = null;
    pendingPromotion.value = null;
    _dragged = null;
    _syncPieces(s);
    _refreshHighlights(s);
    if (s.finished) _showFinale(s);
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    busy.value = true;
    try {
      while (_queue.isNotEmpty) {
        await _animate(_queue.removeFirst());
      }
    } finally {
      busy.value = false;
      _draining = false;
    }
  }

  Future<void> _animate(GameUpdate u) async {
    final next = ChessState.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      switch (e.type) {
        case 'move':
          awaitingServer.value = false;
          pendingPromotion.value = null;
          selected.value = null;
          await _animateMove(e.payload, prev);
        case 'check':
          ChessAudio.instance.play('check');
          if (e.seat == mySeat) _notify(const ChessNotice('Check', icon: Icons.warning_amber_rounded, color: ZpColors.danger));
        case 'checkmate':
          ChessAudio.instance.play('checkmate');
          _notify(const ChessNotice('Checkmate', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
        case 'stalemate':
          _notify(const ChessNotice('Stalemate', icon: Icons.handshake_rounded));
        case 'draw':
          _notify(ChessNotice('Draw: ${_reasonLabel(e.payload['reason'] as String?)}', icon: Icons.handshake_rounded, color: ZpColors.champagne));
        case 'resigned':
          _notify(ChessNotice('${_name(prev, e.seat)} resigned', icon: Icons.flag_rounded, color: ZpColors.danger));
        case 'flag_fell':
          _notify(ChessNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'draw_offered':
          if (e.seat != mySeat) _notify(ChessNotice('${_name(prev, e.seat)} offers a draw', icon: Icons.handshake_rounded, color: ZpColors.champagne));
        case 'draw_declined':
          if (e.seat != mySeat) _notify(ChessNotice('${_name(prev, e.seat)} declined the draw', icon: Icons.close_rounded));
        case 'turn_changed':
        case 'draw_accepted':
        case 'match_finished':
          break;
      }
    }
    _version = u.version;
    displayState.value = next;
    _syncPieces(next);
    _refreshHighlights(next);
    if (next.finished) _showFinale(next);
  }

  Future<void> _animateMove(Map<String, dynamic> p, ChessState? prev) async {
    final from = p['from'] as String;
    final to = p['to'] as String;
    final captured = p['captured'] as String?;
    final promotion = p['promotion'] as String?;
    final castle = p['castle'] as String?;
    final enPassant = p['enPassant'] as bool? ?? false;
    final mover = pieces.remove(from);
    if (mover == null) return;
    final white = mover.isWhite;

    // Victim: on the target square, or behind it for en passant.
    final victimSquare = enPassant ? '${to[0]}${fen.rankOf(to) + (white ? 0 : 2)}' : to;
    final victim = captured != null ? pieces.remove(victimSquare) : null;
    if (victim != null && victim != mover) {
      final at = board.squareCenter(victimSquare);
      world.add(fx.burst(at, color: victim.isWhite ? ZpColors.champagne : ZpColors.goldDeep));
      world.add(fx.ringPulse(at, color: ZpColors.goldLight));
      ChessAudio.instance.play('capture');
      unawaited(victim.captureOut());
    } else {
      ChessAudio.instance.play('move');
    }

    final futures = <Future<void>>[mover.moveTo(to, board.squareCenter(to))];
    if (castle != null) {
      final rank = white ? '1' : '8';
      final rookFrom = castle == 'K' ? 'h$rank' : 'a$rank';
      final rookTo = castle == 'K' ? 'f$rank' : 'd$rank';
      final rook = pieces.remove(rookFrom);
      if (rook != null) {
        pieces[rookTo] = rook;
        futures.add(rook.moveTo(rookTo, board.squareCenter(rookTo), duration: 0.34));
      }
    }
    pieces[to] = mover;
    await Future.wait(futures);
    if (promotion != null) {
      await mover.promoteTo(white ? promotion.toUpperCase() : promotion);
      world.add(fx.ringPulse(board.squareCenter(to), color: ZpColors.goldLight));
    }
  }

  String _reasonLabel(String? r) => switch (r) {
        'agreement' => 'agreed',
        'fifty_move' => 'fifty-move rule',
        'threefold_repetition' => 'repetition',
        'insufficient_material' => 'insufficient material',
        'stalemate' => 'stalemate',
        'timeout' => 'time, no mating material',
        _ => r ?? '',
      };

  String _name(ChessState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';

  void _notify(ChessNotice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  /// Make the piece set match the FEN exactly (creates, re-glyphs, removes, snaps).
  void _syncPieces(ChessState s) {
    final wanted = s.placement.pieces;
    for (final square in pieces.keys.toList()) {
      final comp = pieces[square]!;
      final want = wanted[square];
      if (want == null) {
        pieces.remove(square);
        comp.removeFromParent();
      } else if (comp.piece != want) {
        comp.piece = want;
      }
    }
    for (final e in wanted.entries) {
      final existing = pieces[e.key];
      if (existing == null) {
        final c = PieceComponent(square: e.key, piece: e.value, sprites: pieceSprites, style: pieceStyle, cellSize: cellSize)..position = board.squareCenter(e.key);
        pieces[e.key] = c;
        world.add(c);
      } else if (!existing.moving && (existing.position - board.squareCenter(e.key)).length > 0.5) {
        existing.snapTo(e.key, board.squareCenter(e.key));
      }
      pieces[e.key]!.inCheck = false;
    }
  }

  void _refreshHighlights(ChessState s) {
    final h = board.highlights;
    h.lastMove = s.lastMove;
    final kingSq = s.check && !s.finished ? s.placement.kingSquare(white: s.whiteToMove) : (s.check && s.result?.reason == 'checkmate' ? s.placement.kingSquare(white: s.whiteToMove) : null);
    h.checkSquare = kingSq;
    for (final p in pieces.values) {
      p.inCheck = kingSq != null && p.square == kingSq;
    }
    final sel = selected.value;
    final pending = pendingPromotion.value;
    if (sel != null && canInteract) {
      h.selected = sel;
      final targets = s.legalTargets(sel);
      h.legal = targets;
      final isPawn = s.placement.at(sel)?.toLowerCase() == 'p';
      h.captures = [for (final t in targets) if (s.placement.at(t) != null || (isPawn && t[0] != sel[0])) t];
    } else if (pending != null) {
      h.selected = pending.from;
      h.legal = const [];
      h.captures = const [];
    } else {
      h.selected = null;
      h.legal = const [];
      h.captures = const [];
    }
  }

  void _showFinale(ChessState s) {
    if (_finaleShown) return;
    _finaleShown = true;
    final r = s.result;
    if (r == null) return;
    if (r.reason == 'checkmate' && r.winnerSeat != null) {
      final winnerWhite = s.seatAt(r.winnerSeat!).isWhite;
      board.highlights.darkened = true;
      final king = s.placement.kingSquare(white: winnerWhite);
      if (king != null) {
        pieces[king]
          ?..crowned = true
          ..priority = 45;
      }
      world.add(fx.confetti(Vector2.all(boardSize), accent: winnerWhite ? ZpColors.champagne : ZpColors.royalPurple));
    } else if (!r.isDraw && r.winnerSeat == mySeat) {
      world.add(fx.confetti(Vector2.all(boardSize), accent: ZpColors.champagne));
    }
  }
}
