import userService from '../services/user.service.js';
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
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
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
    const publicUser = await userService.getPublicProfile(id);
    return res.status(200).json({
      success: true,
      data: publicUser,
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
    const result = await userService.getUserLevelStrip(id);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function putProfileEdit(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await userService.editOwnProfile(userId, req.body);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getUserPrivacySettings(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await userService.getUserPrivacySettings(userId);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function putUserPrivacySettings(req, res, next) {
  try {
    const userId = req.auth?.userId;
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

export default {
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
};

