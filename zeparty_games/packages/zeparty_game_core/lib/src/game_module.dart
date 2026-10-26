import 'package:flutter/widgets.dart';

import 'identity.dart';
import 'room.dart';

/// Everything a game screen needs from the platform. Constructed by the
/// launcher, never by the game.
class GameSessionContext {
  const GameSessionContext({
    required this.session,
    required this.room,
    required this.mySeat,
    required this.matchId,
    required this.initialState,
    required this.initialVersion,
    required this.initialSeq,
    required this.deadline,
  });

  final ZePartySession session;
  final RoomState room;

  /// Null when spectating.
  final int? mySeat;
  final String matchId;
  final Map<String, dynamic> initialState;
  final int initialVersion;
  final int initialSeq;
  final int? deadline;

  bool get isSpectator => mySeat == null;
}

/// Live channel between a running game and the authoritative server.
abstract class GameChannel {
  /// Submit an action. The server validates and broadcasts; the game must not
  /// mutate authoritative state locally beyond optimistic animation.
  Future<void> submit(Map<String, dynamic> action, {required int version});

  /// Stream of (events, fullState, version) from the server for this match.
  Stream<GameUpdate> get updates;

  /// Full-state snapshots (initial sync and after a resync). Games must replace
  /// their local state with these and drop any pending animations.
  Stream<GameUpdate> get snapshots;

  /// Emits when the match result arrives.
  Stream<MatchResult> get results;

  /// Presence changes of players in this room.
  Stream<RoomPlayer> get presence;

  /// Ask for a full resync (after a reconnect or on suspicion of drift).
  void resync({int afterSeq = 0});
}

/// Optional extension of [GameChannel] for real-time games (air hockey): sends an
/// action without a version so high-rate inputs never race the server tick.
/// The room layer only checks the version when it is present.
abstract class RealtimeGameChannel implements GameChannel {
  void sendRealtime(Map<String, dynamic> action);
}

/// Lets any game call `channel.sendRealtime(...)`. Channels that do not implement
/// [RealtimeGameChannel] throw [UnsupportedError].
extension GameChannelRealtime on GameChannel {
  void sendRealtime(Map<String, dynamic> action) {
    final self = this;
    if (self is RealtimeGameChannel) {
      self.sendRealtime(action);
      return;
    }
    throw UnsupportedError('${self.runtimeType} does not support real-time actions');
  }
}

class GameUpdate {
  const GameUpdate({required this.events, required this.state, required this.version});
  final List<SequencedEvent> events;
  final Map<String, dynamic> state;
  final int version;
}

/// A playable game module. Each game package exposes one of these.
abstract class ZePartyGameModule {
  String get gameId;

  /// Assets this game needs preloaded before [buildGame] is shown (relative to assets root).
  List<String> get preloadAssets;

  /// Build the full-screen game widget for an active match.
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel);

  /// Optional: a small animated preview for the Game Center card.
  Widget? buildCardPreview(BuildContext context) => null;
}

/// Registry the launcher resolves games from. Host app registers each game
/// package once at startup.
class GameModuleRegistry {
  GameModuleRegistry._();
  static final GameModuleRegistry instance = GameModuleRegistry._();
  final Map<String, ZePartyGameModule> _modules = {};

  void register(ZePartyGameModule module) => _modules[module.gameId] = module;
  ZePartyGameModule? resolve(String gameId) => _modules[gameId];
  Iterable<String> get registeredIds => _modules.keys;
}
