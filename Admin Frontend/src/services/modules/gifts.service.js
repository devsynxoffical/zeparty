// ============================================================
// ZeParty Admin Portal — Gifts Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getGifts(params = {}) {
  const res = await apiClient.get('/v1/admin/gifts', { params });
  const items = res.data?.data || [];
  return items.map((g) => ({
    id: g.id,
    name: g.name,
    coinPrice: Number(g.coinValue || g.coinPrice || 0),
    coinValue: Number(g.coinValue || g.coinPrice || 0),
    category: g.giftCategory?.toLowerCase() || g.category?.toLowerCase() || 'popular',
    icon: g.iconUrl || '🎁',
    iconUrl: g.iconUrl || '',
    svgaAssetUrl: g.svgaAssetUrl || '',
    isAnimated: Boolean(g.isAnimated),
    isFullScreen: Boolean(g.isFullScreen),
    active: Boolean(g.isActive),
    isActive: Boolean(g.isActive),
    createdAt: g.createdAt,
    updatedAt: g.updatedAt,
  }));
}

export async function createGift(giftData) {
  const res = await apiClient.post('/v1/admin/gifts', {
    name: giftData.name,
    coinValue: Number(giftData.coinPrice || giftData.coinValue),
    iconUrl: giftData.iconUrl || (giftData.icon?.startsWith('http') ? giftData.icon : 'https://cdn.zeparty.io/gifts/default.png'),
    svgaAssetUrl: giftData.svgaAssetUrl || null,
    giftCategory: (giftData.category || 'POPULAR').toUpperCase(),
    isAnimated: Boolean(giftData.isAnimated),
    isFullScreen: Boolean(giftData.isFullScreen),
    isActive: giftData.active !== undefined ? Boolean(giftData.active) : true,
  });
  return res.data?.data;
}

export async function updateGift(id, giftData) {
  const payload = {};
  if (giftData.name) payload.name = giftData.name;
  if (giftData.coinPrice !== undefined || giftData.coinValue !== undefined) {
    payload.coinValue = Number(giftData.coinPrice || giftData.coinValue);
  }
  if (giftData.iconUrl) payload.iconUrl = giftData.iconUrl;
  if (giftData.category) payload.giftCategory = giftData.category.toUpperCase();
  if (giftData.active !== undefined) payload.isActive = Boolean(giftData.active);
  if (giftData.isActive !== undefined) payload.isActive = Boolean(giftData.isActive);
  if (giftData.isAnimated !== undefined) payload.isAnimated = Boolean(giftData.isAnimated);

  const res = await apiClient.put(`/v1/admin/gifts/${id}`, payload);
  return res.data?.data;
}

export async function toggleGiftStatus(id, currentActive) {
  const res = await apiClient.put(`/v1/admin/gifts/${id}`, {
    isActive: !currentActive,
  });
  return res.data?.data;
}

export async function deleteGift(id) {
  const res = await apiClient.delete(`/v1/admin/gifts/${id}`);
  return res.data;
}

export default {
  getGifts,
  createGift,
  updateGift,
  toggleGiftStatus,
  deleteGift,
};
