import 'package:flutter/material.dart';
import '../models/live_host_application_model.dart';
import '../models/live_host_model.dart';
import '../core/policy/live_host_policy.dart';

class LiveHostProvider extends ChangeNotifier {
  LiveHostModel? _activeLiveHost;
  final List<LiveHostApplicationModel> _applications = [];
  final List<Map<String, dynamic>> _auditLogs = [];

  LiveHostModel? get activeLiveHost => _activeLiveHost;
  List<LiveHostApplicationModel> get applications => List.unmodifiable(_applications);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  LiveHostProvider() {
    // Clean initial state for authentic live host data
  }

  LiveHostApplicationModel? getApplicationByUserId(String userId) {
    return _applications.where((a) => a.userId == userId).firstOrNull;
  }

  String submitApplication(LiveHostApplicationModel app) {
    // Duplicate protection check
    final existing = _applications.where((a) => a.userId == app.userId && a.status != 'Rejected').firstOrNull;
    if (existing != null) {
      return 'You already have an active application (${existing.status}).';
    }

    _applications.add(app);
    _logAudit(actorId: app.userId, action: 'SUBMIT_LIVE_HOST_APPLICATION', targetId: app.id, reason: 'New direct Live Host application submitted');
    notifyListeners();
    return 'Application submitted successfully! Our team will review within 24-48 hours.';
  }

  void approveApplication(String appId, String reviewerUserId) {
    final idx = _applications.indexWhere((a) => a.id == appId);
    if (idx != -1) {
      final app = _applications[idx];
      _applications[idx] = app.copyWith(status: 'Approved');

      _activeLiveHost = LiveHostModel(
        liveHostId: 'lh_${DateTime.now().millisecondsSinceEpoch}',
        userId: app.userId,
        displayName: app.displayName,
        avatarUrl: app.selfieUrl,
        countryCode: app.country,
        status: 'Active',
        approvalDate: DateTime.now(),
        currentLevel: 1,
      );

      _logAudit(actorId: reviewerUserId, action: 'APPROVE_LIVE_HOST', targetId: appId, reason: 'Identity & liveness verified');
      notifyListeners();
    }
  }

  void rejectApplication(String appId, String reason, String reviewerUserId) {
    final idx = _applications.indexWhere((a) => a.id == appId);
    if (idx != -1) {
      _applications[idx] = _applications[idx].copyWith(status: 'Rejected', rejectionReason: reason);
      _logAudit(actorId: reviewerUserId, action: 'REJECT_LIVE_HOST', targetId: appId, reason: reason);
      notifyListeners();
    }
  }

  // Record 1 Verified Hour Daily Streaming Time
  void addLiveStreamingMinutes(int minutes) {
    if (_activeLiveHost == null) return;

    final newMins = _activeLiveHost!.dailyLiveMinutes + minutes;
    final isNowValid = newMins >= LiveHostPolicy.requiredLiveHostDailyMinutes;

    int newValidDays = _activeLiveHost!.completedValidDays;
    if (!_activeLiveHost!.isTodayValid && isNowValid) {
      newValidDays += 1;
    }

    _activeLiveHost = _activeLiveHost!.copyWith(
      dailyLiveMinutes: newMins,
      isTodayValid: isNowValid,
      completedValidDays: newValidDays,
    );

    notifyListeners();
  }

  // Direct Live Host Platform Salary Withdrawal
  String? requestWithdrawal({
    required double amount,
    required String channel,
    required String pin,
    required String actorUserId,
  }) {
    if (_activeLiveHost == null) return 'No Live Host profile found.';
    if (amount <= 0) return 'Invalid amount.';
    if (_activeLiveHost!.availableSalaryUsd < amount) return 'Insufficient Available Salary.';
    if (pin != '1234' && pin != '0000') return 'Incorrect Security PIN.';

    _activeLiveHost = _activeLiveHost!.copyWith(
      availableSalaryUsd: _activeLiveHost!.availableSalaryUsd - amount,
    );

    _logAudit(
      actorId: actorUserId,
      action: 'DIRECT_LIVE_HOST_WITHDRAWAL',
      targetId: _activeLiveHost!.liveHostId,
      reason: 'Direct platform salary withdrawal to $channel',
      newValue: '-\$${amount.toStringAsFixed(2)}',
    );

    notifyListeners();
    return null;
  }

  void _logAudit({
    required String actorId,
    required String action,
    required String targetId,
    required String reason,
    String? newValue,
  }) {
    _auditLogs.add({
      'actorId': actorId,
      'action': action,
      'targetId': targetId,
      'reason': reason,
      'newValue': newValue ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
