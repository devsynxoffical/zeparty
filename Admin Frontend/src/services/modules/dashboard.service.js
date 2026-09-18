import apiClient from '../api';

export async function getDashboardStats() {
  const [walletRes, usersRes, roomsRes, hostsRes] = await Promise.allSettled([
    apiClient.get('/v1/wallet/stats'),
    apiClient.get('/v1/admin/users', { params: { limit: 1 } }),
    apiClient.get('/v1/admin/rooms', { params: { limit: 1 } }),
    apiClient.get('/v1/admin/hosts', { params: { limit: 1 } }),
  ]);

  const wallet = walletRes.status === 'fulfilled' ? walletRes.value.data?.data || {} : {};
  const totalUsers = usersRes.status === 'fulfilled' ? usersRes.value.data?.pagination?.total || 0 : 0;
  const activeRooms = roomsRes.status === 'fulfilled' ? roomsRes.value.data?.pagination?.total || roomsRes.value.data?.data?.length || 0 : 0;
  const totalHosts = hostsRes.status === 'fulfilled' ? hostsRes.value.data?.pagination?.total || hostsRes.value.data?.data?.length || 0 : 0;

  return {
    totalRevenue: Number(wallet.totalRechargedUSD || 0),
    totalUsers,
    activeRooms,
    activeHosts: totalHosts,
    concurrentViewers: 0,
    coinSalesToday: Number(wallet.totalRechargedUSD || 0),
    coinsSoldToday: Number(wallet.totalCoins || 0),
    giftsSentToday: 0,
    giftCoinsVolumeToday: Number(wallet.totalDiamonds || 0),
    totalCoinsInCirculation: Number(wallet.totalCoins || 0),
    totalDiamondsInCirculation: Number(wallet.totalDiamonds || 0),
    pendingHostVerifications: 0,
    pendingAgencyVerifications: 0,
    revenueGrowthPercent: 0,
    roomsGrowthPercent: 0,
    viewersGrowthPercent: 0,
  };
}

export async function getDashboardCharts() {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const today = new Date();
  const past7Days = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    past7Days.push({
      label: days[d.getDay()],
      value: 0,
    });
  }

  return {
    userActivity: past7Days.map(d => ({ ...d })),
    streamingActivity: past7Days.map(d => ({ ...d })),
    revenue: past7Days.map(d => ({ ...d })),
  };
}

export async function getDashboardContent() {
  const [hostsRes, roomsRes, auditRes] = await Promise.allSettled([
    apiClient.get('/v1/admin/hosts', { params: { limit: 5 } }),
    apiClient.get('/v1/admin/rooms', { params: { limit: 5 } }),
    apiClient.get('/v1/admin/audit-logs', { params: { limit: 5 } }),
  ]);

  const hosts = hostsRes.status === 'fulfilled' ? hostsRes.value.data?.data || [] : [];
  const rooms = roomsRes.status === 'fulfilled' ? roomsRes.value.data?.data || [] : [];
  const audits = auditRes.status === 'fulfilled' ? auditRes.value.data?.data || [] : [];

  return {
    topHosts: hosts.slice(0, 5).map((h, idx) => ({
      id: h.id,
      rank: idx + 1,
      displayName: h.user?.profile?.displayName || h.user?.username || `Host ${h.id.slice(0, 6)}`,
      username: h.user?.username || `@${h.id.slice(0, 6)}`,
      totalViewers: 0,
      hoursStreamed: 0,
      totalEarnings: Number(h.totalDiamondsEarnedMonth || 0),
      isVerified: Boolean(h.isAgencyVerified || h.isKYCVerified),
    })),
    topContent: rooms.slice(0, 5).map((r, idx) => ({
      id: r.id,
      rank: idx + 1,
      title: r.title || 'Untitled Room',
      hostName: r.owner?.username || 'Host',
      category: r.category || 'Live',
      duration: 'Live',
      viewers: Number(r.activeMembersCount || 0),
    })),
    recentActivities: audits.slice(0, 5).map((a) => ({
      id: a.id,
      type: a.action?.toLowerCase() || 'audit_log',
      description: a.details?.message || `${a.action} on ${a.resourceType || 'system'}`,
      adminName: a.admin?.username || a.admin?.email || 'System Admin',
      timestamp: a.createdAt,
    })),
  };
}

export default {
  getDashboardStats,
  getDashboardCharts,
  getDashboardContent,
};

