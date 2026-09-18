import 'dart:async';
import 'package:flutter/material.dart';
import '../core/repositories/notification_repository.dart';
import '../core/services/socket_service.dart';
import '../models/notification_model.dart';
import '../models/notification_preferences_model.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository = NotificationRepository.instance;
  final SocketService _socketService = SocketService.instance;

  List<AppNotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _errorMessage;

  NotificationPreferencesModel _preferences = const NotificationPreferencesModel();
  bool _isPrefsLoading = false;

  StreamSubscription<Map<String, dynamic>>? _notifNewSub;
  StreamSubscription<Map<String, dynamic>>? _notifReadSub;
  StreamSubscription<Map<String, dynamic>>? _notifReadAllSub;
  StreamSubscription<Map<String, dynamic>>? _notifBroadcastSub;

  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  NotificationPreferencesModel get preferences => _preferences;
  bool get isPrefsLoading => _isPrefsLoading;

  NotificationProvider() {
    _initSocketListeners();
    loadNotifications();
  }

  void _initSocketListeners() {
    _notifNewSub = _socketService.onNotificationNew.listen((data) {
      final notif = AppNotificationModel.fromJson(data);
      final exists = _notifications.any((n) => n.id == notif.id);
      if (!exists) {
        _notifications.insert(0, notif);
        _unreadCount++;
        notifyListeners();
      }
    });

    _notifReadSub = _socketService.onNotificationRead.listen((data) {
      final notifId = data['notificationId']?.toString() ?? data['id']?.toString();
      if (notifId == null) return;

      final idx = _notifications.indexWhere((n) => n.id == notifId);
      if (idx != -1 && !_notifications[idx].isRead) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    });

    _notifReadAllSub = _socketService.onNotificationReadAll.listen((_) {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    });

    _notifBroadcastSub = _socketService.onNotificationBroadcast.listen((data) {
      final notif = AppNotificationModel.fromJson(data);
      _notifications.insert(0, notif);
      _unreadCount++;
      notifyListeners();
    });
  }

  /// Loads the first page of notifications from backend
  Future<void> loadNotifications({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final countFuture = _repository.getUnreadCount();
      final feedFuture = _repository.getNotifications(limit: 20);

      final results = await Future.wait([countFuture, feedFuture]);
      _unreadCount = results[0] as int;

      final feedData = results[1] as Map<String, dynamic>;
      _notifications = (feedData['items'] as List<AppNotificationModel>?) ?? [];

      final pageInfo = feedData['pageInfo'] as Map<String, dynamic>? ?? {};
      _hasMore = pageInfo['hasNextPage'] as bool? ?? false;
      _nextCursor = pageInfo['nextCursor'] as String?;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Pull-to-refresh
  Future<void> refreshNotifications() async {
    await loadNotifications(refresh: true);
  }

  /// Loads more notifications using cursor pagination
  Future<void> loadMoreNotifications() async {
    if (_isLoading || !_hasMore || _nextCursor == null) return;

    try {
      final feedData = await _repository.getNotifications(
        cursor: _nextCursor,
        limit: 20,
      );

      final moreItems = (feedData['items'] as List<AppNotificationModel>?) ?? [];
      _notifications.addAll(moreItems);

      final pageInfo = feedData['pageInfo'] as Map<String, dynamic>? ?? {};
      _hasMore = pageInfo['hasNextPage'] as bool? ?? false;
      _nextCursor = pageInfo['nextCursor'] as String?;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading more notifications: $e');
    }
  }

  /// Marks a specific notification as read
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;

    // Optimistic
    final previous = _notifications[index];
    _notifications[index] = previous.copyWith(isRead: true, readAt: DateTime.now());
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      await _repository.markAsRead(id);
    } catch (e) {
      // Revert if failed
      _notifications[index] = previous;
      _unreadCount++;
      notifyListeners();
    }
  }

  /// Marks all unread notifications as read
  Future<void> markAllAsRead() async {
    if (_unreadCount == 0 && _notifications.every((n) => n.isRead)) return;

    // Optimistic
    final backup = List<AppNotificationModel>.from(_notifications);
    final backupCount = _unreadCount;

    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await _repository.markAllAsRead();
    } catch (e) {
      _notifications = backup;
      _unreadCount = backupCount;
      notifyListeners();
    }
  }

  /// Deletes a single notification
  Future<void> deleteNotification(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;

    final removed = _notifications[index];
    _notifications.removeAt(index);
    if (!removed.isRead && _unreadCount > 0) {
      _unreadCount--;
    }
    notifyListeners();

    try {
      await _repository.deleteNotification(id);
    } catch (e) {
      _notifications.insert(index, removed);
      if (!removed.isRead) _unreadCount++;
      notifyListeners();
    }
  }

  /// Loads notification preferences from backend
  Future<void> loadPreferences() async {
    _isPrefsLoading = true;
    notifyListeners();

    try {
      _preferences = await _repository.getPreferences();
      _isPrefsLoading = false;
      notifyListeners();
    } catch (e) {
      _isPrefsLoading = false;
      notifyListeners();
    }
  }

  /// Updates notification preferences on backend
  Future<void> updatePreferences(Map<String, dynamic> changedPrefs) async {
    try {
      _preferences = await _repository.updatePreferences(changedPrefs);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  @override
  void dispose() {
    _notifNewSub?.cancel();
    _notifReadSub?.cancel();
    _notifReadAllSub?.cancel();
    _notifBroadcastSub?.cancel();
    super.dispose();
  }
}
