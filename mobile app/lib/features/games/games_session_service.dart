import 'package:flutter/foundation.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../../core/config/app_config.dart';
import '../../core/services/api_client.dart';
import '../../models/user_model.dart';

/// Token and endpoints for the premium games service, minted by the ZeParty
/// backend (`GET /v1/games/token`). The games service verifies the token with
/// the shared `GAMES_JWT_SECRET`; the app never signs anything itself.
class GamesSessionInfo {
  const GamesSessionInfo({
    required this.token,
    required this.expiresAt,
    required this.apiBaseUrl,
    required this.wsUrl,
  });

  final String token;
  final DateTime expiresAt;
  final String apiBaseUrl;
  final String wsUrl;

  /// Treat the token as stale two minutes before the server expiry so a
  /// socket opened now still authenticates.
  bool get isFresh => DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 2)));
}

class GamesSessionService {
  GamesSessionService._();
  static final GamesSessionService instance = GamesSessionService._();

  GamesSessionInfo? _cached;
  String? _cachedUserId;

  void clear() {
    _cached = null;
    _cachedUserId = null;
  }

  /// Returns a fresh games token for [user], reusing the cached one while valid.
  Future<GamesSessionInfo> fetch(UserModel user, {bool forceRefresh = false}) async {
    final cached = _cached;
    if (!forceRefresh && cached != null && _cachedUserId == user.id && cached.isFresh) {
      return cached;
    }

    final res = await ApiClient.instance.get('/v1/games/token');
    final body = res.data;
    final data = (body is Map && body['data'] is Map) ? Map<String, dynamic>.from(body['data'] as Map) : <String, dynamic>{};
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw ApiException(message: 'Games service token missing from response', code: 'GAMES_TOKEN_MISSING');
    }

    final expiresAtRaw = data['expiresAt']?.toString();
    final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 3600;
    final expiresAt = DateTime.tryParse(expiresAtRaw ?? '') ?? DateTime.now().add(Duration(seconds: expiresIn));

    final serverApi = data['apiBaseUrl']?.toString() ?? '';
    final serverWs = data['wsUrl']?.toString() ?? '';
    final apiBaseUrl = serverApi.isNotEmpty ? serverApi : AppConfig.gamesApiBaseUrl;
    final wsUrl = serverWs.isNotEmpty
        ? serverWs
        : (serverApi.isNotEmpty ? AppConfig.deriveGamesWsUrl(serverApi) : AppConfig.gamesWsUrl);

    final info = GamesSessionInfo(token: token, expiresAt: expiresAt, apiBaseUrl: apiBaseUrl, wsUrl: wsUrl);
    _cached = info;
    _cachedUserId = user.id;
    debugPrint('[GamesSession] token issued for ${user.id}, games API: $apiBaseUrl');
    return info;
  }

  /// Identity + token in the shape the game packages consume.
  ZePartySession toSession(UserModel user, GamesSessionInfo info) {
    final displayName = user.name.trim().isNotEmpty ? user.name.trim() : user.username;
    return ZePartySession(
      identity: ZePartyIdentity(
        userId: user.id,
        displayName: displayName.isNotEmpty ? displayName : user.id,
        avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
      ),
      authToken: info.token,
    );
  }
}
