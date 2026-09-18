// ============================================================
// ZeParty Admin Portal — Store Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getStoreCatalog(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/store/catalog', { params });
    return res.data?.data || [];
  } catch (err) {
    return [];
  }
}

export async function getStoreStats() {
  try {
    const res = await apiClient.get('/v1/admin/store/catalog');
    const items = res.data?.data || [];
    const totalItems = items.length;
    const activeItems = items.filter((i) => i.isActive).length;
    return {
      totalItems,
      activeItems,
      featuredItems: 0,
      totalPurchases: 0,
      totalRevenue: 0,
      categories: ['FRAME', 'ENTRY_EFFECT', 'BADGE', 'ROOM_THEME', 'BUBBLE', 'VEHICLE'],
    };
  } catch (err) {
    return {
      totalItems: 0,
      activeItems: 0,
      featuredItems: 0,
      totalPurchases: 0,
      totalRevenue: 0,
      categories: ['FRAME', 'ENTRY_EFFECT', 'BADGE', 'ROOM_THEME', 'BUBBLE', 'VEHICLE'],
    };
  }
}

export async function getStoreItems(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/store/catalog', { params });
    const items = res.data?.data || [];
    return items.map((i) => ({
      id: i.id,
      name: i.name,
      category: i.assetType || i.category || 'FRAME',
      price: Number(i.priceCoins || i.coinPrice || 0),
      coinPrice: Number(i.priceCoins || i.coinPrice || 0),
      durationDays: Number(i.validDays || i.durationDays || 30),
      status: i.isActive ? 'ACTIVE' : 'INACTIVE',
      thumbnail: i.thumbnailUrl || i.iconUrl || '',
      iconUrl: i.thumbnailUrl || i.iconUrl || '',
      purchases: 0,
      revenue: 0,
      createdAt: i.createdAt,
    }));
  } catch (err) {
    return [];
  }
}

export async function createStoreItem(itemData) {
  const res = await apiClient.post('/v1/admin/assets', {
    name: itemData.name,
    category: (itemData.category || 'FRAME').toUpperCase(),
    coinPrice: Number(itemData.price || itemData.coinPrice || 0),
    durationDays: Number(itemData.durationDays || 30),
    iconUrl: itemData.thumbnail || itemData.iconUrl || 'https://cdn.zeparty.io/assets/default.png',
    resourceKey: itemData.resourceKey || `store_${Date.now()}`,
    isActive: true,
  });
  return res.data?.data;
}

export async function updateStoreItem(id, updateData) {
  const res = await apiClient.put(`/v1/admin/assets/${id}`, updateData);
  return res.data?.data;
}

export default {
  getStoreCatalog,
  getStoreStats,
  getStoreItems,
  createStoreItem,
  updateStoreItem,
};
