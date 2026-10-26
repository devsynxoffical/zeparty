import prisma from '../config/database.js';

/**
 * Social Repository
 * Data access layer for Likes, Comments, Follows, Blocks, Reports, and Profile counters.
 */

// ============================================================
// LIKES
// ============================================================

export async function createLike({ postId, userId }, db = prisma) {
  return await db.like.create({
    data: {
      postId,
      userId,
    },
  });
}

export async function deleteLike({ postId, userId }, db = prisma) {
  return await db.like.delete({
    where: {
      userId_postId: {
        userId,
        postId,
      },
    },
  });
}

export async function findLike({ postId, userId }, db = prisma) {
  return await db.like.findUnique({
    where: {
      userId_postId: {
        userId,
        postId,
      },
    },
  });
}

export async function countLikes(postId, db = prisma) {
  return await db.like.count({
    where: { postId },
  });
}

export async function isPostLikedByUser(postId, userId, db = prisma) {
  if (!postId || !userId || !db.like?.findUnique) return false;
  const like = await db.like.findUnique({
    where: {
      userId_postId: {
        userId,
        postId,
      },
    },
  });
  return Boolean(like);
}

// ============================================================
// COMMENTS
// ============================================================

export async function createComment({ postId, userId, content, parentId = null }, db = prisma) {
  return await db.comment.create({
    data: {
      postId,
      userId,
      content,
      parentId,
    },
    include: {
      user: {
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
    },
  });
}

export async function findCommentById(id, db = prisma) {
  if (!id) return null;
  return await db.comment.findFirst({
    where: {
      id,
      deletedAt: null,
    },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
        },
      },
      post: {
        select: {
          id: true,
          userId: true,
          visibility: true,
        },
      },
    },
  });
}

export async function findCommentsByPost(
  postId,
  { page = 1, limit = 20, parentId = null } = {},
  db = prisma
) {
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const parsedPage = Math.max(1, Number(page) || 1);
  const skip = (parsedPage - 1) * parsedLimit;

  const where = {
    postId,
    deletedAt: null,
    parentId: parentId || null,
  };

  const [total, comments] = await Promise.all([
    db.comment.count({ where }),
    db.comment.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: { createdAt: 'asc' },
      include: {
        user: {
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
        replies: {
          where: { deletedAt: null },
          orderBy: { createdAt: 'asc' },
          take: 5,
          include: {
            user: {
              select: {
                id: true,
                username: true,
                avatarUrl: true,
              },
            },
          },
        },
        _count: {
          select: { replies: { where: { deletedAt: null } } },
        },
      },
    }),
  ]);

  return {
    comments,
    pagination: {
      page: parsedPage,
      limit: parsedLimit,
      total,
      totalPages: Math.ceil(total / parsedLimit) || 1,
    },
  };
}

export async function softDeleteComment(id, db = prisma) {
  return await db.comment.update({
    where: { id },
    data: { deletedAt: new Date() },
  });
}

export const deleteComment = softDeleteComment;
export const findCommentsByPostId = findCommentsByPost;

export async function countComments(postId, db = prisma) {
  return await db.comment.count({
    where: {
      postId,
      deletedAt: null,
    },
  });
}

// ============================================================
// FOLLOWS
// ============================================================

export async function createFollow({ followerId, followingId, status = 'ACCEPTED' }, db = prisma) {
  return await db.follow.create({
    data: {
      followerId,
      followingId,
      status,
    },
  });
}

export async function deleteFollow({ followerId, followingId }, db = prisma) {
  return await db.follow.delete({
    where: {
      followerId_followingId: {
        followerId,
        followingId,
      },
    },
  });
}

export async function findFollow({ followerId, followingId }, db = prisma) {
  return await db.follow.findUnique({
    where: {
      followerId_followingId: {
        followerId,
        followingId,
      },
    },
  });
}

export async function findFollowingUserIds(followerId, db = prisma) {
  const follows = await db.follow.findMany({
    where: {
      followerId,
      status: 'ACCEPTED',
    },
    select: { followingId: true },
  });
  return follows.map((f) => f.followingId);
}

// ============================================================
// CANONICAL USER RESOLUTION
// ============================================================

export async function resolveCanonicalUser(identifier, db = prisma) {
  if (!identifier) return null;
  const strId = String(identifier).trim();
  if (!strId) return null;

  // 1. Direct primary key lookup (e.g. public ID "9202535")
  const directUser = await db.user.findUnique({
    where: { id: strId },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      bio: true,
      region: true,
      countryCode: true,
      status: true,
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
          isPrivate: true,
          followersCount: true,
          followingCount: true,
          postsCount: true,
        },
      },
    },
  });

  if (directUser && directUser.status !== 'DELETED') {
    return directUser;
  }

  // 2. Secondary lookup by username or email, prioritizing non-deleted accounts
  const candidates = await db.user.findMany({
    where: {
      OR: [
        { id: strId },
        { username: strId },
        { email: strId },
      ],
    },
    orderBy: [
      { status: 'asc' }, // 'ACTIVE' comes before 'DELETED'
      { createdAt: 'desc' },
    ],
    take: 5,
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      bio: true,
      region: true,
      countryCode: true,
      status: true,
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
          isPrivate: true,
          followersCount: true,
          followingCount: true,
          postsCount: true,
        },
      },
    },
  });

  const activeCandidate = candidates.find((c) => c.status !== 'DELETED');
  return activeCandidate || directUser || candidates[0] || null;
}

export async function findFollowers(userId, { viewerUserId = null, page = 1, limit = 20 } = {}, db = prisma) {
  const targetUser = await resolveCanonicalUser(userId, db);
  if (!targetUser || targetUser.status === 'DELETED') {
    return {
      followers: [],
      pagination: {
        page: Number(page) || 1,
        limit: Number(limit) || 20,
        total: 0,
        totalPages: 1,
      },
      targetUser: null,
    };
  }

  const targetId = targetUser.id;
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const parsedPage = Math.max(1, Number(page) || 1);
  const skip = (parsedPage - 1) * parsedLimit;

  // Blocked users filter: if viewer is specified, exclude users blocked by or blocking viewer
  let blockedUserIds = [];
  if (viewerUserId) {
    blockedUserIds = await findBlockedUserIds(viewerUserId, db);
  }

  const where = {
    followingId: targetId,
    status: 'ACCEPTED',
    follower: {
      status: { not: 'DELETED' },
    },
  };

  if (blockedUserIds.length > 0) {
    where.followerId = { notIn: blockedUserIds };
  }

  const [total, follows] = await Promise.all([
    db.follow.count({ where }),
    db.follow.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: [
        { createdAt: 'desc' },
        { followerId: 'asc' }, // deterministic tie-breaker
      ],
      include: {
        follower: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            bio: true,
            gender: true,
            region: true,
            status: true,
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
                isPrivate: true,
                followersCount: true,
                followingCount: true,
              },
            },
          },
        },
      },
    }),
  ]);

  // Determine viewer relationship state (isFollowing / isFollowedBy)
  const followerIds = follows.map((f) => f.follower.id);
  let viewerFollowsMap = new Set();
  let viewerFollowedByMap = new Set();

  if (viewerUserId && followerIds.length > 0) {
    const [viewerFollowing, viewerFollowers] = await Promise.all([
      db.follow.findMany({
        where: { followerId: viewerUserId, followingId: { in: followerIds }, status: 'ACCEPTED' },
        select: { followingId: true },
      }),
      db.follow.findMany({
        where: { followerId: { in: followerIds }, followingId: viewerUserId, status: 'ACCEPTED' },
        select: { followerId: true },
      }),
    ]);
    viewerFollowsMap = new Set(viewerFollowing.map((vf) => vf.followingId));
    viewerFollowedByMap = new Set(viewerFollowers.map((vf) => vf.followerId));
  }

  const formattedFollowers = follows.map((f) => {
    const u = f.follower;
    const displayName = u.profile?.displayName || u.username || `User ${u.id}`;
    const isFollowing = viewerFollowsMap.has(u.id);
    const isFollowedBy = viewerFollowedByMap.has(u.id);

    return {
      id: u.id,
      publicId: u.id,
      publicUserId: u.id,
      username: u.username,
      name: displayName,
      displayName,
      avatarUrl: u.avatarUrl || '',
      profileImage: u.avatarUrl || '',
      bio: u.bio || u.profile?.signature || '',
      gender: u.gender || 'Not Specified',
      region: u.region || 'Global',
      status: u.status,
      userType: u.userType || 'USER',
      level: u.profile?.level || 1,
      vipLevel: u.profile?.vipLevel || 0,
      svipLevel: u.profile?.svipLevel || 0,
      nobleRank: u.profile?.nobleRank || null,
      followersCount: u.profile?.followersCount || 0,
      followingCount: u.profile?.followingCount || 0,
      isFollowing,
      isFollowedBy,
      isMutual: isFollowing && isFollowedBy,
      createdAt: f.createdAt,
      profile: {
        displayName,
        avatarUrl: u.avatarUrl || '',
        level: u.profile?.level || 1,
        vipLevel: u.profile?.vipLevel || 0,
        svipLevel: u.profile?.svipLevel || 0,
        nobleRank: u.profile?.nobleRank || null,
        isPrivate: Boolean(u.profile?.isPrivate),
        followersCount: u.profile?.followersCount || 0,
        followingCount: u.profile?.followingCount || 0,
      },
    };
  });

  return {
    followers: formattedFollowers,
    pagination: {
      page: parsedPage,
      limit: parsedLimit,
      total,
      totalPages: Math.ceil(total / parsedLimit) || 1,
    },
    targetUser,
  };
}

export async function findFollowing(userId, { viewerUserId = null, page = 1, limit = 20 } = {}, db = prisma) {
  const targetUser = await resolveCanonicalUser(userId, db);
  if (!targetUser || targetUser.status === 'DELETED') {
    return {
      following: [],
      pagination: {
        page: Number(page) || 1,
        limit: Number(limit) || 20,
        total: 0,
        totalPages: 1,
      },
      targetUser: null,
    };
  }

  const targetId = targetUser.id;
  const parsedLimit = Math.max(1, Math.min(100, Number(limit) || 20));
  const parsedPage = Math.max(1, Number(page) || 1);
  const skip = (parsedPage - 1) * parsedLimit;

  // Blocked users filter
  let blockedUserIds = [];
  if (viewerUserId) {
    blockedUserIds = await findBlockedUserIds(viewerUserId, db);
  }

  const where = {
    followerId: targetId,
    status: 'ACCEPTED',
    following: {
      status: { not: 'DELETED' },
    },
  };

  if (blockedUserIds.length > 0) {
    where.followingId = { notIn: blockedUserIds };
  }

  const [total, follows] = await Promise.all([
    db.follow.count({ where }),
    db.follow.findMany({
      where,
      skip,
      take: parsedLimit,
      orderBy: [
        { createdAt: 'desc' },
        { followingId: 'asc' }, // deterministic tie-breaker
      ],
      include: {
        following: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            bio: true,
            gender: true,
            region: true,
            status: true,
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
                isPrivate: true,
                followersCount: true,
                followingCount: true,
              },
            },
          },
        },
      },
    }),
  ]);

  // Determine viewer relationship state (isFollowing / isFollowedBy)
  const followingIds = follows.map((f) => f.following.id);
  let viewerFollowsMap = new Set();
  let viewerFollowedByMap = new Set();

  if (viewerUserId && followingIds.length > 0) {
    const [viewerFollowing, viewerFollowers] = await Promise.all([
      db.follow.findMany({
        where: { followerId: viewerUserId, followingId: { in: followingIds }, status: 'ACCEPTED' },
        select: { followingId: true },
      }),
      db.follow.findMany({
        where: { followerId: { in: followingIds }, followingId: viewerUserId, status: 'ACCEPTED' },
        select: { followerId: true },
      }),
    ]);
    viewerFollowsMap = new Set(viewerFollowing.map((vf) => vf.followingId));
    viewerFollowedByMap = new Set(viewerFollowers.map((vf) => vf.followerId));
  }

  const formattedFollowing = follows.map((f) => {
    const u = f.following;
    const displayName = u.profile?.displayName || u.username || `User ${u.id}`;
    const isFollowing = viewerFollowsMap.has(u.id);
    const isFollowedBy = viewerFollowedByMap.has(u.id);

    return {
      id: u.id,
      publicId: u.id,
      publicUserId: u.id,
      username: u.username,
      name: displayName,
      displayName,
      avatarUrl: u.avatarUrl || '',
      profileImage: u.avatarUrl || '',
      bio: u.bio || u.profile?.signature || '',
      gender: u.gender || 'Not Specified',
      region: u.region || 'Global',
      status: u.status,
      userType: u.userType || 'USER',
      level: u.profile?.level || 1,
      vipLevel: u.profile?.vipLevel || 0,
      svipLevel: u.profile?.svipLevel || 0,
      nobleRank: u.profile?.nobleRank || null,
      followersCount: u.profile?.followersCount || 0,
      followingCount: u.profile?.followingCount || 0,
      isFollowing,
      isFollowedBy,
      isMutual: isFollowing && isFollowedBy,
      createdAt: f.createdAt,
      profile: {
        displayName,
        avatarUrl: u.avatarUrl || '',
        level: u.profile?.level || 1,
        vipLevel: u.profile?.vipLevel || 0,
        svipLevel: u.profile?.svipLevel || 0,
        nobleRank: u.profile?.nobleRank || null,
        isPrivate: Boolean(u.profile?.isPrivate),
        followersCount: u.profile?.followersCount || 0,
        followingCount: u.profile?.followingCount || 0,
      },
    };
  });

  return {
    following: formattedFollowing,
    pagination: {
      page: parsedPage,
      limit: parsedLimit,
      total,
      totalPages: Math.ceil(total / parsedLimit) || 1,
    },
    targetUser,
  };
}

// ============================================================
// PROFILE COUNTERS
// ============================================================

export async function incrementFollowersCount(userId, db = prisma) {
  const count = await db.follow.count({
    where: { followingId: userId, status: 'ACCEPTED', follower: { status: { not: 'DELETED' } } },
  });
  return await db.userProfile.upsert({
    where: { userId },
    update: { followersCount: count },
    create: { userId, followersCount: count },
  });
}

export async function decrementFollowersCount(userId, db = prisma) {
  const count = await db.follow.count({
    where: { followingId: userId, status: 'ACCEPTED', follower: { status: { not: 'DELETED' } } },
  });
  return await db.userProfile.upsert({
    where: { userId },
    update: { followersCount: count },
    create: { userId, followersCount: count },
  });
}

export async function incrementFollowingCount(userId, db = prisma) {
  const count = await db.follow.count({
    where: { followerId: userId, status: 'ACCEPTED', following: { status: { not: 'DELETED' } } },
  });
  return await db.userProfile.upsert({
    where: { userId },
    update: { followingCount: count },
    create: { userId, followingCount: count },
  });
}

export async function decrementFollowingCount(userId, db = prisma) {
  const count = await db.follow.count({
    where: { followerId: userId, status: 'ACCEPTED', following: { status: { not: 'DELETED' } } },
  });
  return await db.userProfile.upsert({
    where: { userId },
    update: { followingCount: count },
    create: { userId, followingCount: count },
  });
}

export async function incrementPostsCount(userId, db = prisma) {
  if (!db.userProfile?.updateMany && !db.userProfile?.update) return null;
  return await db.userProfile.updateMany({
    where: { userId },
    data: { postsCount: { increment: 1 } },
  });
}

export async function decrementPostsCount(userId, db = prisma) {
  if (!db.userProfile?.findUnique) return null;
  const profile = await db.userProfile.findUnique({ where: { userId } });
  if (!profile || profile.postsCount <= 0) return profile;
  return await db.userProfile.update({
    where: { userId },
    data: { postsCount: { decrement: 1 } },
  });
}

// ============================================================
// USER BLOCKS
// ============================================================

export async function createBlock({ blockerId, blockedId }, db = prisma) {
  return await db.userBlock.create({
    data: {
      blockerId,
      blockedId,
    },
  });
}

export async function deleteBlock({ blockerId, blockedId }, db = prisma) {
  return await db.userBlock.delete({
    where: {
      blockerId_blockedId: {
        blockerId,
        blockedId,
      },
    },
  });
}

export async function isBlocked(userA, userB, db = prisma) {
  if (!userA || !userB || userA === userB || !db.userBlock?.findFirst) return false;
  const block = await db.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: userA, blockedId: userB },
        { blockerId: userB, blockedId: userA },
      ],
    },
  });
  return Boolean(block);
}

export async function findBlockedUserIds(userId, db = prisma) {
  if (!userId) return [];
  const [blockedByMe, blockedMe] = await Promise.all([
    db.userBlock.findMany({
      where: { blockerId: userId },
      select: { blockedId: true },
    }),
    db.userBlock.findMany({
      where: { blockedId: userId },
      select: { blockerId: true },
    }),
  ]);

  const set = new Set([
    ...blockedByMe.map((b) => b.blockedId),
    ...blockedMe.map((b) => b.blockerId),
  ]);
  return Array.from(set);
}

// ============================================================
// REPORTS & MODERATION HOOKS
// ============================================================

export async function createReport(data, db = prisma) {
  return await db.report.create({
    data: {
      reporterUserId: data.reporterUserId,
      reportedUserId: data.reportedUserId || null,
      reportedPostId: data.reportedPostId || null,
      reportedCommentId: data.reportedCommentId || null,
      reportedRoomId: data.reportedRoomId || null,
      violationType: data.violationType || 'SPAM',
      description: data.description || null,
      screenshotUrl: data.screenshotUrl || null,
      status: 'PENDING',
    },
  });
}

// ============================================================
// SOCIAL PROFILE & PRIVACY
// ============================================================

export async function updateUserPrivacy(userId, isPrivate, db = prisma) {
  return await db.userProfile.upsert({
    where: { userId },
    update: { isPrivate: Boolean(isPrivate) },
    create: {
      userId,
      isPrivate: Boolean(isPrivate),
    },
  });
}

export async function findSocialProfile(userId, db = prisma) {
  if (!userId) return null;
  return await resolveCanonicalUser(userId, db);
}

// ─── Profile Visitors Tracking (NEW-16) ─────────────────────────────────────

export async function recordProfileVisit({ visitorId, visitedId, isMystery = false }, db = prisma) {
  if (!visitorId || !visitedId || visitorId === visitedId) return null;

  const [visitor, visited] = await Promise.all([
    resolveCanonicalUser(visitorId, db),
    resolveCanonicalUser(visitedId, db),
  ]);

  if (!visitor || !visited || visitor.id === visited.id) return null;
  if (visitor.status === 'DELETED' || visited.status === 'DELETED') return null;

  // Check if blocked in either direction
  const isBlocked = await db.userBlock.findFirst({
    where: {
      OR: [
        { blockerId: visitor.id, blockedId: visited.id },
        { blockerId: visited.id, blockedId: visitor.id },
      ],
    },
  });
  if (isBlocked) return null;

  // Upsert guarantees exactly ONE record per (visitor, visited) pair, updating visitedAt
  const record = await db.profileVisit.upsert({
    where: {
      visitorId_visitedId: {
        visitorId: visitor.id,
        visitedId: visited.id,
      },
    },
    update: {
      visitedAt: new Date(),
      isMystery: Boolean(isMystery),
    },
    create: {
      visitorId: visitor.id,
      visitedId: visited.id,
      isMystery: Boolean(isMystery),
      visitedAt: new Date(),
    },
  });

  return record;
}

export async function findProfileVisitors(visitedId, { page = 1, limit = 50, viewerUserId = null } = {}, db = prisma) {
  const target = await resolveCanonicalUser(visitedId, db);
  if (!target) {
    return { data: [], visitors: [], pagination: { page: 1, limit, total: 0, totalPages: 0, hasMore: false } };
  }

  // Check blocks
  const blocks = await db.userBlock.findMany({
    where: {
      OR: [
        { blockerId: target.id },
        { blockedId: target.id },
      ],
    },
  });
  const blockedIds = blocks.map(b => (b.blockerId === target.id ? b.blockedId : b.blockerId));

  const isOwner = Boolean(viewerUserId && (viewerUserId === target.id || viewerUserId === target.username));
  if (!isOwner) {
    return {
      data: [],
      visitors: [],
      pagination: {
        page: Math.max(1, Number(page) || 1),
        limit: Math.min(100, Math.max(1, Number(limit) || 50)),
        total: 0,
        totalPages: 0,
        hasMore: false,
      },
    };
  }

  const where = {
    visitedId: target.id,
    visitor: { status: { not: 'DELETED' } },
    ...(blockedIds.length > 0 ? { visitorId: { notIn: blockedIds } } : {}),
  };

  const pageNum = Math.max(1, Number(page) || 1);
  const limitNum = Math.min(100, Math.max(1, Number(limit) || 50));
  const skip = (pageNum - 1) * limitNum;

  const [total, visits] = await Promise.all([
    db.profileVisit.count({ where }),
    db.profileVisit.findMany({
      where,
      orderBy: [{ visitedAt: 'desc' }, { visitorId: 'asc' }],
      skip,
      take: limitNum,
      include: {
        visitor: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: {
              select: {
                displayName: true,
                level: true,
                svipLevel: true,
                nobleRank: true,
                followersCount: true,
                signature: true,
              },
            },
          },
        },
      },
    }),
  ]);

  const results = visits.map(visit => {
    const user = visit.visitor;
    const publicId = /^[1-9]\d{6}$/.test(user.id) ? user.id : (user.username && /^\d+$/.test(user.username) ? user.username : user.id);
    const displayName = user.profile?.displayName || user.username;
    const userObj = {
      id: publicId,
      publicUserId: publicId,
      publicId,
      username: user.username,
      name: displayName,
      displayName,
      nickname: displayName,
      avatarUrl: user.avatarUrl || '',
      accountLevel: user.profile?.level || 1,
      vipLevel: user.profile?.svipLevel ? `SVIP ${user.profile.svipLevel}` : (user.profile?.nobleRank || 'None'),
      followers: user.profile?.followersCount || 0,
      profile: {
        userId: publicId,
        displayName,
        bio: user.profile?.signature || null,
        signature: user.profile?.signature || null,
        avatarUrl: user.avatarUrl || '',
      },
    };

    return {
      id: visit.id,
      visitedAt: visit.visitedAt,
      isMystery: visit.isMystery,
      user: userObj,
      ...userObj,
    };
  });

  return {
    data: results,
    visitors: results,
    pagination: {
      page: pageNum,
      limit: limitNum,
      total,
      totalPages: Math.ceil(total / limitNum),
      hasMore: skip + results.length < total,
    },
  };
}

export async function findProfileVisited(visitorId, { page = 1, limit = 50, viewerUserId = null } = {}, db = prisma) {
  const target = await resolveCanonicalUser(visitorId, db);
  if (!target) {
    return { data: [], visited: [], pagination: { page: 1, limit, total: 0, totalPages: 0, hasMore: false } };
  }

  // Check blocks
  const blocks = await db.userBlock.findMany({
    where: {
      OR: [
        { blockerId: target.id },
        { blockedId: target.id },
      ],
    },
  });
  const blockedIds = blocks.map(b => (b.blockerId === target.id ? b.blockedId : b.blockerId));

  const isOwner = Boolean(viewerUserId && (viewerUserId === target.id || viewerUserId === target.username));
  if (!isOwner) {
    return {
      data: [],
      visited: [],
      pagination: {
        page: Math.max(1, Number(page) || 1),
        limit: Math.min(100, Math.max(1, Number(limit) || 50)),
        total: 0,
        totalPages: 0,
        hasMore: false,
      },
    };
  }

  const where = {
    visitorId: target.id,
    visited: { status: { not: 'DELETED' } },
    ...(blockedIds.length > 0 ? { visitedId: { notIn: blockedIds } } : {}),
  };

  const pageNum = Math.max(1, Number(page) || 1);
  const limitNum = Math.min(100, Math.max(1, Number(limit) || 50));
  const skip = (pageNum - 1) * limitNum;

  const [total, visits] = await Promise.all([
    db.profileVisit.count({ where }),
    db.profileVisit.findMany({
      where,
      orderBy: [{ visitedAt: 'desc' }, { visitedId: 'asc' }],
      skip,
      take: limitNum,
      include: {
        visited: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: {
              select: {
                displayName: true,
                level: true,
                svipLevel: true,
                nobleRank: true,
                followersCount: true,
                signature: true,
              },
            },
          },
        },
      },
    }),
  ]);

  const results = visits.map(visit => {
    const user = visit.visited;
    const publicId = /^[1-9]\d{6}$/.test(user.id) ? user.id : (user.username && /^\d+$/.test(user.username) ? user.username : user.id);
    const displayName = user.profile?.displayName || user.username;
    const userObj = {
      id: publicId,
      publicUserId: publicId,
      publicId,
      username: user.username,
      name: displayName,
      displayName,
      nickname: displayName,
      avatarUrl: user.avatarUrl || '',
      accountLevel: user.profile?.level || 1,
      vipLevel: user.profile?.svipLevel ? `SVIP ${user.profile.svipLevel}` : (user.profile?.nobleRank || 'None'),
      followers: user.profile?.followersCount || 0,
      profile: {
        userId: publicId,
        displayName,
        bio: user.profile?.signature || null,
        signature: user.profile?.signature || null,
        avatarUrl: user.avatarUrl || '',
      },
    };

    return {
      id: visit.id,
      visitedAt: visit.visitedAt,
      isMystery: visit.isMystery,
      user: userObj,
      ...userObj,
    };
  });

  return {
    data: results,
    visited: results,
    pagination: {
      page: pageNum,
      limit: limitNum,
      total,
      totalPages: Math.ceil(total / limitNum),
      hasMore: skip + results.length < total,
    },
  };
}

export default {
  resolveCanonicalUser,
  createLike,
  deleteLike,
  findLike,
  countLikes,
  isPostLikedByUser,
  createComment,
  findCommentById,
  findCommentsByPost,
  findCommentsByPostId,
  softDeleteComment,
  deleteComment,
  countComments,
  createFollow,
  deleteFollow,
  findFollow,
  findFollowingUserIds,
  findFollowers,
  findFollowing,
  incrementFollowersCount,
  decrementFollowersCount,
  incrementFollowingCount,
  decrementFollowingCount,
  incrementPostsCount,
  decrementPostsCount,
  createBlock,
  deleteBlock,
  isBlocked,
  findBlockedUserIds,
  createReport,
  updateUserPrivacy,
  findSocialProfile,
  recordProfileVisit,
  findProfileVisitors,
  findProfileVisited,
};
