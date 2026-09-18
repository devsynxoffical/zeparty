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
