import 'host_bridge.dart';
import 'identity.dart';

/// Configuration the host supplies once at startup.
class ZePartyGamesConfig {
  const ZePartyGamesConfig({
    required this.apiBaseUrl,
    required this.wsUrl,
    this.hostBridge = const NoopHostBridge(),
    this.assetPackage = 'zeparty_game_assets',
  });

  /// e.g. https://games.zeparty.app
  final String apiBaseUrl;

  /// e.g. wss://games.zeparty.app/ws
  final String wsUrl;
  final ZePartyHostBridge hostBridge;

  /// Package that bundles the shared assets. Games load through this.
  final String assetPackage;
}

/// Request to open a game from the host application.
///
/// ```dart
/// ZePartyGameLauncher.openGame(
///   gameId: "ludo_royale",
///   roomId: roomId,          // null: open the game lobby for that game
///   userId: currentUserId,
///   authToken: authToken,
/// );
/// ```
class GameLaunchRequest {
  const GameLaunchRequest({
    required this.gameId,
    required this.session,
    this.roomId,
    this.inviteCode,
    this.spectate = false,
  });

  final String gameId;
  final ZePartySession session;

  /// Join this room immediately. Null opens the game's lobby.
  final String? roomId;
  final String? inviteCode;
  final bool spectate;
}

/// Launcher contract implemented by zeparty_game_ui. Kept here so the host app
/// depends only on core for the call site.
abstract class ZePartyGameLauncherDelegate {
  Future<void> open(GameLaunchRequest request);
}

class ZePartyGameLauncher {
  ZePartyGameLauncher._();

  static ZePartyGamesConfig? _config;
  static ZePartyGameLauncherDelegate? _delegate;

  static ZePartyGamesConfig get config {
    final c = _config;
    if (c == null) throw StateError('ZePartyGameLauncher.configure() must be called first');
    return c;
  }

  static bool get isConfigured => _config != null;

  static void configure(ZePartyGamesConfig config, ZePartyGameLauncherDelegate delegate) {
    _config = config;
    _delegate = delegate;
  }

  /// Host-facing entry point.
  static Future<void> openGame({
    required String gameId,
    required String userId,
    required String authToken,
    String? roomId,
    String? inviteCode,
    String displayName = '',
    String? avatarUrl,
    bool spectate = false,
  }) {
    final d = _delegate;
    if (d == null) throw StateError('ZePartyGameLauncher.configure() must be called first');
    return d.open(GameLaunchRequest(
      gameId: gameId,
      roomId: roomId,
      inviteCode: inviteCode,
      spectate: spectate,
      session: ZePartySession(
        identity: ZePartyIdentity(userId: userId, displayName: displayName.isEmpty ? userId : displayName, avatarUrl: avatarUrl),
        authToken: authToken,
      ),
    ));
  }
}
