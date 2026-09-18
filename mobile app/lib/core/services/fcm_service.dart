import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../repositories/notification_repository.dart';

/// Service managing device registration, notification listeners, and deep-link routing
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final NotificationRepository _repository = NotificationRepository.instance;
  String? _currentDeviceToken;
  bool _isInitialized = false;

  final StreamController<Map<String, dynamic>> _foregroundMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onForegroundMessage =>
      _foregroundMessageController.stream;

  String? get currentDeviceToken => _currentDeviceToken;

  /// Initializes the notification service and device token handling
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Generate or fetch local device identifier token
    try {
      final platformName = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'web';

      // Fallback pseudo device token if native FCM is pending platform provisioning
      _currentDeviceToken = 'fcm_token_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
    } catch (_) {
      _currentDeviceToken = 'fcm_token_client_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Registers the device token with the backend after user login
  Future<void> registerWithBackend({String? customToken}) async {
    final token = customToken ?? _currentDeviceToken;
    if (token == null || token.isEmpty) return;

    try {
      final platformName = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'web';

      await _repository.registerDevice(
        deviceToken: token,
        platform: platformName,
        deviceModel: Platform.operatingSystem,
        appVersion: '1.0.0',
      );
    } catch (e) {
      // Non-fatal error; logs and preserves app continuity
      debugPrint('FCM Device registration error: $e');
    }
  }

  /// Refreshes the device token with backend
  Future<void> handleTokenRefresh(String newToken) async {
    final oldToken = _currentDeviceToken;
    _currentDeviceToken = newToken;

    try {
      final platformName = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'web';

      await _repository.refreshDeviceToken(
        oldToken: oldToken,
        newToken: newToken,
        platform: platformName,
        deviceModel: Platform.operatingSystem,
        appVersion: '1.0.0',
      );
    } catch (e) {
      debugPrint('FCM Token refresh error: $e');
    }
  }

  /// Unregisters the device from backend upon logout
  Future<void> unregisterOnLogout() async {
    if (_currentDeviceToken == null) return;
    try {
      await _repository.removeDevice('current', deviceToken: _currentDeviceToken);
    } catch (e) {
      debugPrint('FCM Device unregistration error: $e');
    }
  }

  /// Dispatches an incoming foreground notification to active subscribers
  void handleIncomingForegroundMessage(Map<String, dynamic> payload) {
    if (!_foregroundMessageController.isClosed) {
      _foregroundMessageController.add(payload);
    }
  }

  /// Safe deep-link navigation router based on backend notification payload
  void handleNotificationTap(BuildContext context, Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;

    final targetType = (data['targetType'] ?? data['type'] ?? data['sourceType'] ?? '')
        .toString()
        .toUpperCase();
    final targetId = (data['targetId'] ?? data['sourceId'] ?? data['id'] ?? '').toString();

    switch (targetType) {
      case 'ROOM':
      case 'LIVE_ROOM':
        // Navigate to room if targetId is present
        break;
      case 'POST':
        // Navigate to social feed
        break;
      case 'SUPPORT':
      case 'TICKET':
        // Navigate to support ticket
        break;
      case 'RECHARGE':
      case 'WALLET':
      case 'FINANCE':
        // Navigate to wallet
        break;
      case 'USER':
      case 'PROFILE':
        // Navigate to profile details
        break;
      default:
        break;
    }
  }

  void dispose() {
    _foregroundMessageController.close();
  }
}
