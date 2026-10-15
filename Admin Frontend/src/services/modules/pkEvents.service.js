import apiClient from '../api.js';

/**
 * 1. Matches: Live Monitor & History
 */
export async function getAdminMatches(params = {}) {
  const res = await apiClient.get('/v1/admin/pk/matches', { params });
  if (res.data?.success) {
    return {
      matches: res.data.data || [],
      meta: res.data.meta || { total: 0, page: 1, limit: 20 },
    };
  }
  return { matches: [], meta: { total: 0, page: 1, limit: 20 } };
}

/**
 * 2. Force Stop Match (Audited & Confirmed)
 */
export async function forceStopMatch(id, reason) {
  const res = await apiClient.post(`/v1/admin/pk/matches/${id}/force-stop`, { reason });
  return res.data;
}

/**
 * 3. PK System Settings
 */
export async function getPKSettings() {
  const res = await apiClient.get('/v1/admin/pk/settings');
  return res.data?.data || null;
}

export async function updatePKSettings(data) {
  const res = await apiClient.put('/v1/admin/pk/settings', data);
  return res.data?.data || null;
}

/**
 * 4. PK Restrictions
 */
export async function getPKRestrictions(params = {}) {
  const res = await apiClient.get('/v1/admin/pk/restrictions', { params });
  if (res.data?.success) {
    return {
      restrictions: res.data.data || [],
      meta: res.data.meta || { total: 0, page: 1, limit: 20 },
    };
  }
  return { restrictions: [], meta: { total: 0, page: 1, limit: 20 } };
}

export async function createPKRestriction(data) {
  const res = await apiClient.post('/v1/admin/pk/restrictions', data);
  return res.data?.data || null;
}

export async function revokePKRestriction(id) {
  const res = await apiClient.delete(`/v1/admin/pk/restrictions/${id}`);
  return res.data?.data || null;
}

/**
 * 5. Audited Result Revision
 */
export async function reviseMatchResult(id, data) {
  const res = await apiClient.post(`/v1/admin/pk/matches/${id}/revise-result`, data);
  return res.data?.data || null;
}

/**
 * 6. Match Snapshot & Supporter Details
 */
export async function getMatchDetails(id) {
  const res = await apiClient.get(`/v1/pk/matches/${id}`);
  return res.data?.data || null;
}

// ── BACKWARD-COMPATIBLE ALIASES ────────────────────────────────
export async function getPKEvents(params = {}) {
  const { matches } = await getAdminMatches(params);
  return matches;
}

export async function getPKStats() {
  try {
    const { matches } = await getAdminMatches({ limit: 100 });
    const active = matches.filter((m) => m.status === 'ACTIVE' || m.status === 'COUNTDOWN' || m.status === 'PREPARING');
    return {
      activeBattles: active.length,
      totalDiamondsPooled: matches.reduce((sum, m) => sum + (Number(m.scoreA || 0) + Number(m.scoreB || 0)), 0),
      totalPKEvents: matches.length,
      totalViewers: 0,
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

export default {
  getAdminMatches,
  forceStopMatch,
  getPKSettings,
  updatePKSettings,
  getPKRestrictions,
  createPKRestriction,
  revokePKRestriction,
  reviseMatchResult,
  getMatchDetails,
  getPKEvents,
  getPKStats,
  getPKLeaderboard,
};
