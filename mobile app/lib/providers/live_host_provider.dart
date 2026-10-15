import 'package:flutter/material.dart';
import '../models/live_host_application_model.dart';
import '../models/live_host_model.dart';
import '../core/policy/live_host_policy.dart';
import '../core/services/api_client.dart';

class LiveHostProvider extends ChangeNotifier {
  LiveHostModel? _activeLiveHost;
  final List<LiveHostApplicationModel> _applications = [];
  final List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = false;

  LiveHostModel? get activeLiveHost => _activeLiveHost;
  List<LiveHostApplicationModel> get applications => List.unmodifiable(_applications);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);
  bool get isLoading => _isLoading;

  LiveHostProvider() {
    // Clean initial state for authentic live host data
  }

  LiveHostApplicationModel? getApplicationByUserId(String userId) {
    return _applications.where((a) => a.userId == userId).firstOrNull;
  }

  Future<void> fetchHostProfile(String userId) async {
    try {
      final res = await ApiClient.instance.get('/v1/hosts/profile');
      if (res.statusCode == 200 && res.data['data'] != null) {
        final data = res.data['data'];
        final rawStatus = (data['hostStatus'] ?? data['status'])?.toString().toUpperCase();
        if (rawStatus == 'ACTIVE' || rawStatus == 'APPROVED') {
          final liveMins = (data['dailyLiveMinutes'] ?? data['verifiedMinutesToday'] ?? data['streamingMinutes'] ?? 0) as int;
          final isTodayValid = liveMins >= LiveHostPolicy.requiredLiveHostDailyMinutes;
          final validDays = (data['completedValidDays'] ?? data['validDays'] ?? (isTodayValid ? 1 : 0)) as int;
          _activeLiveHost = LiveHostModel(
            liveHostId: data['id'] ?? 'lh_$userId',
            userId: userId,
            displayName: data['user']?['profile']?['displayName'] ?? data['user']?['username'] ?? 'Live Host',
            avatarUrl: data['user']?['avatarUrl'] ?? '',
            countryCode: data['user']?['countryCode'] ?? 'GLOBAL',
            status: 'Active',
            approvalDate: data['createdAt'] != null
                ? (DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now())
                : DateTime.now(),
            currentLevel: data['hostLevel'] ?? 1,
            dailyLiveMinutes: liveMins,
            isTodayValid: isTodayValid,
            completedValidDays: validDays,
            achievedDiamonds: data['achievedDiamonds'] ?? 0,
            pendingSalaryUsd: ((data['pendingSalaryUsd'] ?? 0) as num).toDouble(),
            availableSalaryUsd: ((data['availableSalaryUsd'] ?? 0) as num).toDouble(),
          );
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> fetchHostApplication(String userId) async {
    try {
      final res = await ApiClient.instance.get('/v1/hosts/application');
      if (res.statusCode == 200 && res.data['data'] != null) {
        final data = res.data['data'];
        final appStatus = data['status']?.toString().toUpperCase();
        final mappedStatus = (appStatus == 'ACTIVE' || appStatus == 'APPROVED')
            ? 'Approved'
            : (appStatus == 'REJECTED' ? 'Rejected' : 'Under Review');

        final app = LiveHostApplicationModel(
          id: data['id']?.toString() ?? 'app_$userId',
          userId: userId,
          legalName: data['user']?['profile']?['displayName'] ?? data['user']?['username'] ?? 'Host',
          displayName: data['user']?['username'] ?? 'Host',
          dateOfBirth: '',
          gender: 'Not Specified',
          country: 'GLOBAL',
          city: '',
          languages: 'Global',
          category: data['hostType'] ?? 'Streaming',
          schedule: 'Daily',
          phoneOrEmail: data['user']?['phone'] ?? data['user']?['email'] ?? '',
          govIdType: 'VERIFIED',
          govIdNumber: 'VERIFIED',
          frontIdUrl: data['idCardFrontUrl'] ?? '',
          backIdUrl: data['idCardBackUrl'] ?? '',
          selfieUrl: data['videoSampleUrl'],
          status: mappedStatus,
          submittedAt: data['createdAt'] != null
              ? (DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now())
              : DateTime.now(),
        );

        _applications.removeWhere((a) => a.userId == userId);
        _applications.add(app);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String> submitApplicationAsync({
    required LiveHostApplicationModel app,
    required String hostType,
  }) async {
    _isLoading = true;
    notifyListeners();

    // 1. Submit to Backend API (Module 08 Specification: ID fields removed)
    try {
      await ApiClient.instance.post(
        '/v1/hosts/apply-live',
        data: {
          'name': app.legalName,
          'displayName': app.displayName,
          'dateOfBirth': app.dateOfBirth,
          'gender': app.gender.toUpperCase(),
          'phone': app.phoneOrEmail,
          'contentCategory': app.category,
          'hostIntroduction': app.schedule,
        },
      );
    } catch (e) {
      debugPrint('[LiveHostProvider] Backend API host application call: $e');
      final errStr = e.toString().toLowerCase();
      if (!errStr.contains('already exists') && !errStr.contains('409') && !errStr.contains('pending_application_exists')) {
        _isLoading = false;
        notifyListeners();
        rethrow;
      }
    }

    // 2. Update local state
    _applications.removeWhere((a) => a.userId == app.userId);
    _applications.add(app);
    _logAudit(
      actorId: app.userId,
      action: 'SUBMIT_LIVE_HOST_APPLICATION',
      targetId: app.id,
      reason: 'New direct Live Host application submitted ($hostType)',
    );

    _isLoading = false;
    notifyListeners();
    return 'Application submitted successfully! Our team will review within 24-48 hours.';
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

  // Deprecated: Manual simulation removed per production audit requirements.
  // Verified streaming minutes are tracked by the server during real live broadcasts.
  void addLiveStreamingMinutes(int minutes) {
    debugPrint('[LiveHostProvider] Manual simulation disabled. Attendance tracked via server sessions.');
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
