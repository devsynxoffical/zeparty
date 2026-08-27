// ============================================================
// ZeParty Admin Portal — Leaderboards Service (JavaScript)
// ============================================================

import {
  MOCK_LEADERBOARD_RICH,
  MOCK_LEADERBOARD_HOSTS,
} from '../../mocks/leaderboards.mock';

export async function getLeaderboards(period = 'daily', category = 'hosts') {
  await new Promise((res) => setTimeout(res, 200));
  if (category === 'gifters') {
    return [...MOCK_LEADERBOARD_RICH];
  }
  return [...MOCK_LEADERBOARD_HOSTS];
}
