import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import privacyEligibilityService from './privacyEligibility.service.js';

/**
 * ZeParty Authoritative Leaderboard & Global Rankings Service (2026 Specification Alignment)
 * Computes live, real-time ranking data from PostgreSQL for Wealth, Charm, Room, CP, and SVIP.
 * Strictly adheres to UTC calendar period boundaries and geographic scope filtering.
 */

export const EXCLUDED_USERNAMES_FILTER = {
  status: 'ACTIVE',
  NOT: [
    { username: { startsWith: 'target_', mode: 'insensitive' } },
    { username: { startsWith: 'test_', mode: 'insensitive' } },
    { username: { contains: 'candidate', mode: 'insensitive' } },
    { username: { contains: 'tester', mode: 'insensitive' } },
    { username: { startsWith: 'admin_shadow', mode: 'insensitive' } },
    { username: { startsWith: 'dev-admin', mode: 'insensitive' } },
  ],
};

export function formatPoints(points) {
  const p = Number(points || 0);
  if (p >= 1000000) return `${(p / 1000000).toFixed(1)}M`;
  if (p >= 1000) return `${(p / 1000).toFixed(1)}K`;
  return `${p}`;
}

/**
 * Calendar-aligned UTC period boundaries
 */
export function getCalendarPeriodRange(period = 'daily') {
  const now = new Date();
  const end = new Date(now);
  const clean = (period || 'daily').toLowerCase().trim();

  if (clean === 'hourly') {
    const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), now.getUTCHours(), 0, 0, 0));
    return { start, end, period: 'hourly', timezone: 'UTC' };
  }

  if (clean === 'daily') {
    const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
    return { start, end, period: 'daily', timezone: 'UTC' };
  }

  if (clean === 'weekly') {
    const day = now.getUTCDay(); // 0 is Sunday, 1 is Monday
    const diffToMonday = (day + 6) % 7;
    const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - diffToMonday, 0, 0, 0, 0));
    return { start, end, period: 'weekly', timezone: 'UTC' };
  }

  if (clean === 'monthly') {
    const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1, 0, 0, 0, 0));
    return { start, end, period: 'monthly', timezone: 'UTC' };
  }

  // all_time / alltime
  return { start: null, end, period: 'all_time', timezone: 'UTC' };
}

export async function sanitizeRankingUser(userObj, viewerUserId = null, db = prisma) {
  if (!userObj || !userObj.id) return userObj;
  if (viewerUserId && (viewerUserId === userObj.id || viewerUserId === userObj.username)) {
    return userObj;
  }

  try {
    const prefs = await privacyEligibilityService.getUserPreferences(userObj.id, db);
    if (prefs.RANK_INVISIBLE) {
      const eligibility = await privacyEligibilityService.checkUserEligibility(userObj.id, 'RANK_INVISIBLE', db);
      if (eligibility.isEligible) {
        return {
          ...userObj,
          username: 'Mystery User',
          name: 'Mystery User',
          displayName: 'Mystery User',
          avatarUrl: '',
          svipLevel: 0,
          isMystery: true,
        };
      }
    }
  } catch (_) {}

  return userObj;
}

export async function sanitizeRankingsList(rankings, viewerUserId = null, db = prisma) {
  if (!Array.isArray(rankings)) return rankings;
  return await Promise.all(
    rankings.map(async (item) => {
      if (item.user && item.partnerUser) {
        return {
          ...item,
          user: await sanitizeRankingUser(item.user, viewerUserId, db),
          partnerUser: await sanitizeRankingUser(item.partnerUser, viewerUserId, db),
        };
      }
      if (item.user) {
        return {
          ...item,
          user: await sanitizeRankingUser(item.user, viewerUserId, db),
        };
      }
      if (item.id) {
        return await sanitizeRankingUser(item, viewerUserId, db);
      }
      return item;
    })
  );
}

/**
 * 1. Wealth Rankings (Top coin gifters / spenders)
 */
export async function getWealthRankings({
  period = 'daily',
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const { start, end } = getCalendarPeriodRange(period);

  const effectiveCountry = (scope?.toUpperCase() === 'COUNTRY' ? scopeValue : countryCode) || null;
  const effectiveRegion = (scope?.toUpperCase() === 'REGION' ? scopeValue : region) || null;

  const userWhere = {
    ...EXCLUDED_USERNAMES_FILTER,
  };
  if (effectiveCountry) {
    userWhere.countryCode = { equals: effectiveCountry.toUpperCase(), mode: 'insensitive' };
  }
  if (effectiveRegion) {
    userWhere.region = { equals: effectiveRegion.toUpperCase(), mode: 'insensitive' };
  }

  if (start) {
    const aggregations = await db.giftTransaction.groupBy({
      by: ['senderUserId'],
      where: {
        createdAt: { gte: start, lte: end },
        sender: userWhere,
      },
      _sum: {
        totalCoins: true,
      },
      orderBy: {
        _sum: {
          totalCoins: 'desc',
        },
      },
      take,
    });

    if (aggregations.length > 0) {
      const userIds = aggregations.map((a) => a.senderUserId);
      const users = await db.user.findMany({
        where: { id: { in: userIds } },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
          profile: {
            select: {
              displayName: true,
              level: true,
              vipLevel: true,
              svipLevel: true,
              totalSpentCoins: true,
            },
          },
        },
      });

      const userMap = new Map(users.map((u) => [u.id, u]));

      const results = aggregations
        .filter((a) => userMap.has(a.senderUserId))
        .map((a, idx) => {
          const u = userMap.get(a.senderUserId);
          const points = Number(a._sum.totalCoins || 0);
          return {
            rank: idx + 1,
            user: {
              id: u.id,
              username: u.username,
              name: u.profile?.displayName || u.username,
              displayName: u.profile?.displayName || u.username,
              avatarUrl: u.avatarUrl || '',
              level: u.profile?.level || 1,
              wealthLevel: u.profile?.level || 1,
              vipLevel: u.profile?.vipLevel || 0,
              svipLevel: u.profile?.svipLevel || 0,
              countryCode: u.countryCode || 'GLOBAL',
              region: u.region || null,
            },
            points,
            formattedPoints: formatPoints(points),
          };
        });

      return await sanitizeRankingsList(results, viewerUserId, db);
    }
  }

  // Fallback to all-time verified spenders without synthetic multipliers
  const profiles = await db.userProfile.findMany({
    where: {
      user: userWhere,
      totalSpentCoins: { gt: 0 },
    },
    orderBy: [
      { totalSpentCoins: 'desc' },
      { level: 'desc' },
    ],
    take,
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
        },
      },
    },
  });

  const results = profiles.map((p, idx) => {
    const rawSpent = Number(p.totalSpentCoins || 0n);
    return {
      rank: idx + 1,
      user: {
        id: p.user.id,
        username: p.user.username,
        name: p.displayName || p.user.username,
        displayName: p.displayName || p.user.username,
        avatarUrl: p.user.avatarUrl || '',
        level: p.level || 1,
        wealthLevel: p.level || 1,
        vipLevel: p.vipLevel || 0,
        svipLevel: p.svipLevel || 0,
        countryCode: p.user.countryCode || 'GLOBAL',
        region: p.user.region || null,
      },
      points: rawSpent,
      formattedPoints: formatPoints(rawSpent),
    };
  });

  return await sanitizeRankingsList(results, viewerUserId, db);
}

/**
 * 2. Charm Rankings (Top gift receivers / charm earners)
 */
export async function getCharmRankings({
  period = 'daily',
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const { start, end } = getCalendarPeriodRange(period);

  const effectiveCountry = (scope?.toUpperCase() === 'COUNTRY' ? scopeValue : countryCode) || null;
  const effectiveRegion = (scope?.toUpperCase() === 'REGION' ? scopeValue : region) || null;

  const userWhere = {
    ...EXCLUDED_USERNAMES_FILTER,
  };
  if (effectiveCountry) {
    userWhere.countryCode = { equals: effectiveCountry.toUpperCase(), mode: 'insensitive' };
  }
  if (effectiveRegion) {
    userWhere.region = { equals: effectiveRegion.toUpperCase(), mode: 'insensitive' };
  }

  if (start) {
    const aggregations = await db.giftTransaction.groupBy({
      by: ['recipientUserId'],
      where: {
        createdAt: { gte: start, lte: end },
        recipient: userWhere,
      },
      _sum: {
        totalCoins: true,
      },
      orderBy: {
        _sum: {
          totalCoins: 'desc',
        },
      },
      take,
    });

    if (aggregations.length > 0) {
      const userIds = aggregations.map((a) => a.recipientUserId);
      const users = await db.user.findMany({
        where: { id: { in: userIds } },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
          profile: {
            select: {
              displayName: true,
              level: true,
              vipLevel: true,
              svipLevel: true,
              totalEarnedDiamonds: true,
            },
          },
        },
      });

      const userMap = new Map(users.map((u) => [u.id, u]));

      const results = aggregations
        .filter((a) => userMap.has(a.recipientUserId))
        .map((a, idx) => {
          const u = userMap.get(a.recipientUserId);
          const points = Number(a._sum.totalCoins || 0);
          const charmLevel = Math.max(1, Math.floor(Number(u.profile?.totalEarnedDiamonds || 0n) / 10000) + 1);
          return {
            rank: idx + 1,
            user: {
              id: u.id,
              username: u.username,
              name: u.profile?.displayName || u.username,
              displayName: u.profile?.displayName || u.username,
              avatarUrl: u.avatarUrl || '',
              level: charmLevel,
              charmLevel,
              vipLevel: u.profile?.vipLevel || 0,
              svipLevel: u.profile?.svipLevel || 0,
              countryCode: u.countryCode || 'GLOBAL',
              region: u.region || null,
            },
            points,
            formattedPoints: formatPoints(points),
          };
        });

      return await sanitizeRankingsList(results, viewerUserId, db);
    }
  }

  // Fallback to all-time verified diamonds received without synthetic multipliers
  const profiles = await db.userProfile.findMany({
    where: {
      user: userWhere,
      totalEarnedDiamonds: { gt: 0 },
    },
    orderBy: [
      { totalEarnedDiamonds: 'desc' },
      { level: 'desc' },
    ],
    take,
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
        },
      },
    },
  });

  const results = profiles.map((p, idx) => {
    const rawDiamonds = Number(p.totalEarnedDiamonds || 0n);
    const charmLevel = Math.max(1, Math.floor(rawDiamonds / 10000) + 1);
    return {
      rank: idx + 1,
      user: {
        id: p.user.id,
        username: p.user.username,
        name: p.displayName || p.user.username,
        displayName: p.displayName || p.user.username,
        avatarUrl: p.user.avatarUrl || '',
        level: charmLevel,
        charmLevel,
        vipLevel: p.vipLevel || 0,
        svipLevel: p.svipLevel || 0,
        countryCode: p.user.countryCode || 'GLOBAL',
        region: p.user.region || null,
      },
      points: rawDiamonds,
      formattedPoints: formatPoints(rawDiamonds),
    };
  });

  return await sanitizeRankingsList(results, viewerUserId, db);
}

/**
 * 3. Room Rankings (Active & gift-producing rooms)
 */
export async function getRoomRankings({
  period = 'daily',
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const { start, end } = getCalendarPeriodRange(period);

  const effectiveCountry = (scope?.toUpperCase() === 'COUNTRY' ? scopeValue : countryCode) || null;
  const effectiveRegion = (scope?.toUpperCase() === 'REGION' ? scopeValue : region) || null;

  const creatorWhere = {
    ...EXCLUDED_USERNAMES_FILTER,
  };
  if (effectiveCountry) {
    creatorWhere.countryCode = { equals: effectiveCountry.toUpperCase(), mode: 'insensitive' };
  }
  if (effectiveRegion) {
    creatorWhere.region = { equals: effectiveRegion.toUpperCase(), mode: 'insensitive' };
  }

  // Aggregate gifts inside rooms during period
  let roomGiftAgg = [];
  if (start) {
    roomGiftAgg = await db.giftTransaction.groupBy({
      by: ['roomId'],
      where: {
        createdAt: { gte: start, lte: end },
        roomId: { not: null },
      },
      _sum: { totalCoins: true },
      orderBy: { _sum: { totalCoins: 'desc' } },
      take: take * 2,
    });
  }

  const giftScoreByRoomId = new Map(
    roomGiftAgg.filter((a) => a.roomId).map((a) => [a.roomId, Number(a._sum.totalCoins || 0)])
  );

  // Active / LIVE rooms
  const activeRooms = await db.room.findMany({
    where: {
      status: 'LIVE',
      creator: creatorWhere,
    },
    orderBy: [
      { currentViewersCount: 'desc' },
      { createdAt: 'desc' },
    ],
    take: take * 2,
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
          profile: {
            select: {
              displayName: true,
              level: true,
              vipLevel: true,
              svipLevel: true,
              totalEarnedDiamonds: true,
            },
          },
        },
      },
    },
  });

  const roomScores = activeRooms.map((r) => {
    const giftScore = giftScoreByRoomId.get(r.id) || 0;
    const viewers = r.currentViewersCount || 1;
    const totalScore = giftScore > 0 ? giftScore : viewers * 15;
    return {
      room: r,
      points: totalScore,
      viewers,
    };
  });

  // If live rooms are fewer than limit, include past rooms that had gift activity in the period
  if (roomScores.length < take && roomGiftAgg.length > 0) {
    const existingRoomIds = new Set(roomScores.map((s) => s.room.id));
    const missingRoomIds = roomGiftAgg.filter((a) => a.roomId && !existingRoomIds.has(a.roomId)).map((a) => a.roomId);
    if (missingRoomIds.length > 0) {
      const extraRooms = await db.room.findMany({
        where: {
          id: { in: missingRoomIds },
          creator: creatorWhere,
        },
        include: {
          creator: {
            select: {
              id: true,
              username: true,
              avatarUrl: true,
              countryCode: true,
              region: true,
              profile: {
                select: {
                  displayName: true,
                  level: true,
                  vipLevel: true,
                  svipLevel: true,
                  totalEarnedDiamonds: true,
                },
              },
            },
          },
        },
      });

      for (const er of extraRooms) {
        const giftScore = giftScoreByRoomId.get(er.id) || 0;
        roomScores.push({
          room: er,
          points: giftScore,
          viewers: er.currentViewersCount || 0,
        });
      }
    }
  }

  roomScores.sort((a, b) => b.points - a.points);

  const results = roomScores.slice(0, take).map((item, idx) => {
    const r = item.room;
    const creator = r.creator;
    return {
      rank: idx + 1,
      roomId: r.id,
      roomTitle: r.title,
      roomType: r.roomType,
      coverImageUrl: r.coverImageUrl || '',
      currentViewersCount: item.viewers,
      points: item.points,
      formattedPoints: formatPoints(item.points),
      user: {
        id: creator.id,
        username: creator.username,
        name: creator.profile?.displayName || creator.username,
        displayName: creator.profile?.displayName || creator.username,
        avatarUrl: creator.avatarUrl || '',
        level: creator.profile?.level || 1,
        vipLevel: creator.profile?.vipLevel || 0,
        svipLevel: creator.profile?.svipLevel || 0,
        countryCode: creator.countryCode || 'GLOBAL',
        region: creator.region || null,
      },
      creator: {
        id: creator.id,
        username: creator.username,
        name: creator.profile?.displayName || creator.username,
        displayName: creator.profile?.displayName || creator.username,
        avatarUrl: creator.avatarUrl || '',
      },
    };
  });

  return await sanitizeRankingsList(results, viewerUserId, db);
}

/**
 * 4. CP (Couple Partner) Intimacy Rankings
 * Aggregates mutual gifts between pairs within the calendar period.
 */
export async function getCpRankings({
  period = 'daily',
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const { start, end } = getCalendarPeriodRange(period);

  const effectiveCountry = (scope?.toUpperCase() === 'COUNTRY' ? scopeValue : countryCode) || null;
  const effectiveRegion = (scope?.toUpperCase() === 'REGION' ? scopeValue : region) || null;

  const userWhere = {
    ...EXCLUDED_USERNAMES_FILTER,
  };
  if (effectiveCountry) {
    userWhere.countryCode = { equals: effectiveCountry.toUpperCase(), mode: 'insensitive' };
  }
  if (effectiveRegion) {
    userWhere.region = { equals: effectiveRegion.toUpperCase(), mode: 'insensitive' };
  }

  const txWhere = {
    sender: userWhere,
    recipient: userWhere,
  };
  if (start) {
    txWhere.createdAt = { gte: start, lte: end };
  }

  const recentGifts = await db.giftTransaction.findMany({
    where: txWhere,
    select: {
      senderUserId: true,
      recipientUserId: true,
      totalCoins: true,
    },
    take: 2000,
  });

  const pairScores = new Map();
  for (const g of recentGifts) {
    if (!g.senderUserId || !g.recipientUserId || g.senderUserId === g.recipientUserId) continue;
    const u1 = g.senderUserId < g.recipientUserId ? g.senderUserId : g.recipientUserId;
    const u2 = g.senderUserId < g.recipientUserId ? g.recipientUserId : g.senderUserId;
    const key = `${u1}:${u2}`;
    const prev = pairScores.get(key) || { u1, u2, points: 0 };
    prev.points += Number(g.totalCoins || 0);
    pairScores.set(key, prev);
  }

  const sortedPairs = Array.from(pairScores.values())
    .sort((a, b) => b.points - a.points)
    .slice(0, take);

  if (sortedPairs.length > 0) {
    const allUserIds = Array.from(new Set(sortedPairs.flatMap((p) => [p.u1, p.u2])));
    const users = await db.user.findMany({
      where: { id: { in: allUserIds } },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        countryCode: true,
        region: true,
        profile: {
          select: {
            displayName: true,
            level: true,
            vipLevel: true,
            svipLevel: true,
          },
        },
      },
    });

    const userMap = new Map(users.map((u) => [u.id, u]));

    const results = sortedPairs
      .filter((p) => userMap.has(p.u1) && userMap.has(p.u2))
      .map((p, idx) => {
        const user1 = userMap.get(p.u1);
        const user2 = userMap.get(p.u2);
        return {
          rank: idx + 1,
          points: p.points,
          formattedPoints: formatPoints(p.points),
          user: {
            id: user1.id,
            username: user1.username,
            name: user1.profile?.displayName || user1.username,
            displayName: user1.profile?.displayName || user1.username,
            avatarUrl: user1.avatarUrl || '',
            level: user1.profile?.level || 1,
            vipLevel: user1.profile?.vipLevel || 0,
            svipLevel: user1.profile?.svipLevel || 0,
            countryCode: user1.countryCode || 'GLOBAL',
          },
          partnerUser: {
            id: user2.id,
            username: user2.username,
            name: user2.profile?.displayName || user2.username,
            displayName: user2.profile?.displayName || user2.username,
            avatarUrl: user2.avatarUrl || '',
            level: user2.profile?.level || 1,
            vipLevel: user2.profile?.vipLevel || 0,
            svipLevel: user2.profile?.svipLevel || 0,
            countryCode: user2.countryCode || 'GLOBAL',
          },
          relationshipType: 'CP_LOVE',
          relationshipBadge: '💍 Eternal Love',
        };
      });

    return await sanitizeRankingsList(results, viewerUserId, db);
  }

  return [];
}

/**
 * 5. SVIP Rankings
 * High-tier spenders and subscribers
 */
export async function getSvipRankings({
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

  const effectiveCountry = (scope?.toUpperCase() === 'COUNTRY' ? scopeValue : countryCode) || null;
  const effectiveRegion = (scope?.toUpperCase() === 'REGION' ? scopeValue : region) || null;

  const userWhere = {
    ...EXCLUDED_USERNAMES_FILTER,
  };
  if (effectiveCountry) {
    userWhere.countryCode = { equals: effectiveCountry.toUpperCase(), mode: 'insensitive' };
  }
  if (effectiveRegion) {
    userWhere.region = { equals: effectiveRegion.toUpperCase(), mode: 'insensitive' };
  }

  const profiles = await db.userProfile.findMany({
    where: {
      user: userWhere,
      OR: [
        { svipLevel: { gt: 0 } },
        { vipLevel: { gt: 0 } },
      ],
    },
    orderBy: [
      { svipLevel: 'desc' },
      { vipLevel: 'desc' },
      { totalSpentCoins: 'desc' },
      { level: 'desc' },
    ],
    take,
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
        },
      },
    },
  });

  const results = profiles.map((p, idx) => {
    const rawSpent = Number(p.totalSpentCoins || 0n);
    const score = p.svipLevel * 100000 + p.vipLevel * 10000 + rawSpent;
    return {
      rank: idx + 1,
      user: {
        id: p.user.id,
        username: p.user.username,
        name: p.displayName || p.user.username,
        displayName: p.displayName || p.user.username,
        avatarUrl: p.user.avatarUrl || '',
        level: p.level || 1,
        vipLevel: p.vipLevel || 0,
        svipLevel: p.svipLevel || 0,
        countryCode: p.user.countryCode || 'GLOBAL',
        region: p.user.region || null,
      },
      svipLevel: p.svipLevel || 0,
      points: score,
      formattedPoints: formatPoints(score),
    };
  });

  return await sanitizeRankingsList(results, viewerUserId, db);
}

/**
 * 6. Aristocratic Rankings (Nobility tiers)
 */
export async function getAristocraticRankings({
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

  const effectiveCountry = (scope?.toUpperCase() === 'COUNTRY' ? scopeValue : countryCode) || null;
  const effectiveRegion = (scope?.toUpperCase() === 'REGION' ? scopeValue : region) || null;

  const userWhere = {
    ...EXCLUDED_USERNAMES_FILTER,
  };
  if (effectiveCountry) {
    userWhere.countryCode = { equals: effectiveCountry.toUpperCase(), mode: 'insensitive' };
  }
  if (effectiveRegion) {
    userWhere.region = { equals: effectiveRegion.toUpperCase(), mode: 'insensitive' };
  }

  const profiles = await db.userProfile.findMany({
    where: {
      user: userWhere,
    },
    orderBy: [
      { svipLevel: 'desc' },
      { vipLevel: 'desc' },
      { level: 'desc' },
      { totalSpentCoins: 'desc' },
    ],
    take,
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          countryCode: true,
          region: true,
        },
      },
    },
  });

  const results = profiles.map((p, idx) => {
    const rawSpent = Number(p.totalSpentCoins || 0n);
    const nobleLevel = Math.max(1, Math.min(7, Math.floor((p.svipLevel * 2 + p.vipLevel) / 2) || 1));
    const score = p.svipLevel * 150000 + p.vipLevel * 25000 + rawSpent;
    return {
      rank: idx + 1,
      nobleLevel,
      nobleTitle: nobleLevel >= 7 ? 'Emperor' : nobleLevel >= 6 ? 'King' : nobleLevel >= 5 ? 'Duke' : nobleLevel >= 4 ? 'Marquis' : nobleLevel >= 3 ? 'Count' : nobleLevel >= 2 ? 'Viscount' : 'Baron',
      user: {
        id: p.user.id,
        username: p.user.username,
        name: p.displayName || p.user.username,
        displayName: p.displayName || p.user.username,
        avatarUrl: p.user.avatarUrl || '',
        level: p.level || 1,
        vipLevel: p.vipLevel || 0,
        svipLevel: p.svipLevel || 0,
        countryCode: p.user.countryCode || 'GLOBAL',
        region: p.user.region || null,
      },
      points: score,
      formattedPoints: formatPoints(score),
    };
  });

  return await sanitizeRankingsList(results, viewerUserId, db);
}

/**
 * 7. Lucky Rankings
 */
export async function getLuckyRankings({
  period = 'daily',
  limit = 30,
  viewerUserId = null,
} = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const { start, end } = getCalendarPeriodRange(period);

  const where = {
    sender: EXCLUDED_USERNAMES_FILTER,
  };
  if (start) where.createdAt = { gte: start, lte: end };

  const luckyTxs = await db.giftTransaction.findMany({
    where,
    take: take * 2,
    orderBy: { createdAt: 'desc' },
    include: {
      sender: {
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

  if (luckyTxs.length > 0) {
    const senderMap = new Map();
    for (const tx of luckyTxs) {
      if (!tx.sender) continue;
      const sId = tx.sender.id;
      const current = senderMap.get(sId) || {
        user: {
          id: tx.sender.id,
          username: tx.sender.username,
          name: tx.sender.profile?.displayName || tx.sender.username,
          displayName: tx.sender.profile?.displayName || tx.sender.username,
          avatarUrl: tx.sender.avatarUrl || '',
          level: tx.sender.profile?.level || 1,
          vipLevel: tx.sender.profile?.vipLevel || 0,
          svipLevel: tx.sender.profile?.svipLevel || 0,
          countryCode: tx.sender.countryCode || 'GLOBAL',
          region: tx.sender.region || null,
        },
        points: 0,
      };
      current.points += Number(tx.totalCoins || 0);
      senderMap.set(sId, current);
    }

    const list = Array.from(senderMap.values()).sort((a, b) => b.points - a.points).slice(0, take);
    const results = list.map((item, idx) => ({
      rank: idx + 1,
      user: item.user,
      points: item.points,
      formattedPoints: formatPoints(item.points),
    }));
    return await sanitizeRankingsList(results, viewerUserId, db);
  }

  return await getWealthRankings({ period, limit, viewerUserId }, db);
}

/**
 * 8. Lucky Gift & Magic Gift Records
 */
export async function getLuckyGiftRecords({ type = 'lucky', page = 1, limit = 20 } = {}, db = prisma) {
  const p = Math.max(1, parseInt(page, 10) || 1);
  const l = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (p - 1) * l;

  const [records, totalCount] = await Promise.all([
    db.giftTransaction.findMany({
      skip,
      take: l,
      orderBy: { createdAt: 'desc' },
      include: {
        gift: {
          select: {
            id: true,
            name: true,
            iconUrl: true,
            svgaAssetUrl: true,
            coinValue: true,
            giftCategory: true,
          },
        },
        sender: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            countryCode: true,
            profile: { select: { displayName: true } },
          },
        },
        recipient: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            countryCode: true,
            profile: { select: { displayName: true } },
          },
        },
        room: {
          select: {
            id: true,
            title: true,
            roomType: true,
          },
        },
      },
    }),
    db.giftTransaction.count(),
  ]);

  const formattedRecords = records.map((r) => ({
    id: r.id,
    recordType: type === 'magic' ? 'MAGIC_GIFT' : 'LUCKY_GIFT',
    sender: {
      id: r.sender.id,
      username: r.sender.username,
      name: r.sender.profile?.displayName || r.sender.username,
      avatarUrl: r.sender.avatarUrl || '',
    },
    recipient: {
      id: r.recipient.id,
      username: r.recipient.username,
      name: r.recipient.profile?.displayName || r.recipient.username,
      avatarUrl: r.recipient.avatarUrl || '',
    },
    room: r.room ? {
      id: r.room.id,
      title: r.room.title,
      roomType: r.room.roomType,
    } : null,
    gift: {
      id: r.gift.id,
      name: r.gift.name,
      iconUrl: r.gift.iconUrl,
      animationUrl: r.gift.svgaAssetUrl || '',
      category: r.gift.giftCategory,
    },
    quantity: r.giftCount,
    coinValue: Number(r.totalCoins),
    timestamp: r.createdAt.toISOString(),
  }));

  return {
    records: formattedRecords,
    pagination: {
      page: p,
      limit: l,
      totalCount,
      totalPages: Math.ceil(totalCount / l) || 1,
    },
  };
}

/**
 * Unified Authoritative Rankings Engine with caching and standardized envelope
 */
export async function getUnifiedRankings({
  category = 'wealth',
  period = 'daily',
  scope = 'GLOBAL',
  scopeValue = null,
  countryCode = null,
  region = null,
  limit = 30,
  search = null,
  viewerUserId = null,
} = {}, db = prisma) {
  const normCategory = (category || 'wealth').toLowerCase().trim();
  const normPeriod = (period || 'daily').toLowerCase().trim();
  const normScope = (scope || 'GLOBAL').toUpperCase().trim();
  const normScopeVal = (normScope === 'COUNTRY' ? (scopeValue || countryCode) : normScope === 'REGION' ? (scopeValue || region) : null) || null;
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

  const { start, end, timezone } = getCalendarPeriodRange(normPeriod);

  // Redis cache check (60s TTL)
  const cacheKey = `leaderboard:${normCategory}:${normPeriod}:${normScope}:${normScopeVal || 'ALL'}:${take}`;
  try {
    if (redisClient?.isOpen || redisClient?.isReady) {
      const cached = await redisClient.get(cacheKey);
      if (cached) {
        const parsed = JSON.parse(cached);
        if (search && search.trim().length > 0) {
          const q = search.trim().toLowerCase();
          const filtered = (parsed.data || []).filter((item) => {
            const u = item.user;
            const r = item.roomTitle;
            return (
              (u && (u.username?.toLowerCase().includes(q) || u.displayName?.toLowerCase().includes(q) || u.id?.toLowerCase().includes(q))) ||
              (r && r.toLowerCase().includes(q))
            );
          });
          return { ...parsed, data: filtered, totalCount: filtered.length };
        }
        return parsed;
      }
    }
  } catch (_) {}

  let data = [];
  switch (normCategory) {
    case 'room':
      data = await getRoomRankings({ period: normPeriod, scope: normScope, scopeValue: normScopeVal, countryCode, region, limit: take, viewerUserId }, db);
      break;
    case 'charm':
      data = await getCharmRankings({ period: normPeriod, scope: normScope, scopeValue: normScopeVal, countryCode, region, limit: take, viewerUserId }, db);
      break;
    case 'cp':
    case 'couple':
      data = await getCpRankings({ period: normPeriod, scope: normScope, scopeValue: normScopeVal, countryCode, region, limit: take, viewerUserId }, db);
      break;
    case 'svip':
    case 'vip':
      data = await getSvipRankings({ scope: normScope, scopeValue: normScopeVal, countryCode, region, limit: take, viewerUserId }, db);
      break;
    case 'aristocratic':
    case 'aristocracy':
    case 'noble':
      data = await getAristocraticRankings({ scope: normScope, scopeValue: normScopeVal, countryCode, region, limit: take, viewerUserId }, db);
      break;
    case 'lucky':
      data = await getLuckyRankings({ period: normPeriod, limit: take, viewerUserId }, db);
      break;
    case 'wealth':
    default:
      data = await getWealthRankings({ period: normPeriod, scope: normScope, scopeValue: normScopeVal, countryCode, region, limit: take, viewerUserId }, db);
      break;
  }

  const nowIso = new Date().toISOString();
  const envelope = {
    success: true,
    message: 'Leaderboard rankings retrieved successfully',
    category: normCategory,
    period: normPeriod,
    scope: normScope,
    scopeValue: normScopeVal,
    periodStart: start ? start.toISOString() : null,
    periodEnd: end.toISOString(),
    timezone,
    snapshotTime: nowIso,
    lastUpdatedAt: nowIso,
    totalCount: data.length,
    data,
  };

  // Cache in Redis for 60s
  try {
    if (redisClient?.isOpen || redisClient?.isReady) {
      await redisClient.set(cacheKey, JSON.stringify(envelope), { EX: 60 });
    }
  } catch (_) {}

  if (search && search.trim().length > 0) {
    const q = search.trim().toLowerCase();
    const filtered = data.filter((item) => {
      const u = item.user;
      const r = item.roomTitle;
      return (
        (u && (u.username?.toLowerCase().includes(q) || u.displayName?.toLowerCase().includes(q) || u.id?.toLowerCase().includes(q))) ||
        (r && r.toLowerCase().includes(q))
      );
    });
    return { ...envelope, data: filtered, totalCount: filtered.length };
  }

  return envelope;
}

export default {
  sanitizeRankingUser,
  sanitizeRankingsList,
  getCalendarPeriodRange,
  formatPoints,
  getWealthRankings,
  getCharmRankings,
  getRoomRankings,
  getSvipRankings,
  getAristocraticRankings,
  getLuckyRankings,
  getLuckyGiftRecords,
  getCpRankings,
  getUnifiedRankings,
};
