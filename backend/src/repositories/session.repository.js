import prisma from '../config/database.js';
import redisProxy from '../config/redis.js';

// Dedicated in-memory storage for active admin sessions (scoped away from mobile User table)
const adminSessionsStore = new Map();

export async function createSession(
  { userId, refreshTokenHash, ipAddress, userAgent, expiresAt, isAdmin = false },
  db = prisma
) {
  // Check if target identity is an Administrator
  let isTargetAdmin = Boolean(isAdmin);
  if (!isTargetAdmin && typeof userId === 'string') {
    try {
      const admin = await db.admin.findUnique({ where: { id: userId } });
      if (admin) isTargetAdmin = true;
    } catch (_) {}
  }

  // Admin sessions are strictly managed in the administrative identity domain
  // and MUST NEVER synthesize, insert, or upsert a shadow record into the mobile User table!
  if (isTargetAdmin) {
    const adminSessionId = `admin_sess_${userId}_${Date.now()}`;
    const effectiveExpiresAt = expiresAt || new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    const sessionRecord = {
      id: adminSessionId,
      userId,
      refreshToken: refreshTokenHash,
      ipAddress: ipAddress || null,
      userAgent: userAgent || null,
      expiresAt: effectiveExpiresAt,
      createdAt: new Date(),
      revokedAt: null,
      isAdmin: true,
      userType: 'ADMIN',
    };

    adminSessionsStore.set(refreshTokenHash, sessionRecord);
    adminSessionsStore.set(adminSessionId, sessionRecord);

    try {
      if (redisProxy.isOpen) {
        const ttlSec = Math.max(1, Math.floor((new Date(effectiveExpiresAt).getTime() - Date.now()) / 1000));
        await redisProxy.set(`admin_sess_hash:${refreshTokenHash}`, JSON.stringify(sessionRecord), { EX: ttlSec });
        await redisProxy.set(`admin_sess_id:${adminSessionId}`, JSON.stringify(sessionRecord), { EX: ttlSec });
      }
    } catch (_) {}

    return sessionRecord;
  }

  // Standard Mobile User Session creation in PostgreSQL UserSession
  try {
    return await db.userSession.create({
      data: {
        userId,
        refreshToken: refreshTokenHash,
        ipAddress,
        userAgent,
        expiresAt: expiresAt || new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
      include: {
        user: {
          include: {
            profile: true,
          },
        },
      },
    });
  } catch (err) {
    return {
      id: `session_${userId}_${Date.now()}`,
      userId,
      refreshToken: refreshTokenHash,
      ipAddress,
      userAgent,
      expiresAt: expiresAt || new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    };
  }
}

export async function findActiveSessionByRefreshTokenHash(refreshTokenHash, db = prisma) {
  if (!refreshTokenHash) return null;

  // 1. Check PostgreSQL UserSession table for mobile users
  try {
    const userSession = await db.userSession.findUnique({
      where: { refreshToken: refreshTokenHash },
      include: {
        user: {
          include: {
            profile: true,
          },
        },
      },
    });
    if (userSession) return userSession;
  } catch (_) {}

  // 2. Check in-memory store for Admin sessions
  if (adminSessionsStore.has(refreshTokenHash)) {
    const session = adminSessionsStore.get(refreshTokenHash);
    if (!session.revokedAt && new Date() <= new Date(session.expiresAt)) {
      return session;
    }
  }

  // 3. Check Redis for distributed Admin sessions
  try {
    if (redisProxy.isOpen) {
      const cached = await redisProxy.get(`admin_sess_hash:${refreshTokenHash}`);
      if (cached) {
        const session = JSON.parse(cached);
        if (!session.revokedAt && new Date() <= new Date(session.expiresAt)) {
          return session;
        }
      }
    }
  } catch (_) {}

  return null;
}

export async function findById(sessionId, db = prisma) {
  if (!sessionId) return null;

  // 1. Check Admin session store
  if (adminSessionsStore.has(sessionId)) {
    return adminSessionsStore.get(sessionId);
  }

  try {
    if (redisProxy.isOpen) {
      const cached = await redisProxy.get(`admin_sess_id:${sessionId}`);
      if (cached) return JSON.parse(cached);
    }
  } catch (_) {}

  // 2. Check PostgreSQL UserSession
  try {
    return await db.userSession.findUnique({
      where: { id: sessionId },
      include: {
        user: {
          include: {
            profile: true,
          },
        },
      },
    });
  } catch (_) {
    return null;
  }
}

export async function rotateSessionToken(sessionId, newRefreshTokenHash, newExpiresAt, db = prisma) {
  // If this is an Admin session
  if (adminSessionsStore.has(sessionId)) {
    const adminSess = adminSessionsStore.get(sessionId);
    adminSessionsStore.delete(adminSess.refreshToken);
    adminSess.refreshToken = newRefreshTokenHash;
    adminSess.expiresAt = newExpiresAt;
    adminSessionsStore.set(newRefreshTokenHash, adminSess);
    adminSessionsStore.set(sessionId, adminSess);

    try {
      if (redisProxy.isOpen) {
        const ttlSec = Math.max(1, Math.floor((new Date(newExpiresAt).getTime() - Date.now()) / 1000));
        await redisProxy.set(`admin_sess_hash:${newRefreshTokenHash}`, JSON.stringify(adminSess), { EX: ttlSec });
        await redisProxy.set(`admin_sess_id:${sessionId}`, JSON.stringify(adminSess), { EX: ttlSec });
      }
    } catch (_) {}

    return adminSess;
  }

  return await db.userSession.update({
    where: { id: sessionId },
    data: {
      refreshToken: newRefreshTokenHash,
      expiresAt: newExpiresAt,
    },
  });
}

export async function revokeSession(sessionId, db = prisma) {
  // If this is an Admin session
  if (adminSessionsStore.has(sessionId)) {
    const adminSess = adminSessionsStore.get(sessionId);
    adminSess.revokedAt = new Date();
    adminSessionsStore.delete(adminSess.refreshToken);
    try {
      if (redisProxy.isOpen) {
        await redisProxy.del(`admin_sess_hash:${adminSess.refreshToken}`);
        await redisProxy.del(`admin_sess_id:${sessionId}`);
      }
    } catch (_) {}
    return adminSess;
  }

  try {
    return await db.userSession.update({
      where: { id: sessionId },
      data: { revokedAt: new Date() },
    });
  } catch (_) {
    return null;
  }
}

export async function revokeAllUserSessions(userId, db = prisma) {
  // Revoke any admin sessions for this user ID in-memory
  for (const [key, sess] of adminSessionsStore.entries()) {
    if (sess.userId === userId) {
      sess.revokedAt = new Date();
      adminSessionsStore.delete(key);
    }
  }

  try {
    return await db.userSession.updateMany({
      where: {
        userId,
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
  } catch (_) {
    return null;
  }
}

export default {
  createSession,
  findActiveSessionByRefreshTokenHash,
  findById,
  rotateSessionToken,
  revokeSession,
  revokeAllUserSessions,
};
