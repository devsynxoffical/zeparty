// ============================================================
// ZeParty Admin Portal — Moderation Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getModerationStats() {
  try {
    const res = await apiClient.get('/v1/admin/moderation/stats');
    return res.data?.data || {
      reportsToday: 0,
      pendingReview: 0,
      actionedToday: 0,
      appealsPending: 0,
      pendingReports: 0,
      resolvedToday: 0,
      totalRestrictedUsers: 0,
    };
  } catch (err) {
    return {
      reportsToday: 0,
      pendingReview: 0,
      actionedToday: 0,
      appealsPending: 0,
      pendingReports: 0,
      resolvedToday: 0,
      totalRestrictedUsers: 0,
    };
  }
}

export async function getModerationReports(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/reports', { params });
    const items = res.data?.data || [];
    return items.map((r) => ({
      id: r.id,
      type: r.violationType || r.category || r.type || 'USER_BEHAVIOR',
      reporter: r.reporter?.username || r.reporterUserId || 'Anonymous',
      reportedUser: r.reportedUser?.username || r.reportedUserId || 'User',
      targetId: r.reportedUserId || r.reportedRoomId || r.reportedPostId || r.id,
      targetType: r.reportedRoomId ? 'Room' : r.reportedPostId ? 'Post' : 'User',
      targetUserId: r.reportedUserId,
      reason: r.description || r.reason || 'Violation of Community Guidelines',
      status: r.status || 'PENDING',
      priority: r.priority || 'MEDIUM',
      createdAt: r.createdAt,
      assignedAdmin: r.assignedAdmin?.name || r.assignedAdminId || 'Unassigned',
    }));
  } catch (err) {
    return [];
  }
}

export async function updateReportStatus(id, status, notes = '') {
  const res = await apiClient.post(`/v1/admin/reports/${id}/resolve`, {
    status,
    notes,
  });
  return res.data;
}

export async function moderateUser(payload) {
  const res = await apiClient.post('/v1/admin/moderation/user', {
    targetUserId: payload.targetUserId || payload.userId,
    action: (payload.action || 'WARNING').toUpperCase(),
    reason: payload.reason || 'Administrative action',
    durationMinutes: payload.durationMinutes ? Number(payload.durationMinutes) : undefined,
  });
  return res.data;
}

export async function moderateContent(payload) {
  const res = await apiClient.post('/v1/admin/moderation/content', {
    contentType: (payload.contentType || 'POST').toUpperCase(),
    contentId: payload.contentId,
    action: (payload.action || 'REMOVE').toUpperCase(),
    reason: payload.reason || 'Content violation',
  });
  return res.data;
}

export async function getRestrictions(params = {}) {
  const res = await apiClient.get('/v1/admin/restrictions', { params });
  return res.data?.data || [];
}

export async function applyRestriction(payload) {
  const res = await apiClient.post('/v1/admin/restrictions', payload);
  return res.data?.data;
}

export async function liftRestriction(id) {
  const res = await apiClient.delete(`/v1/admin/restrictions/${id}`);
  return res.data;
}

export default {
  getModerationStats,
  getModerationReports,
  updateReportStatus,
  moderateUser,
  moderateContent,
  getRestrictions,
  applyRestriction,
  liftRestriction,
};
