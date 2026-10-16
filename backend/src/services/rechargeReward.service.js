import prisma from '../config/database.js';

/**
 * Calculates authoritative cumulative eligible recharge for an authenticated user within an event window.
 * 
 * Rules:
 * 1. Only OnlineRecharge with status 'SUCCESS' inside the event window.
 * 2. Only OfflineRecharge with status 'APPROVED' inside the event window.
 * 3. Deducts verified chargebacks in the same event window.
 * 4. Uses precise decimal arithmetic; prevents duplicate payment records from double-counting.
 * 5. Returns 0.00 for users with no qualifying transactions.
 */
export async function calculateAuthoritativeRechargeTotal(userId, event, db = prisma) {
  if (!userId || !event || !event.startDate || !event.endDate) {
    return 0.00;
  }

  const startDate = new Date(event.startDate);
  const endDate = new Date(event.endDate);

  // 1. Fetch confirmed online recharges
  const onlineRecharges = await db.onlineRecharge.findMany({
    where: {
      userId,
      status: 'SUCCESS',
      createdAt: {
        gte: startDate,
        lte: endDate,
      },
    },
    select: {
      id: true,
      amountUSD: true,
      gatewayTxId: true,
    },
  });

  // Deduplicate by gatewayTxId to prevent counting repeated webhook callbacks
  const seenTxIds = new Set();
  let onlineTotalUSD = 0;
  for (const r of onlineRecharges) {
    const txId = r.gatewayTxId || r.id;
    if (!seenTxIds.has(txId)) {
      seenTxIds.add(txId);
      onlineTotalUSD += Number(r.amountUSD || 0);
    }
  }

  // 2. Fetch approved offline recharges
  const offlineRecharges = await db.offlineRecharge.findMany({
    where: {
      userId,
      status: 'APPROVED',
      createdAt: {
        gte: startDate,
        lte: endDate,
      },
    },
    select: {
      id: true,
      amountUSD: true,
      transactionRef: true,
    },
  });

  const seenRefs = new Set();
  let offlineTotalUSD = 0;
  for (const r of offlineRecharges) {
    const ref = r.transactionRef || r.id;
    if (!seenRefs.has(ref)) {
      seenRefs.add(ref);
      offlineTotalUSD += Number(r.amountUSD || 0);
    }
  }

  // 3. Deduct dispute chargebacks received during the event window
  const chargebacks = await db.chargeback.findMany({
    where: {
      userId,
      status: { in: ['RECEIVED', 'INVESTIGATING', 'RESOLVED'] },
      createdAt: {
        gte: startDate,
        lte: endDate,
      },
    },
    select: {
      id: true,
      amountUSD: true,
    },
  });

  let chargebackTotalUSD = 0;
  for (const c of chargebacks) {
    chargebackTotalUSD += Number(c.amountUSD || 0);
  }

  // Net cumulative eligible recharge
  const netUSD = Math.max(0, onlineTotalUSD + offlineTotalUSD - chargebackTotalUSD);
  return Number(netUSD.toFixed(2));
}

/**
 * Retrieves the current active recharge event and computes user progress.
 */
export async function getCurrentEventWithUserProgress(userId, eventIdOrDb = null, optionalDb = null) {
  let db = prisma;
  let targetEventId = null;

  if (typeof eventIdOrDb === 'string') {
    targetEventId = eventIdOrDb;
    if (optionalDb) db = optionalDb;
  } else if (eventIdOrDb && typeof eventIdOrDb === 'object') {
    db = eventIdOrDb;
  }

  const now = new Date();

  // Find event
  let event = null;
  if (targetEventId) {
    event = await db.rechargeRewardEvent.findUnique({
      where: { id: targetEventId },
    });
  } else {
    event = await db.rechargeRewardEvent.findFirst({
      where: {
        isActive: true,
      },
      orderBy: {
        startDate: 'desc',
      },
    });
  }

  if (!event) {
    return {
      hasActiveEvent: false,
      event: null,
      userProgress: {
        userId,
        cumulativeRechargeUSD: 0.00,
        currency: 'USD',
        nextMilestone: null,
        claimedCount: 0,
        eligibleCount: 0,
      },
      milestones: [],
    };
  }

  const startDate = new Date(event.startDate);
  const endDate = new Date(event.endDate);

  let eventStatus = 'ACTIVE';
  if (now < startDate) {
    eventStatus = 'UPCOMING';
  } else if (now > endDate) {
    eventStatus = 'EXPIRED';
  }

  const remainingSeconds = Math.max(0, Math.floor((endDate.getTime() - now.getTime()) / 1000));

  // Compute authoritative cumulative recharge for authenticated user
  const cumulativeRechargeUSD = await calculateAuthoritativeRechargeTotal(userId, event, db);

  // Retrieve user's persisted claims for this exact event
  const claims = await db.userMilestoneClaim.findMany({
    where: {
      userId,
      eventId: event.id,
    },
  });
  const claimsByLevel = new Map(claims.map((c) => [c.milestoneLevel, c]));

  // Parse milestones from event
  const rawMilestones = Array.isArray(event.milestones) ? event.milestones : [];
  const milestones = rawMilestones.map((m) => {
    const level = Number(m.level);
    const thresholdUSD = Number(Number(m.thresholdUSD || 0).toFixed(2));
    const claim = claimsByLevel.get(level);
    const isClaimed = !!claim;
    const isEligible = !isClaimed && cumulativeRechargeUSD >= thresholdUSD;

    let status = 'LOCKED';
    if (isClaimed) {
      status = 'CLAIMED';
    } else if (isEligible) {
      status = 'ELIGIBLE';
    }

    const remainingUSD = Math.max(0, Number((thresholdUSD - cumulativeRechargeUSD).toFixed(2)));

    return {
      level,
      thresholdUSD,
      remainingUSD,
      status,
      bonusCoins: Number(m.bonusCoins || 0),
      bonusDiamonds: Number(m.bonusDiamonds || 0),
      specialRewardName: m.specialRewardName || null,
      specialRewardIcon: m.specialRewardIcon || null,
      claimedAt: claim ? claim.claimedAt : null,
    };
  });

  // Calculate next unreached milestone
  let nextMilestone = null;
  for (const m of milestones) {
    if (cumulativeRechargeUSD < m.thresholdUSD) {
      nextMilestone = {
        level: m.level,
        thresholdUSD: m.thresholdUSD,
        remainingUSD: Number((m.thresholdUSD - cumulativeRechargeUSD).toFixed(2)),
      };
      break;
    }
  }

  const claimedCount = milestones.filter((m) => m.status === 'CLAIMED').length;
  const eligibleCount = milestones.filter((m) => m.status === 'ELIGIBLE').length;

  return {
    hasActiveEvent: Boolean(event.isActive && eventStatus === 'ACTIVE'),
    event: {
      id: event.id,
      code: event.code,
      title: event.title,
      description: event.description,
      currency: event.currency || 'USD',
      startDate: event.startDate,
      endDate: event.endDate,
      isActive: event.isActive,
      status: eventStatus,
      remainingSeconds,
    },
    userProgress: {
      userId,
      cumulativeRechargeUSD,
      currency: event.currency || 'USD',
      nextMilestone,
      claimedCount,
      eligibleCount,
    },
    milestones,
  };
}

/**
 * Claims a recharge milestone reward atomically for the authenticated user.
 */
export async function claimMilestoneReward(userId, { eventId, milestoneLevel }, db = prisma) {
  if (!userId) {
    const error = new Error('Authentication required to claim reward');
    error.statusCode = 401;
    throw error;
  }

  const numLevel = Number(milestoneLevel);
  if (isNaN(numLevel) || numLevel <= 0) {
    const error = new Error('Valid milestone level is required');
    error.statusCode = 400;
    throw error;
  }

  // 1. Resolve event
  let event = null;
  if (eventId) {
    event = await db.rechargeRewardEvent.findUnique({ where: { id: eventId } });
  } else {
    event = await db.rechargeRewardEvent.findFirst({
      where: { isActive: true },
      orderBy: { startDate: 'desc' },
    });
  }

  if (!event) {
    const error = new Error('No active recharge reward event found');
    error.statusCode = 404;
    throw error;
  }

  if (!event.isActive) {
    const error = new Error('This recharge reward event is currently inactive');
    error.statusCode = 400;
    throw error;
  }

  const now = new Date();
  if (now < new Date(event.startDate)) {
    const error = new Error('This recharge reward event has not started yet');
    error.statusCode = 400;
    throw error;
  }

  if (now > new Date(event.endDate)) {
    const error = new Error('This recharge reward event has expired');
    error.statusCode = 400;
    throw error;
  }

  // 2. Resolve milestone definition in event
  const rawMilestones = Array.isArray(event.milestones) ? event.milestones : [];
  const milestone = rawMilestones.find((m) => Number(m.level) === numLevel);
  if (!milestone) {
    const error = new Error(`Milestone level ${numLevel} does not exist in event "${event.title}"`);
    error.statusCode = 404;
    throw error;
  }

  const thresholdUSD = Number(milestone.thresholdUSD || 0);

  // 3. Verify authoritative cumulative eligible recharge
  const cumulativeRechargeUSD = await calculateAuthoritativeRechargeTotal(userId, event, db);
  if (cumulativeRechargeUSD < thresholdUSD) {
    const error = new Error(
      `Milestone threshold not met. Required: $${thresholdUSD.toFixed(2)} USD, Current: $${cumulativeRechargeUSD.toFixed(2)} USD`
    );
    error.statusCode = 400;
    error.code = 'THRESHOLD_NOT_MET';
    throw error;
  }

  // 4. Check if already claimed
  const existingClaim = await db.userMilestoneClaim.findUnique({
    where: {
      userId_eventId_milestoneLevel: {
        userId,
        eventId: event.id,
        milestoneLevel: numLevel,
      },
    },
  });

  if (existingClaim) {
    const error = new Error(`Milestone level ${numLevel} has already been claimed for this event`);
    error.statusCode = 400;
    error.code = 'ALREADY_CLAIMED';
    throw error;
  }

  // 5. Execute atomic reward grant in transaction
  return await db.$transaction(async (tx) => {
    // Concurrency defense check
    const checkAgain = await tx.userMilestoneClaim.findUnique({
      where: {
        userId_eventId_milestoneLevel: {
          userId,
          eventId: event.id,
          milestoneLevel: numLevel,
        },
      },
    });

    if (checkAgain) {
      const error = new Error(`Milestone level ${numLevel} has already been claimed`);
      error.statusCode = 400;
      error.code = 'ALREADY_CLAIMED';
      throw error;
    }

    const bonusCoins = BigInt(milestone.bonusCoins || 0);
    const bonusDiamonds = BigInt(milestone.bonusDiamonds || 0);

    // Create claim record
    const claim = await tx.userMilestoneClaim.create({
      data: {
        userId,
        eventId: event.id,
        milestoneLevel: numLevel,
        thresholdUSD: thresholdUSD,
        bonusCoins,
        bonusDiamonds,
        specialRewardName: milestone.specialRewardName || null,
        specialRewardIcon: milestone.specialRewardIcon || null,
        txReference: `RECHARGE_REWARD_L${numLevel}_${Date.now()}`,
      },
    });

    // Credit user wallet
    const wallet = await tx.wallet.findUnique({ where: { userId } });
    if (!wallet) {
      const error = new Error('Wallet not found for authenticated user');
      error.statusCode = 404;
      throw error;
    }

    const coinsBefore = wallet.coinBalance;
    const diamondsBefore = wallet.diamondBalance;

    const updatedWallet = await tx.wallet.update({
      where: { userId },
      data: {
        coinBalance: { increment: bonusCoins },
        diamondBalance: { increment: bonusDiamonds },
      },
    });

    // Record transaction in WalletLedger
    await tx.walletLedger.create({
      data: {
        walletId: wallet.id,
        transactionType: 'RECHARGE',
        coinDelta: bonusCoins,
        diamondDelta: bonusDiamonds,
        usdDelta: 0.00,
        balanceBefore: {
          coins: coinsBefore.toString(),
          diamonds: diamondsBefore.toString(),
        },
        balanceAfter: {
          coins: updatedWallet.coinBalance.toString(),
          diamonds: updatedWallet.diamondBalance.toString(),
        },
        referenceId: claim.id,
      },
    });

    return {
      claim: {
        id: claim.id,
        eventId: claim.eventId,
        milestoneLevel: claim.milestoneLevel,
        thresholdUSD: Number(claim.thresholdUSD),
        bonusCoins: Number(claim.bonusCoins),
        bonusDiamonds: Number(claim.bonusDiamonds),
        specialRewardName: claim.specialRewardName,
        specialRewardIcon: claim.specialRewardIcon,
        claimedAt: claim.claimedAt,
      },
      wallet: {
        coinBalance: Number(updatedWallet.coinBalance),
        diamondBalance: Number(updatedWallet.diamondBalance),
      },
    };
  });
}

/**
 * Retrieves past milestone claim records for the authenticated user.
 */
export async function getUserClaimHistory(userId, { limit = 20 } = {}, db = prisma) {
  const claims = await db.userMilestoneClaim.findMany({
    where: { userId },
    include: {
      event: {
        select: {
          id: true,
          code: true,
          title: true,
        },
      },
    },
    orderBy: {
      claimedAt: 'desc',
    },
    take: limit,
  });

  return claims.map((c) => ({
    id: c.id,
    eventId: c.eventId,
    eventTitle: c.event?.title || 'Recharge Reward Event',
    milestoneLevel: c.milestoneLevel,
    thresholdUSD: Number(c.thresholdUSD),
    bonusCoins: Number(c.bonusCoins),
    bonusDiamonds: Number(c.bonusDiamonds),
    specialRewardName: c.specialRewardName,
    specialRewardIcon: c.specialRewardIcon,
    claimedAt: c.claimedAt,
  }));
}

/**
 * Admin: Retrieves all recharge reward events.
 */
export async function getAdminEvents(db = prisma) {
  const events = await db.rechargeRewardEvent.findMany({
    include: {
      _count: {
        select: { claims: true },
      },
    },
    orderBy: {
      createdAt: 'desc',
    },
  });

  const now = new Date();
  return events.map((e) => {
    let status = 'ACTIVE';
    if (!e.isActive) {
      status = 'INACTIVE';
    } else if (now < new Date(e.startDate)) {
      status = 'UPCOMING';
    } else if (now > new Date(e.endDate)) {
      status = 'EXPIRED';
    }

    return {
      ...e,
      status,
      totalClaimsCount: e._count.claims,
    };
  });
}

/**
 * Admin: Creates or updates a recharge reward event.
 */
export async function createOrUpdateEvent(eventData, { adminId, adminName } = {}, db = prisma) {
  const { id, code, title, description, currency = 'USD', startDate, endDate, isActive = true, milestones } = eventData;

  if (!title) {
    const error = new Error('Event title is required');
    error.statusCode = 400;
    throw error;
  }

  const sDate = new Date(startDate);
  const eDate = new Date(endDate);
  if (isNaN(sDate.getTime()) || isNaN(eDate.getTime())) {
    const error = new Error('Valid start and end dates are required');
    error.statusCode = 400;
    throw error;
  }

  if (eDate <= sDate) {
    const error = new Error('End date must be after start date');
    error.statusCode = 400;
    throw error;
  }

  if (!Array.isArray(milestones) || milestones.length === 0) {
    const error = new Error('At least one milestone definition is required');
    error.statusCode = 400;
    throw error;
  }

  // Validate milestones
  const seenLevels = new Set();
  for (const m of milestones) {
    const lvl = Number(m.level);
    const th = Number(m.thresholdUSD);
    if (!lvl || lvl <= 0) {
      const error = new Error('Each milestone must have a positive integer level');
      error.statusCode = 400;
      throw error;
    }
    if (seenLevels.has(lvl)) {
      const error = new Error(`Duplicate milestone level ${lvl} detected`);
      error.statusCode = 400;
      throw error;
    }
    seenLevels.add(lvl);

    if (isNaN(th) || th <= 0) {
      const error = new Error(`Milestone level ${lvl} must have a positive thresholdUSD`);
      error.statusCode = 400;
      throw error;
    }
  }

  let result;
  if (id) {
    result = await db.rechargeRewardEvent.update({
      where: { id },
      data: {
        title,
        description,
        currency,
        startDate: sDate,
        endDate: eDate,
        isActive: Boolean(isActive),
        milestones,
      },
    });
  } else {
    const finalCode = code || `RECHARGE_EVENT_${Date.now()}`;
    result = await db.rechargeRewardEvent.create({
      data: {
        code: finalCode,
        title,
        description,
        currency,
        startDate: sDate,
        endDate: eDate,
        isActive: Boolean(isActive),
        milestones,
      },
    });
  }

  return result;
}

/**
 * Admin: Toggles event active status.
 */
export async function toggleEventStatus(eventId, isActive, { adminId, adminName } = {}, db = prisma) {
  const event = await db.rechargeRewardEvent.findUnique({ where: { id: eventId } });
  if (!event) {
    const error = new Error('Event not found');
    error.statusCode = 404;
    throw error;
  }

  return await db.rechargeRewardEvent.update({
    where: { id: eventId },
    data: {
      isActive: Boolean(isActive),
    },
  });
}

export default {
  calculateAuthoritativeRechargeTotal,
  getCurrentEventWithUserProgress,
  claimMilestoneReward,
  getUserClaimHistory,
  getAdminEvents,
  createOrUpdateEvent,
  toggleEventStatus,
};
