import '../services/api_client.dart';
import '../../models/notification_model.dart';
import '../../models/notification_preferences_model.dart';

/// Repository for device registration, notification history, unread markers, and preferences
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final ApiClient _client = ApiClient.instance;

  // ─── Device Token Registration ─────────────────────────────────────────────

  /// POST /v1/notifications/devices
  /// Registers an active FCM device token for push delivery
  Future<Map<String, dynamic>> registerDevice({
    required String deviceToken,
    String platform = 'android',
    String? deviceModel,
    String? appVersion,
    String? macAddress,
  }) async {
    final payload = <String, dynamic>{
      'deviceToken': deviceToken,
      'platform': platform.toLowerCase(),
    };
    if (deviceModel != null && deviceModel.isNotEmpty) {
      payload['deviceModel'] = deviceModel;
    }
    if (appVersion != null && appVersion.isNotEmpty) {
      payload['appVersion'] = appVersion;
    }
    if (macAddress != null && macAddress.isNotEmpty) {
      payload['macAddress'] = macAddress;
    }

    final response = await _client.post(
      '/v1/notifications/devices',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// POST /v1/notifications/devices/refresh
  /// Refreshes an expired or updated FCM device token
  Future<Map<String, dynamic>> refreshDeviceToken({
    String? oldToken,
    required String newToken,
    String platform = 'android',
    String? deviceModel,
    String? appVersion,
  }) async {
    final payload = <String, dynamic>{
      'newToken': newToken,
      'platform': platform.toLowerCase(),
    };
    if (oldToken != null && oldToken.isNotEmpty) {
      payload['oldToken'] = oldToken;
    }
    if (deviceModel != null && deviceModel.isNotEmpty) {
      payload['deviceModel'] = deviceModel;
    }
    if (appVersion != null && appVersion.isNotEmpty) {
      payload['appVersion'] = appVersion;
    }

    final response = await _client.post(
      '/v1/notifications/devices/refresh',
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }

  /// DELETE /v1/notifications/devices/:id
  /// Unregisters a device token upon logout
  Future<void> removeDevice(String deviceId, {String? deviceToken}) async {
    final payload = <String, dynamic>{};
    if (deviceToken != null && deviceToken.isNotEmpty) {
      payload['deviceToken'] = deviceToken;
    }
    await _client.delete(
      '/v1/notifications/devices/$deviceId',
      data: payload.isNotEmpty ? payload : null,
    );
  }

  // ─── Notification History & Read State ─────────────────────────────────────

  /// GET /v1/notifications
  /// Retrieves cursor-paginated notification history
  Future<Map<String, dynamic>> getNotifications({
    String? cursor,
    int limit = 20,
    String? type,
    String? category,
    bool unreadOnly = false,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'unreadOnly': unreadOnly,
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    if (type != null && type.isNotEmpty) {
      queryParams['type'] = type;
    }
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }

    final response = await _client.get(
      '/v1/notifications',
      queryParameters: queryParams,
    );

    final rawData = response.data['data'] as Map<String, dynamic>? ?? {};
    final itemsList = rawData['items'] as List<dynamic>? ?? [];
    final items = itemsList
        .map((n) => AppNotificationModel.fromJson(n as Map<String, dynamic>))
        .toList();

    return {
      'items': items,
      'pageInfo': rawData['pageInfo'] as Map<String, dynamic>? ?? {},
    };
  }

  /// GET /v1/notifications/unread-count
  /// Retrieves server-authoritative unread count
  Future<int> getUnreadCount() async {
    final response = await _client.get('/v1/notifications/unread-count');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    return data['unreadCount'] as int? ?? 0;
  }

  /// PATCH /v1/notifications/:id/read
  /// Marks an individual notification as read
  Future<AppNotificationModel> markAsRead(String id) async {
    final response = await _client.patch('/v1/notifications/$id/read');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final notifData = data['notification'] as Map<String, dynamic>? ?? {};
    return AppNotificationModel.fromJson(notifData);
  }

  /// PATCH /v1/notifications/read-all
  /// Marks all unread notifications as read
  Future<Map<String, dynamic>> markAllAsRead() async {
    final response = await _client.patch('/v1/notifications/read-all');
    return response.data as Map<String, dynamic>;
  }

  /// DELETE /v1/notifications/:id
  /// Deletes a notification
  Future<void> deleteNotification(String id) async {
    await _client.delete('/v1/notifications/$id');
  }

  // ─── Notification Preferences ──────────────────────────────────────────────

  /// GET /v1/notifications/preferences
  /// Retrieves user notification preferences
  Future<NotificationPreferencesModel> getPreferences() async {
    final response = await _client.get('/v1/notifications/preferences');
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final prefs = data['preferences'] as Map<String, dynamic>? ?? {};
    return NotificationPreferencesModel.fromJson(prefs);
  }

  /// PUT /v1/notifications/preferences
  /// Updates user notification preferences
  Future<NotificationPreferencesModel> updatePreferences(Map<String, dynamic> prefs) async {
    final response = await _client.put(
      '/v1/notifications/preferences',
      data: prefs,
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final updated = data['preferences'] as Map<String, dynamic>? ?? {};
    return NotificationPreferencesModel.fromJson(updated);
  }
}
