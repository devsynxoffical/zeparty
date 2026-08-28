// ============================================================
// ZeParty Admin Portal — Transfer Rate Service (JavaScript)
// ============================================================

import { MOCK_TRANSFER_RATES } from '../../mocks/transferRates.mock';

let transferRatesState = [...MOCK_TRANSFER_RATES];

export async function getTransferRates() {
  await new Promise((res) => setTimeout(res, 200));
  return [...transferRatesState];
}

export async function updateTransferRate(id, updates) {
  await new Promise((res) => setTimeout(res, 300));
  transferRatesState = transferRatesState.map((t) =>
    t.id === id ? { ...t, ...updates, updatedAt: new Date().toISOString() } : t
  );
  return { success: true };
}

export async function publishTransferRate(id) {
  await new Promise((res) => setTimeout(res, 300));
  transferRatesState = transferRatesState.map((t) => {
    if (t.id === id) {
      const oldRate = t.currentRatePercent;
      const newRateVal = t.proposedRatePercent || t.currentRatePercent;
      const newHistoryItem = {
        version: t.version.replace('-draft', ''),
        ratePercent: oldRate,
        effectiveDate: new Date().toISOString().split('T')[0],
        changedBy: 'Super Admin',
        notes: `Updated transfer fee from ${oldRate}% to ${newRateVal}%`
      };
      return {
        ...t,
        currentRatePercent: newRateVal,
        status: 'ACTIVE',
        version: t.version.replace('-draft', ''),
        history: [newHistoryItem, ...(t.history || [])],
        updatedAt: new Date().toISOString()
      };
    }
    return t;
  });
  return { success: true };
}

export async function rollbackTransferRate(id, targetVersion) {
  await new Promise((res) => setTimeout(res, 350));
  transferRatesState = transferRatesState.map((t) => {
    if (t.id === id) {
      const historical = (t.history || []).find((h) => h.version === targetVersion);
      if (!historical) throw new Error(`Version ${targetVersion} not found in history`);

      const rollbackRecord = {
        version: `v${targetVersion}-rollback`,
        ratePercent: t.currentRatePercent,
        effectiveDate: new Date().toISOString().split('T')[0],
        changedBy: 'Super Admin',
        notes: `Rolled back transfer fee to ${targetVersion} (${historical.ratePercent}%)`
      };

      return {
        ...t,
        currentRatePercent: historical.ratePercent,
        proposedRatePercent: historical.ratePercent,
        status: 'ROLLED_BACK',
        history: [rollbackRecord, ...(t.history || [])],
        updatedAt: new Date().toISOString()
      };
    }
    return t;
  });
  return { success: true };
}
