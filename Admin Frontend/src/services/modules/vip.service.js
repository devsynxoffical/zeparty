// ============================================================
// ZeParty Admin Portal — VIP Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getVIPItems(params = {}) {
  const res = await apiClient.get('/v1/admin/store/vip', { params });
  const items = res.data?.data || [];
  return items.map((v) => ({
    id: v.id,
    name: v.name,
    type: v.category?.toLowerCase() || 'badge',
    price: Number(v.coinPrice || 0),
    coinPrice: Number(v.coinPrice || 0),
    durationDays: Number(v.durationDays || 30),
    active: Boolean(v.isActive),
    isActive: Boolean(v.isActive),
    iconUrl: v.iconUrl || '',
    thumbnail: v.iconUrl || '',
    createdAt: v.createdAt,
  }));
}

export async function createVIPItem(vipData) {
  const res = await apiClient.post('/v1/admin/assets', {
    name: vipData.name,
    category: 'VIP_BADGE',
    coinPrice: Number(vipData.price || 0),
    durationDays: Number(vipData.durationDays || 30),
    iconUrl: vipData.iconUrl || 'https://cdn.zeparty.io/vip/default.png',
    resourceKey: `vip_${Date.now()}`,
    isActive: true,
  });
  return res.data?.data;
}

export async function updateVIPItem(id, vipData) {
  const res = await apiClient.put(`/v1/admin/assets/${id}`, vipData);
  return res.data?.data;
}

export async function toggleVIPStatus(id, currentActive) {
  const res = await apiClient.put(`/v1/admin/assets/${id}`, {
    isActive: !currentActive,
  });
  return res.data?.data;
}

export default {
  getVIPItems,
  createVIPItem,
  updateVIPItem,
  toggleVIPStatus,
};
