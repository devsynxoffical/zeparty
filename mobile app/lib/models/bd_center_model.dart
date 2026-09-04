enum BDSalaryPaymentStatus { pending, processing, paid, held, rejected }
enum BDInvitationStatus { pending, accepted, rejected, expired, cancelled }
enum BDAgencyStatus { active, suspended, review }

class BDAgentItem {
  final String id;
  final String userId;
  final String nickname;
  final String avatarUrl;
  final String agencyId;
  final String agencyName;
  final int currentMonthDiamonds;
  final int previousMonthDiamonds;
  final int activeHostsCount;
  final DateTime assignmentDate;
  final bool isOnline;
  final String status;

  const BDAgentItem({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.agencyId,
    required this.agencyName,
    required this.currentMonthDiamonds,
    required this.previousMonthDiamonds,
    required this.activeHostsCount,
    required this.assignmentDate,
    this.isOnline = true,
    this.status = 'active',
  });
}

class BDAgencyItem {
  final String id;
  final String name;
  final String ownerUserId;
  final String ownerName;
  final String ownerAvatar;
  final BDAgencyStatus status;
  final int agentCount;
  final int hostCount;
  final int currentMonthDiamonds;
  final int diamondTarget;
  final double commissionRate;
  final DateTime createdAt;

  const BDAgencyItem({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerAvatar,
    required this.status,
    required this.agentCount,
    required this.hostCount,
    required this.currentMonthDiamonds,
    required this.diamondTarget,
    required this.commissionRate,
    required this.createdAt,
  });

  double get progressPercentage => diamondTarget > 0 
      ? (currentMonthDiamonds / diamondTarget).clamp(0.0, 1.0) 
      : 0.0;
}

class BDInvitationRecord {
  final String id;
  final String targetUserId;
  final String targetNickname;
  final String targetAvatar;
  final String agencyId;
  final String agencyName;
  final BDInvitationStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final String? note;

  const BDInvitationRecord({
    required this.id,
    required this.targetUserId,
    required this.targetNickname,
    required this.targetAvatar,
    required this.agencyId,
    required this.agencyName,
    required this.status,
    required this.sentAt,
    this.respondedAt,
    this.note,
  });
}

class BDSalaryTier {
  final int tierLevel;
  final String name;
  final int requiredDiamonds;
  final double fixedSalaryUsd;
  final double commissionPercentage;
  final double bonusUsd;
  final int minActiveAgencies;
  final int minActiveAgents;

  const BDSalaryTier({
    required this.tierLevel,
    required this.name,
    required this.requiredDiamonds,
    required this.fixedSalaryUsd,
    required this.commissionPercentage,
    required this.bonusUsd,
    required this.minActiveAgencies,
    required this.minActiveAgents,
  });
}

class BDSalaryRecord {
  final String id;
  final String period; // e.g. '2026-08'
  final String bdUserId;
  final int totalDiamonds;
  final int salaryTier;
  final double fixedSalary;
  final double commission;
  final double bonus;
  final double adjustments;
  final double finalAmount;
  final BDSalaryPaymentStatus status;
  final String? referenceId;
  final DateTime? paymentDate;
  final String? notes;

  const BDSalaryRecord({
    required this.id,
    required this.period,
    required this.bdUserId,
    required this.totalDiamonds,
    required this.salaryTier,
    required this.fixedSalary,
    required this.commission,
    required this.bonus,
    required this.adjustments,
    required this.finalAmount,
    required this.status,
    this.referenceId,
    this.paymentDate,
    this.notes,
  });
}

class BDTargetRecord {
  final String id;
  final String period; // 'Monthly', 'Weekly', 'Q3'
  final int targetDiamonds;
  final int achievedDiamonds;
  final int targetAgencies;
  final int achievedAgencies;
  final double potentialBonusUsd;
  final DateTime endDate;

  const BDTargetRecord({
    required this.id,
    required this.period,
    required this.targetDiamonds,
    required this.achievedDiamonds,
    required this.targetAgencies,
    required this.achievedAgencies,
    required this.potentialBonusUsd,
    required this.endDate,
  });

  double get diamondProgress => targetDiamonds > 0 
      ? (achievedDiamonds / targetDiamonds).clamp(0.0, 1.0) 
      : 0.0;
}

class BDAuditLog {
  final String id;
  final String actionId;
  final String actorId;
  final String actorRole;
  final String targetId;
  final String category; // 'agency', 'agent', 'salary', 'svip', 'noble', 'permission'
  final String action;
  final String oldValue;
  final String newValue;
  final String reason;
  final DateTime timestamp;

  const BDAuditLog({
    required this.id,
    required this.actionId,
    required this.actorId,
    required this.actorRole,
    required this.targetId,
    required this.category,
    required this.action,
    required this.oldValue,
    required this.newValue,
    required this.reason,
    required this.timestamp,
  });
}

class BDSalaryWalletTransaction {
  final String id;
  final String title;
  final double amount;
  final String period;
  final String type; // 'credit', 'payout'
  final DateTime date;
  final String referenceId;

  const BDSalaryWalletTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.period,
    required this.type,
    required this.date,
    required this.referenceId,
  });
}
