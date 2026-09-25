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
  device = {},
  ipAddress,
  userAgent,
}) {
  const targetId = uid || id;
  const cleanEmail = email ? email.trim().toLowerCase() : null;
  const cleanPhone = phone ? phone.trim() : null;
  const cleanName = displayName || name || 'ZeParty Member';

  let existingUser = null;
  // 1. Look up strictly by verified unique email
  if (cleanEmail) {
    existingUser = await userRepository.findByEmail(cleanEmail);
  }
  // 2. Look up strictly by verified phone
  if (!existingUser && cleanPhone) {
    existingUser = await userRepository.findByPhone(cleanPhone);
  }
  // 3. Look up by 7-digit PostgreSQL user ID if valid
  if (!existingUser && targetId && /^[1-9]\d{6}$/.test(String(targetId))) {
    existingUser = await userRepository.findById(String(targetId));
  }

  let user = existingUser;
  let isNewUser = false;

  if (!user) {
    // Generate guaranteed unique username without colliding with existing users
    let finalUsername = username ? username.trim().toLowerCase().replaceAll(/[^a-z0-9_]/g, '') : null;
    if (!finalUsername || finalUsername.length < 3) {
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
    // Existing user: ensure email/phone are recorded if empty, but NEVER overwrite existing profile data
    try {
      if (cleanEmail && !user.email) {
        await prisma.user.update({
          where: { id: user.id },
          data: { email: cleanEmail },
        });
      }
      if (cleanPhone && !user.phone) {
        await prisma.user.update({
          where: { id: user.id },
          data: { phone: cleanPhone },
        });
      }
    } catch (_) {}
    user = await userRepository.findById(user.id);
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

export default {
  requestOtp,
  verifyOtpAndAuthenticate,
  refreshToken,
  logout,
  getCurrentUser,
  adminLogin,
  syncUserFromApp,
};

