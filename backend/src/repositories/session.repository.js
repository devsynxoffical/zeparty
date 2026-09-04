import prisma from '../config/database.js';

export async function createSession(
  { userId, refreshTokenHash, ipAddress, userAgent, expiresAt },
  db = prisma
) {
  return await db.userSession.create({
    data: {
      userId,
      refreshToken: refreshTokenHash,
      ipAddress,
      userAgent,
      expiresAt,
    },
  });
}

export async function findActiveSessionByRefreshTokenHash(refreshTokenHash, db = prisma) {
  if (!refreshTokenHash) return null;
  return await db.userSession.findUnique({
    where: { refreshToken: refreshTokenHash },
    include: {
      user: {
        include: {
          profile: true,
        },
      },
    },
  });
}

export async function findById(sessionId, db = prisma) {
  if (!sessionId) return null;
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
}

export async function rotateSessionToken(sessionId, newRefreshTokenHash, newExpiresAt, db = prisma) {
  return await db.userSession.update({
    where: { id: sessionId },
    data: {
      refreshToken: newRefreshTokenHash,
      expiresAt: newExpiresAt,
    },
  });
}

export async function revokeSession(sessionId, db = prisma) {
  return await db.userSession.update({
    where: { id: sessionId },
    data: { revokedAt: new Date() },
  });
}

export async function revokeAllUserSessions(userId, db = prisma) {
  return await db.userSession.updateMany({
    where: {
      userId,
      revokedAt: null,
    },
    data: { revokedAt: new Date() },
  });
}

export default {
  createSession,
  findActiveSessionByRefreshTokenHash,
  findById,
  rotateSessionToken,
  revokeSession,
  revokeAllUserSessions,
};
