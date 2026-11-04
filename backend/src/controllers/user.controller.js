import userService from '../services/user.service.js';
import socialService from '../services/social.service.js';
import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import * as assetService from '../services/asset.service.js';
import * as userRepository from '../repositories/user.repository.js';
import questService from '../services/quest.service.js';
import * as ledgerRepository from '../repositories/ledger.repository.js';
import {
  queryUsersSchema,
  updateUserStatusSchema,
  deleteAccountSchema,
  updateUserProfileSchema,
  createAdminUserSchema,
  updateAdminUserByAdminSchema,
  userIdParamSchema,
  updateBankInfoSchema,
  banUserSchema,
  freezeUserSchema,
  fraudRiskStatusSchema,
  assignAgencySchema,
  assignHostSchema,
  assignParentBOSchema,
  grantPropSchema,
  revokePropSchema,
  adjustWalletBalanceSchema,
  coinRefundCorrectionSchema,
  resetPasswordAdminSchema,
  resetRoomNameSchema,
  resetRoomCoverSchema,
} from '../validators/user.validator.js';

export async function getAdminUsers(req, res, next) {
  try {
    const filters = queryUsersSchema.parse(req.query);
    const result = await userService.listUsersForAdmin(filters);
    return res.status(200).json({
      success: true,
      message: 'Users retrieved successfully',
      data: result.users,
      pagination: result.pagination,
      users: result.users,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserById(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const user = await userService.getUserDetailsForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'User details retrieved successfully',
      data: user,
    });
  } catch (err) {
    next(err);
  }
}

export async function patchAdminUserStatus(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const { status, reason } = updateUserStatusSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updatedUser = await userService.updateUserStatusByAdmin(id, {
      status,
      reason,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User status updated successfully',
      data: updatedUser,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminUser(req, res, next) {
  try {
    const validatedData = createAdminUserSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const newUser = await userService.createUserByAdmin({
      ...validatedData,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'User created successfully',
      data: newUser,
    });
  } catch (err) {
    next(err);
  }
}

export async function putAdminUser(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = updateAdminUserByAdminSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updatedUser = await userService.updateUserByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User updated successfully',
      data: updatedUser,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminUser(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];
    const reason = req.body?.reason || 'User moved to deleted section by Administrator';
    const permanent = req.query?.permanent === 'true' || req.body?.permanent === true;

    await userService.deleteUserByAdmin(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
      permanent,
    });

    return res.status(200).json({
      success: true,
      message: permanent ? 'User permanently purged successfully' : 'User soft-deleted successfully and moved to Deleted Users section (3-day recovery period)',
      data: { id },
    });
  } catch (err) {
    next(err);
  }
}

export async function restoreAdminUser(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const restoredUser = await userService.restoreUserByAdmin(id, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User restored to active state successfully',
      data: restoredUser,
    });
  } catch (err) {
    next(err);
  }
}

export async function purgeAdminUser(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];
    const reason = req.body?.reason || 'User permanently purged by Administrator';

    await userService.permanentlyPurgeUserByAdmin(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: 'User permanently purged from database',
      data: { id },
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteSelfAccount(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const { password, reason } = deleteAccountSchema.parse(req.body);
    const deletedUser = await userService.deleteSelfAccount(userId, {
      password,
      reason: reason || 'User requested account deletion',
    });

    return res.status(200).json({
      success: true,
      message: 'Account scheduled for deletion. You have 3 days to recover your account by logging in.',
      data: {
        id: deletedUser.id,
        status: deletedUser.status,
        deletedAt: deletedUser.deletedAt,
        scheduledPermanentDeletionAt: deletedUser.scheduledPermanentDeletionAt,
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function getMe(req, res, next) {
  try {
    // Defense in depth: mobile own-profile endpoint MUST reject administrative identities
    if (req.auth?.isAdmin || req.auth?.userType === 'ADMIN' || req.auth?.audience === 'zeparty-admin') {
      return res.status(403).json({
        success: false,
        message: 'Admin accounts cannot access the mobile user profile endpoint',
        error: { code: 'FORBIDDEN' },
      });
    }

    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    // Supplementary safeguard: reject any synthetic shadow or admin identifier
    if (typeof userId === 'string' && (userId.startsWith('dev-admin') || userId.startsWith('admin_shadow'))) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: invalid user profile account',
        error: { code: 'FORBIDDEN' },
      });
    }

    const user = await userService.getSelfProfile(userId);
    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (err) {
    next(err);
  }
}

export async function putMyProfile(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }
    const validatedData = updateUserProfileSchema.parse(req.body);
    const updatedProfile = await userService.updateSelfProfile(userId, validatedData);
    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully',
      data: updatedProfile,
    });
  } catch (err) {
    next(err);
  }
}

export async function getPublicUserById(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const viewerUserId = req.auth?.userId;

    if (viewerUserId && viewerUserId !== id) {
      socialService.recordProfileVisit({ visitorId: viewerUserId, visitedId: id }).catch(() => {});
    }

    const publicUser = await userService.getPublicProfile(id);
    return res.status(200).json({
      success: true,
      data: publicUser,
    });
  } catch (err) {
    next(err);
  }
}

export async function getUserPresence(req, res, next) {
  try {
    const { id } = req.params;
    const presence = await userService.getUserPresence(id);
    return res.status(200).json({
      success: true,
      data: presence,
    });
  } catch (err) {
    next(err);
  }
}

export async function searchUsers(req, res, next) {
  try {
    const { q, limit } = req.query;
    const currentUserId = req.auth?.userId;
    const users = await userService.searchUsers(q || '', {
      limit,
      excludeUserId: currentUserId,
      viewerUserId: currentUserId,
    });
    return res.status(200).json({
      success: true,
      data: users,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminChangeUserCountry(req, res, next) {
  try {
    const { id } = req.params;
    const { countryCode, country, region, reason } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.changeUserCountryByAdmin(id, {
      countryCode: countryCode || country,
      region,
      reason,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User country/region updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminVerifyUserForGrant(req, res, next) {
  try {
    const query = req.body?.userId || req.body?.identifier || req.query?.userId || req.params?.userId;
    const result = await userService.verifyUserForUniqueGrant(query);

    return res.status(200).json({
      success: true,
      message: 'User verified for unique item grant',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminGrantUniqueItem(req, res, next) {
  try {
    const { userId, itemType, itemId, itemName, iconUrl, duration, reason, replaceExisting } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'userId is required for unique item grant',
      });
    }

    const result = await userService.grantUniqueItemToUser(userId, {
      itemType,
      itemId,
      itemName,
      iconUrl,
      duration,
      reason: reason || 'Special item granted by Administrator',
      replaceExisting: Boolean(replaceExisting),
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Special item granted to user successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminRevokeUniqueItem(req, res, next) {
  try {
    const { userId, itemType, itemId, reason } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.revokeUniqueItemFromUser(userId, {
      itemType,
      itemId,
      reason,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Special item revoked from user successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getProfileGrid(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await userService.getProfileMenuGrid(userId);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getRoomUserProfileCard(req, res, next) {
  try {
    const { id } = req.params;
    const viewerUserId = req.auth?.userId;
    const result = await userService.getRoomUserProfileCard(id, viewerUserId);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getUserLevelStrip(req, res, next) {
  try {
    const { id } = req.params;
    const viewerUserId = req.auth?.userId;
    const result = await userService.getUserLevelStrip(id, viewerUserId);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function putProfileEdit(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      const error = new Error('User authentication is required');
      error.statusCode = 401;
      error.code = 'UNAUTHORIZED';
      throw error;
    }
    const result = await userService.editOwnProfile(userId, req.body);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getUserPrivacySettings(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      const error = new Error('User authentication is required');
      error.statusCode = 401;
      error.code = 'UNAUTHORIZED';
      throw error;
    }
    const result = await userService.getUserPrivacySettings(userId);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function putUserPrivacySettings(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      const error = new Error('User authentication is required');
      error.statusCode = 401;
      error.code = 'UNAUTHORIZED';
      throw error;
    }
    const result = await userService.updateUserPrivacySettings(userId, req.body);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getNoblePalette(req, res, next) {
  try {
    const result = await userService.getNoblePalette();
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserDetails(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const user = await userService.getUserDetailsForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'User details retrieved successfully',
      data: user,
    });
  } catch (err) {
    next(err);
  }
}

export async function putAdminUserBankInfo(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = updateBankInfoSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.updateUserBankInfoByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Bank info updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function patchAdminUserBan(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = banUserSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.banUserByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: validatedData.isBanned ? 'User banned successfully' : 'User unbanned successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function patchAdminUserFreeze(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = freezeUserSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.freezeUserByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: validatedData.isFrozen ? 'User frozen successfully' : 'User unfrozen successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function patchAdminUserFraudRisk(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = fraudRiskStatusSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.updateUserFraudRiskStatusByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Fraud risk status updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminAssignAgency(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = assignAgencySchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.assignUserToAgencyByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User assigned to agency successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminRemoveAgency(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.removeUserFromAgencyByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User removed from agency successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminAssignHost(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = assignHostSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.assignUserHostRoleByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Host role assigned successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminRemoveHost(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.removeUserHostRoleByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Host role removed successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminAssignParentBO(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = assignParentBOSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.assignUserParentBOByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Parent BO linked successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminGrantProp(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = grantPropSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.grantUserPropByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Prop granted successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminRevokeProp(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = revokePropSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.revokeUserPropByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Prop revoked successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetProps(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserPropsByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User props reset successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetAvatar(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserAvatarByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User avatar reset successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetNickname(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserNicknameByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User nickname reset successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetRoomName(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = resetRoomNameSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserRoomNameByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User room name reset successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetRoomCover(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = resetRoomCoverSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserRoomCoverByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User room cover reset successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetFamilyAvatar(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserFamilyAvatarByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Family avatar reset successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminResetPassword(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = resetPasswordAdminSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.resetUserPasswordByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User password reset securely',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminAdjustWalletBalance(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = adjustWalletBalanceSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.adjustUserWalletBalanceByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Wallet balance adjusted successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminCoinRefundCorrection(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const validatedData = coinRefundCorrectionSchema.parse(req.body);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.processUserCoinRefundCorrectionByAdmin(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Coin refund / correction processed successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserRecharges(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserRechargeHistoryForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Recharge history retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserGifts(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserGiftHistoryForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Gift history retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserWithdrawals(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserWithdrawalHistoryForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Withdrawal history retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserEarnings(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserEarningsForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'User earnings retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserDynamics(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserRecentDynamicsForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Recent dynamics retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserAuditLogs(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserActionAuditLogsForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Action audit logs retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserReports(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserReportHistoryForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Report history retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserRooms(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserRoomHistoryForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Room history retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserSessions(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserSessionsAndDevicesForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'Sessions and devices retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminUserSession(req, res, next) {
  try {
    const { id, sessionId } = req.params;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.revokeUserSessionByAdmin(id, sessionId, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Session revoked successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminAllUserSessions(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.revokeAllUserSessionsByAdmin(id, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'All sessions revoked successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminUserPermissions(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const result = await userService.getUserEffectivePermissionsForAdmin(id);
    return res.status(200).json({
      success: true,
      message: 'User permissions retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function putAdminUserPermissions(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.updateUserAdminPermissionsByAdmin(id, req.body || {}, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User permissions updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminPropsCatalog(req, res, next) {
  try {
    const { category } = req.query;
    const result = await userService.getPropsCatalog(category);
    return res.status(200).json({ success: true, ...result, data: result.items });
  } catch (err) {
    next(err);
  }
}

export async function postAdminAssignSpecialId(req, res, next) {
  try {
    const { id } = req.params;
    const { newPublicId, reason } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || req.auth?.username || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.assignSpecialIdToUser(
      id,
      { newPublicId, reason },
      { adminId, adminName, ipAddress }
    );

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getAdminNoblesCatalog(req, res, next) {
  try {
    const result = await userService.getNoblesCatalog();
    return res.status(200).json({
      success: true,
      data: result,
      nobles: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminGrantNoble(req, res, next) {
  try {
    const { id } = req.params;
    const { nobleTitle, durationDays, reason } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || req.auth?.username || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await userService.grantNobleTitleToUser(
      id,
      { nobleTitle, durationDays, reason },
      { adminId, adminName, ipAddress }
    );

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminReconcileWealth(req, res, next) {
  try {
    const { id } = req.params;
    const result = await userService.reconcileUserWealthXP(id);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getDailyCheckinStatus(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });

    const rewardsConfig = [
      { day: 1, coins: 50 },
      { day: 2, coins: 100 },
      { day: 3, coins: 150 },
      { day: 4, coins: 200 },
      { day: 5, coins: 250 },
      { day: 6, coins: 300 },
      { day: 7, coins: 350 },
    ];

    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const yesterdayStr = yesterday.toISOString().split('T')[0];

    // 1. Authoritative check in PostgreSQL WalletLedger
    let isTodayClaimed = false;
    let streakDays = 0;
    let currentEligibleDay = 1;

    try {
      const todayLedger = await prisma.walletLedger.findFirst({
        where: { referenceId: `CHECKIN-${userId}-${todayStr}` },
        select: { id: true, balanceAfter: true },
      });

      if (todayLedger) {
        isTodayClaimed = true;
        streakDays = Number(todayLedger.balanceAfter?.streakDays || 1);
        currentEligibleDay = streakDays;
      } else {
        const yesterdayLedger = await prisma.walletLedger.findFirst({
          where: { referenceId: `CHECKIN-${userId}-${yesterdayStr}` },
          select: { id: true, balanceAfter: true },
        });

        if (yesterdayLedger) {
          isTodayClaimed = false;
          const prevStreak = Number(yesterdayLedger.balanceAfter?.streakDays || 1);
          streakDays = prevStreak;
          currentEligibleDay = (prevStreak % 7) + 1;
        } else {
          // Fallback to Redis cache if no recent ledger entry was found
          let state = null;
          if (redisClient.isOpen) {
            const raw = await redisClient.get(`checkin:user:${userId}`).catch(() => null);
            if (raw) state = JSON.parse(raw);
          }
          if (state && state.lastClaimDate === todayStr) {
            isTodayClaimed = true;
            streakDays = Number(state.streakDays || 1);
            currentEligibleDay = streakDays;
          } else if (state && state.lastClaimDate === yesterdayStr) {
            isTodayClaimed = false;
            streakDays = Number(state.streakDays || 1);
            currentEligibleDay = (streakDays % 7) + 1;
          } else {
            isTodayClaimed = false;
            streakDays = 0;
            currentEligibleDay = 1;
          }
        }
      }
    } catch (checkErr) {
      console.warn('[UserController] Warning checking checkin ledger status:', checkErr.message);
    }

    const rewards = rewardsConfig.map((item) => {
      let status = 'LOCKED';
      if (isTodayClaimed) {
        status = item.day <= streakDays ? 'CLAIMED' : 'LOCKED';
      } else {
        if (streakDays > 0 && item.day < currentEligibleDay) {
          status = 'CLAIMED';
        } else if (item.day === currentEligibleDay) {
          status = 'AVAILABLE';
        } else {
          status = 'LOCKED';
        }
      }
      return {
        ...item,
        status,
      };
    });

    // Authoritative daily quests status (independent tracking for games and gifts)
    let dailyQuests = [];
    try {
      dailyQuests = await questService.getDailyQuestsStatus(userId, prisma);
    } catch (_) {}

    return res.status(200).json({
      success: true,
      data: {
        streakDays: isTodayClaimed ? streakDays : (currentEligibleDay > 1 ? streakDays : 0),
        currentEligibleDay,
        isTodayClaimed,
        rewards,
        dailyQuests,
      },
      dailyQuests,
    });
  } catch (err) {
    next(err);
  }
}

export async function claimDailyCheckin(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });

    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const yesterdayStr = yesterday.toISOString().split('T')[0];
    const refId = `CHECKIN-${userId}-${todayStr}`;

    // 1. Idempotency & duplicate check in PostgreSQL ledger
    const existingLedger = await prisma.walletLedger.findFirst({
      where: { referenceId: refId },
      include: { wallet: true },
    });
    if (existingLedger) {
      const currentCoins = Number(existingLedger.wallet?.coinBalance || 0);
      const claimedStreak = Number(existingLedger.balanceAfter?.streakDays || 1);
      if (redisClient.isOpen) {
        await redisClient.set(
          `checkin:user:${userId}`,
          JSON.stringify({
            lastClaimDate: todayStr,
            streakDays: claimedStreak,
            lastClaimedAt: existingLedger.createdAt.toISOString(),
            lastCoinsReward: claimedStreak * 50,
          }),
          { EX: 60 * 60 * 24 * 30 }
        ).catch(() => {});
      }
      return res.status(400).json({
        success: false,
        code: 'ALREADY_CLAIMED',
        message: 'You have already claimed today\'s check-in bonus. Come back tomorrow!',
        data: {
          day: claimedStreak,
          rewardCoins: claimedStreak * 50,
          newStreak: claimedStreak,
          walletCoins: currentCoins,
          referenceId: refId,
        },
      });
    }

    // 2. Concurrency Protection: Distributed Lock
    const lockKey = `checkin:lock:${userId}:${todayStr}`;
    if (redisClient.isOpen) {
      const acquired = await redisClient.set(lockKey, '1', { NX: true, EX: 30 }).catch(() => true);
      if (!acquired) {
        return res.status(409).json({ success: false, code: 'CLAIM_IN_PROGRESS', message: 'Claim in progress or already processed today.' });
      }
    }

    // 3. Determine streak
    let prevStreak = 0;
    try {
      const yesterdayLedger = await prisma.walletLedger.findFirst({
        where: { referenceId: `CHECKIN-${userId}-${yesterdayStr}` },
        select: { balanceAfter: true },
      });
      if (yesterdayLedger) {
        prevStreak = Number(yesterdayLedger.balanceAfter?.streakDays || 1);
      } else if (redisClient.isOpen) {
        const raw = await redisClient.get(`checkin:user:${userId}`).catch(() => null);
        if (raw) {
          const s = JSON.parse(raw);
          if (s.lastClaimDate === yesterdayStr) {
            prevStreak = Number(s.streakDays || 1);
          }
        }
      }
    } catch (_) {}

    const newStreak = prevStreak > 0 ? (prevStreak % 7) + 1 : 1;
    const rewardCoins = newStreak * 50;

    // 4. Atomic PostgreSQL Transaction: Wallet Balance Mutation + Immutable WalletLedger Entry
    const claimResult = await prisma.$transaction(async (tx) => {
      // Re-verify inside tx to protect against concurrent execution
      const dup = await tx.walletLedger.findFirst({
        where: { referenceId: refId },
      });
      if (dup) {
        const err = new Error('You have already claimed today\'s check-in bonus.');
        err.statusCode = 400;
        err.code = 'ALREADY_CLAIMED';
        throw err;
      }

      let wallet = await tx.wallet.findUnique({ where: { userId } });
      if (!wallet) {
        wallet = await tx.wallet.create({
          data: {
            userId,
            coinBalance: 0n,
            diamondBalance: 0n,
          },
        });
      }

      const balanceBeforeCoins = BigInt(wallet.coinBalance || 0n);
      const rewardCoinsBig = BigInt(rewardCoins);
      const newCoinBalance = balanceBeforeCoins + rewardCoinsBig;

      // Authoritative balance update using correct schema field coinBalance
      const updatedWallet = await tx.wallet.update({
        where: { id: wallet.id },
        data: {
          coinBalance: newCoinBalance,
        },
      });

      // Record immutable WalletLedger entry
      const ledgerEntry = await ledgerRepository.createEntry(
        {
          walletId: wallet.id,
          transactionType: 'RECHARGE',
          coinDelta: rewardCoinsBig,
          diamondDelta: 0n,
          usdDelta: 0.0,
          balanceBefore: {
            coins: balanceBeforeCoins.toString(),
            diamonds: (wallet.diamondBalance || 0n).toString(),
          },
          balanceAfter: {
            coins: newCoinBalance.toString(),
            diamonds: (wallet.diamondBalance || 0n).toString(),
            streakDays: newStreak,
            day: newStreak,
            claimedDate: todayStr,
          },
          referenceId: refId,
        },
        tx
      );

      return { updatedWallet, ledgerEntry };
    });

    // 5. Update Redis state with 30-day TTL and release lock
    if (redisClient.isOpen) {
      await redisClient.set(
        `checkin:user:${userId}`,
        JSON.stringify({
          lastClaimDate: todayStr,
          streakDays: newStreak,
          lastClaimedAt: now.toISOString(),
          lastCoinsReward: rewardCoins,
        }),
        { EX: 60 * 60 * 24 * 30 }
      ).catch(() => {});
      await redisClient.del(lockKey).catch(() => {});
    }

    return res.status(200).json({
      success: true,
      message: `Day ${newStreak} bonus claimed: +${rewardCoins} ZeCoins!`,
      data: {
        day: newStreak,
        rewardCoins,
        newStreak,
        walletCoins: Number(claimResult.updatedWallet.coinBalance),
        ledgerEntryId: claimResult.ledgerEntry.id,
        referenceId: refId,
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function getDailyQuests(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const quests = await questService.getDailyQuestsStatus(userId, prisma);
    return res.status(200).json({
      success: true,
      message: 'Daily quests retrieved successfully',
      data: quests,
      quests,
    });
  } catch (err) {
    next(err);
  }
}

export async function postClaimDailyQuest(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) return res.status(401).json({ success: false, message: 'Unauthorized' });

    const questId = req.params.questId || req.body?.questId || req.body?.id || req.body?.questKey;
    if (!questId) {
      return res.status(400).json({ success: false, message: 'questId is required to claim quest' });
    }

    const result = await questService.claimDailyQuest(userId, questId, prisma);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getUserReceivedGifts(req, res, next) {
  try {
    const { id } = req.params;
    let targetUser = await userRepository.findUserById(id).catch(() => null);
    if (!targetUser) {
      targetUser = await userRepository.findUserByUniqueId(id).catch(() => null);
    }
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    // CRITICAL: Strictly filter out self-sent gifts (senderUserId != targetUser.id)
    const txs = await prisma.giftTransaction.findMany({
      where: {
        recipientUserId: targetUser.id,
        senderUserId: { not: targetUser.id },
      },
      include: {
        gift: true,
      },
      orderBy: { createdAt: 'desc' },
    });

    const giftMap = new Map();
    for (const tx of txs) {
      const gId = tx.giftId;
      const count = Number(tx.giftCount || 1);
      const coins = Number(tx.totalCoins || 0);
      if (!giftMap.has(gId)) {
        giftMap.set(gId, {
          giftId: gId,
          name: tx.gift?.name || 'Gift',
          iconUrl: tx.gift?.iconUrl || '',
          animationUrl: tx.gift?.animationUrl || '',
          category: tx.gift?.category || 'NORMAL',
          count: 0,
          totalCoins: 0,
          lastReceivedAt: tx.createdAt,
        });
      }
      const entry = giftMap.get(gId);
      entry.count += count;
      entry.totalCoins += coins;
    }

    const gifts = Array.from(giftMap.values()).sort((a, b) => b.totalCoins - a.totalCoins);

    return res.status(200).json({
      success: true,
      data: gifts,
      totalGiftsReceived: txs.length,
      totalUniqueGifts: gifts.length,
    });
  } catch (err) {
    next(err);
  }
}

export async function getUserHonorAssets(req, res, next) {
  try {
    const { id } = req.params;
    let targetUser = await userRepository.findUserById(id).catch(() => null);
    if (!targetUser) {
      targetUser = await userRepository.findUserByUniqueId(id).catch(() => null);
    }
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const assets = await assetService.getUserBackpack(targetUser.id);
    return res.status(200).json({
      success: true,
      data: assets,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getDailyCheckinStatus,
  claimDailyCheckin,
  getDailyQuests,
  postClaimDailyQuest,
  getUserReceivedGifts,
  getUserHonorAssets,
  getAdminUsers,
  getAdminUserById,
  patchAdminUserStatus,
  postAdminUser,
  putAdminUser,
  deleteAdminUser,
  restoreAdminUser,
  purgeAdminUser,
  deleteSelfAccount,
  getMe,
  putMyProfile,
  getPublicUserById,
  getUserPresence,
  searchUsers,
  postAdminChangeUserCountry,
  postAdminVerifyUserForGrant,
  postAdminGrantUniqueItem,
  postAdminRevokeUniqueItem,
  getProfileGrid,
  getRoomUserProfileCard,
  getUserLevelStrip,
  putProfileEdit,
  getUserPrivacySettings,
  putUserPrivacySettings,
  getNoblePalette,
  getAdminUserDetails,
  putAdminUserBankInfo,
  patchAdminUserBan,
  patchAdminUserFreeze,
  patchAdminUserFraudRisk,
  postAdminAssignAgency,
  deleteAdminRemoveAgency,
  postAdminAssignHost,
  deleteAdminRemoveHost,
  postAdminAssignParentBO,
  postAdminGrantProp,
  postAdminRevokeProp,
  postAdminResetProps,
  postAdminResetAvatar,
  postAdminResetNickname,
  postAdminResetRoomName,
  postAdminResetRoomCover,
  postAdminResetFamilyAvatar,
  postAdminResetPassword,
  postAdminAdjustWalletBalance,
  postAdminCoinRefundCorrection,
  getAdminUserRecharges,
  getAdminUserGifts,
  getAdminUserWithdrawals,
  getAdminUserEarnings,
  getAdminUserDynamics,
  getAdminUserAuditLogs,
  getAdminUserReports,
  getAdminUserRooms,
  getAdminUserSessions,
  deleteAdminUserSession,
  deleteAdminAllUserSessions,
  getAdminUserPermissions,
  putAdminUserPermissions,
  getAdminPropsCatalog,
  postAdminAssignSpecialId,
  getAdminNoblesCatalog,
  postAdminGrantNoble,
  postAdminReconcileWealth,
};


