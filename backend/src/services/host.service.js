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

export default {
  applyForHost,
  reviewHostApplication,
  updateHostProfileStatus,
  getHostDetails,
  getHostProfileByUserId,
  getMyHostApplication,
  recordHostPerformance,
};
