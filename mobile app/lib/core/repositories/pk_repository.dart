import '../services/api_client.dart';
import '../../models/pk_battle_model.dart';
import '../../models/user_model.dart';

class PKRepository {
  static final PKRepository instance = PKRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  PKRepository._internal();

  // ── CANONICAL PK 2.0 API METHODS ─────────────────────────────────────────

  /// 1. Discover opponent by room ID or host ID
  /// GET /v1/pk/discover?query=...&roomType=...
  Future<PKDiscoveryResult?> discoverOpponent({
    required String query,
    required String roomType,
  }) async {
    try {
      final response = await _apiClient.get(
        '/v1/pk/discover',
        queryParameters: {
          'query': query.trim(),
          'roomType': roomType.toUpperCase(),
        },
      );
      final data = response.data?['data'];
      if (data is Map<String, dynamic>) {
        return PKDiscoveryResult.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 2. Send 1v1 PK Match invitation
  /// POST /v1/pk/invitations
  Future<Map<String, dynamic>> sendInvitation({
    required String fromRoomId,
    required String targetRoomId,
    required String targetHostUserId,
    int durationSeconds = 300,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/invitations',
      data: {
        'fromRoomId': fromRoomId,
        'targetRoomId': targetRoomId,
        'targetHostUserId': targetHostUserId,
        'durationSeconds': durationSeconds,
      },
    );
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// 3. Respond to invitation (ACCEPT or REJECT)
  /// POST /v1/pk/invitations/:id/respond
  Future<Map<String, dynamic>> respondInvitation({
    required String invitationId,
    required String action, // 'ACCEPT' or 'REJECT'
    String? targetRoomId,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/invitations/$invitationId/respond',
      data: {
        'action': action.toUpperCase(),
        if (targetRoomId != null) 'targetRoomId': targetRoomId,
      },
    );
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// 4. Cancel sent invitation
  /// POST /v1/pk/invitations/:id/cancel
  Future<Map<String, dynamic>> cancelInvitation(String invitationId) async {
    final response = await _apiClient.post('/v1/pk/invitations/$invitationId/cancel');
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// 5. Confirm operator readiness and media preparation
  /// POST /v1/pk/matches/:id/ready
  Future<Map<String, dynamic>> setOperatorReady({
    required String matchId,
    bool mediaPrepared = true,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/matches/$matchId/ready',
      data: {'mediaPrepared': mediaPrepared},
    );
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// 6. Get authoritative match snapshot
  /// GET /v1/pk/matches/:id
  Future<PKBattleModel?> getMatchSnapshot(String matchId) async {
    try {
      final response = await _apiClient.get('/v1/pk/matches/$matchId');
      final data = response.data?['data'];
      if (data is Map<String, dynamic>) {
        return PKBattleModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 7. Get active match for room (reconnect & recovery)
  /// GET /v1/pk/rooms/:roomId/active
  Future<PKBattleModel?> getActiveMatchForRoom(String roomId) async {
    try {
      final response = await _apiClient.get('/v1/pk/rooms/$roomId/active');
      final data = response.data?['data'];
      if (data is Map<String, dynamic>) {
        return PKBattleModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 8. Get top 3 supporters for both sides
  /// GET /v1/pk/matches/:id/supporters
  Future<Map<String, List<PKSupporterModel>>> getTopSupporters(String matchId) async {
    try {
      final response = await _apiClient.get('/v1/pk/matches/$matchId/supporters');
      final data = response.data?['data'] as Map<String, dynamic>? ?? {};
      final listA = (data['sideASupporters'] as List? ?? [])
          .map((item) => PKSupporterModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      final listB = (data['sideBSupporters'] as List? ?? [])
          .map((item) => PKSupporterModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      return {'sideA': listA, 'sideB': listB};
    } catch (_) {
      return {'sideA': [], 'sideB': []};
    }
  }

  /// 9. Request rematch after match completion
  /// POST /v1/pk/matches/:id/rematch
  Future<Map<String, dynamic>> requestRematch(String matchId) async {
    final response = await _apiClient.post('/v1/pk/matches/$matchId/rematch');
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// 10. Get match history
  /// GET /v1/pk/history
  Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 20}) async {
    final response = await _apiClient.get(
      '/v1/pk/history',
      queryParameters: {'page': page, 'limit': limit},
    );
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  // ── BACKWARD-COMPATIBLE / LEGACY METHODS ───────────────────────────────────

  /// Legacy: Create a new host-controlled PK Session
  Future<PKBattleModel> createPKSession({
    required String roomId,
    int durationSeconds = 300,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/create',
      data: {
        'roomId': roomId,
        'durationSeconds': durationSeconds,
      },
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Legacy: Invite an active live host or a user to the PK Session
  Future<Map<String, dynamic>> sendPKInvite({
    required String pkId,
    required String targetUserId,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/invite',
      data: {
        'pkId': pkId,
        'targetUserId': targetUserId,
      },
    );
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Legacy: Get invitation details by invitation ID
  Future<Map<String, dynamic>> getInvitationDetails(String inviteId) async {
    final response = await _apiClient.get('/v1/pk/invite/$inviteId');
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Legacy: Respond to a PK invitation (accept / decline)
  Future<PKBattleModel> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/invitations/$inviteId/respond',
      data: {'action': accept ? 'ACCEPT' : 'REJECT'},
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Legacy: Join PK Session by invite code / deep-link code
  Future<PKBattleModel> joinByInviteCode(String inviteCode) async {
    final response = await _apiClient.post(
      '/v1/pk/join-by-code',
      data: {'inviteCode': inviteCode.trim()},
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Legacy: Explicitly start the PK battle
  Future<PKBattleModel> startPKBattle(String pkId) async {
    final response = await _apiClient.post('/v1/pk/$pkId/start');
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Legacy: Explicitly end the PK battle
  Future<PKBattleModel> endPKBattle(String pkId) async {
    final response = await _apiClient.post('/v1/pk/$pkId/end');
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Legacy: Get current authoritative PK session state
  Future<PKBattleModel> getPKSession(String pkId) async {
    final response = await _apiClient.get('/v1/pk/$pkId');
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Legacy: Fetch currently active live hosts available for Host vs Host PK
  Future<List<UserModel>> getAvailableLiveHosts() async {
    final response = await _apiClient.get('/v1/pk/available-hosts');
    final data = response.data?['data'];
    if (data is List) {
      return data.map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
