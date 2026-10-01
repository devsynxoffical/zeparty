import prisma from '../config/database.js';

async function ensureHostProfile(userId, db = prisma) {
  if (!userId) return null;
  let profile = await db.hostProfile.findUnique({ where: { userId } });
  if (!profile) {
    profile = await db.hostProfile.create({
      data: {
        userId,
        hostCode: `H_${userId}_${Math.floor(1000 + Math.random() * 9000)}`,
        status: 'APPROVED',
      },
    });
  }
  return profile;
}

export class PKRepository {
  async createPKEvent({ roomAId, roomBId, hostAUserId, hostBUserId, durationSeconds = 300 }, db = prisma) {
    // Ensure HostProfile exists for both hosts
    const [hostAProfile, hostBProfile] = await Promise.all([
      ensureHostProfile(hostAUserId, db),
      ensureHostProfile(hostBUserId, db),
    ]);

    return db.pKEvent.create({
      data: {
        roomAId,
        roomBId,
        hostAUserId: hostAProfile.id,
        hostBUserId: hostBProfile.id,
        durationSeconds,
        hostAScore: 0n,
        hostBScore: 0n,
        status: 'COUNTDOWN',
      },
      include: {
        roomA: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        roomB: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        hostA: true,
        hostB: true,
      },
    });
  }

  async findPKEventById(id, db = prisma) {
    return db.pKEvent.findUnique({
      where: { id },
      include: {
        roomA: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        roomB: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        hostA: true,
        hostB: true,
      },
    });
  }

  async findActivePKForRoom(roomId, db = prisma) {
    return db.pKEvent.findFirst({
      where: {
        OR: [{ roomAId: roomId }, { roomBId: roomId }],
        status: { in: ['COUNTDOWN', 'ACTIVE'] },
      },
      include: {
        roomA: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        roomB: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        hostA: true,
        hostB: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async updatePKStatus(id, { status, winnerHostUserId, endedAt }, db = prisma) {
    return db.pKEvent.update({
      where: { id },
      data: {
        status,
        ...(winnerHostUserId !== undefined ? { winnerHostUserId } : {}),
        ...(endedAt !== undefined ? { endedAt } : {}),
      },
      include: {
        roomA: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        roomB: {
          include: {
            creator: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
        hostA: true,
        hostB: true,
      },
    });
  }

  async incrementHostScore(id, hostKey, scoreDelta, db = prisma) {
    const field = hostKey === 'hostA' ? 'hostAScore' : 'hostBScore';
    return db.pKEvent.update({
      where: { id },
      data: {
        [field]: {
          increment: BigInt(scoreDelta),
        },
      },
    });
  }

  async findAvailableLiveRooms({ excludeRoomId = null, excludeUserId = null } = {}, db = prisma) {
    const where = {
      status: 'LIVE',
    };
    if (excludeRoomId) where.id = { not: excludeRoomId };
    if (excludeUserId) where.creatorUserId = { not: excludeUserId };

    const activeRooms = await db.room.findMany({
      where,
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            userType: true,
            profile: {
              select: {
                displayName: true,
                level: true,
                vipLevel: true,
                followersCount: true,
              },
            },
          },
        },
      },
      orderBy: { currentViewersCount: 'desc' },
      take: 50,
    });

    return activeRooms;
  }

  async listPKEvents({ page = 1, limit = 20, status }, db = prisma) {
    const skip = (Number(page) - 1) * Number(limit);
    const where = status ? { status } : {};

    const [total, events] = await Promise.all([
      db.pKEvent.count({ where }),
      db.pKEvent.findMany({
        where,
        skip,
        take: Number(limit),
        include: {
          roomA: true,
          roomB: true,
          hostA: true,
          hostB: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return { total, events, page: Number(page), limit: Number(limit) };
  }
}

export const pkRepository = new PKRepository();
export default pkRepository;
