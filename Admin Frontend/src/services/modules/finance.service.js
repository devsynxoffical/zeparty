// ============================================================
// ZeParty Admin Portal — Finance Service (JavaScript)
// All data comes from the backend / database. No mock fallbacks.
// ============================================================

import apiClient from '../api';

// Backend settlement statuses -> statuses used by the admin UI
const SETTLEMENT_STATUS_MAP = {
  OPEN: 'PENDING',
  CALCULATING: 'PENDING',
  CALCULATED: 'PENDING',
  PENDING_APPROVAL: 'PENDING',
  APPROVED: 'APPROVED',
  PROCESSING: 'APPROVED',
  PAID: 'PAID',
  CANCELLED: 'REJECTED',
};

export function mapSettlementRecord(item) {
  const rawStatus = String(item.status || '').toUpperCase();
  return {
    id: item.id,
    period: item.settlementPeriod?.periodCode || item.periodCode || '',
    entity: item.user?.username || item.recipientType || '',
    recipientType: item.recipientType || '',
    gross: Number(item.grossEarningsUSD ?? 0),
    commission: Number(item.commissionUSD ?? 0),
    net: Number(item.netPayableUSD ?? 0),
    status: SETTLEMENT_STATUS_MAP[rawStatus] || rawStatus,
    rawStatus,
    date: item.createdAt,
  };
}

export async function getMasterLedger(params = {}) {
  const res = await apiClient.get('/v1/finance/transactions', { params });
  return res.data;
}

export async function getFinanceDashboard() {
  const res = await apiClient.get('/v1/finance/dashboard');
  return res.data?.data || null;
}

export async function getRevenueChart(period = 'Week') {
  const res = await apiClient.get('/v1/finance/chart', { params: { period } });
  return Array.isArray(res.data?.data) ? res.data.data : [];
}

export async function getSettlements(params = {}) {
  const res = await apiClient.get('/v1/admin/settlements/records', { params: { limit: 100, ...params } });
  const rawList = res.data?.data;
  const list = Array.isArray(rawList) ? rawList : (Array.isArray(rawList?.items) ? rawList.items : (Array.isArray(rawList?.records) ? rawList.records : []));
  return list.map(mapSettlementRecord);
}

export async function updateSettlementStatus(id, status) {
  if (status === 'APPROVED') {
    const res = await apiClient.post(`/v1/admin/settlements/records/${id}/approve`);
    return res.data;
  }
  if (status === 'PAID') {
    const res = await apiClient.post(`/v1/admin/settlements/records/${id}/pay`);
    return res.data;
  }
  throw new Error(`Unsupported settlement status transition: ${status}`);
}


export async function getSettlementPeriods(params = {}) {
  const res = await apiClient.get('/v1/admin/settlements/periods', { params });
  return res.data?.data || [];
}

export async function calculateSettlementPeriod(payload) {
  const res = await apiClient.post('/v1/admin/settlements/calculate', payload);
  return res.data;
}

export default {
  getMasterLedger,
  getFinanceDashboard,
  getRevenueChart,
  getSettlements,
  updateSettlementStatus,
  getSettlementPeriods,
  calculateSettlementPeriod,
};
