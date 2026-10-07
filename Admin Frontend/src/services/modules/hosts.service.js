// ============================================================
// ZeParty Admin Portal — Hosts Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getHosts(params = {}) {
  const res = await apiClient.get('/v1/admin/hosts', { params });
  return res.data?.data || [];
}

export async function getHostApplications(params = {}) {
  const res = await apiClient.get('/v1/admin/hosts/applications', { params });
  const items = res.data?.data || [];
  return items.map((app) => {
    const rawStatus = (app.status || '').toUpperCase();
    const isPending = rawStatus === 'APPLIED' || rawStatus === 'PENDING' || !rawStatus;
    return {
      id: app.id,
      userId: app.userId,
      applicantName: app.user?.profile?.displayName || app.user?.username || app.userId,
      applicantUsername: app.user?.username || app.userId,
      user: app.user?.username || app.userId,
      hostType: app.hostType || 'BOTH',
      agencyId: app.agencyId,
      agencyName: app.agency?.name || 'Independent',
      status: isPending ? 'pending' : rawStatus.toLowerCase(),
      submittedAt: app.createdAt,
      reviewedAt: app.reviewedAt,
      reviewerAdminId: app.reviewerAdminId,
      rejectionReason: app.rejectionReason,
      idCardFrontUrl: app.idCardFrontUrl || app.idDocumentUrl,
      idCardBackUrl: app.idCardBackUrl,
      videoSampleUrl: app.videoSampleUrl || app.liveDemoUrl,
      userProfile: app.user?.profile,
    };
  });
}

export async function getHostApplicationById(id) {
  const res = await apiClient.get(`/v1/admin/hosts/applications/${id}`);
  return res.data?.data;
}

export async function approveHostApplication(id, payload = {}) {
  const res = await apiClient.put(`/v1/admin/hosts/applications/${id}`, {
    status: 'APPROVED',
    commissionPercent: payload.commissionPercent || 70,
    reason: payload.reason || 'Approved by administrator',
  });
  return res.data;
}

export async function rejectHostApplication(id, reason) {
  const res = await apiClient.put(`/v1/admin/hosts/applications/${id}`, {
    status: 'REJECTED',
    reason: reason || 'Application rejected by administrator',
  });
  return res.data;
}

export async function updateHostStatus(id, status, reason) {
  const res = await apiClient.put(`/v1/admin/hosts/${id}/status`, {
    status,
    reason: reason || 'Status updated by administrator',
  });
  return res.data;
}

export default {
  getHosts,
  getHostApplications,
  getHostApplicationById,
  approveHostApplication,
  rejectHostApplication,
  updateHostStatus,
};
