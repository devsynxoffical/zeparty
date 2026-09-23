import prisma from '../config/database.js';
import userRepository from '../repositories/user.repository.js';

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    let validAdminId = adminId;
    if (validAdminId && validAdminId !== 'SYSTEM' && validAdminId !== 'ADMIN') {
      const exists = await db.admin?.findUnique?.({ where: { id: validAdminId }, select: { id: true } });
      if (!exists) {
        const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
        validAdminId = fallback ? fallback.id : null;
        if (fallback && !adminName) adminName = fallback.name;
      }
    } else {
      const fallback = await db.admin?.findFirst?.({ select: { id: true, name: true } });
      validAdminId = fallback ? fallback.id : null;
      if (fallback && !adminName) adminName = fallback.name;
    }

    if (!validAdminId || !db.auditLog?.create) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System Administrator',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in user.service:', err.message);
  }
}

export async function listUsersForAdmin(filters, db = prisma) {
  return await userRepository.findUsersPaginated(filters, db);
}

export async function getUserDetailsForAdmin(userId, db = prisma) {
  const user = await userRepository.findUserDetailsById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }
  return user;
}

export async function updateUserStatusByAdmin(
  userId,
  { status, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const beforeState = {
    id: existingUser.id,
    username: existingUser.username,
    status: existingUser.status,
  };

  const updatedUser = await userRepository.updateUserStatus(userId, status, db);

  const afterState = {
    id: updatedUser.id,
    username: updatedUser.username,
    status: updatedUser.status,
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: `USER_STATUS_${status}`,
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason,
      ipAddress,
    },
    db
  );

  return updatedUser;
}

export async function getSelfProfile(userId, db = prisma) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }
  return user;
}

export async function updateSelfProfile(userId, profileData, db = prisma) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  return await userRepository.updateUserProfile(userId, profileData, db);
}

export async function getPublicProfile(userId, db = prisma) {
  const publicUser = await userRepository.findPublicProfileById(userId, db);
  if (!publicUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }
  return publicUser;
}

export async function createUserByAdmin(
  { username, displayName, phone, email, countryCode = 'US', status = 'ACTIVE', userType = 'USER', coins = 0, diamonds = 0, adminId, adminName, ipAddress },
  db = prisma
) {
  // Check if username already exists
  const existingUsername = await userRepository.findByUsername(username, db);
  if (existingUsername) {
    const error = new Error('A user with this username already exists');
    error.statusCode = 409;
    error.code = 'USERNAME_ALREADY_EXISTS';
    throw error;
  }

  if (phone) {
    const existingPhone = await userRepository.findByPhone(phone, db);
    if (existingPhone) {
      const error = new Error('A user with this phone number already exists');
      error.statusCode = 409;
      error.code = 'PHONE_ALREADY_EXISTS';
      throw error;
    }
  }

  if (email) {
    const existingEmail = await userRepository.findByEmail(email, db);
    if (existingEmail) {
      const error = new Error('A user with this email address already exists');
      error.statusCode = 409;
      error.code = 'EMAIL_ALREADY_EXISTS';
      throw error;
    }
  }

  const createdUser = await userRepository.createUserWithProfile(
    {
      username,
      displayName: displayName || username,
      phone: phone || null,
      email: email || null,
      countryCode: countryCode || 'US',
      status,
      userType,
      coinBalance: coins || 0,
      diamondBalance: diamonds || 0,
    },
    db
  );

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_CREATED_BY_ADMIN',
      targetEntity: 'User',
      targetEntityId: createdUser.id,
      beforeStateJson: null,
      afterStateJson: {
        id: createdUser.id,
        username: createdUser.username,
        status: createdUser.status,
        userType: createdUser.userType,
      },
      reason: 'User created via Admin panel',
      ipAddress,
    },
    db
  );

  return createdUser;
}

export async function updateUserByAdmin(
  userId,
  updateData,
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const existingUser = await userRepository.findUserDetailsById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const { displayName, phone, email, countryCode, status, userType, avatarUrl, bio, gender, dob } = updateData;

  const userUpdate = {};
  if (phone !== undefined) userUpdate.phone = phone || null;
  if (email !== undefined) userUpdate.email = email || null;
  if (countryCode !== undefined) userUpdate.countryCode = countryCode;
  if (status !== undefined) userUpdate.status = status;
  if (userType !== undefined) userUpdate.userType = userType;
  if (avatarUrl !== undefined) userUpdate.avatarUrl = avatarUrl || null;
  if (bio !== undefined) userUpdate.bio = bio;
  if (gender !== undefined) userUpdate.gender = gender;
  if (dob !== undefined) userUpdate.dob = dob ? new Date(dob) : null;

  const profileUpdate = {};
  if (displayName !== undefined) profileUpdate.displayName = displayName;
  if (avatarUrl !== undefined) profileUpdate.avatarUrl = avatarUrl || null;

  await db.$transaction(async (tx) => {
    if (Object.keys(userUpdate).length > 0) {
      await tx.user.update({
        where: { id: userId },
        data: userUpdate,
      });
    }

    if (Object.keys(profileUpdate).length > 0) {
      await tx.userProfile.upsert({
        where: { userId },
        create: {
          userId,
          displayName: profileUpdate.displayName || existingUser.username,
          avatarUrl: profileUpdate.avatarUrl || null,
        },
        update: profileUpdate,
      });
    }
  });

  const updatedUser = await userRepository.findUserDetailsById(userId, db);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_UPDATED_BY_ADMIN',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: {
        id: existingUser.id,
        username: existingUser.username,
        status: existingUser.status,
      },
      afterStateJson: {
        id: updatedUser.id,
        username: updatedUser.username,
        status: updatedUser.status,
      },
      reason: 'User details updated via Admin panel',
      ipAddress,
    },
    db
  );

  return updatedUser;
}

export async function deleteUserByAdmin(
  userId,
  { adminId, adminName, ipAddress, reason },
  db = prisma
) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_DELETED_BY_ADMIN',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: {
        id: existingUser.id,
        username: existingUser.username,
        status: existingUser.status,
      },
      afterStateJson: null,
      reason: reason || 'Deleted by Administrator',
      ipAddress,
    },
    db
  );

  return await userRepository.deleteUserById(userId, db);
}

export async function searchUsers(query, options = {}) {
  return await userRepository.searchUsers(query, options);
}

export default {
  listUsersForAdmin,
  getUserDetailsForAdmin,
  updateUserStatusByAdmin,
  createUserByAdmin,
  updateUserByAdmin,
  deleteUserByAdmin,
  getSelfProfile,
  updateSelfProfile,
  getPublicProfile,
  searchUsers,
};
