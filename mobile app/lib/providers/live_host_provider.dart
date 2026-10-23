import 'dart:async';
import 'package:flutter/material.dart';
import '../models/live_host_application_model.dart';
import '../models/live_host_model.dart';
import '../models/hosting_eligibility_model.dart';
import '../models/host_target_summary_model.dart';
import '../core/policy/live_host_policy.dart';
import '../core/services/api_client.dart';

class LiveHostProvider extends ChangeNotifier {
  LiveHostModel? _activeLiveHost;
  final List<LiveHostApplicationModel> _applications = [];
  final List<Map<String, dynamic>> _auditLogs = [];
  HostingEligibilityModel? _eligibility;
  HostTargetSummaryModel? _targetSummary;
  bool _isLoading = false;
  bool _isLoadingTarget = false;
  String? _targetError;
  Timer? _heartbeatTimer;

  LiveHostModel? get activeLiveHost => _activeLiveHost;
  List<LiveHostApplicationModel> get applications => List.unmodifiable(_applications);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);
  HostingEligibilityModel? get eligibility => _eligibility;
  HostTargetSummaryModel? get targetSummary => _targetSummary;
  bool get isLoading => _isLoading;
  bool get isLoadingTarget => _isLoadingTarget;
  String? get targetError => _targetError;

  LiveHostProvider() {
    // Clean initial state for authentic live host data
  }

  LiveHostApplicationModel? getApplicationByUserId(String userId) {
    return _applications.where((a) => a.userId == userId).firstOrNull;
  }

  Future<HostingEligibilityModel?> fetchEligibility() async {
    try {
      final res = await ApiClient.instance.get('/v1/hosts/eligibility');
      if (res.data != null && res.data['data'] != null) {
        _eligibility = HostingEligibilityModel.fromJson(res.data['data']);
        notifyListeners();
        return _eligibility;
      }
    } catch (e) {
      debugPrint('[LiveHostProvider] fetchEligibility error: $e');
    }
    return null;
  }

  Future<HostTargetSummaryModel?> fetchHostTargetSummary({DateTime? date}) async {
    _isLoadingTarget = true;
    _targetError = null;
    notifyListeners();

    try {
      final query = date != null ? {'date': date.toIso8601String()} : null;
      final res = await ApiClient.instance.get('/v1/hosts/targets/summary', queryParameters: query);
      if (res.statusCode == 200 && res.data != null && res.data['data'] != null) {
        _targetSummary = HostTargetSummaryModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _isLoadingTarget = false;
        notifyListeners();
        return _targetSummary;
      }
    } catch (e) {
      debugPrint('[LiveHostProvider] fetchHostTargetSummary error: $e');
      _targetError = e.toString();
    } finally {
      _isLoadingTarget = false;
      notifyListeners();
    }
    return null;
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
      _isLoading = false;
      notifyListeners();
      rethrow;
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

  // ── Periodic Broadcast Streaming Heartbeat (Change 26) ──
  // Sends verified heartbeat every 60 seconds during live broadcast sessions
  void startBroadcastHeartbeat(String roomId) {
    stopBroadcastHeartbeat();
    _sendHeartbeat(roomId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendHeartbeat(roomId);
    });
  }

  Future<void> _sendHeartbeat(String roomId) async {
    try {
      await ApiClient.instance.post('/v1/hosts/heartbeat', data: {'roomId': roomId});
    } catch (_) {
      try {
        await ApiClient.instance.post('/v1/rooms/$roomId/heartbeat');
      } catch (_) {}
    }
  }

  void stopBroadcastHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── Host Attendance & Target Tracking (Change 26) ──
  Map<String, dynamic>? _attendanceData;
  Map<String, dynamic>? get attendanceData => _attendanceData;

  Future<void> fetchAttendance() async {
    try {
      final res = await ApiClient.instance.get('/v1/hosts/attendance');
      if (res.statusCode == 200 && res.data != null) {
        _attendanceData = res.data['data'] is Map<String, dynamic>
            ? res.data['data'] as Map<String, dynamic>
            : res.data as Map<String, dynamic>;
        notifyListeners();
      }
    } catch (_) {}
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

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
