// ============================================================
// ZeParty Admin Portal — Communications Service (JavaScript)
// ============================================================

import {
  MOCK_ANNOUNCEMENTS,
  MOCK_NOTIFICATIONS,
} from '../../mocks/comms.mock';

let announcementsState = [...MOCK_ANNOUNCEMENTS];
let notificationsState = [...MOCK_NOTIFICATIONS];

// ---- Announcements ----
export async function getAnnouncements() {
  await new Promise((res) => setTimeout(res, 200));
  return [...announcementsState];
}

export async function createAnnouncement(data) {
  await new Promise((res) => setTimeout(res, 300));
  const newAnn = {
    id: 'ann-' + Date.now(),
    title: data.title,
    body: data.body,
    audience: data.audience || 'all',
    status: data.publishNow ? 'published' : 'draft',
    createdAt: new Date().toISOString(),
  };
  announcementsState = [newAnn, ...announcementsState];
  return newAnn;
}

export async function toggleAnnouncementPublish(id) {
  await new Promise((res) => setTimeout(res, 250));
  announcementsState = announcementsState.map((a) =>
    a.id === id ? { ...a, status: a.status === 'published' ? 'draft' : 'published' } : a
  );
  return { success: true };
}

// ---- Notifications ----
export async function getNotifications() {
  await new Promise((res) => setTimeout(res, 200));
  return [...notificationsState];
}

export async function broadcastNotification(data) {
  await new Promise((res) => setTimeout(res, 350));
  const newNotif = {
    id: 'notif-' + Date.now(),
    title: data.title,
    message: data.message,
    targetSegment: data.targetSegment || 'All Users',
    status: 'sent',
    sentAt: new Date().toISOString(),
  };
  notificationsState = [newNotif, ...notificationsState];
  return newNotif;
}
