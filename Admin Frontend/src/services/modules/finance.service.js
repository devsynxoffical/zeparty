import { financeDashboardMock, financeRevenueChartMock, financeSettlementsMock } from '../../mocks/finance.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let settlements = [...financeSettlementsMock];

export async function getFinanceDashboard() { await delay(); return { ...financeDashboardMock }; }
export async function getRevenueChart() { await delay(); return [...financeRevenueChartMock]; }
export async function getSettlements() { await delay(); return [...settlements]; }
export async function updateSettlementStatus(id, status) {
  await delay();
  settlements = settlements.map(s => s.id === id ? { ...s, status } : s);
  return settlements.find(s => s.id === id);
}
