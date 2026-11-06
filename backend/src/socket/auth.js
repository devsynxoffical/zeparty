import jwt from 'jsonwebtoken';
import env from '../config/env.js';
import userRepository from '../repositories/user.repository.js';
import { SOCKET_ERRORS } from './socket.constants.js';

/**
 * Socket.IO connection authentication middleware using authoritative JWT & database verification.
 * 
 * Extracts JWT from handshake auth token or authorization header.
 * Verifies token signature, expiration, and user account status against the database.
 * Rejects banned, suspended, inactive users, or spoofed unverified identities.
 * Keeps genuinely anonymous guest connections working safely under guest_ prefix.
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

    const clientClaimedUserId = socket.handshake.auth?.userId ||
      socket.handshake.auth?.id ||
      socket.handshake.query?.userId ||
      socket.handshake.auth?.user?.id ||
      socket.handshake.auth?.user?.userId;

    const isAnonymousGuestRequested = Boolean(
      token === 'guest_anonymous' ||
      (!token && (!clientClaimedUserId || String(clientClaimedUserId).startsWith('guest_')))
    );

    // -------------------------------------------------------------
    // PATH 1: Genuinely Anonymous Guest Connection
    // -------------------------------------------------------------
    if (isAnonymousGuestRequested) {
      // Security: Guest IDs MUST be strictly server-generated.
      // Never adopt client-supplied guestId or clientClaimedUserId to prevent guest session hijacking.
      const guestSocketId = socket.id || socket.handshake?.id || socket.client?.id;
      const guestId = 'guest_' + (guestSocketId || Math.random().toString(36).substring(2, 10));

      const clientUser = socket.handshake.auth?.user || socket.handshake.auth?.userData;
      const fallbackName = clientUser?.displayName || clientUser?.name || clientUser?.username ||
        `User_${String(guestId).replace('guest_', '').substring(0, 5)}`;

      socket.isGuest = true;
      socket.userId = guestId;
      console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [AUTH] socket=${socket.id} mode=GUEST userId=${guestId} name=${fallbackName}`);
      socket.user = {
        id: guestId,
        userId: guestId,
        username: fallbackName,
        displayName: fallbackName,
        name: fallbackName,
        avatarUrl: clientUser?.avatarUrl || null,
        status: 'ACTIVE',
        userType: 'USER',
        isVip: false,
        isHost: false,
        nobleTitle: null,
        nobleLevel: null,
        isAdmin: false,
        isOwner: false,
        role: 'USER',
        isGuest: true,
        profile: {
          displayName: fallbackName,
          avatarUrl: clientUser?.avatarUrl || null,
          vipLevel: 0,
          svipLevel: 0,
          nobleRank: null,
        },
      };

      return next();
    }

    // -------------------------------------------------------------
    // PATH 2: Authenticated User (Host / Member)
    // -------------------------------------------------------------
    if (!token) {
      const err = new Error('Authentication token is required for authenticated sessions');
      err.data = { code: SOCKET_ERRORS.UNAUTHORIZED };
      return next(err);
    }

    let decoded = null;
    let verifiedUserId = null;

    // Cryptographic verification of access token
    // Security: NEVER trust unverified tokens or unverified session_token_ strings
    try {
      decoded = jwt.verify(token, env.JWT_SECRET);
      verifiedUserId = decoded.sub || decoded.userId || decoded.id || decoded.uid;
    } catch (jwtErr) {
      console.warn(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [AUTH_ERROR] socket=${socket.id} reason=${jwtErr.message}`);
      const err = new Error(jwtErr.name === 'TokenExpiredError' ? 'Access token has expired' : 'Invalid or expired authentication token');
      err.data = { code: SOCKET_ERRORS.UNAUTHORIZED, reason: jwtErr.message };
      return next(err);
    }

    if (!verifiedUserId) {
      const err = new Error('Token subject identifier missing');
      err.data = { code: SOCKET_ERRORS.UNAUTHORIZED };
      return next(err);
    }

    // Authoritative Database User Verification
    let user = null;
    const lookupId = String(verifiedUserId);
    const lookupUid = decoded.firebaseUid || decoded.uid || null;
    const lookupEmail = decoded.email || (lookupId.includes('@') ? lookupId : null);

    if (customUserLookup) {
      if (typeof customUserLookup.findById === 'function') {
        user = await customUserLookup.findById(lookupId).catch(() => null);
      } else if (typeof customUserLookup.findUserById === 'function') {
        user = await customUserLookup.findUserById(lookupId).catch(() => null);
      } else if (customUserLookup.user && typeof customUserLookup.user.findUnique === 'function') {
        user = await customUserLookup.user.findUnique({ where: { id: lookupId }, include: { profile: true, hostProfile: true } }).catch(() => null);
      } else if (typeof customUserLookup === 'function') {
        user = await customUserLookup(lookupId).catch(() => null);
      }

      if (!user && (lookupUid || typeof customUserLookup.findByFirebaseUid === 'function')) {
        const uidToTry = lookupUid || lookupId;
        if (typeof customUserLookup.findByFirebaseUid === 'function') {
          user = await customUserLookup.findByFirebaseUid(uidToTry).catch(() => null);
        }
      }

      if (!user && lookupEmail && typeof customUserLookup.findByEmail === 'function') {
        user = await customUserLookup.findByEmail(lookupEmail).catch(() => null);
      }
    } else {
      user = await (userRepository.findById ? userRepository.findById(lookupId) : userRepository.findUserById(lookupId)).catch(() => null);

      if (!user && userRepository.findByFirebaseUid) {
        user = await userRepository.findByFirebaseUid(lookupUid || lookupId).catch(() => null);
      }

      if (!user && lookupEmail && userRepository.findByEmail) {
        user = await userRepository.findByEmail(lookupEmail).catch(() => null);
      }
    }

    if (!user) {
      const err = new Error('Authenticated user account not found');
      err.data = { code: SOCKET_ERRORS.UNAUTHORIZED };
      return next(err);
    }

    if (user.status && user.status !== 'ACTIVE') {
      const err = new Error(`Account is ${user.status.toLowerCase()}. Access denied.`);
      err.data = { code: SOCKET_ERRORS.USER_NOT_ACTIVE, status: user.status };
      return next(err);
    }

    const effectiveName = user.profile?.displayName || user.name || user.username || 'User';

    // Requirement 2 & 4: Preserve valid authenticated Host identity without converting to guest
    socket.isGuest = false;
    socket.userId = user.id;
    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [AUTH] socket=${socket.id} mode=AUTHENTICATED userId=${user.id} username=${user.username} role=${user.userType || 'USER'}`);
    socket.user = {
      id: user.id,
      userId: user.id,
      username: user.username,
      name: effectiveName,
      displayName: effectiveName,
      avatarUrl: user.profile?.avatarUrl || user.avatarUrl || null,
      status: user.status || 'ACTIVE',
      isVip: Boolean(user.profile?.vipLevel > 0 || user.profile?.svipLevel > 0),
      isHost: user.userType === 'HOST' || Boolean(user.hostProfile),
      nobleTitle: user.profile?.nobleRank || null,
      nobleLevel: user.profile?.nobleRank || null,
      isAdmin: Boolean(decoded?.isAdmin || user.userType === 'ADMIN'),
      isOwner: Boolean(decoded?.isOwner),
      role: user.userType || decoded?.role || 'USER',
      isGuest: false,
      profile: user.profile || { displayName: effectiveName },
    };

    return next();
  } catch (err) {
    const error = new Error('Internal authentication error during socket handshake');
    error.data = { code: SOCKET_ERRORS.INTERNAL_ERROR };
    return next(error);
  }
}

export default socketAuthMiddleware;
