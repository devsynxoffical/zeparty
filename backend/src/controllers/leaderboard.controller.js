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
      case 'couple':
        data = await leaderboardService.getCpRankings({ period, limit });
        break;
      case 'svip':
      case 'vip':
        data = await leaderboardService.getSvipRankings({ limit });
        break;
      case 'aristocratic':
      case 'aristocracy':
      case 'noble':
        data = await leaderboardService.getAristocraticRankings({ limit });
        break;
      case 'lucky':
        data = await leaderboardService.getLuckyRankings({ period, limit });
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

export async function getLuckyGiftRecords(req, res, next) {
  try {
    const { type = 'lucky', page = 1, limit = 20 } = req.query;
    const result = await leaderboardService.getLuckyGiftRecords({ type, page, limit });

    return res.status(200).json({
      success: true,
      message: 'Lucky gift records retrieved successfully',
      data: result.records,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getRankings,
  getLuckyGiftRecords,
};
