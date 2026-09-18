// ============================================================
// ZeParty Admin Portal — BD Center Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getBDCenters(params = {}) {
  const res = await apiClient.get('/v1/admin/bd-centers', { params });
  const items = res.data?.data || [];
  return items.map((b) => ({
    id: b.id,
    name: b.name,
    code: b.code || `BDC-${b.id.slice(0, 6).toUpperCase()}`,
    ownerUserId: b.ownerUserId,
    ownerUsername: b.owner?.username || b.ownerUserId,
    status: b.status || 'ACTIVE',
    region: b.region || 'GLOBAL',
    commissionPercent: Number(b.commissionPercent || 5),
    activeHostsCount: b._count?.hosts || b.hosts?.length || 0,
    activeAgenciesCount: b._count?.agencies || b.agencies?.length || 0,
    monthlyVolumeCoins: Number(b.monthlyVolumeCoins || 0),
    createdAt: b.createdAt,
    updatedAt: b.updatedAt,
  }));
}

export async function getBDCenterById(id) {
  const res = await apiClient.get(`/v1/admin/bd-centers/${id}`);
  return res.data?.data;
}

export async function createBDCenter(payload) {
  const res = await apiClient.post('/v1/admin/bd-centers', payload);
  return res.data?.data;
}

export async function updateBDCenter(id, updates) {
  const res = await apiClient.put(`/v1/admin/bd-centers/${id}`, updates);
  return res.data?.data;
}

export async function deactivateBDCenter(id) {
  const res = await apiClient.put(`/v1/admin/bd-centers/${id}`, { status: 'INACTIVE' });
  return res.data;
}

export async function sendBDCenterInvite(id, payload) {
  const res = await apiClient.post(`/v1/admin/bd-centers/${id}/invites`, payload);
  return res.data?.data;
}

export async function getBDCenterInvites(id) {
  const res = await apiClient.get(`/v1/admin/bd-centers/${id}/invites`);
  return res.data?.data || [];
}

export default {
  getBDCenters,
  getBDCenterById,
  createBDCenter,
  updateBDCenter,
  deactivateBDCenter,
  sendBDCenterInvite,
  getBDCenterInvites,
};
