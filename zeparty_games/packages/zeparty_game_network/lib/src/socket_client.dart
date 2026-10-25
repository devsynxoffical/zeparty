import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

enum SocketStatus { disconnected, connecting, connected, reconnecting }

class ServerError {
  const ServerError(this.code, this.message, this.reqId);
  final String code;
  final String message;
  final String? reqId;
  @override
  String toString() => '$code: $message';
}

/// One multiplexed WebSocket per user. Reconnects with exponential backoff and
/// requests a resync after every reconnect so the UI converges on server state.
class ZePartySocketClient extends ChangeNotifier {
  ZePartySocketClient({required this.wsUrl, required this.authToken, WebSocketChannel Function(Uri uri)? connector}) : _connector = connector ?? WebSocketChannel.connect;

  final String wsUrl;
  String authToken;
  final WebSocketChannel Function(Uri uri) _connector;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  SocketStatus _status = SocketStatus.disconnected;
  int _attempt = 0;
  bool _closedByUser = false;
  Timer? _reconnectTimer;
  int _lastSeq = 0;

  final _room = StreamController<RoomState?>.broadcast();
  final _gameState = StreamController<Map<String, dynamic>>.broadcast();
  final _gameEvents = StreamController<Map<String, dynamic>>.broadcast();
  final _results = StreamController<MatchResult>.broadcast();
  final _presence = StreamController<Map<String, dynamic>>.broadcast();
  final _invites = StreamController<Map<String, dynamic>>.broadcast();
  final _errors = StreamController<ServerError>.broadcast();
  final Map<String, Completer<void>> _pending = {};
  int _reqCounter = 0;

  RoomState? _currentRoom;

  SocketStatus get status => _status;
  RoomState? get currentRoom => _currentRoom;
  int get lastSeq => _lastSeq;

  Stream<RoomState?> get roomStream => _room.stream;
  Stream<Map<String, dynamic>> get gameStateStream => _gameState.stream;
  Stream<Map<String, dynamic>> get gameEventsStream => _gameEvents.stream;
  Stream<MatchResult> get resultStream => _results.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presence.stream;
  Stream<Map<String, dynamic>> get inviteStream => _invites.stream;
  Stream<ServerError> get errorStream => _errors.stream;

  Future<void> connect() async {
    _closedByUser = false;
    _reconnectTimer?.cancel();
    _setStatus(_attempt == 0 ? SocketStatus.connecting : SocketStatus.reconnecting);
    try {
      final ch = _connector(Uri.parse(wsUrl));
      await ch.ready.timeout(const Duration(seconds: 10));
      _channel = ch;
      _sub = ch.stream.listen(_onMessage, onDone: _onDone, onError: (_) => _onDone());
      _sendRaw({'type': 'auth', 'token': authToken});
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _closedByUser = true;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(SocketStatus.disconnected);
  }

  void _onDone() {
    _sub?.cancel();
    _channel = null;
    if (_closedByUser) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closedByUser) return;
    _setStatus(SocketStatus.reconnecting);
    _attempt++;
    final delay = Duration(milliseconds: min(30000, 500 * pow(2, min(_attempt, 6)).toInt()) + Random().nextInt(300));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  void _setStatus(SocketStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }

  void _onMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = msg['type'] as String;
    switch (type) {
      case 'player.presence':
        if (_status != SocketStatus.connected) {
          // First presence after auth = authenticated.
          _attempt = 0;
          _setStatus(SocketStatus.connected);
          if (_lastSeq > 0 || _currentRoom != null) _sendRaw({'type': 'room.resync', 'afterSeq': _lastSeq});
        }
        _applyPresence(msg);
        _presence.add(msg);
      case 'room.state':
        _currentRoom = RoomState.fromJson(msg['room'] as Map<String, dynamic>);
        _room.add(_currentRoom);
        notifyListeners();
      case 'room.closed':
        _currentRoom = null;
        _lastSeq = 0;
        _room.add(null);
        notifyListeners();
      case 'room.invite':
        _invites.add(msg);
      case 'game.state':
        _lastSeq = msg['seq'] as int? ?? _lastSeq;
        _gameState.add(msg);
      case 'game.events':
        final events = msg['events'] as List<dynamic>;
        if (events.isNotEmpty) {
          final last = (events.last as Map<String, dynamic>)['seq'] as int;
          if (last > _lastSeq) _lastSeq = last;
        }
        _gameEvents.add(msg);
      case 'game.result':
        _results.add(MatchResult.fromJson(msg));
      case 'error':
        final err = ServerError(msg['code'] as String, msg['message'] as String? ?? '', msg['reqId'] as String?);
        final c = err.reqId == null ? null : _pending.remove(err.reqId);
        if (c != null) {
          c.completeError(err);
        } else {
          _errors.add(err);
        }
    }
  }

  void _applyPresence(Map<String, dynamic> msg) {
    final room = _currentRoom;
    if (room == null) return;
    final uid = msg['userId'] as String;
    final players = room.players
        .map((p) => p.userId == uid
            ? p.copyWith(connected: msg['connected'] as bool? ?? p.connected, micActive: msg['micActive'] as bool? ?? p.micActive, muted: msg['muted'] as bool? ?? p.muted)
            : p)
        .toList();
    _currentRoom = room.withPlayers(players);
    _room.add(_currentRoom);
  }

  void _sendRaw(Map<String, dynamic> m) {
    final ch = _channel;
    if (ch == null) throw StateError('socket not connected');
    ch.sink.add(jsonEncode(m));
  }

  /// Send a command. Resolves when the server has not replied with an error for
  /// `reqId` within a short window (the server only answers commands on failure).
  Future<void> send(Map<String, dynamic> m) {
    final reqId = 'r${++_reqCounter}';
    final c = Completer<void>();
    _pending[reqId] = c;
    try {
      _sendRaw({...m, 'reqId': reqId});
    } catch (e) {
      _pending.remove(reqId);
      return Future.error(e);
    }
    Timer(const Duration(milliseconds: 600), () {
      if (_pending.remove(reqId) != null && !c.isCompleted) c.complete();
    });
    return c.future;
  }

  // Convenience commands --------------------------------------------------------------------
  Future<void> createRoom(String gameId, {bool isPrivate = false, int? maxPlayers, Map<String, dynamic>? rules}) =>
      send({'type': 'room.create', 'gameId': gameId, 'isPrivate': isPrivate, 'maxPlayers': ?maxPlayers, 'rules': ?rules});
  Future<void> joinRoom(String roomId, {String? inviteCode}) => send({'type': 'room.join', 'roomId': roomId, 'inviteCode': ?inviteCode});
  Future<void> spectate(String roomId) => send({'type': 'room.spectate', 'roomId': roomId});
  Future<void> leaveRoom() => send({'type': 'room.leave'});
  Future<void> setReady(bool ready) => send({'type': 'room.ready', 'ready': ready});
  Future<void> invite(String roomId, String userId) => send({'type': 'room.invite', 'roomId': roomId, 'userId': userId});
  Future<void> kick(String userId) => send({'type': 'room.kick', 'userId': userId});
  Future<void> startMatch() => send({'type': 'room.start'});
  Future<void> voteRematch() => send({'type': 'room.rematch'});
  Future<void> joinMatchmaking(String gameId, {int? tableSize}) => send({'type': 'matchmaking.join', 'gameId': gameId, 'tableSize': ?tableSize});
  Future<void> leaveMatchmaking() => send({'type': 'matchmaking.leave'});
  Future<void> setVoiceState({required bool micActive, required bool muted}) => send({'type': 'voice.state', 'micActive': micActive, 'muted': muted});
  void resync({int afterSeq = 0}) => _sendRaw({'type': 'room.resync', 'afterSeq': afterSeq});
  Future<void> gameAction(String roomId, String matchId, Map<String, dynamic> action, {required int version}) =>
      send({'type': 'game.action', 'roomId': roomId, 'matchId': matchId, 'version': version, 'action': action});

  @override
  void dispose() {
    disconnect();
    _room.close();
    _gameState.close();
    _gameEvents.close();
    _results.close();
    _presence.close();
    _invites.close();
    _errors.close();
    super.dispose();
  }
}
