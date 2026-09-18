// ============================================================
// ZeParty Admin Portal — Banners Service (JavaScript)
// Server-authoritative PostgreSQL Banners Management Integration
// ============================================================

import apiClient from '../api';

function formatBannerRecord(b) {
  if (!b) return null;
  return {
    id: b.id,
    title: b.title,
    image: b.imageUrl || b.image || '',
    imageUrl: b.imageUrl || b.image || '',
    linkUrl: b.destinationUrl || b.linkUrl || null,
    placement: b.placement || 'Home Carousel',
    target: b.targetValue ? `${b.targetType || 'Country'}: ${b.targetValue}` : (b.target || 'Global'),
    targetType: b.targetType || 'GLOBAL',
    targetValue: b.targetValue || null,
    priority: b.position !== undefined ? b.position : (b.priority || 0),
    startDate: b.startsAt ? new Date(b.startsAt).toISOString().split('T')[0] : (b.startDate || 'Immediate'),
    endDate: b.endsAt ? new Date(b.endsAt).toISOString().split('T')[0] : (b.endDate || 'Permanent'),
    status: b.isActive ? 'ACTIVE' : (b.status || 'INACTIVE'),
    isActive: b.isActive !== undefined ? b.isActive : true,
    createdAt: b.createdAt || new Date().toISOString(),
  };
}

export async function getBanners(params = {}) {
  const res = await apiClient.get('/v1/admin/banners', { params });
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data.map(formatBannerRecord);
  }
  return [];
}

export async function getBannerById(id) {
  const res = await apiClient.get(`/v1/admin/banners/${id}`);
  if (res.data && res.data.success && res.data.data) {
    return formatBannerRecord(res.data.data);
  }
  throw new Error('Banner not found');
}

export async function createBanner(bannerData) {
  const payload = {
    title: bannerData.title,
    imageUrl: bannerData.imageUrl || bannerData.image || '',
    linkUrl: bannerData.linkUrl || bannerData.destinationUrl || null,
    placement: bannerData.placement || 'Home Carousel',
    targetType: bannerData.isGlobal ? 'GLOBAL' : 'COUNTRY',
    targetValue: Array.isArray(bannerData.selectedCountries) ? bannerData.selectedCountries.join(',') : (bannerData.targetValue || null),
    priority: Number(bannerData.priority || 0),
    startsAt: bannerData.startDate ? new Date(bannerData.startDate).toISOString() : null,
    endsAt: bannerData.endDate ? new Date(bannerData.endDate).toISOString() : null,
    status: bannerData.status || 'ACTIVE',
  };

  const res = await apiClient.post('/v1/admin/banners', payload);
  return formatBannerRecord(res.data?.data);
}

export async function updateBanner(id, updateData) {
  const payload = {
    ...(updateData.title !== undefined && { title: updateData.title }),
    ...(updateData.imageUrl !== undefined && { imageUrl: updateData.imageUrl }),
    ...(updateData.image !== undefined && { imageUrl: updateData.image }),
    ...(updateData.linkUrl !== undefined && { linkUrl: updateData.linkUrl }),
    ...(updateData.placement !== undefined && { placement: updateData.placement }),
    ...(updateData.priority !== undefined && { priority: Number(updateData.priority) }),
    ...(updateData.status !== undefined && { status: updateData.status }),
    ...(updateData.isActive !== undefined && { status: updateData.isActive ? 'ACTIVE' : 'INACTIVE' }),
  };

  const res = await apiClient.put(`/v1/admin/banners/${id}`, payload);
  return formatBannerRecord(res.data?.data);
}

export async function deleteBanner(id) {
  const res = await apiClient.delete(`/v1/admin/banners/${id}`);
  return res.data;
}

export async function getBannerStats() {
  try {
    const banners = await getBanners();
    return {
      activeBanners: banners.filter((b) => b.status === 'ACTIVE').length,
      scheduledCampaigns: banners.filter((b) => b.status === 'SCHEDULED').length,
      globalReach: banners.filter((b) => b.targetType === 'GLOBAL' || b.target === 'Global').length,
      regionalOverrides: banners.filter((b) => b.targetType === 'COUNTRY' || b.target !== 'Global').length,
    };
  } catch {
    return {
      activeBanners: 0,
      scheduledCampaigns: 0,
      globalReach: 0,
      regionalOverrides: 0,
    };
  }
}

export default {
  getBanners,
  getBannerById,
  createBanner,
  updateBanner,
  deleteBanner,
  getBannerStats,
};
