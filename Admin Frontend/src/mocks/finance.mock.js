export const financeDashboardMock = {
  grossRechargeRevenue: 1250000.50,
  netPlatformRevenue: 450000.25,
  hostEarnings: 600000.00,
  agencyCommission: 150000.00,
  platformProfit: 50000.25,
  giftRevenue: 800000.00,
  pkGameRevenue: 450000.50,
  pendingSettlement: 75000.00,
};

export const financeRevenueChartMock = [
  { label: 'Mon', revenue: 15000 },
  { label: 'Tue', revenue: 18000 },
  { label: 'Wed', revenue: 16500 },
  { label: 'Thu', revenue: 22000 },
  { label: 'Fri', revenue: 28000 },
  { label: 'Sat', revenue: 35000 },
  { label: 'Sun', revenue: 32000 },
];

export const financeSettlementsMock = [
  { id: 'SET-9001', period: '2026-07', entity: 'Host_Alpha', gross: 5000, commission: 500, net: 4500, status: 'PAID', date: '2026-08-01T10:00:00Z' },
  { id: 'SET-9002', period: '2026-07', entity: 'Agency_Beta', gross: 15000, commission: 3000, net: 12000, status: 'PAID', date: '2026-08-02T11:00:00Z' },
  { id: 'SET-9003', period: '2026-08 (W1)', entity: 'Host_Gamma', gross: 1200, commission: 120, net: 1080, status: 'APPROVED', date: '2026-08-10T09:00:00Z' },
  { id: 'SET-9004', period: '2026-08 (W2)', entity: 'Host_Delta', gross: 800, commission: 80, net: 720, status: 'PENDING', date: '2026-08-17T08:30:00Z' },
  { id: 'SET-9005', period: '2026-08 (W2)', entity: 'Agency_Zeta', gross: 4500, commission: 900, net: 3600, status: 'REJECTED', date: '2026-08-18T14:15:00Z' },
  { id: 'SET-9006', period: '2026-07', entity: 'Host_Epsilon', gross: 3000, commission: 300, net: 2700, status: 'PAID', date: '2026-08-01T10:05:00Z' },
  { id: 'SET-9007', period: '2026-07', entity: 'Agency_Omega', gross: 25000, commission: 5000, net: 20000, status: 'PAID', date: '2026-08-02T11:30:00Z' },
  { id: 'SET-9008', period: '2026-08 (W1)', entity: 'Host_Theta', gross: 500, commission: 50, net: 450, status: 'APPROVED', date: '2026-08-10T09:15:00Z' },
  { id: 'SET-9009', period: '2026-08 (W2)', entity: 'Host_Iota', gross: 2200, commission: 220, net: 1980, status: 'PENDING', date: '2026-08-17T08:45:00Z' },
  { id: 'SET-9010', period: '2026-08 (W2)', entity: 'Agency_Sigma', gross: 8000, commission: 1600, net: 6400, status: 'PENDING', date: '2026-08-17T15:00:00Z' },
];
