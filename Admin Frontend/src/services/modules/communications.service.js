// ============================================================
// ZeParty Admin Portal — Communications Service (JavaScript)
// Server-authoritative Announcements and Notifications Integration
// ============================================================

import apiClient from '../api';

function formatAnnouncementRecord(a) {
  if (!a) return null;
  return {
    id: a.id,
    title: a.title,
    content: a.content || a.body || '',
    body: a.body || a.content || '',
    type: a.type || 'Maintenance',
    audience: a.targetAudience ? (a.targetAudience === 'ALL' ? 'All Users' : a.targetAudience) : (a.audience || 'All Users'),
    targetAudience: a.targetAudience || 'ALL',
    pinned: Boolean(a.isPinned || a.pinned),
    isPinned: Boolean(a.isPinned || a.pinned),
    status: a.isActive !== undefined ? (a.isActive ? 'published' : 'draft') : (a.status || 'published'),
    isActive: a.isActive !== undefined ? a.isActive : true,
    publishedAt: a.startsAt || a.createdAt || new Date().toISOString(),
    createdAt: a.createdAt || new Date().toISOString(),
    createdBy: a.createdBy || 'Admin',
  };
}

// ---- Announcements Service Methods ----

export async function getAnnouncements(params = {}) {
  const res = await apiClient.get('/v1/admin/announcements', { params });
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data.map(formatAnnouncementRecord);
  }
  return [];
}

export async function getAnnouncementById(id) {
  const res = await apiClient.get(`/v1/admin/announcements/${id}`);
  if (res.data && res.data.success && res.data.data) {
    return formatAnnouncementRecord(res.data.data);
  }
  throw new Error('Announcement not found');
}

export async function createAnnouncement(data) {
  let targetAudience = 'ALL';
  if (data.audience === 'Hosts Only') targetAudience = 'HOSTS';
  else if (data.audience === 'VIP Users' || data.audience === 'VIP Users Only') targetAudience = 'VIP_USERS';
  else if (data.audience === 'Agencies') targetAudience = 'AGENCIES';
  else if (data.audience === 'Resellers') targetAudience = 'SELLERS';

  const payload = {
    title: data.title,
    content: data.content || data.body || '',
    body: data.content || data.body || '',
    type: data.type || 'Maintenance',
    targetAudience,
    targetType: targetAudience,
    isPinned: Boolean(data.pinned || data.isPinned),
    status: data.publishNow !== false ? 'ACTIVE' : 'DRAFT',
  };

  const res = await apiClient.post('/v1/admin/announcements', payload);
  return formatAnnouncementRecord(res.data?.data);
}

export async function updateAnnouncement(id, data) {
  const payload = {
    ...(data.title !== undefined && { title: data.title }),
    ...(data.content !== undefined && { content: data.content, body: data.content }),
    ...(data.body !== undefined && { content: data.body, body: data.body }),
    ...(data.type !== undefined && { type: data.type }),
    ...(data.pinned !== undefined && { isPinned: Boolean(data.pinned) }),
    ...(data.isPinned !== undefined && { isPinned: Boolean(data.isPinned) }),
    ...(data.status !== undefined && { status: data.status.toUpperCase() }),
  };

  const res = await apiClient.put(`/v1/admin/announcements/${id}`, payload);
  return formatAnnouncementRecord(res.data?.data);
}

export async function deleteAnnouncement(id) {
  const res = await apiClient.delete(`/v1/admin/announcements/${id}`);
  return res.data;
}

export async function toggleAnnouncementPublish(id) {
  const res = await apiClient.get(`/v1/admin/announcements/${id}`);
  const current = res.data?.data;
  const newStatus = current?.status === 'ACTIVE' ? 'DRAFT' : 'ACTIVE';
  return updateAnnouncement(id, { status: newStatus, isActive: newStatus === 'ACTIVE' });
}

// ---- Notifications Service Methods ----

export async function getNotifications(params = {}) {
  const res = await apiClient.get('/v1/admin/notifications', { params });
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data;
  }
  return [];
}

export async function broadcastNotification(data) {
  const payload = {
    title: data.title,
    body: data.body || data.message || '',
    message: data.message || data.body || '',
    type: data.type || 'SYSTEM',
    targetSegment: data.targetSegment || 'All Users',
    targetType: data.targetSegment === 'All Users' ? 'GLOBAL' : 'SEGMENT',
  };

  const res = await apiClient.post('/v1/admin/notifications', payload);
  return res.data?.data;
}

export default {
  getAnnouncements,
  getAnnouncementById,
  createAnnouncement,
  updateAnnouncement,
  deleteAnnouncement,
  toggleAnnouncementPublish,
  getNotifications,
  broadcastNotification,
};
