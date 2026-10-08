import prisma from '../config/database.js';

/**
 * Generates a random unique 7-digit numeric user ID (e.g. '1103757')
 * Range: 1000000 to 9999999
 */
export async function generate7DigitUserId(db = prisma) {
  while (true) {
    const randomId = Math.floor(1000000 + Math.random() * 9000000).toString();
    const existing = await db.user.findUnique({
      where: { id: randomId },
      select: { id: true },
    });
    if (!existing) {
      return randomId;
    }
  }
}

export default {
  generate7DigitUserId,
};
