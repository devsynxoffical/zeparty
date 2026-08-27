// ============================================================
// ZeParty Admin Portal — Mock Audit Logs
// ============================================================

export function generateMockAuditLogs() {
  const logs = [];
  const now = Date.now();

  const add = (offsetHrs, module, action, targetType, targetId, targetName, beforeValue, afterValue, reason, status = 'SUCCESS', riskLevel = 'LOW', meta = {}) => {
    logs.push({
      id: `log-${now - Math.floor(Math.random() * 100000)}`,
      timestamp: new Date(now - offsetHrs * 3600000).toISOString(),
      operatorId: 'admin-1',
      operatorName: 'Super Admin',
      operatorRole: 'Super Admin',
      module,
      action,
      targetType,
      targetId,
      targetName,
      beforeValue,
      afterValue,
      reason,
      status,
      riskLevel,
      metadata: { ip: '127.0.0.1', ...meta }
    });
  };

  // 1. Users
  add(1, 'Users', 'USER_BANNED', 'user', 'USR-1002', 'BadUser99', { status: 'active' }, { status: 'banned' }, 'Repeated harassment', 'SUCCESS', 'HIGH');
  add(24, 'Users', 'USER_UNBANNED', 'user', 'USR-1005', 'ReformedUser', { status: 'banned' }, { status: 'active' }, 'Appeal approved', 'SUCCESS', 'MEDIUM');
  add(48, 'Users', 'BALANCE_ADJUSTED', 'user', 'usr-1', 'TestUser', { coins: 500 }, { coins: 1500 }, 'Manual compensation for bug', 'SUCCESS', 'HIGH');
  add(50, 'Users', 'VIP_GRANTED', 'user', 'usr-1', 'TestUser', { vip: false }, { vip: true, vipLevel: 'Gold' }, 'Event winner', 'SUCCESS', 'MEDIUM');

  // 2. Hosts & Agencies
  add(2, 'Hosts', 'HOST_APPROVED', 'host', 'HST-8821', 'Singer_Star', { status: 'pending' }, { status: 'approved' }, 'Passed ID verification', 'SUCCESS', 'MEDIUM');
  add(26, 'Hosts', 'HOST_REJECTED', 'host', 'HST-9912', 'Fake_Host', { status: 'pending' }, { status: 'rejected' }, 'Invalid documentation', 'SUCCESS', 'LOW');
  add(5, 'Agencies', 'AGENCY_APPROVED', 'agency', 'AGC-551', 'StarTalent', { status: 'pending' }, { status: 'approved' }, 'Business verified', 'SUCCESS', 'HIGH');

  // 3. Rooms
  add(0.5, 'Live Rooms', 'ROOM_MUTED', 'room', 'room-1', 'Late Night Vibes', { roomMuted: false }, { roomMuted: true }, 'Inappropriate language detected', 'SUCCESS', 'MEDIUM');
  add(1.5, 'Live Rooms', 'ROOM_USER_KICKED', 'user', 'usr-troll', 'TrollMaster', null, null, 'Spamming chat', 'SUCCESS', 'LOW');

  // 4. PK & Events
  add(3, 'PK & Events', 'EVENT_CREATED', 'event', 'evt-1', 'Summer Rumble', null, { name: 'Summer Rumble', prizePool: 50000 }, 'Seasonal event', 'SUCCESS', 'LOW');
  add(25, 'PK & Events', 'EVENT_DISABLED', 'event', 'evt-2', 'Winter Clash', { status: 'ACTIVE' }, { status: 'DISABLED' }, 'Event ended', 'SUCCESS', 'LOW');

  // 5. Withdrawals
  add(4, 'Finance', 'WITHDRAWAL_APPROVED', 'withdrawal', 'WD-10482', 'Withdrawal WD-10482', { status: 'pending' }, { status: 'approved' }, 'Verified earnings', 'SUCCESS', 'HIGH');
  add(28, 'Finance', 'WITHDRAWAL_HELD', 'withdrawal', 'WD-10481', 'Withdrawal WD-10481', { status: 'pending' }, { status: 'held' }, 'Suspicious activity', 'SUCCESS', 'HIGH');

  // 6. Settings & Teams
  add(48, 'Settings', 'SETTING_UPDATED', 'setting', 'sys-cfg', 'Withdrawal Rule', { minAmount: 50 }, { minAmount: 100 }, 'Updated policy', 'SUCCESS', 'HIGH');
  add(72, 'Teams & Roles', 'ROLE_CHANGED', 'admin', 'admin-2', 'Moderator Joe', { role: 'Moderator' }, { role: 'Admin' }, 'Promoted', 'SUCCESS', 'HIGH');

  // Add more generic logs to pad it out
  for (let i = 0; i < 15; i++) {
    add(i * 5 + 10, 'Moderation', 'REPORT_REVIEWED', 'report', `REP-${i}`, `Report ${i}`, null, null, 'No violation found', 'SUCCESS', 'LOW');
  }

  return logs.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
}
