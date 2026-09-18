import apiClient from '../api.js';

export async function getPKEvents(params = {}) {
  const res = await apiClient.get('/v1/admin/pk-events', { params });
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data;
  }
  return [];
}

export async function getPKStats() {
  try {
    const events = await getPKEvents();
    const active = events.filter((e) => e.status === 'ACTIVE' || e.status === 'COUNTDOWN');
    return {
      activeBattles: active.length,
      totalDiamondsPooled: events.reduce((sum, e) => sum + (Number(e.team1Score || 0) + Number(e.team2Score || 0)), 0),
      totalPKEvents: events.length,
      totalViewers: events.reduce((sum, e) => sum + (Number(e.viewerCount || 0)), 0),
    };
  } catch {
    return {
      activeBattles: 0,
      totalDiamondsPooled: 0,
      totalPKEvents: 0,
      totalViewers: 0,
    };
  }
}

export async function getPKLeaderboard() {
  return [];
}

export async function createPKEvent(eventData) {
  const res = await apiClient.post('/v1/admin/pk-events/start', eventData);
  return res.data?.data;
}

export async function updatePKEvent(id, updateData) {
  const res = await apiClient.post(`/v1/admin/pk-events/${id}/end`, updateData);
  return res.data?.data;
}

