export const moderationStatsMock = {
  reportsToday: 145,
  pendingReview: 32,
  actionedToday: 110,
  appealsPending: 15,
};

export const moderationReportsMock = [
  { id: 'REP-5001', targetType: 'User', targetId: 'User_X', reason: 'Spam/Scam', reporter: 'User_Y', status: 'NEW', priority: 'HIGH', date: '2026-08-19T10:15:00Z' },
  { id: 'REP-5002', targetType: 'Room', targetId: 'Room_Live_12', reason: 'Inappropriate Content', reporter: 'User_Z', status: 'REVIEWING', priority: 'URGENT', date: '2026-08-19T09:30:00Z' },
  { id: 'REP-5003', targetType: 'Host', targetId: 'Host_Alpha', reason: 'Harassment', reporter: 'User_A', status: 'ACTIONED', priority: 'MEDIUM', date: '2026-08-18T14:20:00Z' },
  { id: 'REP-5004', targetType: 'Message', targetId: 'Msg_89012', reason: 'Hate Speech', reporter: 'System', status: 'NEW', priority: 'HIGH', date: '2026-08-19T11:05:00Z' },
  { id: 'REP-5005', targetType: 'User', targetId: 'User_B', reason: 'Fake Profile', reporter: 'User_C', status: 'REJECTED', priority: 'LOW', date: '2026-08-17T16:45:00Z' },
  { id: 'REP-5006', targetType: 'Host', targetId: 'Host_Beta', reason: 'Off-platform trading', reporter: 'User_D', status: 'REVIEWING', priority: 'HIGH', date: '2026-08-19T08:10:00Z' },
  { id: 'REP-5007', targetType: 'Room', targetId: 'Room_Party_55', reason: 'Underage user', reporter: 'System', status: 'NEW', priority: 'URGENT', date: '2026-08-19T11:20:00Z' },
  { id: 'REP-5008', targetType: 'User', targetId: 'User_E', reason: 'Abusive language', reporter: 'User_F', status: 'ACTIONED', priority: 'MEDIUM', date: '2026-08-18T09:15:00Z' },
];
