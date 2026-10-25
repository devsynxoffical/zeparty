import 'dart:async';

import 'identity.dart';

/// Voice room state owned by the ZeParty host app. Games only observe it.
class VoiceParticipantState {
  const VoiceParticipantState({required this.userId, required this.speaking, required this.muted, required this.connected});
  final String userId;
  final bool speaking;
  final bool muted;
  final bool connected;
}

/// Hooks the host application implements so the games can coexist with the
/// existing social features. Every method has a safe no-op default so the demo
/// shell runs without the host. See docs/integration/host_bridge.md.
abstract class ZePartyHostBridge {
  const ZePartyHostBridge();

  /// Stream of voice activity for players in the current room. The game draws
  /// mic / speaker indicators from this; it never captures audio itself.
  Stream<VoiceParticipantState> get voiceState => const Stream.empty();

  /// Whether the host's audio session is currently active (someone talking).
  /// Used to duck game music.
  Stream<bool> get voiceActive => const Stream.empty();

  /// Request the host to mute or unmute the local user.
  Future<void> setLocalMuted(bool muted) async {}

  /// Open the host's friend picker; resolves with the chosen user ids.
  Future<List<ZePartyIdentity>> pickFriendsToInvite() async => const [];

  /// Deliver a social notification through the host (invite received, rematch).
  Future<void> notify({required String toUserId, required String title, required String body, Map<String, String> data = const {}}) async {}

  /// Open a user's profile in the host app.
  Future<void> openProfile(String userId) async {}

  /// Host-side room ownership: who owns the live/voice room the game runs in.
  String? get roomOwnerId => null;

  /// Host asks the game to shut down (e.g. live room ended). Games listen and leave.
  Stream<String> get hostCloseRequests => const Stream.empty();

  /// The host reports a player was removed from the live room; the game forfeits them.
  Stream<String> get playerRemoved => const Stream.empty();

  /// Haptic feedback through the host's settings (user may have haptics off).
  Future<void> haptic(HapticKind kind) async {}
}

enum HapticKind { light, medium, heavy, success, error }

/// Default bridge for the standalone demo: logs and no-ops.
class NoopHostBridge extends ZePartyHostBridge {
  const NoopHostBridge();
}

/// Mutable bridge for tests and the demo's voice simulator.
class SimulatedHostBridge extends ZePartyHostBridge {
  final _voice = StreamController<VoiceParticipantState>.broadcast();
  final _active = StreamController<bool>.broadcast();
  final _close = StreamController<String>.broadcast();
  final _removed = StreamController<String>.broadcast();
  final List<String> notifications = [];

  @override
  Stream<VoiceParticipantState> get voiceState => _voice.stream;
  @override
  Stream<bool> get voiceActive => _active.stream;
  @override
  Stream<String> get hostCloseRequests => _close.stream;
  @override
  Stream<String> get playerRemoved => _removed.stream;

  void emitVoice(VoiceParticipantState s) => _voice.add(s);
  void emitVoiceActive(bool v) => _active.add(v);
  void requestClose(String reason) => _close.add(reason);
  void removePlayer(String userId) => _removed.add(userId);

  @override
  Future<void> notify({required String toUserId, required String title, required String body, Map<String, String> data = const {}}) async {
    notifications.add('$toUserId: $title');
  }

  void dispose() {
    _voice.close();
    _active.close();
    _close.close();
    _removed.close();
  }
}
