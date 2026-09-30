import userService from '../services/user.service.js';
import {
  queryUsersSchema,
  updateUserStatusSchema,
  deleteAccountSchema,
  updateUserProfileSchema,
  createAdminUserSchema,
  updateAdminUserByAdminSchema,
  userIdParamSchema,
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
};
