import prisma from '../config/database.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    let validAdminId = adminId;
    if (validAdminId && validAdminId !== 'SYSTEM' && validAdminId !== 'ADMIN') {
      const exists = await db.admin?.findUnique?.({ where: { id: validAdminId }, select: { id: true } });
      if (!exists) {
        const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
        validAdminId = fallback ? fallback.id : null;
        if (fallback && !adminName) adminName = fallback.name;
      }
    } else {
      const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
      validAdminId = fallback ? fallback.id : null;
      if (fallback && !adminName) adminName = fallback.name;
    }

    if (!validAdminId || !db.auditLog?.create) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System Administrator',
        action,
        targetEntity: targetEntity || 'RankingRewardEvent',
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in rankingReward.service:', err.message);
  }
}

// In-Memory / Database-Backed Storage for Ranking Reward Events
let rankingEventsCache = [
  {
    id: 'rw_evt_weekly_agency_pk',
    name: 'Weekly Top Agency — Pakistan',
    eventType: 'WEEKLY_TOP_AGENCY',
    rankingSubject: 'AGENCY',
    metric: 'DIAMONDS_AND_RECHARGE',
    scope: 'COUNTRY_WISE',
    countries: ['PK'],
    recurrence: 'WEEKLY',
    startsAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
    endsAt: new Date(Date.now() + 4 * 24 * 60 * 60 * 1000).toISOString(),
    distributionMode: 'AUTOMATIC',
    tieRule: 'EARLIEST_SCORE',
    status: 'LIVE',
    rewards: {
      top1: { rank: 1, rewardType: 'USD_VALUE', amount: 500, title: 'Champion Agency Trophy + $500' },
      top2: { rank: 2, rewardType: 'USD_VALUE', amount: 300, title: 'Runner-Up Agency Trophy + $300' },
      top3: { rank: 3, rewardType: 'USD_VALUE', amount: 150, title: '3rd Place Agency Trophy + $150' },
      customRanks: [
        { rank: 4, rewardType: 'COINS', amount: 1000000, title: '1,000,000 Gold Coins' },
        { rank: 5, rewardType: 'COINS', amount: 500000, title: '500,000 Gold Coins' }
      ]
    },
    leaderboardSnapshot: [
      { rank: 1, subjectId: 'agency_701', name: 'Falcon Stars Agency', score: 14500000, validated: true },
      { rank: 2, subjectId: 'agency_702', name: 'Royal Voice Club', score: 9800000, validated: true },
      { rank: 3, subjectId: 'agency_703', name: 'Apex Talents', score: 6200000, validated: true }
    ],
    distributedRewards: [],
    createdAt: new Date().toISOString(),
  },
  {
    id: 'rw_evt_weekly_game_global',
    name: 'Weekly Top Game Masters — Global',
    eventType: 'WEEKLY_TOP_GAME',
    rankingSubject: 'USER',
    metric: 'VALID_BET_VOLUME',
    scope: 'GLOBAL',
    countries: [],
    recurrence: 'WEEKLY',
    startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    endsAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString(),
    distributionMode: 'MANUAL_APPROVAL',
    tieRule: 'EARLIEST_SCORE',
    status: 'LIVE',
    rewards: {
      top1: { rank: 1, rewardType: 'COINS', amount: 5000000, title: 'Game Emperor Badge + 5M Coins' },
      top2: { rank: 2, rewardType: 'COINS', amount: 2500000, title: 'Game Master Badge + 2.5M Coins' },
      top3: { rank: 3, rewardType: 'COINS', amount: 1000000, title: 'Game Elite Badge + 1M Coins' }
    },
    leaderboardSnapshot: [
      { rank: 1, subjectId: 'user_1001', name: 'LuckyStrike', score: 28000000, validated: true },
      { rank: 2, subjectId: 'user_1002', name: 'RocketPilot', score: 19500000, validated: true },
      { rank: 3, subjectId: 'user_1003', name: 'DiceRoller', score: 12200000, validated: true }
    ],
    distributedRewards: [],
    createdAt: new Date().toISOString(),
  }
];

export async function listRankingEventsForAdmin(filters = {}) {
  let list = [...rankingEventsCache];
  if (filters.status) {
    list = list.filter((e) => e.status.toUpperCase() === filters.status.toUpperCase());
  }
  if (filters.eventType) {
    list = list.filter((e) => e.eventType.toUpperCase() === filters.eventType.toUpperCase());
  }
  if (filters.country) {
    const c = filters.country.toUpperCase();
    list = list.filter((e) => e.scope === 'GLOBAL' || (Array.isArray(e.countries) && e.countries.includes(c)));
  }
  if (filters.search) {
    const q = filters.search.toLowerCase();
    list = list.filter((e) => e.name.toLowerCase().includes(q));
  }

  return {
    totalCount: list.length,
    events: list,
  };
}

export async function getRankingEventById(id) {
  const event = rankingEventsCache.find((e) => e.id === id);
  if (!event) {
    const error = new Error('Ranking reward event not found');
    error.statusCode = 404;
    throw error;
  }
  return event;
}

export async function createRankingEvent(data, { adminId, adminName, ipAddress } = {}) {
  if (!data.name || !data.name.trim()) {
    const error = new Error('Event name is required');
    error.statusCode = 400;
    throw error;
  }

  const now = new Date();
  const startsAt = data.startsAt ? new Date(data.startsAt).toISOString() : now.toISOString();
  const endsAt = data.endsAt ? new Date(data.endsAt).toISOString() : new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();

  let countryList = [];
  if (Array.isArray(data.countries)) {
    countryList = data.countries.map((c) => String(c).toUpperCase());
  } else if (typeof data.countries === 'string' && data.countries.trim()) {
    countryList = data.countries.split(',').map((c) => c.trim().toUpperCase());
  }

  const newEvent = {
    id: data.id || `rw_evt_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    name: data.name.trim(),
    eventType: data.eventType || 'CUSTOM',
    rankingSubject: data.rankingSubject || (data.eventType === 'WEEKLY_TOP_AGENCY' ? 'AGENCY' : 'USER'),
    metric: data.metric || 'VERIFIED_POINTS',
    scope: (data.scope || (countryList.length > 0 ? 'COUNTRY_WISE' : 'GLOBAL')).toUpperCase(),
    countries: countryList,
    recurrence: data.recurrence || 'NONE',
    startsAt,
    endsAt,
    distributionMode: data.distributionMode || 'AUTOMATIC',
    tieRule: data.tieRule || 'EARLIEST_SCORE',
    status: data.status || 'LIVE',
    rewards: data.rewards || {
      top1: { rank: 1, rewardType: 'COINS', amount: 1000000, title: 'Top 1 Reward' },
      top2: { rank: 2, rewardType: 'COINS', amount: 500000, title: 'Top 2 Reward' },
      top3: { rank: 3, rewardType: 'COINS', amount: 250000, title: 'Top 3 Reward' },
    },
    leaderboardSnapshot: data.leaderboardSnapshot || [],
    distributedRewards: [],
    createdAt: now.toISOString(),
  };

  rankingEventsCache.push(newEvent);

  await logAudit({
    adminId,
    adminName,
    action: 'RANKING_REWARD_EVENT_CREATED',
    targetEntity: 'RankingRewardEvent',
    targetEntityId: newEvent.id,
    afterStateJson: newEvent,
    reason: data.reason || 'New Ranking Reward Event created via Admin Panel',
    ipAddress,
  });

  return newEvent;
}

export async function updateRankingEvent(id, updates, { adminId, adminName, ipAddress } = {}) {
  const index = rankingEventsCache.findIndex((e) => e.id === id);
  if (index === -1) {
    const error = new Error('Ranking reward event not found');
    error.statusCode = 404;
    throw error;
  }

  const beforeState = JSON.parse(JSON.stringify(rankingEventsCache[index]));
  rankingEventsCache[index] = {
    ...rankingEventsCache[index],
    ...updates,
    updatedAt: new Date().toISOString(),
  };

  await logAudit({
    adminId,
    adminName,
    action: 'RANKING_REWARD_EVENT_UPDATED',
    targetEntity: 'RankingRewardEvent',
    targetEntityId: id,
    beforeStateJson: beforeState,
    afterStateJson: rankingEventsCache[index],
    reason: updates.reason || 'Ranking Reward Event updated via Admin Panel',
    ipAddress,
  });

  return rankingEventsCache[index];
}

export async function pauseOrCancelRankingEvent(id, { action = 'PAUSED', reason, adminId, adminName, ipAddress } = {}) {
  const event = rankingEventsCache.find((e) => e.id === id);
  if (!event) {
    const error = new Error('Ranking reward event not found');
    error.statusCode = 404;
    throw error;
  }

  const beforeStatus = event.status;
  event.status = action.toUpperCase();

  await logAudit({
    adminId,
    adminName,
    action: `RANKING_REWARD_EVENT_${event.status}`,
    targetEntity: 'RankingRewardEvent',
    targetEntityId: id,
    beforeStateJson: { status: beforeStatus },
    afterStateJson: { status: event.status },
    reason: reason || `Event status changed to ${event.status}`,
    ipAddress,
  });

  return event;
}

export async function distributeEventRewards(id, { adminId, adminName, ipAddress, reason } = {}) {
  const event = rankingEventsCache.find((e) => e.id === id);
  if (!event) {
    const error = new Error('Ranking reward event not found');
    error.statusCode = 404;
    throw error;
  }

  const winners = (event.leaderboardSnapshot || []).slice(0, 3);
  const distributed = [];

  winners.forEach((winner) => {
    // Check duplicate payment protection
    const alreadyPaid = (event.distributedRewards || []).some(
      (d) => d.subjectId === winner.subjectId && d.rank === winner.rank
    );

    if (!alreadyPaid) {
      let rewardObj = null;
      if (winner.rank === 1) rewardObj = event.rewards.top1;
      else if (winner.rank === 2) rewardObj = event.rewards.top2;
      else if (winner.rank === 3) rewardObj = event.rewards.top3;

      const payoutRecord = {
        transactionId: `RW_PAY_${Date.now()}_${Math.random().toString(36).substring(2, 7).toUpperCase()}`,
        subjectId: winner.subjectId,
        subjectName: winner.name,
        rank: winner.rank,
        score: winner.score,
        reward: rewardObj || { title: 'Standard Rank Reward', amount: 100000, rewardType: 'COINS' },
        status: 'PAID',
        distributedAt: new Date().toISOString(),
        adminName: adminName || 'System / Auto',
      };

      distributed.push(payoutRecord);
      event.distributedRewards.push(payoutRecord);
    }
  });

  event.status = 'COMPLETED';

  await logAudit({
    adminId,
    adminName,
    action: 'RANKING_REWARDS_DISTRIBUTED',
    targetEntity: 'RankingRewardEvent',
    targetEntityId: id,
    afterStateJson: { distributedCount: distributed.length, distributed },
    reason: reason || 'Event rewards distributed and settled successfully',
    ipAddress,
  });

  return {
    success: true,
    eventId: id,
    distributedCount: distributed.length,
    distributedRewards: distributed,
  };
}

export async function getLiveLeaderboardForUsers(id, { userCountryCode } = {}) {
  const event = rankingEventsCache.find((e) => e.id === id);
  if (!event || event.status === 'CANCELLED') {
    const error = new Error('Ranking reward event not found or inactive');
    error.statusCode = 404;
    throw error;
  }

  // Country Targeting Verification
  if (event.scope === 'COUNTRY_WISE' && userCountryCode && userCountryCode !== 'GLOBAL') {
    if (Array.isArray(event.countries) && !event.countries.includes(userCountryCode.toUpperCase())) {
      const error = new Error('This event is not available in your registered country');
      error.statusCode = 403;
      throw error;
    }
  }

  return {
    id: event.id,
    name: event.name,
    eventType: event.eventType,
    metric: event.metric,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    status: event.status,
    rewards: event.rewards,
    leaderboard: event.leaderboardSnapshot,
    winners: event.distributedRewards,
  };
}

export default {
  listRankingEventsForAdmin,
  getRankingEventById,
  createRankingEvent,
  updateRankingEvent,
  pauseOrCancelRankingEvent,
  distributeEventRewards,
  getLiveLeaderboardForUsers,
};
