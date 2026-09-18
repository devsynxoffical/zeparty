// ============================================================
// ZeParty Admin Portal — Transfer Rate Service (JavaScript)
// 100% Real Backend Driven via /v1/admin/economy/configs
// ============================================================

import apiClient from '../api';

export async function getTransferRates() {
  const res = await apiClient.get('/v1/admin/economy/configs');
  const configs = res?.data?.data || [];
  return configs.filter((c) => c.key?.includes('TRANSFER') || c.key?.includes('RATE'));
}

export async function updateTransferRate(id, updates) {
  const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(id)}`, {
    valueJson: updates,
    reason: updates.reason || 'Updated transfer rate configuration',
  });
  return res?.data || { success: true };
}

export async function publishTransferRate(id) {
  const res = await apiClient.post(`/v1/admin/economy/configs/${encodeURIComponent(id)}/restore`);
  return res?.data || { success: true };
}

export async function rollbackTransferRate(id, targetVersion) {
  const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(id)}`, {
    valueJson: { rollbackTo: targetVersion },
    reason: `Rolled back to version ${targetVersion}`,
  });
  return res?.data || { success: true };
}

export default {
  getTransferRates,
  updateTransferRate,
  publishTransferRate,
  rollbackTransferRate,
};
