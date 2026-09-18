// ============================================================
// ZeParty Admin Portal — Support Ticket Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getSupportStats() {
  try {
    const res = await apiClient.get('/v1/admin/support/stats');
    return res.data?.data || { openTickets: 0, highPriority: 0, unassigned: 0, waitingForReply: 0, resolvedToday: 0 };
  } catch (err) {
    return { openTickets: 0, highPriority: 0, unassigned: 0, waitingForReply: 0, resolvedToday: 0 };
  }
}

export async function getSupportTickets(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/support', { params });
    const items = res.data?.data || [];
    return items.map((t) => ({
      id: t.id,
      ticketNumber: t.ticketNumber || `TCK-${t.id.slice(0, 6)}`,
      subject: t.subject || 'Support Inquiry',
      category: t.category || 'GENERAL',
      status: t.status || 'OPEN',
      priority: t.priority || 'MEDIUM',
      userId: t.userId,
      userName: t.user?.username || t.user?.profile?.displayName || t.userId,
      messages: t.messages || [],
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    }));
  } catch (err) {
    return [];
  }
}

export async function getTicketDetails(id) {
  const res = await apiClient.get(`/v1/admin/support/${id}`);
  return res.data?.data;
}

export async function replyToTicket(id, message) {
  const res = await apiClient.post(`/v1/admin/support/${id}/reply`, { message });
  return res.data?.data;
}

export async function updateTicketStatus(id, status) {
  const res = await apiClient.patch(`/v1/admin/support/${id}`, { status });
  return res.data?.data;
}

export async function updateTicket(id, updateData) {
  if (updateData.status) {
    return updateTicketStatus(id, updateData.status);
  }
  return { success: true };
}

export default {
  getSupportStats,
  getSupportTickets,
  getTicketDetails,
  replyToTicket,
  updateTicketStatus,
  updateTicket,
};
