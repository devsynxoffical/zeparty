// ============================================================
// ZeParty Admin Portal — Reports & Analytics Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getReportCards() {
  const [usersRes, statsRes] = await Promise.allSettled([
    apiClient.get('/v1/admin/users', { params: { limit: 1 } }),
    apiClient.get('/v1/wallet/stats'),
  ]);

  const totalUsers = usersRes.status === 'fulfilled' ? Number(usersRes.value.data?.pagination?.total || 0) : 0;
  const stats = statsRes.status === 'fulfilled' ? statsRes.value.data?.data || {} : {};

  return {
    totalRegisteredUsers: totalUsers,
    activeMonthlyUsers: totalUsers > 0 ? totalUsers : 0,
    totalTurnoverUSD: Number(stats.totalRechargedUSD || 0),
    totalCirculatingCoins: Number(stats.totalCoins || 0),
  };
}

export async function getUserGrowthChart() {
  try {
    const res = await apiClient.get('/v1/admin/users', { params: { limit: 100 } });
    const users = res.data?.data || [];
    if (!users.length) return [];

    // Group by month from actual registered users
    const monthCounts = {};
    users.forEach((u) => {
      const month = u.createdAt ? new Date(u.createdAt).toLocaleString('default', { month: 'short' }) : 'Recent';
      monthCounts[month] = (monthCounts[month] || 0) + 1;
    });

    return Object.entries(monthCounts).map(([period, count]) => ({
      period,
      users: count,
    }));
  } catch {
    return [];
  }
}

export async function getDeviceBreakdown() {
  try {
    const res = await apiClient.get('/v1/admin/users', { params: { limit: 50 } });
    const users = res.data?.data || [];
    if (!users.length) return [];

    let androidCount = 0;
    let iosCount = 0;
    users.forEach((u) => {
      if (u.deviceType?.toLowerCase().includes('ios')) iosCount++;
      else androidCount++;
    });

    const total = androidCount + iosCount;
    if (!total) return [];

    return [
      { platform: 'Android (Flutter)', share: Math.round((androidCount / total) * 100) },
      { platform: 'iOS (Flutter)', share: Math.round((iosCount / total) * 100) },
    ];
  } catch {
    return [];
  }
}

export async function getCountryBreakdown() {
  try {
    const res = await apiClient.get('/v1/admin/users', { params: { limit: 100 } });
    const users = res.data?.data || [];
    if (!users.length) return [];

    const countryCounts = {};
    users.forEach((u) => {
      const c = u.country || 'Global';
      countryCounts[c] = (countryCounts[c] || 0) + 1;
    });

    const total = users.length;
    return Object.entries(countryCounts).map(([country, count]) => ({
      country,
      code: country.slice(0, 2).toUpperCase(),
      users: count,
      percentage: Math.round((count / total) * 100),
    }));
  } catch {
    return [];
  }
}

export default {
  getReportCards,
  getUserGrowthChart,
  getDeviceBreakdown,
  getCountryBreakdown,
};
