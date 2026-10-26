import leaderboardService from '../services/leaderboard.service.js';

export async function getRankings(req, res, next) {
  try {
    const viewerUserId = req.auth?.userId || null;
    const { category = 'wealth', period = 'daily', limit = 30 } = req.query;
    let data = [];

    switch ((category || '').toLowerCase()) {
      case 'room':
        data = await leaderboardService.getRoomRankings({ period, limit, viewerUserId });
        break;
      case 'charm':
        data = await leaderboardService.getCharmRankings({ period, limit, viewerUserId });
        break;
      case 'cp':
      case 'couple':
        data = await leaderboardService.getCpRankings({ period, limit, viewerUserId });
        break;
      case 'svip':
      case 'vip':
        data = await leaderboardService.getSvipRankings({ limit, viewerUserId });
        break;
      case 'aristocratic':
      case 'aristocracy':
      case 'noble':
        data = await leaderboardService.getAristocraticRankings({ limit, viewerUserId });
        break;
      case 'lucky':
        data = await leaderboardService.getLuckyRankings({ period, limit, viewerUserId });
        break;
      case 'wealth':
      default:
        data = await leaderboardService.getWealthRankings({ period, limit, viewerUserId });
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
