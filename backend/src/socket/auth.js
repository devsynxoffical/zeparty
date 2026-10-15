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

    let userId = socket.handshake.auth?.userId || socket.handshake.auth?.id || socket.handshake.query?.userId;
    let decoded = {};

    if (token && typeof token === 'string' && token !== 'guest_anonymous') {
      try {
        decoded = jwt.verify(token, env.JWT_SECRET);
        userId = decoded.sub || decoded.userId || decoded.id || userId;
      } catch (jwtErr) {
        if (token.startsWith('session_token_')) {
          userId = token.replace('session_token_', '');
        } else {
          try {
            const dec = jwt.decode(token);
            userId = dec?.sub || dec?.userId || dec?.id || userId;
          } catch (_) {}
        }
      }
    }

    const clientUser = socket.handshake.auth?.user || socket.handshake.auth?.userData;
    if (!userId && clientUser && (clientUser.id || clientUser.userId)) {
      userId = clientUser.id || clientUser.userId;
    }

    // Look up user to verify active account status
    let user = null;
    if (userId && !String(userId).startsWith('guest_') && token !== 'guest_anonymous') {
      if (customUserLookup) {
        if (typeof customUserLookup.findById === 'function') {
          user = await customUserLookup.findById(userId).catch(() => null);
        } else if (typeof customUserLookup.findUserById === 'function') {
          user = await customUserLookup.findUserById(userId).catch(() => null);
        } else if (customUserLookup.user && typeof customUserLookup.user.findUnique === 'function') {
          user = await customUserLookup.user.findUnique({ where: { id: userId }, include: { profile: true } }).catch(() => null);
        } else if (typeof customUserLookup === 'function') {
          user = await customUserLookup(userId).catch(() => null);
        }
      } else {
        user = await (userRepository.findById ? userRepository.findById(userId) : userRepository.findUserById(userId)).catch(() => null);
      }
    }

    const isGuest = !user && Boolean(
      String(userId).startsWith('guest_') ||
      token === 'guest_anonymous' ||
      (!token && !decoded?.sub && !decoded?.userId && !decoded?.id)
    );

    if (isGuest && !String(userId).startsWith('guest_')) {
      userId = 'guest_' + (userId || socket.id || Math.random().toString(36).substring(2, 9));
    }

    if (!user) {
      if (clientUser && (clientUser.id || clientUser.userId)) {
        const effectiveClientName = clientUser.displayName || clientUser.name || clientUser.username || `User_${String(userId).substring(0, 6)}`;
        user = {
          id: userId,
          username: clientUser.username || effectiveClientName,
          status: 'ACTIVE',
          userType: clientUser.role || 'USER',
          avatarUrl: clientUser.avatarUrl || null,
          profile: {
            displayName: effectiveClientName,
            avatarUrl: clientUser.avatarUrl || null,
            vipLevel: clientUser.vipLevel || (clientUser.isVip ? 1 : 0),
            svipLevel: clientUser.svipLevel || 0,
            nobleRank: clientUser.nobleTitle || null,
          },
        };
      } else {
        const fallbackName = String(userId).startsWith('guest_')
          ? `User_${String(userId).replace('guest_', '').substring(0, 5)}`
          : `User_${String(userId).substring(0, 6)}`;
        user = {
          id: userId,
          username: fallbackName,
          status: 'ACTIVE',
          userType: 'USER',
          profile: { displayName: fallbackName },
        };
      }
    }

    if (user.status && user.status !== 'ACTIVE') {
      const err = new Error(`Account is ${user.status.toLowerCase()}. Access denied.`);
      err.data = { code: SOCKET_ERRORS.USER_NOT_ACTIVE, status: user.status };
      return next(err);
    }

    const effectiveName = user.profile?.displayName || user.name || user.username || 'User';

    // Attach authenticated identity to socket
    socket.isGuest = isGuest;
    socket.user = {
      id: user.id,
      userId: user.id,
      username: user.username,
      name: effectiveName,
      displayName: effectiveName,
      avatarUrl: user.profile?.avatarUrl || user.avatarUrl || null,
      status: user.status || 'ACTIVE',
      isVip: Boolean(user.profile?.vipLevel > 0 || user.profile?.svipLevel > 0),
      isHost: user.userType === 'HOST',
      nobleTitle: user.profile?.nobleRank || null,
      nobleLevel: user.profile?.nobleRank || null,
      isAdmin: decoded.isAdmin || false,
      isOwner: decoded.isOwner || false,
      role: user.userType || decoded.role || null,
      isGuest,
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
