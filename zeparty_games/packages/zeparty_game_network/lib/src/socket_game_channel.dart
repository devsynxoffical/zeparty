import 'dart:async';

import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'socket_client.dart';

/// Adapts the multiplexed socket into the per-match [GameChannel] a game sees.
class SocketGameChannel implements RealtimeGameChannel {
  SocketGameChannel({required this.socket, required this.roomId, required this.matchId});

  final ZePartySocketClient socket;
  final String roomId;
  final String matchId;

  @override
  Stream<GameUpdate> get updates => socket.gameEventsStream.where((m) => m['matchId'] == matchId).map((m) => GameUpdate(
        events: (m['events'] as List<dynamic>).map((e) => SequencedEvent.fromJson(e as Map<String, dynamic>)).toList(),
        state: m['state'] as Map<String, dynamic>,
        version: m['version'] as int,
      ));

  @override
  Stream<GameUpdate> get snapshots => socket.gameStateStream.where((m) => m['matchId'] == matchId).map((m) => GameUpdate(
        events: const [],
        state: m['state'] as Map<String, dynamic>,
        version: m['version'] as int,
      ));

  @override
  Stream<MatchResult> get results => socket.resultStream.where((r) => r.matchId == matchId);

  @override
  Stream<RoomPlayer> get presence => socket.roomStream.where((r) => r != null).expand((r) => r!.players);

  @override
  Future<void> submit(Map<String, dynamic> action, {required int version}) => socket.gameAction(roomId, matchId, action, version: version);

  /// Real-time input: no `version`, so the room layer applies it against whatever
  /// state the server tick is at. Errors are reported through the socket's error
  /// stream; the future is intentionally not awaited.
  @override
  void sendRealtime(Map<String, dynamic> action) {
    unawaited(socket.send({'type': 'game.action', 'roomId': roomId, 'matchId': matchId, 'action': action}).catchError((Object _) {}));
  }

  @override
  void resync({int afterSeq = 0}) => socket.resync(afterSeq: afterSeq);
}
