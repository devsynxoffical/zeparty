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
