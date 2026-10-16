import rechargeRewardService from '../services/rechargeReward.service.js';

export async function getCurrentEvent(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const data = await rechargeRewardService.getCurrentEventWithUserProgress(userId);
    return res.status(200).json({
      success: true,
      message: 'Recharge reward event and user progress retrieved successfully',
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function claimMilestone(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const { eventId, milestoneLevel } = req.body;
    const result = await rechargeRewardService.claimMilestoneReward(userId, { eventId, milestoneLevel });

    return res.status(200).json({
      success: true,
      message: `🎉 Milestone level ${result.claim.milestoneLevel} reward claimed successfully!`,
      data: result,
    });
  } catch (err) {
    if (err.statusCode) {
      return res.status(err.statusCode).json({
        success: false,
        message: err.message,
        error: { code: err.code || 'CLAIM_ERROR' },
      });
    }
    next(err);
  }
}

export async function getClaimHistory(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const { limit = 20 } = req.query;
    const claims = await rechargeRewardService.getUserClaimHistory(userId, { limit: Number(limit) });

    return res.status(200).json({
      success: true,
      data: claims,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminEvents(req, res, next) {
  try {
    const events = await rechargeRewardService.getAdminEvents();
    return res.status(200).json({
      success: true,
      data: events,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminEvent(req, res, next) {
  try {
    const adminId = req.auth?.userId;
    const adminName = req.admin?.name || 'Administrator';

    const event = await rechargeRewardService.createOrUpdateEvent(req.body, { adminId, adminName });
    return res.status(200).json({
      success: true,
      message: 'Recharge reward event saved successfully',
      data: event,
    });
  } catch (err) {
    if (err.statusCode) {
      return res.status(err.statusCode).json({
        success: false,
        message: err.message,
      });
    }
    next(err);
  }
}

export async function patchAdminToggleEvent(req, res, next) {
  try {
    const { id } = req.params;
    const { isActive } = req.body;
    const adminId = req.auth?.userId;
    const adminName = req.admin?.name || 'Administrator';

    const updated = await rechargeRewardService.toggleEventStatus(id, isActive, { adminId, adminName });
    return res.status(200).json({
      success: true,
      message: `Event status updated to ${isActive ? 'ACTIVE' : 'INACTIVE'}`,
      data: updated,
    });
  } catch (err) {
    if (err.statusCode) {
      return res.status(err.statusCode).json({
        success: false,
        message: err.message,
      });
    }
    next(err);
  }
}

export default {
  getCurrentEvent,
  claimMilestone,
  getClaimHistory,
  getAdminEvents,
  postAdminEvent,
  patchAdminToggleEvent,
};
