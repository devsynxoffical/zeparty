// ============================================================
// ZeParty Admin Portal — Dashboard Service (JavaScript)
// ============================================================

import {
  MOCK_DASHBOARD_STATS,
  MOCK_CHART_DATA,
  MOCK_TOP_HOSTS,
  MOCK_TOP_CONTENT,
  MOCK_RECENT_ACTIVITY,
} from '../../mocks/dashboard.mock';

export async function getDashboardStats() {
  await new Promise((res) => setTimeout(res, 200));
  return { ...MOCK_DASHBOARD_STATS };
}

export async function getDashboardCharts() {
  await new Promise((res) => setTimeout(res, 200));
  return MOCK_CHART_DATA;
}

export async function getDashboardContent() {
  await new Promise((res) => setTimeout(res, 200));
  return {
    topHosts: [...MOCK_TOP_HOSTS],
    topContent: [...MOCK_TOP_CONTENT],
    recentActivities: [...MOCK_RECENT_ACTIVITY],
  };
}
