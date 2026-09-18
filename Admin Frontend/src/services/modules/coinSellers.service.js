// ============================================================
// ZeParty Admin Portal — Coin Sellers Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getCoinSellers(params = {}) {
  const res = await apiClient.get('/v1/admin/sellers', { params });
  const items = res.data?.data || [];
  return items.map((s) => ({
    id: s.id,
    name: s.businessName || s.user?.username || s.id,
    contactEmail: s.user?.email || 'seller@zeparty.io',
    allocatedQuota: Number(s.resellerBalanceCoins || s.allocatedQuota || s.user?.wallet?.sellerBalanceCoins || 0),
    soldCoins: Number(s.soldCoins || 0),
    commissionPct: Number(s.profitMarginPercent || s.commissionPercent || 10.0),
    status: (s.sellerStatus || s.status || 'ACTIVE').toLowerCase(),
    userId: s.userId,
    username: s.user?.username ? `@${s.user.username}` : `@${s.id?.slice(0, 6)}`,
    country: s.user?.countryCode || 'US',
    resellerBalanceCoins: Number(s.resellerBalanceCoins || s.user?.wallet?.sellerBalanceCoins || 0),
    creditLimit: Number(s.creditLimitUSD || 10000),
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  }));
}

export async function createCoinSeller(payload) {
  const res = await apiClient.post('/v1/admin/sellers', payload);
  return res.data?.data;
}

export async function getCoinSellerById(id) {
  const res = await apiClient.get(`/v1/admin/sellers/${id}`);
  return res.data?.data;
}

export async function updateCoinSeller(id, payload) {
  const res = await apiClient.put(`/v1/admin/sellers/${id}`, payload);
  return res.data?.data;
}

export async function deleteCoinSeller(id) {
  const res = await apiClient.delete(`/v1/admin/sellers/${id}`);
  return res.data;
}

export async function toggleSellerStatus(id, currentStatus) {
  const isCurrentlyActive = (currentStatus || '').toLowerCase() === 'active';
  const nextStatus = isCurrentlyActive ? 'SUSPENDED' : 'ACTIVE';
  const res = await apiClient.put(`/v1/admin/sellers/${id}/status`, { sellerStatus: nextStatus, status: nextStatus });
  return res.data;
}

export async function allocateCoinsToSeller(id, amount, notes = '') {
  const res = await apiClient.post(`/v1/admin/sellers/${id}/allocate`, {
    amountCoins: Number(amount),
    amount: Number(amount),
    notes,
  });
  return res.data;
}

export async function correctSellerBalance(id, payload) {
  const res = await apiClient.post(`/v1/admin/sellers/${id}/correct`, payload);
  return res.data;
}

export default {
  getCoinSellers,
  createCoinSeller,
  getCoinSellerById,
  updateCoinSeller,
  deleteCoinSeller,
  toggleSellerStatus,
  allocateCoinsToSeller,
  correctSellerBalance,
};
