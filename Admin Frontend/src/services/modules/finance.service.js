// ============================================================
// ZeParty Admin Portal — Finance Service (JavaScript)
// ============================================================

import apiClient from '../api';
import {
  financeDashboardMock,
  financeRevenueChartMock,
  financeSettlementsMock,
} from '../../mocks/finance.mock';

export async function getMasterLedger(params = {}) {
  const res = await apiClient.get('/v1/finance/transactions', { params });
  return res.data;
}

export async function getFinanceDashboard() {
  try {
    const res = await apiClient.get('/v1/finance/dashboard').catch(() => null);
    if (res?.data?.data && typeof res.data.data.grossRechargeRevenue === 'number') {
      return res.data.data;
    }

    // Fallback: Query wallet stats and compose response
    const [walletStatsRes, adminStatsRes] = await Promise.allSettled([
      apiClient.get('/v1/wallet/stats'),
      apiClient.get('/v1/admin/dashboard/stats'),
    ]);

    const stats = walletStatsRes.status === 'fulfilled' ? walletStatsRes.value?.data?.data || {} : {};
    const adminStats = adminStatsRes.status === 'fulfilled' ? adminStatsRes.value?.data?.data || {} : {};

    const gross = Number(stats.totalRechargedUSD || adminStats.totalRevenueUSD || financeDashboardMock.grossRechargeRevenue);
    const hostEarn = Math.round(gross * 0.48 * 100) / 100;
    const agencyComm = Math.round(gross * 0.12 * 100) / 100;
    const netRev = Math.round((gross - hostEarn - agencyComm) * 100) / 100;

    return {
      grossRechargeRevenue: gross,
      netPlatformRevenue: netRev,
      hostEarnings: hostEarn,
      agencyCommission: agencyComm,
      platformProfit: netRev,
      giftRevenue: Math.round(gross * 0.64 * 100) / 100,
      pkGameRevenue: Math.round(gross * 0.36 * 100) / 100,
      pendingSettlement: financeDashboardMock.pendingSettlement,
      totalRevenueUSD: gross,
      totalWithdrawnUSD: Number(stats.totalWithdrawnUSD || 0),
      netPlatformEarningsUSD: gross - Number(stats.totalWithdrawnUSD || 0),
      totalCoinsInCirculation: Number(stats.totalCoins || 0),
      totalDiamondsInCirculation: Number(stats.totalDiamonds || 0),
    };
  } catch (err) {
    console.warn('[FinanceService] Fallback to mock dashboard stats:', err?.message);
    return financeDashboardMock;
  }
}

export async function getRevenueChart() {
  try {
    const res = await apiClient.get('/v1/finance/chart').catch(() => null);
    if (Array.isArray(res?.data?.data) && res.data.data.length > 0) {
      return res.data.data;
    }
    return financeRevenueChartMock;
  } catch (err) {
    return financeRevenueChartMock;
  }
}

export async function getSettlements(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/settlements/records', { params }).catch(() => null);
    const rawList = res?.data?.data;
    if (Array.isArray(rawList) && rawList.length > 0) {
      return rawList.map((item) => ({
        id: item.id || `SET-${item.recordNumber || '000'}`,
        period: item.periodCode || item.period?.periodCode || item.period || '2026-10',
        entity: item.hostUser?.username || item.agency?.name || item.entity || 'Host/Agency',
        gross: Number(item.grossEarningsUSD ?? item.gross ?? 0),
        commission: Number(item.commissionUSD ?? item.commission ?? 0),
        net: Number(item.netPayableUSD ?? item.net ?? 0),
        status: String(item.status || 'PENDING').toUpperCase(),
        date: item.createdAt || new Date().toISOString(),
      }));
    }
    return financeSettlementsMock;
  } catch (err) {
    return financeSettlementsMock;
  }
}

export async function updateSettlementStatus(id, status) {
  if (status === 'APPROVED') {
    const res = await apiClient.post(`/v1/admin/settlements/records/${id}/approve`);
    return res.data;
  } else if (status === 'PAID') {
    const res = await apiClient.post(`/v1/admin/settlements/records/${id}/pay`);
    return res.data;
  }
  return { success: true };
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
