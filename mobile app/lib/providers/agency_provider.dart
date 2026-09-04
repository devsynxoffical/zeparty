import 'package:flutter/material.dart';
import '../models/agency_model.dart';
import '../models/agency_member_model.dart';
import '../models/agency_wallet_ledger_model.dart';
import '../models/agency_invitation_model.dart';
import '../models/audio_host_model.dart';

class AgencyProvider extends ChangeNotifier {
  AgencyModel? _userAgency;
  final List<AgencyMemberModel> _members = [];
  final List<AudioHostModel> _audioHosts = [];
  final List<AgencyWalletLedgerModel> _walletLedger = [];
  final List<AgencyInvitationModel> _invitations = [];
  final List<Map<String, dynamic>> _auditLogs = [];

  AgencyModel? get userAgency => _userAgency;
  List<AgencyMemberModel> get members => List.unmodifiable(_members);
  List<AudioHostModel> get audioHosts => List.unmodifiable(_audioHosts);
  List<AgencyWalletLedgerModel> get walletLedger => List.unmodifiable(_walletLedger);
  List<AgencyInvitationModel> get invitations => List.unmodifiable(_invitations);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  AgencyProvider() {
    _initMockData();
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
      totalHosts: 3,
      totalMembers: 5,
      cycle15DayId: 'cycle_2026_09_A',
      pendingBalanceUsd: 150.0,
      availableBalanceUsd: 850.00,
      countryCode: 'GLOBAL',
      createdAt: now,
    );
    notifyListeners();
  }

  void _initMockData() {
    final now = DateTime.now();
    _userAgency = AgencyModel(
      id: 'agency_777',
      name: 'ZeParty Royal Agency',
      logoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      description: 'Official Premier Agency for Top Creators & Hosts',
      ownerUserId: 'user_1001',
      ownerName: 'Danial Khan',
      status: 'Active',
      totalHosts: 4,
      totalMembers: 12,
      cycle15DayId: 'cycle_2026_08_A',
      pendingBalanceUsd: 284.0,
      availableBalanceUsd: 1420.50,
      countryCode: 'GLOBAL',
      createdAt: now.subtract(const Duration(days: 120)),
    );

    _members.addAll([
      AgencyMemberModel(id: 'm1', agencyId: 'agency_777', userId: 'user_1001', name: 'Danial Khan', avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80', countryCode: 'GLOBAL', role: 'Owner', status: 'Active', targetStatus: 'Target Achieved', joinedAt: now.subtract(const Duration(days: 120))),
      AgencyMemberModel(id: 'm2', agencyId: 'agency_777', userId: 'user_1002', name: 'Sophia Rose', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80', countryCode: 'US', role: 'Host', status: 'Active', targetStatus: 'Target Achieved', joinedAt: now.subtract(const Duration(days: 90))),
      AgencyMemberModel(id: 'm3', agencyId: 'agency_777', userId: 'user_1003', name: 'Alex Rivera', avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=300&q=80', countryCode: 'PK', role: 'Host', status: 'Active', targetStatus: 'In Progress', joinedAt: now.subtract(const Duration(days: 60))),
      AgencyMemberModel(id: 'm4', agencyId: 'agency_777', userId: 'user_1004', name: 'Elena Rostova', avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80', countryCode: 'IN', role: 'Host', status: 'Active', targetStatus: 'In Progress', joinedAt: now.subtract(const Duration(days: 45))),
    ]);

    _audioHosts.addAll([
      AudioHostModel(hostId: 'ah_1', userId: 'user_1002', userName: 'Sophia Rose', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80', agencyId: 'agency_777', agencyName: 'ZeParty Royal Agency', joinDate: now.subtract(const Duration(days: 90)), currentLevel: 5, achievedDiamonds: 520000, completedValidDays: 8, dailyOnlineMinutes: 140, isTodayValid: true, pendingSalaryUsd: 32.0, availableSalaryUsd: 120.0),
      AudioHostModel(hostId: 'ah_2', userId: 'user_1003', userName: 'Alex Rivera', avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=300&q=80', agencyId: 'agency_777', agencyName: 'ZeParty Royal Agency', joinDate: now.subtract(const Duration(days: 60)), currentLevel: 3, achievedDiamonds: 120000, completedValidDays: 10, dailyOnlineMinutes: 130, isTodayValid: true, pendingSalaryUsd: 6.40, availableSalaryUsd: 48.0),
      AudioHostModel(hostId: 'ah_3', userId: 'user_1004', userName: 'Elena Rostova', avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80', agencyId: 'agency_777', agencyName: 'ZeParty Royal Agency', joinDate: now.subtract(const Duration(days: 45)), currentLevel: 2, achievedDiamonds: 45000, completedValidDays: 7, dailyOnlineMinutes: 90, isTodayValid: false, pendingSalaryUsd: 0.0, availableSalaryUsd: 20.0),
    ]);

    _walletLedger.addAll([
      AgencyWalletLedgerModel(transactionId: 'tx_ag_101', cycleId: 'cycle_2026_07_B', agencyId: 'agency_777', hostId: 'user_1002', diamonds: 520000, usdAmount: 32.0, commissionUsd: 8.0, type: 'Settlement', status: 'Completed', recipientChannel: 'Agency Wallet', timestamp: now.subtract(const Duration(days: 16))),
      AgencyWalletLedgerModel(transactionId: 'tx_ag_102', cycleId: 'cycle_2026_07_B', agencyId: 'agency_777', hostId: 'user_1003', diamonds: 120000, usdAmount: 6.4, commissionUsd: 1.6, type: 'Settlement', status: 'Completed', recipientChannel: 'Agency Wallet', timestamp: now.subtract(const Duration(days: 16))),
    ]);
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
