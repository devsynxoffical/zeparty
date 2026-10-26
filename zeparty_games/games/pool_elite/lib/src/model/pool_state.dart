import 'dart:math' as math;

/// Mirrors backend/src/games/pool_elite/rules.ts.
class PoolRules {
  const PoolRules({
    this.eightOnBreak = 'respot',
    this.ballInHandAnywhere = true,
    this.callShots = false,
    this.turnTimeoutSeconds = 45,
    this.timeoutsToForfeit = 3,
  });

  final String eightOnBreak;
  final bool ballInHandAnywhere;
  final bool callShots;
  final int turnTimeoutSeconds;
  final int timeoutsToForfeit;

  factory PoolRules.fromJson(Map<String, dynamic> j) => PoolRules(
        eightOnBreak: j['eightOnBreak'] as String? ?? 'respot',
        ballInHandAnywhere: j['ballInHandAnywhere'] as bool? ?? true,
        callShots: j['callShots'] as bool? ?? false,
        turnTimeoutSeconds: (j['turnTimeoutSeconds'] as num?)?.toInt() ?? 45,
        timeoutsToForfeit: (j['timeoutsToForfeit'] as num?)?.toInt() ?? 3,
      );
}

class PoolPocket {
  const PoolPocket({required this.id, required this.x, required this.y, required this.r, required this.kind});
  final int id;
  final double x;
  final double y;
  final double r;
  final String kind;

  factory PoolPocket.fromJson(Map<String, dynamic> j) => PoolPocket(
        id: (j['id'] as num).toInt(),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        r: (j['r'] as num).toDouble(),
        kind: j['kind'] as String? ?? 'corner',
      );
}

class PoolSegment {
  const PoolSegment(this.x1, this.y1, this.x2, this.y2);
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  factory PoolSegment.fromJson(Map<String, dynamic> j) => PoolSegment(
        (j['x1'] as num).toDouble(),
        (j['y1'] as num).toDouble(),
        (j['x2'] as num).toDouble(),
        (j['y2'] as num).toDouble(),
      );
}

/// Exact playfield geometry shipped inside the state by the server. The
/// renderer draws from these numbers so hit areas and replays line up.
class PoolTable {
  const PoolTable({
    required this.width,
    required this.height,
    required this.ballRadius,
    required this.headStringX,
    required this.footSpot,
    required this.headSpot,
    required this.pockets,
    required this.cushions,
  });

  final double width;
  final double height;
  final double ballRadius;
  final double headStringX;
  final math.Point<double> footSpot;
  final math.Point<double> headSpot;
  final List<PoolPocket> pockets;
  final List<PoolSegment> cushions;

  static math.Point<double> _pt(Map<String, dynamic>? j, double x, double y) =>
      j == null ? math.Point<double>(x, y) : math.Point((j['x'] as num).toDouble(), (j['y'] as num).toDouble());

  factory PoolTable.fromJson(Map<String, dynamic> j) => PoolTable(
        width: (j['width'] as num?)?.toDouble() ?? 200,
        height: (j['height'] as num?)?.toDouble() ?? 100,
        ballRadius: (j['ballRadius'] as num?)?.toDouble() ?? 2.86,
        headStringX: (j['headStringX'] as num?)?.toDouble() ?? 50,
        footSpot: _pt(j['footSpot'] as Map<String, dynamic>?, 150, 50),
        headSpot: _pt(j['headSpot'] as Map<String, dynamic>?, 50, 50),
        pockets: (j['pockets'] as List<dynamic>? ?? const []).map((p) => PoolPocket.fromJson(p as Map<String, dynamic>)).toList(),
        cushions: (j['cushions'] as List<dynamic>? ?? const []).map((p) => PoolSegment.fromJson(p as Map<String, dynamic>)).toList(),
      );

  /// Default geometry when a snapshot predates the table spec (tests, previews).
  factory PoolTable.standard() => const PoolTable(
        width: 200,
        height: 100,
        ballRadius: 2.86,
        headStringX: 50,
        footSpot: math.Point(150, 50),
        headSpot: math.Point(50, 50),
        pockets: [
          PoolPocket(id: 0, x: -1.6, y: -1.6, r: 5.2, kind: 'corner'),
          PoolPocket(id: 1, x: 100, y: -2.0, r: 4.6, kind: 'side'),
          PoolPocket(id: 2, x: 201.6, y: -1.6, r: 5.2, kind: 'corner'),
          PoolPocket(id: 3, x: -1.6, y: 101.6, r: 5.2, kind: 'corner'),
          PoolPocket(id: 4, x: 100, y: 102.0, r: 4.6, kind: 'side'),
          PoolPocket(id: 5, x: 201.6, y: 101.6, r: 5.2, kind: 'corner'),
        ],
        cushions: [],
      );

  PoolPocket? pocketById(int id) {
    for (final p in pockets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// True when a ball centred here would leave the cloth or overlap [others].
  bool placementBlocked(double x, double y, Iterable<PoolBall> others) {
    final r = ballRadius;
    if (x < r || x > width - r || y < r || y > height - r) return true;
    for (final o in others) {
      if (o.pocketed || o.id == 0) continue;
      final dx = o.x - x;
      final dy = o.y - y;
      if (dx * dx + dy * dy < 4 * r * r - 1e-6) return true;
    }
    return false;
  }
}

class PoolBall {
  const PoolBall({required this.id, required this.x, required this.y, required this.pocketed});
  final int id;
  final double x;
  final double y;
  final bool pocketed;

  bool get isCue => id == 0;
  bool get isEight => id == 8;
  bool get isSolid => id >= 1 && id <= 7;
  bool get isStripe => id >= 9 && id <= 15;
  String? get group => isSolid ? 'solids' : (isStripe ? 'stripes' : null);

  factory PoolBall.fromJson(Map<String, dynamic> j) => PoolBall(
        id: (j['id'] as num).toInt(),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        pocketed: j['pocketed'] as bool? ?? false,
      );
}

class PoolSeat {
  const PoolSeat({
    required this.seat,
    required this.userId,
    required this.displayName,
    required this.group,
    required this.fouls,
    required this.consecutiveTimeouts,
    required this.forfeited,
    required this.connected,
  });

  final int seat;
  final String userId;
  final String displayName;

  /// 'solids', 'stripes' or null while the table is open.
  final String? group;
  final int fouls;
  final int consecutiveTimeouts;
  final bool forfeited;
  final bool connected;

  factory PoolSeat.fromJson(Map<String, dynamic> j) => PoolSeat(
        seat: (j['seat'] as num).toInt(),
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        group: j['group'] as String?,
        fouls: (j['fouls'] as num?)?.toInt() ?? 0,
        consecutiveTimeouts: (j['consecutiveTimeouts'] as num?)?.toInt() ?? 0,
        forfeited: j['forfeited'] as bool? ?? false,
        connected: j['connected'] as bool? ?? true,
      );
}

enum PoolPhase {
  breakShot,
  play,
  finished;

  static PoolPhase parse(String? s) => switch (s) { 'break' => PoolPhase.breakShot, 'finished' => PoolPhase.finished, _ => PoolPhase.play };
}

class LastShot {
  const LastShot({required this.seat, required this.pocketed, required this.fouls, required this.firstContact, required this.railContacted, required this.cueScratched, required this.isBreak});
  final int seat;
  final List<int> pocketed;
  final List<String> fouls;
  final int? firstContact;
  final bool railContacted;
  final bool cueScratched;
  final bool isBreak;

  factory LastShot.fromJson(Map<String, dynamic> j) => LastShot(
        seat: (j['seat'] as num).toInt(),
        pocketed: (j['pocketed'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
        fouls: (j['fouls'] as List<dynamic>? ?? const []).cast<String>(),
        firstContact: (j['firstContact'] as num?)?.toInt(),
        railContacted: j['railContacted'] as bool? ?? false,
        cueScratched: j['cueScratched'] as bool? ?? false,
        isBreak: j['isBreak'] as bool? ?? false,
      );
}

/// Immutable snapshot of the server's pool state (see backend engine.ts).
class PoolState {
  const PoolState({
    required this.rules,
    required this.table,
    required this.seats,
    required this.balls,
    required this.turnSeat,
    required this.phase,
    required this.openTable,
    required this.ballInHand,
    required this.cueBehindHeadString,
    required this.shotCount,
    required this.lastShot,
    required this.winnerSeat,
    required this.finishReason,
    required this.placements,
    required this.version,
    required this.turnDeadline,
  });

  final PoolRules rules;
  final PoolTable table;
  final List<PoolSeat> seats;
  final List<PoolBall> balls;
  final int turnSeat;
  final PoolPhase phase;
  final bool openTable;
  final bool ballInHand;
  final bool cueBehindHeadString;
  final int shotCount;
  final LastShot? lastShot;
  final int? winnerSeat;
  final String? finishReason;
  final List<int> placements;
  final int version;
  final int? turnDeadline;

  bool get finished => phase == PoolPhase.finished;
  bool get isBreak => phase == PoolPhase.breakShot;

  PoolSeat seatAt(int seat) => seats.firstWhere((s) => s.seat == seat);
  PoolSeat? seatOrNull(int? seat) => seat == null ? null : seats.where((s) => s.seat == seat).firstOrNull;
  PoolSeat get current => seatAt(turnSeat);
  PoolSeat opponentOf(int seat) => seats.firstWhere((s) => s.seat != seat);

  PoolBall get cueBall => balls.firstWhere((b) => b.id == 0);
  PoolBall? ballById(int id) => balls.where((b) => b.id == id).firstOrNull;
  Iterable<PoolBall> get onTable => balls.where((b) => !b.pocketed);

  /// Balls of [group] still on the table.
  int remaining(String? group) => group == null ? 0 : balls.where((b) => !b.pocketed && b.group == group).length;

  /// Mirrors the server's legal first-contact rule for the aim guide.
  List<int> legalFirstContacts(int seat) {
    final me = seatAt(seat);
    final live = onTable.where((b) => !b.isCue).toList();
    if (isBreak) return live.map((b) => b.id).toList();
    if (openTable || me.group == null) return live.where((b) => !b.isEight).map((b) => b.id).toList();
    final own = live.where((b) => b.group == me.group).toList();
    if (own.isNotEmpty) return own.map((b) => b.id).toList();
    return live.where((b) => b.isEight).map((b) => b.id).toList();
  }

  factory PoolState.fromJson(Map<String, dynamic> j) => PoolState(
        rules: PoolRules.fromJson((j['rules'] as Map<String, dynamic>?) ?? const {}),
        table: j['table'] == null ? PoolTable.standard() : PoolTable.fromJson(j['table'] as Map<String, dynamic>),
        seats: (j['seats'] as List<dynamic>).map((s) => PoolSeat.fromJson(s as Map<String, dynamic>)).toList(),
        balls: (j['balls'] as List<dynamic>).map((b) => PoolBall.fromJson(b as Map<String, dynamic>)).toList(),
        turnSeat: (j['turnSeat'] as num).toInt(),
        phase: PoolPhase.parse(j['phase'] as String?),
        openTable: j['openTable'] as bool? ?? true,
        ballInHand: j['ballInHand'] as bool? ?? false,
        cueBehindHeadString: j['cueBehindHeadString'] as bool? ?? false,
        shotCount: (j['shotCount'] as num?)?.toInt() ?? 0,
        lastShot: j['lastShot'] == null ? null : LastShot.fromJson(j['lastShot'] as Map<String, dynamic>),
        winnerSeat: (j['winnerSeat'] as num?)?.toInt(),
        finishReason: j['finishReason'] as String?,
        placements: (j['placements'] as List<dynamic>? ?? const []).map((e) => (e as num).toInt()).toList(),
        version: (j['version'] as num?)?.toInt() ?? 0,
        turnDeadline: (j['turnDeadline'] as num?)?.toInt(),
      );
}
