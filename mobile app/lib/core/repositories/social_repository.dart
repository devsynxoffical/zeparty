import '../services/api_client.dart';

/// Social & Post Repository
/// All calls are against the real ZeParty backend.
/// Never falls back to local/mock data on network errors — errors propagate.
class SocialRepository {
  static final SocialRepository instance = SocialRepository._internal();
  SocialRepository._internal();

  final ApiClient _client = ApiClient.instance;

  // ─── Feed ─────────────────────────────────────────────────────────────────

  /// GET /v1/feed
  Future<Map<String, dynamic>> fetchFeed({
    String feedType = 'PUBLIC',
    int page = 1,
    int limit = 20,
    String? cursor,
    String? authorUserId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/feed',
      queryParameters: {
        'feedType': feedType,
        'page': page,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (authorUserId != null) 'authorUserId': authorUserId,
      },
    );
    return response.data!;
  }

  // ─── Posts ────────────────────────────────────────────────────────────────

  /// POST /v1/posts
  Future<Map<String, dynamic>> createPost({
    required String content,
    List<String>? mediaUrls,
    String visibility = 'PUBLIC',
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/posts',
      data: {
        'content': content,
        'visibility': visibility,
        if (mediaUrls != null && mediaUrls.isNotEmpty) 'mediaUrls': mediaUrls,
      },
    );
    return response.data!;
  }

  /// GET /v1/posts/:id
  Future<Map<String, dynamic>> getPostById(String postId) async {
    final response = await _client.get<Map<String, dynamic>>('/v1/posts/$postId');
    return response.data!;
  }

  /// DELETE /v1/posts/:id
  Future<void> deletePost(String postId) async {
    await _client.delete<Map<String, dynamic>>('/v1/posts/$postId');
  }

  // ─── Likes ────────────────────────────────────────────────────────────────

  /// POST /v1/posts/:id/like
  Future<Map<String, dynamic>> likePost(String postId) async {
    final response = await _client.post<Map<String, dynamic>>('/v1/posts/$postId/like');
    return response.data!;
  }

  /// DELETE /v1/posts/:id/like
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    final response = await _client.delete<Map<String, dynamic>>('/v1/posts/$postId/like');
    return response.data!;
  }

  // ─── Comments ─────────────────────────────────────────────────────────────

  /// GET /v1/posts/:id/comments
  Future<Map<String, dynamic>> fetchComments(
    String postId, {
    int page = 1,
    int limit = 20,
    String? parentId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/posts/$postId/comments',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (parentId != null) 'parentId': parentId,
      },
    );
    return response.data!;
  }

  /// POST /v1/posts/:id/comments
  Future<Map<String, dynamic>> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/posts/$postId/comments',
      data: {
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
    return response.data!;
  }

  /// DELETE /v1/posts/comments/:id
  Future<void> deleteComment(String commentId) async {
    await _client.delete<Map<String, dynamic>>('/v1/posts/comments/$commentId');
  }

  // ─── Social Profile ───────────────────────────────────────────────────────

  /// GET /v1/users/:id/social-profile
  Future<Map<String, dynamic>> getSocialProfile(String userId) async {
    final response = await _client.get<Map<String, dynamic>>('/v1/users/$userId/social-profile');
    return response.data!;
  }

  // ─── Follow / Unfollow ────────────────────────────────────────────────────

  /// POST /v1/users/:id/follow
  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await _client.post<Map<String, dynamic>>('/v1/users/$userId/follow');
    return response.data!;
  }

  /// DELETE /v1/users/:id/follow
  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final response = await _client.delete<Map<String, dynamic>>('/v1/users/$userId/follow');
    return response.data!;
  }

  /// GET /v1/users/:id/followers
  Future<Map<String, dynamic>> fetchFollowers(String userId, {int page = 1, int limit = 20}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/users/$userId/followers',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data!;
  }

  /// GET /v1/users/:id/following
  Future<Map<String, dynamic>> fetchFollowing(String userId, {int page = 1, int limit = 20}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/users/$userId/following',
      queryParameters: {'page': page, 'limit': limit},
    );
    return response.data!;
  }

  // ─── Block / Unblock ──────────────────────────────────────────────────────

  /// POST /v1/users/:id/block
  Future<void> blockUser(String userId) async {
    await _client.post<Map<String, dynamic>>('/v1/users/$userId/block');
  }

  /// DELETE /v1/users/:id/block
  Future<void> unblockUser(String userId) async {
    await _client.delete<Map<String, dynamic>>('/v1/users/$userId/block');
  }

  // ─── Privacy ──────────────────────────────────────────────────────────────

  /// PUT /v1/users/me/privacy
  Future<void> updatePrivacy(bool isPrivate) async {
    await _client.put<Map<String, dynamic>>(
      '/v1/users/me/privacy',
      data: {'isPrivate': isPrivate},
    );
  }

  // ─── Reporting ────────────────────────────────────────────────────────────

  /// POST /v1/posts/:id/report
  Future<void> reportContent({
    required String postId,
    required String violationType,
    String? description,
  }) async {
    await _client.post<Map<String, dynamic>>(
      '/v1/posts/$postId/report',
      data: {
        'violationType': violationType,
        if (description != null) 'description': description,
      },
    );
  }

  // ─── User Profile & Search ───────────────────────────────────────────────────

  /// GET /v1/users/:id
  Future<Map<String, dynamic>> getUserById(String userId) async {
    final response = await _client.get<Map<String, dynamic>>('/v1/users/$userId');
    return response.data!;
  }

  /// GET /v1/users/search
  Future<List<dynamic>> searchUsers(String query, {int limit = 20}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/users/search',
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );
    return response.data?['data'] as List<dynamic>? ?? [];
  }

  // ─── Direct Messaging ─────────────────────────────────────────────────────

  /// GET /v1/messages/conversations
  Future<List<dynamic>> fetchConversations() async {
    final response = await _client.get<Map<String, dynamic>>('/v1/messages/conversations');
    return response.data?['data'] as List<dynamic>? ?? [];
  }

  /// GET /v1/messages/:targetUserId
  Future<Map<String, dynamic>> fetchMessages(
    String targetUserId, {
    int page = 1,
    int limit = 50,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/v1/messages/$targetUserId',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    return response.data!;
  }

  /// POST /v1/messages/:targetUserId
  Future<Map<String, dynamic>> sendMessage(
    String targetUserId, {
    required String content,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/v1/messages/$targetUserId',
      data: {
        'content': content,
      },
    );
    return response.data!;
  }

  /// PATCH /v1/messages/:targetUserId/read
  Future<void> markMessagesAsRead(String targetUserId) async {
    await _client.patch<Map<String, dynamic>>('/v1/messages/$targetUserId/read');
  }
}
