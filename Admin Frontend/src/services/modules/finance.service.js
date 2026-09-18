// ============================================================
// ZeParty Admin Portal — Finance Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getMasterLedger(params = {}) {
  const res = await apiClient.get('/v1/finance/transactions', { params });
  return res.data;
}

export async function getFinanceDashboard() {
  const [walletStatsRes, transactionsRes] = await Promise.allSettled([
    apiClient.get('/v1/wallet/stats'),
    apiClient.get('/v1/finance/transactions', { params: { limit: 10 } }),
  ]);

  const stats = walletStatsRes.status === 'fulfilled' ? walletStatsRes.value.data?.data || {} : {};
  const txList = transactionsRes.status === 'fulfilled' ? transactionsRes.value.data?.data || [] : [];

  return {
    totalRevenueUSD: stats.totalRechargedUSD || 0,
    totalWithdrawnUSD: stats.totalWithdrawnUSD || 0,
    netPlatformEarningsUSD: (stats.totalRechargedUSD || 0) - (stats.totalWithdrawnUSD || 0),
    totalCoinsInCirculation: stats.totalCoins || 0,
    totalDiamondsInCirculation: stats.totalDiamonds || 0,
    recentTransactions: txList,
  };
}

export async function getRevenueChart() {
  // Pull transactions to compute daily aggregates if needed, or structured chart
  const res = await apiClient.get('/v1/finance/transactions', { params: { limit: 100 } });
  const items = res.data?.data || [];
  
  // Aggregate by date
  const dateMap = {};
  items.forEach(item => {
    const d = item.createdAt ? new Date(item.createdAt).toISOString().split('T')[0] : 'Today';
    if (!dateMap[d]) dateMap[d] = { date: d, revenue: 0, withdrawals: 0 };
    if (item.type === 'RECHARGE') dateMap[d].revenue += Number(item.amount || 0);
    if (item.type === 'WITHDRAWAL') dateMap[d].withdrawals += Number(item.amount || 0);
  });

  return Object.values(dateMap);
}

export async function getSettlements(params = {}) {
  const res = await apiClient.get('/v1/admin/settlements/records', { params });
  return res.data?.data || [];
}

export async function updateSettlementStatus(id, status) {
  if (status === 'APPROVED') {
    const res = await apiClient.post(`/v1/admin/settlements/records/${id}/approve`);
    return res.data;
  } else if (status === 'PAID') {
    const res = await apiClient.post(`/v1/admin/settlements/records/${id}/pay`);
    return res.data;
  }
  return { success: true };
}

export async function getSettlementPeriods(params = {}) {
  const res = await apiClient.get('/v1/admin/settlements/periods', { params });
  return res.data?.data || [];
}

export async function calculateSettlementPeriod(payload) {
  const res = await apiClient.post('/v1/admin/settlements/calculate', payload);
  return res.data;
}

export default {
  getMasterLedger,
  getFinanceDashboard,
  getRevenueChart,
  getSettlements,
  updateSettlementStatus,
  getSettlementPeriods,
  calculateSettlementPeriod,
};
