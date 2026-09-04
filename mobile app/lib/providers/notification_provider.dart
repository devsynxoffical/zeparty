import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../core/constants/dummy_data.dart';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotificationModel> _notifications = List.from(DummyData.notifications);
  bool _isLoading = false;

  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> refreshNotifications() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    _isLoading = false;
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      final notif = _notifications[index];
      _notifications[index] = AppNotificationModel(
        id: notif.id,
        title: notif.title,
        message: notif.message,
        category: notif.category,
        timestamp: notif.timestamp,
        isRead: true,
      );
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      final notif = _notifications[i];
      if (!notif.isRead) {
        _notifications[i] = AppNotificationModel(
          id: notif.id,
          title: notif.title,
          message: notif.message,
          category: notif.category,
          timestamp: notif.timestamp,
          isRead: true,
        );
      }
    }
    notifyListeners();
  }

  void deleteNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String message,
    required String category,
  }) {
    _notifications.insert(
      0,
      AppNotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        category: category,
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );
    notifyListeners();
  }
}
