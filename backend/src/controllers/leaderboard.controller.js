import leaderboardService from '../services/leaderboard.service.js';

export async function getRankings(req, res, next) {
  try {
    const viewerUserId = req.auth?.userId || null;
    const {
      category = 'wealth',
      period = 'daily',
      scope = 'GLOBAL',
      scopeValue = null,
      country = null,
      countryCode = null,
      region = null,
      limit = 30,
      search = null,
    } = req.query;

    const result = await leaderboardService.getUnifiedRankings({
      category,
      period,
      scope,
      scopeValue: scopeValue || country || countryCode,
      countryCode: countryCode || country || scopeValue,
      region,
      limit,
      search,
      viewerUserId,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getAdminRankings(req, res, next) {
  try {
    const {
      category = 'wealth',
      period = 'daily',
      scope = 'GLOBAL',
      scopeValue = null,
      country = null,
      countryCode = null,
      region = null,
      limit = 50,
      search = null,
    } = req.query;

    const result = await leaderboardService.getUnifiedRankings({
      category,
      period,
      scope,
      scopeValue: scopeValue || country || countryCode,
      countryCode: countryCode || country || scopeValue,
      region,
      limit,
      search,
      viewerUserId: null,
    });

    return res.status(200).json(result);
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
  getAdminRankings,
  getLuckyGiftRecords,
};
