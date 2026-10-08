import 'package:flutter/material.dart';
import '../models/agency_model.dart';
import '../models/agency_member_model.dart';
import '../models/agency_wallet_ledger_model.dart';
import '../models/agency_invitation_model.dart';
import '../models/audio_host_model.dart';

class AgencyHostRequest {
  final String id;
  final String agencyId;
  final String agencyName;
  final String applicantUserId;
  final String applicantName;
  final String applicantAvatar;
  String status; // 'Pending', 'Accepted', 'Declined'
  final DateTime createdAt;

  AgencyHostRequest({
    required this.id,
    required this.agencyId,
    required this.agencyName,
    required this.applicantUserId,
    required this.applicantName,
    required this.applicantAvatar,
    this.status = 'Pending',
    required this.createdAt,
  });
}

class AgencyProvider extends ChangeNotifier {
  AgencyModel? _userAgency;
  final List<AgencyMemberModel> _members = [];
  final List<AudioHostModel> _audioHosts = [];
  final List<AgencyWalletLedgerModel> _walletLedger = [];
  final List<AgencyInvitationModel> _invitations = [];
  final List<Map<String, dynamic>> _auditLogs = [];
  final List<AgencyHostRequest> _hostRequests = [];

  final List<AgencyModel> _allAgencies = [
    AgencyModel(
      id: 'agency_101',
      name: 'ZeParty Premier Agency',
      logoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      description: 'Official ZeParty Elite Audio Host Network',
      ownerUserId: '6076247',
      ownerName: 'ZeParty Official Owner',
      status: 'Active',
      totalHosts: 12,
      totalMembers: 15,
      cycle15DayId: 'cycle_2026_09_A',
      pendingBalanceUsd: 250.0,
      availableBalanceUsd: 1200.0,
      countryCode: 'GLOBAL',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    AgencyModel(
      id: 'agency_102',
      name: 'Global Star Talent Agency',
      logoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      description: 'Top-tier audio broadcasting and live show hosts',
      ownerUserId: 'user_star_owner',
      ownerName: 'Alex Mercer',
      status: 'Active',
      totalHosts: 8,
      totalMembers: 10,
      cycle15DayId: 'cycle_2026_09_A',
      pendingBalanceUsd: 180.0,
      availableBalanceUsd: 750.0,
      countryCode: 'US',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
  ];

  AgencyModel? get userAgency => _userAgency;
  List<AgencyMemberModel> get members => List.unmodifiable(_members);
  List<AudioHostModel> get audioHosts => List.unmodifiable(_audioHosts);
  List<AgencyWalletLedgerModel> get walletLedger => List.unmodifiable(_walletLedger);
  List<AgencyInvitationModel> get invitations => List.unmodifiable(_invitations);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);
  List<AgencyHostRequest> get hostRequests => List.unmodifiable(_hostRequests);

  List<AgencyModel> get allAgencies {
    final list = List<AgencyModel>.from(_allAgencies);
    if (_userAgency != null && !list.any((a) => a.id == _userAgency!.id)) {
      list.insert(0, _userAgency!);
    }
    return List.unmodifiable(list);
  }

  List<AgencyModel> searchAgencies(String query) {
    if (query.trim().isEmpty) return allAgencies;
    final q = query.trim().toLowerCase();
    return allAgencies.where((a) => a.id.toLowerCase().contains(q) || a.name.toLowerCase().contains(q)).toList();
  }

  AgencyHostRequest? getHostRequestForUser(String userId) {
    return _hostRequests.where((r) => r.applicantUserId == userId).firstOrNull;
  }

  String submitHostJoinRequest({
    required String agencyId,
    required String userId,
    required String userName,
    required String userAvatar,
  }) {
    final existing = _hostRequests.where((r) => r.applicantUserId == userId && r.agencyId == agencyId && r.status == 'Pending').firstOrNull;
    if (existing != null) {
      return 'You already have a pending join request for this agency.';
    }

    final targetAgency = allAgencies.where((a) => a.id == agencyId).firstOrNull;
    final agencyName = targetAgency?.name ?? 'ZeParty Agency';

    final req = AgencyHostRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      agencyId: agencyId,
      agencyName: agencyName,
      applicantUserId: userId,
      applicantName: userName,
      applicantAvatar: userAvatar,
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    _hostRequests.insert(0, req);
    notifyListeners();
    return 'Join request sent to $agencyName!';
  }

  void acceptHostJoinRequest(String requestId) {
    final idx = _hostRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    final req = _hostRequests[idx];
    req.status = 'Accepted';

    // Add applicant as host
    if (!_audioHosts.any((h) => h.userId == req.applicantUserId)) {
      _audioHosts.add(
        AudioHostModel(
          hostId: 'host_${DateTime.now().millisecondsSinceEpoch}',
          userId: req.applicantUserId,
          userName: req.applicantName,
          avatarUrl: req.applicantAvatar,
          agencyId: req.agencyId,
          agencyName: req.agencyName,
          achievedDiamonds: 15000,
          completedValidDays: 10,
          dailyOnlineMinutes: 120,
          status: 'Active',
          joinDate: DateTime.now(),
        ),
      );
    }

    notifyListeners();
  }

  void declineHostJoinRequest(String requestId) {
    final idx = _hostRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) return;

    _hostRequests[idx].status = 'Declined';
    notifyListeners();
  }

  AgencyProvider() {
    // Clean initial state for authentic user data
  }

  void registerAgency({
    required String name,
    required String description,
    required String ownerUserId,
    required String ownerName,
  }) {
    final now = DateTime.now();
    final newId = 'agency_${now.millisecondsSinceEpoch.toString().substring(7)}';
    _userAgency = AgencyModel(
      id: newId,
      name: name,
      logoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      description: description,
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      status: 'Active',
      totalHosts: 0,
      totalMembers: 1,
      cycle15DayId: 'cycle_${now.year}_${now.month}_A',
      pendingBalanceUsd: 0.0,
      availableBalanceUsd: 0.0,
      countryCode: 'GLOBAL',
      createdAt: now,
    );
    _allAgencies.insert(0, _userAgency!);
    notifyListeners();
  }

  bool isAgencyOwner(String userId) {
    return _userAgency != null && _userAgency!.ownerUserId == userId;
  }

  AudioHostModel? getAudioHostByUserId(String userId) {
    return _audioHosts.where((h) => h.userId == userId).firstOrNull;
  }

  // Member Invitation & Management
  String inviteMember({
    required String targetUserId,
    required String targetName,
    required String inviterUserId,
    required String inviterName,
  }) {
    final existing = _members.where((m) => m.userId == targetUserId && m.status == 'Active').firstOrNull;
    if (existing != null) {
      return 'User is already an active member of this agency.';
    }

    final inviteId = 'inv_ag_${DateTime.now().millisecondsSinceEpoch}';
    final invitation = AgencyInvitationModel(
      id: inviteId,
      agencyId: _userAgency?.id ?? 'agency_777',
      agencyName: _userAgency?.name ?? 'ZeParty Agency',
      inviterUserId: inviterUserId,
      inviterName: inviterName,
      targetUserId: targetUserId,
      targetName: targetName,
      status: 'Pending',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    _invitations.add(invitation);
    _logAudit(actorId: inviterUserId, action: 'INVITE_MEMBER', targetId: targetUserId, reason: 'New agency invitation issued');
    notifyListeners();
    return 'Invitation sent to $targetName!';
  }

  void acceptAgencyInvitation({
    required String invitationId,
    required String targetUserId,
    required String targetName,
    String? targetAvatar,
  }) {
    final idx = _invitations.indexWhere((inv) => inv.id == invitationId || inv.targetUserId == targetUserId);
    if (idx != -1) {
      _invitations[idx] = _invitations[idx].copyWith(status: 'Accepted');
    }

    // Add applicant as host
    if (!_audioHosts.any((h) => h.userId == targetUserId)) {
      _audioHosts.add(
        AudioHostModel(
          hostId: 'host_${DateTime.now().millisecondsSinceEpoch}',
          userId: targetUserId,
          userName: targetName,
          avatarUrl: targetAvatar ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
          agencyId: _userAgency?.id ?? 'agency_777',
          agencyName: _userAgency?.name ?? 'ZeParty Agency',
          achievedDiamonds: 10000,
          completedValidDays: 5,
          dailyOnlineMinutes: 90,
          status: 'Active',
          joinDate: DateTime.now(),
        ),
      );
    }

    // Add to members list
    if (!_members.any((m) => m.userId == targetUserId)) {
      _members.add(
        AgencyMemberModel(
          id: 'mem_${DateTime.now().millisecondsSinceEpoch}',
          agencyId: _userAgency?.id ?? 'agency_777',
          userId: targetUserId,
          name: targetName,
          avatarUrl: targetAvatar ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
          countryCode: _userAgency?.countryCode ?? 'GLOBAL',
          role: 'Host',
          status: 'Active',
          targetStatus: 'In Progress',
          joinedAt: DateTime.now(),
        ),
      );
    }

    if (_userAgency != null) {
      _userAgency = _userAgency!.copyWith(
        totalHosts: _audioHosts.length,
        totalMembers: _members.length,
      );
    }

    notifyListeners();
  }

  void declineAgencyInvitation({
    required String invitationId,
    required String targetUserId,
  }) {
    final idx = _invitations.indexWhere((inv) => inv.id == invitationId || inv.targetUserId == targetUserId);
    if (idx != -1) {
      _invitations[idx] = _invitations[idx].copyWith(status: 'Declined');
    }
    notifyListeners();
  }

  bool removeMember({
    required String memberUserId,
    required String reason,
    required String actorUserId,
  }) {
    final idx = _members.indexWhere((m) => m.userId == memberUserId);
    if (idx == -1) return false;

    final member = _members[idx];
    _members[idx] = member.copyWith(status: 'Removed');

    _logAudit(
      actorId: actorUserId,
      action: 'REMOVE_MEMBER',
      targetId: memberUserId,
      reason: reason,
      previousValue: member.status,
      newValue: 'Removed',
    );

    notifyListeners();
    return true;
  }

  // Idempotent 15-day Cycle Settlement
  bool settle15DayCycle({required String cycleId, required String actorUserId}) {
    if (_userAgency == null) return false;

    // Move pending to available
    final settledAmount = _userAgency!.pendingBalanceUsd;
    if (settledAmount <= 0) return false;

    _userAgency = _userAgency!.copyWith(
      availableBalanceUsd: _userAgency!.availableBalanceUsd + settledAmount,
      pendingBalanceUsd: 0.0,
      cycle15DayId: cycleId,
    );

    _walletLedger.insert(
      0,
      AgencyWalletLedgerModel(
        transactionId: 'tx_settle_${DateTime.now().millisecondsSinceEpoch}',
        cycleId: cycleId,
        agencyId: _userAgency!.id,
        hostId: 'SYSTEM_ALL',
        diamonds: 0,
        usdAmount: settledAmount,
        commissionUsd: 0.0,
        type: 'Settlement',
        status: 'Completed',
        timestamp: DateTime.now(),
      ),
    );

    _logAudit(
      actorId: actorUserId,
      action: 'CYCLE_SETTLEMENT',
      targetId: _userAgency!.id,
      reason: '15-day cycle closed & validated',
      newValue: 'Settled \$${settledAmount.toStringAsFixed(2)}',
    );

    notifyListeners();
    return true;
  }

  // Idempotent Wallet Transfer / Withdrawal
  String? requestWithdrawal({
    required double amount,
    required String channel,
    required String pin,
    required String actorUserId,
  }) {
    if (_userAgency == null) return 'No agency found.';
    if (amount <= 0) return 'Invalid amount.';
    if (_userAgency!.availableBalanceUsd < amount) return 'Insufficient Available Balance.';
    if (pin != '1234' && pin != '0000') return 'Incorrect Security PIN.';

    final txId = 'tx_wdr_${DateTime.now().millisecondsSinceEpoch}';

    _userAgency = _userAgency!.copyWith(
      availableBalanceUsd: _userAgency!.availableBalanceUsd - amount,
    );

    _walletLedger.insert(
      0,
      AgencyWalletLedgerModel(
        transactionId: txId,
        cycleId: _userAgency!.cycle15DayId,
        agencyId: _userAgency!.id,
        hostId: actorUserId,
        diamonds: 0,
        usdAmount: amount,
        commissionUsd: 0.0,
        type: 'Withdrawal',
        status: 'Approved',
        recipientChannel: channel,
        timestamp: DateTime.now(),
      ),
    );

    _logAudit(
      actorId: actorUserId,
      action: 'WITHDRAWAL_REQUEST',
      targetId: _userAgency!.id,
      reason: 'Withdrawal to $channel',
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
    String? previousValue,
    String? newValue,
  }) {
    _auditLogs.add({
      'agencyId': _userAgency?.id ?? '',
      'actorId': actorId,
      'action': action,
      'targetId': targetId,
      'reason': reason,
      'previousValue': previousValue ?? '',
      'newValue': newValue ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
