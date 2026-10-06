import prisma from '../config/database.js';

async function ensureHostProfile(userId, db = prisma) {
  if (!userId) return null;
  let profile = await db.hostProfile.findUnique({ where: { userId } });
  if (!profile) {
    profile = await db.hostProfile.create({
      data: {
        userId,
        hostCode: `H_${userId.substring(0, 8)}_${Math.floor(1000 + Math.random() * 9000)}`,
        status: 'ACTIVE',
      },
    });
  }
  return profile;
}

export class PKRepository {
  /**
   * Create a new PK battle event.
   */
  async createPKEvent({
    initiatorUserId,
    roomAId,
    roomBId = null,
    hostAUserId,
    hostBUserId = null,
    durationSeconds = 300,
    participants = [],
    inviteCode = null,
    status = 'CREATED',
  }, db = prisma) {
    const hostAProfile = await ensureHostProfile(hostAUserId, db);
    const hostBProfile = hostBUserId ? await ensureHostProfile(hostBUserId, db) : null;

    return db.pKEvent.create({
      data: {
        initiatorUserId,
        roomAId,
        roomBId: roomBId || undefined,
        hostAUserId: hostAProfile.id,
        hostBUserId: hostBProfile ? hostBProfile.id : undefined,
        durationSeconds,
        hostAScore: 0n,
        hostBScore: 0n,
        participantsJson: participants,
        inviteCode,
        status,
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

  /**
   * Find PK event by ID.
   */
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

  /**
   * Find PK event by invitation code.
   */
  async findPKEventByInviteCode(inviteCode, db = prisma) {
    return db.pKEvent.findFirst({
      where: {
        inviteCode,
        status: { in: ['CREATED', 'INVITING', 'READY', 'COUNTDOWN', 'ACTIVE', 'STARTED'] },
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

  /**
   * Find currently active or ready PK battle for a room.
   */
  async findActivePKForRoom(roomId, db = prisma) {
    return db.pKEvent.findFirst({
      where: {
        OR: [{ roomAId: roomId }, { roomBId: roomId }],
        status: { in: ['CREATED', 'INVITING', 'READY', 'COUNTDOWN', 'ACTIVE', 'STARTED'] },
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

  /**
   * Update PK status, startedAt, participants, scores, and winner.
   */
  async updatePKStatus(id, {
    status,
    startedAt,
    winnerHostUserId,
    endedAt,
    participantsJson,
    roomBId,
    hostBUserId,
  }, db = prisma) {
    const data = {
      ...(status !== undefined ? { status } : {}),
      ...(startedAt !== undefined ? { startedAt } : {}),
      ...(winnerHostUserId !== undefined ? { winnerHostUserId } : {}),
      ...(endedAt !== undefined ? { endedAt } : {}),
      ...(participantsJson !== undefined ? { participantsJson } : {}),
      ...(roomBId !== undefined ? { roomBId } : {}),
    };

    if (hostBUserId) {
      const hostBProfile = await ensureHostProfile(hostBUserId, db);
      data.hostBUserId = hostBProfile.id;
    }

    return db.pKEvent.update({
      where: { id },
      data,
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

  /**
   * Increment score for a specific participant slot or host.
   */
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

  /**
   * Find available active live rooms for host-to-host discovery.
   */
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

  /**
   * Verify whether a user is an active host of a room.
   */
  async verifyLiveHost(userId, roomId, db = prisma) {
    if (!userId || !roomId) return false;
    const room = await db.room.findFirst({
      where: {
        id: roomId,
        creatorUserId: userId,
        status: 'LIVE',
      },
    });
    return !!room;
  }

  /**
   * List PK events for Admin oversight.
   */
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
