// ============================================================
// ZeParty Admin Portal — Leaderboards & Rankings Service
// 100% Real Backend Driven via /v1/admin/rankings
// ============================================================

import apiClient from '../api';

/**
 * Fetch authoritative rankings from the backend ranking engine
 * @param {Object} params
 * @param {string} params.category - 'wealth', 'charm', 'room', 'cp', 'svip', 'noble', 'lucky'
 * @param {string} params.period - 'hourly', 'daily', 'weekly', 'monthly', 'all_time'
 * @param {string} params.scope - 'GLOBAL', 'REGION', 'COUNTRY'
 * @param {string} [params.country] - country code (e.g., 'PK', 'US')
 * @param {string} [params.region] - region name (e.g., 'MENA', 'ASIA')
 * @param {number} [params.limit] - max records to return (1-100)
 * @param {string} [params.search] - search query for filter
 */
export async function getRankings(params = {}) {
  const {
    category = 'wealth',
    period = 'daily',
    scope = 'GLOBAL',
    country = null,
    region = null,
    limit = 50,
    search = '',
  } = params;

  const queryParams = {
    category: (category || 'wealth').toLowerCase(),
    period: (period || 'daily').toLowerCase().replace('-', '_'),
    scope: (scope || 'GLOBAL').toUpperCase(),
    limit,
  };

  if (country) queryParams.country = country;
  if (region) queryParams.region = region;
  if (search && search.trim()) queryParams.search = search.trim();

  try {
    const res = await apiClient.get('/v1/admin/rankings', { params: queryParams });
    return res.data;
  } catch (err) {
    // Graceful fallback to public rankings if admin route falls through
    const fallbackRes = await apiClient.get('/v1/rankings', { params: queryParams });
    return fallbackRes.data;
  }
}

/**
 * Fetch lucky gift records
 */
export async function getLuckyGiftRecords({ type = 'lucky', page = 1, limit = 20 } = {}) {
  const res = await apiClient.get('/v1/admin/rankings/lucky-records', { params: { type, page, limit } });
  return res.data;
}

/**
 * Backward compatibility wrapper
 */
export async function getLeaderboards(period = 'daily', category = 'hosts') {
  const catMap = {
    hosts: 'charm',
    gifters: 'wealth',
    rich: 'wealth',
    rooms: 'room',
    cp: 'cp',
    svip: 'svip',
  };
  const response = await getRankings({
    category: catMap[category] || category,
    period,
  });
  return response?.data || [];
}

export default {
  getRankings,
  getLuckyGiftRecords,
  getLeaderboards,
};
