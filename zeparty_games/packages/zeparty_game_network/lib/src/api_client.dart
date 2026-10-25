import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zeparty_game_core/zeparty_game_core.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// Typed REST client. Every call sends the host-issued bearer token.
class ZePartyApiClient {
  ZePartyApiClient({required this.baseUrl, required this.authToken, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  String authToken;
  final http.Client _client;

  Map<String, String> get _headers => {'authorization': 'Bearer $authToken', 'content-type': 'application/json'};

  Future<Map<String, dynamic>> _req(String method, String path, {Map<String, dynamic>? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _client.send(req)).timeout(const Duration(seconds: 15));
    final decoded = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, decoded['error'] as String? ?? 'http_${res.statusCode}', decoded['message'] as String? ?? res.reasonPhrase ?? '');
    }
    return decoded;
  }

  /// Development only: obtain a token from the mock auth adapter.
  static Future<ZePartySession> devLogin(String baseUrl, {required String userId, required String displayName, String? avatarUrl}) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/dev-login'), headers: {'content-type': 'application/json'}, body: jsonEncode({'userId': userId, 'displayName': displayName, 'avatarUrl': avatarUrl}));
    if (res.statusCode != 200) throw ApiException(res.statusCode, 'dev_login_failed', res.body);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return ZePartySession(identity: ZePartyIdentity.fromJson(j['identity'] as Map<String, dynamic>), authToken: j['token'] as String);
  }

  Future<ZePartyIdentity> me() async => ZePartyIdentity.fromJson(await _req('GET', '/me'));

  Future<({List<GameCatalogEntry> games, int onlineUsers})> games() async {
    final j = await _req('GET', '/games');
    return (games: (j['games'] as List<dynamic>).map((g) => GameCatalogEntry.fromJson(g as Map<String, dynamic>)).toList(), onlineUsers: j['onlineUsers'] as int? ?? 0);
  }

  Future<List<RoomSummary>> rooms({String? gameId}) async {
    final j = await _req('GET', '/rooms', query: gameId == null ? null : {'gameId': gameId});
    return (j['rooms'] as List<dynamic>).map((r) => RoomSummary.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> wallet() => _req('GET', '/wallet');
  Future<List<Map<String, dynamic>>> walletTransactions({int limit = 50, String? before}) async {
    final j = await _req('GET', '/wallet/transactions', query: {'limit': '$limit', 'before': ?before});
    return (j['transactions'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> claimDaily() => _req('POST', '/wallet/daily-claim', body: {});

  Future<List<Map<String, dynamic>>> cosmetics({String? gameId}) async {
    final j = await _req('GET', '/cosmetics', query: gameId == null ? null : {'gameId': gameId});
    return (j['cosmetics'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<({List<Map<String, dynamic>> items, Map<String, String> equipped})> inventory({String? gameId}) async {
    final j = await _req('GET', '/inventory', query: gameId == null ? null : {'gameId': gameId});
    return (items: (j['items'] as List<dynamic>).cast<Map<String, dynamic>>(), equipped: ((j['equipped'] as Map<String, dynamic>?) ?? const {}).map((k, v) => MapEntry(k, v as String)));
  }

  Future<Map<String, dynamic>> purchase(String cosmeticId, String idempotencyKey) => _req('POST', '/inventory/purchase', body: {'cosmeticId': cosmeticId, 'idempotencyKey': idempotencyKey});
  Future<void> equip(String cosmeticId) => _req('POST', '/inventory/equip', body: {'cosmeticId': cosmeticId});

  Future<List<Map<String, dynamic>>> achievements() async => ((await _req('GET', '/achievements'))['achievements'] as List<dynamic>).cast<Map<String, dynamic>>();
  Future<Map<String, dynamic>> claimAchievement(String id) => _req('POST', '/achievements/$id/claim', body: {});
  Future<void> tutorialComplete() => _req('POST', '/achievements/tutorial-complete', body: {});

  Future<Map<String, dynamic>> leaderboard(String gameId, {bool weekly = false}) => _req('GET', '/leaderboards/$gameId', query: weekly ? {'period': 'weekly'} : null);
  Future<List<Map<String, dynamic>>> matchHistory({int limit = 30}) async => ((await _req('GET', '/matches/history', query: {'limit': '$limit'}))['matches'] as List<dynamic>).cast<Map<String, dynamic>>();

  void close() => _client.close();
}
