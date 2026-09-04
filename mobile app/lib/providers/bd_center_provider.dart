import 'package:flutter/material.dart';
import '../models/bd_center_model.dart';

class BDCenterProvider extends ChangeNotifier {
  bool _isLoading = false;
  
  // BD Operator Profile Metadata
  final String _bdUserId = 'BD-88091';
  final String _nickname = 'ZeParty Regional Director';
  final String _avatarUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80';
  final String _country = 'United Arab Emirates';
  final String _region = 'MENA Region';
  final String _status = 'Verified BD Partner';

  // KPI Metrics
  final int _currentMonthAgencyDiamonds = 8450000;
  final int _previousMonthAgencyDiamonds = 6200000;
  final int _currentSalaryTier = 4;
  final double _currentSalaryProjection = 3450.00;
  final int _currentDiamondTarget = 10000000;
  final int _totalAgenciesCount = 14;
  final int _totalActiveAgentsCount = 52;
  int _pendingInvitationsCount = 3;

  // Salary Configuration Tiers
  final List<BDSalaryTier> _salaryTiers = [
    const BDSalaryTier(tierLevel: 1, name: 'Tier 1 (Bronze)', requiredDiamonds: 1000000, fixedSalaryUsd: 500.0, commissionPercentage: 5.0, bonusUsd: 100.0, minActiveAgencies: 2, minActiveAgents: 5),
    const BDSalaryTier(tierLevel: 2, name: 'Tier 2 (Silver)', requiredDiamonds: 2500000, fixedSalaryUsd: 1200.0, commissionPercentage: 7.0, bonusUsd: 250.0, minActiveAgencies: 4, minActiveAgents: 12),
    const BDSalaryTier(tierLevel: 3, name: 'Tier 3 (Gold)', requiredDiamonds: 5000000, fixedSalaryUsd: 2200.0, commissionPercentage: 10.0, bonusUsd: 500.0, minActiveAgencies: 8, minActiveAgents: 25),
    const BDSalaryTier(tierLevel: 4, name: 'Tier 4 (Platinum)', requiredDiamonds: 10000000, fixedSalaryUsd: 4000.0, commissionPercentage: 12.0, bonusUsd: 1000.0, minActiveAgencies: 12, minActiveAgents: 40),
    const BDSalaryTier(tierLevel: 5, name: 'Tier 5 (Diamond)', requiredDiamonds: 20000000, fixedSalaryUsd: 7500.0, commissionPercentage: 15.0, bonusUsd: 2500.0, minActiveAgencies: 20, minActiveAgents: 80),
  ];

  // Connected Agents
  final List<BDAgentItem> _agents = [
    BDAgentItem(
      id: 'agt_1',
      userId: '772910',
      nickname: 'Luna Star',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      agencyId: 'ag_1',
      agencyName: 'ZeParty Royal Agency',
      currentMonthDiamonds: 1450000,
      previousMonthDiamonds: 1100000,
      activeHostsCount: 12,
      assignmentDate: DateTime(2026, 1, 15),
    ),
    BDAgentItem(
      id: 'agt_2',
      userId: '448201',
      nickname: 'Alex Thunder',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      agencyId: 'ag_1',
      agencyName: 'ZeParty Royal Agency',
      currentMonthDiamonds: 2100000,
      previousMonthDiamonds: 1800000,
      activeHostsCount: 18,
      assignmentDate: DateTime(2026, 2, 1),
    ),
    BDAgentItem(
      id: 'agt_3',
      userId: '992015',
      nickname: 'Zara Diamond',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
      agencyId: 'ag_2',
      agencyName: 'Starlight Media',
      currentMonthDiamonds: 980000,
      previousMonthDiamonds: 750000,
      activeHostsCount: 8,
      assignmentDate: DateTime(2026, 3, 10),
    ),
    BDAgentItem(
      id: 'agt_4',
      userId: '110934',
      nickname: 'Leo King',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      agencyId: 'ag_3',
      agencyName: 'Galaxy Talent Hub',
      currentMonthDiamonds: 1850000,
      previousMonthDiamonds: 1200000,
      activeHostsCount: 14,
      assignmentDate: DateTime(2026, 4, 5),
    ),
  ];

  // Managed Agencies
  final List<BDAgencyItem> _agencies = [
    BDAgencyItem(
      id: 'ag_1',
      name: 'ZeParty Royal Agency',
      ownerUserId: '339102',
      ownerName: 'Vikram Mehta',
      ownerAvatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=300&q=80',
      status: BDAgencyStatus.active,
      agentCount: 18,
      hostCount: 64,
      currentMonthDiamonds: 3550000,
      diamondTarget: 4000000,
      commissionRate: 15.0,
      createdAt: DateTime(2025, 11, 10),
    ),
    BDAgencyItem(
      id: 'ag_2',
      name: 'Starlight Media',
      ownerUserId: '558291',
      ownerName: 'Elena Rostova',
      ownerAvatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=300&q=80',
      status: BDAgencyStatus.active,
      agentCount: 14,
      hostCount: 42,
      currentMonthDiamonds: 2600000,
      diamondTarget: 3000000,
      commissionRate: 12.0,
      createdAt: DateTime(2026, 1, 20),
    ),
    BDAgencyItem(
      id: 'ag_3',
      name: 'Galaxy Talent Hub',
      ownerUserId: '881903',
      ownerName: 'Tariq Al-Mansoor',
      ownerAvatar: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=300&q=80',
      status: BDAgencyStatus.active,
      agentCount: 20,
      hostCount: 78,
      currentMonthDiamonds: 2300000,
      diamondTarget: 3000000,
      commissionRate: 14.0,
      createdAt: DateTime(2026, 2, 14),
    ),
  ];

  // Invitations
  final List<BDInvitationRecord> _invitations = [
    BDInvitationRecord(
      id: 'inv_1',
      targetUserId: '661890',
      targetNickname: 'Golden Streamer VIP',
      targetAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
      agencyId: 'ag_1',
      agencyName: 'ZeParty Royal Agency',
      status: BDInvitationStatus.pending,
      sentAt: DateTime.now().subtract(const Duration(hours: 6)),
      note: 'Invited to join Agency Top Tier',
    ),
    BDInvitationRecord(
      id: 'inv_2',
      targetUserId: '882194',
      targetNickname: 'Sara Live',
      targetAvatar: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=300&q=80',
      agencyId: 'ag_2',
      agencyName: 'Starlight Media',
      status: BDInvitationStatus.accepted,
      sentAt: DateTime.now().subtract(const Duration(days: 2)),
      respondedAt: DateTime.now().subtract(const Duration(days: 1)),
      note: 'Direct BD recruitment',
    ),
  ];

  // Salary Payout Records
  final List<BDSalaryRecord> _salaryHistory = [
    BDSalaryRecord(
      id: 'sal_2026_07',
      period: '2026-07',
      bdUserId: 'BD-88091',
      totalDiamonds: 7800000,
      salaryTier: 3,
      fixedSalary: 2200.00,
      commission: 780.00,
      bonus: 500.00,
      adjustments: 0.0,
      finalAmount: 3480.00,
      status: BDSalaryPaymentStatus.paid,
      referenceId: 'TX-SAL-99481',
      paymentDate: DateTime(2026, 8, 5),
    ),
    BDSalaryRecord(
      id: 'sal_2026_06',
      period: '2026-06',
      bdUserId: 'BD-88091',
      totalDiamonds: 6400000,
      salaryTier: 3,
      fixedSalary: 2200.00,
      commission: 640.00,
      bonus: 300.00,
      adjustments: 0.0,
      finalAmount: 3140.00,
      status: BDSalaryPaymentStatus.paid,
      referenceId: 'TX-SAL-88310',
      paymentDate: DateTime(2026, 7, 5),
    ),
  ];

  // Audit Logs
  final List<BDAuditLog> _auditLogs = [
    BDAuditLog(
      id: 'log_1',
      actionId: 'ACT-9901',
      actorId: 'BD-88091',
      actorRole: 'BD Partner',
      targetId: '772910',
      category: 'agent',
      action: 'Agent Assignment',
      oldValue: 'Unassigned',
      newValue: 'ZeParty Royal Agency',
      reason: 'Standard onboarding transfer',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    BDAuditLog(
      id: 'log_2',
      actionId: 'ACT-9844',
      actorId: 'BD-88091',
      actorRole: 'BD Partner',
      targetId: '992015',
      category: 'svip',
      action: 'Manual SVIP Upgrade',
      oldValue: 'SVIP 9',
      newValue: 'SVIP 11',
      reason: 'Top Creator promotional grant',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  // BD Salary Wallet (Separate from user coins/diamonds)
  double _salaryWalletBalance = 6620.00;
  double _totalSalaryReceived = 14200.00;

  final List<BDSalaryWalletTransaction> _walletTransactions = [
    BDSalaryWalletTransaction(
      id: 'tx_sal_07',
      title: 'July 2026 Monthly BD Salary Approved',
      amount: 3480.00,
      period: '2026-07',
      type: 'credit',
      date: DateTime(2026, 8, 5),
      referenceId: 'TX-SAL-99481',
    ),
    BDSalaryWalletTransaction(
      id: 'tx_sal_06',
      title: 'June 2026 Monthly BD Salary Approved',
      amount: 3140.00,
      period: '2026-06',
      type: 'credit',
      date: DateTime(2026, 7, 5),
      referenceId: 'TX-SAL-88310',
    ),
  ];

  // Getters
  bool get isLoading => _isLoading;
  String get bdUserId => _bdUserId;
  String get nickname => _nickname;
  String get avatarUrl => _avatarUrl;
  String get country => _country;
  String get region => _region;
  String get status => _status;
  int get currentMonthAgencyDiamonds => _currentMonthAgencyDiamonds;
  int get previousMonthAgencyDiamonds => _previousMonthAgencyDiamonds;
  int get currentSalaryTier => _currentSalaryTier;
  double get currentSalaryProjection => _currentSalaryProjection;
  int get currentDiamondTarget => _currentDiamondTarget;
  int get totalAgenciesCount => _totalAgenciesCount;
  int get totalActiveAgentsCount => _totalActiveAgentsCount;
  int get pendingInvitationsCount => _pendingInvitationsCount;
  double get targetProgress => _currentDiamondTarget > 0 
      ? (_currentMonthAgencyDiamonds / _currentDiamondTarget).clamp(0.0, 1.0) 
      : 0.0;

  double get salaryWalletBalance => _salaryWalletBalance;
  double get totalSalaryReceived => _totalSalaryReceived;
  List<BDSalaryWalletTransaction> get walletTransactions => List.unmodifiable(_walletTransactions);

  List<BDSalaryTier> get salaryTiers => List.unmodifiable(_salaryTiers);
  List<BDAgentItem> get agents => List.unmodifiable(_agents);
  List<BDAgencyItem> get agencies => List.unmodifiable(_agencies);
  List<BDInvitationRecord> get invitations => List.unmodifiable(_invitations);
  List<BDSalaryRecord> get salaryHistory => List.unmodifiable(_salaryHistory);
  List<BDAuditLog> get auditLogs => List.unmodifiable(_auditLogs);

  // Invite Agent
  Future<bool> sendAgentInvitation({
    required String targetUserId,
    required String targetNickname,
    required String agencyId,
    required String agencyName,
    String? note,
  }) async {
    // Prevent duplicate invitations
    final exists = _invitations.any(
      (inv) => inv.targetUserId == targetUserId && inv.status == BDInvitationStatus.pending
    );
    if (exists) return false;

    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));

    final newInvite = BDInvitationRecord(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      targetUserId: targetUserId,
      targetNickname: targetNickname,
      targetAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
      agencyId: agencyId,
      agencyName: agencyName,
      status: BDInvitationStatus.pending,
      sentAt: DateTime.now(),
      note: note,
    );

    _invitations.insert(0, newInvite);
    _pendingInvitationsCount = _invitations.where((i) => i.status == BDInvitationStatus.pending).length;
    
    // Log audit
    _auditLogs.insert(0, BDAuditLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      actorId: _bdUserId,
      actorRole: 'BD Partner',
      targetId: targetUserId,
      category: 'agent',
      action: 'Send Invitation',
      oldValue: 'None',
      newValue: 'Pending Invite ($agencyName)',
      reason: note ?? 'BD Agent Invitation',
      timestamp: DateTime.now(),
    ));

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // Cancel Invitation
  void cancelInvitation(String invitationId) {
    final index = _invitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      final inv = _invitations[index];
      _invitations[index] = BDInvitationRecord(
        id: inv.id,
        targetUserId: inv.targetUserId,
        targetNickname: inv.targetNickname,
        targetAvatar: inv.targetAvatar,
        agencyId: inv.agencyId,
        agencyName: inv.agencyName,
        status: BDInvitationStatus.cancelled,
        sentAt: inv.sentAt,
        respondedAt: DateTime.now(),
        note: 'Cancelled by BD operator',
      );
      _pendingInvitationsCount = _invitations.where((i) => i.status == BDInvitationStatus.pending).length;
      notifyListeners();
    }
  }

  // BD SVIP Operator Actions
  void operatorGrantSVIP({
    required String targetUserId,
    required int targetLevel,
    required String reason,
    required String operatorId,
  }) {
    _auditLogs.insert(0, BDAuditLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      actorId: operatorId,
      actorRole: 'BD Operator',
      targetId: targetUserId,
      category: 'svip',
      action: 'Manual SVIP Grant',
      oldValue: 'Previous Level',
      newValue: 'SVIP $targetLevel',
      reason: reason,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  // BD Noble Operator Actions
  void operatorGrantNoble({
    required String targetUserId,
    required String rankId,
    required String reason,
    required String operatorId,
  }) {
    _auditLogs.insert(0, BDAuditLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      actionId: 'ACT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      actorId: operatorId,
      actorRole: 'BD Operator',
      targetId: targetUserId,
      category: 'noble',
      action: 'Manual Noble Grant',
      oldValue: 'Previous Rank',
      newValue: rankId.toUpperCase(),
      reason: reason,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }
}
