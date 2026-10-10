// ============================================================
// ZeParty Admin Portal — Banners Service (JavaScript)
// Server-authoritative PostgreSQL Banners Management Integration
// ============================================================

import apiClient from '../api';

function formatBannerRecord(b) {
  if (!b) return null;
  return {
    id: b.id,
    title: b.title || '',
    subtitle: b.subtitle || '',
    customText: b.customText || '',
    image: b.imageUrl || b.image || '',
    imageUrl: b.imageUrl || b.image || '',
    linkUrl: b.destinationUrl || b.linkUrl || null,
    destinationUrl: b.destinationUrl || b.linkUrl || null,
    placement: b.placement || 'Home Carousel',
    target: b.countries ? `Country: ${b.countries}` : (b.targetType === 'COUNTRY_WISE' ? 'Country-specific' : 'Global'),
    targetType: b.targetType || 'GLOBAL',
    targetValue: b.countries || b.targetValue || null,
    countries: b.countries || '',
    priority: b.position !== undefined ? b.position : (b.priority || 0),
    position: b.position !== undefined ? b.position : (b.priority || 0),
    startDate: b.startsAt ? new Date(b.startsAt).toISOString().split('T')[0] : (b.startDate || 'Immediate'),
    endDate: b.endsAt ? new Date(b.endsAt).toISOString().split('T')[0] : (b.endDate || 'Permanent'),
    startsAt: b.startsAt || null,
    endsAt: b.endsAt || null,
    status: b.isActive ? 'ACTIVE' : (b.status || 'INACTIVE'),
    isActive: b.isActive !== undefined ? b.isActive : true,
    createdAt: b.createdAt || new Date().toISOString(),
  };
}

export async function uploadBannerMedia(file) {
  if (!file) throw new Error('No file provided');

  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = async (e) => {
      try {
        const base64 = e.target.result;
        const mimeType = file.type || 'image/jpeg';
        const res = await apiClient.post('/v1/media/upload', {
          dataBase64: base64,
          mimeType,
          folder: 'banners',
        }).catch(async () => {
          // Fallback route without /v1 prefix
          return await apiClient.post('/media/upload', {
            dataBase64: base64,
            mimeType,
            folder: 'banners',
          });
        });

        if (res.data && res.data.success && res.data.data?.url) {
          resolve(res.data.data.url);
        } else {
          // Fallback to data url if local backend storage is direct
          resolve(base64);
        }
      } catch (err) {
        console.warn('[BannersService] Upload to server failed, falling back to base64 data URL:', err.message);
        resolve(reader.result);
      }
    };
    reader.onerror = (err) => reject(err);
    reader.readAsDataURL(file);
  });
}

export async function getBanners(params = {}) {
  const res = await apiClient.get('/v1/admin/banners', { params }).catch(async () => {
    return await apiClient.get('/admin/banners', { params });
  });
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data.map(formatBannerRecord);
  }
  return [];
}

export async function getBannerById(id) {
  const res = await apiClient.get(`/v1/admin/banners/${id}`).catch(async () => {
    return await apiClient.get(`/admin/banners/${id}`);
  });
  if (res.data && res.data.success && res.data.data) {
    return formatBannerRecord(res.data.data);
  }
  throw new Error('Banner not found');
}

export async function createBanner(bannerData) {
  const payload = {
    title: bannerData.title ? bannerData.title.trim() : null,
    subtitle: bannerData.subtitle ? bannerData.subtitle.trim() : null,
    customText: bannerData.customText ? bannerData.customText.trim() : null,
    imageUrl: bannerData.imageUrl || bannerData.image || '',
    destinationUrl: bannerData.destinationUrl || bannerData.linkUrl || null,
    linkUrl: bannerData.destinationUrl || bannerData.linkUrl || null,
    placement: bannerData.placement || 'Home Carousel',
    targetType: bannerData.isGlobal ? 'GLOBAL' : 'COUNTRY_WISE',
    countries: Array.isArray(bannerData.selectedCountries)
      ? bannerData.selectedCountries.join(',')
      : (bannerData.countries || bannerData.targetValue || ''),
    position: Number(bannerData.priority !== undefined ? bannerData.priority : (bannerData.position || 0)),
    priority: Number(bannerData.priority !== undefined ? bannerData.priority : (bannerData.position || 0)),
    startsAt: bannerData.startDate ? new Date(bannerData.startDate).toISOString() : (bannerData.startsAt || null),
    endsAt: bannerData.endDate ? new Date(bannerData.endDate).toISOString() : (bannerData.endsAt || null),
    status: bannerData.status || 'ACTIVE',
    isActive: bannerData.status ? bannerData.status === 'ACTIVE' : (bannerData.isActive ?? true),
  };

  const res = await apiClient.post('/v1/admin/banners', payload).catch(async () => {
    return await apiClient.post('/admin/banners', payload);
  });
  return formatBannerRecord(res.data?.data);
}

export async function updateBanner(id, updateData) {
  const payload = {
    ...(updateData.title !== undefined && { title: updateData.title ? updateData.title.trim() : null }),
    ...(updateData.subtitle !== undefined && { subtitle: updateData.subtitle ? updateData.subtitle.trim() : null }),
    ...(updateData.customText !== undefined && { customText: updateData.customText ? updateData.customText.trim() : null }),
    ...(updateData.imageUrl !== undefined && { imageUrl: updateData.imageUrl }),
    ...(updateData.image !== undefined && { imageUrl: updateData.image }),
    ...(updateData.linkUrl !== undefined && { destinationUrl: updateData.linkUrl, linkUrl: updateData.linkUrl }),
    ...(updateData.destinationUrl !== undefined && { destinationUrl: updateData.destinationUrl, linkUrl: updateData.destinationUrl }),
    ...(updateData.placement !== undefined && { placement: updateData.placement }),
    ...(updateData.targetType !== undefined && { targetType: updateData.targetType }),
    ...(updateData.countries !== undefined && { countries: Array.isArray(updateData.countries) ? updateData.countries.join(',') : updateData.countries }),
    ...(updateData.priority !== undefined && { position: Number(updateData.priority), priority: Number(updateData.priority) }),
    ...(updateData.position !== undefined && { position: Number(updateData.position), priority: Number(updateData.position) }),
    ...(updateData.status !== undefined && { status: updateData.status, isActive: updateData.status === 'ACTIVE' }),
    ...(updateData.isActive !== undefined && { isActive: Boolean(updateData.isActive), status: updateData.isActive ? 'ACTIVE' : 'INACTIVE' }),
    ...(updateData.startDate !== undefined && { startsAt: updateData.startDate ? new Date(updateData.startDate).toISOString() : null }),
    ...(updateData.endDate !== undefined && { endsAt: updateData.endDate ? new Date(updateData.endDate).toISOString() : null }),
  };

  const res = await apiClient.put(`/v1/admin/banners/${id}`, payload).catch(async () => {
    return await apiClient.put(`/admin/banners/${id}`, payload);
  });
  return formatBannerRecord(res.data?.data);
}

export async function deleteBanner(id) {
  const res = await apiClient.delete(`/v1/admin/banners/${id}`).catch(async () => {
    return await apiClient.delete(`/admin/banners/${id}`);
  });
  return res.data;
}

export async function getBannerStats() {
  try {
    const banners = await getBanners();
    return {
      activeBanners: banners.filter((b) => b.status === 'ACTIVE').length,
      scheduledCampaigns: banners.filter((b) => b.status === 'SCHEDULED').length,
      globalReach: banners.filter((b) => b.targetType === 'GLOBAL' || b.target === 'Global').length,
      regionalOverrides: banners.filter((b) => b.targetType === 'COUNTRY' || b.targetType === 'COUNTRY_WISE' || b.target !== 'Global').length,
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
  uploadBannerMedia,
  getBanners,
  getBannerById,
  createBanner,
  updateBanner,
  deleteBanner,
  getBannerStats,
};
