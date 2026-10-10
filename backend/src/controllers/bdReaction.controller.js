import bdReactionService from '../services/bdReaction.service.js';

export async function getAdminBDReactions(req, res, next) {
  try {
    const { status, country, search } = req.query;
    const result = await bdReactionService.listReactionsForAdmin({ status, country, search });
    return res.status(200).json({
      success: true,
      message: 'BD Reactions retrieved successfully',
      data: result.reactions,
      masterEnabled: result.masterEnabled,
      totalCount: result.totalCount,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminBDReaction(req, res, next) {
  try {
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const reaction = await bdReactionService.createReaction(req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'BD Reaction created successfully',
      data: reaction,
    });
  } catch (err) {
    next(err);
  }
}

export async function putAdminBDReaction(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await bdReactionService.updateReaction(id, req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'BD Reaction updated successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminToggleBDReaction(req, res, next) {
  try {
    const { id } = req.params;
    const { isActive } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await bdReactionService.toggleReactionStatus(id, {
      isActive,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: `BD Reaction is now ${updated.isActive ? 'Active' : 'Inactive'}`,
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminMasterSwitchBDReactions(req, res, next) {
  try {
    const { enabled } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdReactionService.setMasterSwitch({
      enabled,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: `BD Reaction Master Switch set to ${result.masterEnabled ? 'ENABLED' : 'DISABLED'}`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminBDReaction(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdReactionService.deleteReaction(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: 'BD Reaction deleted successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminEmergencyDisableBDReaction(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdReactionService.emergencyDisableReaction(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: 'BD Reaction emergency-disabled successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminBDReactionsAnalytics(req, res, next) {
  try {
    const analytics = await bdReactionService.getReactionAnalytics();
    return res.status(200).json({
      success: true,
      message: 'BD Reactions analytics retrieved successfully',
      data: analytics,
    });
  } catch (err) {
    next(err);
  }
}

export async function getUserBDReactions(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { countryCode, role, placement } = req.query;

    const result = await bdReactionService.listActiveReactionsForUser({
      userId,
      countryCode,
      role,
      placement,
    });

    return res.status(200).json({
      success: true,
      data: result.reactions,
      masterEnabled: result.masterEnabled,
    });
  } catch (err) {
    next(err);
  }
}

export async function postUserSendBDReaction(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { reactionId, targetUserId, targetContext } = req.body;

    const result = await bdReactionService.sendReactionByUser({
      userId,
      reactionId,
      targetUserId,
      targetContext,
    });

    return res.status(200).json({
      success: true,
      message: 'Reaction sent successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getAdminBDReactions,
  postAdminBDReaction,
  putAdminBDReaction,
  postAdminToggleBDReaction,
  postAdminMasterSwitchBDReactions,
  deleteAdminBDReaction,
  postAdminEmergencyDisableBDReaction,
  getAdminBDReactionsAnalytics,
  getUserBDReactions,
  postUserSendBDReaction,
};
