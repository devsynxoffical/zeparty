import prisma from '../config/database.js';
import presenceService from '../socket/presence.service.js';
import bcrypt from 'bcryptjs';

export async function createRoomWithSeats(
  {
    creatorUserId,
    title,
    coverImageUrl = null,
    backgroundImageUrl = null,
    roomType = 'LIVE_VIDEO',
    category = 'CHAT',
    isPrivate = false,
    roomPin = null,
    agoraChannelName,
    capacity = 10,
    seatCapacity = null,
  },
  db = prisma
) {
  // Archive any previous active rooms created by this user to avoid multiple duplicate rooms
  try {
    await db.room.updateMany({
      where: {
        creatorUserId,
        status: 'LIVE',
      },
      data: {
        status: 'ENDED',
        endedAt: new Date(),
        currentViewersCount: 0,
      },
    });
  } catch (err) {
    console.warn('[RoomRepository] Could not archive previous rooms:', err?.message);
  }

  // Initialize seats (defaults to 10 seats: host + co-host + 8 mic seats for standard layout)
  const totalSeats = Math.max(10, parseInt(seatCapacity || capacity, 10) || 10);
  const seatsData = Array.from({ length: totalSeats }, (_, i) => ({
    seatIndex: i,
    occupiedUserId: i === 0 && roomType === 'AUDIO_PARTY' ? creatorUserId : null,
    isMuted: false,
    isLocked: false,
  }));

  return await db.room.create({
    data: {
      creatorUserId,
      title,
      coverImageUrl,
      backgroundImageUrl,
      roomType,
      category,
      isPrivate,
      roomPin,
      agoraChannelName,
      status: 'LIVE',
      currentViewersCount: 0, // Audience viewer count starts at 0 (host is not an audience viewer)
      members: {
        create: {
          userId: creatorUserId,
        },
      },
      seats: {
        create: seatsData,
      },
    },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
          userType: true,
          profile: {
            select: {
              displayName: true,
              level: true,
              vipLevel: true,
              svipLevel: true,
              nobleRank: true,
              followersCount: true,
              followingCount: true,
              isPrivate: true,
            },
          },
        },
      },
      seats: {
        orderBy: { seatIndex: 'asc' },
        include: {
          occupiedUser: {
            select: {
              id: true,
              username: true,
              avatarUrl: true,
              profile: true,
            },
          },
        },
      },
      _count: {
        select: { members: true },
      },
    },
  });
}

export async function findRoomById(id, db = prisma) {
  if (!id || typeof id !== 'string') return null;
  const cleanId = id.trim();
  const include = {
    creator: {
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        profile: {
          select: {
            displayName: true,
            level: true,
            vipLevel: true,
            svipLevel: true,
            nobleRank: true,
          },
        },
      },
    },
    seats: {
      orderBy: { seatIndex: 'asc' },
      include: {
        occupiedUser: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: {
              select: {
                displayName: true,
                level: true,
                vipLevel: true,
              },
            },
          },
        },
      },
    },
    members: {
      include: {
        user: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: {
              select: {
                displayName: true,
              },
            },
          },
        },
      },
    },
    giftTransactions: {
      select: {
        totalCoins: true,
      },
    },
  };

  let room = await db.room.findUnique({
    where: { id: cleanId },
    include,
  }).catch(() => null);

  if (!room && cleanId.length >= 4 && cleanId.length <= 32) {
    room = await db.room.findFirst({
      where: {
        id: { startsWith: cleanId, mode: 'insensitive' },
      },
      include,
    }).catch(() => null);
  }

  return room;
}

export async function findActiveRooms(
  {
    roomType = null,
    category = null,
    search = null,
    isPrivate = null,
    page = 1,
    limit = 20,
  } = {},
  db = prisma
) {
  const where = {
    status: 'LIVE',
    creator: {
      id: { not: '' },
    },
  };

  if (isPrivate !== null && isPrivate !== undefined) {
    where.isPrivate = Boolean(isPrivate);
  }

  if (roomType) where.roomType = roomType;
  if (category) where.category = category;
  if (search && search.trim() !== '') {
    const s = search.trim();
    where.OR = [
      { id: { contains: s, mode: 'insensitive' } },
      { title: { contains: s, mode: 'insensitive' } },
      { creator: { username: { contains: s, mode: 'insensitive' } } },
      { creator: { profile: { displayName: { contains: s, mode: 'insensitive' } } } },
    ];
  }

  const parsedPage = Math.max(1, Number(page) || 1);
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const skip = (parsedPage - 1) * parsedLimit;

  const [total, rawRooms] = await Promise.all([
    db.room.count({ where }),
    db.room.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: [
        { isPinnedTop: 'desc' },
        { pinnedPosition: 'asc' },
        { createdAt: 'desc' },
        { currentViewersCount: 'desc' },
      ],
      select: {
        id: true,
        creatorUserId: true,
        title: true,
        coverImageUrl: true,
        backgroundImageUrl: true,
        roomType: true,
        category: true,
        isPrivate: true,
        roomPin: true,
        agoraChannelName: true,
        isPinnedTop: true,
        pinnedPosition: true,
        currentViewersCount: true,
        status: true,
        createdAt: true,
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            countryCode: true,
            region: true,
            userType: true,
            profile: {
              select: {
                displayName: true,
                level: true,
                vipLevel: true,
                svipLevel: true,
                nobleRank: true,
                followersCount: true,
                followingCount: true,
                isPrivate: true,
              },
            },
          },
        },
        seats: {
          select: {
            seatIndex: true,
            occupiedUserId: true,
            isLocked: true,
            isMuted: true,
          },
          orderBy: { seatIndex: 'asc' },
        },
      },
    }),
  ]);

  const rooms = rawRooms.map((r) => {
    const hasPin = Boolean(r.roomPin);
    const lockMode = hasPin ? 'PIN' : (r.isPrivate ? 'Approval' : 'NONE');
    const { roomPin: _confidentialPin, ...safeRoom } = r;
    const seatCount = (r.seats || []).length || 10;
    return {
      ...safeRoom,
      isLocked: Boolean(r.isPrivate),
      lockMode,
      seatCapacity: seatCount,
      capacity: seatCount,
    };
  });

  return {
    rooms,
    pagination: {
      page: parsedPage,
      limit: parsedLimit,
      total,
      totalPages: Math.ceil(total / parsedLimit),
    },
  };
}

export async function findAdminRooms(
  {
    search = null,
    status = null,
    roomType = null,
    isPinnedTop = null,
    page = 1,
    limit = 20,
  } = {},
  db = prisma
) {
  const where = {
    creator: { id: { not: '' } },
  };

  if (status === 'active' || status === 'LIVE') {
    where.status = 'LIVE';
  } else if (status && status !== 'all') {
    where.status = status;
  }
  if (roomType) where.roomType = roomType;
  if (isPinnedTop !== null && isPinnedTop !== undefined) {
    where.isPinnedTop = isPinnedTop === 'true' || isPinnedTop === true;
  }

  if (search && search.trim() !== '') {
    const s = search.trim();
    where.OR = [
      { title: { contains: s, mode: 'insensitive' } },
      { creator: { username: { contains: s, mode: 'insensitive' } } },
    ];
  }

  const parsedPage = Math.max(1, Number(page) || 1);
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const skip = (parsedPage - 1) * parsedLimit;

  const [total, rooms] = await Promise.all([
    db.room.count({ where }),
    db.room.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: { createdAt: 'desc' },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            countryCode: true,
            profile: {
              select: {
                displayName: true,
              },
            },
          },
        },
        seats: {
          orderBy: { seatIndex: 'asc' },
          include: {
            occupiedUser: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: {
                  select: {
                    displayName: true,
                    level: true,
                  },
                },
              },
            },
          },
        },
        members: {
          take: 10,
          include: {
            user: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: {
                  select: {
                    displayName: true,
                  },
                },
              },
            },
          },
        },
      },
    }),
  ]);

  const formattedRooms = rooms.map((r) => {
    const hasPin = Boolean(r.roomPin);
    const lockMode = hasPin ? 'PIN' : (r.isPrivate ? 'Approval' : 'NONE');
    const { roomPin: _confidentialPin, ...safeR } = r;
    const seatCount = (r.seats || []).length || 10;
    return {
      ...safeR,
      isLocked: Boolean(r.isPrivate),
      lockMode,
      seatCapacity: seatCount,
      capacity: seatCount,
    };
  });

  return {
    rooms: formattedRooms,
    pagination: {
      page: parsedPage,
      limit: parsedLimit,
      total,
      totalPages: Math.ceil(total / parsedLimit),
    },
  };
}

export async function joinRoomTx({ roomId, userId, pin = null, isApproved = false }, db = prisma) {
  let resolvedRoomId = roomId;
  let room = await db.room.findUnique({
    where: { id: roomId },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
    });
    if (room) {
      resolvedRoomId = room.id;
    }
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  let isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(room.status);
  if (!isRoomOpen) {
    // Check if the host has started a new active room session
    if (room.creatorUserId) {
      const activeRoom = await db.room.findFirst({
        where: {
          creatorUserId: room.creatorUserId,
          status: 'LIVE',
        },
        select: { id: true },
      });
      if (activeRoom) {
        resolvedRoomId = activeRoom.id;
        room = await db.room.findUnique({ where: { id: resolvedRoomId } });
        isRoomOpen = room && ['LIVE', 'ACTIVE', 'OPEN'].includes(room.status);
      }
    }

    if (!isRoomOpen) {
      const error = new Error('Room is not available or has ended');
      error.statusCode = 400;
      error.code = 'ROOM_NOT_LIVE';
      throw error;
    }
  }

  // Check if user was kicked from this room session
  const activeKick = await db.roomModeration.findFirst({
    where: {
      roomId: resolvedRoomId,
      targetUserId: userId,
      actionType: 'KICK',
    },
  });

  if (activeKick) {
    const error = new Error('You have been kicked from this room session');
    error.statusCode = 403;
    error.code = 'ROOM_KICKED';
    throw error;
  }

  // Issue 07: Authoritative Room Lock & Access Enforcement
  if (room.isPrivate) {
    const isOwnerOrHost = room.creatorUserId === userId;
    let isBypassUser = isOwnerOrHost;
    if (!isBypassUser && userId && !String(userId).startsWith('guest_')) {
      const staffMember = await db.roomMember.findFirst({
        where: {
          roomId: resolvedRoomId,
          userId,
          role: { in: ['OWNER', 'HOST', 'CO_HOST', 'ADMIN', 'MODERATOR'] },
        },
      });
      if (staffMember) isBypassUser = true;
    }

    if (!isBypassUser) {
      if (room.roomPin) {
        if (!pin) {
          const error = new Error('Room is locked with a PIN');
          error.statusCode = 403;
          error.code = 'ROOM_LOCKED_PIN_REQUIRED';
          throw error;
        }
        let pinMatch = false;
        try {
          if (room.roomPin.startsWith('$2')) {
            pinMatch = await bcrypt.compare(String(pin).trim(), room.roomPin);
          } else {
            pinMatch = String(pin).trim() === String(room.roomPin).trim();
          }
        } catch (_) {
          pinMatch = String(pin).trim() === String(room.roomPin).trim();
        }
        if (!pinMatch) {
          const error = new Error('Incorrect room PIN');
          error.statusCode = 403;
          error.code = 'INVALID_ROOM_PIN';
          throw error;
        }
      } else {
        // Approval Mode
        if (!isApproved) {
          const error = new Error('Host approval required to enter this room');
          error.statusCode = 403;
          error.code = 'ROOM_APPROVAL_REQUIRED';
          throw error;
        }
      }
    }
  }

  const isGuest = Boolean(String(userId).startsWith('guest_'));

  if (!isGuest) {
    // Clean up any stale membership for this registered user in other rooms
    try {
      await db.roomMember.deleteMany({
        where: {
          userId,
          roomId: { not: resolvedRoomId },
        },
      });
    } catch (cleanErr) {
      console.warn(`[RoomRepo] Stale room membership cleanup notice for user ${userId}:`, cleanErr.message);
    }

    // Ensure RoomMember record exists for registered user
    try {
      const existingMember = await db.roomMember.findUnique({
        where: {
          roomId_userId: {
            roomId: resolvedRoomId,
            userId,
          },
        },
      });

      if (!existingMember) {
        await db.roomMember.create({
          data: {
            roomId: resolvedRoomId,
            userId,
          },
        });
      }
    } catch (memberErr) {
      console.warn(`[RoomRepo] Membership registration error for user ${userId} in room ${resolvedRoomId}:`, memberErr.message);
    }

    // If returning user is the creator/host, preserve existing seat state without forcibly re-occupying vacant seat 0
    if (room.creatorUserId === userId) {
      try {
        const seat0 = await db.roomSeat.findUnique({
          where: { roomId_seatIndex: { roomId: resolvedRoomId, seatIndex: 0 } },
        });
        if (seat0 && seat0.occupiedUserId === userId) {
          // Already occupied by creator, preserve
        }
      } catch (_) {}
    }
  }

  const audienceMemberCount = await db.roomMember.count({
    where: {
      roomId: resolvedRoomId,
      userId: { not: room.creatorUserId },
    },
  });

  let totalViewerCount = audienceMemberCount;
  try {
    const presenceViewerCount = await presenceService.getRoomViewerCount(resolvedRoomId, room.creatorUserId);
    if (typeof presenceViewerCount === 'number' && presenceViewerCount >= 0) {
      totalViewerCount = Math.max(audienceMemberCount, presenceViewerCount);
    }
  } catch (_) {}

  return await db.room.update({
    where: { id: resolvedRoomId },
    data: {
      currentViewersCount: totalViewerCount,
    },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
          profile: true,
        },
      },
    },
  });
}

export async function leaveRoomTx({ roomId, userId }, db = prisma) {
  let resolvedRoomId = roomId;
  let room = await db.room.findUnique({
    where: { id: roomId },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
    });
    if (room) {
      resolvedRoomId = room.id;
    }
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isGuest = Boolean(String(userId).startsWith('guest_'));

  // Release seat if user occupied one
  try {
    await db.roomSeat.updateMany({
      where: {
        roomId: resolvedRoomId,
        occupiedUserId: userId,
      },
      data: {
        occupiedUserId: null,
        isMuted: false,
      },
    });
  } catch (seatErr) {
    console.warn(`[RoomRepo] Seat release notice on leave for user ${userId}:`, seatErr.message);
  }

  if (!isGuest) {
    // Remove persistent membership record for registered user
    try {
      await db.roomMember.deleteMany({
        where: {
          roomId: resolvedRoomId,
          userId,
        },
      });
    } catch (leaveErr) {
      console.warn(`[RoomRepo] Membership removal notice for user ${userId}:`, leaveErr.message);
    }
  }

  const totalMemberCount = await db.roomMember.count({
    where: { roomId: resolvedRoomId },
  });

  // Check active presence to avoid terminating room if viewers (or guests) are still inside
  let activePresenceCount = 0;
  try {
    activePresenceCount = await presenceService.getRoomActiveUserCount(resolvedRoomId);
  } catch (_) {}

  // A guest leaving is purely a viewer departure and must NEVER terminate the room.
  // Registered members only trigger termination if no persistent members AND no active socket presence remain.
  // Audio party rooms are governed by host absent timers with a grace period; do not auto-close prematurely here.
  const isAudioParty = (room.roomType || '').toUpperCase().includes('AUDIO') || (room.roomType || '').toUpperCase().includes('PARTY');
  const shouldDeleteRoom = !isAudioParty && !isGuest && totalMemberCount === 0 && activePresenceCount === 0 && (room.creatorUserId === userId);

  if (shouldDeleteRoom) {
    try {
      await db.room.update({
        where: { id: resolvedRoomId },
        data: {
          status: 'ENDED',
          currentViewersCount: 0,
          endedAt: new Date(),
        },
      });
      await presenceService.clearRoomPresence(resolvedRoomId);
    } catch (closeErr) {
      console.warn(`[RoomRepo] Failed to end empty room ${resolvedRoomId}:`, closeErr.message);
    }
    return { id: resolvedRoomId, currentViewersCount: 0, status: 'ENDED' };
  }

  const audienceMemberCount = await db.roomMember.count({
    where: {
      roomId: resolvedRoomId,
      userId: { not: room.creatorUserId },
    },
  });

  let totalViewerCount = audienceMemberCount;
  try {
    const presenceViewerCount = await presenceService.getRoomViewerCount(resolvedRoomId, room.creatorUserId);
    if (typeof presenceViewerCount === 'number' && presenceViewerCount >= 0) {
      totalViewerCount = Math.max(audienceMemberCount, presenceViewerCount);
    }
  } catch (_) {}

  return await db.room.update({
    where: { id: resolvedRoomId },
    data: {
      currentViewersCount: totalViewerCount,
    },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
          profile: true,
        },
      },
    },
  });
}

export async function occupySeatTx({ roomId, seatIndex, userId }, db = prisma) {
  return await db.$transaction(async (tx) => {
    let resolvedRoomId = roomId;
    let room = await tx.room.findUnique({
      where: { id: roomId },
    });

    if (!room && roomId && roomId.length <= 16) {
      room = await tx.room.findFirst({
        where: { id: { startsWith: roomId, mode: 'insensitive' } },
      });
      if (room) {
        resolvedRoomId = room.id;
      }
    }

    if (!room) {
      const error = new Error('Room not found');
      error.statusCode = 404;
      error.code = 'ROOM_NOT_FOUND';
      throw error;
    }

    if (room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(room.status.toUpperCase())) {
      const error = new Error('Room is not live');
      error.statusCode = 400;
      error.code = 'ROOM_NOT_LIVE';
      throw error;
    }

    // Check if user already occupies another seat in this room
    const existingUserSeat = await tx.roomSeat.findFirst({
      where: {
        roomId: resolvedRoomId,
        occupiedUserId: userId,
      },
    });

    let vacatedSeatIndex = null;
    if (existingUserSeat) {
      if (existingUserSeat.seatIndex === seatIndex) {
        return { ...existingUserSeat, updatedSeat: existingUserSeat, vacatedSeatIndex: null, isNoop: true }; // Idempotent already on this seat
      }
      // Auto-vacate previous seat to allow seamless mic assignment/move
      vacatedSeatIndex = existingUserSeat.seatIndex;
      await tx.roomSeat.update({
        where: { id: existingUserSeat.id },
        data: { occupiedUserId: null },
      });
    }

    // Find target seat or auto-create if missing
    let targetSeat = await tx.roomSeat.findUnique({
      where: {
        roomId_seatIndex: {
          roomId: resolvedRoomId,
          seatIndex,
        },
      },
    });

    if (!targetSeat) {
      targetSeat = await tx.roomSeat.create({
        data: {
          roomId: resolvedRoomId,
          seatIndex,
          isMuted: false,
          isLocked: false,
        },
      });
    }

    if (seatIndex === 0 && room.creatorUserId !== userId) {
      const error = new Error('Seat 0 is reserved exclusively for the host');
      error.statusCode = 403;
      error.code = 'SEAT_RESERVED_FOR_HOST';
      throw error;
    }

    if (targetSeat.isLocked) {
      const error = new Error('Seat is locked');
      error.statusCode = 403;
      error.code = 'SEAT_LOCKED';
      throw error;
    }

    if (targetSeat.occupiedUserId && targetSeat.occupiedUserId !== userId) {
      const error = new Error('Seat is already occupied by another user');
      error.statusCode = 409;
      error.code = 'SEAT_ALREADY_OCCUPIED';
      throw error;
    }

    // Check if user has an active moderation mute in this room
    const activeModMute = await tx.roomModeration.findFirst({
      where: {
        roomId: resolvedRoomId,
        targetUserId: userId,
        actionType: 'MUTE_MIC',
      },
    });
    const isModerationMuted = Boolean(activeModMute);

    const updatedSeat = await tx.roomSeat.update({
      where: {
        roomId_seatIndex: {
          roomId: resolvedRoomId,
          seatIndex,
        },
      },
      data: {
        occupiedUserId: userId,
        ...(isModerationMuted ? { isMuted: true, isMutedByModerator: true } : {}),
      },
      include: {
        occupiedUser: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: true,
          },
        },
      },
    });

    return { ...updatedSeat, updatedSeat, vacatedSeatIndex };
  }, { maxWait: 15000, timeout: 20000 });
}

export async function leaveSeatTx({ roomId, seatIndex, userId, force = false }, db = prisma) {
  return await db.$transaction(async (tx) => {
    let resolvedRoomId = roomId;
    let seat = await tx.roomSeat.findUnique({
      where: {
        roomId_seatIndex: {
          roomId: resolvedRoomId,
          seatIndex,
        },
      },
      include: {
        room: true,
      },
    });

    if (!seat && roomId && roomId.length <= 16) {
      const room = await tx.room.findFirst({
        where: { id: { startsWith: roomId, mode: 'insensitive' } },
        select: { id: true },
      });
      if (room) {
        resolvedRoomId = room.id;
        seat = await tx.roomSeat.findUnique({
          where: {
            roomId_seatIndex: {
              roomId: resolvedRoomId,
              seatIndex,
            },
          },
          include: {
            room: true,
          },
        });
      }
    }

    if (!seat) {
      const error = new Error('Seat not found');
      error.statusCode = 404;
      error.code = 'SEAT_NOT_FOUND';
      throw error;
    }

    if (!seat.occupiedUserId) {
      return { ...seat, isNoop: true }; // Already empty
    }

    const isSeatOwner = seat.occupiedUserId === userId;
    const isRoomCreator = seat.room.creatorUserId === userId;

    if (!isSeatOwner && !isRoomCreator && !force) {
      const error = new Error('Unauthorized to release this seat');
      error.statusCode = 403;
      error.code = 'FORBIDDEN';
      throw error;
    }

    return await tx.roomSeat.update({
      where: {
        roomId_seatIndex: {
          roomId: resolvedRoomId,
          seatIndex,
        },
      },
      data: {
        occupiedUserId: null,
        isMuted: false,
        isMutedByModerator: false,
      },
    });
  }, { maxWait: 15000, timeout: 20000 });
}

export async function pinRoom({ roomId, isPinnedTop, pinnedPosition = null }, db = prisma) {
  if (isPinnedTop && pinnedPosition) {
    // Unpin any other room occupying the exact same pinned position
    await db.room.updateMany({
      where: {
        id: { not: roomId },
        isPinnedTop: true,
        pinnedPosition: Number(pinnedPosition),
      },
      data: {
        isPinnedTop: false,
        pinnedPosition: null,
      },
    });
  }

  return await db.room.update({
    where: { id: roomId },
    data: {
      isPinnedTop,
      pinnedPosition: isPinnedTop ? (Number(pinnedPosition) || 1) : null,
    },
  });
}

export async function closeRoomTx({ roomId, status = 'ENDED', endedAt = new Date() }, db = prisma) {
  return await db.$transaction(async (tx) => {
    // Release all seats
    await tx.roomSeat.updateMany({
      where: { roomId },
      data: {
        occupiedUserId: null,
        isMuted: false,
      },
    });

    // Delete all active memberships
    await tx.roomMember.deleteMany({
      where: { roomId },
    });

    return await tx.room.update({
      where: { id: roomId },
      data: {
        status,
        endedAt,
        currentViewersCount: 0,
      },
    });
  });
}

export async function updateRoomCoverImage({ roomId, coverImageUrl }, db = prisma) {
  return await db.room.update({
    where: { id: roomId },
    data: { coverImageUrl },
  });
}

export async function updateRoomBackgroundTx({ roomId, backgroundImageUrl }, db = prisma) {
  let resolvedRoomId = roomId;
  let room = await db.room.findUnique({ where: { id: roomId }, select: { id: true } });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }
  resolvedRoomId = room.id;

  return await db.room.update({
    where: { id: resolvedRoomId },
    data: { backgroundImageUrl },
  });
}

export async function updateRoomMuteStatus({ roomId, isMuted }, db = prisma) {
  // Update all seats in the room
  await db.roomSeat.updateMany({
    where: { roomId },
    data: { isMuted: Boolean(isMuted) },
  });

  return await db.room.findUnique({
    where: { id: roomId },
  });
}

export async function updateSeatMuteStatus({ roomId, seatIndex, isMuted, isMutedByModerator, isModerator = false }, db = prisma) {
  const index = Number(seatIndex);

  // If unmuting, verify if seat is under moderation mute
  if (!isMuted && !isModerator) {
    const existing = await db.roomSeat.findUnique({
      where: { roomId_seatIndex: { roomId, seatIndex: index } },
    });
    if (existing?.isMutedByModerator) {
      const error = new Error('Microphone is muted by room moderation and cannot be unmuted');
      error.statusCode = 403;
      error.code = 'CANNOT_OVERRIDE_MODERATION_MUTE';
      throw error;
    }
  }

  const updateData = { isMuted: Boolean(isMuted) };
  if (isMutedByModerator !== undefined) {
    updateData.isMutedByModerator = Boolean(isMutedByModerator);
  }

  try {
    return await db.roomSeat.update({
      where: {
        roomId_seatIndex: {
          roomId,
          seatIndex: index,
        },
      },
      data: updateData,
    });
  } catch {
    return await db.roomSeat.upsert({
      where: {
        roomId_seatIndex: {
          roomId,
          seatIndex: index,
        },
      },
      update: updateData,
      create: {
        roomId,
        seatIndex: index,
        isMuted: Boolean(isMuted),
        isMutedByModerator: Boolean(isMutedByModerator),
      },
    });
  }
}

export async function updateSeatLockStatus({ roomId, seatIndex, isLocked }, db = prisma) {
  const index = Number(seatIndex);
  const updateData = { isLocked: Boolean(isLocked) };

  try {
    return await db.roomSeat.update({
      where: {
        roomId_seatIndex: {
          roomId,
          seatIndex: index,
        },
      },
      data: updateData,
    });
  } catch {
    return await db.roomSeat.upsert({
      where: {
        roomId_seatIndex: {
          roomId,
          seatIndex: index,
        },
      },
      update: updateData,
      create: {
        roomId,
        seatIndex: index,
        isMuted: false,
        isLocked: Boolean(isLocked),
      },
    });
  }
}

export async function updateUserSeatMuteStatus({ roomId, userId, isMuted, isMutedByModerator, isModerator = false }, db = prisma) {
  // Check if target is currently moderation muted
  if (!isMuted && !isModerator) {
    const modMute = await db.roomModeration.findFirst({
      where: {
        roomId,
        targetUserId: userId,
        actionType: 'MUTE_MIC',
      },
    });
    if (modMute) {
      const error = new Error('Microphone is muted by room moderation and cannot be unmuted');
      error.statusCode = 403;
      error.code = 'CANNOT_OVERRIDE_MODERATION_MUTE';
      throw error;
    }
  }

  // Check if user occupies a seat
  const seat = await db.roomSeat.findFirst({
    where: { roomId, occupiedUserId: userId },
  });

  if (seat) {
    if (!isMuted && !isModerator && seat.isMutedByModerator) {
      const error = new Error('Microphone is muted by room moderation and cannot be unmuted');
      error.statusCode = 403;
      error.code = 'CANNOT_OVERRIDE_MODERATION_MUTE';
      throw error;
    }
    const updateData = { isMuted: Boolean(isMuted) };
    if (isMutedByModerator !== undefined) {
      updateData.isMutedByModerator = Boolean(isMutedByModerator);
    }
    return await db.roomSeat.update({
      where: { id: seat.id },
      data: updateData,
    });
  }

  // Check if user is the room creator
  const room = await db.room.findUnique({
    where: { id: roomId },
    select: { creatorUserId: true },
  });

  if (room && room.creatorUserId === userId) {
    return await updateSeatMuteStatus({ roomId, seatIndex: 0, isMuted, isMutedByModerator, isModerator }, db);
  }

  return null;
}

export async function kickUserFromRoomTx({ roomId, targetUserId }, db = prisma) {
  return await db.$transaction(async (tx) => {
    // 1. Release any seat occupied by this user
    await tx.roomSeat.updateMany({
      where: {
        roomId,
        occupiedUserId: targetUserId,
      },
      data: {
        occupiedUserId: null,
        isMuted: false,
        isMutedByModerator: false,
      },
    });

    // 2. Remove room membership
    await tx.roomMember.deleteMany({
      where: {
        roomId,
        userId: targetUserId,
      },
    });

    // 3. Decrement viewer count if greater than 0
    const room = await tx.room.findUnique({ where: { id: roomId } });
    if (room && room.currentViewersCount > 0) {
      await tx.room.update({
        where: { id: roomId },
        data: { currentViewersCount: { decrement: 1 } },
      });
    }

    return { roomId, targetUserId };
  });
}

export async function updateRoomLockSettings({ roomId, isLocked, roomPin = null }, db = prisma) {
  let resolvedRoomId = roomId;
  let room = await db.room.findUnique({ where: { id: roomId }, select: { id: true } });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }
  resolvedRoomId = room.id;

  return await db.room.update({
    where: { id: resolvedRoomId },
    data: {
      isPrivate: Boolean(isLocked),
      roomPin: isLocked ? roomPin : null,
    },
  });
}

export async function updateRoomDetails({ roomId, title, coverImageUrl, category, roomType, backgroundImageUrl }, db = prisma) {
  let resolvedRoomId = roomId;
  let room = await db.room.findUnique({ where: { id: roomId }, select: { id: true } });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }
  resolvedRoomId = room.id;

  const data = {};
  if (title !== undefined && title !== null && String(title).trim() !== '') data.title = String(title).trim();
  if (coverImageUrl !== undefined) data.coverImageUrl = coverImageUrl;
  const validCategories = ['MUSIC', 'CHAT', 'GAMING'];
  if (category && validCategories.includes(String(category).toUpperCase())) {
    data.category = String(category).toUpperCase();
  }
  if (roomType !== undefined && roomType !== null) data.roomType = roomType;
  if (backgroundImageUrl !== undefined) data.backgroundImageUrl = backgroundImageUrl;

  return await db.room.update({
    where: { id: resolvedRoomId },
    data,
  });
}

export async function updateRoomLayoutTx({ roomId, capacity, roomType }, db = prisma) {
  return await db.$transaction(async (tx) => {
    let resolvedRoomId = roomId;
    let room = await tx.room.findUnique({
      where: { id: roomId },
      include: {
        seats: {
          orderBy: { seatIndex: 'asc' },
          include: {
            occupiedUser: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
      },
    });

    if (!room && roomId && roomId.length <= 16) {
      room = await tx.room.findFirst({
        where: { id: { startsWith: roomId, mode: 'insensitive' } },
        include: {
          seats: {
            orderBy: { seatIndex: 'asc' },
            include: {
              occupiedUser: {
                select: {
                  id: true,
                  username: true,
                  avatarUrl: true,
                  profile: true,
                },
              },
            },
          },
        },
      });
      if (room) {
        resolvedRoomId = room.id;
      }
    }

    if (!room) {
      const error = new Error('Room not found');
      error.statusCode = 404;
      error.code = 'ROOM_NOT_FOUND';
      throw error;
    }

    const currentSeats = room.seats || [];
    const targetCapacity = Math.max(8, Math.min(30, parseInt(capacity, 10) || 10));

    // Handle Seat Expansion: add missing indices up to targetCapacity
    if (targetCapacity > currentSeats.length) {
      const existingIndices = new Set(currentSeats.map((s) => s.seatIndex));
      const newSeatsData = [];
      for (let i = 0; i < targetCapacity; i++) {
        if (!existingIndices.has(i)) {
          newSeatsData.push({
            roomId: resolvedRoomId,
            seatIndex: i,
            isMuted: false,
            isLocked: false,
            occupiedUserId: null,
          });
        }
      }
      if (newSeatsData.length > 0) {
        await tx.roomSeat.createMany({
          data: newSeatsData,
        });
      }
    } else if (targetCapacity < currentSeats.length) {
      // Handle Seat Shrinking: Gracefully remove unoccupied seats above targetCapacity
      await tx.roomSeat.deleteMany({
        where: {
          roomId: resolvedRoomId,
          seatIndex: { gte: targetCapacity },
          occupiedUserId: null,
        },
      });
    }

    // Update roomType if valid and provided
    const updateData = {};
    if (roomType && ['LIVE_VIDEO', 'AUDIO_PARTY'].includes(String(roomType).toUpperCase())) {
      updateData.roomType = String(roomType).toUpperCase();
    }

    if (Object.keys(updateData).length > 0) {
      await tx.room.update({
        where: { id: resolvedRoomId },
        data: updateData,
      });
    }

    // Return the updated room with freshly ordered seats
    const updatedRoom = await tx.room.findUnique({
      where: { id: resolvedRoomId },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: true,
          },
        },
        seats: {
          orderBy: { seatIndex: 'asc' },
          include: {
            occupiedUser: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
                profile: true,
              },
            },
          },
        },
      },
    });

    return updatedRoom;
  }, { timeout: 20000, maxWait: 10000 });
}

export default {
  createRoomWithSeats,
  findRoomById,
  findActiveRooms,
  findAdminRooms,
  joinRoomTx,
  leaveRoomTx,
  occupySeatTx,
  leaveSeatTx,
  pinRoom,
  closeRoomTx,
  updateRoomCoverImage,
  updateRoomBackgroundTx,
  updateRoomMuteStatus,
  updateSeatMuteStatus,
  updateSeatLockStatus,
  updateUserSeatMuteStatus,
  kickUserFromRoomTx,
  updateRoomLockSettings,
  updateRoomDetails,
  updateRoomLayoutTx,
};
