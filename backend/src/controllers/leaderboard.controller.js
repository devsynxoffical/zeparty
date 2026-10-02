import leaderboardService from '../services/leaderboard.service.js';

export async function getRankings(req, res, next) {
  try {
    const { category = 'wealth', period = 'daily', limit = 30 } = req.query;
    let data = [];

    switch ((category || '').toLowerCase()) {
      case 'room':
        data = await leaderboardService.getRoomRankings({ period, limit });
        break;
      case 'charm':
        data = await leaderboardService.getCharmRankings({ period, limit });
        break;
      case 'cp':
        data = await leaderboardService.getCpRankings({ period, limit });
        break;
      case 'svip':
      case 'vip':
        data = await leaderboardService.getSvipRankings({ limit });
        break;
      case 'wealth':
      default:
        data = await leaderboardService.getWealthRankings({ period, limit });
        break;
    }

    return res.status(200).json({
      success: true,
      message: 'Leaderboard rankings retrieved successfully',
      category,
      period,
      data,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getRankings,
};
