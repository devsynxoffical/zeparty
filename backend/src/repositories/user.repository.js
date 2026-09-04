import prisma from '../config/database.js';

export async function findByPhone(phone, db = prisma) {
  if (!phone) return null;
  return await db.user.findUnique({
    where: { phone },
    include: {
      profile: true,
      wallet: true,
      hostProfile: true,
    },
  });
}

export async function findById(id, db = prisma) {
  if (!id) return null;
  return await db.user.findUnique({
    where: { id },
    include: {
      profile: true,
      wallet: true,
      hostProfile: true,
    },
  });
}

export async function findByEmail(email, db = prisma) {
  if (!email) return null;
  return await db.user.findUnique({
    where: { email },
    include: {
      profile: true,
      wallet: true,
    },
  });
}

export async function findByUsername(username, db = prisma) {
  if (!username) return null;
  return await db.user.findUnique({
    where: { username },
  });
}

/**
 * Creates a new User and associated UserProfile and Wallet in a single transaction.
 */
export async function createUserWithProfile(
  { phone, email = null, username, status = 'ACTIVE', userType = 'USER', countryCode = 'US' },
  db = prisma
) {
  return await db.user.create({
    data: {
      phone,
      email,
      username,
      status,
      userType,
      countryCode,
      profile: {
        create: {
          displayName: username,
        },
      },
      wallet: {
        create: {
          coinBalance: 0n,
          diamondBalance: 0n,
        },
      },
    },
    include: {
      profile: true,
      wallet: true,
    },
  });
}

export async function updateLastLogin(userId, db = prisma) {
  return await db.user.update({
    where: { id: userId },
    data: { lastLoginAt: new Date() },
  });
}

export default {
  findByPhone,
  findById,
  findByEmail,
  findByUsername,
  createUserWithProfile,
  updateLastLogin,
};
