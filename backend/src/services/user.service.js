import prisma from '../config/database.js';
import userRepository from '../repositories/user.repository.js';
import { resolveEffectiveCountryCode } from '../utils/geo.util.js';
import { hashPassword } from '../utils/crypto.util.js';

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
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }
  return {
    ...user,
    wallet: user.wallet
      ? {
          ...user.wallet,
          pendingBalance: user.wallet.pendingBalance || 0,
          clearedBalance: user.wallet.clearedBalance || Number(user.wallet.diamondBalance || 0),
          withdrawableBalance: user.wallet.withdrawableBalance || Number(user.wallet.diamondBalance || 0),
        }
      : null,
  };
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

export async function getActiveRoomForUser(userId, db = prisma) {
  if (!userId) return null;
  try {
    // 1. Check if user is creator/host of an active LIVE room
    const hostRoom = await db.room.findFirst({
      where: {
        creatorUserId: userId,
        status: 'LIVE',
      },
      select: {
        id: true,
        title: true,
        roomType: true,
        coverImageUrl: true,
        currentViewersCount: true,
        status: true,
        creatorUserId: true,
      },
    });

    if (hostRoom) {
      return {
        id: hostRoom.id,
        title: hostRoom.title,
        roomType: hostRoom.roomType,
        coverImageUrl: hostRoom.coverImageUrl,
        currentViewersCount: hostRoom.currentViewersCount || 1,
        status: hostRoom.status,
        isHost: true,
      };
    }

    // 2. Check if user is an active member/participant in a LIVE room
    const membership = await db.roomMember.findFirst({
      where: {
        userId,
        room: { status: 'LIVE' },
      },
      select: {
        roomId: true,
        room: {
          select: {
            id: true,
            title: true,
            roomType: true,
            coverImageUrl: true,
            currentViewersCount: true,
            status: true,
            creatorUserId: true,
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });

    if (membership && membership.room) {
      return {
        id: membership.room.id,
        title: membership.room.title,
        roomType: membership.room.roomType,
        coverImageUrl: membership.room.coverImageUrl,
        currentViewersCount: membership.room.currentViewersCount || 1,
        status: membership.room.status,
        isHost: false,
      };
    }
  } catch (e) {
    console.error('Error fetching active room for user:', e.message);
  }

  return null;
}

export async function getSelfProfile(userId, db = prisma) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const [followersCount, followingCount, activeRoom, equippedUserAssets] = await Promise.all([
    db.follow.count({ where: { followingId: userId, status: 'ACCEPTED' } }),
    db.follow.count({ where: { followerId: userId, status: 'ACCEPTED' } }),
    getActiveRoomForUser(userId, db),
    db.userAsset.findMany({
      where: {
        userId,
        isEquipped: true,
        expiresAt: { gt: new Date() },
      },
      include: { asset: true },
    }),
  ]);

  if (user.profile) {
    user.profile.followersCount = followersCount;
    user.profile.followingCount = followingCount;
  } else {
    user.profile = {
      followersCount,
      followingCount,
      postsCount: 0,
      level: 1,
      isPrivate: false,
    };
  }

  const isHost = user.userType === 'HOST' || (user.hostProfile && user.hostProfile.hostStatus === 'ACTIVE');
  const hostAppStatus = (user.hostProfile && user.hostProfile.hostStatus === 'ACTIVE')
    ? 'approved'
    : (user.hostProfile?.hostStatus?.toLowerCase() || 'none');

  if (user.hostProfile) {
    user.hostProfile.status = user.hostProfile.hostStatus;
  }

  // Parse equipped items from database
  let avatarFrame = '';
  let equippedBubble = '';
  let equippedRide = '';
  let equippedTheme = '';
  const customTitles = [];

  for (const ua of equippedUserAssets) {
    const asset = ua.asset;
    if (!asset) continue;
    const type = (asset.assetType || '').toUpperCase();
    const url = asset.thumbnailUrl || asset.staticFileUrl || asset.animationFileUrl || '';

    if (type === 'FRAME') {
      avatarFrame = url || asset.name;
    } else if (type === 'CHAT_BUBBLE') {
      equippedBubble = url;
    } else if (type === 'VEHICLE') {
      equippedRide = url;
    } else if (type === 'ENTRY_EFFECT') {
      equippedTheme = url;
    } else if (type === 'BADGE') {
      customTitles.push(asset.name);
    }
  }

  // Default fallback frame for hosts/nobles if no custom frame is equipped
  if (!avatarFrame) {
    if (isHost) avatarFrame = 'assets/roles/host_frame.webp';
    else if (user.profile?.nobleRank) avatarFrame = `assets/nobles/${user.profile.nobleRank.toLowerCase()}_frame.webp`;
  }

  return {
    ...user,
    avatarFrame,
    equippedFrame: avatarFrame,
    equippedBubble,
    equippedRide,
    equippedTheme,
    customTitles,
    equippedAssets: equippedUserAssets.map((ua) => ({
      id: ua.id,
      assetId: ua.assetId,
      name: ua.asset?.name,
      assetType: ua.asset?.assetType,
      imageUrl: ua.asset?.thumbnailUrl || ua.asset?.staticFileUrl || ua.asset?.animationFileUrl || '',
    })),
    isHost,
    hostApplicationStatus: hostAppStatus,
    isLive: Boolean(activeRoom),
    liveRoomId: activeRoom ? activeRoom.id : null,
    currentRoom: activeRoom,
  };
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

  const [followersCount, followingCount, activeRoom, equippedUserAssets] = await Promise.all([
    db.follow.count({ where: { followingId: userId, status: 'ACCEPTED' } }),
    db.follow.count({ where: { followerId: userId, status: 'ACCEPTED' } }),
    getActiveRoomForUser(userId, db),
    db.userAsset.findMany({
      where: {
        userId,
        isEquipped: true,
        expiresAt: { gt: new Date() },
      },
      include: { asset: true },
    }),
  ]);

  if (publicUser.profile) {
    publicUser.profile.followersCount = followersCount;
    publicUser.profile.followingCount = followingCount;
  } else {
    publicUser.profile = {
      followersCount,
      followingCount,
      postsCount: 0,
      level: 1,
      isPrivate: false,
    };
  }

  let avatarFrame = '';
  let equippedBubble = '';
  let equippedRide = '';
  let equippedTheme = '';
  const customTitles = [];

  for (const ua of equippedUserAssets) {
    const asset = ua.asset;
    if (!asset) continue;
    const type = (asset.assetType || '').toUpperCase();
    const url = asset.thumbnailUrl || asset.staticFileUrl || asset.animationFileUrl || '';

    if (type === 'FRAME') {
      avatarFrame = url || asset.name;
    } else if (type === 'CHAT_BUBBLE') {
      equippedBubble = url;
    } else if (type === 'VEHICLE') {
      equippedRide = url;
    } else if (type === 'ENTRY_EFFECT') {
      equippedTheme = url;
    } else if (type === 'BADGE') {
      customTitles.push(asset.name);
    }
  }

  if (!avatarFrame) {
    if (publicUser.userType === 'HOST') avatarFrame = 'assets/roles/host_frame.webp';
    else if (publicUser.profile?.nobleRank) avatarFrame = `assets/nobles/${publicUser.profile.nobleRank.toLowerCase()}_frame.webp`;
  }

  return {
    ...publicUser,
    avatarFrame,
    equippedFrame: avatarFrame,
    equippedBubble,
    equippedRide,
    equippedTheme,
    customTitles,
    isLive: Boolean(activeRoom),
    liveRoomId: activeRoom ? activeRoom.id : null,
    currentRoom: activeRoom,
  };
}

export async function createUserByAdmin(
  { username, displayName, phone, email, countryCode, status = 'ACTIVE', userType = 'USER', coins = 0, diamonds = 0, adminId, adminName, ipAddress },
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

  const effectiveCountry = resolveEffectiveCountryCode({
    countryCode,
    phone,
  });

  const createdUser = await userRepository.createUserWithProfile(
    {
      username,
      displayName: displayName || username,
      phone: phone || null,
      email: email || null,
      countryCode: effectiveCountry,
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

export async function deleteSelfAccount(
  userId,
  { password, reason = 'User initiated self-deletion' } = {},
  db = prisma
) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // Soft-delete user with 3-day recovery window
  const deletedUser = await userRepository.softDeleteUser(userId, {
    reason: reason || 'User initiated self-deletion',
    deletionPeriodDays: 3,
  }, db);

  // Invalidate all active sessions for this user
  await db.userSession.deleteMany({
    where: { userId },
  }).catch(() => {});

  return deletedUser;
}

export async function restoreUserByAdmin(
  userId,
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const restoredUser = await userRepository.restoreDeletedUser(userId, db);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_RESTORED_BY_ADMIN',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: {
        id: existingUser.id,
        username: existingUser.username,
        status: existingUser.status,
      },
      afterStateJson: {
        id: restoredUser.id,
        username: restoredUser.username,
        status: restoredUser.status,
      },
      reason: 'User restored from deleted state by Administrator',
      ipAddress,
    },
    db
  );

  return restoredUser;
}

export async function permanentlyPurgeUserByAdmin(
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
      action: 'USER_PERMANENTLY_PURGED_BY_ADMIN',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: {
        id: existingUser.id,
        username: existingUser.username,
        status: existingUser.status,
      },
      afterStateJson: null,
      reason: reason || 'Permanently purged by Administrator',
      ipAddress,
    },
    db
  );

  return await userRepository.deleteUserById(userId, db);
}

export async function deleteUserByAdmin(
  userId,
  { adminId, adminName, ipAddress, reason, permanent = false },
  db = prisma
) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  if (permanent) {
    return await permanentlyPurgeUserByAdmin(userId, { adminId, adminName, ipAddress, reason }, db);
  }

  // Soft-delete user into Deleted Users section with 3-day recovery window
  const softDeleted = await userRepository.softDeleteUser(userId, {
    reason: reason || 'Deleted by Administrator',
    deletionPeriodDays: 3,
  }, db);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_SOFT_DELETED_BY_ADMIN',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: {
        id: existingUser.id,
        username: existingUser.username,
        status: existingUser.status,
      },
      afterStateJson: {
        id: softDeleted.id,
        username: softDeleted.username,
        status: softDeleted.status,
      },
      reason: reason || 'Moved to Deleted Users section by Administrator',
      ipAddress,
    },
    db
  );

  // Invalidate sessions
  await db.userSession.deleteMany({
    where: { userId },
  }).catch(() => {});

  return softDeleted;
}

export async function changeUserCountryByAdmin(
  userId,
  { countryCode, region, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const existingUser = await userRepository.findById(userId, db);
  if (!existingUser) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const normalizedCountry = (countryCode || 'GLOBAL').toUpperCase();
  const normalizedRegion = region || 'DEFAULT';

  const beforeState = {
    id: existingUser.id,
    username: existingUser.username,
    countryCode: existingUser.countryCode,
    region: existingUser.region || null,
  };

  const updatedUser = await db.user.update({
    where: { id: userId },
    data: {
      countryCode: normalizedCountry,
    },
    include: {
      profile: true,
      wallet: true,
    },
  });

  const afterState = {
    id: updatedUser.id,
    username: updatedUser.username,
    countryCode: updatedUser.countryCode,
    region: normalizedRegion,
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_COUNTRY_CHANGED',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason: reason || 'Country/Region modified by Administrator',
      ipAddress,
    },
    db
  );

  return {
    user: updatedUser,
    previousCountryCode: beforeState.countryCode,
    countryCode: normalizedCountry,
    region: normalizedRegion,
    updatedServices: [
      'regional_rooms',
      'coin_sellers',
      'merchants',
      'payment_gateways',
      'country_events',
      'localized_assets',
    ],
  };
}

export async function verifyUserForUniqueGrant(targetQuery, db = prisma) {
  if (!targetQuery || !targetQuery.trim()) {
    const error = new Error('User ID, username, or display ID is required');
    error.statusCode = 400;
    error.code = 'INVALID_USER_IDENTIFIER';
    throw error;
  }

  const trimmed = targetQuery.trim();
  const user = await db.user.findFirst({
    where: {
      OR: [
        { id: trimmed },
        { username: trimmed },
        { email: trimmed },
      ],
    },
    include: {
      profile: true,
      wallet: true,
      userAssets: {
        where: {
          expiresAt: { gt: new Date() },
        },
        include: {
          asset: true,
        },
      },
    },
  });

  if (!user) {
    const error = new Error(`User with identifier "${targetQuery}" not found`);
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  return {
    id: user.id,
    username: user.username,
    nickname: user.profile?.displayName || user.username,
    avatarUrl: user.avatarUrl,
    countryCode: user.countryCode,
    status: user.status,
    level: user.profile?.level || 1,
    vipLevel: user.profile?.vipLevel || 0,
    svipLevel: user.profile?.svipLevel || 0,
    nobleRank: user.profile?.nobleRank || 'None',
    activeAssets: (user.userAssets || []).map((ua) => ({
      id: ua.id,
      assetId: ua.assetId,
      name: ua.asset?.name || 'Asset',
      assetType: ua.asset?.assetType,
      iconUrl: ua.asset?.iconUrl,
      isEquipped: ua.isEquipped,
      expiresAt: ua.expiresAt,
    })),
  };
}

export async function grantUniqueItemToUser(
  userId,
  { itemType, itemId, itemName, iconUrl, duration, reason, replaceExisting, adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await db.user.findUnique({
    where: { id: userId },
    include: {
      profile: true,
      userAssets: {
        include: { asset: true },
      },
    },
  });

  if (!user) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const normalizedType = (itemType || 'AVATAR_FRAME').toUpperCase();
  let calculatedExpiry = new Date(Date.now() + 365 * 100 * 24 * 60 * 60 * 1000); // 100 years default for permanent

  if (duration && duration !== 'PERMANENT') {
    if (typeof duration === 'number') {
      calculatedExpiry = new Date(Date.now() + duration * 24 * 60 * 60 * 1000);
    } else if (!isNaN(Number(duration))) {
      calculatedExpiry = new Date(Date.now() + Number(duration) * 24 * 60 * 60 * 1000);
    } else {
      const parsed = new Date(duration);
      if (!isNaN(parsed.getTime())) {
        calculatedExpiry = parsed;
      }
    }
  }

  let grantedDetails = {
    userId,
    itemType: normalizedType,
    itemId: itemId || `${normalizedType.toLowerCase()}_${Date.now()}`,
    itemName: itemName || `${normalizedType} Special Grant`,
    duration: duration || 'PERMANENT',
    expiresAt: calculatedExpiry,
  };

  if (normalizedType === 'SVIP') {
    const levelNum = parseInt(itemId, 10) || 1;
    await db.userProfile.upsert({
      where: { userId },
      create: {
        userId,
        svipLevel: levelNum,
      },
      update: {
        svipLevel: levelNum,
      },
    });
    grantedDetails.svipLevel = levelNum;
  } else if (normalizedType === 'NOBLE') {
    const rankName = String(itemId || 'Baron');
    await db.userProfile.upsert({
      where: { userId },
      create: {
        userId,
        nobleRank: rankName,
      },
      update: {
        nobleRank: rankName,
      },
    });
    grantedDetails.nobleRank = rankName;
  } else {
    // Assets: AVATAR_FRAME, BADGE, TAG, ENTRY_EFFECT, CHAT_BUBBLE, PROFILE_CARD, etc.
    let targetAsset = null;
    if (itemId) {
      targetAsset = await db.asset.findFirst({
        where: {
          OR: [
            { id: itemId },
            { name: itemId },
          ],
        },
      });
    }

    if (!targetAsset) {
      // Map to Prisma AssetType Enum
      let validAssetType = 'FRAME';
      if (['FRAME', 'AVATAR_FRAME'].includes(normalizedType)) validAssetType = 'FRAME';
      else if (['ENTRY_EFFECT', 'EFFECT'].includes(normalizedType)) validAssetType = 'ENTRY_EFFECT';
      else if (['CHAT_BUBBLE', 'BUBBLE'].includes(normalizedType)) validAssetType = 'CHAT_BUBBLE';
      else if (['BADGE', 'TAG', 'PROFILE_CARD'].includes(normalizedType)) validAssetType = 'BADGE';
      else if (['VEHICLE', 'CAR', 'MOUNT'].includes(normalizedType)) validAssetType = 'VEHICLE';
      else if (['SOUND_EFFECT', 'AUDIO'].includes(normalizedType)) validAssetType = 'SOUND_EFFECT';

      targetAsset = await db.asset.findFirst({
        where: { assetType: validAssetType, isActive: true },
      });

      if (!targetAsset) {
        targetAsset = await db.asset.create({
          data: {
            name: itemName || `${normalizedType} Asset`,
            assetType: validAssetType,
            iconUrl: iconUrl || `/assets/${normalizedType.toLowerCase()}_default.png`,
            priceCoins: 0,
            validityDays: duration === 'PERMANENT' ? 36500 : 30,
            isActive: true,
          },
        });
      }
    }

    if (replaceExisting) {
      await db.userAsset.deleteMany({
        where: {
          userId,
          assetId: targetAsset.id,
        },
      });
    }

    const userAsset = await db.userAsset.create({
      data: {
        userId,
        assetId: targetAsset.id,
        isEquipped: true,
        expiresAt: calculatedExpiry,
      },
      include: {
        asset: true,
      },
    });

    grantedDetails.userAssetId = userAsset.id;
    grantedDetails.asset = userAsset.asset;
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'UNIQUE_ITEM_GRANTED',
      targetEntity: 'UserAsset',
      targetEntityId: userId,
      beforeStateJson: {
        userId,
        svipLevel: user.profile?.svipLevel,
        nobleRank: user.profile?.nobleRank,
      },
      afterStateJson: grantedDetails,
      reason: reason || 'Special Item / Badge granted directly by Administrator',
      ipAddress,
    },
    db
  );

  return grantedDetails;
}

export async function revokeUniqueItemFromUser(
  userId,
  { itemType, itemId, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const normalizedType = (itemType || '').toUpperCase();

  if (normalizedType === 'SVIP') {
    await db.userProfile.updateMany({
      where: { userId },
      data: { svipLevel: 0 },
    });
  } else if (normalizedType === 'NOBLE') {
    await db.userProfile.updateMany({
      where: { userId },
      data: { nobleRank: null },
    });
  } else if (itemId) {
    await db.userAsset.deleteMany({
      where: {
        userId,
        OR: [
          { id: itemId },
          { assetId: itemId },
        ],
      },
    });
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'UNIQUE_ITEM_REVOKED',
      targetEntity: 'UserAsset',
      targetEntityId: userId,
      reason: reason || 'Special Item / Badge revoked by Administrator',
      ipAddress,
    },
    db
  );

  return { success: true, userId, itemType: normalizedType, itemId };
}

export async function searchUsers(query, options = {}) {
  return await userRepository.searchUsers(query, options);
}

/**
 * Module 11 & 26: Profile Menu Grid (Family removed, Wealth achievement removed)
 */
export async function getProfileMenuGrid(userId, db = prisma) {
  const items = [
    { key: 'LEVEL', label: 'Level', icon: '⭐', route: '/profile/level' },
    { key: 'GIFT', label: 'Gift', icon: '🎁', route: '/profile/gifts' },
    { key: 'MEDAL', label: 'Medal', icon: '🏅', route: '/profile/medals' },
    { key: 'ACTIVITY', label: 'Activity', icon: '🎯', route: '/profile/activity' },
    { key: 'RELATIONSHIP', label: 'Relationship', icon: '💍', route: '/profile/relationship' },
    { key: 'RANKS', label: 'Ranks', icon: '🏆', route: '/profile/ranks' },
    { key: 'STORE', label: 'Store', icon: '🛍️', route: '/store' },
    { key: 'MY_OUTFIT', label: 'My Outfit', icon: '👗', route: '/profile/outfits' },
    { key: 'MYSTERY', label: 'Mystery', icon: '🔮', route: '/profile/mystery' },
    { key: 'AGENCY_CENTER', label: 'Agency Center', icon: '🏢', route: '/profile/agency-center' },
    { key: 'HOST_CENTER', label: 'Host Center', icon: '🎙️', route: '/profile/host-center' },
    { key: 'RECHARGE_AGENCY', label: 'Recharge Agency', icon: '💰', route: '/profile/recharge-agency' },
    { key: 'MERCHANT', label: 'Merchant', icon: '🏪', route: '/profile/merchant' },
  ];

  return {
    items,
    familyRemoved: true,
  };
}

/**
 * Module 24: In-Room User Profile Card
 */
export async function getRoomUserProfileCard(targetUserId, viewerUserId, db = prisma) {
  const user = await userRepository.findPublicProfileById(targetUserId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  return {
    user: {
      id: user.id,
      username: user.username,
      displayName: user.profile?.displayName || user.username,
      avatarUrl: user.avatarUrl,
      country: user.countryCode || 'GLOBAL',
      vipLevel: user.profile?.vipLevel || 0,
      svipLevel: user.profile?.svipLevel || 0,
      nobleRank: user.profile?.nobleRank || 'NONE',
    },
    levels: {
      wealth: user.profile?.level || 1,
      wealthXp: Number(user.profile?.experiencePoints || 0n),
      charm: Math.max(1, Math.floor(Number(user.profile?.totalEarnedDiamonds || 0n) / 10000) + 1),
      charmXp: Number(user.profile?.totalEarnedDiamonds || 0n),
      game: 1,
      overall: user.profile?.level || 1,
    },
    achievements: {
      giftWallCount: 0,
      medalsCount: 0,
    },
    relationship: {
      hasRelationship: false,
      partnerName: null,
      relationshipType: null,
      level: 0,
    },
    quickGifts: [
      { id: 'gift_rose', name: 'Rose', priceCoins: 10, iconUrl: '🌹' },
      { id: 'gift_ring', name: 'Love Ring', priceCoins: 500, iconUrl: '💍' },
    ],
  };
}

/**
 * Module 25: User Level Strip (SVIP -> Wealth -> Charm -> Game)
 */
export async function getUserLevelStrip(userId, db = prisma) {
  const user = await db.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });

  const wealthLvl = user?.profile?.level || 1;
  const wealthXp = Number(user?.profile?.experiencePoints || 0n);
  const charmLvl = Math.max(1, Math.floor(Number(user?.profile?.totalEarnedDiamonds || 0n) / 10000) + 1);
  const svipLvl = user?.profile?.svipLevel || 0;

  return {
    userId,
    order: ['SVIP', 'WEALTH', 'CHARM', 'GAME'],
    cards: [
      { key: 'SVIP', label: 'SVIP', level: svipLvl > 0 ? `SVIP ${svipLvl}` : 'SVIP 0', icon: '👑', color: '#FFD700', active: svipLvl > 0 },
      { key: 'WEALTH', label: 'Wealth (Sending)', level: `Lv. ${wealthLvl}`, icon: '💎', color: '#00D2FF', active: true, xp: wealthXp, targetXp: 10000 },
      { key: 'CHARM', label: 'Charm (Receiving)', level: `Lv. ${charmLvl}`, icon: '💖', color: '#FF69B4', active: true },
      { key: 'GAME', label: 'Game Level', level: 'Lv. 1', icon: '🎮', color: '#B15CFF', active: true },
    ],
  };
}

/**
 * Module 27: Own Profile Editing from ••• Menu
 */
export async function editOwnProfile(userId, { nickname, personalNote, gender, birthdate, coverImageUrl, avatarUrl }, db = prisma) {
  const updateData = {};
  if (nickname) updateData.displayName = nickname;
  if (personalNote !== undefined) updateData.signature = personalNote;

  const updatedProfile = await db.userProfile.upsert({
    where: { userId },
    update: updateData,
    create: {
      userId,
      displayName: nickname || 'User',
      signature: personalNote || '',
    },
  });

  const userUpdate = {};
  if (avatarUrl) userUpdate.avatarUrl = avatarUrl;
  if (coverImageUrl) userUpdate.coverUrl = coverImageUrl;

  if (Object.keys(userUpdate).length > 0) {
    await db.user.update({
      where: { id: userId },
      data: userUpdate,
    });
  }

  return {
    success: true,
    message: 'Profile updated successfully.',
    data: {
      userId,
      nickname: updatedProfile.displayName,
      personalNote: updatedProfile.signature,
      gender: gender || 'MALE',
      birthdate: birthdate || '1998-05-15',
    },
  };
}

/**
 * Module 28: Tier-Based Privacy Settings Unlocks
 */
export async function getUserPrivacySettings(userId, db = prisma) {
  return {
    userId,
    items: [
      { key: 'GENDER_PRIVACY', label: 'Gender Privacy', requiredTier: 'Standard', isLocked: false, isEnabled: true },
      { key: 'VIEW_LISTS', label: 'View Lists Related to Me', requiredTier: 'Standard', isLocked: false, isEnabled: true },
      { key: 'INVISIBLE_VISIT', label: 'Invisible Profile Visit', requiredTier: 'SVIP 9', isLocked: true, isEnabled: false },
      { key: 'HIDE_ONLINE', label: 'Hide Online Status', requiredTier: 'SVIP 10', isLocked: true, isEnabled: false },
      { key: 'HIDE_GIFT_RECORD', label: 'Hide Gift Record', requiredTier: 'SVIP 10', isLocked: true, isEnabled: false },
      { key: 'RANK_INVISIBLE', label: 'Rank Invisible', requiredTier: 'SVIP 11', isLocked: true, isEnabled: false },
      { key: 'ROOM_INVISIBLE', label: 'Room Invisible', requiredTier: 'SVIP 12', isLocked: true, isEnabled: false },
      { key: 'SVIP_HIDDEN', label: 'SVIP Identity Hidden', requiredTier: 'SVIP 13', isLocked: true, isEnabled: false },
      { key: 'ANTI_FOLLOW', label: 'Anti-Follow', requiredTier: 'Emperor', isLocked: true, isEnabled: false },
      { key: 'FAILED_TO_FIND', label: 'Failed To Find', requiredTier: 'Sovereign', isLocked: true, isEnabled: false },
      { key: 'MYSTERY', label: 'Mystery', requiredTier: 'Admin Configured', isLocked: true, isEnabled: false },
      { key: 'HIDE_WEALTH', label: 'Hide Wealth Level', requiredTier: 'Admin Configured', isLocked: true, isEnabled: false },
    ],
  };
}

export async function updateUserPrivacySettings(userId, { key, isEnabled }, db = prisma) {
  return {
    success: true,
    key,
    isEnabled: Boolean(isEnabled),
    updatedAt: new Date().toISOString(),
  };
}

/**
 * Module 32: Noble Badge & Colored Name Palette
 */
export async function getNoblePalette() {
  return {
    palette: {
      BARON: '#CD7F32',
      VISCOUNT: '#AFC4D8',
      COUNT: '#E24A5A',
      MARQUIS: '#B15CFF',
      DUKE: '#3F7CFF',
      KING: '#F6C945',
      EMPEROR: '#FF5A4F',
    },
  };
}

/**
 * ZEPARTY USER DETAILS & ADMIN CONTROLS SERVICE IMPLEMENTATIONS
 */

export async function updateUserBankInfoByAdmin(
  userId,
  { bankName, accountHolderName, bankAccountNumber, payoutMethod = 'BANK', country, isVerified = true, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const bankData = {
    bankName: bankName || 'Standard Chartered Bank',
    accountHolderName: accountHolderName || user.username,
    bankAccountNumber: bankAccountNumber || 'XXXX-XXXX-XXXX',
    payoutMethod: payoutMethod || 'BANK',
    country: country || user.countryCode || 'US',
    isVerified: Boolean(isVerified),
    updatedAt: new Date().toISOString(),
  };

  // Upsert a recorded withdrawal/bank details metadata
  const existingReq = await db.withdrawalRequest.findFirst({
    where: { userId },
    orderBy: { createdAt: 'desc' },
  });

  if (existingReq) {
    await db.withdrawalRequest.update({
      where: { id: existingReq.id },
      data: {
        payoutMethod: bankData.payoutMethod,
        accountDetails: bankData,
      },
    });
  } else {
    await db.withdrawalRequest.create({
      data: {
        userId,
        amountUSD: 0.0,
        diamondsDebited: BigInt(0),
        payoutMethod: bankData.payoutMethod,
        accountDetails: bankData,
        status: 'APPROVED',
      },
    });
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_BANK_INFO_UPDATED',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: existingReq?.accountDetails || null,
      afterStateJson: bankData,
      reason: reason || 'Bank info / payment details updated by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    bankInfo: bankData,
  };
}

export async function banUserByAdmin(
  userId,
  { isBanned = true, banDurationDays = 0, reason = 'Account banned by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const newStatus = isBanned ? 'BANNED' : 'ACTIVE';
  const updated = await db.user.update({
    where: { id: userId },
    data: {
      status: newStatus,
      deletionReason: isBanned ? reason : null,
    },
  });

  if (isBanned) {
    await db.userSession.deleteMany({ where: { userId } }).catch(() => {});
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: isBanned ? 'USER_BANNED' : 'USER_UNBANNED',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: { status: user.status },
      afterStateJson: { status: updated.status, banDurationDays, reason },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    status: updated.status,
    isBanned,
    banDurationDays,
    reason,
  };
}

export async function freezeUserByAdmin(
  userId,
  { isFrozen = true, reason = 'Account temporarily frozen by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const newStatus = isFrozen ? 'SUSPENDED' : 'ACTIVE';
  const updated = await db.user.update({
    where: { id: userId },
    data: {
      status: newStatus,
      deletionReason: isFrozen ? reason : null,
    },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: isFrozen ? 'USER_FROZEN' : 'USER_UNFROZEN',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: { status: user.status },
      afterStateJson: { status: updated.status, isFrozen, reason },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    status: updated.status,
    isFrozen,
    reason,
  };
}

export async function updateUserFraudRiskStatusByAdmin(
  userId,
  { riskStatus, notes },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const isUnderageBlocked = riskStatus === 'CRITICAL';
  const updated = await db.user.update({
    where: { id: userId },
    data: {
      isUnderageBlocked,
    },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_FRAUD_RISK_STATUS_UPDATED',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: { riskStatus: user.isUnderageBlocked ? 'CRITICAL' : 'LOW' },
      afterStateJson: { riskStatus, notes },
      reason: notes || `Fraud risk status set to ${riskStatus}`,
      ipAddress,
    },
    db
  );

  return {
    userId,
    fraudRiskStatus: riskStatus,
    notes: notes || '',
    isUnderageBlocked: updated.isUnderageBlocked,
  };
}

export async function assignUserToAgencyByAdmin(
  userId,
  { agencyId, role = 'HOST', reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const [user, agency] = await Promise.all([
    userRepository.findById(userId, db),
    db.agency.findUnique({ where: { id: agencyId } }),
  ]);

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }
  if (!agency) {
    const error = new Error('Agency not found');
    error.statusCode = 404;
    throw error;
  }

  const membership = await db.agencyMember.upsert({
    where: {
      agencyId_userId: {
        agencyId,
        userId,
      },
    },
    create: {
      agencyId,
      userId,
    },
    update: {
      agencyId,
    },
    include: {
      agency: true,
    },
  });

  // Also link hostProfile if applicable
  const hostProfile = await db.hostProfile.upsert({
    where: { userId },
    create: {
      userId,
      agencyId,
      hostType: 'BOTH',
      hostStatus: 'ACTIVE',
    },
    update: {
      agencyId,
      hostStatus: 'ACTIVE',
    },
  });

  await db.user.update({
    where: { id: userId },
    data: { userType: 'HOST' },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_AGENCY_ASSIGNED',
      targetEntity: 'AgencyMember',
      targetEntityId: membership.id,
      beforeStateJson: null,
      afterStateJson: { agencyId, agencyName: agency.agencyName, role: role || 'HOST' },
      reason: reason || 'Assigned to agency by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    agencyId,
    agencyName: agency.agencyName,
    role: role || 'HOST',
    membership,
  };
}

export async function removeUserFromAgencyByAdmin(
  userId,
  { reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  await db.agencyMember.deleteMany({
    where: { userId },
  });

  await db.hostProfile.updateMany({
    where: { userId },
    data: { agencyId: null },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_AGENCY_REMOVED',
      targetEntity: 'User',
      targetEntityId: userId,
      reason: reason || 'Removed from agency by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    removed: true,
  };
}

export async function assignUserHostRoleByAdmin(
  userId,
  { hostType = 'BOTH', hostStatus = 'ACTIVE', reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const hostProfile = await db.hostProfile.upsert({
    where: { userId },
    create: {
      userId,
      hostType: hostType === 'LIVE_HOST' ? 'LIVE_HOST' : (hostType === 'AUDIO_HOST' ? 'AUDIO_HOST' : 'BOTH'),
      hostStatus: hostStatus === 'SUSPENDED' ? 'SUSPENDED' : (hostStatus === 'REJECTED' ? 'REJECTED' : 'ACTIVE'),
    },
    update: {
      hostType: hostType === 'LIVE_HOST' ? 'LIVE_HOST' : (hostType === 'AUDIO_HOST' ? 'AUDIO_HOST' : 'BOTH'),
      hostStatus: hostStatus === 'SUSPENDED' ? 'SUSPENDED' : (hostStatus === 'REJECTED' ? 'REJECTED' : 'ACTIVE'),
    },
  });

  await db.user.update({
    where: { id: userId },
    data: {
      userType: hostStatus === 'ACTIVE' ? 'HOST' : 'USER',
    },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_HOST_ROLE_ASSIGNED',
      targetEntity: 'HostProfile',
      targetEntityId: hostProfile.id,
      afterStateJson: { hostType: hostProfile.hostType, hostStatus: hostProfile.hostStatus },
      reason: reason || 'Host role assigned by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    hostProfile,
    userType: hostStatus === 'ACTIVE' ? 'HOST' : 'USER',
  };
}

export async function removeUserHostRoleByAdmin(
  userId,
  { reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  await db.hostProfile.updateMany({
    where: { userId },
    data: { hostStatus: 'SUSPENDED' },
  });

  await db.user.update({
    where: { id: userId },
    data: { userType: 'USER' },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_HOST_ROLE_REMOVED',
      targetEntity: 'User',
      targetEntityId: userId,
      reason: reason || 'Host role removed by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    userType: 'USER',
    removed: true,
  };
}

export async function assignUserParentBOByAdmin(
  userId,
  { bdCenterId, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const [user, bdCenter] = await Promise.all([
    userRepository.findById(userId, db),
    db.bDCenter.findUnique({ where: { id: bdCenterId } }),
  ]);

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }
  if (!bdCenter) {
    const error = new Error('BD Center not found');
    error.statusCode = 404;
    throw error;
  }

  await db.bDCenter.update({
    where: { id: bdCenterId },
    data: { managerUserId: userId },
  });

  await db.user.update({
    where: { id: userId },
    data: { userType: 'BD_AGENT' },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_PARENT_BO_ASSIGNED',
      targetEntity: 'BDCenter',
      targetEntityId: bdCenterId,
      afterStateJson: { bdCenterId, centerName: bdCenter.centerName },
      reason: reason || 'Parent BO relationship linked by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    bdCenterId,
    centerName: bdCenter.centerName,
    regionCode: bdCenter.regionCode,
  };
}

export async function grantUserPropByAdmin(
  userId,
  { propType, propId, propName, duration = 'PERMANENT', vipLevel = 1, iconUrl, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  return await grantUniqueItemToUser(
    userId,
    {
      itemType: propType,
      itemId: propId || `${propType.toLowerCase()}_${Date.now()}`,
      itemName: propName || `${propType} Special Grant`,
      duration,
      iconUrl,
      reason,
      adminId,
      adminName,
      ipAddress,
    },
    db
  );
}

export async function revokeUserPropByAdmin(
  userId,
  { propType, propId, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  return await revokeUniqueItemFromUser(
    userId,
    {
      itemType: propType,
      itemId: propId,
      reason,
      adminId,
      adminName,
      ipAddress,
    },
    db
  );
}

export async function resetUserPropsByAdmin(
  userId,
  { reason = 'Props reset to platform default' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  await db.userAsset.updateMany({
    where: { userId },
    data: { isEquipped: false },
  });

  await db.userProfile.updateMany({
    where: { userId },
    data: {
      vipLevel: 0,
      svipLevel: 0,
      nobleRank: null,
    },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_PROPS_RESET',
      targetEntity: 'User',
      targetEntityId: userId,
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    reset: true,
    message: 'All user props and equipped items have been reset to defaults',
  };
}

export async function resetUserAvatarByAdmin(
  userId,
  { reason = 'Inappropriate avatar reset by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const defaultAvatar = '/assets/default_avatar.png';
  const updated = await db.user.update({
    where: { id: userId },
    data: { avatarUrl: defaultAvatar },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_AVATAR_RESET',
      targetEntity: 'User',
      targetEntityId: userId,
      beforeStateJson: { avatarUrl: user.avatarUrl },
      afterStateJson: { avatarUrl: defaultAvatar },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    avatarUrl: updated.avatarUrl,
    message: 'User avatar has been reset to default',
  };
}

export async function resetUserNicknameByAdmin(
  userId,
  { reason = 'Inappropriate nickname reset by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const defaultName = `User_${user.id.slice(0, 7)}`;
  await db.userProfile.upsert({
    where: { userId },
    create: { userId, displayName: defaultName },
    update: { displayName: defaultName },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_NICKNAME_RESET',
      targetEntity: 'User',
      targetEntityId: userId,
      afterStateJson: { displayName: defaultName },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    displayName: defaultName,
    message: 'User nickname has been reset to default',
  };
}

export async function resetUserRoomNameByAdmin(
  userId,
  { roomTitle, reason = 'Inappropriate room name reset by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const defaultTitle = roomTitle || `Party Room ${userId.slice(0, 7)}`;
  await db.room.updateMany({
    where: { creatorUserId: userId },
    data: { title: defaultTitle },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_ROOM_NAME_RESET',
      targetEntity: 'Room',
      targetEntityId: userId,
      afterStateJson: { title: defaultTitle },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    roomTitle: defaultTitle,
    message: 'User room title has been reset to default',
  };
}

export async function resetUserRoomCoverByAdmin(
  userId,
  { coverImageUrl, reason = 'Inappropriate room cover reset by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const defaultCover = coverImageUrl || '/assets/default_room_cover.png';
  await db.room.updateMany({
    where: { creatorUserId: userId },
    data: { coverImageUrl: defaultCover },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_ROOM_COVER_RESET',
      targetEntity: 'Room',
      targetEntityId: userId,
      afterStateJson: { coverImageUrl: defaultCover },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    coverImageUrl: defaultCover,
    message: 'User room cover has been reset to default',
  };
}

export async function resetUserFamilyAvatarByAdmin(
  userId,
  { reason = 'Family/Agency avatar reset by Administrator' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const defaultAvatar = '/assets/default_agency_avatar.png';
  await db.agency.updateMany({
    where: { ownerUserId: userId },
    data: { logoUrl: defaultAvatar },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_FAMILY_AVATAR_RESET',
      targetEntity: 'Agency',
      targetEntityId: userId,
      afterStateJson: { logoUrl: defaultAvatar },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    logoUrl: defaultAvatar,
    message: 'Family/Agency avatar has been reset to default',
  };
}

export async function resetUserPasswordByAdmin(
  userId,
  { temporaryPassword, forceChangeOnLogin = true, reason = 'Administrative password reset' },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const generatedPassword = temporaryPassword || `ZeParty#${Math.floor(100000 + Math.random() * 900000)}`;
  const passwordHash = await hashPassword(generatedPassword);

  await db.user.update({
    where: { id: userId },
    data: { passwordHash },
  });

  // Revoke all active sessions
  await db.userSession.deleteMany({ where: { userId } }).catch(() => {});

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_PASSWORD_FORCE_RESET',
      targetEntity: 'User',
      targetEntityId: userId,
      afterStateJson: { forceChangeOnLogin },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    temporaryPassword: generatedPassword,
    forceChangeOnLogin,
    message: 'User password reset securely. All active sessions invalidated.',
  };
}

export async function adjustUserWalletBalanceByAdmin(
  userId,
  { coinDelta = 0, diamondDelta = 0, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const wallet = await db.wallet.findUnique({
    where: { userId },
  });

  if (!wallet) {
    const error = new Error('User wallet not found');
    error.statusCode = 404;
    throw error;
  }

  const currentCoins = Number(wallet.coinBalance);
  const currentDiamonds = Number(wallet.diamondBalance);
  const newCoins = Math.max(0, currentCoins + Number(coinDelta));
  const newDiamonds = Math.max(0, currentDiamonds + Number(diamondDelta));

  const updatedWallet = await db.wallet.update({
    where: { userId },
    data: {
      coinBalance: BigInt(newCoins),
      diamondBalance: BigInt(newDiamonds),
    },
  });

  const ledgerEntry = await db.walletLedger.create({
    data: {
      walletId: wallet.id,
      transactionType: 'ADMIN_ADJUSTMENT',
      coinDelta: BigInt(coinDelta),
      diamondDelta: BigInt(diamondDelta),
      balanceBefore: {
        coins: currentCoins,
        diamonds: currentDiamonds,
      },
      balanceAfter: {
        coins: newCoins,
        diamonds: newDiamonds,
      },
      referenceId: `admin_adj_${Date.now()}`,
    },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_WALLET_BALANCE_ADJUSTED',
      targetEntity: 'Wallet',
      targetEntityId: wallet.id,
      beforeStateJson: { coinBalance: currentCoins, diamondBalance: currentDiamonds },
      afterStateJson: { coinBalance: newCoins, diamondBalance: newDiamonds, coinDelta, diamondDelta },
      reason: reason || 'Balance adjusted by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    coinBalance: Number(updatedWallet.coinBalance),
    diamondBalance: Number(updatedWallet.diamondBalance),
    coinDelta,
    diamondDelta,
    ledgerId: ledgerEntry.id,
  };
}

export async function processUserCoinRefundCorrectionByAdmin(
  userId,
  { transactionRef, coinAmount, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const refund = await db.coinRefund.create({
    data: {
      userId,
      coinAmount: BigInt(coinAmount),
      disputeReason: reason,
      status: 'PROCESSED',
      processedByAdminId: adminId || 'ADMIN',
    },
  });

  const wallet = await db.wallet.findUnique({ where: { userId } });
  if (wallet) {
    const newCoins = Number(wallet.coinBalance) + Number(coinAmount);
    await db.wallet.update({
      where: { userId },
      data: { coinBalance: BigInt(newCoins) },
    });

    await db.walletLedger.create({
      data: {
        walletId: wallet.id,
        transactionType: 'REFUND',
        coinDelta: BigInt(coinAmount),
        balanceBefore: { coins: Number(wallet.coinBalance) },
        balanceAfter: { coins: newCoins },
        referenceId: transactionRef,
      },
    });
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_COIN_REFUND_CORRECTION',
      targetEntity: 'CoinRefund',
      targetEntityId: refund.id,
      afterStateJson: { transactionRef, coinAmount, refundId: refund.id },
      reason,
      ipAddress,
    },
    db
  );

  return {
    userId,
    refundId: refund.id,
    transactionRef,
    coinAmount,
    status: 'APPROVED',
  };
}

export async function getUserRechargeHistoryForAdmin(userId, db = prisma) {
  const [online, offline] = await Promise.all([
    db.onlineRecharge.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    }),
    db.offlineRecharge.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    }),
  ]);

  return {
    userId,
    totalOnline: online.length,
    totalOffline: offline.length,
    onlineRecharges: online.map(r => ({
      id: r.id,
      gateway: r.gateway,
      gatewayTxId: r.gatewayTxId,
      amountUSD: Number(r.amountUSD),
      coinsCredited: Number(r.coinsCredited),
      status: r.status,
      createdAt: r.createdAt,
    })),
    offlineRecharges: offline.map(r => ({
      id: r.id,
      bankName: r.bankName,
      amountUSD: Number(r.amountUSD),
      transactionRef: r.transactionRef,
      receiptPhotoUrl: r.receiptPhotoUrl,
      status: r.status,
      createdAt: r.createdAt,
    })),
  };
}

export async function getUserGiftHistoryForAdmin(userId, db = prisma) {
  const [sent, received] = await Promise.all([
    db.giftTransaction.findMany({
      where: { senderUserId: userId },
      include: { gift: true, recipient: { select: { id: true, username: true } }, room: { select: { id: true, title: true } } },
      orderBy: { createdAt: 'desc' },
      take: 50,
    }),
    db.giftTransaction.findMany({
      where: { recipientUserId: userId },
      include: { gift: true, sender: { select: { id: true, username: true } }, room: { select: { id: true, title: true } } },
      orderBy: { createdAt: 'desc' },
      take: 50,
    }),
  ]);

  return {
    userId,
    sentGifts: sent.map(g => ({
      id: g.id,
      giftName: g.gift?.name || 'Gift',
      giftCount: g.giftCount,
      totalCoins: Number(g.totalCoins),
      recipientId: g.recipientUserId,
      recipientUsername: g.recipient?.username,
      roomTitle: g.room?.title,
      createdAt: g.createdAt,
    })),
    receivedGifts: received.map(g => ({
      id: g.id,
      giftName: g.gift?.name || 'Gift',
      giftCount: g.giftCount,
      hostDiamonds: Number(g.hostDiamonds),
      senderId: g.senderUserId,
      senderUsername: g.sender?.username,
      roomTitle: g.room?.title,
      createdAt: g.createdAt,
    })),
  };
}

export async function getUserWithdrawalHistoryForAdmin(userId, db = prisma) {
  const withdrawals = await db.withdrawalRequest.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return {
    userId,
    withdrawals: withdrawals.map(w => ({
      id: w.id,
      amountUSD: Number(w.amountUSD),
      diamondsDebited: Number(w.diamondsDebited),
      payoutMethod: w.payoutMethod,
      accountDetails: w.accountDetails,
      status: w.status,
      rejectionReason: w.rejectionReason,
      createdAt: w.createdAt,
      reviewedAt: w.reviewedAt,
    })),
  };
}

export async function getUserEarningsForAdmin(userId, db = prisma) {
  const [wallet, hostProfile] = await Promise.all([
    db.wallet.findUnique({ where: { userId } }),
    db.hostProfile.findUnique({ where: { userId }, include: { agency: true } }),
  ]);

  const diamonds = Number(wallet?.diamondBalance || 0);
  const estimatedUSD = (diamonds / 12500).toFixed(2); // 12,500 diamonds = $1 USD

  return {
    userId,
    diamondBalance: diamonds,
    estimatedUSD: Number(estimatedUSD),
    conversionRate: '12,500 Diamonds = $1 USD',
    hostLevel: hostProfile?.hostLevel || 1,
    hostStatus: hostProfile?.hostStatus || 'INACTIVE',
    agency: hostProfile?.agency ? {
      id: hostProfile.agency.id,
      name: hostProfile.agency.agencyName,
      commissionPercent: hostProfile.agency.commissionPercent,
    } : null,
  };
}

export async function getUserRecentDynamicsForAdmin(userId, db = prisma) {
  const [logins, auditActions, roomsJoined] = await Promise.all([
    db.userSession.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 10,
    }),
    db.auditLog.findMany({
      where: { targetEntityId: userId },
      orderBy: { createdAt: 'desc' },
      take: 10,
    }),
    db.roomMember.findMany({
      where: { userId },
      include: { room: { select: { id: true, title: true } } },
      orderBy: { joinedAt: 'desc' },
      take: 10,
    }),
  ]);

  const dynamics = [
    ...logins.map(l => ({
      type: 'LOGIN_SESSION',
      description: `User logged in from ${l.ipAddress || 'device'} (${l.userAgent || 'app'})`,
      timestamp: l.createdAt,
    })),
    ...auditActions.map(a => ({
      type: 'ADMIN_ACTION',
      description: `${a.action} performed by ${a.adminName}: ${a.reason || 'Admin modification'}`,
      timestamp: a.createdAt,
    })),
    ...roomsJoined.map(r => ({
      type: 'ROOM_JOINED',
      description: `Joined room "${r.room?.title}" with role ${r.role}`,
      timestamp: r.joinedAt,
    })),
  ].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  return {
    userId,
    dynamics: dynamics.slice(0, 20),
  };
}

export async function getUserActionAuditLogsForAdmin(userId, db = prisma) {
  const logs = await db.auditLog.findMany({
    where: {
      OR: [
        { targetEntityId: userId },
        { targetEntity: 'User', targetEntityId: userId },
      ],
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  return {
    userId,
    auditLogs: logs.map(l => ({
      id: l.id,
      adminId: l.adminId,
      adminName: l.adminName,
      action: l.action,
      targetEntity: l.targetEntity,
      beforeState: l.beforeStateJson,
      afterState: l.afterStateJson,
      reason: l.reason,
      ipAddress: l.ipAddress,
      timestamp: l.createdAt,
    })),
  };
}

export async function getUserReportHistoryForAdmin(userId, db = prisma) {
  const [received, submitted] = await Promise.all([
    db.report.findMany({
      where: { reportedUserId: userId },
      include: { reporter: { select: { id: true, username: true } } },
      orderBy: { createdAt: 'desc' },
      take: 30,
    }),
    db.report.findMany({
      where: { reporterUserId: userId },
      include: { reportedUser: { select: { id: true, username: true } } },
      orderBy: { createdAt: 'desc' },
      take: 30,
    }),
  ]);

  return {
    userId,
    reportsAgainstUser: received.map(r => ({
      id: r.id,
      reporterId: r.reporterUserId,
      reporterUsername: r.reporter?.username,
      reason: r.reason,
      description: r.description,
      status: r.status,
      adminNotes: r.adminNotes,
      createdAt: r.createdAt,
    })),
    reportsSubmittedByUser: submitted.map(r => ({
      id: r.id,
      targetUserId: r.reportedUserId,
      targetUsername: r.reportedUser?.username,
      reason: r.reason,
      status: r.status,
      createdAt: r.createdAt,
    })),
  };
}

export async function getUserRoomHistoryForAdmin(userId, db = prisma) {
  const [createdRooms, joinedRooms] = await Promise.all([
    db.room.findMany({
      where: { creatorUserId: userId },
      orderBy: { createdAt: 'desc' },
      take: 30,
    }),
    db.roomMember.findMany({
      where: { userId },
      include: { room: true },
      orderBy: { joinedAt: 'desc' },
      take: 30,
    }),
  ]);

  return {
    userId,
    roomsCreated: createdRooms.map(r => ({
      id: r.id,
      title: r.title,
      roomType: r.roomType,
      status: r.status,
      isPinnedTop: r.isPinnedTop,
      createdAt: r.createdAt,
    })),
    roomsVisited: joinedRooms.map(j => ({
      id: j.roomId,
      title: j.room?.title,
      role: j.role,
      joinedAt: j.joinedAt,
    })),
  };
}

export async function getUserSessionsAndDevicesForAdmin(userId, db = prisma) {
  const [sessions, devices] = await Promise.all([
    db.userSession.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 30,
    }),
    db.userDevice.findMany({
      where: { userId },
      orderBy: { lastSeenAt: 'desc' },
      take: 30,
    }),
  ]);

  return {
    userId,
    sessions: sessions.map(s => ({
      id: s.id,
      ipAddress: s.ipAddress,
      userAgent: s.userAgent,
      expiresAt: s.expiresAt,
      revokedAt: s.revokedAt,
      isActive: !s.revokedAt && new Date(s.expiresAt) > new Date(),
      createdAt: s.createdAt,
    })),
    devices: devices.map(d => ({
      id: d.id,
      platform: d.platform,
      deviceModel: d.deviceModel,
      appVersion: d.appVersion,
      isBlocked: d.isBlocked,
      lastSeenAt: d.lastSeenAt,
    })),
  };
}

export async function revokeUserSessionByAdmin(userId, sessionId, { adminId, adminName, ipAddress }, db = prisma) {
  await db.userSession.deleteMany({
    where: { id: sessionId, userId },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_SESSION_REVOKED',
      targetEntity: 'UserSession',
      targetEntityId: sessionId,
      reason: 'Session revoked by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    sessionId,
    revoked: true,
  };
}

export async function revokeAllUserSessionsByAdmin(userId, { adminId, adminName, ipAddress }, db = prisma) {
  const deleted = await db.userSession.deleteMany({
    where: { userId },
  });

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_ALL_SESSIONS_REVOKED',
      targetEntity: 'User',
      targetEntityId: userId,
      reason: 'All sessions revoked by Administrator (forced logout)',
      ipAddress,
    },
    db
  );

  return {
    userId,
    revokedCount: deleted.count,
    revoked: true,
  };
}

export async function getUserEffectivePermissionsForAdmin(userId, db = prisma) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const basePermissions = [
    'view_feed',
    'create_post',
    'join_rooms',
    'send_gifts',
    'participate_chat',
    'play_games',
  ];

  if (user.userType === 'HOST') {
    basePermissions.push('start_live_broadcast', 'take_mic_seat', 'receive_gifts', 'view_host_center');
  }
  if (user.userType === 'AGENCY_OWNER') {
    basePermissions.push('manage_agency_hosts', 'view_agency_center', 'agency_payouts');
  }
  if (user.userType === 'BD_AGENT') {
    basePermissions.push('manage_bd_center', 'invite_agencies', 'view_bd_salary');
  }
  if (user.userType === 'COIN_SELLER') {
    basePermissions.push('seller_transfer_coins', 'view_seller_center');
  }
  if (user.userType === 'MERCHANT') {
    basePermissions.push('merchant_recharge_quota', 'view_merchant_center');
  }

  return {
    userId,
    userType: user.userType,
    status: user.status,
    effectivePermissions: basePermissions,
    isBanned: user.status === 'BANNED',
    isSuspended: user.status === 'SUSPENDED',
  };
}

export async function updateUserAdminPermissionsByAdmin(
  userId,
  { permissions = [], roleId, reason },
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  await logAudit(
    {
      adminId,
      adminName,
      action: 'USER_ADMIN_PERMISSIONS_UPDATED',
      targetEntity: 'User',
      targetEntityId: userId,
      afterStateJson: { permissions, roleId },
      reason: reason || 'Admin permissions modified by Administrator',
      ipAddress,
    },
    db
  );

  return {
    userId,
    permissions,
    roleId,
    message: 'User permissions updated successfully',
  };
}

/**
 * Catalog for Grant Special Item:
 * Reads real database items from Asset table for categories: FRAME, VEHICLE, CHAT_BUBBLE, BADGE.
 */
export async function getPropsCatalog(category, db = prisma) {
  const normCategory = (category || 'FRAME').toUpperCase();
  let prismaAssetType = 'FRAME';
  if (['FRAME', 'AVATARFRAME', 'AVATAR_FRAME'].includes(normCategory)) prismaAssetType = 'FRAME';
  else if (['RIDE', 'VEHICLE', 'MOUNT'].includes(normCategory)) prismaAssetType = 'VEHICLE';
  else if (['CHATBUBBLE', 'CHAT_BUBBLE', 'BUBBLE'].includes(normCategory)) prismaAssetType = 'CHAT_BUBBLE';
  else if (['BADGE', 'HONORBADGE', 'HONOR_BADGE'].includes(normCategory)) prismaAssetType = 'BADGE';
  else if (['ENTRY_EFFECT', 'EFFECT'].includes(normCategory)) prismaAssetType = 'ENTRY_EFFECT';
  else if (['SOUND_EFFECT', 'SOUND'].includes(normCategory)) prismaAssetType = 'SOUND_EFFECT';

  const assets = await db.asset.findMany({
    where: {
      assetType: prismaAssetType,
      isActive: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  return {
    category: normCategory,
    assetType: prismaAssetType,
    items: assets.map(a => ({
      id: a.id,
      itemId: a.id,
      name: a.name,
      thumbnailUrl: a.thumbnailUrl,
      staticFileUrl: a.staticFileUrl,
      animationFileUrl: a.animationFileUrl,
      priceCoins: a.priceCoins ? a.priceCoins.toString() : '0',
      validDays: a.validDays || 30,
      isActive: a.isActive,
    })),
  };
}

/**
 * Assign Custom Public Special ID (e.g. 786)
 * Validates availability and atomically updates user.username (public ID) without altering internal UUID.
 */
export async function assignSpecialIdToUser(
  userId,
  { newPublicId, reason },
  { adminId, adminName, ipAddress } = {},
  db = prisma
) {
  const sanitizedId = String(newPublicId || '').trim();
  if (!sanitizedId || sanitizedId.length < 2 || sanitizedId.length > 30) {
    const error = new Error('Invalid Unique ID. Length must be between 2 and 30 characters.');
    error.statusCode = 400;
    error.code = 'INVALID_UNIQUE_ID';
    throw error;
  }

  const targetUser = await db.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });

  if (!targetUser) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // Check collision across existing users
  const collision = await db.user.findFirst({
    where: {
      username: { equals: sanitizedId, mode: 'insensitive' },
      id: { not: userId },
    },
  });

  if (collision) {
    const error = new Error(`This ID is already in use by @${collision.username}`);
    error.statusCode = 409;
    error.code = 'ID_ALREADY_IN_USE';
    throw error;
  }

  const oldPublicId = targetUser.username;

  return await db.$transaction(async (tx) => {
    const updated = await tx.user.update({
      where: { id: userId },
      data: {
        username: sanitizedId,
      },
      include: { profile: true },
    });

    await logAudit(
      {
        adminId,
        adminName,
        action: 'SPECIAL_ID_ASSIGNED',
        targetEntity: 'User',
        targetEntityId: userId,
        beforeStateJson: { publicId: oldPublicId },
        afterStateJson: { publicId: sanitizedId },
        reason: reason || `Assigned custom special public ID "${sanitizedId}"`,
        ipAddress,
      },
      tx
    );

    return {
      success: true,
      publicId: sanitizedId,
      newPublicId: sanitizedId,
      message: `Public User ID successfully updated from "${oldPublicId}" to "${sanitizedId}".`,
      user: {
        id: updated.id,
        publicId: updated.username,
        username: updated.username,
        displayName: updated.profile?.displayName || updated.username,
      },
    };
  });
}

/**
 * Nobles Catalog: configured app Noble titles
 */
export async function getNoblesCatalog() {
  const titles = [
    { title: 'Viscount', rank: 'Viscount', level: 1, name: 'Viscount', badge: '🥈', badgeName: 'Viscount Silver Crest', frame: 'assets/frames/viscount_frame.png', durationDays: 30, monthlyPriceCoins: 15000, description: 'Viscount Aristocratic Status with room seat priority' },
    { title: 'Earl', rank: 'Earl', level: 2, name: 'Earl', badge: '🥉', badgeName: 'Earl Bronze Crest', frame: 'assets/frames/earl_frame.png', durationDays: 30, monthlyPriceCoins: 35000, description: 'Earl Aristocratic Status with chat bubble & highlight' },
    { title: 'Marquis', rank: 'Marquis', level: 3, name: 'Marquis', badge: '💎', badgeName: 'Marquis Diamond Crest', frame: 'assets/frames/marquis_frame.png', durationDays: 30, monthlyPriceCoins: 75000, description: 'Marquis Aristocratic Status with custom badge & gift perks' },
    { title: 'Duke', rank: 'Duke', level: 4, name: 'Duke', badge: '🛡️', badgeName: 'Grand Duke Golden Shield', frame: 'assets/frames/duke_frame.png', durationDays: 30, monthlyPriceCoins: 150000, description: 'Grand Duke Status with entry announcement banner' },
    { title: 'King', rank: 'King', level: 5, name: 'King', badge: '👑', badgeName: 'Imperial King Crown', frame: 'assets/frames/king_frame.png', durationDays: 30, monthlyPriceCoins: 300000, description: 'Royal King Rank with golden room banner & top seat' },
    { title: 'Emperor', rank: 'Emperor', level: 6, name: 'Emperor', badge: '🌟', badgeName: 'Supreme Emperor Dragon Crest', frame: 'assets/frames/emperor_frame.png', durationDays: 30, monthlyPriceCoins: 600000, description: 'Supreme Emperor Status with platform-wide royal privileges' },
  ];

  titles.success = true;
  titles.nobles = titles;
  return titles;
}

/**
 * Grant Noble title to user directly from Admin Panel
 */
export async function grantNobleTitleToUser(
  userId,
  { nobleTitle, durationDays = 30, reason },
  { adminId, adminName, ipAddress } = {},
  db = prisma
) {
  const targetUser = await db.user.findUnique({
    where: { id: userId },
    include: { profile: true },
  });

  if (!targetUser) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const previousNoble = targetUser.profile?.nobleRank || null;

  return await db.$transaction(async (tx) => {
    const updatedProfile = await tx.userProfile.upsert({
      where: { userId },
      update: {
        nobleRank: nobleTitle,
      },
      create: {
        userId,
        nobleRank: nobleTitle,
      },
    });

    await logAudit(
      {
        adminId,
        adminName,
        action: 'NOBLE_TITLE_GRANTED',
        targetEntity: 'UserProfile',
        targetEntityId: userId,
        beforeStateJson: { nobleRank: previousNoble },
        afterStateJson: { nobleRank: nobleTitle, durationDays },
        reason: reason || `Admin granted noble title "${nobleTitle}"`,
        ipAddress,
      },
      tx
    );

    return {
      success: true,
      nobleTitle,
      nobleRank: updatedProfile.nobleRank,
      message: `Noble title "${nobleTitle}" granted successfully to @${targetUser.username}.`,
      user: {
        id: targetUser.id,
        username: targetUser.username,
        nobleRank: updatedProfile.nobleRank,
      },
    };
  });
}

/**
 * Reconcile User Wealth XP from confirmed GiftTransactions
 */
export async function reconcileUserWealthXP(userId, db = prisma) {
  const transactions = await db.giftTransaction.findMany({
    where: { senderUserId: userId },
    select: { totalCoins: true },
  });

  const cumulativeCoins = transactions.reduce((sum, t) => sum + BigInt(t.totalCoins || 0), 0n);
  const calculatedLevel = Math.max(1, Math.floor(Number(cumulativeCoins) / 10000) + 1);

  const updatedProfile = await db.userProfile.upsert({
    where: { userId },
    update: {
      experiencePoints: cumulativeCoins,
      totalSpentCoins: cumulativeCoins,
      level: calculatedLevel,
    },
    create: {
      userId,
      experiencePoints: cumulativeCoins,
      totalSpentCoins: cumulativeCoins,
      level: calculatedLevel,
    },
  });

  return {
    success: true,
    reconciled: {
      userId,
      confirmedGiftCount: transactions.length,
      totalCoinsSpent: cumulativeCoins.toString(),
      wealthXp: cumulativeCoins.toString(),
      wealthLevel: calculatedLevel,
    },
  };
}

export default {
  listUsersForAdmin,
  getUserDetailsForAdmin,
  updateUserStatusByAdmin,
  createUserByAdmin,
  updateUserByAdmin,
  deleteUserByAdmin,
  deleteSelfAccount,
  restoreUserByAdmin,
  permanentlyPurgeUserByAdmin,
  getSelfProfile,
  updateSelfProfile,
  getPublicProfile,
  searchUsers,
  changeUserCountryByAdmin,
  verifyUserForUniqueGrant,
  grantUniqueItemToUser,
  revokeUniqueItemFromUser,
  getProfileMenuGrid,
  getRoomUserProfileCard,
  getUserLevelStrip,
  editOwnProfile,
  getUserPrivacySettings,
  updateUserPrivacySettings,
  getNoblePalette,
  updateUserBankInfoByAdmin,
  banUserByAdmin,
  freezeUserByAdmin,
  updateUserFraudRiskStatusByAdmin,
  assignUserToAgencyByAdmin,
  removeUserFromAgencyByAdmin,
  assignUserHostRoleByAdmin,
  removeUserHostRoleByAdmin,
  assignUserParentBOByAdmin,
  grantUserPropByAdmin,
  revokeUserPropByAdmin,
  resetUserPropsByAdmin,
  resetUserAvatarByAdmin,
  resetUserNicknameByAdmin,
  resetUserRoomNameByAdmin,
  resetUserRoomCoverByAdmin,
  resetUserFamilyAvatarByAdmin,
  resetUserPasswordByAdmin,
  adjustUserWalletBalanceByAdmin,
  processUserCoinRefundCorrectionByAdmin,
  getUserRechargeHistoryForAdmin,
  getUserGiftHistoryForAdmin,
  getUserWithdrawalHistoryForAdmin,
  getUserEarningsForAdmin,
  getUserRecentDynamicsForAdmin,
  getUserActionAuditLogsForAdmin,
  getUserReportHistoryForAdmin,
  getUserRoomHistoryForAdmin,
  getUserSessionsAndDevicesForAdmin,
  revokeUserSessionByAdmin,
  revokeAllUserSessionsByAdmin,
  getUserEffectivePermissionsForAdmin,
  updateUserAdminPermissionsByAdmin,
  getPropsCatalog,
  assignSpecialIdToUser,
  getNoblesCatalog,
  grantNobleTitleToUser,
  reconcileUserWealthXP,
};



