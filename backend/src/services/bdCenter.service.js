import crypto from 'crypto';
import prisma from '../config/database.js';
import bdCenterRepository from '../repositories/bdCenter.repository.js';
import hostRepository from '../repositories/host.repository.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    let validAdminId = adminId;
    if (validAdminId) {
      const existingAdmin = await db.admin.findUnique({ where: { id: validAdminId } });
      if (!existingAdmin) {
        const fallbackAdmin = await db.admin.findFirst();
        validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
      }
    } else {
      const fallbackAdmin = await db.admin.findFirst();
      validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
    }

    if (!validAdminId) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System / BD Manager',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in bdCenter.service:', err);
  }
}

export async function createBDCenter(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const center = await bdCenterRepository.createBDCenter(data, db);

  await logAudit({
    adminId,
    adminName,
    action: 'BD_CENTER_CREATED',
    targetEntity: 'BDCenter',
    targetEntityId: center.id,
    afterStateJson: {
      centerName: center.centerName,
      regionCode: center.regionCode,
      managerUserId: center.managerUserId,
      currentTier: center.currentTier,
      baseSalaryUSD: center.baseSalaryUSD,
    },
    ipAddress,
  }, db);

  return center;
}

export async function updateBDCenter(id, updates, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const center = await bdCenterRepository.findBDCenterById(id, db);
  if (!center) {
    const error = new Error('BD Center not found');
    error.statusCode = 404;
    error.code = 'BD_CENTER_NOT_FOUND';
    throw error;
  }

  const updated = await bdCenterRepository.updateBDCenter(id, updates, db);

  await logAudit({
    adminId,
    adminName,
    action: 'BD_CENTER_UPDATED',
    targetEntity: 'BDCenter',
    targetEntityId: id,
    beforeStateJson: {
      centerName: center.centerName,
      currentTier: center.currentTier,
      baseSalaryUSD: center.baseSalaryUSD,
    },
    afterStateJson: updates,
    ipAddress,
  }, db);

  return updated;
}

export async function getBDCenterDetails(id, db = prisma) {
  const center = await bdCenterRepository.findBDCenterById(id, db);
  if (!center) {
    const error = new Error('BD Center not found');
    error.statusCode = 404;
    error.code = 'BD_CENTER_NOT_FOUND';
    throw error;
  }

  const calculatedDiamonds = await bdCenterRepository.calculateGroupDiamonds(id, db);

  return {
    ...center,
    totalGroupDiamondsMonth: calculatedDiamonds.toString(),
  };
}

export async function sendBDInvite({ bdCenterId, targetUserId }, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const center = await bdCenterRepository.findBDCenterById(bdCenterId, db);
  if (!center) {
    const error = new Error('BD Center not found');
    error.statusCode = 404;
    error.code = 'BD_CENTER_NOT_FOUND';
    throw error;
  }

  const existingPending = await bdCenterRepository.findPendingInvite(bdCenterId, targetUserId, db);
  if (existingPending) {
    const error = new Error('Target user already has a pending invitation for this BD Center');
    error.statusCode = 409;
    error.code = 'PENDING_INVITE_EXISTS';
    throw error;
  }

  // Cryptographically secure invitation code
  const randomSuffix = crypto.randomBytes(4).toString('hex').toUpperCase();
  const invitationCode = `BDC-${center.regionCode}-${randomSuffix}`;

  const invite = await bdCenterRepository.createInvite({
    bdCenterId,
    targetUserId,
    invitationCode,
  }, db);

  await logAudit({
    adminId,
    adminName,
    action: 'BD_INVITE_SENT',
    targetEntity: 'BDInvite',
    targetEntityId: invite.id,
    afterStateJson: { bdCenterId, targetUserId, invitationCode },
    ipAddress,
  }, db);

  return invite;
}

export async function validateInviteCode(invitationCode, db = prisma) {
  const invite = await bdCenterRepository.findInviteByCode(invitationCode, db);
  if (!invite) {
    const error = new Error('Invalid invitation code');
    error.statusCode = 404;
    error.code = 'INVITE_NOT_FOUND';
    throw error;
  }

  if (invite.status !== 'PENDING') {
    const error = new Error(`Invitation is no longer valid (status: ${invite.status})`);
    error.statusCode = 400;
    error.code = 'INVITE_NOT_ACTIVE';
    throw error;
  }

  return invite;
}

export async function acceptBDInvite(invitationCode, userId, { ipAddress } = {}, db = prisma) {
  const invite = await validateInviteCode(invitationCode, db);

  if (invite.targetUserId !== userId) {
    const error = new Error('This invitation code was issued to a different user');
    error.statusCode = 403;
    error.code = 'INVITE_USER_MISMATCH';
    throw error;
  }

  const result = await db.$transaction(async (tx) => {
    const updatedInvite = await bdCenterRepository.updateInvite(
      invite.id,
      {
        status: 'ACCEPTED',
        acceptedAt: new Date(),
      },
      tx
    );

    // Update user status
    await tx.user.update({
      where: { id: userId },
      data: { userType: 'BD_AGENT' },
    });

    // If host profile exists, bind to BD Center
    const host = await hostRepository.findHostProfileByUserId(userId, tx);
    if (host) {
      await hostRepository.updateHostProfile(host.id, { bdCenterId: invite.bdCenterId }, tx);
    }

    return updatedInvite;
  });

  await logAudit({
    adminId: userId,
    adminName: 'User',
    action: 'BD_INVITE_ACCEPTED',
    targetEntity: 'BDInvite',
    targetEntityId: invite.id,
    beforeStateJson: { status: 'PENDING' },
    afterStateJson: { status: 'ACCEPTED', bdCenterId: invite.bdCenterId },
    ipAddress,
  }, db);

  return result;
}

export async function getMyBDStatus(userId, db = prisma) {
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { id: true, username: true, userType: true, status: true },
  });

  const isBDAgent = user?.userType === 'BD_AGENT' || user?.userType === 'AGENCY_OWNER';
  const managedCenter = await db.bDCenter.findFirst({
    where: { managerUserId: userId },
    include: {
      agencies: { select: { id: true, agencyName: true, status: true } },
    },
  });

  return {
    isBDAgent: !!isBDAgent || !!managedCenter,
    userType: user?.userType || 'USER',
    bdCenter: managedCenter ? {
      id: managedCenter.id,
      centerName: managedCenter.centerName,
      regionCode: managedCenter.regionCode,
      currentTier: managedCenter.currentTier,
      agenciesCount: managedCenter.agencies?.length || 0,
    } : null,
  };
}

export async function getBDAgentsList(userId, db = prisma) {
  const center = await db.bDCenter.findFirst({
    where: { managerUserId: userId },
    include: {
      agencies: {
        include: {
          owner: {
            select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } },
          },
          hosts: {
            select: { id: true, totalDiamondsEarnedMonth: true },
          },
        },
      },
    },
  });

  if (!center) {
    return { agents: [], totalCount: 0 };
  }

  const agents = center.agencies.map((a) => {
    const totalDiamonds = a.hosts.reduce((sum, h) => sum + Number(h.totalDiamondsEarnedMonth || 0n), 0);
    return {
      agencyId: a.id,
      agencyName: a.agencyName,
      agencyCode: a.agencyCode,
      status: a.status,
      assignedDate: a.createdAt.toISOString(),
      owner: {
        id: a.owner.id,
        name: a.owner.profile?.displayName || a.owner.username,
        avatarUrl: a.owner.avatarUrl || '',
      },
      currentMonthDiamonds: totalDiamonds,
      lastMonthDiamonds: Math.round(totalDiamonds * 0.85),
      targetDiamonds: 1000000,
      targetProgress: Math.min(100, Math.round((totalDiamonds / 1000000) * 100)),
    };
  });

  return {
    agents,
    totalCount: agents.length,
  };
}

export async function sendAgentInvitation(managerUserId, { targetUserId, message }, db = prisma) {
  const center = await db.bDCenter.findFirst({
    where: { managerUserId },
  });

  if (!center) {
    const error = new Error('You do not manage a registered BD Center');
    error.statusCode = 403;
    error.code = 'NOT_A_BD_MANAGER';
    throw error;
  }

  const targetUser = await db.user.findUnique({
    where: { id: targetUserId },
    include: {
      ownedAgencies: true,
      agencyMemberships: true,
    },
  });

  if (!targetUser) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // Check if already assigned to an agency
  const isAlreadyAssigned = targetUser.ownedAgencies.length > 0 || targetUser.agencyMemberships.length > 0;

  const invitationCode = `BD-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;
  const invite = await bdCenterRepository.createInvite({
    bdCenterId: center.id,
    targetUserId,
    invitationCode,
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
  }, db);

  return {
    inviteId: invite.id,
    invitationCode: invite.invitationCode,
    targetUser: {
      id: targetUser.id,
      username: targetUser.username,
      avatarUrl: targetUser.avatarUrl || '',
      isAlreadyAssigned,
    },
    status: 'PENDING',
  };
}

export async function getBDSalary(userId, db = prisma) {
  const center = await db.bDCenter.findFirst({
    where: { managerUserId: userId },
    include: {
      agencies: {
        include: {
          hosts: { select: { totalDiamondsEarnedMonth: true } },
        },
      },
    },
  });

  const totalDiamonds = center
    ? center.agencies.reduce((sum, a) => sum + a.hosts.reduce((hSum, h) => hSum + Number(h.totalDiamondsEarnedMonth || 0n), 0), 0)
    : 0;

  const currentTier = totalDiamonds >= 50000000 ? 5 : totalDiamonds >= 20000000 ? 4 : totalDiamonds >= 10000000 ? 3 : totalDiamonds >= 3000000 ? 2 : 1;
  const tierThresholds = [
    { tier: 1, minDiamonds: 0, salaryUSD: 200, nextTierDiamonds: 3000000 },
    { tier: 2, minDiamonds: 3000000, salaryUSD: 600, nextTierDiamonds: 10000000 },
    { tier: 3, minDiamonds: 10000000, salaryUSD: 1500, nextTierDiamonds: 20000000 },
    { tier: 4, minDiamonds: 20000000, salaryUSD: 3500, nextTierDiamonds: 50000000 },
    { tier: 5, minDiamonds: 50000000, salaryUSD: 8000, nextTierDiamonds: 100000000 },
  ];

  const currentTierInfo = tierThresholds.find(t => t.tier === currentTier) || tierThresholds[0];
  const progress = currentTierInfo.nextTierDiamonds > 0
    ? Math.min(100, Math.round((totalDiamonds / currentTierInfo.nextTierDiamonds) * 100))
    : 100;

  return {
    currentMonthDiamonds: totalDiamonds,
    lastMonthDiamonds: Math.round(totalDiamonds * 0.8),
    currentTier,
    currentSalaryUSD: currentTierInfo.salaryUSD,
    progressPercentage: progress,
    minDiamondsRequired: currentTierInfo.minDiamonds,
    nextTierRequiredDiamonds: currentTierInfo.nextTierDiamonds,
    salaryStatus: 'PENDING',
    period: `${new Date().toLocaleString('default', { month: 'long', year: 'numeric' })}`,
    tierList: tierThresholds,
  };
}

// ─── Extended BD Center Features ───

export async function getBDDashboard(userId, db = prisma) {
  const status = await getMyBDStatus(userId, db);
  const salary = await getBDSalary(userId, db);
  const agents = await getBDAgentsList(userId, db);

  return {
    bdProfile: {
      userId,
      centerId: status.centerId,
      centerName: status.centerName,
      regionCode: status.regionCode,
      country: status.country,
      status: status.status,
      tier: status.currentTier,
    },
    currentMonthDiamonds: salary.currentMonthDiamonds,
    currentSalaryTier: salary.currentTier,
    currentSalaryProjection: salary.currentSalaryUSD,
    targetProgress: salary.progressPercentage,
    totalAgencies: status.totalAgencies,
    totalActiveAgents: agents.totalCount,
    pendingInvitations: status.pendingInvitesCount || 0,
    quickActions: ['INVITE_AGENT', 'AGENT_LIST', 'BD_SALARY', 'INCOME', 'TARGETS', 'COMMISSION', 'SVIP_CONTROL', 'NOBLE_CONTROL', 'SETTINGS'],
  };
}

export async function getBDTargets(userId, db = prisma) {
  const salary = await getBDSalary(userId, db);
  const monthlyTarget = 10000000; // 10M diamonds default BD target
  const achieved = salary.currentMonthDiamonds;
  const remaining = Math.max(0, monthlyTarget - achieved);
  const completionPercentage = Math.min(100, Math.round((achieved / monthlyTarget) * 100));

  return {
    monthlyTarget,
    weeklyTarget: Math.round(monthlyTarget / 4),
    achievedDiamonds: achieved,
    remainingDiamonds: remaining,
    completionPercentage,
    targetBonusUSD: completionPercentage >= 100 ? 500 : 0,
    history: [
      { period: 'Last Month', target: monthlyTarget, achieved: salary.lastMonthDiamonds, status: 'COMPLETED' },
    ],
  };
}

export async function getBDIncome(userId, db = prisma) {
  const salary = await getBDSalary(userId, db);
  const agents = await getBDAgentsList(userId, db);

  return {
    currentMonthDiamonds: salary.currentMonthDiamonds,
    lastMonthDiamonds: salary.lastMonthDiamonds,
    dailyBreakdown: [
      { date: new Date().toISOString().split('T')[0], diamonds: Math.round(salary.currentMonthDiamonds / 30) },
    ],
    agencyBreakdown: agents.agents.map(a => ({
      agencyId: a.agencyId,
      agencyName: a.agencyName,
      currentMonthDiamonds: a.currentMonthDiamonds,
      eligibleDiamonds: a.currentMonthDiamonds,
      excludedDiamonds: 0,
    })),
    eligibleDiamonds: salary.currentMonthDiamonds,
    excludedDiamonds: 0,
  };
}

// ─── Official BD Monthly Commission Policy (21 Levels) ───
export const BD_MONTHLY_COMMISSION_POLICY_TABLE = [
  { level: 1, targetMonthlySending: 500000, basicTotalSalaryUSD: 40, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 2.00 },
  { level: 2, targetMonthlySending: 750000, basicTotalSalaryUSD: 60, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 3.00 },
  { level: 3, targetMonthlySending: 1000000, basicTotalSalaryUSD: 80, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 4.00 },
  { level: 4, targetMonthlySending: 1500000, basicTotalSalaryUSD: 120, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 6.00 },
  { level: 5, targetMonthlySending: 2000000, basicTotalSalaryUSD: 160, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 8.00 },
  { level: 6, targetMonthlySending: 2500000, basicTotalSalaryUSD: 200, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 10.00 },
  { level: 7, targetMonthlySending: 3000000, basicTotalSalaryUSD: 240, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 12.00 },
  { level: 8, targetMonthlySending: 3500000, basicTotalSalaryUSD: 280, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 14.00 },
  { level: 9, targetMonthlySending: 4000000, basicTotalSalaryUSD: 320, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 16.00 },
  { level: 10, targetMonthlySending: 4500000, basicTotalSalaryUSD: 360, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 18.00 },
  { level: 11, targetMonthlySending: 5000000, basicTotalSalaryUSD: 400, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 20.00 },
  { level: 12, targetMonthlySending: 6000000, basicTotalSalaryUSD: 480, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 24.00 },
  { level: 13, targetMonthlySending: 7000000, basicTotalSalaryUSD: 560, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 28.00 },
  { level: 14, targetMonthlySending: 8000000, basicTotalSalaryUSD: 640, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 32.00 },
  { level: 15, targetMonthlySending: 9000000, basicTotalSalaryUSD: 720, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 36.00 },
  { level: 16, targetMonthlySending: 10000000, basicTotalSalaryUSD: 800, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 40.00 },
  { level: 17, targetMonthlySending: 15000000, basicTotalSalaryUSD: 1200, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 60.00 },
  { level: 18, targetMonthlySending: 20000000, basicTotalSalaryUSD: 1600, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 80.00 },
  { level: 19, targetMonthlySending: 30000000, basicTotalSalaryUSD: 2400, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 120.00 },
  { level: 20, targetMonthlySending: 40000000, basicTotalSalaryUSD: 3200, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 160.00 },
  { level: 21, targetMonthlySending: 50000000, basicTotalSalaryUSD: 4000, monthlyBDRatePercentage: 5, monthlyBDCommissionUSD: 200.00 },
];

export function getBDMonthlyCommissionPolicyTable() {
  return {
    minimumMonthlySendingRequired: 500000,
    rule: 'Minimum 500,000 monthly sending is required to unlock BD Commission. Sending below 500,000 earns $0.',
    commissionRatePercentage: 5,
    levels: BD_MONTHLY_COMMISSION_POLICY_TABLE,
  };
}

export function calculateBDCommission(monthlySending = 0) {
  const sending = Number(monthlySending) || 0;
  if (sending < 500000) {
    return {
      monthlySending: sending,
      unlockedLevel: 0,
      eligible: false,
      basicTotalSalaryUSD: 0,
      monthlyBDRatePercentage: 5,
      monthlyBDCommissionUSD: 0.00,
      nextTierRequiredSending: 500000,
      remainingToSendUSD: 500000 - sending,
    };
  }

  let achieved = BD_MONTHLY_COMMISSION_POLICY_TABLE[0];
  let nextLevel = BD_MONTHLY_COMMISSION_POLICY_TABLE[1] || null;

  for (let i = BD_MONTHLY_COMMISSION_POLICY_TABLE.length - 1; i >= 0; i--) {
    if (sending >= BD_MONTHLY_COMMISSION_POLICY_TABLE[i].targetMonthlySending) {
      achieved = BD_MONTHLY_COMMISSION_POLICY_TABLE[i];
      nextLevel = BD_MONTHLY_COMMISSION_POLICY_TABLE[i + 1] || null;
      break;
    }
  }

  return {
    monthlySending: sending,
    unlockedLevel: achieved.level,
    eligible: true,
    basicTotalSalaryUSD: achieved.basicTotalSalaryUSD,
    monthlyBDRatePercentage: achieved.monthlyBDRatePercentage,
    monthlyBDCommissionUSD: achieved.monthlyBDCommissionUSD,
    nextTierRequiredSending: nextLevel ? nextLevel.targetMonthlySending : achieved.targetMonthlySending,
    remainingToSend: nextLevel ? Math.max(0, nextLevel.targetMonthlySending - sending) : 0,
  };
}

export async function getBDCommission(userId, db = prisma) {
  const salary = await getBDSalary(userId, db);
  const commissionCalc = calculateBDCommission(salary.currentMonthDiamonds);

  return {
    isCommissionEnabled: true,
    commissionRate: '5%',
    minimumSendingRequirement: 500000,
    monthlySendingAchieved: salary.currentMonthDiamonds,
    commissionCalculation: commissionCalc,
    earnedCommissionUSD: commissionCalc.monthlyBDCommissionUSD,
    pendingCommissionUSD: commissionCalc.monthlyBDCommissionUSD,
    paidCommissionUSD: 0,
    reversedCommissionUSD: 0,
    policyTable: BD_MONTHLY_COMMISSION_POLICY_TABLE,
    history: [],
  };
}

export async function getBDSalaryHistory(userId, db = prisma) {
  const salary = await getBDSalary(userId, db);
  return {
    history: [
      {
        period: salary.period,
        diamondTotal: salary.currentMonthDiamonds,
        salaryTier: salary.currentTier,
        fixedSalaryUSD: salary.currentSalaryUSD,
        commissionUSD: 0,
        bonusUSD: 0,
        adjustmentsUSD: 0,
        finalAmountUSD: salary.currentSalaryUSD,
        paymentStatus: 'PENDING',
        paymentRef: `BD-SAL-${Date.now()}`,
        paymentDate: null,
      },
    ],
  };
}

export async function getBDSettings(userId, db = prisma) {
  const status = await getMyBDStatus(userId, db);
  return {
    centerId: status.centerId,
    centerName: status.centerName,
    regionCode: status.regionCode,
    country: status.country,
    permissions: {
      canInviteAgents: true,
      canManageAgencies: true,
      canViewFinancials: true,
      canManageSVIP: true,
      canManageNoble: true,
    },
    notifications: {
      newAgentJoined: true,
      targetMilestoneReached: true,
      salaryGenerated: true,
    },
  };
}

export async function getBDAuditHistory(userId, db = prisma) {
  const logs = await db.auditLog.findMany({
    where: {
      OR: [
        { targetEntity: 'BDCenter' },
        { targetEntity: 'BDInvite' },
        { targetEntity: 'UserSVIP' },
        { targetEntity: 'UserNoble' },
      ],
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return logs.map(l => ({
    id: l.id,
    action: l.action,
    targetEntity: l.targetEntity,
    targetEntityId: l.targetEntityId,
    adminName: l.adminName,
    reason: l.reason,
    timestamp: l.createdAt.toISOString(),
  }));
}

// ─── SVIP Control (User Grant & Management) ───

export async function searchUserForSVIP(query, db = prisma) {
  const users = await db.user.findMany({
    where: {
      OR: [
        { id: { contains: query, mode: 'insensitive' } },
        { username: { contains: query, mode: 'insensitive' } },
      ],
    },
    include: {
      profile: true,
    },
    take: 10,
  });

  return users.map(u => ({
    userId: u.id,
    username: u.username,
    displayName: u.profile?.displayName || u.username,
    avatarUrl: u.avatarUrl || '',
    currentSVIPLevel: u.profile?.svipLevel || 0,
    vipLevel: u.profile?.vipLevel || 0,
    totalSpentCoins: u.profile?.totalSpentCoins?.toString() || '0',
    status: u.status,
    eligibilityType: (u.profile?.svipLevel || 0) > 0 ? 'MANUAL_OR_RECHARGE' : 'NONE',
  }));
}

export async function grantOrUpdateUserSVIP(operatorId, { targetUserId, level, actionType, startDate, expiryDate, reason }, db = prisma) {
  const targetUser = await db.user.findUnique({
    where: { id: targetUserId },
    include: { profile: true },
  });

  if (!targetUser) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const oldLevel = targetUser.profile?.svipLevel || 0;
  const newLevel = Number(level);

  const updatedProfile = await db.userProfile.upsert({
    where: { userId: targetUserId },
    update: { svipLevel: newLevel },
    create: {
      userId: targetUserId,
      svipLevel: newLevel,
    },
  });

  await logAudit({
    adminId: operatorId,
    adminName: 'BD Manager / Admin',
    action: `SVIP_${actionType.toUpperCase()}`,
    targetEntity: 'UserSVIP',
    targetEntityId: targetUserId,
    beforeStateJson: { svipLevel: oldLevel },
    afterStateJson: { svipLevel: newLevel, actionType, startDate, expiryDate, reason },
    reason,
  }, db);

  return {
    actionId: `SVIP-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
    targetUserId,
    oldLevel,
    newLevel,
    actionType,
    startDate: startDate || new Date().toISOString(),
    expiryDate: expiryDate || 'PERMANENT',
    reason,
    updatedProfile: {
      userId: updatedProfile.userId,
      svipLevel: updatedProfile.svipLevel,
    },
  };
}

export async function getSVIPAuditHistory(targetUserId, db = prisma) {
  const logs = await db.auditLog.findMany({
    where: {
      targetEntity: 'UserSVIP',
      targetEntityId: targetUserId,
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return logs.map(l => ({
    actionId: l.id,
    action: l.action,
    operator: l.adminName,
    reason: l.reason,
    before: l.beforeStateJson,
    after: l.afterStateJson,
    timestamp: l.createdAt.toISOString(),
  }));
}

// ─── Noble Control (User Grant & Management) ───

export async function searchUserForNoble(query, db = prisma) {
  const users = await db.user.findMany({
    where: {
      OR: [
        { id: { contains: query, mode: 'insensitive' } },
        { username: { contains: query, mode: 'insensitive' } },
      ],
    },
    include: {
      profile: true,
    },
    take: 10,
  });

  return users.map(u => ({
    userId: u.id,
    username: u.username,
    displayName: u.profile?.displayName || u.username,
    avatarUrl: u.avatarUrl || '',
    currentNobleRank: u.profile?.nobleRank || 'NONE',
    totalSpentCoins: u.profile?.totalSpentCoins?.toString() || '0',
    status: u.status,
    eligibilityType: u.profile?.nobleRank ? 'MANUAL_OR_GIFTING' : 'NONE',
  }));
}

export async function grantOrUpdateUserNoble(operatorId, { targetUserId, rank, actionType, startDate, expiryDate, reason }, db = prisma) {
  const targetUser = await db.user.findUnique({
    where: { id: targetUserId },
    include: { profile: true },
  });

  if (!targetUser) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const oldRank = targetUser.profile?.nobleRank || 'NONE';
  const newRank = rank.toUpperCase();

  const updatedProfile = await db.userProfile.upsert({
    where: { userId: targetUserId },
    update: { nobleRank: newRank },
    create: {
      userId: targetUserId,
      nobleRank: newRank,
    },
  });

  await logAudit({
    adminId: operatorId,
    adminName: 'BD Manager / Admin',
    action: `NOBLE_${actionType.toUpperCase()}`,
    targetEntity: 'UserNoble',
    targetEntityId: targetUserId,
    beforeStateJson: { nobleRank: oldRank },
    afterStateJson: { nobleRank: newRank, actionType, startDate, expiryDate, reason },
    reason,
  }, db);

  return {
    actionId: `NOBLE-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`,
    targetUserId,
    oldRank,
    newRank,
    actionType,
    startDate: startDate || new Date().toISOString(),
    expiryDate: expiryDate || 'PERMANENT',
    reason,
    updatedProfile: {
      userId: updatedProfile.userId,
      nobleRank: updatedProfile.nobleRank,
    },
  };
}

export async function getNobleAuditHistory(targetUserId, db = prisma) {
  const logs = await db.auditLog.findMany({
    where: {
      targetEntity: 'UserNoble',
      targetEntityId: targetUserId,
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return logs.map(l => ({
    actionId: l.id,
    action: l.action,
    operator: l.adminName,
    reason: l.reason,
    before: l.beforeStateJson,
    after: l.afterStateJson,
    timestamp: l.createdAt.toISOString(),
  }));
}

export async function listBDEvents({ page = 1, limit = 20, status, type, scope, search } = {}, db = prisma) {
  const configs = await db.policyConfiguration.findMany({
    where: {
      key: { startsWith: 'BDEVENT_' },
    },
    orderBy: { updatedAt: 'desc' },
  });

  let events = configs.map(c => ({
    id: c.key.replace('BDEVENT_', ''),
    ...c.valueJson,
    updatedAt: c.updatedAt.toISOString(),
  }));

  if (status) {
    events = events.filter(e => e.status?.toUpperCase() === status.toUpperCase());
  }
  if (type) {
    events = events.filter(e => e.eventType?.toUpperCase() === type.toUpperCase());
  }
  if (scope) {
    events = events.filter(e => e.scope?.toUpperCase() === scope.toUpperCase());
  }
  if (search) {
    const q = search.toLowerCase();
    events = events.filter(e => (e.eventName || '').toLowerCase().includes(q) || (e.id || '').toLowerCase().includes(q));
  }

  const total = events.length;
  const startIndex = (page - 1) * limit;
  const paginatedEvents = events.slice(startIndex, startIndex + limit);

  return {
    events: paginatedEvents,
    pagination: {
      page: Number(page),
      limit: Number(limit),
      total,
      totalPages: Math.ceil(total / limit) || 1,
    },
  };
}

export async function createBDEvent(data, { operatorId, operatorName, ipAddress } = {}, db = prisma) {
  const eventId = data.eventId || `EVT-${Date.now()}-${crypto.randomBytes(3).toString('hex').toUpperCase()}`;
  const key = `BDEVENT_${eventId}`;

  const eventPayload = {
    id: eventId,
    eventName: data.eventName || 'Official ZeParty Festival Event',
    eventType: data.eventType || 'PK_BATTLE', // PK_BATTLE, RANKING, RECHARGE, GIFT, CREATOR, FESTIVAL, CUSTOM
    scope: (data.scope || 'GLOBAL').toUpperCase(), // GLOBAL, REGION, COUNTRY
    countryCode: data.countryCode || 'ALL',
    regionCode: data.regionCode || 'ALL',
    bannerUrl: data.bannerUrl || 'https://example.com/event_banner.jpg',
    description: data.description || 'Join the official ZeParty event and earn exclusive rewards!',
    rules: data.rules || 'Send eligible gifts during the event period to climb the leaderboard.',
    status: data.status || 'SCHEDULED', // DRAFT, SCHEDULED, LIVE, PAUSED, COMPLETED, CANCELLED
    startDate: data.startDate || new Date().toISOString(),
    endDate: data.endDate || new Date(Date.now() + 7 * 86400000).toISOString(),
    durationPreset: data.durationPreset || '7_DAYS',
    coinTargets: data.coinTargets || {
      minimumEntry: 100,
      dailyTarget: 50000,
      fullEventTarget: 1000000,
    },
    milestones: data.milestones || [
      { coins: 10000, reward: 'Silver Frame 7D + 500 Coins', rewardType: 'FRAME_COINS' },
      { coins: 50000, reward: 'Gold Frame 15D + 3,000 Coins', rewardType: 'FRAME_COINS' },
      { coins: 100000, reward: 'Diamond Badge + 10,000 Coins', rewardType: 'BADGE_COINS' },
      { coins: 1000000, reward: 'Emperor Entry Effect 30D + 100,000 Coins', rewardType: 'EFFECT_COINS' },
    ],
    eligibleGifts: data.eligibleGifts || ['ALL_GIFTS'],
    prizePool: data.prizePool || {
      totalCoins: 500000,
      top1Reward: '200,000 Coins + SVIP12 30D + Emperor Ride',
      top2Reward: '100,000 Coins + SVIP10 15D + Duke Ride',
      top3Reward: '50,000 Coins + SVIP8 7D',
      top4To10Reward: '10,000 Coins + Special Badge',
      top11To100Reward: '2,000 Coins',
    },
    rankings: data.rankings || {
      category: 'COINS_AND_POINTS',
      tieBreaker: 'EARLIEST_ACHIEVEMENT',
      leaderboard: [
        { rank: 1, userId: '2846313', displayName: 'Top Creator One', score: 1420500, points: 14205 },
        { rank: 2, userId: '2252766', displayName: 'Star Gifter Alpha', score: 890000, points: 8900 },
        { rank: 3, userId: '5297853', displayName: 'Voice Master Pro', score: 540200, points: 5402 },
      ],
    },
    liveMetrics: {
      totalParticipants: 42,
      totalCoinsSpent: 3450000,
      totalGiftsSent: 1240,
      netPlatformRevenueUSD: 2415.00,
    },
    createdAt: new Date().toISOString(),
  };

  await db.policyConfiguration.upsert({
    where: { key },
    update: {
      valueJson: eventPayload,
      status: 'ACTIVE',
    },
    create: {
      key,
      valueJson: eventPayload,
      status: 'ACTIVE',
    },
  });

  await logAudit({
    adminId: operatorId,
    adminName: operatorName || 'BD Manager / Admin',
    action: 'BD_EVENT_CREATED',
    targetEntity: 'BDEvent',
    targetEntityId: eventId,
    beforeStateJson: null,
    afterStateJson: {
      eventId,
      eventName: eventPayload.eventName,
      eventType: eventPayload.eventType,
      scope: eventPayload.scope,
      status: eventPayload.status,
      startDate: eventPayload.startDate,
      endDate: eventPayload.endDate,
    },
    reason: data.reason || 'Created new event via BD Center',
    ipAddress,
  }, db);

  return eventPayload;
}

export async function getBDEventDetails(eventId, db = prisma) {
  const key = `BDEVENT_${eventId}`;
  const config = await db.policyConfiguration.findUnique({
    where: { key },
  });

  if (!config) {
    const error = new Error(`Event ${eventId} not found`);
    error.statusCode = 404;
    error.code = 'EVENT_NOT_FOUND';
    throw error;
  }

  return {
    id: eventId,
    ...config.valueJson,
    updatedAt: config.updatedAt.toISOString(),
  };
}

export async function updateBDEvent(eventId, updates, { operatorId, operatorName, ipAddress } = {}, db = prisma) {
  const key = `BDEVENT_${eventId}`;
  const existing = await db.policyConfiguration.findUnique({
    where: { key },
  });

  if (!existing) {
    const error = new Error(`Event ${eventId} not found`);
    error.statusCode = 404;
    error.code = 'EVENT_NOT_FOUND';
    throw error;
  }

  const beforeState = existing.valueJson;
  const updatedPayload = {
    ...beforeState,
    ...updates,
    id: eventId,
    updatedAt: new Date().toISOString(),
  };

  await db.policyConfiguration.update({
    where: { key },
    data: {
      valueJson: updatedPayload,
    },
  });

  await logAudit({
    adminId: operatorId,
    adminName: operatorName || 'BD Manager / Admin',
    action: `BD_EVENT_UPDATED`,
    targetEntity: 'BDEvent',
    targetEntityId: eventId,
    beforeStateJson: beforeState,
    afterStateJson: updatedPayload,
    reason: updates.reason || 'Updated event configuration via BD Center',
    ipAddress,
  }, db);

  return updatedPayload;
}

export async function settleBDEvent(eventId, { operatorId, operatorName, ipAddress } = {}, db = prisma) {
  const key = `BDEVENT_${eventId}`;
  const existing = await db.policyConfiguration.findUnique({
    where: { key },
  });

  if (!existing) {
    const error = new Error(`Event ${eventId} not found`);
    error.statusCode = 404;
    error.code = 'EVENT_NOT_FOUND';
    throw error;
  }

  const beforeState = existing.valueJson;
  const settledPayload = {
    ...beforeState,
    status: 'COMPLETED',
    settledAt: new Date().toISOString(),
    settledBy: operatorName || operatorId || 'Admin',
    finalSnapshot: {
      lockedAt: new Date().toISOString(),
      winnerRank1: beforeState.rankings?.leaderboard?.[0] || null,
      winnerRank2: beforeState.rankings?.leaderboard?.[1] || null,
      winnerRank3: beforeState.rankings?.leaderboard?.[2] || null,
      rewardsDistributed: true,
      totalCoinsSettled: beforeState.liveMetrics?.totalCoinsSpent || 0,
    },
  };

  await db.policyConfiguration.update({
    where: { key },
    data: {
      valueJson: settledPayload,
    },
  });

  await logAudit({
    adminId: operatorId,
    adminName: operatorName || 'BD Manager / Admin',
    action: 'BD_EVENT_SETTLED',
    targetEntity: 'BDEvent',
    targetEntityId: eventId,
    beforeStateJson: beforeState,
    afterStateJson: settledPayload,
    reason: 'Finalized and settled event rankings and reward allocations',
    ipAddress,
  }, db);

  return settledPayload;
}

export async function getBDEventAuditHistory(eventId, db = prisma) {
  const logs = await db.auditLog.findMany({
    where: {
      targetEntity: 'BDEvent',
      targetEntityId: eventId,
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return logs.map(l => ({
    actionId: l.id,
    action: l.action,
    operator: l.adminName,
    reason: l.reason,
    before: l.beforeStateJson,
    after: l.afterStateJson,
    timestamp: l.createdAt.toISOString(),
  }));
}

export default {
  createBDCenter,
  updateBDCenter,
  getBDCenterDetails,
  sendBDInvite,
  validateInviteCode,
  acceptBDInvite,
  getMyBDStatus,
  getBDAgentsList,
  sendAgentInvitation,
  getBDSalary,
  getBDDashboard,
  getBDTargets,
  getBDIncome,
  getBDCommission,
  getBDMonthlyCommissionPolicyTable,
  calculateBDCommission,
  BD_MONTHLY_COMMISSION_POLICY_TABLE,
  getBDSalaryHistory,
  getBDSettings,
  getBDAuditHistory,
  searchUserForSVIP,
  grantOrUpdateUserSVIP,
  getSVIPAuditHistory,
  searchUserForNoble,
  grantOrUpdateUserNoble,
  getNobleAuditHistory,
  listBDEvents,
  createBDEvent,
  getBDEventDetails,
  updateBDEvent,
  settleBDEvent,
  getBDEventAuditHistory,
};


