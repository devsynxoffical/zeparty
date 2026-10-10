import appEmojiService from '../services/appEmoji.service.js';

export async function getAdminEmojis(req, res, next) {
  try {
    const { category, roomType, status, search } = req.query;
    const result = await appEmojiService.listEmojisForAdmin({ category, roomType, status, search });
    return res.status(200).json({
      success: true,
      message: 'App Emojis retrieved successfully',
      data: result.emojis,
      categories: result.categories,
      masterEnabled: result.masterEnabled,
      totalCount: result.totalCount,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminEmoji(req, res, next) {
  try {
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const emoji = await appEmojiService.createEmoji(req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Emoji created successfully',
      data: emoji,
    });
  } catch (err) {
    next(err);
  }
}

export async function putAdminEmoji(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await appEmojiService.updateEmoji(id, req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Emoji updated successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminToggleEmoji(req, res, next) {
  try {
    const { id } = req.params;
    const { isActive } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await appEmojiService.toggleEmojiStatus(id, {
      isActive,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: `Emoji is now ${updated.isActive ? 'Active' : 'Inactive'}`,
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminMasterSwitchEmojis(req, res, next) {
  try {
    const { enabled } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await appEmojiService.setMasterEmojiSwitch({
      enabled,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: `Emoji Master Switch set to ${result.masterEnabled ? 'ENABLED' : 'DISABLED'}`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminEmoji(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await appEmojiService.deleteEmoji(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: 'Emoji deleted successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminEmergencyDisableEmoji(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await appEmojiService.emergencyDisableEmoji(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: 'Emoji emergency-disabled successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminReorderEmojis(req, res, next) {
  try {
    const { orderedIds } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await appEmojiService.reorderEmojis(orderedIds, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Emojis reordered successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminEmojisAnalytics(req, res, next) {
  try {
    const analytics = await appEmojiService.getEmojiAnalytics();
    return res.status(200).json({
      success: true,
      message: 'App Emojis analytics retrieved successfully',
      data: analytics,
    });
  } catch (err) {
    next(err);
  }
}

export async function getUserEmojiTray(req, res, next) {
  try {
    const { roomType, countryCode } = req.query;
    const userSvipLevel = req.user?.profile?.svipLevel || 0;
    const userNobleRank = req.user?.profile?.nobleRank || null;

    const result = await appEmojiService.getAppEmojiTray({
      roomType,
      userSvipLevel,
      userNobleRank,
      countryCode,
    });

    return res.status(200).json({
      success: true,
      data: result.emojis,
      categories: result.categories,
      masterEnabled: result.masterEnabled,
    });
  } catch (err) {
    next(err);
  }
}

export async function postUserSendAppEmoji(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { emojiId, roomId, targetUserId } = req.body;

    const result = await appEmojiService.sendAppEmoji({
      userId,
      emojiId,
      roomId,
      targetUserId,
    });

    return res.status(200).json({
      success: true,
      message: 'Emoji sent successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getAdminEmojis,
  postAdminEmoji,
  putAdminEmoji,
  postAdminToggleEmoji,
  postAdminMasterSwitchEmojis,
  deleteAdminEmoji,
  postAdminEmergencyDisableEmoji,
  postAdminReorderEmojis,
  getAdminEmojisAnalytics,
  getUserEmojiTray,
  postUserSendAppEmoji,
};
