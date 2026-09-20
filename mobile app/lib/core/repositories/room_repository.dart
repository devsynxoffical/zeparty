import '../services/api_client.dart';
import '../../models/live_room_model.dart';

class RoomRepository {
  static final RoomRepository instance = RoomRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  RoomRepository._internal();

  /// Create a new live party / streaming room on backend
  Future<LiveRoomModel> createRoom({
    required String title,
    String? coverImageUrl,
    String roomType = 'AUDIO_PARTY',
    String category = 'CHAT',
    bool isPrivate = false,
    String? roomPin,
  }) async {
    String normType = 'LIVE_VIDEO';
    final uType = roomType.toUpperCase().trim();
    if (uType.contains('AUDIO') || uType.contains('PARTY')) {
      normType = 'AUDIO_PARTY';
    }

    String normCat = 'CHAT';
    final uCat = category.toUpperCase().trim();
    if (uCat.contains('MUSIC')) {
      normCat = 'MUSIC';
    } else if (uCat.contains('GAME') || uCat.contains('GAMING')) {
      normCat = 'GAMING';
    }

    final response = await _apiClient.post(
      '/v1/rooms',
      data: {
        'title': title,
        'coverImageUrl': coverImageUrl ?? '',
        'roomType': normType,
        'category': normCat,
        'isPrivate': isPrivate,
        if (roomPin != null && roomPin.isNotEmpty) 'roomPin': roomPin,
      },
    );

    final data = response.data?['data'] as Map<String, dynamic>;
    return LiveRoomModel.fromJson(data);
  }

  /// Get active live rooms with discovery filtering
  Future<List<LiveRoomModel>> getActiveRooms({
    int page = 1,
    int limit = 20,
    String? category,
    String? roomType,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (category != null && category.isNotEmpty && category != 'All') {
      queryParams['category'] = category;
    }
    if (roomType != null && roomType.isNotEmpty) {
      queryParams['roomType'] = roomType;
    }

    final response = await _apiClient.get(
      '/v1/rooms/active',
      queryParameters: queryParams,
    );

    final roomsList = response.data?['data'] as List? ?? [];
    return roomsList
        .map((r) => LiveRoomModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Get full room details including current 8-seat state and participants
  Future<LiveRoomModel> getRoomDetails(String roomId) async {
    final response = await _apiClient.get('/v1/rooms/$roomId');
    final data = response.data?['data'] as Map<String, dynamic>;
    return LiveRoomModel.fromJson(data);
  }

  /// Join a room as viewer / audience
  Future<Map<String, dynamic>> joinRoom(String roomId, {String? password}) async {
    final response = await _apiClient.post(
      '/v1/rooms/$roomId/join',
      data: password != null && password.isNotEmpty ? {'password': password, 'pin': password} : null,
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Leave a room cleanly on backend
  Future<void> leaveRoom(String roomId) async {
    try {
      await _apiClient.post('/v1/rooms/$roomId/leave');
    } catch (_) {
      // Best-effort departure
    }
  }

  /// Terminate and close a live room (Host only)
  Future<void> closeRoom(String roomId) async {
    await _apiClient.post('/v1/rooms/$roomId/close');
  }

  /// Occupy a specific mic seat index (0..7)
  Future<Map<String, dynamic>> occupySeat(String roomId, int seatIndex) async {
    final response = await _apiClient.post('/v1/rooms/$roomId/seats/$seatIndex/occupy');
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Release/leave a mic seat index (0..7)
  Future<void> leaveSeat(String roomId, int seatIndex) async {
    await _apiClient.post('/v1/rooms/$roomId/seats/$seatIndex/leave');
  }

  /// Fetch Agora RTC token generated for the user's current room role
  Future<Map<String, dynamic>> getAgoraToken(String roomId) async {
    final response = await _apiClient.post('/v1/rooms/$roomId/agora-token');
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Refresh an existing Agora RTC token
  Future<Map<String, dynamic>> refreshAgoraToken(String roomId) async {
    final response = await _apiClient.post('/v1/rooms/$roomId/agora-token/refresh');
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }
}
