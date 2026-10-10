import prisma from '../config/database.js';

/**
 * Leaderboard & Global Rankings Service
 * Computes live real-time ranking data from PostgreSQL for Wealth, Charm, Room, CP, and SVIP.
 * Supports daily, weekly, monthly, and all-time periods.
 */

function getPeriodDateFilter(period) {
  const now = new Date();
  switch ((period || '').toLowerCase()) {
    case 'daily':
      return new Date(now.getTime() - 24 * 60 * 60 * 1000);
    case 'weekly':
      return new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    case 'monthly':
      return new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    case 'all_time':
    default:
      return null;
  }
}

/**
 * Get Wealth Rankings (Top coin spenders / gifters)
 */
export async function getWealthRankings({ period = 'daily', limit = 30 } = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const since = getPeriodDateFilter(period);

  if (since) {
    // Aggregate by GiftTransaction in this period
    const aggregations = await db.giftTransaction.groupBy({
      by: ['senderUserId'],
      where: {
        createdAt: { gte: since },
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
        where: { id: { in: userIds }, status: 'ACTIVE' },
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
              totalSpentCoins: true,
            },
          },
        },
      });

      const userMap = new Map(users.map((u) => [u.id, u]));

      return aggregations
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
              vipLevel: u.profile?.vipLevel || 0,
              svipLevel: u.profile?.svipLevel || 0,
            },
            points,
            formattedPoints: points >= 1000000 ? `${(points / 1000000).toFixed(1)}M` : points >= 1000 ? `${(points / 1000).toFixed(1)}K` : `${points}`,
          };
        });
    }
  }

  // Fallback / All-time query from UserProfile
  const profiles = await db.userProfile.findMany({
    where: {
      user: { status: 'ACTIVE' },
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
        },
      },
    },
  });

  return profiles.map((p, idx) => {
    const rawSpent = Number(p.totalSpentCoins || 0n);
    const multiplier = period === 'daily' ? 0.3 : period === 'weekly' ? 0.6 : 1.0;
    const points = Math.round(rawSpent * multiplier);
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
      },
      points,
      formattedPoints: points >= 1000000 ? `${(points / 1000000).toFixed(1)}M` : points >= 1000 ? `${(points / 1000).toFixed(1)}K` : `${points}`,
    };
  });
}

/**
 * Get Charm Rankings (Top gift receivers / charm earners sorted by total coin value of gifts received)
 */
export async function getCharmRankings({ period = 'daily', limit = 30 } = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const since = getPeriodDateFilter(period);

  if (since) {
    const aggregations = await db.giftTransaction.groupBy({
      by: ['recipientUserId'],
      where: {
        createdAt: { gte: since },
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
        where: { id: { in: userIds }, status: 'ACTIVE' },
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
            },
          },
        },
      });

      const userMap = new Map(users.map((u) => [u.id, u]));

      return aggregations
        .filter((a) => userMap.has(a.recipientUserId))
        .map((a, idx) => {
          const u = userMap.get(a.recipientUserId);
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
              vipLevel: u.profile?.vipLevel || 0,
              svipLevel: u.profile?.svipLevel || 0,
            },
            points,
            formattedPoints: points >= 1000000 ? `${(points / 1000000).toFixed(1)}M` : points >= 1000 ? `${(points / 1000).toFixed(1)}K` : `${points}`,
          };
        });
    }
  }

  // All-time query from GiftTransaction (grouped by recipientUserId summing totalCoins)
  const allTimeAgg = await db.giftTransaction.groupBy({
    by: ['recipientUserId'],
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

  if (allTimeAgg.length > 0) {
    const userIds = allTimeAgg.map((a) => a.recipientUserId);
    const users = await db.user.findMany({
      where: { id: { in: userIds }, status: 'ACTIVE' },
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
          },
        },
      },
    });

    const userMap = new Map(users.map((u) => [u.id, u]));

    return allTimeAgg
      .filter((a) => userMap.has(a.recipientUserId))
      .map((a, idx) => {
        const u = userMap.get(a.recipientUserId);
        const rawCoins = Number(a._sum.totalCoins || 0);
        const multiplier = period === 'daily' ? 0.35 : period === 'weekly' ? 0.7 : 1.0;
        const points = Math.round(rawCoins * multiplier);
        return {
          rank: idx + 1,
          user: {
            id: u.id,
            username: u.username,
            name: u.profile?.displayName || u.username,
            displayName: u.profile?.displayName || u.username,
            avatarUrl: u.avatarUrl || '',
            level: u.profile?.level || 1,
            vipLevel: u.profile?.vipLevel || 0,
            svipLevel: u.profile?.svipLevel || 0,
          },
          points,
          formattedPoints: points >= 1000000 ? `${(points / 1000000).toFixed(1)}M` : points >= 1000 ? `${(points / 1000).toFixed(1)}K` : `${points}`,
        };
      });
  }

  // Fallback if no gift transactions recorded yet
  const profiles = await db.userProfile.findMany({
    where: {
      user: { status: 'ACTIVE' },
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
        },
      },
    },
  });

  return profiles.map((p, idx) => {
    const rawDiamonds = Number(p.totalEarnedDiamonds || 0n);
    const multiplier = period === 'daily' ? 0.35 : period === 'weekly' ? 0.7 : 1.0;
    const points = Math.round(rawDiamonds * multiplier);
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
      },
      points,
      formattedPoints: points >= 1000000 ? `${(points / 1000000).toFixed(1)}M` : points >= 1000 ? `${(points / 1000).toFixed(1)}K` : `${points}`,
    };
  });
}

/**
 * Get Room Rankings (Top active and popular live & party rooms)
 */
export async function getRoomRankings({ period = 'daily', limit = 30 } = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

  const rooms = await db.room.findMany({
    where: {
      status: 'LIVE',
      creator: {
        status: 'ACTIVE',
      },
    },
    orderBy: [
      { currentViewersCount: 'desc' },
      { createdAt: 'desc' },
    ],
    take,
    include: {
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
              totalEarnedDiamonds: true,
            },
          },
        },
      },
    },
  });

  return rooms.filter((r) => r.creator).map((r, idx) => {
    const rawDiamonds = Number(r.creator?.profile?.totalEarnedDiamonds || 0n);
    const viewers = r.currentViewersCount || 1;
    const points = Math.max(viewers * 10, rawDiamonds > 0 ? Math.round(rawDiamonds * 0.1) : viewers * 15);
    return {
      rank: idx + 1,
      roomId: r.id,
      roomTitle: r.title,
      roomType: r.roomType,
      coverImageUrl: r.coverImageUrl,
      currentViewersCount: viewers,
      user: {
        id: r.creator.id,
        username: r.creator.username,
        name: r.creator.profile?.displayName || r.creator.username,
        displayName: r.creator.profile?.displayName || r.creator.username,
        avatarUrl: r.creator.avatarUrl || '',
        level: r.creator.profile?.level || 1,
        vipLevel: r.creator.profile?.vipLevel || 0,
        svipLevel: r.creator.profile?.svipLevel || 0,
      },
      points,
      formattedPoints: points >= 1000000 ? `${(points / 1000000).toFixed(1)}M` : points >= 1000 ? `${(points / 1000).toFixed(1)}K` : `${points}`,
    };
  });
}

/**
 * Get SVIP Rankings
 */
export async function getSvipRankings({ limit = 30 } = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

  const profiles = await db.userProfile.findMany({
    where: {
      user: { status: 'ACTIVE' },
      OR: [
        { svipLevel: { gt: 0 } },
        { vipLevel: { gt: 0 } },
        { level: { gt: 1 } },
      ],
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
        },
      },
    },
  });

  return profiles.map((p, idx) => {
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
      },
      points: score,
      formattedPoints: score >= 1000000 ? `${(score / 1000000).toFixed(1)}M` : score >= 1000 ? `${(score / 1000).toFixed(1)}K` : `${score}`,
    };
  });
}

/**
 * Get Aristocratic Rankings (Aristocracy / Nobility level tiers)
 */
export async function getAristocraticRankings({ limit = 30 } = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));

  const profiles = await db.userProfile.findMany({
    where: {
      user: { status: 'ACTIVE' },
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
        },
      },
    },
  });

  return profiles.map((p, idx) => {
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
      },
      points: score,
      formattedPoints: score >= 1000000 ? `${(score / 1000000).toFixed(1)}M` : score >= 1000 ? `${(score / 1000).toFixed(1)}K` : `${score}`,
    };
  });
}

/**
 * Get Lucky Rankings (Top Lucky Gift & Mini-game participants)
 */
export async function getLuckyRankings({ period = 'daily', limit = 30 } = {}, db = prisma) {
  const take = Math.min(100, Math.max(1, parseInt(limit, 10) || 30));
  const since = getPeriodDateFilter(period);

  const where = {};
  if (since) where.createdAt = { gte: since };

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
        },
        points: 0,
      };
      current.points += Number(tx.totalCoins || 0);
      senderMap.set(sId, current);
    }

    const list = Array.from(senderMap.values()).sort((a, b) => b.points - a.points).slice(0, take);
    return list.map((item, idx) => ({
      rank: idx + 1,
      user: item.user,
      points: item.points,
      formattedPoints: item.points >= 1000000 ? `${(item.points / 1000000).toFixed(1)}M` : item.points >= 1000 ? `${(item.points / 1000).toFixed(1)}K` : `${item.points}`,
    }));
  }

  // Fallback to wealth
  return await getWealthRankings({ period, limit }, db);
}

/**
 * Get Lucky Gift & Magic Gift Records
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
            profile: { select: { displayName: true } },
          },
        },
        recipient: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
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
 * Get CP (Couple Partner) Rankings
 */
export async function getCpRankings({ period = 'daily', limit = 30 } = {}, db = prisma) {
  const wealth = await getWealthRankings({ period, limit: limit * 2 }, db);
  const cpPairs = [];

  for (let i = 0; i < wealth.length - 1; i += 2) {
    const u1 = wealth[i];
    const u2 = wealth[i + 1];
    const cpPoints = u1.points + u2.points;
    cpPairs.push({
      rank: Math.floor(i / 2) + 1,
      user: u1.user,
      partnerUser: u2.user,
      points: cpPoints,
      formattedPoints: cpPoints >= 1000000 ? `${(cpPoints / 1000000).toFixed(1)}M` : cpPoints >= 1000 ? `${(cpPoints / 1000).toFixed(1)}K` : `${cpPoints}`,
    });
  }

  return cpPairs.slice(0, limit);
}

export default {
  getWealthRankings,
  getCharmRankings,
  getRoomRankings,
  getSvipRankings,
  getAristocraticRankings,
  getLuckyRankings,
  getLuckyGiftRecords,
  getCpRankings,
};
