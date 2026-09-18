// ============================================================
// ZeParty Admin Portal — Agencies Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getAgencies(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/agencies', { params });
    const items = res.data?.data || [];
    return items.map((a) => ({
      id: a.id,
      name: a.agencyName || a.name || 'Agency',
      code: a.agencyCode || a.code || '-',
      ownerUserId: a.ownerUserId,
      ownerUsername: a.owner?.username || a.ownerUserId || 'Owner',
      status: a.status?.toLowerCase() || 'active',
      activeHostsCount: a.hosts?.length || a._count?.hosts || 0,
      commissionPct: Number(a.commissionRate || a.commissionPercent || 15),
      bdCenterId: a.bdCenterId,
      bdCenterName: a.bdCenter?.centerName || a.bdCenter?.name || 'General BD',
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
    }));
  } catch (err) {
    console.warn('Failed to fetch agencies:', err.message);
    return [];
  }
}

export async function getActiveAgencies() {
  const res = await apiClient.get('/v1/admin/agencies', { params: { status: 'ACTIVE' } });
  return res.data?.data || [];
}

export async function getAgencyById(id) {
  const res = await apiClient.get(`/v1/admin/agencies/${id}`);
  return res.data?.data;
}

export async function createAgency(payload) {
  const res = await apiClient.post('/v1/admin/agencies', payload);
  return res.data?.data;
}

export async function updateAgency(id, payload) {
  const res = await apiClient.put(`/v1/admin/agencies/${id}`, payload);
  return res.data?.data;
}

export async function approveAgency(id) {
  const res = await apiClient.put(`/v1/admin/agencies/${id}`, { status: 'ACTIVE' });
  return res.data;
}

export async function rejectAgency(id, reason) {
  const res = await apiClient.put(`/v1/admin/agencies/${id}`, {
    status: 'INACTIVE',
    reason: reason || 'Rejected by administrator',
  });
  return res.data;
}

export async function transferHostAgency(hostId, fromAgencyId, toAgencyId, reason) {
  const res = await apiClient.post(`/v1/admin/agencies/${toAgencyId}/transfer-host`, {
    hostId,
    fromAgencyId,
    reason: reason || 'Administrative transfer',
  });
  return res.data;
}

export async function getAgencyMembers(agencyId, params = {}) {
  const res = await apiClient.get(`/v1/admin/agencies/${agencyId}/members`, { params });
  return res.data?.data || [];
}

export default {
  getAgencies,
  getActiveAgencies,
  getAgencyById,
  createAgency,
  updateAgency,
  approveAgency,
  rejectAgency,
  transferHostAgency,
  getAgencyMembers,
};
