// ============================================================
// ZeParty Admin Portal — Exchange Rate Service (JavaScript)
// 100% Real Backend Driven via /v1/admin/economy/configs
// ============================================================

import apiClient from '../api';

export async function getExchangeRates() {
  const res = await apiClient.get('/v1/admin/economy/configs');
  const configs = res?.data?.data || [];
  return configs.filter((c) => c.key?.includes('EXCHANGE') || c.key?.includes('RATE') || c.key?.includes('USD'));
}

export async function createRateDraft(payload) {
  const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(payload.key || 'EXCHANGE_RATE_DRAFT')}`, {
    valueJson: payload,
    reason: payload.reason || 'Draft exchange rate',
  });
  return res?.data?.data || payload;
}

export async function updateRate(id, updates) {
  const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(id)}`, {
    valueJson: updates,
    reason: updates.reason || 'Updated exchange rate',
  });
  return res?.data || { success: true };
}

export async function approveRate(id, approverName = 'Finance Director') {
  const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(id)}`, {
    valueJson: { approvedBy: approverName, approvedAt: new Date().toISOString() },
    reason: `Approved by ${approverName}`,
  });
  return res?.data || { success: true };
}

export async function publishRate(id) {
  const res = await apiClient.post(`/v1/admin/economy/configs/${encodeURIComponent(id)}/restore`);
  return res?.data || { success: true };
}

export async function rollbackRate(id, targetVersion) {
  const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(id)}`, {
    valueJson: { rollbackTo: targetVersion },
    reason: `Rolled back exchange rate to ${targetVersion}`,
  });
  return res?.data || { success: true };
}

export default {
  getExchangeRates,
  createRateDraft,
  updateRate,
  approveRate,
  publishRate,
  rollbackRate,
};
