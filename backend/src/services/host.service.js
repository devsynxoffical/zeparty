import prisma from '../config/database.js';
import hostRepository from '../repositories/host.repository.js';
import policyService from './policy.service.js';
import * as notificationService from './notification.service.js';
import emailService from './email.service.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || 'SYSTEM',
        adminName: adminName || 'System',
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
    console.error('Failed to write audit log in host.service:', err);
  }
}

export async function applyForHost({ userId, hostType, idCardFrontUrl, idCardBackUrl, videoSampleUrl, ipAddress }, db = prisma) {
  // Check if active profile exists
  const existingProfile = await hostRepository.findHostProfileByUserId(userId, db);
  if (existingProfile && existingProfile.hostStatus === 'ACTIVE') {
    const error = new Error('User already has an active host profile');
    error.statusCode = 409;
    error.code = 'HOST_PROFILE_ALREADY_EXISTS';
    throw error;
  }

  // Check if pending application exists
  const pendingApp = await hostRepository.findPendingApplicationByUserId(userId, db);
  if (pendingApp) {
    const error = new Error('User already has a pending host verification application');
    error.statusCode = 409;
    error.code = 'PENDING_APPLICATION_EXISTS';
    throw error;
  }

  const application = await hostRepository.createApplication(
    {
      userId,
      hostType,
      idCardFrontUrl,
      idCardBackUrl,
      videoSampleUrl,
    },
    db
  );

  await logAudit({
    adminId: userId,
    adminName: 'User',
    action: 'HOST_APPLICATION_SUBMITTED',
    targetEntity: 'HostApplication',
    targetEntityId: application.id,
    afterStateJson: { hostType, status: 'APPLIED' },
    ipAddress,
  }, db);

  return application;
}

export async function reviewHostApplication(
  applicationId,
  { status, rejectionReason, adminId, adminName, ipAddress },
  db = prisma
) {
  const application = await hostRepository.findApplicationById(applicationId, db);
  if (!application) {
    const error = new Error('Host application not found');
    error.statusCode = 404;
    error.code = 'APPLICATION_NOT_FOUND';
    throw error;
  }

  if (application.status !== 'APPLIED') {
    const error = new Error(`Application has already been reviewed (current status: ${application.status})`);
    error.statusCode = 400;
    error.code = 'APPLICATION_ALREADY_REVIEWED';
    throw error;
  }

  // Fetch target user for notifications
  const targetUser = await db.user.findUnique({
    where: { id: application.userId },
    include: { profile: true },
  });

  const username = targetUser?.username || 'Host';
  const userEmail = targetUser?.email;

  if (status === 'ACTIVE' || status === 'APPROVED') {
    // Atomic approval & host profile provisioning
    const result = await db.$transaction(async (tx) => {
      const updatedApp = await hostRepository.updateApplication(
        applicationId,
        {
          status: 'ACTIVE',
          reviewerAdminId: adminId,
          reviewedAt: new Date(),
        },
        tx
      );

      // Create or update HostProfile
      const hostProfile = await tx.hostProfile.upsert({
        where: { userId: application.userId },
        update: {
          hostType: application.hostType,
          hostStatus: 'ACTIVE',
        },
        create: {
          userId: application.userId,
          hostType: application.hostType,
          hostStatus: 'ACTIVE',
          hostLevel: 1,
        },
      });

      // Update userType to HOST
      await tx.user.update({
        where: { id: application.userId },
        data: { userType: 'HOST' },
      });

      return { application: updatedApp, hostProfile };
    });

    await logAudit({
      adminId,
      adminName,
      action: 'HOST_APPLICATION_APPROVED',
      targetEntity: 'HostApplication',
      targetEntityId: applicationId,
      beforeStateJson: { status: application.status },
      afterStateJson: { status: 'ACTIVE', hostProfileId: result.hostProfile.id },
      ipAddress,
    }, db);

    // 1. Dispatch In-App Notification
    try {
      const readableType =
        application.hostType === 'BOTH'
          ? 'Live Video & Social Audio'
          : application.hostType === 'AUDIO_HOST'
          ? 'Social Audio Party'
          : 'Live Video';

      await notificationService.sendNotification({
        recipientId: application.userId,
        title: 'Host Application Approved! 🎉',
        body: `Congratulations @${username}! Your application for ${readableType} Host has been approved. You can now start broadcasting, hosting parties, and competing in PK battles.`,
        type: 'SYSTEM',
        category: 'System',
        data: {
          hostType: application.hostType,
          hostProfileId: result.hostProfile.id,
          status: 'ACTIVE',
          action: 'HOST_APPROVED',
        },
        sourceType: 'HOST_APPLICATION',
        sourceId: applicationId,
      }, db);
    } catch (notifErr) {
      console.warn('[HostService] In-app notification delivery error:', notifErr.message);
    }

    // 2. Dispatch Gmail / Email Notification
    try {
      if (userEmail) {
        await emailService.sendHostApprovalEmail({
          userEmail,
          username,
          hostType: application.hostType,
        });
      }
    } catch (emailErr) {
      console.warn('[HostService] Email dispatch error:', emailErr.message);
    }

    return result;
  } else if (status === 'REJECTED') {
    const updatedApp = await hostRepository.updateApplication(
      applicationId,
      {
        status: 'REJECTED',
        rejectionReason: rejectionReason || 'Application rejected by administrator',
        reviewerAdminId: adminId,
        reviewedAt: new Date(),
      },
      db
    );

    await logAudit({
      adminId,
      adminName,
      action: 'HOST_APPLICATION_REJECTED',
      targetEntity: 'HostApplication',
      targetEntityId: applicationId,
      beforeStateJson: { status: application.status },
      afterStateJson: { status: 'REJECTED', rejectionReason },
      reason: rejectionReason,
      ipAddress,
    }, db);

    // 1. Dispatch In-App Notification
    try {
      await notificationService.sendNotification({
        recipientId: application.userId,
        title: 'Host Application Update',
        body: `Your host verification application was not approved. Reason: ${rejectionReason || 'Did not meet compliance criteria.'}`,
        type: 'SYSTEM',
        category: 'System',
        data: {
          hostType: application.hostType,
          status: 'REJECTED',
          rejectionReason,
          action: 'HOST_REJECTED',
        },
        sourceType: 'HOST_APPLICATION',
        sourceId: applicationId,
      }, db);
    } catch (notifErr) {
      console.warn('[HostService] In-app notification delivery error:', notifErr.message);
    }

    // 2. Dispatch Gmail / Email Notification
    try {
      if (userEmail) {
        await emailService.sendHostRejectionEmail({
          userEmail,
          username,
          hostType: application.hostType,
          reason: rejectionReason,
        });
      }
    } catch (emailErr) {
      console.warn('[HostService] Email dispatch error:', emailErr.message);
    }

    return { application: updatedApp };
  } else {
    const error = new Error('Invalid review status. Must be ACTIVE or REJECTED');
    error.statusCode = 400;
    error.code = 'INVALID_STATUS';
    throw error;
  }
}

export async function updateHostProfileStatus(
  hostId,
  { hostStatus, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const host = await hostRepository.findHostProfileById(hostId, db);
  if (!host) {
    const error = new Error('Host profile not found');
    error.statusCode = 404;
    error.code = 'HOST_NOT_FOUND';
    throw error;
  }

  const updatedHost = await hostRepository.updateHostProfile(
    hostId,
    { hostStatus },
    db
  );

  await logAudit({
    adminId,
    adminName,
    action: 'HOST_STATUS_UPDATED',
    targetEntity: 'HostProfile',
    targetEntityId: hostId,
    beforeStateJson: { hostStatus: host.hostStatus },
    afterStateJson: { hostStatus },
    reason,
    ipAddress,
  }, db);

  return updatedHost;
}

export async function getHostDetails(hostId, db = prisma) {
  const host = await hostRepository.findHostProfileById(hostId, db);
  if (!host) {
    const error = new Error('Host profile not found');
    error.statusCode = 404;
    error.code = 'HOST_NOT_FOUND';
    throw error;
  }

  // Resolve dynamic host level policy info
  const policyType = host.hostType === 'AUDIO_HOST' ? 'AUDIO_HOST' : 'LIVE_HOST';
  const effectivePolicy = await policyService.getEffectivePolicy(policyType, db);

  return {
    ...host,
    totalDiamondsEarnedMonth: host.totalDiamondsEarnedMonth ? host.totalDiamondsEarnedMonth.toString() : '0',
    effectivePolicySummary: effectivePolicy?.summary || null,
  };
}

export async function getHostProfileByUserId(userId, db = prisma) {
  const host = await hostRepository.findHostProfileByUserId(userId, db);
  if (!host) {
    const error = new Error('Host profile not found for user');
    error.statusCode = 404;
    error.code = 'HOST_NOT_FOUND';
    throw error;
  }

  return {
    ...host,
    totalDiamondsEarnedMonth: host.totalDiamondsEarnedMonth ? host.totalDiamondsEarnedMonth.toString() : '0',
  };
}

export async function recordHostPerformance(
  hostId,
  { liveHoursDelta = 0, diamondsDelta = 0n, targetDaysDelta = 0 },
  db = prisma
) {
  return await hostRepository.updateHostPerformance(
    hostId,
    {
      liveHoursDelta,
      diamondsDelta: BigInt(diamondsDelta),
      targetDaysDelta,
    },
    db
  );
}

export async function getMyHostApplication(userId, db = prisma) {
  return await hostRepository.findLatestApplicationByUserId(userId, db);
}

export async function getHostIncomeDashboard(userId, db = prisma) {
  const host = await hostRepository.findHostProfileByUserId(userId, db);
  const wallet = await db.wallet.findUnique({
    where: { userId },
  });

  const isLiveHost = host?.hostType === 'LIVE_HOST';
  const eligibleDiamonds = Number(wallet?.diamondBalance || 0n);

  // 25-level target tiers (ZeParty 2026 Policy)
  const tiers = [
    { level: 1, targetDiamonds: 25000, durationDays: 10, basicSalaryUSD: 2.00, hostSalaryUSD: 1.60, agencySalaryUSD: 0.40, specialId: '/' },
    { level: 2, targetDiamonds: 50000, durationDays: 10, basicSalaryUSD: 4.00, hostSalaryUSD: 3.20, agencySalaryUSD: 0.80, specialId: '/' },
    { level: 3, targetDiamonds: 100000, durationDays: 10, basicSalaryUSD: 8.00, hostSalaryUSD: 6.40, agencySalaryUSD: 1.60, specialId: '/' },
    { level: 4, targetDiamonds: 250000, durationDays: 10, basicSalaryUSD: 20.00, hostSalaryUSD: 16.00, agencySalaryUSD: 4.00, specialId: '/' },
    { level: 5, targetDiamonds: 500000, durationDays: 8, basicSalaryUSD: 40.00, hostSalaryUSD: 32.00, agencySalaryUSD: 8.00, specialId: '/' },
    { level: 6, targetDiamonds: 750000, durationDays: 8, basicSalaryUSD: 60.00, hostSalaryUSD: 48.00, agencySalaryUSD: 12.00, specialId: '/' },
    { level: 7, targetDiamonds: 1000000, durationDays: 8, basicSalaryUSD: 80.00, hostSalaryUSD: 64.00, agencySalaryUSD: 16.00, specialId: '/' },
    { level: 8, targetDiamonds: 1500000, durationDays: 8, basicSalaryUSD: 120.00, hostSalaryUSD: 96.00, agencySalaryUSD: 24.00, specialId: '/' },
    { level: 9, targetDiamonds: 2000000, durationDays: 8, basicSalaryUSD: 160.00, hostSalaryUSD: 128.00, agencySalaryUSD: 32.00, specialId: '/' },
    { level: 10, targetDiamonds: 2500000, durationDays: 8, basicSalaryUSD: 200.00, hostSalaryUSD: 160.00, agencySalaryUSD: 40.00, specialId: '/' },
    { level: 11, targetDiamonds: 3000000, durationDays: 5, basicSalaryUSD: 240.00, hostSalaryUSD: 192.00, agencySalaryUSD: 48.00, specialId: 'Special ID 3 Days' },
    { level: 12, targetDiamonds: 3500000, durationDays: 5, basicSalaryUSD: 280.00, hostSalaryUSD: 224.00, agencySalaryUSD: 56.00, specialId: 'Special ID 3 Days' },
    { level: 13, targetDiamonds: 4000000, durationDays: 5, basicSalaryUSD: 320.00, hostSalaryUSD: 256.00, agencySalaryUSD: 64.00, specialId: 'Special ID 3 Days' },
    { level: 14, targetDiamonds: 4500000, durationDays: 5, basicSalaryUSD: 360.00, hostSalaryUSD: 288.00, agencySalaryUSD: 72.00, specialId: 'Special ID 7 Days' },
    { level: 15, targetDiamonds: 5000000, durationDays: 5, basicSalaryUSD: 400.00, hostSalaryUSD: 320.00, agencySalaryUSD: 80.00, specialId: 'Special ID 15 Days' },
    { level: 16, targetDiamonds: 6000000, durationDays: 5, basicSalaryUSD: 480.00, hostSalaryUSD: 384.00, agencySalaryUSD: 96.00, specialId: 'Special ID 15 Days' },
    { level: 17, targetDiamonds: 7000000, durationDays: 5, basicSalaryUSD: 560.00, hostSalaryUSD: 448.00, agencySalaryUSD: 112.00, specialId: 'Special ID 15 Days' },
    { level: 18, targetDiamonds: 8000000, durationDays: 5, basicSalaryUSD: 640.00, hostSalaryUSD: 512.00, agencySalaryUSD: 128.00, specialId: 'Special ID 30 Days' },
    { level: 19, targetDiamonds: 9000000, durationDays: 5, basicSalaryUSD: 720.00, hostSalaryUSD: 576.00, agencySalaryUSD: 144.00, specialId: 'Special ID 30 Days' },
    { level: 20, targetDiamonds: 10000000, durationDays: 5, basicSalaryUSD: 800.00, hostSalaryUSD: 640.00, agencySalaryUSD: 160.00, specialId: 'Special ID 60 Days' },
    { level: 21, targetDiamonds: 15000000, durationDays: 5, basicSalaryUSD: 1200.00, hostSalaryUSD: 960.00, agencySalaryUSD: 240.00, specialId: 'Special ID 60 Days' },
    { level: 22, targetDiamonds: 20000000, durationDays: 5, basicSalaryUSD: 1600.00, hostSalaryUSD: 1280.00, agencySalaryUSD: 320.00, specialId: 'Special ID 60 Days' },
    { level: 23, targetDiamonds: 30000000, durationDays: 5, basicSalaryUSD: 2400.00, hostSalaryUSD: 1920.00, agencySalaryUSD: 480.00, specialId: 'Special ID 90 Days' },
    { level: 24, targetDiamonds: 40000000, durationDays: 5, basicSalaryUSD: 3200.00, hostSalaryUSD: 2560.00, agencySalaryUSD: 640.00, specialId: 'Special ID 90 Days' },
    { level: 25, targetDiamonds: 50000000, durationDays: 5, basicSalaryUSD: 4000.00, hostSalaryUSD: 3200.00, agencySalaryUSD: 800.00, specialId: 'Special ID 120 Days' },
  ];

  // Determine current active target tier (target tier 1 is base policy)
  let activeTier = tiers[0];
  let targetAchieved = false;
  for (const t of tiers) {
    if (eligibleDiamonds >= t.targetDiamonds) {
      activeTier = t;
      targetAchieved = true;
    }
  }

  // Daily hosting requirements
  const requiredDailyHours = isLiveHost ? 1 : 2;
  const dailyTargetMinutes = requiredDailyHours * 60;
  // Genuinely tracked attendance minutes: starts strictly at 0 for new host
  const completedMinutesToday = Number(host?.todayOnlineMinutes || 0);

  // Completed valid days: starts strictly at 0
  const completedValidDays = Number(host?.targetDaysAchieved || 0);
  const requiredDays = activeTier.durationDays;

  // Earned salaries for the current cycle: strictly $0.00 until confirmed target is achieved
  const basicTotalSalary = targetAchieved ? activeTier.basicSalaryUSD : 0.00;
  const hostBasicSalary = targetAchieved ? activeTier.hostSalaryUSD : 0.00;
  const agencyShareEarned = targetAchieved ? activeTier.agencySalaryUSD : 0.00;
  const specialIdBonusEarned = targetAchieved && activeTier.specialId !== '/' ? activeTier.specialId : '$0.00';

  // Progress bar strictly starts at 0%
  const progressPercent = Math.min(100, Math.floor((eligibleDiamonds / activeTier.targetDiamonds) * 100));

  // Today attendance status
  let todayStatus = 'Not started';
  if (completedMinutesToday >= dailyTargetMinutes) {
    todayStatus = 'Completed';
  } else if (completedMinutesToday > 0) {
    todayStatus = 'In progress';
  }

  // Fetch real database settlement records & withdrawal requests for this host
  const [settlementRecords, withdrawalRequests] = await Promise.all([
    db.settlementRecord.findMany({
      where: { userId, recipientType: 'HOST' },
      orderBy: { createdAt: 'desc' },
      take: 20,
    }),
    db.withdrawalRequest.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 20,
    }),
  ]);

  // Available, pending and lifetime totals from genuine database records
  const totalEarnedUSD = settlementRecords
    .filter(r => r.status === 'PAID')
    .reduce((sum, r) => sum + Number(r.netPayableUSD), 0);

  const pendingSalaryUSD = settlementRecords
    .filter(r => r.status === 'CALCULATED' || r.status === 'APPROVED')
    .reduce((sum, r) => sum + Number(r.netPayableUSD), 0);

  const pendingWithdrawalUSD = withdrawalRequests
    .filter(w => w.status === 'PENDING')
    .reduce((sum, w) => sum + Number(w.amountUSD), 0);

  const totalWithdrawnUSD = Number(wallet?.totalWithdrawnUSD || 0.00);

  // Available host salary in USD (converts eligible diamonds or paid settlements)
  // 12,500 diamonds = $1 USD
  const availableHostSalaryUSD = Math.max(0, Math.round(((eligibleDiamonds / 12500) - pendingWithdrawalUSD) * 100) / 100);

  // History entries combined and formatted
  const combinedHistory = [
    ...settlementRecords.map(s => ({
      id: s.id,
      type: 'SALARY_SETTLEMENT',
      title: 'Host Cycle Salary',
      amountUSD: Number(s.netPayableUSD),
      status: s.status,
      date: s.createdAt,
    })),
    ...withdrawalRequests.map(w => ({
      id: w.id,
      type: 'WITHDRAWAL',
      title: 'Salary Withdrawal',
      amountUSD: Number(w.amountUSD),
      status: w.status,
      date: w.createdAt,
    })),
  ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  // 15-day transfer eligibility countdown
  const now = new Date();
  const hostCreated = host?.createdAt || now;
  const daysSinceActive = Math.floor((now.getTime() - hostCreated.getTime()) / (24 * 60 * 60 * 1000));
  const remainingDaysToWithdraw = Math.max(0, 15 - daysSinceActive);

  return {
    hostIdentity: {
      userId,
      uniqueId: host?.user?.username || userId,
      hostName: host?.user?.profile?.displayName || host?.user?.username || 'Host',
      avatarUrl: host?.user?.avatarUrl || '',
      hostLevel: host?.hostLevel || 1,
      hostType: host?.hostType || 'AUDIO_HOST',
      agencyId: host?.agencyId || null,
      agencyName: host?.agency?.agencyName || 'No agency joined',
    },
    newHostInitialDisplay: {
      achievedCoinsOrDiamonds: eligibleDiamonds,
      targetProgressBarPercent: progressPercent,
      basicTotalSalaryUSD: Number(basicTotalSalary.toFixed(2)),
      hostBasicSalaryUSD: Number(hostBasicSalary.toFixed(2)),
      agencyShareUSD: Number(agencyShareEarned.toFixed(2)),
      specialIdBonus: specialIdBonusEarned,
      completedValidDays,
      requiredValidDays: requiredDays,
      todayTrackedMinutes: completedMinutesToday,
      requiredDailyMinutes: dailyTargetMinutes,
      todayStatus,
      availableHostSalaryUSD: Number(availableHostSalaryUSD.toFixed(2)),
      pendingSalaryUSD: Number(pendingSalaryUSD.toFixed(2)),
      pendingWithdrawalUSD: Number(pendingWithdrawalUSD.toFixed(2)),
      totalEarnedUSD: Number(totalEarnedUSD.toFixed(2)),
      totalWithdrawnUSD: Number(totalWithdrawnUSD.toFixed(2)),
      historyRecordsCount: combinedHistory.length,
    },
    // Backwards-compatible legacy properties for existing UI widgets
    currentLevel: activeTier.level,
    targetDiamonds: activeTier.targetDiamonds,
    eligibleDiamonds,
    dollarTarget: activeTier.basicSalaryUSD,
    achievedDollars: targetAchieved ? activeTier.hostSalaryUSD : 0.00,
    remainingDiamonds: Math.max(0, activeTier.targetDiamonds - eligibleDiamonds),
    remainingDollars: Math.max(0, activeTier.basicSalaryUSD - (targetAchieved ? activeTier.hostSalaryUSD : 0)),
    progressPercent,
    specialIdBonus: specialIdBonusEarned,
    durationDays: requiredDays,
    targetPeriod: `15 Days (${now.toLocaleString('default', { month: 'long', year: 'numeric' })})`,
    targetStatus: targetAchieved ? 'TARGET_ACHIEVED' : 'IN_PROGRESS',
    availableHostSalary: availableHostSalaryUSD,
    pendingSalary: pendingSalaryUSD,
    pendingWithdrawal: pendingWithdrawalUSD,
    totalEarned: totalEarnedUSD,
    totalWithdrawn: totalWithdrawnUSD,
    history: combinedHistory,
    hasRecords: combinedHistory.length > 0,
    policyTiers: tiers, // Policy salary table showing potential payouts (clearly labelled as policy)
    policyNotes: {
      roomOwnerReward: 'If you send users to a room, the room owner will receive a 5% reward weekly.',
      incompleteDaysRule: 'If the host does not complete the valid days, he will receive only 50% of the target.',
      noAgencyRequired: isLiveHost ? 'No agency is required — you can register directly through the app and become a Live Host yourself.' : undefined,
    },
    withdrawalEligibility: {
      isEligible: availableHostSalaryUSD > 0 && remainingDaysToWithdraw === 0,
      holdingPeriodDays: 15,
      remainingDays: remainingDaysToWithdraw,
      notice: 'The host can transfer eligible diamond earnings to an authorized Coin Seller after 15 days and then request/receive withdrawal according to the configured withdrawal process. The host is required to complete at least 2 hours of hosting activity every day.',
    },
    dailyHosting: {
      dailyRequiredHours: requiredDailyHours,
      completedMinutesToday,
      remainingMinutesToday: Math.max(0, dailyTargetMinutes - completedMinutesToday),
      isDailyTargetMet: completedMinutesToday >= dailyTargetMinutes,
      hostingType: isLiveHost ? 'Live Video Hosting (1h daily for 10 days)' : 'Audio Hosting (2h daily)',
      todayStatus,
    },
  };
}

export async function becomeLiveHost(userId, { phone, otpCode, idCardFrontUrl, idCardBackUrl }, { ipAddress } = {}, db = prisma) {
  const existingHost = await hostRepository.findHostProfileByUserId(userId, db);
  if (existingHost && existingHost.hostStatus === 'ACTIVE') {
    return { status: 'ACTIVE', message: 'You are already an active Live Host', hostProfile: existingHost };
  }

  const application = await applyForHost({
    userId,
    hostType: 'LIVE_HOST',
    idCardFrontUrl: idCardFrontUrl || 'https://assets.zeparty.app/verifications/id_front.jpg',
    idCardBackUrl: idCardBackUrl || 'https://assets.zeparty.app/verifications/id_back.jpg',
    videoSampleUrl: 'https://assets.zeparty.app/verifications/selfie_liveness.mp4',
    ipAddress,
  }, db);

  return {
    status: 'SUBMITTED',
    message: 'Live Host application and liveness verification submitted for review',
    application,
  };
}

/**
 * Module 14: Agency Host Policy Table (Levels 1–25)
 */
export async function getAgencyHostPolicyTable() {
  const levels = [
    { level: 1, diamondTarget: 25000, validDays: 10, basicTotalSalary: 2, hostSalary: 1.60, agencySalary: 0.40, specialIdBonus: '/' },
    { level: 2, diamondTarget: 50000, validDays: 10, basicTotalSalary: 4, hostSalary: 3.20, agencySalary: 0.80, specialIdBonus: '/' },
    { level: 3, diamondTarget: 100000, validDays: 10, basicTotalSalary: 8, hostSalary: 6.40, agencySalary: 1.60, specialIdBonus: '/' },
    { level: 4, diamondTarget: 250000, validDays: 10, basicTotalSalary: 20, hostSalary: 16.00, agencySalary: 4.00, specialIdBonus: '/' },
    { level: 5, diamondTarget: 500000, validDays: 8, basicTotalSalary: 40, hostSalary: 32.00, agencySalary: 8.00, specialIdBonus: '/' },
    { level: 6, diamondTarget: 750000, validDays: 8, basicTotalSalary: 60, hostSalary: 48.00, agencySalary: 12.00, specialIdBonus: '/' },
    { level: 7, diamondTarget: 1000000, validDays: 8, basicTotalSalary: 80, hostSalary: 64.00, agencySalary: 16.00, specialIdBonus: '/' },
    { level: 8, diamondTarget: 1500000, validDays: 8, basicTotalSalary: 120, hostSalary: 96.00, agencySalary: 24.00, specialIdBonus: '/' },
    { level: 9, diamondTarget: 2000000, validDays: 8, basicTotalSalary: 160, hostSalary: 128.00, agencySalary: 32.00, specialIdBonus: '/' },
    { level: 10, diamondTarget: 2500000, validDays: 8, basicTotalSalary: 200, hostSalary: 160.00, agencySalary: 40.00, specialIdBonus: '/' },
    { level: 11, diamondTarget: 3000000, validDays: 5, basicTotalSalary: 240, hostSalary: 192.00, agencySalary: 48.00, specialIdBonus: 'Special ID 3 Days' },
    { level: 12, diamondTarget: 3500000, validDays: 5, basicTotalSalary: 280, hostSalary: 224.00, agencySalary: 56.00, specialIdBonus: 'Special ID 3 Days' },
    { level: 13, diamondTarget: 4000000, validDays: 5, basicTotalSalary: 320, hostSalary: 256.00, agencySalary: 64.00, specialIdBonus: 'Special ID 3 Days' },
    { level: 14, diamondTarget: 4500000, validDays: 5, basicTotalSalary: 360, hostSalary: 288.00, agencySalary: 72.00, specialIdBonus: 'Special ID 7 Days' },
    { level: 15, diamondTarget: 5000000, validDays: 5, basicTotalSalary: 400, hostSalary: 320.00, agencySalary: 80.00, specialIdBonus: 'Special ID 15 Days' },
    { level: 16, diamondTarget: 6000000, validDays: 5, basicTotalSalary: 480, hostSalary: 384.00, agencySalary: 96.00, specialIdBonus: 'Special ID 15 Days' },
    { level: 17, diamondTarget: 7000000, validDays: 5, basicTotalSalary: 560, hostSalary: 448.00, agencySalary: 112.00, specialIdBonus: 'Special ID 15 Days' },
    { level: 18, diamondTarget: 8000000, validDays: 5, basicTotalSalary: 640, hostSalary: 512.00, agencySalary: 128.00, specialIdBonus: 'Special ID 30 Days' },
    { level: 19, diamondTarget: 9000000, validDays: 5, basicTotalSalary: 720, hostSalary: 576.00, agencySalary: 144.00, specialIdBonus: 'Special ID 30 Days' },
    { level: 20, diamondTarget: 10000000, validDays: 5, basicTotalSalary: 800, hostSalary: 640.00, agencySalary: 160.00, specialIdBonus: 'Special ID 60 Days' },
    { level: 21, diamondTarget: 15000000, validDays: 5, basicTotalSalary: 1200, hostSalary: 960.00, agencySalary: 240.00, specialIdBonus: 'Special ID 60 Days' },
    { level: 22, diamondTarget: 20000000, validDays: 5, basicTotalSalary: 1600, hostSalary: 1280.00, agencySalary: 320.00, specialIdBonus: 'Special ID 60 Days' },
    { level: 23, diamondTarget: 30000000, validDays: 5, basicTotalSalary: 2400, hostSalary: 1920.00, agencySalary: 480.00, specialIdBonus: 'Special ID 90 Days' },
    { level: 24, diamondTarget: 40000000, validDays: 5, basicTotalSalary: 3200, hostSalary: 2560.00, agencySalary: 640.00, specialIdBonus: 'Special ID 90 Days' },
    { level: 25, diamondTarget: 50000000, validDays: 5, basicTotalSalary: 4000, hostSalary: 3200.00, agencySalary: 800.00, specialIdBonus: 'Special ID 120 Days' },
  ];

  return {
    cycleDays: 15,
    dailyRequirementHours: 2.0,
    dailyRequirementUnmuted: true,
    levels,
  };
}

/**
 * Module 15: Live Host Direct Registration Policy Table (Levels 1–25)
 */
export async function getLiveHostPolicyTable() {
  const levels = [
    { level: 1, diamondTarget: 25000, validDays: 10, basicSalaryUSD: 2 },
    { level: 2, diamondTarget: 50000, validDays: 10, basicSalaryUSD: 4 },
    { level: 3, diamondTarget: 100000, validDays: 10, basicSalaryUSD: 8 },
    { level: 4, diamondTarget: 250000, validDays: 10, basicSalaryUSD: 20 },
    { level: 5, diamondTarget: 500000, validDays: 8, basicSalaryUSD: 40 },
    { level: 6, diamondTarget: 750000, validDays: 8, basicSalaryUSD: 60 },
    { level: 7, diamondTarget: 1000000, validDays: 8, basicSalaryUSD: 80 },
    { level: 8, diamondTarget: 1500000, validDays: 8, basicSalaryUSD: 120 },
    { level: 9, diamondTarget: 2000000, validDays: 8, basicSalaryUSD: 160 },
    { level: 10, diamondTarget: 2500000, validDays: 8, basicSalaryUSD: 200 },
    { level: 11, diamondTarget: 3000000, validDays: 5, basicSalaryUSD: 240 },
    { level: 12, diamondTarget: 3500000, validDays: 5, basicSalaryUSD: 280 },
    { level: 13, diamondTarget: 4000000, validDays: 5, basicSalaryUSD: 320 },
    { level: 14, diamondTarget: 4500000, validDays: 5, basicSalaryUSD: 360 },
    { level: 15, diamondTarget: 5000000, validDays: 5, basicSalaryUSD: 400 },
    { level: 16, diamondTarget: 6000000, validDays: 5, basicSalaryUSD: 480 },
    { level: 17, diamondTarget: 7000000, validDays: 5, basicSalaryUSD: 560 },
    { level: 18, diamondTarget: 8000000, validDays: 5, basicSalaryUSD: 640 },
    { level: 19, diamondTarget: 9000000, validDays: 5, basicSalaryUSD: 720 },
    { level: 20, diamondTarget: 10000000, validDays: 5, basicSalaryUSD: 800 },
    { level: 21, diamondTarget: 15000000, validDays: 5, basicSalaryUSD: 1200 },
    { level: 22, diamondTarget: 20000000, validDays: 5, basicSalaryUSD: 1600 },
    { level: 23, diamondTarget: 30000000, validDays: 5, basicSalaryUSD: 2400 },
    { level: 24, diamondTarget: 40000000, validDays: 5, basicSalaryUSD: 3200 },
    { level: 25, diamondTarget: 50000000, validDays: 5, basicSalaryUSD: 4000 },
  ];

  return {
    cycleDays: 15,
    dailyRequirementHours: 1.0,
    directPlatformSalary: true,
    agencyCommissionDeducted: 0,
    levels,
  };
}

/**
 * Remove Host Role from Host and Creator Registry
 * Revokes host status and agency membership while preserving the user account,
 * unique ID, chats, personal wallet balances, and historical earnings records.
 */
export async function removeHostRole({ hostProfileId, adminId, adminName, reason, ipAddress }, db = prisma) {
  const host = await db.hostProfile.findUnique({
    where: { id: hostProfileId },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          email: true,
          userType: true,
          profile: true,
        },
      },
      agency: true,
    },
  });

  if (!host) {
    const error = new Error('Host registration not found');
    error.statusCode = 404;
    error.code = 'HOST_NOT_FOUND';
    throw error;
  }

  return await db.$transaction(async (tx) => {
    // 1. Mark host profile as REJECTED / inactive
    const updatedHost = await tx.hostProfile.update({
      where: { id: hostProfileId },
      data: {
        hostStatus: 'REJECTED',
        agencyId: null,
      },
    });

    // 2. Remove active agency membership if any
    await tx.agencyMember.deleteMany({
      where: { hostProfileId },
    });

    // 3. If user has no other active host profiles, revert userType to USER
    const otherActiveHosts = await tx.hostProfile.findMany({
      where: {
        userId: host.userId,
        id: { not: hostProfileId },
        hostStatus: 'ACTIVE',
      },
    });

    if (otherActiveHosts.length === 0) {
      await tx.user.update({
        where: { id: host.userId },
        data: { userType: 'USER' },
      });
    }

    // 4. Log audit log
    await logAudit(
      {
        adminId,
        adminName,
        action: 'HOST_ROLE_REMOVED',
        targetEntity: 'HostProfile',
        targetEntityId: hostProfileId,
        beforeStateJson: {
          hostType: host.hostType,
          hostStatus: host.hostStatus,
          agencyId: host.agencyId,
          agencyName: host.agency?.agencyName,
          userId: host.userId,
          username: host.user?.username,
        },
        afterStateJson: {
          hostStatus: 'REJECTED',
          agencyId: null,
          roleRevokedAt: new Date().toISOString(),
        },
        reason: reason || 'Host role removed by Administrator from Host Registry',
        ipAddress,
      },
      tx
    );

    return {
      success: true,
      message: `Host role successfully removed for ${host.user?.username || host.userId}. User account and personal earnings preserved.`,
      host: updatedHost,
    };
  });
}

export default {
  applyForHost,
  reviewHostApplication,
  updateHostProfileStatus,
  getHostDetails,
  getHostProfileByUserId,
  getMyHostApplication,
  recordHostPerformance,
  getHostIncomeDashboard,
  becomeLiveHost,
  getAgencyHostPolicyTable,
  getLiveHostPolicyTable,
  removeHostRole,
};

