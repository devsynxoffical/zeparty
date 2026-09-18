// ============================================================
// ZeParty Admin Portal — Merchants Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getMerchants(params = {}) {
  const res = await apiClient.get('/v1/admin/merchants', { params });
  const items = res.data?.data || [];
  return items.map((m) => {
    const allocation = Number(m.monthlyQuotaCoins ?? m.coinAllocation ?? m.user?.wallet?.sellerBalanceCoins ?? 25200000);
    const sellerCoins = Number(m.user?.wallet?.sellerBalanceCoins ?? m.monthlyQuotaCoins ?? allocation);
    return {
      id: m.id,
      userRef: m.userId || m.user?.id,
      merchantName: m.companyName || m.merchantName || m.name || m.user?.profile?.displayName || m.user?.username || m.id,
      contactPerson: m.contactPerson || m.user?.profile?.displayName || m.companyName || 'Merchant Representative',
      email: m.email || m.user?.email || 'merchant@zeparty.io',
      status: (m.status || 'ACTIVE').toLowerCase(),
      packagePriceUSD: Number(m.packagePriceUSD || 3000),
      coinRatio: Number(m.coinRatio || 8400),
      totalCoins: allocation,
      coinAllocation: allocation,
      sellerBalanceCoins: sellerCoins,
      targetUSD: Number(m.targetUSD || 1000),
      salesThisMonthUSD: Number(m.totalSpentUSD || m.salesThisMonthUSD || 0),
      workingPeriodDays: Number(m.workingPeriodDays || 30),
      joinedAt: m.createdAt,
      country: m.country || m.user?.countryCode || 'US',
      paymentMethods: m.paymentMethods || ['Bank Wire Transfer', 'USDT (TRC20)'],
      dailySettlementLimitUSD: Number(m.dailySettlementLimitUSD || 10000),
      linkedToWithdrawalSettlement: Boolean(m.linkedToWithdrawalSettlement),
      minPortalAmountUSD: Number(m.minPortalAmountUSD || 300),
      history: m.history || [],
      user: m.user,
    };
  });
}

export async function getMerchantById(id) {
  const res = await apiClient.get(`/v1/admin/merchants/${id}`);
  return res.data?.data;
}

export async function createMerchant(payload) {
  const res = await apiClient.post('/v1/admin/merchants', payload);
  return res.data?.data;
}

export async function updateMerchant(id, payload) {
  const res = await apiClient.put(`/v1/admin/merchants/${id}`, payload);
  return res.data?.data;
}

export async function adjustMerchantBalance(id, payload) {
  const res = await apiClient.post(`/v1/admin/merchants/${id}/adjust-balance`, payload);
  return res.data?.data;
}

export async function deleteMerchant(id, reason = '') {
  const res = await apiClient.delete(`/v1/admin/merchants/${id}`, {
    data: { reason },
  });
  return res.data;
}

export default {
  getMerchants,
  getMerchantById,
  createMerchant,
  updateMerchant,
  adjustMerchantBalance,
  deleteMerchant,
};
