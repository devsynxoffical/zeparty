import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:air_hockey/air_hockey.dart' show AirHockeyModule;
import 'package:carrom_masters/carrom_masters.dart' show CarromMastersModule;
import 'package:chess_legends/chess_legends.dart' show ChessLegendsModule;
import 'package:color_clash/color_clash.dart' show ColorClashModule;
import 'package:connect4_galaxy/connect4_galaxy.dart' show Connect4GalaxyModule;
import 'package:darts_arena/darts_arena.dart' show DartsArenaModule;
import 'package:ludo_royale/ludo_royale.dart' show LudoRoyaleModule;
import 'package:mini_golf_paradise/mini_golf_paradise.dart' show MiniGolfParadiseModule;
import 'package:pool_elite/pool_elite.dart' show PoolEliteModule;
import 'package:snake_ladder_kingdom/snake_ladder_kingdom.dart' show SnakeLadderKingdomModule;
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../../core/config/app_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_overlay_provider.dart';
import 'games_session_service.dart';
import 'zeparty_host_bridge.dart';

/// Registers the ten premium games and configures the shared launcher.
///
/// Call [GamesBootstrap.initialize] once at startup (after `AppConfig`). Open a
/// game anywhere with [GamesBootstrap.openGame]; the full Game Center hub is
/// `GameLobbyScreen`.
class GamesBootstrap {
  GamesBootstrap._();

  static bool _registered = false;
  static final ZePartyAppHostBridge _bridge = ZePartyAppHostBridge();

  /// The ten shipped games, in Game Center order.
  static const List<String> gameIds = [
    'ludo_royale',
    'connect4_galaxy',
    'snake_ladder_kingdom',
    'chess_legends',
    'color_clash',
    'carrom_masters',
    'pool_elite',
    'air_hockey',
    'darts_arena',
    'mini_golf_paradise',
  ];

  static void initialize() {
    registerAllGames();
    configureLauncher(apiBaseUrl: AppConfig.gamesApiBaseUrl, wsUrl: AppConfig.gamesWsUrl);
  }

  static void registerAllGames() {
    if (_registered) return;
    GameModuleRegistry.instance
      ..register(LudoRoyaleModule())
      ..register(Connect4GalaxyModule())
      ..register(SnakeLadderKingdomModule())
      ..register(ChessLegendsModule())
      ..register(ColorClashModule())
      ..register(CarromMastersModule())
      ..register(PoolEliteModule())
      ..register(AirHockeyModule())
      ..register(DartsArenaModule())
      ..register(MiniGolfParadiseModule());
    _registered = true;
  }

  /// (Re)configures the launcher. Called at startup with the compile-time URLs
  /// and again whenever the backend hands us the live games-service endpoints.
  static void configureLauncher({required String apiBaseUrl, required String wsUrl}) {
    if (ZePartyGameLauncher.isConfigured &&
        ZePartyGameLauncher.config.apiBaseUrl == apiBaseUrl &&
        ZePartyGameLauncher.config.wsUrl == wsUrl) {
      return;
    }
    ZePartyGameLauncher.configure(
      ZePartyGamesConfig(apiBaseUrl: apiBaseUrl, wsUrl: wsUrl, hostBridge: _bridge),
      NavigatorLauncherDelegate(RoomOverlayProvider.navigatorKey),
    );
  }

  /// Fetches a games token for the signed-in user and returns the session plus
  /// the endpoints to use. Throws when the user is not signed in or the token
  /// request fails.
  static Future<(ZePartySession, GamesSessionInfo)> prepareSession(BuildContext context, {bool forceRefresh = false}) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (!auth.isAuthenticated || user.id.isEmpty) {
      throw StateError('Sign in to play games');
    }
    final info = await GamesSessionService.instance.fetch(user, forceRefresh: forceRefresh);
    configureLauncher(apiBaseUrl: info.apiBaseUrl, wsUrl: info.wsUrl);
    return (GamesSessionService.instance.toSession(user, info), info);
  }

  /// Opens [gameId] full screen (its lobby, or [roomId] directly). Shows a
  /// snackbar and returns false when the session could not be prepared.
  static Future<bool> openGame(BuildContext context, String gameId, {String? roomId, String? inviteCode}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final (session, _) = await prepareSession(context);
      await ZePartyGameLauncher.openGame(
        gameId: gameId,
        roomId: roomId,
        inviteCode: inviteCode,
        userId: session.identity.userId,
        displayName: session.identity.displayName,
        avatarUrl: session.identity.avatarUrl,
        authToken: session.authToken,
      );
      return true;
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      return false;
    }
  }

  static String _friendlyError(Object e) {
    if (e is StateError) return e.message;
    final text = e.toString();
    if (text.contains('Network') || text.contains('connection')) {
      return 'Cannot reach the game servers right now. Please try again.';
    }
    return 'Could not start the game. Please try again.';
  }
}
