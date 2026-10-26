import 'dart:async';
import 'package:flutter/material.dart';
import '../models/live_host_application_model.dart';
import '../models/live_host_model.dart';
import '../models/hosting_eligibility_model.dart';
import '../models/host_target_summary_model.dart';
import '../core/policy/live_host_policy.dart';
import '../core/services/api_client.dart';
import '../core/services/socket_service.dart';

class LiveHostProvider extends ChangeNotifier {
  LiveHostModel? _activeLiveHost;
  final List<LiveHostApplicationModel> _applications = [];
  final List<Map<String, dynamic>> _auditLogs = [];
  HostingEligibilityModel? _eligibility;
  HostTargetSummaryModel? _targetSummary;
  bool _isLoading = false;
  bool _isLoadingTarget = false;
  String? _targetError;
  String? _profileError;
  Timer? _heartbeatTimer;
  String? _currentBroadcastRoomId;

  String? get currentBroadcastRoomId => _currentBroadcastRoomId;
  bool get isHeartbeatActive => _heartbeatTimer != null;
  String? get profileError => _profileError;

  StreamSubscription? _hostTargetSubscription;
  StreamSubscription? _reconnectSubscription;

  LiveHostModel? get activeLiveHost => _activeLiveHost;
  set activeLiveHost(LiveHostModel? host) {
    _activeLiveHost = host;
    notifyListeners();
  }
  List<LiveHostApplicationModel> get applications =>
      List.unmodifiable(_applications);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);
  HostingEligibilityModel? get eligibility => _eligibility;
  HostTargetSummaryModel? get targetSummary => _targetSummary;
  bool get isLoading => _isLoading;
  bool get isLoadingTarget => _isLoadingTarget;
  String? get targetError => _targetError;

  LiveHostProvider({SocketService? socketService}) {
    initRealtimeListeners(socketService: socketService);
  }

  void initRealtimeListeners({SocketService? socketService}) {
    final socket = socketService ?? SocketService.instance;
    _hostTargetSubscription?.cancel();
    _reconnectSubscription?.cancel();

    _hostTargetSubscription = socket.onHostTargetUpdated.listen((_) {
      debugPrint(
        '[LiveHostProvider] host:target_updated received -> invalidating cache & refetching REST target summary',
      );
      invalidateTargetCache();
      fetchHostTargetSummary();
    });

    _reconnectSubscription = socket.onReconnect.listen((_) {
      debugPrint(
        '[LiveHostProvider] network/socket reconnected -> refreshing target summary',
      );
      fetchHostTargetSummary();
    });
  }

  void invalidateTargetCache() {
    _targetSummary = null;
    _targetError = null;
    notifyListeners();
  }

  Future<HostTargetSummaryModel?> refreshTargetSummary() async {
    invalidateTargetCache();
    return fetchHostTargetSummary();
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

  Future<HostTargetSummaryModel?> fetchHostTargetSummary({
    DateTime? date,
  }) async {
    _isLoadingTarget = true;
    _targetError = null;
    notifyListeners();

    try {
      final query = date != null ? {'date': date.toIso8601String()} : null;
      final res = await ApiClient.instance.get(
        '/v1/hosts/targets/summary',
        queryParameters: query,
      );
      if (res.statusCode == 200 &&
          res.data != null &&
          res.data['data'] != null) {
        _targetSummary = HostTargetSummaryModel.fromJson(
          res.data['data'] as Map<String, dynamic>,
        );
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
    if (userId.isEmpty) return;
    _isLoading = true;
    _profileError = null;
    notifyListeners();

    try {
      final res = await ApiClient.instance.get('/v1/hosts/profile');
      if (res.statusCode == 200 && res.data['data'] != null) {
        final data = res.data['data'];
        final rawStatus = (data['hostStatus'] ?? data['status'])
            ?.toString()
            .toUpperCase();
        if (rawStatus == 'ACTIVE' || rawStatus == 'APPROVED') {
          final liveMins =
              int.tryParse(data['dailyLiveMinutes']?.toString() ?? '') ??
              int.tryParse(data['verifiedMinutesToday']?.toString() ?? '') ??
              int.tryParse(data['streamingMinutes']?.toString() ?? '') ??
              (data['dailyLiveMinutes'] is num
                  ? (data['dailyLiveMinutes'] as num).toInt()
                  : 0);
          final isTodayValid =
              data['isTodayValid'] == true ||
              (liveMins >= LiveHostPolicy.requiredLiveHostDailyMinutes);
          final validDays =
              int.tryParse(data['completedValidDays']?.toString() ?? '') ??
              int.tryParse(data['validDays']?.toString() ?? '') ??
              int.tryParse(data['targetDaysAchieved']?.toString() ?? '') ??
              (isTodayValid ? 1 : 0);
          final diamonds =
              int.tryParse(data['achievedDiamonds']?.toString() ?? '0') ??
              (data['achievedDiamonds'] is num
                  ? (data['achievedDiamonds'] as num).toInt()
                  : 0);
          final lvl =
              int.tryParse(data['hostLevel']?.toString() ?? '1') ??
              (data['hostLevel'] is num
                  ? (data['hostLevel'] as num).toInt()
                  : 1);

          _activeLiveHost = LiveHostModel(
            liveHostId: data['id'] ?? 'lh_$userId',
            userId: userId,
            displayName:
                data['user']?['profile']?['displayName'] ??
                data['user']?['username'] ??
                'Live Host',
            avatarUrl: data['user']?['avatarUrl'] ?? '',
            countryCode: data['user']?['countryCode'] ?? 'GLOBAL',
            status: 'Active',
            approvalDate: data['createdAt'] != null
                ? (DateTime.tryParse(data['createdAt'].toString()) ??
                      DateTime.now())
                : DateTime.now(),
            currentLevel: lvl,
            dailyLiveMinutes: liveMins,
            isTodayValid: isTodayValid,
            completedValidDays: validDays,
            achievedDiamonds: diamonds,
            pendingSalaryUsd: (data['pendingSalaryUsd'] is num)
                ? (data['pendingSalaryUsd'] as num).toDouble()
                : (double.tryParse(
                        data['pendingSalaryUsd']?.toString() ?? '0',
                      ) ??
                      0.0),
            availableSalaryUsd: (data['availableSalaryUsd'] is num)
                ? (data['availableSalaryUsd'] as num).toDouble()
                : (double.tryParse(
                        data['availableSalaryUsd']?.toString() ?? '0',
                      ) ??
                      0.0),
          );
          _profileError = null;
        } else {
          _profileError = 'Host profile is not currently active';
        }
      } else {
        _profileError = 'Failed to retrieve host profile';
      }
    } catch (e) {
      _profileError = e.toString();
      debugPrint('[LiveHostProvider] fetchHostProfile error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
          legalName:
              data['user']?['profile']?['displayName'] ??
              data['user']?['username'] ??
              'Host',
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
              ? (DateTime.tryParse(data['createdAt'].toString()) ??
                    DateTime.now())
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
    final existing = _applications
        .where((a) => a.userId == app.userId && a.status != 'Rejected')
        .firstOrNull;
    if (existing != null) {
      return 'You already have an active application (${existing.status}).';
    }

    _applications.add(app);
    _logAudit(
      actorId: app.userId,
      action: 'SUBMIT_LIVE_HOST_APPLICATION',
      targetId: app.id,
      reason: 'New direct Live Host application submitted',
    );
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

      _logAudit(
        actorId: reviewerUserId,
        action: 'APPROVE_LIVE_HOST',
        targetId: appId,
        reason: 'Identity & liveness verified',
      );
      notifyListeners();
    }
  }

  void rejectApplication(String appId, String reason, String reviewerUserId) {
    final idx = _applications.indexWhere((a) => a.id == appId);
    if (idx != -1) {
      _applications[idx] = _applications[idx].copyWith(
        status: 'Rejected',
        rejectionReason: reason,
      );
      _logAudit(
        actorId: reviewerUserId,
        action: 'REJECT_LIVE_HOST',
        targetId: appId,
        reason: reason,
      );
      notifyListeners();
    }
  }

  // Deprecated: Manual simulation removed per production audit requirements.
  // Verified streaming minutes are tracked by the server during real live broadcasts.
  void addLiveStreamingMinutes(int minutes) {
    debugPrint(
      '[LiveHostProvider] Manual simulation disabled. Attendance tracked via server sessions.',
    );
  }

  // Direct Live Host Platform Salary Withdrawal
  String? requestWithdrawal({
    required double amount,
    required String channel,
    required String pin,
    required String actorUserId,
  }) {
    if (_activeLiveHost == null) {
      return 'No Live Host profile found.';
    }
    if (amount <= 0) {
      return 'Invalid amount.';
    }
    if (_activeLiveHost!.availableSalaryUsd < amount) {
      return 'Insufficient Available Salary.';
    }
    if (pin != '1234' && pin != '0000') {
      return 'Incorrect Security PIN.';
    }

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
    if (roomId.isEmpty) return;
    stopBroadcastHeartbeat();
    _currentBroadcastRoomId = roomId;
    _sendHeartbeat(roomId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_currentBroadcastRoomId != null) {
        _sendHeartbeat(_currentBroadcastRoomId!);
      }
    });
  }

  Future<void> _sendHeartbeat(String roomId) async {
    bool heartbeatRecorded = false;
    dynamic responseData;

    try {
      final res = await ApiClient.instance.post(
        '/v1/hosts/heartbeat',
        data: {'roomId': roomId},
      );
      if (res.statusCode == 200 && res.data != null) {
        heartbeatRecorded = true;
        responseData = res.data is Map ? (res.data['data'] ?? res.data) : null;
      }
    } catch (_) {
      try {
        final fallbackRes = await ApiClient.instance.post('/v1/rooms/$roomId/heartbeat');
        if (fallbackRes.statusCode == 200 && fallbackRes.data != null) {
          heartbeatRecorded = true;
          responseData = fallbackRes.data is Map ? (fallbackRes.data['data'] ?? fallbackRes.data) : null;
        }
      } catch (_) {}
    }

    if (!heartbeatRecorded) {
      try {
        SocketService.instance.emit('stream:heartbeat', {'roomId': roomId});
      } catch (_) {}
    } else if (responseData is Map) {
      _updateAttendanceFromHeartbeat(Map<String, dynamic>.from(responseData));
    }
  }

  void stopBroadcastHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _currentBroadcastRoomId = null;
  }

  // ── Host Attendance & Target Tracking (Change 26) ──
  Map<String, dynamic>? _attendanceData;
  Map<String, dynamic>? get attendanceData => _attendanceData;

  void updateAttendanceFromHeartbeat(Map<String, dynamic> data) =>
      _updateAttendanceFromHeartbeat(data);

  void _updateAttendanceFromHeartbeat(Map<String, dynamic> data) {
    _attendanceData = data;
    if (_activeLiveHost != null) {
      final rawMins = data['dailyLiveMinutes'] ??
          data['verifiedMinutesToday'] ??
          data['streamingMinutes'];
      final liveMins = (rawMins is num)
          ? rawMins.toInt()
          : (int.tryParse(rawMins?.toString() ?? '') ??
              _activeLiveHost!.dailyLiveMinutes);

      final rawValid = data['isTodayValid'];
      final isTodayValid = rawValid == true ||
          (liveMins >= LiveHostPolicy.requiredLiveHostDailyMinutes);

      final rawDays = data['completedValidDays'] ??
          data['validDays'] ??
          data['targetDaysAchieved'];
      final validDays = (rawDays is num)
          ? rawDays.toInt()
          : (int.tryParse(rawDays?.toString() ?? '') ??
              _activeLiveHost!.completedValidDays);

      final changed = _activeLiveHost!.dailyLiveMinutes != liveMins ||
          _activeLiveHost!.isTodayValid != isTodayValid ||
          _activeLiveHost!.completedValidDays != validDays;

      if (changed) {
        _activeLiveHost = _activeLiveHost!.copyWith(
          dailyLiveMinutes: liveMins,
          isTodayValid: isTodayValid,
          completedValidDays: validDays,
        );
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  Future<void> fetchAttendance() async {
    try {
      final res = await ApiClient.instance.get('/v1/hosts/attendance');
      if (res.statusCode == 200 && res.data != null) {
        final rawData = res.data['data'] is Map ? res.data['data'] : res.data;
        if (rawData is Map) {
          _updateAttendanceFromHeartbeat(Map<String, dynamic>.from(rawData));
        }
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

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _hostTargetSubscription?.cancel();
    _reconnectSubscription?.cancel();
    super.dispose();
  }
}
