// ============================================================
// ZeParty Admin Portal — Asset Management Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getAssets(params = {}) {
  const res = await apiClient.get('/v1/admin/assets', { params });
  const items = res.data?.data || [];
  return items.map((a) => ({
    id: a.id,
    name: a.name,
    category: a.category || 'FRAME',
    subCategory: a.subCategory || 'Standard',
    price: Number(a.coinPrice || a.price || 0),
    coinPrice: Number(a.coinPrice || a.price || 0),
    status: a.isActive ? 'active' : 'inactive',
    isActive: Boolean(a.isActive),
    roomAvailability: 'Both',
    thumbnail: a.iconUrl || a.previewUrl || 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=120&auto=format&fit=crop&q=60',
    iconUrl: a.iconUrl || '',
    previewUrl: a.previewUrl || '',
    resourceKey: a.resourceKey || '',
    duration: Number(a.durationDays || 30),
    durationDays: Number(a.durationDays || 30),
    volume: 80,
    comboSupport: false,
    comboCount: 1,
    fullScreen: false,
    priority: 1,
    startDate: '',
    endDate: '',
    assignment: 'All',
    updatedAt: a.updatedAt || a.createdAt,
    history: [
      {
        timestamp: a.createdAt,
        operator: 'System Admin',
        action: 'Created',
        details: 'Initial asset catalog release.',
        before: null,
        after: a.isActive ? 'Active' : 'Inactive',
      },
    ],
  }));
}

export async function getAssetById(id) {
  const res = await apiClient.get(`/v1/admin/assets/${id}`);
  return res.data?.data;
}

export async function createAsset(payload) {
  const assetType = (payload.assetType || payload.category || 'FRAME').toUpperCase();
  const thumbnailUrl =
    payload.thumbnailUrl ||
    payload.thumbnail ||
    payload.iconUrl ||
    'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=120&auto=format&fit=crop&q=60';
  const priceCoins = Number(payload.priceCoins ?? payload.coinPrice ?? payload.price ?? 0);
  const validDays = Number(payload.validDays ?? payload.durationDays ?? payload.duration ?? 30);
  const subcategory = (payload.assetSubcategory || payload.subCategory || 'STATIC').toUpperCase();

  const res = await apiClient.post('/v1/admin/assets', {
    name: payload.name,
    assetType,
    assetSubcategory: ['STATIC', 'ANIMATED_SVGA', 'MP4_VIDEO', 'MP3_AUDIO'].includes(subcategory)
      ? subcategory
      : 'STATIC',
    thumbnailUrl,
    priceCoins,
    validDays,
    isActive: payload.status === 'active' || payload.isActive !== false,
  });
  return res.data?.data;
}

export const addAsset = createAsset;

export async function updateAsset(id, payload) {
  const updateData = {};
  if (payload.name) updateData.name = payload.name;
  if (payload.category) updateData.category = payload.category.toUpperCase();
  if (payload.price !== undefined || payload.coinPrice !== undefined) {
    updateData.coinPrice = Number(payload.price || payload.coinPrice);
  }
  if (payload.duration !== undefined || payload.durationDays !== undefined) {
    updateData.durationDays = Number(payload.duration || payload.durationDays);
  }
  if (payload.thumbnail || payload.iconUrl) {
    updateData.iconUrl = payload.thumbnail || payload.iconUrl;
  }
  if (payload.status !== undefined) {
    updateData.isActive = payload.status === 'active';
  }
  if (payload.isActive !== undefined) {
    updateData.isActive = Boolean(payload.isActive);
  }

  const res = await apiClient.put(`/v1/admin/assets/${id}`, updateData);
  return res.data?.data;
}

export async function replaceAssetFile(id, file) {
  return updateAsset(id, {
    thumbnail: URL.createObjectURL(file),
  });
}

export async function deleteAsset(id) {
  const res = await apiClient.delete(`/v1/admin/assets/${id}`);
  return res.data;
}

export default {
  getAssets,
  getAssetById,
  createAsset,
  addAsset,
  updateAsset,
  replaceAssetFile,
  deleteAsset,
};
