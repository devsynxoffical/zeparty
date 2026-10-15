import jwt from 'jsonwebtoken';
import env from '../config/env.js';
import { generateRandomToken, hashToken } from '../utils/crypto.util.js';

/**
 * Generate short-lived JWT access token carrying essential claims.
 */
export function generateAccessToken(payload) {
  const isAdmin = Boolean(payload.isAdmin || payload.userType === 'ADMIN');
  const audience = payload.audience || (isAdmin ? 'zeparty-admin' : 'zeparty-mobile');
  const claims = {
    sub: String(payload.userId || payload.adminId),
    sessionId: payload.sessionId,
    userType: payload.userType || (isAdmin ? 'ADMIN' : 'USER'),
    roleId: payload.roleId || null,
    isAdmin,
  };

  return jwt.sign(claims, env.JWT_SECRET, {
    expiresIn: env.JWT_EXPIRES_IN,
    audience,
    issuer: 'zeparty-api',
  });
}

/**
 * Decode JWT token without verifying expiration.
 */
export function decodeToken(token) {
  try {
    return jwt.decode(token);
  } catch {
    return null;
  }
}

/**
 * Verify access token claims against env JWT_SECRET.
 */
export function verifyAccessToken(token, options = {}) {
  try {
    const decoded = jwt.verify(token, env.JWT_SECRET, options);
    // If audience claim exists, validate that it belongs to an expected domain
    if (decoded && decoded.aud) {
      if (decoded.aud !== 'zeparty-admin' && decoded.aud !== 'zeparty-mobile') {
        const error = new Error('Invalid token audience');
        error.status = 401;
        error.code = 'TOKEN_INVALID';
        throw error;
      }
    }
    return decoded;
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      const error = new Error('Access token has expired');
      error.status = 401;
      error.code = 'TOKEN_EXPIRED';
      throw error;
    }
    const error = new Error(err.message || 'Invalid authentication token');
    error.status = 401;
    error.code = err.code || 'TOKEN_INVALID';
    throw error;
  }
}

/**
 * Generate long-lived opaque refresh token and its server-side SHA256 hash.
 */
export function generateRefreshToken() {
  const rawToken = generateRandomToken(40);
  const tokenHash = hashToken(rawToken);
  
  // Calculate expiration date (7 days default)
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  return {
    rawToken,
    tokenHash,
    expiresAt,
  };
}

export default {
  generateAccessToken,
  decodeToken,
  verifyAccessToken,
  generateRefreshToken,
};
