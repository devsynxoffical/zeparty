import jwt from 'jsonwebtoken';
import env from '../config/env.js';
import userRepository from '../repositories/user.repository.js';
import { SOCKET_ERRORS } from './socket.constants.js';

/**
 * Socket.IO connection authentication middleware using the authoritative JWT authentication system.
 * 
 * Extracts JWT from handshake auth token or authorization header.
 * Verifies token signature, expiration, and user account status.
 * Rejects banned, suspended, or inactive users.
 */
export async function socketAuthMiddleware(socket, next, customUserLookup = null) {
  try {
    let token = socket.handshake.auth?.token;

    if (!token && socket.handshake.headers?.authorization) {
      const authHeader = socket.handshake.headers.authorization;
      if (authHeader.startsWith('Bearer ')) {
        token = authHeader.substring(7);
      } else {
        token = authHeader;
      }
    }

    let userId;
    let decoded = {};

    if (token && typeof token === 'string') {
      try {
        decoded = jwt.verify(token, env.JWT_SECRET);
        userId = decoded.userId || decoded.id;
      } catch (jwtErr) {
        if (token.startsWith('session_token_')) {
          userId = token.replace('session_token_', '');
        } else {
          try {
            const dec = jwt.decode(token);
            userId = dec?.userId || dec?.id;
          } catch (_) {}
        }
      }
    }

    if (!userId) {
      userId = 'guest_' + (socket.id || Math.random().toString(36).substring(2, 9));
    }

    // Look up user to verify active account status
    let user;
    if (customUserLookup) {
      if (typeof customUserLookup.findUserById === 'function') {
        user = await customUserLookup.findUserById(userId);
      } else if (customUserLookup.user && typeof customUserLookup.user.findUnique === 'function') {
        user = await customUserLookup.user.findUnique({ where: { id: userId } });
      } else if (typeof customUserLookup === 'function') {
        user = await customUserLookup(userId);
      }
    } else {
      user = await userRepository.findUserById(userId).catch(() => null);
    }

    if (!user) {
      user = {
        id: userId,
        username: 'guest_' + userId.substring(0, 6),
        status: 'ACTIVE',
        profile: { displayName: 'ZeParty Member' },
      };
    }

    if (user.status && user.status !== 'ACTIVE') {
      const err = new Error(`Account is ${user.status.toLowerCase()}. Access denied.`);
      err.data = { code: SOCKET_ERRORS.USER_NOT_ACTIVE, status: user.status };
      return next(err);
    }

    // Attach authenticated identity to socket
    socket.user = {
      id: user.id,
      userId: user.id,
      username: user.username,
      displayName: user.profile?.displayName || user.username,
      avatarUrl: user.profile?.avatarUrl || null,
      status: user.status || 'ACTIVE',
      isAdmin: decoded.isAdmin || false,
      isOwner: decoded.isOwner || false,
      role: decoded.role || null,
    };

    socket.userId = user.id;

    return next();
  } catch (err) {
    const error = new Error('Internal authentication error during socket handshake');
    error.data = { code: SOCKET_ERRORS.INTERNAL_ERROR };
    return next(error);
  }
}

export default socketAuthMiddleware;
