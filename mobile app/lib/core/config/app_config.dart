import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

enum AppEnvironment {
  development,
  staging,
  production,
}

/// Authoritative Centralized Environment Configuration for ZeParty Mobile Client
class AppConfig {
  static AppEnvironment _environment = AppEnvironment.development;
  static String _apiBaseUrl = '';

  static AppEnvironment get environment => _environment;
  static String get apiBaseUrl => _apiBaseUrl;

  /// Staging API Base URL (intended domain: https://api-staging.zeparty.site)
  static const String stagingApiUrl = 'https://api-staging.zeparty.site/api';

  /// Development API Base URLs
  static const String devAndroidEmulatorUrl = 'http://10.0.2.2:5000/api';
  static const String devIosOrWebUrl = 'http://localhost:5000/api';

  /// Production API Base URL fallback
  static const String defaultProdUrl = 'https://api.zeparty.site/api';

  /// Initialize application environment and configure ApiClient
  static void initialize({
    AppEnvironment environment = AppEnvironment.development,
    String? customBaseUrl,
  }) {
    _environment = environment;

    if (customBaseUrl != null && customBaseUrl.isNotEmpty) {
      _apiBaseUrl = customBaseUrl;
    } else {
      // Determine default base URL based on compile-time environment or target
      const envOverride = String.fromEnvironment('API_BASE_URL');
      if (envOverride.isNotEmpty) {
        _apiBaseUrl = envOverride;
      } else {
        switch (environment) {
          case AppEnvironment.staging:
            _apiBaseUrl = stagingApiUrl;
            break;
          case AppEnvironment.production:
            _apiBaseUrl = defaultProdUrl;
            break;
          case AppEnvironment.development:
          default:
            if (kIsWeb) {
              _apiBaseUrl = devIosOrWebUrl;
            } else if (defaultTargetPlatform == TargetPlatform.android) {
              _apiBaseUrl = devAndroidEmulatorUrl;
            } else {
              _apiBaseUrl = devIosOrWebUrl;
            }
            break;
        }
      }
    }

    // Configure the authoritative ApiClient instance
    ApiClient.instance.initialize(baseUrl: _apiBaseUrl);
    debugPrint('[AppConfig] Initialized in ${_environment.name} mode with API Base: $_apiBaseUrl');
  }
}
