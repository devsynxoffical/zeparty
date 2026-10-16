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
        targetEntity: targetEntity || 'ExchangeTransferControl',
        targetEntityId: targetEntityId || 'GLOBAL',
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in exchangeTransfer.service:', err.message);
  }
}

// 15 days in milliseconds
const FIFTEEN_DAYS_MS = 15 * 24 * 60 * 60 * 1000;

// Master In-Memory & Database-Backed State
let configState = {
  version: 'v1.0.0',
  exchangeStatus: 'PROHIBITED', // Coins ↔ Diamonds exchange is strictly prohibited per Bug 21 product rule
  exchangeOffAt: null,
  exchangeAutoEnableAt: null,
  globalExchangeRate: 0, // Prohibited
  
  transferStatus: 'ON', // 'ON' | 'OFF'
  transferOffAt: null,
  transferAutoEnableAt: null,
  globalTransferRate: 0.0001, // 10,000 Diamonds -> $1 USD
  globalTransferFee: 0.0,
  
  eligibleCoinSellersOnly: true,
  requireCountryMatch: false,
  pendingRequestPolicy: 'LOCK_RATE_AT_CONFIRMATION', // 'LOCK_RATE_AT_CONFIRMATION' | 'PAUSE_REVIEW' | 'AUTO_REFUND'
  
  countryOverrides: [
    {
      id: 'ov_pk',
      countryCode: 'PK',
      countryName: 'Pakistan',
      exchangeRate: 0,
      transferRate: 0.0001,
      fee: 0.0,
      exchangeStatus: 'PROHIBITED',
      transferStatus: 'ON',
      eligibleSellersOnly: true,
      requireCountryMatch: true,
      status: 'ACTIVE',
      updatedAt: new Date().toISOString(),
    },
    {
      id: 'ov_sa',
      countryCode: 'SA',
      countryName: 'Saudi Arabia',
      exchangeRate: 0,
      transferRate: 0.000105,
      fee: 0.0,
      exchangeStatus: 'PROHIBITED',
      transferStatus: 'ON',
      eligibleSellersOnly: true,
      requireCountryMatch: true,
      status: 'ACTIVE',
      updatedAt: new Date().toISOString(),
    },
    {
      id: 'ov_ae',
      countryCode: 'AE',
      countryName: 'United Arab Emirates',
      exchangeRate: 0,
      transferRate: 0.000102,
      fee: 0.0,
      exchangeStatus: 'PROHIBITED',
      transferStatus: 'ON',
      eligibleSellersOnly: true,
      requireCountryMatch: true,
      status: 'ACTIVE',
      updatedAt: new Date().toISOString(),
    }
  ],
  
  history: [
    {
      version: 'v1.0.0',
      timestamp: new Date().toISOString(),
      adminName: 'Super Admin',
      action: 'INITIAL_CONFIGURATION',
      reason: 'Base standard exchange & diamond transfer policy established.',
    }
  ]
};

// Periodic or On-Demand 15-Day Auto-Return Sweep
export function checkAutoReturn() {
  const now = Date.now();
  let changed = false;

  // Note: Coin ↔ Diamond Exchange is permanently PROHIBITED. No auto-return exists for exchange.

  // Auto-Return Diamond Transfer if 15 days elapsed
  if (configState.transferStatus === 'OFF' && configState.transferAutoEnableAt) {
    if (now >= new Date(configState.transferAutoEnableAt).getTime()) {
      configState.transferStatus = 'ON';
      configState.transferOffAt = null;
      configState.transferAutoEnableAt = null;
      changed = true;
      console.log('🔄 [ExchangeTransfer] Diamond Transfer automatically restored to ON after 15 complete days.');
    }
  }

  return changed;
}

export async function getAdminControlState() {
  checkAutoReturn();

  const now = Date.now();

  let transferRemainingMs = 0;
  if (configState.transferStatus === 'OFF' && configState.transferAutoEnableAt) {
    transferRemainingMs = Math.max(0, new Date(configState.transferAutoEnableAt).getTime() - now);
  }

  return {
    ...configState,
    exchangeCountdown: {
      isOff: true,
      prohibited: true,
      offAt: null,
      autoEnableAt: null,
      remainingMs: 0,
      remainingDays: '0.00',
    },
    transferCountdown: {
      isOff: configState.transferStatus === 'OFF',
      offAt: configState.transferOffAt,
      autoEnableAt: configState.transferAutoEnableAt,
      remainingMs: transferRemainingMs,
      remainingDays: (transferRemainingMs / (24 * 60 * 60 * 1000)).toFixed(2),
    },
  };
}

export async function previewRateCalculation({ type = 'EXCHANGE', amount = 1000, countryCode = 'GLOBAL' }) {
  checkAutoReturn();

  const numAmount = Number(amount);
  if (isNaN(numAmount) || numAmount <= 0) {
    const error = new Error('Amount must be a positive number greater than 0');
    error.statusCode = 400;
    throw error;
  }

  const normalizedType = String(type || '').toUpperCase();
  if (
    normalizedType === 'EXCHANGE' ||
    normalizedType === 'COINS_TO_DIAMONDS' ||
    normalizedType === 'DIAMONDS_TO_COINS' ||
    normalizedType.includes('COIN')
  ) {
    const error = new Error('Coin and Diamond exchange is strictly prohibited. Diamonds are for display within ZeParty only.');
    error.statusCode = 400;
    error.code = 'EXCHANGE_PROHIBITED';
    throw error;
  }

  const normalizedCountry = (countryCode || 'GLOBAL').toUpperCase();
  
  // Check Worldwide Master Status for Transfer
  const isWorldwideOff = configState.transferStatus === 'OFF';
  
  // Resolve Country Override
  const override = configState.countryOverrides.find(
    (ov) => ov.countryCode.toUpperCase() === normalizedCountry && ov.status === 'ACTIVE'
  );

  let activeRate = 1.0;
  let activeFee = 0.0;
  let appliedScope = 'GLOBAL';
  let appliedRuleId = 'GLOBAL_DEFAULT';

  // TRANSFER
  if (override && override.transferRate > 0) {
    activeRate = Number(override.transferRate);
    activeFee = Number(override.fee || 0);
    appliedScope = override.countryCode;
    appliedRuleId = override.id;
  } else {
    activeRate = Number(configState.globalTransferRate);
    activeFee = Number(configState.globalTransferFee || 0);
  }

  const rawConverted = numAmount * activeRate;
  const finalAmount = Math.max(0, rawConverted - activeFee);

  return {
    type,
    inputAmount: numAmount,
    activeRate,
    fee: activeFee,
    convertedOutput: Number(rawConverted.toFixed(4)),
    finalAmount: Number(finalAmount.toFixed(4)),
    appliedScope,
    appliedRuleId,
    isWorldwideOff,
    isFeatureAvailable: !isWorldwideOff,
    payoutUnit: 'USD_VALUE',
  };
}

export async function publishConfiguration(updates, { adminId, adminName, ipAddress } = {}) {
  checkAutoReturn();

  // Strictly disallow enabling Coin <-> Diamond exchange
  if (updates.exchangeStatus === 'ON') {
    const error = new Error('Activating Coin and Diamond exchange is prohibited. Diamonds are for display within ZeParty only.');
    error.statusCode = 400;
    error.code = 'EXCHANGE_PROHIBITED';
    throw error;
  }

  const beforeState = JSON.parse(JSON.stringify(configState));
  const now = new Date();

  // Exchange is permanently prohibited
  configState.exchangeStatus = 'PROHIBITED';
  configState.globalExchangeRate = 0;
  configState.exchangeOffAt = null;
  configState.exchangeAutoEnableAt = null;

  // Validate Transfer Rate
  if (updates.globalTransferRate !== undefined) {
    const rate = Number(updates.globalTransferRate);
    if (isNaN(rate) || rate <= 0) {
      const error = new Error('Transfer rate must be a valid positive number');
      error.statusCode = 400;
      throw error;
    }
    configState.globalTransferRate = rate;
  }

  if (updates.globalTransferFee !== undefined) {
    configState.globalTransferFee = Math.max(0, Number(updates.globalTransferFee));
  }

  // Handle Diamond Transfer ON/OFF with 15-day rule
  if (updates.transferStatus !== undefined) {
    const newStatus = updates.transferStatus === 'OFF' ? 'OFF' : 'ON';
    if (newStatus === 'OFF' && configState.transferStatus !== 'OFF') {
      configState.transferStatus = 'OFF';
      configState.transferOffAt = now.toISOString();
      configState.transferAutoEnableAt = new Date(now.getTime() + FIFTEEN_DAYS_MS).toISOString();
    } else if (newStatus === 'ON') {
      configState.transferStatus = 'ON';
      configState.transferOffAt = null;
      configState.transferAutoEnableAt = null;
    }
  }

  if (updates.eligibleCoinSellersOnly !== undefined) {
    configState.eligibleCoinSellersOnly = Boolean(updates.eligibleCoinSellersOnly);
  }

  if (updates.requireCountryMatch !== undefined) {
    configState.requireCountryMatch = Boolean(updates.requireCountryMatch);
  }

  if (updates.pendingRequestPolicy !== undefined) {
    configState.pendingRequestPolicy = updates.pendingRequestPolicy;
  }

  // Handle Country Overrides
  if (Array.isArray(updates.countryOverrides)) {
    configState.countryOverrides = updates.countryOverrides.map((ov) => ({
      id: ov.id || `ov_${(ov.countryCode || 'XX').toLowerCase()}_${Date.now()}`,
      countryCode: (ov.countryCode || 'XX').toUpperCase(),
      countryName: ov.countryName || ov.countryCode,
      exchangeRate: 0,
      transferRate: Number(ov.transferRate) || configState.globalTransferRate,
      fee: Number(ov.fee || 0),
      exchangeStatus: 'PROHIBITED',
      transferStatus: ov.transferStatus || 'ON',
      eligibleSellersOnly: ov.eligibleSellersOnly !== undefined ? Boolean(ov.eligibleSellersOnly) : true,
      requireCountryMatch: ov.requireCountryMatch !== undefined ? Boolean(ov.requireCountryMatch) : false,
      status: ov.status || 'ACTIVE',
      updatedAt: now.toISOString(),
    }));
  }

  // Generate new version tag
  const verParts = (configState.version || 'v1.0.0').replace('v', '').split('.').map(Number);
  verParts[2] = (verParts[2] || 0) + 1;
  configState.version = `v${verParts.join('.')}`;

  const historyEntry = {
    version: configState.version,
    timestamp: now.toISOString(),
    adminName: adminName || 'System Administrator',
    action: updates.action || 'PUBLISH_CONFIGURATION',
    reason: updates.reason || 'Exchange & Transfer configuration published by Administrator',
    snapshot: JSON.parse(JSON.stringify(configState)),
  };

  configState.history.unshift(historyEntry);

  await logAudit({
    adminId,
    adminName,
    action: 'EXCHANGE_TRANSFER_CONFIG_PUBLISHED',
    targetEntity: 'ExchangeTransferPolicy',
    targetEntityId: configState.version,
    beforeStateJson: beforeState,
    afterStateJson: configState,
    reason: updates.reason || 'Published new diamond transfer rates and settings',
    ipAddress,
  });

  return getAdminControlState();
}

export async function rollbackConfiguration(targetVersion, { adminId, adminName, ipAddress, reason } = {}) {
  const entry = configState.history.find((h) => h.version === targetVersion);
  if (!entry) {
    const error = new Error(`Configuration version ${targetVersion} not found for rollback`);
    error.statusCode = 404;
    throw error;
  }

  const snapshot = entry.snapshot || {
    globalTransferRate: 0.0001,
    globalTransferFee: 0.0,
    transferStatus: 'ON',
    countryOverrides: configState.countryOverrides,
  };

  const beforeState = JSON.parse(JSON.stringify(configState));
  
  // Restore snapshot properties but strictly enforce exchange prohibition
  configState.globalExchangeRate = 0;
  configState.globalTransferRate = snapshot.globalTransferRate;
  configState.globalTransferFee = snapshot.globalTransferFee;
  configState.exchangeStatus = 'PROHIBITED';
  configState.exchangeOffAt = null;
  configState.exchangeAutoEnableAt = null;
  configState.transferStatus = snapshot.transferStatus;
  configState.countryOverrides = (snapshot.countryOverrides || []).map((ov) => ({
    ...ov,
    exchangeRate: 0,
    exchangeStatus: 'PROHIBITED',
  }));
  
  // Version bump
  const verParts = (configState.version || 'v1.0.0').replace('v', '').split('.').map(Number);
  verParts[1] = (verParts[1] || 0) + 1;
  verParts[2] = 0;
  configState.version = `v${verParts.join('.')}`;

  const rollbackEntry = {
    version: configState.version,
    timestamp: new Date().toISOString(),
    adminName: adminName || 'System Administrator',
    action: 'ROLLBACK_CONFIGURATION',
    reason: reason || `Rolled back to configuration version ${targetVersion}`,
  };

  configState.history.unshift(rollbackEntry);

  await logAudit({
    adminId,
    adminName,
    action: 'EXCHANGE_TRANSFER_CONFIG_ROLLBACK',
    targetEntity: 'ExchangeTransferPolicy',
    targetEntityId: configState.version,
    beforeStateJson: beforeState,
    afterStateJson: configState,
    reason: reason || `Rolled back to version ${targetVersion}`,
    ipAddress,
  });

  return getAdminControlState();
}

export async function getUserExchangeTransferStatus({ userCountryCode = 'GLOBAL', userId } = {}) {
  checkAutoReturn();

  const normalizedCountry = (userCountryCode || 'GLOBAL').toUpperCase();
  
  // Worldwide Master Check for Transfer
  const isTransferWorldwideOff = configState.transferStatus === 'OFF';

  // Country Override
  const override = configState.countryOverrides.find(
    (ov) => ov.countryCode.toUpperCase() === normalizedCountry && ov.status === 'ACTIVE'
  );

  const transferAvailable = !isTransferWorldwideOff && (!override || override.transferStatus === 'ON');
  const transferRate = (override && override.transferRate > 0) ? override.transferRate : configState.globalTransferRate;
  const transferFee = (override && override.fee !== undefined) ? override.fee : configState.globalTransferFee;

  return {
    exchange: {
      isAvailable: false,
      rate: 0,
      unit: 'N/A',
      minDiamonds: 0,
      hiddenWorldwide: true,
      prohibited: true,
      message: 'Coin and Diamond exchange is strictly prohibited. Diamonds are for display within ZeParty only.',
    },
    transfer: {
      isAvailable: transferAvailable,
      rate: transferRate,
      fee: transferFee,
      unit: 'USD reference per 1 Diamond',
      minDiamonds: 40000,
      hiddenWorldwide: isTransferWorldwideOff,
      requireCountryMatch: override ? override.requireCountryMatch : configState.requireCountryMatch,
      eligibleSellersOnly: true,
    },
    userCountry: normalizedCountry,
  };
}

export default {
  getAdminControlState,
  previewRateCalculation,
  publishConfiguration,
  rollbackConfiguration,
  getUserExchangeTransferStatus,
  checkAutoReturn,
};
