import crypto from 'crypto';
import otpService from './otp.service.js';
import sessionService from './session.service.js';
import userRepository from '../repositories/user.repository.js';
import deviceRepository from '../repositories/device.repository.js';
import loginAttemptRepository from '../repositories/login-attempt.repository.js';
import adminRepository from '../repositories/admin.repository.js';
import { comparePassword, hashToken } from '../utils/crypto.util.js';
import sessionRepository from '../repositories/session.repository.js';
import effectivePermissionsService from './effectivePermissions.service.js';

export async function requestOtp({ phone, purpose = 'LOGIN', ipAddress, logger }) {
  return await otpService.requestOtp({ phone, purpose, ipAddress, logger });
}

export async function verifyOtpAndAuthenticate({
  phone,
  code,
  purpose = 'LOGIN',
  device = {},
  ipAddress,
  userAgent,
  logger,
}) {
  const normalizedPhone = otpService.normalizePhone(phone);

  // Security check: IP blocking
  const isIpBlocked = await deviceRepository.isIpBlocked(ipAddress);
  if (isIpBlocked) {
    await loginAttemptRepository.recordLoginAttempt({
      identifier: normalizedPhone,
      ipAddress,
      userAgent,
      isSuccessful: false,
      failureReason: 'IP_BLOCKED',
    });
    const error = new Error('Access denied. Your IP address is blocked.');
    error.status = 403;
    error.code = 'IP_BLOCKED';
    throw error;
  }

  // Security check: Device blocking
  const isDeviceBlocked = await deviceRepository.isDeviceBlocked({
    deviceToken: device.deviceToken,
    macAddress: device.macAddress,
  });
  if (isDeviceBlocked) {
    await loginAttemptRepository.recordLoginAttempt({
      identifier: normalizedPhone,
      ipAddress,
      userAgent,
      isSuccessful: false,
      failureReason: 'DEVICE_BLOCKED',
    });
    const error = new Error('Access denied. Your device is restricted.');
    error.status = 403;
    error.code = 'DEVICE_BLOCKED';
    throw error;
  }

  // Verify OTP code
  await otpService.verifyOtp({ phone: normalizedPhone, code, purpose });

  // Find or Create User
  let user = await userRepository.findByPhone(normalizedPhone);
  let isNewUser = false;

  if (!user) {
    const randomSuffix = crypto.randomBytes(4).toString('hex');
    const defaultUsername = `user_${randomSuffix}`;

    user = await userRepository.createUserWithProfile({
      phone: normalizedPhone,
      username: defaultUsername,
      status: 'ACTIVE',
      userType: 'USER',
    });
    isNewUser = true;
  }

  // Verify Account Status
  if (user.status !== 'ACTIVE') {
    await loginAttemptRepository.recordLoginAttempt({
      identifier: normalizedPhone,
      ipAddress,
      userAgent,
      isSuccessful: false,
      failureReason: `ACCOUNT_${user.status}`,
    });
    const error = new Error(`Account is ${user.status.toLowerCase()}. Access restricted.`);
    error.status = 403;
    error.code = user.status === 'SUSPENDED' ? 'ACCOUNT_SUSPENDED' : 'ACCOUNT_BANNED';
    throw error;
  }

  // Record/update UserDevice
  if (device && (device.deviceToken || device.macAddress || device.platform)) {
    await deviceRepository.upsertDevice({
      userId: user.id,
      deviceToken: device.deviceToken,
      platform: device.platform || 'ANDROID',
      macAddress: device.macAddress,
      deviceModel: device.deviceModel,
      appVersion: device.appVersion,
    });
  }

  // Create UserSession and issue token pair
  const sessionResult = await sessionService.createSession({
    userId: user.id,
    userType: user.userType,
    ipAddress,
    userAgent,
  });

  // Update user last login
  await userRepository.updateLastLogin(user.id);

  // Record successful login attempt
  await loginAttemptRepository.recordLoginAttempt({
    identifier: normalizedPhone,
    ipAddress,
    userAgent,
    isSuccessful: true,
  });

  return {
    isNewUser,
    user: sanitizeUser(user),
    accessToken: sessionResult.accessToken,
    refreshToken: sessionResult.refreshToken,
    expiresAt: sessionResult.expiresAt,
  };
}

export async function refreshToken({ refreshToken, ipAddress, userAgent }) {
  return await sessionService.rotateRefreshToken({ refreshToken, ipAddress, userAgent });
}

export async function logout({ sessionId, refreshToken }) {
  if (sessionId) {
    await sessionService.revokeSession(sessionId).catch(() => {});
  }
  if (refreshToken) {
    try {
      const tokenHash = hashToken(refreshToken);
      const session = await sessionRepository.findActiveSessionByRefreshTokenHash(tokenHash);
      if (session) {
        await sessionService.revokeSession(session.id).catch(() => {});
      }
    } catch {}
  }
  return { success: true, message: 'Successfully logged out.' };
}

export async function getCurrentUser({ userId }) {
  const user = await userRepository.findById(userId);
  if (!user) {
    const error = new Error('Authenticated user not found.');
    error.status = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }
  return sanitizeUser(user);
}

export async function adminLogin({ usernameOrEmail, password, ipAddress, userAgent }) {
  const admin = await adminRepository.findByUsernameOrEmail(usernameOrEmail);

  if (!admin) {
    await loginAttemptRepository.recordLoginAttempt({
      identifier: usernameOrEmail,
      ipAddress,
      userAgent,
      isSuccessful: false,
      failureReason: 'ADMIN_NOT_FOUND',
    });
    const error = new Error('Invalid administrative credentials.');
    error.status = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  if (admin.status !== 'ACTIVE') {
    await loginAttemptRepository.recordLoginAttempt({
      identifier: usernameOrEmail,
      ipAddress,
      userAgent,
      isSuccessful: false,
      failureReason: `ADMIN_${admin.status}`,
    });
    const error = new Error('Admin account is suspended or inactive.');
    error.status = 403;
    error.code = 'ACCOUNT_SUSPENDED';
    throw error;
  }

  const isValidPassword = await comparePassword(password, admin.passwordHash);
  if (!isValidPassword) {
    await loginAttemptRepository.recordLoginAttempt({
      identifier: usernameOrEmail,
      ipAddress,
      userAgent,
      isSuccessful: false,
      failureReason: 'INVALID_PASSWORD',
    });
    const error = new Error('Invalid administrative credentials.');
    error.status = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const isOwner = Boolean(admin.isOwner);

  // Session creation for Admin / Owner
  const sessionResult = await sessionService.createSession({
    userId: admin.id,
    userType: 'ADMIN',
    roleId: admin.roleId || (isOwner ? 'owner' : 'super_admin'),
    isAdmin: true,
    isOwner: isOwner,
    ipAddress,
    userAgent,
  });

  await loginAttemptRepository.recordLoginAttempt({
    identifier: usernameOrEmail,
    ipAddress,
    userAgent,
    isSuccessful: true,
  });

  const effective = await effectivePermissionsService.calculateEffectivePermissions(admin);

  return {
    admin: {
      id: admin.id,
      name: admin.name,
      username: admin.username,
      email: admin.email,
      status: admin.status,
      isSuperAdmin: Boolean(admin.isSuperAdmin || isOwner),
      isOwner: isOwner,
      role: admin.roleId || (isOwner ? 'owner' : 'super_admin'),
      effectiveModules: effective.modules,
      permissions: effective.permissions,
      canApprove: effective.canApprove,
    },
    accessToken: sessionResult.accessToken,
    refreshToken: sessionResult.refreshToken,
    expiresAt: sessionResult.expiresAt,
  };
}

function sanitizeUser(user) {
  if (!user) return null;
  const { passwordHash, ...safeUser } = user;
  return {
    ...safeUser,
    profile: safeUser.profile
      ? {
          ...safeUser.profile,
          experiencePoints: safeUser.profile.experiencePoints
            ? safeUser.profile.experiencePoints.toString()
            : '0',
          totalSpentCoins: safeUser.profile.totalSpentCoins
            ? safeUser.profile.totalSpentCoins.toString()
            : '0',
          totalEarnedDiamonds: safeUser.profile.totalEarnedDiamonds
            ? safeUser.profile.totalEarnedDiamonds.toString()
            : '0',
        }
      : null,
    wallet: safeUser.wallet
      ? {
          ...safeUser.wallet,
          coinBalance: safeUser.wallet.coinBalance ? safeUser.wallet.coinBalance.toString() : '0',
          diamondBalance: safeUser.wallet.diamondBalance ? safeUser.wallet.diamondBalance.toString() : '0',
          sellerBalanceCoins: safeUser.wallet.sellerBalanceCoins
            ? safeUser.wallet.sellerBalanceCoins.toString()
            : '0',
          escrowLockedCoins: safeUser.wallet.escrowLockedCoins
            ? safeUser.wallet.escrowLockedCoins.toString()
            : '0',
        }
      : null,
  };
}

export async function syncUserFromApp({
  uid,
  id,
  email,
  name,
  displayName,
  username,
  avatarUrl,
  bio,
  gender,
  dob,
  countryCode,
  phone,
  coins = 1000,
  diamonds = 100,
  isSignup = false,
  device = {},
  ipAddress,
  userAgent,
}) {
  const targetId = id || uid;
  const cleanEmail = email && typeof email === 'string' && email.trim() ? email.trim().toLowerCase() : null;
  const cleanPhone = phone && typeof phone === 'string' && phone.trim() ? phone.trim() : null;
  const firebaseUid = (uid && !/^[1-9]\d{6}$/.test(String(uid))) ? String(uid) : null;

  // Sanitize display name to filter out raw technical IDs/UIDs and clamp to 25 chars max
  const isTechIdStr = (str) => {
    if (!str || typeof str !== 'string') return true;
    const t = str.trim();
    return t.length >= 20 || /^[a-zA-Z0-9_-]{20,}$/.test(t) || t.startsWith('user_') || t.startsWith('google_');
  };

  let cleanName = null;
  const rawInputName = displayName || name;
  if (rawInputName && !isTechIdStr(rawInputName)) {
    cleanName = rawInputName.trim().slice(0, 25).trim();
  }
  if (!cleanName && cleanEmail) {
    const handle = cleanEmail.split('@')[0].trim();
    if (handle) {
      cleanName = (handle.charAt(0).toUpperCase() + handle.slice(1)).slice(0, 25).trim();
    }
  }
  if (!cleanName) {
    cleanName = 'ZeParty Member';
  }

  let user = null;
  let isNewUser = false;

  if (isSignup) {
    // ----------------------------------------------------
    // STRICT SIGNUP VALIDATION - NEVER MERGE OR OVERLAP USERS
    // ----------------------------------------------------
    if (cleanEmail) {
      const existing = await userRepository.findByEmail(cleanEmail);
      if (existing) {
        if (existing.status === 'DELETED') {
          const err = new Error('An account with this email is currently in the 3-day recovery period. Please log in to restore your account.');
          err.statusCode = 409;
          err.code = 'EMAIL_IN_RECOVERY';
          throw err;
        }
        const err = new Error('This email is already registered. Please log in or use a different email.');
        err.statusCode = 409;
        err.code = 'EMAIL_ALREADY_EXISTS';
        throw err;
      }
    }

    if (cleanPhone) {
      const existing = await userRepository.findByPhone(cleanPhone);
      if (existing) {
        const err = new Error('This phone number is already registered. Please log in or use a different phone number.');
        err.statusCode = 409;
        err.code = 'PHONE_ALREADY_EXISTS';
        throw err;
      }
    }

    if (firebaseUid) {
      const existing = await userRepository.findByFirebaseUid(firebaseUid);
      if (existing) {
        const err = new Error('An account associated with this login already exists. Please log in.');
        err.statusCode = 409;
        err.code = 'ACCOUNT_ALREADY_EXISTS';
        throw err;
      }
    }

    // Generate guaranteed unique username without colliding with existing users
    let finalUsername = username ? username.trim().toLowerCase().replaceAll(/[^a-z0-9_]/g, '') : null;
    if (!finalUsername || finalUsername.length < 3 || isTechIdStr(finalUsername)) {
      if (cleanEmail) {
        finalUsername = cleanEmail.split('@')[0].toLowerCase().replaceAll(/[^a-z0-9_]/g, '');
      }
      if (!finalUsername || finalUsername.length < 3) {
        finalUsername = `user_${crypto.randomBytes(3).toString('hex')}`;
      }
    }
    
    // Check collision and guarantee uniqueness
    let collision = await userRepository.findByUsername(finalUsername);
    while (collision) {
      finalUsername = `${finalUsername.slice(0, 15)}_${Math.floor(100 + Math.random() * 900)}`;
      collision = await userRepository.findByUsername(finalUsername);
    }

    user = await userRepository.createUserWithProfile({
      firebaseUid,
      email: cleanEmail,
      phone: cleanPhone,
      username: finalUsername,
      displayName: cleanName,
      avatarUrl: avatarUrl || null,
      coverUrl: null,
      status: 'ACTIVE',
      userType: 'USER',
      countryCode: countryCode || 'US',
      coinBalance: coins || 1000,
      diamondBalance: diamonds || 100,
    });
    isNewUser = true;
  } else {
    // ----------------------------------------------------
    // LOGIN / SYNC FLOW
    // ----------------------------------------------------
    let existingUser = null;
    if (cleanEmail) {
      existingUser = await userRepository.findByEmail(cleanEmail);
    }
    if (!existingUser && cleanPhone) {
      existingUser = await userRepository.findByPhone(cleanPhone);
    }
    if (!existingUser && firebaseUid) {
      existingUser = await userRepository.findByFirebaseUid(firebaseUid);
    }
    if (!existingUser && targetId && /^[1-9]\d{6}$/.test(String(targetId))) {
      existingUser = await userRepository.findById(String(targetId));
    }

    if (existingUser) {
      user = existingUser;

      // Check account status
      if (user.status === 'BANNED') {
        const err = new Error('Your account has been banned by the platform administrator.');
        err.statusCode = 403;
        err.code = 'ACCOUNT_BANNED';
        throw err;
      }
      if (user.status === 'SUSPENDED') {
        const err = new Error('Your account is temporarily suspended.');
        err.statusCode = 403;
        err.code = 'ACCOUNT_SUSPENDED';
        throw err;
      }
      if (user.status === 'DELETED') {
        const now = new Date();
        if (user.scheduledPermanentDeletionAt && new Date(user.scheduledPermanentDeletionAt) > now) {
          // Account is within 3-day recovery window -> automatically restore it!
          await userRepository.restoreDeletedUser(user.id);
          user = await userRepository.findById(user.id);
        } else {
          // Account expired past 3 days -> purge permanently
          await userRepository.purgeExpiredDeletedUsers().catch(() => {});
          const err = new Error('This account has been permanently deleted.');
          err.statusCode = 404;
          err.code = 'ACCOUNT_PERMANENTLY_DELETED';
          throw err;
        }
      }

      // Link firebaseUid if missing
      if (firebaseUid && !user.firebaseUid) {
        await prisma.user.update({
          where: { id: user.id },
          data: { firebaseUid },
        }).catch(() => {});
      }
    } else {
      // First-time login / sync (e.g. Google Sign-in on fresh account)
      let finalUsername = username ? username.trim().toLowerCase().replaceAll(/[^a-z0-9_]/g, '') : null;
      if (!finalUsername || finalUsername.length < 3 || isTechIdStr(finalUsername)) {
        if (cleanEmail) {
          finalUsername = cleanEmail.split('@')[0].toLowerCase().replaceAll(/[^a-z0-9_]/g, '');
        }
        if (!finalUsername || finalUsername.length < 3) {
          finalUsername = `user_${crypto.randomBytes(3).toString('hex')}`;
        }
      }
      
      let collision = await userRepository.findByUsername(finalUsername);
      while (collision) {
        finalUsername = `${finalUsername.slice(0, 15)}_${Math.floor(100 + Math.random() * 900)}`;
        collision = await userRepository.findByUsername(finalUsername);
      }

      user = await userRepository.createUserWithProfile({
        firebaseUid,
        email: cleanEmail,
        phone: cleanPhone,
        username: finalUsername,
        displayName: cleanName,
        avatarUrl: avatarUrl || null,
        coverUrl: null,
        status: 'ACTIVE',
        userType: 'USER',
        countryCode: countryCode || 'US',
        coinBalance: coins || 1000,
        diamondBalance: diamonds || 100,
      });
      isNewUser = true;
    }
  }

  if (device && (device.deviceToken || device.macAddress || device.platform)) {
    await deviceRepository.upsertDevice({
      userId: user.id,
      deviceToken: device.deviceToken,
      platform: device.platform || 'ANDROID',
      macAddress: device.macAddress,
      deviceModel: device.deviceModel,
      appVersion: device.appVersion,
    }).catch(() => {});
  }

  const sessionResult = await sessionService.createSession({
    userId: user.id,
    userType: user.userType || 'USER',
    ipAddress,
    userAgent,
  });

  await userRepository.updateLastLogin(user.id).catch(() => {});

  return {
    isNewUser,
    user: sanitizeUser(user),
    accessToken: sessionResult.accessToken,
    refreshToken: sessionResult.refreshToken,
    expiresAt: sessionResult.expiresAt,
  };
}

export async function recoverAccount({ email, phone, ipAddress, userAgent }) {
  const cleanEmail = email ? email.trim().toLowerCase() : null;
  const cleanPhone = phone ? phone.trim() : null;

  let user = null;
  if (cleanEmail) {
    user = await userRepository.findByEmail(cleanEmail);
  } else if (cleanPhone) {
    user = await userRepository.findByPhone(cleanPhone);
  }

  if (!user) {
    const err = new Error('No account found with the provided details.');
    err.statusCode = 404;
    err.code = 'USER_NOT_FOUND';
    throw err;
  }

  if (user.status !== 'DELETED') {
    const err = new Error('This account is already active.');
    err.statusCode = 400;
    err.code = 'ACCOUNT_ALREADY_ACTIVE';
    throw err;
  }

  const now = new Date();
  if (user.scheduledPermanentDeletionAt && new Date(user.scheduledPermanentDeletionAt) <= now) {
    await userRepository.purgeExpiredDeletedUsers().catch(() => {});
    const err = new Error('The 3-day recovery window has expired. This account has been permanently deleted.');
    err.statusCode = 410;
    err.code = 'ACCOUNT_PERMANENTLY_DELETED';
    throw err;
  }

  await userRepository.restoreDeletedUser(user.id);
  const restoredUser = await userRepository.findById(user.id);

  const sessionResult = await sessionService.createSession({
    userId: restoredUser.id,
    userType: restoredUser.userType || 'USER',
    ipAddress,
    userAgent,
  });

  await userRepository.updateLastLogin(restoredUser.id).catch(() => {});

  return {
    user: sanitizeUser(restoredUser),
    accessToken: sessionResult.accessToken,
    refreshToken: sessionResult.refreshToken,
    expiresAt: sessionResult.expiresAt,
  };
}

export default {
  requestOtp,
  verifyOtpAndAuthenticate,
  refreshToken,
  logout,
  getCurrentUser,
  adminLogin,
  syncUserFromApp,
  recoverAccount,
};

