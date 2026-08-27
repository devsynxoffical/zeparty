// ============================================================
// ZeParty Admin Portal — Monetization Service (JavaScript)
// ============================================================

import {
  MOCK_RECHARGE_PLANS,
  MOCK_OFFLINE_RECHARGE,
  MOCK_WITHDRAWALS,
} from '../../mocks/monetization.mock';

let plansState = [...MOCK_RECHARGE_PLANS];
let offlineState = [...MOCK_OFFLINE_RECHARGE];
let withdrawalsState = [...MOCK_WITHDRAWALS];

// ---- Recharge Plans ----
export async function getRechargePlans() {
  await new Promise((res) => setTimeout(res, 200));
  return [...plansState];
}

export async function createRechargePlan(planData) {
  await new Promise((res) => setTimeout(res, 300));
  const newPlan = {
    id: 'plan-' + Date.now(),
    coins: Number(planData.coins),
    bonusCoins: Number(planData.bonusCoins || 0),
    priceUSD: Number(planData.priceUSD),
    popular: Boolean(planData.popular),
    badge: planData.badge || null,
    active: true,
  };
  plansState = [newPlan, ...plansState];
  return newPlan;
}

export async function updateRechargePlan(id, planData) {
  await new Promise((res) => setTimeout(res, 300));
  plansState = plansState.map((p) =>
    p.id === id ? { ...p, ...planData } : p
  );
  return { success: true };
}

export async function toggleRechargePlan(id) {
  await new Promise((res) => setTimeout(res, 250));
  plansState = plansState.map((p) =>
    p.id === id ? { ...p, active: !p.active } : p
  );
  return { success: true };
}

// ---- Offline Recharge ----
export async function getOfflineRechargeRequests() {
  await new Promise((res) => setTimeout(res, 200));
  return [...offlineState];
}

export async function approveOfflineRecharge(id) {
  await new Promise((res) => setTimeout(res, 300));
  offlineState = offlineState.map((req) =>
    req.id === id ? { ...req, status: 'approved', reviewedAt: new Date().toISOString() } : req
  );
  return { success: true };
}

export async function rejectOfflineRecharge(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  offlineState = offlineState.map((req) =>
    req.id === id ? { ...req, status: 'rejected', rejectReason: reason, reviewedAt: new Date().toISOString() } : req
  );
  return { success: true };
}

// ---- Withdrawals ----
export async function getWithdrawals() {
  await new Promise((res) => setTimeout(res, 200));
  return [...withdrawalsState];
}

export async function approveWithdrawal(id) {
  await new Promise((res) => setTimeout(res, 300));
  withdrawalsState = withdrawalsState.map((w) =>
    w.id === id ? { ...w, status: 'approved', processedAt: new Date().toISOString() } : w
  );
  return { success: true };
}

export async function rejectWithdrawal(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  withdrawalsState = withdrawalsState.map((w) =>
    w.id === id ? { ...w, status: 'rejected', rejectReason: reason, processedAt: new Date().toISOString() } : w
  );
  return { success: true };
}
