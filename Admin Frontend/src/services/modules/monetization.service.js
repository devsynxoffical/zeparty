// ============================================================
// ZeParty Admin Portal — Monetization Service (JavaScript)
// ============================================================

import apiClient from '../api';

// ---- Recharge Plans ----
export async function getRechargePlans() {
  const res = await apiClient.get('/v1/finance/recharge/plans');
  const items = res.data?.data || [];
  return items.map((p) => ({
    id: p.id,
    name: p.badgeText ? `${p.coinAmount} Coins (${p.badgeText})` : `${p.coinAmount} Coins Package`,
    coins: Number(p.coinAmount),
    price: Number(p.priceUSD),
    bonus: Number(p.bonusCoins || 0),
    badge: p.badgeText || null,
    targetCountry: 'GLOBAL',
    featured: Boolean(p.badgeText),
    active: Boolean(p.isActive),
    createdAt: p.createdAt,
  }));
}

export async function createRechargePlan(planData) {
  const res = await apiClient.post('/v1/finance/recharge/plans', {
    coinAmount: Number(planData.coins),
    priceUSD: Number(planData.price || planData.priceUSD),
    bonusCoins: Number(planData.bonus || planData.bonusCoins || 0),
    badgeText: planData.badge || planData.badgeText || (planData.featured ? 'POPULAR' : null),
    isActive: planData.active !== undefined ? Boolean(planData.active) : true,
  });
  return res.data?.data;
}

export async function updateRechargePlan(id, planData) {
  const updatePayload = {};
  if (planData.coins !== undefined) updatePayload.coinAmount = Number(planData.coins);
  if (planData.price !== undefined || planData.priceUSD !== undefined) {
    updatePayload.priceUSD = Number(planData.price || planData.priceUSD);
  }
  if (planData.bonus !== undefined || planData.bonusCoins !== undefined) {
    updatePayload.bonusCoins = Number(planData.bonus || planData.bonusCoins);
  }
  if (planData.badge !== undefined || planData.badgeText !== undefined) {
    updatePayload.badgeText = planData.badge || planData.badgeText;
  }
  if (planData.active !== undefined) updatePayload.isActive = Boolean(planData.active);

  const res = await apiClient.patch(`/v1/finance/recharge/plans/${id}`, updatePayload);
  return res.data?.data;
}

export async function toggleRechargePlan(id, currentActive) {
  const res = await apiClient.patch(`/v1/finance/recharge/plans/${id}`, {
    isActive: !currentActive,
  });
  return res.data?.data;
}

export async function deleteRechargePlan(id) {
  const res = await apiClient.delete(`/v1/finance/recharge/plans/${id}`);
  return res.data;
}

// ---- Offline Recharge ----
export async function getOfflineRechargeRequests(params = {}) {
  const res = await apiClient.get('/v1/finance/recharge/offline', { params });
  const items = res.data?.data || [];
  return items.map((req) => ({
    id: req.id,
    userId: req.userId,
    username: req.user?.username || req.userId,
    country: 'GLOBAL',
    amountUSD: Number(req.amountUSD || req.amount || 0),
    amountCoins: Number(req.coinAmount || req.coins || 0),
    paymentMethod: req.paymentMethod || 'Manual Bank Wire',
    referenceNumber: req.referenceId || req.receiptRef || `REF-${req.id.slice(0, 8)}`,
    receiptUrl: req.receiptUrl || null,
    status: req.status?.toLowerCase() || 'pending',
    assignedEntity: req.assignedSeller || 'Platform Vault',
    sellerCommissionPct: req.sellerCommission ? Number(req.sellerCommission) : null,
    createdAt: req.createdAt,
    reviewedAt: req.reviewedAt || req.updatedAt,
    rejectReason: req.rejectReason,
  }));
}

export async function approveOfflineRecharge(id) {
  const res = await apiClient.post(`/v1/finance/recharge/offline/${id}/approve`);
  return res.data;
}

export async function rejectOfflineRecharge(id, reason) {
  const res = await apiClient.post(`/v1/finance/recharge/offline/${id}/reject`, {
    reason: reason || 'Recharge request rejected by administrator',
  });
  return res.data;
}

// ---- Withdrawals ----
export async function getWithdrawals(params = {}) {
  const res = await apiClient.get('/v1/finance/withdrawals', { params });
  const items = res.data?.data || [];
  return items.map((w) => ({
    id: w.id,
    hostId: w.userId,
    hostName: w.user?.username || w.user?.profile?.displayName || w.userId,
    agencyName: w.agencyName || 'Independent Host',
    diamondsAmount: Number(w.diamondAmount || w.diamonds || 0),
    amountUSD: Number(w.amountUSD || w.amount || 0),
    payoutMethod: w.payoutMethod || 'Bank Wire Transfer',
    accountDetails: w.accountDetails || 'Default Payout Account',
    status: w.status?.toLowerCase() || 'pending',
    requestedAt: w.createdAt,
    processedAt: w.processedAt || w.updatedAt,
    rejectReason: w.rejectReason,
  }));
}

export async function approveWithdrawal(id) {
  const res = await apiClient.post(`/v1/finance/withdrawals/${id}/approve`);
  return res.data;
}

export async function rejectWithdrawal(id, reason) {
  const res = await apiClient.post(`/v1/finance/withdrawals/${id}/reject`, {
    reason: reason || 'Withdrawal rejected by administrator',
  });
  return res.data;
}

// ---- Coin Refunds & Chargebacks ----
export async function getCoinRefunds(params = {}) {
  const res = await apiClient.get('/v1/finance/refunds/coins', { params });
  return res.data?.data || [];
}

export async function processCoinRefund(id) {
  const res = await apiClient.post(`/v1/finance/refunds/coins/${id}/process`);
  return res.data;
}

export async function rejectCoinRefund(id, reason) {
  const res = await apiClient.post(`/v1/finance/refunds/coins/${id}/reject`, {
    reason: reason || 'Refund rejected by administrator',
  });
  return res.data;
}

export async function getChargebacks(params = {}) {
  const res = await apiClient.get('/v1/admin/chargebacks', { params });
  return res.data?.data || [];
}

export async function resolveChargeback(id, payload) {
  const res = await apiClient.post(`/v1/admin/chargebacks/${id}/resolve`, payload);
  return res.data;
}

export default {
  getRechargePlans,
  createRechargePlan,
  updateRechargePlan,
  toggleRechargePlan,
  deleteRechargePlan,
  getOfflineRechargeRequests,
  approveOfflineRecharge,
  rejectOfflineRecharge,
  getWithdrawals,
  approveWithdrawal,
  rejectWithdrawal,
  getCoinRefunds,
  processCoinRefund,
  rejectCoinRefund,
  getChargebacks,
  resolveChargeback,
};
