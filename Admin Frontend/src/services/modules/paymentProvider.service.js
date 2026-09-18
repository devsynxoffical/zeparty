// ============================================================
// ZeParty Admin Portal — Payment Provider Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getPaymentProviders(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/payment-providers', { params });
    const items = res.data?.data || [];
    return items.map((p) => ({
      id: p.id,
      name: p.name,
      fee: p.feeDescription || '2.9% + $0.30',
      limits: p.limitsDescription || '$10 - $5,000',
      status: p.isActive ? 'ACTIVE' : 'DISABLED',
      apiKey: p.apiKey ? `${p.apiKey.slice(0, 6)}••••••••` : '••••••••',
      isSandbox: Boolean(p.isSandbox),
      webhookUrl: p.webhookUrl || '',
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    }));
  } catch (err) {
    console.warn('Failed to load payment providers:', err.message);
    return [];
  }
}

export async function getPaymentProviderById(id) {
  const res = await apiClient.get(`/v1/admin/payment-providers/${id}`);
  return res.data?.data;
}

export async function createPaymentProvider(data) {
  const res = await apiClient.post('/v1/admin/payment-providers', {
    name: data.name,
    apiKey: data.apiKey,
    apiSecret: data.apiSecret,
    webhookUrl: data.webhookUrl,
    webhookSecret: data.webhookSecret,
    isSandbox: data.isSandbox !== undefined ? Boolean(data.isSandbox) : true,
    isActive: data.isActive !== undefined ? Boolean(data.isActive) : true,
    feeDescription: data.fee || data.feeDescription,
    limitsDescription: data.limits || data.limitsDescription,
  });
  return res.data?.data;
}

export async function updatePaymentProvider(id, data) {
  const payload = {};
  if (data.fee !== undefined || data.feeDescription !== undefined) {
    payload.feeDescription = data.fee || data.feeDescription;
  }
  if (data.limits !== undefined || data.limitsDescription !== undefined) {
    payload.limitsDescription = data.limits || data.limitsDescription;
  }
  if (data.status !== undefined) {
    payload.isActive = data.status === 'ACTIVE';
  }
  if (data.isActive !== undefined) {
    payload.isActive = Boolean(data.isActive);
  }
  if (data.isSandbox !== undefined) {
    payload.isSandbox = Boolean(data.isSandbox);
  }
  if (data.apiKey) payload.apiKey = data.apiKey;
  if (data.apiSecret) payload.apiSecret = data.apiSecret;
  if (data.webhookUrl) payload.webhookUrl = data.webhookUrl;
  if (data.webhookSecret) payload.webhookSecret = data.webhookSecret;

  const res = await apiClient.put(`/v1/admin/payment-providers/${id}`, payload);
  return res.data?.data;
}

export default {
  getPaymentProviders,
  getPaymentProviderById,
  createPaymentProvider,
  updatePaymentProvider,
};
