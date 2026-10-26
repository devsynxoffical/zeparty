import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

enum AppEnvironment {
  development,
  staging,
  production,
}

/// Authoritative Centralized Environment Configuration for ZeParty Mobile Client
class AppConfig {
  static AppEnvironment _environment = AppEnvironment.production;
  static String _apiBaseUrl = railwayApiUrl;

  static AppEnvironment get environment => _environment;
  static String get apiBaseUrl => _apiBaseUrl;

  /// Live Railway Backend URL (production)
  static const String railwayApiUrl = 'https://zeparty-backend-production.up.railway.app/api';

  /// Staging API Base URL
  static const String stagingApiUrl = railwayApiUrl;

  /// Development LAN URL (for optional local debugging)
  static const String devLanUrl = 'http://192.168.18.113:8080/api';

  /// Production API Base URL
  static const String defaultProdUrl = railwayApiUrl;

  // ── Premium games service (zeparty_games/backend) ──
  // Compile-time override: --dart-define=GAMES_API_BASE_URL=https://games.example.com
  // The value returned by GET /v1/games/token (apiBaseUrl / wsUrl) takes precedence at runtime.
  static const String _gamesApiOverride = String.fromEnvironment('GAMES_API_BASE_URL');
  static const String _gamesWsOverride = String.fromEnvironment('GAMES_WS_URL');
  static const String defaultGamesApiUrl = 'https://zeparty-games-production.up.railway.app';

  static String get gamesApiBaseUrl => _gamesApiOverride.isNotEmpty ? _gamesApiOverride : defaultGamesApiUrl;

  static String get gamesWsUrl => _gamesWsOverride.isNotEmpty ? _gamesWsOverride : deriveGamesWsUrl(gamesApiBaseUrl);

  /// https://host → wss://host/ws, http://host → ws://host/ws
  static String deriveGamesWsUrl(String apiBaseUrl) {
    var base = apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    if (base.startsWith('https://')) return 'wss://${base.substring(8)}/ws';
    if (base.startsWith('http://')) return 'ws://${base.substring(7)}/ws';
    return '$base/ws';
  }

  /// Initialize application environment and configure ApiClient
  static void initialize({
    AppEnvironment environment = AppEnvironment.production,
    String? customBaseUrl,
  }) {
    _environment = environment;

    if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
      _apiBaseUrl = customBaseUrl;
    } else {
      const envOverride = String.fromEnvironment('API_BASE_URL');
      if (envOverride.isNotEmpty) {
        _apiBaseUrl = envOverride;
      } else {
        // Always default to live production Railway server
        _apiBaseUrl = railwayApiUrl;
      }
    }

    // Configure the authoritative ApiClient instance
    ApiClient.instance.initialize(baseUrl: _apiBaseUrl);
    debugPrint('[AppConfig] Initialized in ${_environment.name} mode with API Base: $_apiBaseUrl');
  }
}
