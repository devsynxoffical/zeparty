// ============================================================
// ZeParty Admin Portal — Users Service (JavaScript)
// Server-authoritative PostgreSQL User Management Integration
// ============================================================

import apiClient from '../api';

function formatUserRecord(u) {
  if (!u) return null;
  const wallet = u.wallet || {};
  const profile = u.profile || {};
  const hostProfile = u.hostProfile || {};

  const cleanDisplayName =
    (profile.displayName && profile.displayName.trim() && profile.displayName !== 'ZeParty Member')
      ? profile.displayName.trim()
      : (u.displayName && u.displayName.trim() ? u.displayName.trim() : (u.username || `User ${u.id.slice(0, 6)}`));

  return {
    id: u.id,
    username: u.username || (u.phone ? `user_${u.phone.replace(/\D/g, '').slice(-4)}` : `user_${u.id.slice(0, 8)}`),
    displayName: cleanDisplayName,
    email: u.email || '',
    phone: u.phone || '',
    country: u.countryCode || 'PK',
    region: u.countryCode === 'PK' ? 'South Asia' : 'Global',
    status: (u.status || 'ACTIVE').toLowerCase(),
    coins: Number(wallet.coinBalance || u.coins || 0),
    diamonds: Number(wallet.diamondBalance || u.diamonds || 0),
    clearedBalance: Number(wallet.diamondBalance || u.clearedBalance || 0),
    totalGifted: Number(profile.totalSpentCoins || u.totalGifted || 0),
    vip: Boolean(u.isVip || (profile.level && profile.level >= 5)),
    vipLevel: profile.level && profile.level >= 5 ? `VIP ${Math.min(10, profile.level)}` : 'Standard',
    svipLevel: profile.level && profile.level >= 8 ? `SVIP ${profile.level}` : null,
    isHost: Boolean(u.isHost || hostProfile.id || u.userType === 'HOST'),
    hostTier: hostProfile.hostLevel ? `Tier ${hostProfile.hostLevel}` : u.isHost ? 'Active' : null,
    registeredAt: u.createdAt || new Date().toISOString(),
    lastActive: u.lastLoginAt || u.updatedAt || new Date().toISOString(),
    avatarUrl: u.avatarUrl || null,
    devices: (u.devices || []).map((d) => ({
      id: d.id,
      deviceName: d.deviceModel || 'Mobile Client',
      deviceType: d.platform || 'android',
      appVersion: d.appVersion || 'v1.0.0',
      ip: d.lastSeenIp || '127.0.0.1',
      loginTime: d.lastSeenAt || d.createdAt || new Date().toISOString(),
      status: d.isActive && !d.isBlocked ? 'active' : 'revoked',
    })),
    bankDetails: u.bankDetails || null,
    props: u.props || {
      avatarFrame: null,
      ride: null,
      chatBubble: null,
      badge: null,
      specialId: null,
    },
    bdCenterId: hostProfile.bdCenterId || null,
    agencyId: hostProfile.agencyId || null,
    agencyName: hostProfile.agency?.name || null,
  };
}

export async function getUsers(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/users', { params });
    const userList = res.data?.data || res.data?.users || (Array.isArray(res.data) ? res.data : []);
    const pagination = res.data?.pagination || {
      page: Number(params.page) || 1,
      limit: Number(params.limit) || 20,
      total: Array.isArray(userList) ? userList.length : 0,
      totalPages: 1,
    };

    const formatted = Array.isArray(userList)
      ? userList
          .filter((u) => !u.isOwner && u.username !== 'owner' && !u.email?.includes('owner@zeparty.app'))
          .map(formatUserRecord)
      : [];

    return {
      users: formatted,
      pagination: {
        ...pagination,
        total: Number(pagination.total || formatted.length),
      },
      data: formatted,
    };
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to load users from backend.');
  }
}

export async function getUserById(id) {
  try {
    const res = await apiClient.get(`/v1/admin/users/${id}`);
    const userData = res.data?.data || res.data?.user || res.data;
    if (userData && (userData.id || userData.username)) {
      return formatUserRecord(userData);
    }
    throw new Error('User not found');
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to load user details from backend.');
  }
}

export async function updateUserStatus(id, { status, reason }) {
  const backendStatus = status.toUpperCase();
  try {
    const res = await apiClient.patch(`/v1/admin/users/${id}/status`, {
      status: backendStatus,
      reason: reason || `Admin updated status to ${backendStatus}`,
    });
    const userData = res.data?.data || res.data?.user;
    if (userData) {
      return formatUserRecord(userData);
    }
    return { id, status: status.toLowerCase() };
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to update user status on backend.');
  }
}

export async function suspendUser(id, reason) {
  return updateUserStatus(id, { status: 'SUSPENDED', reason: reason || 'Account suspended by administrator' });
}

export async function banUser(id, reason) {
  return updateUserStatus(id, { status: 'BANNED', reason: reason || 'Account banned for policy violation' });
}

export async function unbanUser(id, reason) {
  return updateUserStatus(id, { status: 'ACTIVE', reason: reason || 'Account unbanned by administrator' });
}

export async function adjustUserBalance(id, amount, currencyType = 'coins', action = 'add', reason = '') {
  const isDiamond = String(currencyType).toLowerCase().includes('diamond');
  const asset = isDiamond ? 'DIAMONDS' : 'COINS';
  const direction = (action === 'add' || action === 'CREDIT' || action === 'credit') ? 'CREDIT' : 'DEBIT';

  try {
    const res = await apiClient.post('/v1/wallet/adjust', {
      targetUserId: id,
      asset,
      direction,
      amount: Number(amount),
      reason: reason || `Administrative balance adjustment (${action} ${amount} ${currencyType})`,
    });
    if (res.data && res.data.success) {
      return res.data;
    }
    return { success: true };
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to adjust user balance on backend.');
  }
}

export async function createUser(payload) {
  try {
    const res = await apiClient.post('/v1/admin/users', payload);
    if (res.data && res.data.success && (res.data.data || res.data.user)) {
      return formatUserRecord(res.data.data || res.data.user);
    }
    if (res.data && res.data.success) {
      return res.data;
    }
    throw new Error(res.data?.message || 'Failed to create user');
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to create user on backend.');
  }
}

export async function updateUser(id, payload) {
  try {
    const res = await apiClient.put(`/v1/admin/users/${id}`, payload);
    if (res.data && res.data.success && (res.data.data || res.data.user)) {
      return formatUserRecord(res.data.data || res.data.user);
    }
    if (res.data && res.data.success) {
      return res.data;
    }
    throw new Error(res.data?.message || 'Failed to update user');
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to update user on backend.');
  }
}

export async function deleteUser(id, reason = '') {
  try {
    const res = await apiClient.delete(`/v1/admin/users/${id}`, { data: { reason } });
    return res.data;
  } catch (err) {
    throw new Error(err.response?.data?.message || err.message || 'Failed to delete user on backend.');
  }
}

export default {
  getUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  updateUserStatus,
  suspendUser,
  banUser,
  unbanUser,
  adjustUserBalance,
};
