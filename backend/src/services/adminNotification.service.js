import prisma from '../config/database.js';
import broadcastRepository from '../repositories/notificationBroadcast.repository.js';
import notificationRepository from '../repositories/notification.repository.js';
import deviceRepository from '../repositories/device.repository.js';
import fcmAdapter from '../adapters/fcm.adapter.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';

async function logAudit(
  {
    adminId,
    adminName,
    action,
    targetEntity,
    targetEntityId,
    beforeStateJson,
    afterStateJson,
    reason,
    ipAddress,
  },
  db = prisma
) {
  try {
    let validAdminId = adminId;
    if (validAdminId) {
      const existingAdmin = await db.admin?.findUnique?.({ where: { id: validAdminId } }).catch(() => null);
      if (!existingAdmin) {
        const fallbackAdmin = await db.admin?.findFirst?.({ select: { id: true, name: true } }).catch(() => null);
        validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
        if (fallbackAdmin && !adminName) adminName = fallbackAdmin.name;
      }
    } else {
      const fallbackAdmin = await db.admin?.findFirst?.({ select: { id: true, name: true } }).catch(() => null);
      validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
      if (fallbackAdmin && !adminName) adminName = fallbackAdmin.name;
    }

    if (!validAdminId || !db.auditLog?.create) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System Automation',
        action,
        targetEntity,
        targetEntityId: targetEntityId ? String(targetEntityId) : null,
        beforeStateJson: beforeStateJson || null,
        afterStateJson: afterStateJson || null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in adminNotification.service:', err);
  }
}

/**
 * Resolves target recipient user IDs based on audience category.
 */
export async function resolveTargetUserIds(audience, customUserIds = [], db = prisma) {
  if (audience === 'Selected Users' && Array.isArray(customUserIds) && customUserIds.length > 0) {
    return customUserIds;
  }

  const normalized = String(audience || 'All Users').toLowerCase();

  if (normalized.includes('vip')) {
    const vips = await db.userProfile.findMany({
      where: { vipLevel: { gt: 0 } },
      select: { userId: true },
      take: 10000,
    });
    return vips.map((v) => v.userId);
  }

  if (normalized.includes('host')) {
    const hosts = await db.user.findMany({
      where: {
        status: 'ACTIVE',
        OR: [
          { userType: 'HOST' },
          { hostProfile: { hostStatus: 'ACTIVE' } },
        ],
      },
      select: { id: true },
      take: 10000,
    });
    return hosts.map((h) => h.id);
  }

  if (normalized.includes('active')) {
    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const activeUsers = await db.user.findMany({
      where: {
        status: 'ACTIVE',
        lastLoginAt: { gte: sevenDaysAgo },
      },
      select: { id: true },
      take: 10000,
    });
    return activeUsers.map((u) => u.id);
  }

  // Default: All active users
  const allUsers = await db.user.findMany({
    where: { status: 'ACTIVE' },
    select: { id: true },
    take: 20000,
  });
  return allUsers.map((u) => u.id);
}

/**
 * Creates and dispatches a broadcast notification campaign.
 */
export async function broadcastNotification(
  payload,
  secondArg = prisma,
  thirdArg = prisma
) {
  // Support both (payload, db) and (payload, { adminId, ... }, db)
  let db = prisma;
  let options = {};

  if (secondArg && typeof secondArg === 'object') {
    if (secondArg.user || secondArg.$transaction) {
      db = secondArg;
    } else {
      options = secondArg;
      if (thirdArg && (thirdArg.user || thirdArg.$transaction)) {
        db = thirdArg;
      }
    }
  }

  const {
    title,
    body,
    message,
    type = 'Push',
    audience = 'All Users',
    targetSegment = null,
    destination = null,
    data = {},
    customUserIds = [],
    userIds = [],
    route = null,
    adminId = options.adminId || null,
    adminName = options.adminName || 'Super Admin',
    ipAddress = options.ipAddress || '127.0.0.1',
  } = { ...payload, ...options };

  const effectiveTitle = (title || '').trim();
  const effectiveBody = (body || message || '').trim();

  if (!effectiveTitle || !effectiveBody) {
    const error = new Error('Title and body/message are required for notification broadcast');
    error.statusCode = 400;
    error.code = 'INVALID_BROADCAST_PAYLOAD';
    throw error;
  }

  const effectiveAudience = audience || targetSegment || 'All Users';
  const effectiveDestination = destination || route || data?.destination || data?.route || 'zeparty://home';
  const targetUserIds = Array.isArray(customUserIds) && customUserIds.length > 0
    ? customUserIds
    : (Array.isArray(userIds) ? userIds : []);

  // 1. Resolve Target Recipients Server-Side
  const recipientIds = (effectiveAudience === 'CUSTOM_USERS' || effectiveAudience === 'Selected Users') && targetUserIds.length > 0
    ? targetUserIds
    : await resolveTargetUserIds(effectiveAudience, targetUserIds, db);

  // Resolve valid adminId to satisfy foreign key constraint
  let validAdminId = adminId;
  if (validAdminId) {
    const existingAdmin = await db.admin.findUnique({ where: { id: validAdminId } }).catch(() => null);
    if (!existingAdmin) {
      const fallbackAdmin = await db.admin.findFirst().catch(() => null);
      validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
    }
  } else {
    const fallbackAdmin = await db.admin.findFirst().catch(() => null);
    validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
  }

  // 2. Persist Initial Broadcast Campaign Record
  const broadcast = await broadcastRepository.createBroadcast(
    {
      adminId: validAdminId,
      title: effectiveTitle,
      body: effectiveBody,
      type: type || 'Push',
      audience: effectiveAudience,
      recipientCount: recipientIds.length,
      status: 'DISPATCHING',
      metadataJson: {
        destination: effectiveDestination,
        data,
        customUserIds: customUserIds.length > 0 ? customUserIds : undefined,
        createdAt: new Date().toISOString(),
      },
    },
    db
  );

  // 3. Batch Insert In-App Notifications for Recipients (up to 500 per batch)
  if (recipientIds.length > 0) {
    const notificationRecords = recipientIds.map((userId) => ({
      userId,
      title: effectiveTitle,
      body: effectiveBody,
      type: 'MARKETING',
      category: 'System',
      dataJson: {
        ...data,
        destination: effectiveDestination,
        broadcastId: broadcast.id,
      },
      sourceType: 'CAMPAIGN',
      sourceId: broadcast.id,
      deliveryStatus: 'DELIVERED',
    }));

    const BATCH_SIZE = 500;
    for (let i = 0; i < notificationRecords.length; i += BATCH_SIZE) {
      const chunk = notificationRecords.slice(i, i + BATCH_SIZE);
      await notificationRepository.createManyNotifications(chunk, db).catch((err) => {
        console.warn('Failed batch notification insert:', err.message);
      });
    }
  }

  // 4. Multi-device Push Delivery Execution
  let dispatchStats = {
    recipientCount: recipientIds.length,
    tokensCount: 0,
    providerAcceptedCount: 0,
    failedCount: 0,
    invalidTokensCount: 0,
    destination: effectiveDestination,
    completedAt: new Date().toISOString(),
  };

  let finalStatus = 'SAVED';

  try {
    if (recipientIds.length > 0) {
      const devices = await deviceRepository.findTokensByUserIds(recipientIds, db);
      const tokens = devices.map((d) => d.deviceToken).filter(Boolean);
      dispatchStats.tokensCount = tokens.length;

      if (tokens.length > 0) {
        const pushResult = await fcmAdapter.sendMulticast({
          tokens,
          title: effectiveTitle,
          body: effectiveBody,
          data: {
            ...data,
            destination: effectiveDestination,
            broadcastId: broadcast.id,
          },
        });

        dispatchStats.providerAcceptedCount = pushResult.sentCount || 0;
        dispatchStats.failedCount = pushResult.failureCount || 0;
        dispatchStats.invalidTokensCount = (pushResult.invalidTokens || []).length;
        dispatchStats.providerStatus = pushResult.status || 'SENT';

        if (pushResult.invalidTokens && pushResult.invalidTokens.length > 0) {
          await deviceRepository.cleanupInvalidTokens(pushResult.invalidTokens, db).catch(() => {});
        }

        if (fcmAdapter.isMockMode && fcmAdapter.isMockMode()) {
          finalStatus = 'SIMULATED';
        } else if (pushResult.sentCount > 0 && pushResult.failureCount === 0) {
          finalStatus = 'PROVIDER_ACCEPTED';
        } else if (pushResult.sentCount > 0 && pushResult.failureCount > 0) {
          finalStatus = 'PARTIALLY_DELIVERED';
        } else if (pushResult.sentCount === 0 && pushResult.failureCount > 0) {
          finalStatus = 'FAILED';
        } else {
          finalStatus = 'SENT';
        }
      } else {
        finalStatus = recipientIds.length > 0 ? 'QUEUED' : 'SAVED';
      }
    }
  } catch (pushErr) {
    console.error('Push broadcast delivery error:', pushErr);
    finalStatus = 'FAILED';
    dispatchStats.error = pushErr.message;
  }

  // 5. Update Broadcast Campaign Record with Delivery Metrics
  const updatedBroadcast = await db.notificationBroadcast.update({
    where: { id: broadcast.id },
    data: {
      status: finalStatus,
      metadataJson: {
        destination: effectiveDestination,
        route: effectiveDestination,
        data,
        customUserIds: customUserIds.length > 0 ? customUserIds : undefined,
        dispatchStats,
        admin: {
          id: validAdminId,
          name: adminName,
          ip: ipAddress,
        },
      },
    },
  });

  // 6. Audit Log Entry
  await logAudit(
    {
      adminId,
      adminName,
      action: 'NOTIFICATION_BROADCAST_SENT',
      targetEntity: 'NotificationBroadcast',
      targetEntityId: broadcast.id,
      afterStateJson: {
        id: broadcast.id,
        title: effectiveTitle,
        audience: effectiveAudience,
        recipientCount: recipientIds.length,
        status: finalStatus,
        dispatchStats,
      },
      reason: `Push broadcast sent to ${recipientIds.length} users (${effectiveAudience})`,
      ipAddress,
    },
    db
  );

  return {
    ...updatedBroadcast,
    success: true,
    broadcast: updatedBroadcast,
    recipientCount: recipientIds.length,
    dispatchStats,
  };
}

/**
 * Retries a failed or partially delivered broadcast campaign.
 */
export async function retryBroadcast(broadcastId, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const broadcast = await broadcastRepository.findBroadcastById(broadcastId, db);
  if (!broadcast) {
    const error = new Error('Broadcast campaign not found');
    error.statusCode = 404;
    error.code = 'BROADCAST_NOT_FOUND';
    throw error;
  }

  const customUserIds = broadcast.metadataJson?.customUserIds || [];
  const recipientIds = await resolveTargetUserIds(broadcast.audience, customUserIds, db);

  const devices = await deviceRepository.findTokensByUserIds(recipientIds, db);
  const tokens = devices.map((d) => d.deviceToken).filter(Boolean);

  let retryStats = {
    retriedAt: new Date().toISOString(),
    tokensCount: tokens.length,
    providerAcceptedCount: 0,
    failedCount: 0,
  };

  let finalStatus = broadcast.status;

  if (tokens.length > 0) {
    const pushResult = await fcmAdapter.sendMulticast({
      tokens,
      title: broadcast.title,
      body: broadcast.body,
      data: {
        destination: broadcast.metadataJson?.destination || 'zeparty://home',
        broadcastId: broadcast.id,
      },
    });

    retryStats.providerAcceptedCount = pushResult.sentCount || 0;
    retryStats.failedCount = pushResult.failureCount || 0;

    if (pushResult.invalidTokens && pushResult.invalidTokens.length > 0) {
      await deviceRepository.cleanupInvalidTokens(pushResult.invalidTokens, db).catch(() => {});
    }

    if (pushResult.sentCount > 0) {
      finalStatus = pushResult.failureCount === 0 ? 'PROVIDER_ACCEPTED' : 'PARTIALLY_DELIVERED';
    } else {
      finalStatus = 'FAILED';
    }
  }

  const nextRetryCount = (broadcast.metadataJson?.retryCount || 0) + 1;

  const updated = await db.notificationBroadcast.update({
    where: { id: broadcastId },
    data: {
      status: finalStatus,
      metadataJson: {
        ...broadcast.metadataJson,
        retryCount: nextRetryCount,
        lastRetry: retryStats,
      },
    },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'NOTIFICATION_BROADCAST_RETRIED',
      targetEntity: 'NotificationBroadcast',
      targetEntityId: broadcastId,
      afterStateJson: { id: broadcastId, status: finalStatus, retryStats, retryCount: nextRetryCount },
      reason: `Retried push broadcast to ${tokens.length} devices`,
      ipAddress,
    },
    db
  );

  return {
    success: true,
    broadcast: updated,
    retryCount: nextRetryCount,
    dispatchedCount: tokens.length,
    retryStats,
  };
}

/**
 * Dispatches broadcast FCM push to target user tokens.
 */
async function dispatchBroadcastPush(recipientIds, { title, body, data }, db = prisma) {
  if (!recipientIds || recipientIds.length === 0) return;

  const devices = await deviceRepository.findTokensByUserIds(recipientIds, db);
  const tokens = devices.map((d) => d.deviceToken).filter(Boolean);

  if (tokens.length === 0) return;

  const pushResult = await fcmAdapter.sendMulticast({
    tokens,
    title,
    body,
    data,
  });

  if (pushResult.invalidTokens && pushResult.invalidTokens.length > 0) {
    await deviceRepository.cleanupInvalidTokens(pushResult.invalidTokens, db);
  }
}

/**
 * Lists broadcast history for Admin Portal.
 */
export async function listBroadcasts(filters, db = prisma) {
  return await broadcastRepository.findBroadcasts(filters, db);
}

/**
 * Retrieves details for a specific broadcast campaign.
 */
export async function getBroadcastDetails(id, db = prisma) {
  const broadcast = await broadcastRepository.findBroadcastById(id, db);
  if (!broadcast) {
    const error = new Error('Broadcast campaign not found');
    error.statusCode = 404;
    error.code = 'BROADCAST_NOT_FOUND';
    throw error;
  }
  return broadcast;
}

export default {
  resolveTargetUserIds,
  broadcastNotification,
  retryBroadcast,
  listBroadcasts,
  getBroadcastDetails,
};
