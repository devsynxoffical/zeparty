import '../services/api_client.dart';
import '../../models/pk_battle_model.dart';
import '../../models/user_model.dart';

class PKRepository {
  static final PKRepository instance = PKRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  PKRepository._internal();

  /// Create a new host-controlled PK Session
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

  /// Invite an active live host or a user to the PK Session
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

  /// Get invitation details by invitation ID
  Future<Map<String, dynamic>> getInvitationDetails(String inviteId) async {
    final response = await _apiClient.get('/v1/pk/invite/$inviteId');
    return (response.data?['data'] as Map<String, dynamic>?) ?? {};
  }

  /// Respond to a PK invitation (accept / decline)
  Future<PKBattleModel> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final response = await _apiClient.post(
      '/v1/pk/invite/$inviteId/respond',
      data: {'accept': accept},
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Join PK Session by invite code / deep-link code
  Future<PKBattleModel> joinByInviteCode(String inviteCode) async {
    final response = await _apiClient.post(
      '/v1/pk/join-by-code',
      data: {'inviteCode': inviteCode.trim()},
    );
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Explicitly start the PK battle (transitions from READY -> STARTED, stamps startedAt)
  Future<PKBattleModel> startPKBattle(String pkId) async {
    final response = await _apiClient.post('/v1/pk/$pkId/start');
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Explicitly end the PK battle
  Future<PKBattleModel> endPKBattle(String pkId) async {
    final response = await _apiClient.post('/v1/pk/$pkId/end');
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Get current authoritative PK session state
  Future<PKBattleModel> getPKSession(String pkId) async {
    final response = await _apiClient.get('/v1/pk/$pkId');
    final data = response.data?['data'] as Map<String, dynamic>;
    return PKBattleModel.fromJson(data);
  }

  /// Fetch currently active live hosts available for Host vs Host PK
  Future<List<UserModel>> getAvailableLiveHosts() async {
    final response = await _apiClient.get('/v1/pk/available-hosts');
    final data = response.data?['data'];
    if (data is List) {
      return data.map((json) => UserModel.fromJson(json as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
