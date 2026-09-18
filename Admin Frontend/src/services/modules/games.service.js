// ============================================================
// ZeParty Admin Portal — Canonical Games Service (JavaScript)
// 100% Real Backend Driven via /v1/admin/games
// ============================================================

import apiClient from '../api';

export async function getGames() {
  const res = await apiClient.get('/v1/admin/games');
  if (res?.data?.success && Array.isArray(res.data.data)) {
    return res.data.data;
  }
  return [];
}

export async function toggleGameStatus(id, newStatus) {
  const res = await apiClient.patch(`/v1/admin/games/${id}/status`, { isActive: Boolean(newStatus) });
  return res?.data || { success: true };
}

export async function updateGameConfig(id, config, operatorName = 'Super Admin', changeReason = 'Updated game configuration') {
  const res = await apiClient.put(`/v1/admin/games/${id}/config`, {
    ...config,
    operator: operatorName,
    reason: changeReason,
  });
  if (res?.data?.success) {
    return res.data.data;
  }
  return res?.data;
}

export default {
  getGames,
  toggleGameStatus,
  updateGameConfig,
};
