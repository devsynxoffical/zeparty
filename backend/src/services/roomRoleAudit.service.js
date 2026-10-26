import prisma from '../config/database.js';
import crypto from 'crypto';

/**
 * In-memory resilient circular buffer for room-scoped role audit logs.
 * Holds recent role promotion/demotion events across room lifecycles.
 */
const MAX_AUDIT_LOGS = 1000;
const roleAuditLogStore = [];

/**
 * Record a room role modification in the audit trail.
 *
 * @param {Object} params
 * @param {string} params.roomId
 * @param {string} params.actorUserId
 * @param {string} params.targetUserId
 * @param {string} params.action - 'ROOM_ADMIN_PROMOTED' | 'ROOM_ADMIN_DEMOTED'
 * @param {string} params.role - 'ADMIN' | 'MEMBER'
 * @param {string} [params.reason]
 * @param {string} [params.outcome='SUCCESS'] - 'SUCCESS' | 'DENIED' | 'FAILED'
 * @param {Object} [db=prisma]
 */
export async function recordRoleChange(
  {
    roomId,
    actorUserId,
    targetUserId,
    action,
    role,
    reason = null,
    outcome = 'SUCCESS',
  },
  db = prisma
) {
  const auditEntry = {
    id: `role_audit_${crypto.randomUUID()}`,
    roomId: String(roomId),
    actorUserId: String(actorUserId),
    targetUserId: String(targetUserId),
    action: action || (role === 'ADMIN' ? 'ROOM_ADMIN_PROMOTED' : 'ROOM_ADMIN_DEMOTED'),
    role: role || (action === 'ROOM_ADMIN_PROMOTED' ? 'ADMIN' : 'MEMBER'),
    reason: reason ? String(reason).substring(0, 500) : null,
    outcome: outcome || 'SUCCESS',
    timestamp: new Date().toISOString(),
  };

  // Append to local audit store
  roleAuditLogStore.unshift(auditEntry);
  if (roleAuditLogStore.length > MAX_AUDIT_LOGS) {
    roleAuditLogStore.pop();
  }

  // Attempt database audit log if an Admin entity exists or matches actor
  try {
    if (db && db.auditLog && typeof db.auditLog.create === 'function') {
      const adminUser = await db.admin.findUnique({
        where: { id: actorUserId },
        select: { id: true, name: true },
      }).catch(() => null);

      if (adminUser) {
        await db.auditLog.create({
          data: {
            adminId: adminUser.id,
            adminName: adminUser.name || 'Room Owner',
            action: auditEntry.action,
            targetEntity: 'RoomMember',
            targetEntityId: `${roomId}:${targetUserId}`,
            afterStateJson: { role: auditEntry.role, targetUserId, roomId },
            reason: auditEntry.reason,
            ipAddress: '127.0.0.1',
          },
        }).catch(() => null);
      }
    }
  } catch (_) {
    // Non-blocking platform audit logging
  }

  return auditEntry;
}

/**
 * Retrieve audit history for a specific room.
 *
 * @param {string} roomId
 * @param {Object} [options]
 * @param {number} [options.limit=50]
 * @param {number} [options.offset=0]
 */
export function getRoomRoleAuditLogs(roomId, { limit = 50, offset = 0 } = {}) {
  const cleanRoomId = String(roomId).trim();
  const filtered = roleAuditLogStore.filter((log) => log.roomId === cleanRoomId);
  const parsedOffset = Math.max(0, Number(offset) || 0);
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 50));
  return {
    total: filtered.length,
    roomId: cleanRoomId,
    logs: filtered.slice(parsedOffset, parsedOffset + parsedLimit),
  };
}

/**
 * Retrieve recent audit history across all rooms for diagnostics.
 *
 * @param {number} [limit=100]
 */
export function getAllRoleAuditLogs(limit = 100) {
  const parsedLimit = Math.max(1, Math.min(500, Number(limit) || 100));
  return roleAuditLogStore.slice(0, parsedLimit);
}

export default {
  recordRoleChange,
  getRoomRoleAuditLogs,
  getAllRoleAuditLogs,
};
