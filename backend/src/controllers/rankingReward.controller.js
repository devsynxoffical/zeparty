import rankingRewardService from '../services/rankingReward.service.js';

export async function getAdminRankingEvents(req, res, next) {
  try {
    const { status, eventType, country, search } = req.query;
    const result = await rankingRewardService.listRankingEventsForAdmin({ status, eventType, country, search });
    return res.status(200).json({
      success: true,
      message: 'Ranking reward events retrieved successfully',
      data: result.events,
      totalCount: result.totalCount,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminRankingEventById(req, res, next) {
  try {
    const { id } = req.params;
    const event = await rankingRewardService.getRankingEventById(id);
    return res.status(200).json({
      success: true,
      data: event,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminCreateRankingEvent(req, res, next) {
  try {
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const event = await rankingRewardService.createRankingEvent(req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Ranking reward event created successfully',
      data: event,
    });
  } catch (err) {
    next(err);
  }
}

export async function putAdminUpdateRankingEvent(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await rankingRewardService.updateRankingEvent(id, req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Ranking reward event updated successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminPauseOrCancelEvent(req, res, next) {
  try {
    const { id } = req.params;
    const { action, reason } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await rankingRewardService.pauseOrCancelRankingEvent(id, {
      action,
      reason,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: `Event status updated to ${updated.status}`,
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminDistributeRewards(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await rankingRewardService.distributeEventRewards(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: 'Event rewards settled and distributed successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getUserEventLeaderboard(req, res, next) {
  try {
    const { id } = req.params;
    const userCountryCode = req.user?.countryCode || req.query.countryCode;

    const data = await rankingRewardService.getLiveLeaderboardForUsers(id, { userCountryCode });

    return res.status(200).json({
      success: true,
      data,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getAdminRankingEvents,
  getAdminRankingEventById,
  postAdminCreateRankingEvent,
  putAdminUpdateRankingEvent,
  postAdminPauseOrCancelEvent,
  postAdminDistributeRewards,
  getUserEventLeaderboard,
};
