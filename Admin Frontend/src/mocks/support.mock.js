export const supportStatsMock = {
  openTickets: 124,
  highPriority: 18,
  unassigned: 45,
  waitingForReply: 32,
  resolvedToday: 86,
};

export const supportTicketsMock = [
  { id: 'TKT-7001', user: 'User_John', subject: 'Recharge Failed but money deducted', category: 'Recharge', priority: 'HIGH', assignedTo: 'Unassigned', status: 'OPEN', created: '2026-08-19T09:15:00Z', updated: '2026-08-19T09:15:00Z' },
  { id: 'TKT-7002', user: 'Host_Alice', subject: 'Withdrawal delayed for 3 days', category: 'Withdrawal', priority: 'URGENT', assignedTo: 'Admin_Sarah', status: 'IN_PROGRESS', created: '2026-08-16T14:30:00Z', updated: '2026-08-19T10:05:00Z' },
  { id: 'TKT-7003', user: 'User_Bob', subject: 'Cannot access my VIP privileges', category: 'Account', priority: 'MEDIUM', assignedTo: 'Admin_Mike', status: 'WAITING', created: '2026-08-18T11:20:00Z', updated: '2026-08-18T16:45:00Z' },
  { id: 'TKT-7004', user: 'User_Charlie', subject: 'Reported a scammer in my room', category: 'Report', priority: 'HIGH', assignedTo: 'Unassigned', status: 'OPEN', created: '2026-08-19T10:30:00Z', updated: '2026-08-19T10:30:00Z' },
  { id: 'TKT-7005', user: 'Agency_Global', subject: 'Commission calculation issue', category: 'Agency', priority: 'HIGH', assignedTo: 'Admin_John', status: 'RESOLVED', created: '2026-08-15T09:00:00Z', updated: '2026-08-19T08:15:00Z' },
  { id: 'TKT-7006', user: 'User_Dave', subject: 'App crashes when joining PK', category: 'Technical', priority: 'LOW', assignedTo: 'Admin_Mike', status: 'CLOSED', created: '2026-08-10T15:45:00Z', updated: '2026-08-12T11:30:00Z' },
  { id: 'TKT-7007', user: 'Host_Zeta', subject: 'Change agency request', category: 'Host', priority: 'MEDIUM', assignedTo: 'Unassigned', status: 'OPEN', created: '2026-08-19T11:10:00Z', updated: '2026-08-19T11:10:00Z' },
  { id: 'TKT-7008', user: 'User_Eve', subject: 'Lost coins during game crash', category: 'Recharge', priority: 'MEDIUM', assignedTo: 'Admin_Sarah', status: 'IN_PROGRESS', created: '2026-08-18T13:20:00Z', updated: '2026-08-19T09:45:00Z' },
];
