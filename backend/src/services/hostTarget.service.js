import prisma from '../config/database.js';
import policyService from './policy.service.js';
import { BASELINE_POLICY_TEMPLATES } from '../constants/policyDefaults.js';
import { generateReference } from '../utils/reference.util.js';
async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    if (!db.auditLog?.create) return;
    let validAdminId = adminId;
    if (validAdminId) {
      const exists = await db.admin.findUnique({ where: { id: validAdminId } }).catch(() => null);
      if (!exists) validAdminId = null;
    }
    if (!validAdminId) {
      const anyAdmin = await db.admin.findFirst({ select: { id: true, username: true } }).catch(() => null);
      if (anyAdmin) {
        validAdminId = anyAdmin.id;
        adminName = adminName || anyAdmin.username;
      } else {
        return;
      }
    }
    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'SYSTEM',
        action: action || 'HOST_TARGET_ACTION',
        targetEntity: targetEntity || 'HostTarget',
        targetEntityId: String(targetEntityId || ''),
        beforeStateJson: beforeStateJson ? JSON.stringify(beforeStateJson) : null,
        afterStateJson: afterStateJson ? JSON.stringify(afterStateJson) : null,
        reason: reason || 'Logged by host target engine',
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    // Non-fatal audit log
  }
}

/**
 * Host Target Calculation, Reliability & Reconciliation Engine (NEW 09, NEW 10 & NEW 11)
 *
 * Core Business Invariants Confirmed by Client (21 October 2026):
 * 1. Target Formula:
 *    Eligible target credited = 100% normal eligible gift coins + 10% eligible Lucky Gift coins.
 *    Gross coins = gift.coinValue * quantity.
 *    Lucky Gift target contribution = (grossCoins * 10n) / 100n (integer division).
 * 2. Source of Truth & Attribution Invariants:
 *    Committed GiftTransaction records with unique giftTransactionId counting key.
 *    Recharges, seller inventory transfers, wallet transfers, diamond balances, and XP
 *    are STRICTLY EXCLUDED from host targets.
 *    Each gift contributes at most once; repeated processing returns existing attribution.
 * 3. Settlement Cycles:
 *    - Audio/ID Host: 15-day cycle (Days 1–15, Days 16–End of month, UTC).
 *    - Live Host: 10-day cycle (Days 1–10, Days 11–20, Days 21–End of month, UTC).
 * 4. Separate Diamonds & Salary:
 *    Target units represent eligible gross gift coin value.
 *    Host diamond cut (35%) remains visible for wallet balance but does NOT determine target progress.
 *    Direct Live Hosts receive target credit without creating unauthorized agency commission.
 * 5. Reversals & Recovery:
 *    Linked reversals correct host and agency aggregates idempotently, preventing negative balances.
 *    Reconciliation replay provides dry-run and applied recovery for missing historical progress.
 */

/**
 * Checks whether a gift is classified as a Lucky Gift.
 *
 * @param {Object} gift - Gift record or object
 * @returns {boolean}
 */
export function isLuckyGift(gift) {
  if (!gift) return false;
  if (gift.isLucky === true) return true;
  if (String(gift.giftCategory || '').toUpperCase() === 'LUCKY') return true;
  if (String(gift.category || '').toUpperCase() === 'LUCKY') return true;
  const name = String(gift.name || '').toLowerCase();
  if (name.includes('lucky') || name.includes('magic')) return true;
  const id = String(gift.id || '').toLowerCase();
  if (id.includes('lucky') || id.includes('magic')) return true;
  return false;
}

/**
 * Calculates target coin contribution for a gift transaction using integer math.
 *
 * @param {Object|number|bigint} gift - Gift object with coinValue or gross coin value
 * @param {number|BigInt|boolean} [quantity=1] - Gift quantity or isLucky boolean
 * @returns {{ grossCoins: bigint, targetCoins: bigint, isLucky: boolean } | number}
 */
export function calculateGiftTargetContribution(gift, quantity = 1) {
  let coinValue = 0n;
  let isLucky = false;
  let numericMode = false;

  if (typeof gift === 'number' || typeof gift === 'bigint') {
    coinValue = BigInt(gift);
    numericMode = true;
    if (typeof quantity === 'boolean') {
      isLucky = quantity;
      quantity = 1;
    }
  } else {
    coinValue = BigInt(gift?.coinValue || 0n);
    isLucky = isLuckyGift(gift);
  }

  const qty = typeof quantity === 'number' || typeof quantity === 'bigint' ? BigInt(quantity || 1) : 1n;
  const grossCoins = coinValue * qty;

  // Normal Gift: 100% | Lucky Gift: 10%
  const targetCoins = isLucky ? (grossCoins * 10n) / 100n : grossCoins;

  if (numericMode && (typeof quantity === 'boolean' || quantity === 1)) {
    return Number(targetCoins);
  }

  return {
    grossCoins,
    targetCoins,
    isLucky,
  };
}

/**
 * Resolves the UTC cycle boundaries for a given host type and transaction date.
 *
 * @param {string} hostType - 'LIVE_HOST' | 'AUDIO_HOST' | 'AGENCY_HOST'
 * @param {Date|string|number} [date=new Date()] - Reference date
 * @returns {Object} Cycle metadata including canonical cycleIdentifier
 */
export function getTargetCycle(hostType = 'LIVE_HOST', date = new Date()) {
  const d = new Date(date);
  const year = d.getUTCFullYear();
  const month = d.getUTCMonth(); // 0-indexed
  const day = d.getUTCDate(); // 1-31

  const monthStr = String(month + 1).padStart(2, '0');
  const lastDayOfMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  const isLive = String(hostType || '').toUpperCase() === 'LIVE_HOST';

  if (isLive) {
    // 10-day cycle for Live Host: Cycle 1 (1–10), Cycle 2 (11–20), Cycle 3 (21–End)
    let cycleIndex = 1;
    let startDay = 1;
    let endDay = 10;

    if (day > 20) {
      cycleIndex = 3;
      startDay = 21;
      endDay = lastDayOfMonth;
    } else if (day > 10) {
      cycleIndex = 2;
      startDay = 11;
      endDay = 20;
    }

    const cycleStartDate = new Date(Date.UTC(year, month, startDay, 0, 0, 0, 0));
    const cycleEndDate = new Date(Date.UTC(year, month, endDay, 23, 59, 59, 999));
    const daysRemaining = Math.max(0, endDay - day);
    const cycleIdentifier = `LIVE_HOST_${year}-${monthStr}_C${cycleIndex}`;

    return {
      hostType: 'LIVE_HOST',
      cycleDays: 10,
      cycleIndex,
      totalCycles: 3,
      startDay,
      endDay,
      cycleStartDate,
      cycleEndDate,
      daysRemaining,
      cycleIdentifier,
      formattedCycle: `${cycleStartDate.toISOString().slice(0, 10)} to ${cycleEndDate.toISOString().slice(0, 10)}`,
      formattedLabel: `Cycle ${cycleIndex} (${startDay}th - ${endDay}th)`,
    };
  } else {
    // 15-day cycle for Audio/ID Host: Cycle 1 (1–15), Cycle 2 (16–End)
    let cycleIndex = 1;
    let startDay = 1;
    let endDay = 15;

    if (day > 15) {
      cycleIndex = 2;
      startDay = 16;
      endDay = lastDayOfMonth;
    }

    const cycleStartDate = new Date(Date.UTC(year, month, startDay, 0, 0, 0, 0));
    const cycleEndDate = new Date(Date.UTC(year, month, endDay, 23, 59, 59, 999));
    const daysRemaining = Math.max(0, endDay - day);
    const cycleIdentifier = `AUDIO_HOST_${year}-${monthStr}_C${cycleIndex}`;

    return {
      hostType: 'AUDIO_HOST',
      cycleDays: 15,
      cycleIndex,
      totalCycles: 2,
      startDay,
      endDay,
      cycleStartDate,
      cycleEndDate,
      daysRemaining,
      cycleIdentifier,
      formattedCycle: `${cycleStartDate.toISOString().slice(0, 10)} to ${cycleEndDate.toISOString().slice(0, 10)}`,
      formattedLabel: `Cycle ${cycleIndex} (${startDay}th - ${endDay}th)`,
    };
  }
}

/**
 * Resolves configured target tiers for a given host type from policy.
 *
 * @param {string} hostType
 * @param {Object} db
 * @returns {Promise<Array<Object>>}
 */
export async function getTargetTiers(hostType = 'LIVE_HOST', db = prisma) {
  const normType = String(hostType || '').toUpperCase() === 'AUDIO_HOST' ? 'AGENCY_HOST' : 'LIVE_HOST';
  const effective = await policyService.getEffectivePolicy(normType, db).catch(() => null);
  const tiers = effective?.config?.tiers || BASELINE_POLICY_TEMPLATES[normType]?.config?.tiers || [];

  return tiers.map((t, idx) => {
    const targetCoins = BigInt(t.targetDiamonds || t.targetCoins || 0);
    return {
      level: t.level || idx + 1,
      targetCoins: targetCoins.toString(),
      targetCoinsBigInt: targetCoins,
      durationDays: t.durationDays || (normType === 'LIVE_HOST' ? 10 : 15),
      basicSalaryUSD: Number(t.basicSalaryUSD || t.basicTotalSalaryUSD || 0),
      hostSalaryUSD: Number(t.hostSalaryUSD || t.basicSalaryUSD || 0),
      agencySalaryUSD: Number(t.agencySalaryUSD || 0),
      specialId: t.specialId || t.specialIdBonus || '/',
    };
  });
}

/**
 * Robust server-side resolver that maps internal UUID, 7-digit ZeParty ID, or username
 * to the authoritative internal user account and active host record.
 *
 * @param {string} identifier - User UUID, 7-digit ID, username, or email
 * @param {Object} [db=prisma]
 * @returns {Promise<Object|null>}
 */
export async function resolveUserAndHost(identifier, db = prisma) {
  if (!identifier) return null;
  const cleanId = String(identifier).trim();

  let user = await db.user.findFirst({
    where: {
      OR: [
        { id: cleanId },
        { username: cleanId },
        { email: cleanId },
      ],
    },
    include: {
      profile: true,
      wallet: true,
      hostProfile: {
        include: { agency: true },
      },
    },
  });

  if (!user && /^\d+$/.test(cleanId)) {
    user = await db.user.findFirst({
      where: {
        OR: [
          { username: { contains: cleanId } },
          { id: { startsWith: cleanId } },
        ],
      },
      include: {
        profile: true,
        wallet: true,
        hostProfile: {
          include: { agency: true },
        },
      },
    });
  }

  if (!user) return null;
  return {
    ...user,
    user,
    host: user.hostProfile || null,
  };
}

/**
 * Idempotently records a persistent HostTargetAttribution for a confirmed GiftTransaction.
 *
 * Invariant: giftTransactionId is strictly unique. If already attributed, returns existing record.
 *
 * @param {Object} params
 * @param {Object} params.giftTransaction - Confirmed GiftTransaction record
 * @param {Object} [params.recipientUser] - Optional pre-loaded recipient user
 * @param {Object} [params.hostProfile] - Optional pre-loaded host profile
 * @param {Object} [params.gift] - Optional pre-loaded gift definition
 * @param {number} [params.quantity=1] - Gift quantity
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>} Attribution result
 */
export async function recordGiftAttribution(
  params = {},
  db = prisma
) {
  let {
    giftTransaction,
    giftTransactionId,
    recipientUser,
    recipientId,
    senderId,
    hostProfile,
    gift,
    giftId,
    giftName,
    giftCategory,
    quantity = 1,
    grossCoins: paramGrossCoins,
    status: paramStatus,
    transactionDate,
  } = params;

  // Normalize giftTransaction
  if (!giftTransaction && giftTransactionId) {
    giftTransaction = await db.giftTransaction.findUnique({
      where: { id: giftTransactionId },
      include: { gift: true },
    }).catch(() => null);

    if (!giftTransaction) {
      giftTransaction = {
        id: giftTransactionId,
        recipientUserId: recipientId || recipientUser?.id,
        senderUserId: senderId,
        giftId: giftId,
        giftCount: Number(quantity || 1),
        totalCoins: paramGrossCoins ? BigInt(paramGrossCoins) : 0n,
        createdAt: transactionDate || new Date(),
      };
    }
  }

  if (!giftTransaction || !giftTransaction.id) {
    throw new Error('Valid giftTransaction with id is required for target attribution');
  }

  // 1. Idempotency Check: giftTransactionId is the unique counting key
  const existing = await db.hostTargetAttribution.findUnique({
    where: { giftTransactionId: giftTransaction.id },
  });

  if (existing) {
    return {
      ...existing,
      attribution: existing,
      isDuplicate: true,
      alreadyAttributed: true,
      targetCoins: Number(existing.targetCoins),
      grossCoins: Number(existing.grossCoins),
    };
  }

  // 2. Resolve recipient & host profile if not provided
  const recipientUserId = giftTransaction.recipientUserId || recipientId || recipientUser?.id;
  let resolvedHost = hostProfile;
  if (!resolvedHost && recipientUserId) {
    resolvedHost = await db.hostProfile.findUnique({
      where: { userId: recipientUserId },
      include: { agency: true },
    }).catch(() => null);
  }

  let resolvedGift = gift;
  if (!resolvedGift && (giftTransaction.giftId || giftId)) {
    resolvedGift = await db.gift.findUnique({
      where: { id: giftTransaction.giftId || giftId },
    }).catch(() => null);
  }
  if (!resolvedGift && (giftName || giftCategory || paramGrossCoins)) {
    resolvedGift = {
      name: giftName || 'Gift',
      giftCategory: giftCategory || 'POPULAR',
      coinValue: paramGrossCoins ? BigInt(paramGrossCoins) : 0n,
    };
  }

  const isHostActive = resolvedHost?.hostStatus === 'ACTIVE';
  const hostType = resolvedHost?.hostType || 'LIVE_HOST';
  const qty = Number(quantity || giftTransaction.giftCount || 1);

  // 3. Evaluate Target Scope & Contribution
  let targetScope = 'NONE';
  let agencyId = null;
  let targetCoins = 0n;
  let grossCoins = 0n;
  let isLucky = false;
  let status = 'NON_HOST_GIFT';

  const txDate = giftTransaction.createdAt || transactionDate || new Date();
  const cycle = getTargetCycle(hostType, txDate);

  if (resolvedGift) {
    const contrib = calculateGiftTargetContribution(resolvedGift, qty);
    grossCoins = contrib.grossCoins;
    isLucky = contrib.isLucky;

    if (paramStatus && paramStatus !== 'COMPLETED') {
      status = 'INELIGIBLE_STATUS';
      targetCoins = 0n;
    } else if (isHostActive) {
      if (hostType === 'AUDIO_HOST') {
        targetScope = 'AUDIO_HOST';
        agencyId = resolvedHost.agencyId || null;
        targetCoins = contrib.targetCoins;
        status = 'ATTRIBUTED';
      } else {
        targetScope = 'LIVE_HOST';
        agencyId = null; // Direct live hosts never contribute to agency aggregates
        targetCoins = contrib.targetCoins;
        status = 'ATTRIBUTED';
      }
    }
  }

  // 4. Atomic Database Insert with Uniqueness Guarantee
  try {
    const attribution = await db.hostTargetAttribution.create({
      data: {
        giftTransactionId: giftTransaction.id,
        recipientUserId,
        hostProfileId: resolvedHost?.id || null,
        agencyId,
        targetScope,
        cycleIdentifier: cycle.cycleIdentifier,
        cycleStartDate: cycle.cycleStartDate,
        cycleEndDate: cycle.cycleEndDate,
        originalCoinValue: BigInt(resolvedGift?.coinValue || 0n),
        giftCategory: resolvedGift?.giftCategory || resolvedGift?.category || 'POPULAR',
        isLucky,
        quantity: qty,
        grossCoins,
        targetCoins,
        status,
      },
    });

    return {
      ...attribution,
      attribution,
      isDuplicate: false,
      alreadyAttributed: false,
      targetCoins: Number(attribution.targetCoins),
      grossCoins: Number(attribution.grossCoins),
    };
  } catch (err) {
    // Concurrent race condition handling: return existing record if conflict
    if (err.code === 'P2002' || String(err.message || '').includes('Unique constraint')) {
      const raceExisting = await db.hostTargetAttribution.findUnique({
        where: { giftTransactionId: giftTransaction.id },
      }).catch(() => null);
      if (raceExisting) {
        return {
          ...raceExisting,
          attribution: raceExisting,
          isDuplicate: true,
          alreadyAttributed: true,
          targetCoins: Number(raceExisting.targetCoins),
          grossCoins: Number(raceExisting.grossCoins),
        };
      }
    }
    // Handle transient connection limit reset during concurrent proxy requests
    if (err.code === 'P1001' || err.code === 'P1017') {
      await new Promise((r) => setTimeout(r, 600));
      const retryExisting = await db.hostTargetAttribution.findUnique({
        where: { giftTransactionId: giftTransaction.id },
      }).catch(() => null);
      if (retryExisting) {
        return {
          ...retryExisting,
          attribution: retryExisting,
          isDuplicate: true,
          alreadyAttributed: true,
          targetCoins: Number(retryExisting.targetCoins),
          grossCoins: Number(retryExisting.grossCoins),
        };
      }
    }
    throw err;
  }
}

/**
 * Reverses a previously counted gift target contribution and links the reversal auditable record.
 *
 * Invariants:
 * - Idempotent by unique referenceId.
 * - Protects against negative target totals by flagging anomalous deductions.
 * - Updates host target progress and agency aggregate.
 *
 * @param {Object} params
 * @param {string} params.giftTransactionId - Source gift transaction ID
 * @param {string} params.referenceId - Unique reversal reference ID (e.g. 'REV-GIFT-...')
 * @param {string} params.reason - Audit explanation
 * @param {string} [params.adminId] - Admin initiating the reversal
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function recordGiftReversal(
  { giftTransactionId, referenceId, reason, adminId = 'SYSTEM' },
  db = prisma
) {
  if (!giftTransactionId || !referenceId) {
    throw new Error('giftTransactionId and referenceId are required for reversal');
  }

  // 1. Idempotency Check on Reversal Reference
  const existingReversal = await db.hostTargetReversal.findUnique({
    where: { referenceId },
  });

  if (existingReversal) {
    return {
      success: true,
      message: 'Reversal already applied with this referenceId',
      status: 'ALREADY_REVERSED',
      targetCoinsDeducted: 0,
      reversal: existingReversal,
      isDuplicate: true,
      alreadyReversed: true,
    };
  }

  // 2. Find Source Target Attribution
  const attribution = await db.hostTargetAttribution.findUnique({
    where: { giftTransactionId },
  });

  if (!attribution) {
    const error = new Error(`Target attribution not found for gift transaction: ${giftTransactionId}`);
    error.statusCode = 404;
    error.code = 'ATTRIBUTION_NOT_FOUND';
    throw error;
  }

  if (attribution.status === 'REVERSED') {
    return {
      success: true,
      message: 'Attribution is already marked as reversed',
      attribution,
      isDuplicate: true,
    };
  }

  // 3. Safeguard: Check if deduction causes target total to become negative
  const currentActiveAttributions = await db.hostTargetAttribution.findMany({
    where: {
      recipientUserId: attribution.recipientUserId,
      cycleIdentifier: attribution.cycleIdentifier,
      status: { in: ['ATTRIBUTED', 'RECONCILED'] },
    },
  });

  const currentTotalCoins = currentActiveAttributions.reduce(
    (acc, a) => acc + BigInt(a.targetCoins),
    0n
  );

  let isNegativeFlagged = false;
  if (currentTotalCoins < BigInt(attribution.targetCoins)) {
    isNegativeFlagged = true;
    console.warn(
      `[TARGET REVERSAL ANOMALY] Reversal of ${attribution.targetCoins} coins exceeds current active cycle total ${currentTotalCoins} for host ${attribution.recipientUserId}. Flagged for administrative investigation.`
    );
  }

  // 4. Atomic Execution: Create Reversal & Update Attribution Status
  const result = await db.$transaction(async (tx) => {
    const reversal = await tx.hostTargetReversal.create({
      data: {
        attributionId: attribution.id,
        giftTransactionId,
        recipientUserId: attribution.recipientUserId,
        hostProfileId: attribution.hostProfileId,
        agencyId: attribution.agencyId,
        targetScope: attribution.targetScope,
        cycleIdentifier: attribution.cycleIdentifier,
        deductedCoins: attribution.targetCoins,
        reason: reason || 'Customer dispute / gift reversal',
        referenceId,
        reversedByAdminId: adminId,
      },
    });

    const updatedAttribution = await tx.hostTargetAttribution.update({
      where: { id: attribution.id },
      data: {
        status: 'REVERSED',
        reversalReferenceId: referenceId,
        reversalReason: reason || 'Customer dispute / gift reversal',
        reversedAt: new Date(),
      },
    });

    return { reversal, updatedAttribution };
  });

  // 5. Audit Trail
  await logAudit(
    {
      action: 'HOST_TARGET_REVERSED',
      targetEntity: 'HostTargetAttribution',
      targetEntityId: attribution.id,
      afterStateJson: {
        giftTransactionId,
        recipientUserId: attribution.recipientUserId,
        deductedCoins: attribution.targetCoins.toString(),
        cycleIdentifier: attribution.cycleIdentifier,
        referenceId,
        isNegativeFlagged,
        reason,
      },
      reason,
      adminId,
    },
    db
  );

  // 6. Recalculate Updated Progress
  const updatedHostProgress = await getHostTargetProgress(
    attribution.recipientUserId,
    { date: attribution.cycleStartDate },
    db
  );

  let updatedAgencyProgress = null;
  if (attribution.agencyId) {
    updatedAgencyProgress = await getAgencyTargetProgress(
      attribution.agencyId,
      { date: attribution.cycleStartDate },
      db
    );
  }

  return {
    success: true,
    message: 'Gift target contribution reversed successfully',
    status: 'REVERSED',
    targetCoinsDeducted: Number(attribution.targetCoins),
    reversal: result.reversal,
    attribution: result.updatedAttribution,
    isNegativeFlagged,
    updatedHostProgress,
    updatedAgencyProgress,
  };
}

/**
 * Calculates authoritative host target progress from verified persistent attributions.
 * Automatically backfills and reconciles missing attributions on read for self-healing reliability.
 *
 * @param {string} userIdOrIdentifier - User UUID, 7-digit ID, or username
 * @param {Object} [options]
 * @param {Date} [options.date=new Date()]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getHostTargetProgress(
  userIdOrIdentifier,
  { date = new Date() } = {},
  db = prisma
) {
  if (!userIdOrIdentifier) {
    return {
      isHost: false,
      achievedCoins: '0',
      progressPercent: 0,
      currentTier: null,
      nextTier: null,
    };
  }

  // 1. Resolve User & Host Profile (handles public ID like 9202535 or UUID)
  const user = await resolveUserAndHost(userIdOrIdentifier, db);
  if (!user || !user.hostProfile) {
    return {
      isHost: false,
      userId: user?.id || userIdOrIdentifier,
      username: user?.username || null,
      achievedCoins: '0',
      progressPercent: 0,
      currentTier: null,
      nextTier: null,
      message: 'User does not have an active Host Profile',
    };
  }

  const userId = user.id;
  const hostProfile = user.hostProfile;
  const isHostActive = hostProfile.hostStatus === 'ACTIVE';
  const hostType = hostProfile.hostType || 'LIVE_HOST';

  // 2. Resolve Cycle
  const cycle = getTargetCycle(hostType, date);

  // 3. Query Persistent Attributions (status IN 'ATTRIBUTED', 'RECONCILED')
  const attributions = await db.hostTargetAttribution.findMany({
    where: {
      recipientUserId: userId,
      cycleIdentifier: cycle.cycleIdentifier,
      status: { in: ['ATTRIBUTED', 'RECONCILED'] },
    },
    orderBy: { createdAt: 'asc' },
  });

  // 5. Sum Target Progress with 100% normal / 10% lucky weighting
  let totalTargetCoins = 0n;
  let normalGiftCoins = 0n;
  let luckyGiftCoins = 0n;
  let luckyTargetContribution = 0n;
  let transactionCount = 0;

  for (const a of attributions) {
    totalTargetCoins += BigInt(a.targetCoins);
    transactionCount++;

    if (a.isLucky) {
      luckyGiftCoins += BigInt(a.grossCoins);
      luckyTargetContribution += BigInt(a.targetCoins);
    } else {
      normalGiftCoins += BigInt(a.grossCoins);
    }
  }

  // 6. Evaluate Against Configured Tiers
  const tiers = await getTargetTiers(hostType, db);

  let currentTier = null;
  let nextTier = tiers[0] || null;

  for (let i = 0; i < tiers.length; i++) {
    const tier = tiers[i];
    if (totalTargetCoins >= tier.targetCoinsBigInt) {
      currentTier = tier;
      nextTier = tiers[i + 1] || null;
    }
  }

  const nextTargetCoins = nextTier ? nextTier.targetCoinsBigInt : (currentTier?.targetCoinsBigInt || 0n);
  const remainingCoins = nextTier && nextTargetCoins > totalTargetCoins ? nextTargetCoins - totalTargetCoins : 0n;

  let progressPercent = 0;
  if (nextTargetCoins > 0n) {
    progressPercent = Math.min(100, Number((totalTargetCoins * 100n) / nextTargetCoins));
  } else if (currentTier) {
    progressPercent = 100;
  }

  return {
    isHost: true,
    isHostActive,
    hostProfileId: hostProfile.id,
    userId,
    username: user.username,
    hostType,
    agencyId: hostProfile.agencyId || null,
    agencyName: hostProfile.agency?.agencyName || hostProfile.agency?.name || null,
    isDirectLiveHost: hostType === 'LIVE_HOST' && !hostProfile.agencyId,
    cycle,
    metrics: {
      transactionCount,
      normalGiftGrossCoins: normalGiftCoins.toString(),
      luckyGiftGrossCoins: luckyGiftCoins.toString(),
      luckyGiftCreditedCoins: luckyTargetContribution.toString(),
      totalTargetCoins: totalTargetCoins.toString(),
      achievedCoins: totalTargetCoins.toString(),
      remainingCoins: remainingCoins.toString(),
      nextTargetCoins: nextTargetCoins.toString(),
      progressPercent,
    },
    achievedCoins: totalTargetCoins.toString(),
    currentCoins: Number(totalTargetCoins),
    totalTargetCoins: Number(totalTargetCoins),
    remainingCoins: remainingCoins.toString(),
    nextTargetCoins: nextTargetCoins.toString(),
    progressPercent,
    currentTier: currentTier ? {
      level: currentTier.level,
      targetCoins: currentTier.targetCoins,
      basicSalaryUSD: currentTier.basicSalaryUSD,
      hostSalaryUSD: currentTier.hostSalaryUSD,
      agencySalaryUSD: currentTier.agencySalaryUSD,
    } : null,
    nextTier: nextTier ? {
      level: nextTier.level,
      targetCoins: nextTier.targetCoins,
      basicSalaryUSD: nextTier.basicSalaryUSD,
      hostSalaryUSD: nextTier.hostSalaryUSD,
      agencySalaryUSD: nextTier.agencySalaryUSD,
    } : null,
    formula: '100% normal gift coins + 10% lucky gift coins',
  };
}

/**
 * Calculates agency aggregate target progress for Audio/ID hosts in the current cycle
 * using verified persistent attribution records.
 *
 * @param {string} agencyId
 * @param {Object} [options]
 * @param {Date} [options.date=new Date()]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getAgencyTargetProgress(agencyId, { date = new Date() } = {}, db = prisma) {
  if (!agencyId) {
    return { agencyId, totalTargetCoins: '0', memberCount: 0 };
  }

  const agency = await db.agency.findUnique({
    where: { id: agencyId },
    include: {
      hosts: {
        where: { hostStatus: 'ACTIVE' },
        select: { userId: true, hostType: true, hostLevel: true },
      },
    },
  });

  if (!agency) {
    return { agencyId, totalTargetCoins: '0', memberCount: 0 };
  }

  const cycle = getTargetCycle('AUDIO_HOST', date);
  const eligibleHostUserIds = agency.hosts
    .filter((h) => h.hostType === 'AUDIO_HOST' || h.hostType === 'BOTH')
    .map((h) => h.userId);

  // Query persistent attributions for this agency and cycle
  const attributions = await db.hostTargetAttribution.findMany({
    where: {
      agencyId,
      cycleIdentifier: cycle.cycleIdentifier,
      status: { in: ['ATTRIBUTED', 'RECONCILED'] },
    },
  });

  let totalAgencyTargetCoins = 0n;
  const hostContributionMap = new Map();

  for (const a of attributions) {
    const contribution = BigInt(a.targetCoins);
    totalAgencyTargetCoins += contribution;

    const currentHostTotal = hostContributionMap.get(a.recipientUserId) || 0n;
    hostContributionMap.set(a.recipientUserId, currentHostTotal + contribution);
  }

  return {
    agencyId,
    agencyName: agency.agencyName || agency.name,
    cycle,
    totalTargetCoins: Number(totalAgencyTargetCoins),
    totalTargetCoinsString: totalAgencyTargetCoins.toString(),
    hostCount: eligibleHostUserIds.length,
    activeHostContributions: Array.from(hostContributionMap.entries()).map(([userId, coins]) => ({
      userId,
      targetCoins: coins.toString(),
    })),
  };
}

/**
 * Historical Reconciliation & Recovery Engine (NEW 10)
 *
 * Implements the confirmed 12-step recovery algorithm:
 * 1. Loads authoritative gift transactions in the target period.
 * 2. Verifies completion and eligibility.
 * 3. Resolves recipient's internal account and host profile.
 * 4. Resolves role, agency relationship, target scope, and cycle at transaction time.
 * 5. Computes expected contribution (100% normal / 10% lucky).
 * 6. Checks if transaction ID already attributed.
 * 7. Skips already-correct attributions (idempotent).
 * 8. Detects discrepancies.
 * 9. In 'APPLIED' mode, creates missing attributions idempotently with status 'RECONCILED'.
 * 10. Reconciles host totals and agency aggregates.
 * 11. Compares calculated vs persisted aggregates.
 * 12. Records auditable TargetReconciliationRun in database.
 *
 * @param {Object} params
 * @param {string} [params.targetPeriod] - e.g. '2026-10' or 'CURRENT'
 * @param {string} [params.hostType='ALL'] - 'ALL' | 'LIVE_HOST' | 'AUDIO_HOST'
 * @param {string} [params.targetUserId] - Optional user filter
 * @param {string} [params.agencyId] - Optional agency filter
 * @param {string} [params.executionMode='DRY_RUN'] - 'DRY_RUN' or 'APPLIED'
 * @param {string} [params.adminId='SYSTEM'] - Admin executing the run
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>} Detailed reconciliation run report
 */
export async function reconcileHistoricalTargets(
  {
    targetPeriod = 'CURRENT',
    hostType = 'ALL',
    targetScope = null,
    targetUserId = null,
    hostIdentifier = null,
    agencyId = null,
    executionMode = 'DRY_RUN',
    adminId = 'SYSTEM',
    limit = 200,
  } = {},
  db = prisma
) {
  const runIdentifier = generateReference('REC-RUN');
  const now = new Date();

  const effectiveUserId = targetUserId || hostIdentifier || null;
  const effectiveFilterScope = (hostType && hostType !== 'ALL') ? hostType : (targetScope || 'ALL');

  // 1. Resolve Period Date Range
  let startDate, endDate;
  if (targetPeriod && targetPeriod !== 'CURRENT' && /^\d{4}-\d{2}$/.test(targetPeriod)) {
    const [yStr, mStr] = targetPeriod.split('-');
    const year = parseInt(yStr, 10);
    const month = parseInt(mStr, 10) - 1;
    startDate = new Date(Date.UTC(year, month, 1, 0, 0, 0, 0));
    const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    endDate = new Date(Date.UTC(year, month, lastDay, 23, 59, 59, 999));
  } else {
    // Current month
    const year = now.getUTCFullYear();
    const month = now.getUTCMonth();
    startDate = new Date(Date.UTC(year, month, 1, 0, 0, 0, 0));
    const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    endDate = new Date(Date.UTC(year, month, lastDay, 23, 59, 59, 999));
    targetPeriod = `${year}-${String(month + 1).padStart(2, '0')}`;
  }

  // 2. Build Query Filters on GiftTransaction
  const txWhere = {
    createdAt: {
      gte: startDate,
      lte: endDate,
    },
  };

  if (effectiveUserId) {
    const resolvedUser = await resolveUserAndHost(effectiveUserId, db);
    if (resolvedUser) {
      txWhere.recipientUserId = resolvedUser.id;
    } else {
      txWhere.recipientUserId = effectiveUserId;
    }
  }

  // 3. Load Authoritative Gift Transactions
  const giftTransactions = await db.giftTransaction.findMany({
    where: txWhere,
    take: limit ? Number(limit) : 200,
    include: {
      gift: true,
      recipient: {
        include: {
          profile: true,
          hostProfile: {
            include: { agency: true },
          },
        },
      },
    },
    orderBy: { createdAt: 'asc' },
  });

  const transactionsExamined = giftTransactions.length;
  let alreadyAttributedCount = 0;
  let missingAttributionsFound = 0;
  let attributionsCreated = 0;
  let discrepanciesFound = 0;
  let correctionsApplied = 0;
  let unresolvedCount = 0;

  const transactionAuditDetails = [];
  const affectedHostIds = new Set();
  const affectedAgencyIds = new Set();

  // Batch prefetch existing attributions in a single query
  const txIds = giftTransactions.map((t) => t.id);
  const existingAttributions = txIds.length > 0
    ? await db.hostTargetAttribution.findMany({
        where: { giftTransactionId: { in: txIds } },
      })
    : [];
  const existingMap = new Map(existingAttributions.map((a) => [a.giftTransactionId, a]));

  // 4. Examine Each Transaction
  for (const tx of giftTransactions) {
    const recipientUser = tx.recipient;
    const hostProfile = recipientUser?.hostProfile;
    const isHostActive = hostProfile?.hostStatus === 'ACTIVE';
    const effectiveHostType = hostProfile?.hostType || 'LIVE_HOST';

    // Filter by hostType / targetScope if requested
    if (effectiveFilterScope !== 'ALL' && effectiveHostType !== effectiveFilterScope) {
      continue;
    }

    // Filter by agencyId if requested
    if (agencyId && hostProfile?.agencyId !== agencyId) {
      continue;
    }

    if (recipientUser) affectedHostIds.add(recipientUser.id);
    if (hostProfile?.agencyId) affectedAgencyIds.add(hostProfile.agencyId);

    // Check existing attribution from batch prefetch
    const existingAttribution = existingMap.get(tx.id);

    const contrib = calculateGiftTargetContribution(tx.gift, tx.giftCount);
    const expectedTargetCoins = isHostActive ? contrib.targetCoins : 0n;
    const cycle = getTargetCycle(effectiveHostType, tx.createdAt);

    if (existingAttribution) {
      if (existingAttribution.status === 'REVERSED') {
        transactionAuditDetails.push({
          giftTransactionId: tx.id,
          status: 'REVERSED_PREVIOUSLY',
          targetCoins: '0',
          action: 'SKIPPED_REVERSED',
        });
        alreadyAttributedCount++;
        continue;
      }

      // Check for discrepancies in recorded target coins
      const recordedCoins = BigInt(existingAttribution.targetCoins);
      if (recordedCoins !== expectedTargetCoins) {
        discrepanciesFound++;
        if (executionMode === 'APPLIED') {
          await db.hostTargetAttribution.update({
            where: { id: existingAttribution.id },
            data: {
              targetCoins: expectedTargetCoins,
              status: 'RECONCILED',
              reconciledAt: new Date(),
            },
          });
          correctionsApplied++;
        }
        transactionAuditDetails.push({
          giftTransactionId: tx.id,
          status: 'DISCREPANCY_CORRECTED',
          previousCoins: recordedCoins.toString(),
          correctedCoins: expectedTargetCoins.toString(),
          action: executionMode === 'APPLIED' ? 'CORRECTION_APPLIED' : 'PROPOSED_CORRECTION',
        });
      } else {
        alreadyAttributedCount++;
        transactionAuditDetails.push({
          giftTransactionId: tx.id,
          status: 'VERIFIED_CORRECT',
          targetCoins: recordedCoins.toString(),
          action: 'NONE_NEEDED',
        });
      }
    } else {
      // Missing Attribution
      missingAttributionsFound++;

      if (!recipientUser) {
        unresolvedCount++;
        transactionAuditDetails.push({
          giftTransactionId: tx.id,
          status: 'UNRESOLVED_MISSING_RECIPIENT_USER',
          action: 'FLAGGED_MANUAL_REVIEW',
        });
        continue;
      }

      let targetScope = 'NONE';
      let effectiveAgencyId = null;

      if (isHostActive) {
        if (effectiveHostType === 'AUDIO_HOST') {
          targetScope = 'AUDIO_HOST';
          effectiveAgencyId = hostProfile.agencyId || null;
        } else {
          targetScope = 'LIVE_HOST';
          effectiveAgencyId = null;
        }
      }

      if (executionMode === 'APPLIED') {
        await db.hostTargetAttribution.create({
          data: {
            giftTransactionId: tx.id,
            recipientUserId: recipientUser.id,
            hostProfileId: hostProfile?.id || null,
            agencyId: effectiveAgencyId,
            targetScope,
            cycleIdentifier: cycle.cycleIdentifier,
            cycleStartDate: cycle.cycleStartDate,
            cycleEndDate: cycle.cycleEndDate,
            originalCoinValue: BigInt(tx.gift?.coinValue || 0n),
            giftCategory: tx.gift?.giftCategory || 'POPULAR',
            isLucky: contrib.isLucky,
            quantity: Number(tx.giftCount || 1),
            grossCoins: contrib.grossCoins,
            targetCoins: expectedTargetCoins,
            status: 'RECONCILED',
            reconciledAt: new Date(),
          },
        });
        attributionsCreated++;
      }

      transactionAuditDetails.push({
        giftTransactionId: tx.id,
        recipientUserId: recipientUser.id,
        status: 'MISSING_ATTRIBUTION_RESTORED',
        targetCoins: expectedTargetCoins.toString(),
        targetScope,
        action: executionMode === 'APPLIED' ? 'ATTRIBUTION_CREATED' : 'PROPOSED_CREATION',
      });
    }
  }

  // 5. Compute Host & Agency Totals After Operation
  const hostReconciliationSummaries = [];
  const targetHostsToSummarize = effectiveUserId && txWhere.recipientUserId
    ? [txWhere.recipientUserId]
    : Array.from(affectedHostIds).slice(0, 5);

  for (const hId of targetHostsToSummarize) {
    const progress = await getHostTargetProgress(hId, { date: startDate }, db).catch(() => null);
    if (progress) {
      hostReconciliationSummaries.push({
        userId: hId,
        username: progress.username,
        hostType: progress.hostType,
        achievedCoins: progress.achievedCoins,
        cycleIdentifier: progress.cycle?.cycleIdentifier,
      });
    }
  }

  const agencyReconciliationSummaries = [];
  const targetAgenciesToSummarize = agencyId
    ? [agencyId]
    : Array.from(affectedAgencyIds).slice(0, 5);

  for (const aId of targetAgenciesToSummarize) {
    const agencyProg = await getAgencyTargetProgress(aId, { date: startDate }, db).catch(() => null);
    if (agencyProg) {
      agencyReconciliationSummaries.push({
        agencyId: aId,
        agencyName: agencyProg.agencyName,
        totalTargetCoins: agencyProg.totalTargetCoins,
        cycleIdentifier: agencyProg.cycle?.cycleIdentifier,
      });
    }
  }

  const runStatus = unresolvedCount > 0 ? 'REQUIRES_MANUAL_REVIEW' : 'COMPLETED';

  const summaryReportJson = {
    runIdentifier,
    executionMode,
    targetPeriod,
    hostType: effectiveFilterScope,
    dateRange: {
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
    },
    metrics: {
      transactionsExamined,
      alreadyAttributedCount,
      missingAttributionsFound,
      attributionsCreated,
      discrepanciesFound,
      correctionsApplied,
      unresolvedCount,
    },
    hostSummaries: hostReconciliationSummaries,
    agencySummaries: agencyReconciliationSummaries,
    transactionAuditDetails: transactionAuditDetails.slice(0, 50), // Sample for audit storage
  };

  // 6. Persist TargetReconciliationRun Audit Record
  let savedRun = null;
  try {
    savedRun = await db.targetReconciliationRun.create({
      data: {
        runIdentifier,
        executionMode,
        targetPeriod,
        hostType: effectiveFilterScope,
        targetUserId: effectiveUserId || null,
        agencyId: agencyId || null,
        transactionsExamined,
        alreadyAttributedCount,
        missingAttributionsFound,
        attributionsCreated,
        discrepanciesFound,
        correctionsApplied,
        unresolvedCount,
        status: runStatus,
        summaryReportJson,
        executedByAdminId: adminId,
      },
    });
  } catch (saveErr) {
    console.warn('Could not save TargetReconciliationRun record:', saveErr.message);
  }

  // 7. Audit Log
  await logAudit(
    {
      action: executionMode === 'APPLIED' ? 'TARGET_RECONCILIATION_APPLIED' : 'TARGET_RECONCILIATION_PREVIEW',
      targetEntity: 'TargetReconciliationRun',
      targetEntityId: savedRun?.id || runIdentifier,
      afterStateJson: {
        runIdentifier,
        executionMode,
        targetPeriod,
        transactionsExamined,
        missingAttributionsFound,
        attributionsCreated,
        discrepanciesFound,
        correctionsApplied,
        unresolvedCount,
      },
      reason: `Historical target reconciliation run (${executionMode}) for ${targetPeriod}`,
      adminId,
    },
    db
  );

  return {
    success: true,
    runId: savedRun?.id || runIdentifier,
    runIdentifier,
    executionMode,
    targetPeriod,
    status: runStatus,
    metrics: {
      transactionsExamined,
      alreadyAttributedCount,
      missingAttributionsFound,
      attributionsCreated,
      discrepanciesFound,
      correctionsApplied,
      unresolvedCount,
    },
    affectedHostsCount: affectedHostIds.size,
    affectedAgenciesCount: affectedAgencyIds.size,
    hostSummaries: hostReconciliationSummaries,
    agencySummaries: agencyReconciliationSummaries,
    sampleAuditDetails: transactionAuditDetails.slice(0, 20),
  };
}

/**
 * Lists past target reconciliation runs for admin audit & review.
 *
 * @param {Object} [options]
 * @param {number} [options.page=1]
 * @param {number} [options.limit=20]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getTargetReconciliationRuns(
  { page = 1, limit = 20 } = {},
  db = prisma
) {
  const skip = (Number(page) - 1) * Number(limit);
  const [runs, totalCount] = await Promise.all([
    db.targetReconciliationRun.findMany({
      skip,
      take: Number(limit),
      orderBy: { createdAt: 'desc' },
    }),
    db.targetReconciliationRun.count(),
  ]);

  return {
    runs,
    pagination: {
      page: Number(page),
      limit: Number(limit),
      totalCount,
      totalPages: Math.ceil(totalCount / Number(limit)) || 1,
    },
  };
}

export default {
  isLuckyGift,
  calculateGiftTargetContribution,
  getTargetCycle,
  getTargetTiers,
  resolveUserAndHost,
  recordGiftAttribution,
  recordGiftReversal,
  getHostTargetProgress,
  getAgencyTargetProgress,
  reconcileHistoricalTargets,
  getTargetReconciliationRuns,
};
