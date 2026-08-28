// ============================================================
// ZeParty Admin Portal — Exchange Rate Service (JavaScript)
// ============================================================

import { MOCK_EXCHANGE_RATES } from '../../mocks/exchangeRates.mock';

let exchangeRatesState = [...MOCK_EXCHANGE_RATES];

export async function getExchangeRates() {
  await new Promise((res) => setTimeout(res, 200));
  return [...exchangeRatesState];
}

export async function createRateDraft(payload) {
  await new Promise((res) => setTimeout(res, 300));
  const newRate = {
    id: `ex-${Date.now().toString().slice(-4)}`,
    status: 'DRAFT',
    version: `v${Math.floor(3 + Math.random() * 2)}.${Math.floor(Math.random() * 9)}.0-draft`,
    effectiveDate: payload.effectiveDate || new Date().toISOString(),
    createdBy: 'Admin Operator',
    approvedBy: 'Pending Approval',
    updatedAt: new Date().toISOString(),
    history: [],
    ...payload
  };
  exchangeRatesState = [newRate, ...exchangeRatesState];
  return newRate;
}

export async function updateRate(id, updates) {
  await new Promise((res) => setTimeout(res, 300));
  exchangeRatesState = exchangeRatesState.map((r) =>
    r.id === id ? { ...r, ...updates, updatedAt: new Date().toISOString() } : r
  );
  return { success: true };
}

export async function approveRate(id, approverName = 'Finance Director') {
  await new Promise((res) => setTimeout(res, 300));
  exchangeRatesState = exchangeRatesState.map((r) =>
    r.id === id
      ? {
          ...r,
          status: 'SCHEDULED',
          approvedBy: approverName,
          updatedAt: new Date().toISOString()
        }
      : r
  );
  return { success: true };
}

export async function publishRate(id) {
  await new Promise((res) => setTimeout(res, 300));
  exchangeRatesState = exchangeRatesState.map((r) => {
    if (r.id === id) {
      const oldRate = r.currentRate;
      const newRateVal = r.proposedRate || r.currentRate;
      const newHistoryItem = {
        version: r.version.replace('-draft', ''),
        rate: oldRate,
        effectiveDate: new Date().toISOString().split('T')[0],
        changedBy: 'Super Admin',
        notes: `Updated rate from ${oldRate} to ${newRateVal}`
      };
      return {
        ...r,
        currentRate: newRateVal,
        status: 'ACTIVE',
        version: r.version.replace('-draft', ''),
        history: [newHistoryItem, ...(r.history || [])],
        updatedAt: new Date().toISOString()
      };
    }
    return r;
  });
  return { success: true };
}

export async function rollbackRate(id, targetVersion) {
  await new Promise((res) => setTimeout(res, 350));
  exchangeRatesState = exchangeRatesState.map((r) => {
    if (r.id === id) {
      const historical = (r.history || []).find((h) => h.version === targetVersion);
      if (!historical) throw new Error(`Version ${targetVersion} not found in history`);

      const rollbackRecord = {
        version: `v${targetVersion}-rollback`,
        rate: r.currentRate,
        effectiveDate: new Date().toISOString().split('T')[0],
        changedBy: 'Super Admin',
        notes: `Rolled back to version ${targetVersion} (rate: ${historical.rate})`
      };

      return {
        ...r,
        currentRate: historical.rate,
        proposedRate: historical.rate,
        status: 'ROLLED_BACK',
        history: [rollbackRecord, ...(r.history || [])],
        updatedAt: new Date().toISOString()
      };
    }
    return r;
  });
  return { success: true };
}
