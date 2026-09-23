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
  return await db.user.findFirst({
    where: {
      username: {
        equals: username.trim(),
        mode: 'insensitive',
      },
    },
  });
}

export async function createUserWithProfile(
  { id = null, phone = null, email = null, username, displayName = null, avatarUrl = null, coverUrl = null, status = 'ACTIVE', userType = 'USER', countryCode = 'PK', coinBalance = 0, diamondBalance = 0 },
  db = prisma
) {
  let finalId = id;
  if (!finalId) {
    let unique = false;
    while (!unique) {
      const candidateId = Math.floor(1000000 + Math.random() * 9000000).toString();
      const existing = await db.user.findUnique({ where: { id: candidateId } });
      if (!existing) {
        finalId = candidateId;
        unique = true;
      }
    }
  }

  const data = {
    id: finalId,
    phone: phone || null,
    email: email || null,
    username,
    status,
    userType,
    countryCode: countryCode || 'PK',
    avatarUrl: avatarUrl || null,
    profile: {
      create: {
        displayName: displayName || username,
      },
    },
    wallet: {
      create: {
        coinBalance: BigInt(coinBalance || 0),
        diamondBalance: BigInt(diamondBalance || 0),
      },
    },
  };
  return await db.user.create({
    data,
    include: {
      profile: true,
      wallet: true,
      hostProfile: true,
    },
  });
}

export async function updateLastLogin(userId, db = prisma) {
  return await db.user.update({
    where: { id: userId },
    data: { lastLoginAt: new Date() },
  });
}

export async function findUsersPaginated(
  {
    page = 1,
    limit = 20,
    search = null,
    status = null,
    userType = null,
    countryCode = null,
    createdFrom = null,
    createdTo = null,
  } = {},
  db = prisma
) {
  const where = {};

  if (status) {
    where.status = status;
  }
  if (userType) {
    where.userType = userType;
  }
  if (countryCode) {
    where.countryCode = countryCode;
  }
  if (createdFrom || createdTo) {
    where.createdAt = {};
    if (createdFrom) where.createdAt.gte = new Date(createdFrom);
    if (createdTo) where.createdAt.lte = new Date(createdTo);
  }

  if (search && search.trim() !== '') {
    const s = search.trim();
    where.OR = [
      { username: { contains: s, mode: 'insensitive' } },
      { phone: { contains: s, mode: 'insensitive' } },
      { email: { contains: s, mode: 'insensitive' } },
      { profile: { displayName: { contains: s, mode: 'insensitive' } } },
    ];
  }

  // Authoritatively exclude Owner and Admin identities from normal User Management
  const allAdmins = db?.admin
    ? await db.admin.findMany({
        select: { id: true, email: true, username: true, isOwner: true },
      })
    : [];
  const adminIds = allAdmins.map((a) => a.id).filter(Boolean);
  const adminEmails = allAdmins.map((a) => a.email).filter(Boolean);
  const adminUsernames = allAdmins.map((a) => a.username).filter(Boolean);
  const shadowUsernames = adminUsernames.map((u) => `admin_${u}`);

  const andFilters = [];

  if (adminIds.length > 0) {
    andFilters.push({ id: { notIn: adminIds } });
  }

  if (adminEmails.length > 0) {
    andFilters.push({
      OR: [
        { email: null },
        {
          AND: [
            { email: { notIn: adminEmails } },
            { email: { not: { contains: 'owner@zeparty.app' } } },
          ],
        },
      ],
    });
  }

  andFilters.push({
    username: {
      notIn: [...adminUsernames, ...shadowUsernames],
      not: { startsWith: 'admin_' },
    },
  });

  if (where.AND) {
    if (Array.isArray(where.AND)) {
      where.AND.push(...andFilters);
    } else {
      where.AND = [where.AND, ...andFilters];
    }
  } else {
    where.AND = andFilters;
  }

  const parsedPage = Math.max(1, Number(page) || 1);
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const skip = (parsedPage - 1) * parsedLimit;

  const [total, users] = await Promise.all([
    db.user.count({ where }),
    db.user.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        firebaseUid: true,
        phone: true,
        email: true,
        username: true,
        status: true,
        userType: true,
        countryCode: true,
        avatarUrl: true,
        bio: true,
        gender: true,
        dob: true,
        lastLoginAt: true,
        createdAt: true,
        updatedAt: true,
        profile: {
          select: {
            id: true,
            displayName: true,
            level: true,
            vipLevel: true,
            svipLevel: true,
            nobleRank: true,
          },
        },
        wallet: {
          select: {
            id: true,
            coinBalance: true,
            diamondBalance: true,
            sellerBalanceCoins: true,
          },
        },
        hostProfile: {
          select: {
            id: true,
            hostType: true,
            hostStatus: true,
            hostLevel: true,
          },
        },
      },
    }),
  ]);

  return {
    users,
    pagination: {
      page: parsedPage,
      limit: parsedLimit,
      total,
      totalPages: Math.ceil(total / parsedLimit),
    },
  };
}

export async function findUserDetailsById(id, db = prisma) {
  if (!id) return null;

  return await db.user.findUnique({
    where: { id },
    select: {
      id: true,
      firebaseUid: true,
      phone: true,
      email: true,
      username: true,
      status: true,
      userType: true,
      countryCode: true,
      avatarUrl: true,
      bio: true,
      gender: true,
      dob: true,
      isUnderageBlocked: true,
      lastLoginAt: true,
      createdAt: true,
      updatedAt: true,
      profile: true,
      wallet: true,
      hostProfile: {
        include: {
          agency: {
            select: {
              id: true,
              agencyName: true,
              agencyCode: true,
              status: true,
            },
          },
        },
      },
      ownedAgencies: {
        select: {
          id: true,
          agencyName: true,
          agencyCode: true,
          status: true,
        },
      },
      managedBDCenters: {
        select: {
          id: true,
          centerName: true,
          regionCode: true,
          currentTier: true,
        },
      },
      coinSeller: true,
      merchant: {
        select: {
          id: true,
          companyName: true,
          monthlyQuotaCoins: true,
          totalSpentUSD: true,
          status: true,
        },
      },
      sessions: {
        take: 5,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          ipAddress: true,
          userAgent: true,
          expiresAt: true,
          revokedAt: true,
          createdAt: true,
        },
      },
      devices: {
        take: 5,
        orderBy: { lastSeenAt: 'desc' },
        select: {
          id: true,
          platform: true,
          deviceModel: true,
          appVersion: true,
          isBlocked: true,
          lastSeenAt: true,
        },
      },
    },
  });
}

export async function updateUserStatus(id, status, db = prisma) {
  return await db.user.update({
    where: { id },
    data: { status },
    select: {
      id: true,
      username: true,
      status: true,
      updatedAt: true,
    },
  });
}

export async function updateUserProfile(
  userId,
  { username, name, displayName, bio, gender, dob, birthDate, dateOfBirth, avatarUrl, coverUrl, signature, countryCode, region },
  db = prisma
) {
  const userUpdateData = {};
  if (username !== undefined && username.trim().length >= 3) {
    // Check if username is already taken by another user
    const existing = await db.user.findFirst({
      where: {
        username: username.trim(),
        NOT: { id: userId },
      },
    });
    if (!existing) {
      userUpdateData.username = username.trim();
    }
  }
  if (bio !== undefined) userUpdateData.bio = bio;
  if (gender !== undefined) userUpdateData.gender = gender;
  
  const effectiveDob = dob || birthDate || dateOfBirth;
  if (effectiveDob !== undefined) {
    const parsedDate = effectiveDob ? new Date(effectiveDob) : null;
    if (parsedDate && !isNaN(parsedDate.getTime())) {
      userUpdateData.dob = parsedDate;
    }
  }
  
  if (avatarUrl !== undefined) userUpdateData.avatarUrl = avatarUrl;
  if (coverUrl !== undefined && coverUrl !== null) userUpdateData.coverUrl = coverUrl;
  if (countryCode !== undefined) userUpdateData.countryCode = countryCode;
  if (region !== undefined && region !== null && region.trim().length > 0) userUpdateData.region = region.trim();

  const profileUpdateData = {};
  const effectiveDisplayName = displayName || name;
  if (effectiveDisplayName !== undefined) profileUpdateData.displayName = effectiveDisplayName;
  if (signature !== undefined) profileUpdateData.signature = signature;

  return await db.$transaction(async (tx) => {
    if (Object.keys(userUpdateData).length > 0) {
      await tx.user.update({
        where: { id: userId },
        data: userUpdateData,
      });
    }

    if (Object.keys(profileUpdateData).length > 0) {
      await tx.userProfile.upsert({
        where: { userId },
        create: {
          userId,
          displayName: profileUpdateData.displayName || null,
          signature: profileUpdateData.signature || null,
        },
        update: profileUpdateData,
      });
    }

    return await tx.user.findUnique({
      where: { id: userId },
      include: {
        profile: true,
        wallet: true,
        hostProfile: true,
      },
    });
  });
}

export async function findPublicProfileById(id, db = prisma) {
  if (!id) return null;
  return await db.user.findUnique({
    where: { id },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      bio: true,
      gender: true,
      countryCode: true,
      userType: true,
      createdAt: true,
      profile: {
        select: {
          displayName: true,
          level: true,
          vipLevel: true,
          svipLevel: true,
          nobleRank: true,
          signature: true,
        },
      },
      hostProfile: {
        select: {
          hostType: true,
          hostLevel: true,
          hostStatus: true,
        },
      },
    },
  });
}

export async function deleteUserById(id, db = prisma) {
  if (!id) return null;

  // 1. Clean up GiftTransactions sent or received
  try {
    if (db.giftTransaction?.deleteMany) {
      await db.giftTransaction.deleteMany({
        where: {
          OR: [{ senderUserId: id }, { recipientUserId: id }],
        },
      });
    }
  } catch (_) {}

  // 2. Clean up P2P Escrow Orders
  try {
    if (db.p2PEscrowOrder?.deleteMany) {
      await db.p2PEscrowOrder.deleteMany({
        where: {
          OR: [{ buyerUserId: id }, { sellerUserId: id }],
        },
      });
    }
  } catch (_) {}

  // 3. Clean up PK Events if host profile exists
  try {
    const host = await db.hostProfile?.findUnique?.({ where: { userId: id }, select: { id: true } });
    if (host && db.pKEvent?.deleteMany) {
      await db.pKEvent.deleteMany({
        where: {
          OR: [{ hostAUserId: host.id }, { hostBUserId: host.id }],
        },
      });
    }
  } catch (_) {}

  // 4. Clean up Agencies owned by this user
  try {
    const ownedAgencies = await db.agency?.findMany?.({
      where: { ownerUserId: id },
      select: { id: true },
    });
    if (ownedAgencies && ownedAgencies.length > 0) {
      const agencyIds = ownedAgencies.map((a) => a.id);
      if (db.hostProfile?.updateMany) {
        await db.hostProfile.updateMany({
          where: { agencyId: { in: agencyIds } },
          data: { agencyId: null },
        });
      }
      if (db.agencyMember?.deleteMany) {
        await db.agencyMember.deleteMany({
          where: { agencyId: { in: agencyIds } },
        });
      }
      if (db.agency?.deleteMany) {
        await db.agency.deleteMany({
          where: { id: { in: agencyIds } },
        });
      }
    }
  } catch (_) {}

  // 5. Clean up BDCenters managed by this user
  try {
    const managedBDs = await db.bDCenter?.findMany?.({
      where: { managerUserId: id },
      select: { id: true },
    });
    if (managedBDs && managedBDs.length > 0) {
      const bdIds = managedBDs.map((b) => b.id);
      if (db.agency?.updateMany) {
        await db.agency.updateMany({
          where: { bdCenterId: { in: bdIds } },
          data: { bdCenterId: null },
        });
      }
      if (db.hostProfile?.updateMany) {
        await db.hostProfile.updateMany({
          where: { bdCenterId: { in: bdIds } },
          data: { bdCenterId: null },
        });
      }
      if (db.bDInvite?.deleteMany) {
        await db.bDInvite.deleteMany({
          where: { bdCenterId: { in: bdIds } },
        });
      }
      if (db.bDCenter?.deleteMany) {
        await db.bDCenter.deleteMany({
          where: { id: { in: bdIds } },
        });
      }
    }
  } catch (_) {}

  // 6. Clean up Rooms created by this user
  try {
    const userRooms = await db.room?.findMany?.({
      where: { creatorUserId: id },
      select: { id: true },
    });
    if (userRooms && userRooms.length > 0) {
      const roomIds = userRooms.map((r) => r.id);
      if (db.giftTransaction?.deleteMany) {
        await db.giftTransaction.deleteMany({
          where: { roomId: { in: roomIds } },
        });
      }
      if (db.roomModerationAction?.deleteMany) {
        await db.roomModerationAction.deleteMany({
          where: { roomId: { in: roomIds } },
        });
      }
      if (db.roomMember?.deleteMany) {
        await db.roomMember.deleteMany({
          where: { roomId: { in: roomIds } },
        });
      }
      if (db.roomSeat?.deleteMany) {
        await db.roomSeat.deleteMany({
          where: { roomId: { in: roomIds } },
        });
      }
      if (db.room?.deleteMany) {
        await db.room.deleteMany({
          where: { id: { in: roomIds } },
        });
      }
    }
  } catch (_) {}

  // 7. Clean up Social, Likes, Comments, Posts, Follows, Messages
  try {
    if (db.like?.deleteMany) {
      await db.like.deleteMany({ where: { userId: id } });
    }
    if (db.comment?.deleteMany) {
      await db.comment.deleteMany({ where: { userId: id } });
    }
    const userPosts = await db.post?.findMany?.({ where: { userId: id }, select: { id: true } });
    if (userPosts && userPosts.length > 0) {
      const pIds = userPosts.map((p) => p.id);
      if (db.like?.deleteMany) await db.like.deleteMany({ where: { postId: { in: pIds } } });
      if (db.comment?.deleteMany) await db.comment.deleteMany({ where: { postId: { in: pIds } } });
      if (db.post?.deleteMany) await db.post.deleteMany({ where: { id: { in: pIds } } });
    }
    if (db.follow?.deleteMany) {
      await db.follow.deleteMany({
        where: { OR: [{ followerId: id }, { followingId: id }] },
      });
    }
    if (db.message?.deleteMany) {
      await db.message.deleteMany({
        where: { OR: [{ senderUserId: id }, { recipientUserId: id }] },
      });
    }
    if (db.notification?.deleteMany) {
      await db.notification.deleteMany({ where: { userId: id } });
    }
    if (db.notificationPreference?.deleteMany) {
      await db.notificationPreference.deleteMany({ where: { userId: id } });
    }
  } catch (_) {}

  // 8. Clean up Reports, Moderation, Support Tickets, Restrictions, Transactions
  try {
    if (db.report?.deleteMany) {
      await db.report.deleteMany({
        where: {
          OR: [{ reporterUserId: id }, { reportedUserId: id }],
        },
      });
    }
    if (db.restriction?.deleteMany) {
      await db.restriction.deleteMany({ where: { userId: id } });
    }
    if (db.moderationAction?.deleteMany) {
      await db.moderationAction.deleteMany({ where: { targetId: id } });
    }
    if (db.supportTicket?.deleteMany) {
      await db.supportTicket.deleteMany({ where: { userId: id } });
    }
    if (db.userBlock?.deleteMany) {
      await db.userBlock.deleteMany({
        where: { OR: [{ blockerId: id }, { blockedId: id }] },
      });
    }
    if (db.onlineRecharge?.deleteMany) await db.onlineRecharge.deleteMany({ where: { userId: id } });
    if (db.offlineRecharge?.deleteMany) await db.offlineRecharge.deleteMany({ where: { userId: id } });
    if (db.withdrawalRequest?.deleteMany) await db.withdrawalRequest.deleteMany({ where: { userId: id } });
    if (db.coinRefund?.deleteMany) await db.coinRefund.deleteMany({ where: { userId: id } });
    if (db.chargeback?.deleteMany) await db.chargeback.deleteMany({ where: { userId: id } });
    if (db.userAsset?.deleteMany) await db.userAsset.deleteMany({ where: { userId: id } });
    if (db.gameTransaction?.deleteMany) await db.gameTransaction.deleteMany({ where: { userId: id } });
    if (db.settlementRecord?.deleteMany) await db.settlementRecord.deleteMany({ where: { userId: id } });
    if (db.settlementAdjustment?.deleteMany) await db.settlementAdjustment.deleteMany({ where: { userId: id } });
    if (db.hostApplication?.deleteMany) await db.hostApplication.deleteMany({ where: { userId: id } });
    if (db.coinSeller?.deleteMany) await db.coinSeller.deleteMany({ where: { userId: id } });
    if (db.merchant?.deleteMany) await db.merchant.deleteMany({ where: { userId: id } });
    if (db.roomMember?.deleteMany) await db.roomMember.deleteMany({ where: { userId: id } });
    if (db.roomSeat?.deleteMany) await db.roomSeat.deleteMany({ where: { userId: id } });
    if (db.userSession?.deleteMany) await db.userSession.deleteMany({ where: { userId: id } });
    if (db.userDevice?.deleteMany) await db.userDevice.deleteMany({ where: { userId: id } });
    if (db.hostProfile?.deleteMany) await db.hostProfile.deleteMany({ where: { userId: id } });
    if (db.userProfile?.deleteMany) await db.userProfile.deleteMany({ where: { userId: id } });
    if (db.wallet?.deleteMany) await db.wallet.deleteMany({ where: { userId: id } });
  } catch (_) {}

  // 9. Delete the user safely from PostgreSQL
  return await db.user.delete({
    where: { id },
  });
}

/**
 * Search users by username, display name, phone, or id
 */
export async function searchUsers(query, { limit = 20, excludeUserId = null } = {}, db = prisma) {
  if (!query || !query.trim()) return [];
  const q = query.trim();
  const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));

  const where = {
    status: 'ACTIVE',
    OR: [
      { username: { contains: q, mode: 'insensitive' } },
      { phone: { contains: q, mode: 'insensitive' } },
      { bio: { contains: q, mode: 'insensitive' } },
      { profile: { displayName: { contains: q, mode: 'insensitive' } } },
      ...(q.length === 36 ? [{ id: q }] : []),
    ],
  };

  if (excludeUserId) {
    where.NOT = { id: excludeUserId };
  }

  const users = await db.user.findMany({
    where,
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      bio: true,
      gender: true,
      dob: true,
      countryCode: true,
      profile: {
        select: {
          displayName: true,
          signature: true,
          level: true,
          vipLevel: true,
        },
      },
    },
    take: limitNum,
  });

  return users.map((u) => ({
    id: u.id,
    username: u.username,
    name: u.profile?.displayName || u.username,
    displayName: u.profile?.displayName || u.username,
    avatarUrl: u.avatarUrl || '',
    bio: u.bio || u.profile?.signature || '',
    gender: u.gender || 'Not Specified',
    dob: u.dob,
    countryCode: u.countryCode || 'US',
    isVip: (u.profile?.vipLevel || 0) > 0,
    vipLevel: u.profile?.vipLevel ? `VIP ${u.profile.vipLevel}` : 'None',
  }));
}

export default {
  findByPhone,
  findById,
  findUserById: findById,
  findByEmail,
  findByUsername,
  createUserWithProfile,
  updateLastLogin,
  findUsersPaginated,
  findUserDetailsById,
  updateUserStatus,
  updateUserProfile,
  findPublicProfileById,
  deleteUserById,
  searchUsers,
};


