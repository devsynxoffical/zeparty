import roomRepository from '../repositories/room.repository.js';
import userRepository from '../repositories/user.repository.js';
import roomService from '../services/room.service.js';
import micInviteService from '../services/micInvite.service.js';
import presenceService from './presence.service.js';
import prisma from '../config/database.js';
import { startHostAbsentTimer, clearHostAbsentTimer } from './roomTimer.manager.js';
import { deriveAgoraUid } from '../utils/agoraToken.util.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';
import * as attendanceService from '../services/attendance.service.js';

/**
 * Builds a safe, public room snapshot containing no sensitive admin or private fields.
 */
export function buildRoomSnapshot(room, viewerCount, activePresenceUsers = []) {
  if (!room) return null;

  const hostUserId = room.creatorUserId || room.creator?.id;

  // Determine if host is currently occupying a seat on stage
  const hostIsOccupyingSeat = (room.seats || []).some(
    (s) => (s.occupiedUserId === hostUserId || s.user?.id === hostUserId)
  );

  const membersList = (room.members || [])
    .filter((m) => {
      const mid = m.userId || m.user?.id;
      // If host is occupying a seat, do not duplicate in audience list
      if (mid === hostUserId && hostIsOccupyingSeat) {
        return false;
      }
      return true;
    })
    .map((m) => {
      const u = m.user || {};
      const mid = m.userId || u.id;
      const isHost = mid === hostUserId;
      const displayName = u.profile?.displayName || u.displayName || u.username || (isHost ? 'Host' : 'User');
      return {
        userId: mid,
        role: isHost ? 'HOST' : (m.role || 'LISTENER'),
        isHost,
        isOwner: isHost,
        user: {
          id: mid,
          username: u.username || displayName,
          displayName,
          name: displayName,
          avatarUrl: u.avatarUrl || u.profile?.avatarUrl || null,
        },
      };
    });

  const existingMemberIds = new Set(membersList.map((m) => m.userId));

  // If host is NOT occupying a seat, ensure host is included in audience exactly once
  if (!hostIsOccupyingSeat && hostUserId && !existingMemberIds.has(hostUserId)) {
    const hostUser = room.creator || {};
    const hostDisplayName = hostUser.profile?.displayName || hostUser.displayName || hostUser.username || 'Host';
    membersList.unshift({
      userId: hostUserId,
      role: 'HOST',
      isHost: true,
      isOwner: true,
      user: {
        id: hostUserId,
        username: hostUser.username || hostDisplayName,
        displayName: hostDisplayName,
        name: hostDisplayName,
        avatarUrl: hostUser.avatarUrl || hostUser.profile?.avatarUrl || null,
      },
    });
    existingMemberIds.add(hostUserId);
  }

  // Merge active guest participants
  for (const pres of (activePresenceUsers || [])) {
    const pid = pres.userId || pres.id;
    if (pid && !existingMemberIds.has(pid)) {
      if (pid === hostUserId && hostIsOccupyingSeat) {
        continue;
      }
      const isHost = pid === hostUserId;
      const guestDisplayName = pres.displayName || pres.name || pres.username || (isHost ? 'Host' : `User_${String(pid).replace('guest_', '').substring(0, 5)}`);
      membersList.push({
        userId: pid,
        role: isHost ? 'HOST' : 'LISTENER',
        isHost,
        isOwner: isHost,
        user: {
          id: pid,
          username: guestDisplayName,
          displayName: guestDisplayName,
          name: guestDisplayName,
          avatarUrl: pres.avatarUrl || null,
        },
      });
      existingMemberIds.add(pid);
    }
  }

  const hasPin = Boolean(room.roomPin);
  const lockMode = hasPin ? 'PIN' : (room.isPrivate ? 'Approval' : 'NONE');

  return {
    id: room.id,
    roomId: room.id,
    creatorUserId: hostUserId,
    title: room.title,
    roomType: room.roomType || 'VIDEO_PARTY',
    category: room.category || 'CHATTING',
    status: room.status,
    backgroundImageUrl: room.backgroundImageUrl || null,
    background: room.backgroundImageUrl || null,
    coverImageUrl: room.coverImageUrl || null,
    coverUrl: room.coverImageUrl || null,
    isPinned: Boolean(room.isPinned),
    pinPosition: room.pinPosition || null,
    currentViewersCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    viewerCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    feedClearedAt: room.feedClearedAt || null,
    agoraChannelName: room.agoraChannelName || null,
    agoraHostUid: hostUserId ? deriveAgoraUid(hostUserId) : null,
    isLocked: Boolean(room.isPrivate),
    lockMode,
    seatCapacity: (room.seats || []).length || 10,
    capacity: (room.seats || []).length || 10,
    roomSendingTotal: room.roomSendingTotal || room.dailySendingTotal || 0,
    dailySendingTotal: room.dailySendingTotal || room.roomSendingTotal || 0,
    periodTotalCoins: room.periodTotalCoins || room.dailySendingTotal || 0,
    trophyCoins: room.trophyCoins || room.dailySendingTotal || 0,
    host: room.creator ? {
      id: room.creator.id,
      username: room.creator.username,
      displayName: room.creator.profile?.displayName || room.creator.username,
      avatarUrl: room.creator.profile?.avatarUrl || null,
    } : null,
    seats: (room.seats || []).map((s) => {
      const u = s.occupiedUser || s.user;
      return {
        seatIndex: s.seatIndex,
        isLocked: s.isLocked,
        isMuted: s.isMuted,
        user: u ? {
          id: u.id,
          username: u.username,
          displayName: u.profile?.displayName || u.displayName || u.username,
          avatarUrl: u.profile?.avatarUrl || u.avatarUrl || null,
        } : null,
      };
    }),
    members: membersList,
    createdAt: room.createdAt,
  };
}

function resolveArgs(arg1, arg2, arg3, arg4, arg5) {
  // Case A: (io, socket, data, callback, db)
  if (arg2 && (arg2.handshake || arg2.conn || arg2.client || typeof arg2.join === 'function' || arg2.userId || arg2.id)) {
    const io = arg1;
    const socket = arg2;
    const data = arg3;
    const callback = typeof arg4 === 'function' ? arg4 : (typeof arg5 === 'function' ? arg5 : null);
    const dbCandidate = (arg4 && typeof arg4 === 'object' && typeof arg4 !== 'function') ? arg4 : arg5;
    const db = (dbCandidate && typeof dbCandidate === 'object') ? dbCandidate : prisma;
    return { io, socket, data, callback, db };
  }

  // Case B: (socket, data, callback, db)
  const socket = arg1;
  const data = arg2;
  const callback = typeof arg3 === 'function' ? arg3 : (typeof arg4 === 'function' ? arg4 : null);
  const dbCandidate = (arg3 && typeof arg3 === 'object' && typeof arg3 !== 'function') ? arg3 : ((arg4 && typeof arg4 === 'object' && typeof arg4 !== 'function') ? arg4 : arg5);
  const db = (dbCandidate && typeof dbCandidate === 'object') ? dbCandidate : prisma;
  return { io: null, socket, data, callback, db };
}

export async function onJoinRoom(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);

  try {
    const roomId = data?.roomId;
    if (!roomId || typeof roomId !== 'string') {
      const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const userId = socket.userId;

    // 1. Authoritative Room Existence and Lifecycle Check
    let room = await roomRepository.findRoomById(roomId, db || prisma);
    if (!room) {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_FOUND, message: 'Room not found' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(room.status.toUpperCase())) {
      // Auto-resolve to creator's active live room session if available
      const creatorId = room.creatorUserId || room.creator?.id;
      if (creatorId) {
        const activeRoom = await (db || prisma).room.findFirst({
          where: {
            creatorUserId: creatorId,
            status: 'LIVE',
          },
          select: { id: true },
        });
        if (activeRoom) {
          const resolvedRoom = await roomRepository.findRoomById(activeRoom.id, db || prisma);
          if (resolvedRoom && resolvedRoom.status && ['LIVE', 'ACTIVE', 'OPEN'].includes(resolvedRoom.status.toUpperCase())) {
            room = resolvedRoom;
          }
        }
      }

      if (room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(room.status.toUpperCase())) {
        const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_LIVE, message: 'Room is not available or has ended' } };
        if (typeof callback === 'function') return callback(err);
        return socket.emit(SOCKET_EVENTS.ERROR, err);
      }
    }

    // 2. Immediately subscribe socket to room channel so broadcasts & chat are reliably delivered
    if (typeof socket.join === 'function') {
      await socket.join(`room:${room.id}`);
      if (room.id !== roomId) {
        await socket.join(`room:${roomId}`);
      }
    }
    socket.joinedRooms = socket.joinedRooms || new Set();
    socket.joinedRooms.add(roomId);
    socket.joinedRooms.add(room.id);

    // 3. Persistent RoomMember registration via authoritative Room Service
    let joinResult = null;
    try {
      const pin = data?.pin || data?.password || data?.roomPin;
      const isApproved = Boolean(data?.isApproved);
      joinResult = await roomService.joinRoom(room.id, userId, { pin, isApproved }, db || prisma);
    } catch (joinErr) {
      if (['ROOM_LOCKED_PIN_REQUIRED', 'INVALID_ROOM_PIN', 'ROOM_APPROVAL_REQUIRED'].includes(joinErr.code)) {
        const errPayload = {
          success: false,
          error: {
            code: joinErr.code,
            message: joinErr.message,
          },
        };
        if (typeof callback === 'function') return callback(errPayload);
        return socket.emit(SOCKET_EVENTS.ERROR, errPayload);
      }
      console.warn(`[RoomSocket] Warning joining room ${roomId} for user ${userId}:`, joinErr.message);
    }

    // Cancel any active host absence timer if host returned
    const isHostUser = room.creatorUserId === userId || room.creator?.id === userId;
    if (isHostUser) {
      clearHostAbsentTimer(room.id, io);
    }

    const clientUser = data?.user || {};
    const effectiveJoinedId = clientUser.id || clientUser.userId || socket.user?.id || userId;
    const fallbackGuestName = String(effectiveJoinedId).startsWith('guest_')
      ? `User_${String(effectiveJoinedId).replace('guest_', '').substring(0, 5)}`
      : `User_${String(effectiveJoinedId).substring(0, 6)}`;
    const effectiveJoinedName = clientUser.displayName || clientUser.name || clientUser.username || socket.user?.displayName || socket.user?.name || socket.user?.username || fallbackGuestName;
    let effectiveJoinedAvatar = clientUser.avatarUrl || socket.user?.avatarUrl || null;
    const effectiveJoinedVip = Boolean(clientUser.isVip || socket.user?.isVip);
    const effectiveJoinedNoble = clientUser.nobleTitle || socket.user?.nobleTitle || null;
    const isGuestUser = Boolean(socket.isGuest || String(effectiveJoinedId).startsWith('guest_'));

    if (!effectiveJoinedAvatar && effectiveJoinedId && !isGuestUser) {
      try {
        const uRec = await (db || prisma).user.findUnique({
          where: { id: effectiveJoinedId },
          select: { avatarUrl: true },
        });
        effectiveJoinedAvatar = uRec?.avatarUrl || null;
      } catch (_) {}
    }

    // 4. Ephemeral Presence Tracking with rich user metadata
    let isFirstSocket = true;
    try {
      const pres = await presenceService.addSocketToRoom(room.id, effectiveJoinedId, socket.id, {
        displayName: effectiveJoinedName,
        avatarUrl: effectiveJoinedAvatar,
        isGuest: isGuestUser,
        joinedAt: new Date().toISOString(),
      });
      isFirstSocket = pres?.isFirstSocket ?? true;
    } catch (_) {}

    // 5. Generate and Send Authoritative Room Snapshot
    let currentCount = 0;
    try {
      currentCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    } catch (_) {
      currentCount = typeof joinResult?.currentViewersCount === 'number'
        ? joinResult.currentViewersCount
        : (typeof room.currentViewersCount === 'number' ? room.currentViewersCount : 1);
    }

    let activeUsers = [];
    try {
      activeUsers = await presenceService.getRoomActiveUsers(room.id);
    } catch (_) {}

    let feedClearedAt = null;
    try {
      feedClearedAt = await presenceService.getRoomFeedClearedAt(room.id);
    } catch (_) {}

    let recentGifts = [];
    try {
      const recentTxs = await (db || prisma).giftTransaction.findMany({
        where: { roomId: room.id },
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: {
          gift: { select: { id: true, name: true, iconUrl: true } },
          sender: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
          recipient: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
        },
      });
      recentGifts = recentTxs.reverse().map((tx) => ({
        id: tx.id,
        transactionId: tx.id,
        roomId: room.id,
        giftId: tx.giftId,
        giftName: tx.gift?.name || 'Gift',
        giftIcon: tx.gift?.iconUrl || '🎁',
        quantity: tx.giftCount,
        senderUserId: tx.senderUserId,
        senderName: tx.sender?.profile?.displayName || tx.sender?.username || 'User',
        senderAvatar: tx.sender?.avatarUrl || '',
        receiverUserId: tx.recipientUserId,
        receiverName: tx.recipient?.profile?.displayName || tx.recipient?.username || 'Host',
        receiverAvatar: tx.recipient?.avatarUrl || '',
        timestamp: tx.createdAt.toISOString(),
      }));
    } catch (_) {}

    // Issue 08: Calculate today's daily gift coin total for room header trophy counter
    let dailySendingTotal = 0;
    try {
      const todayUtc = new Date();
      todayUtc.setUTCHours(0, 0, 0, 0);
      const dailyAggr = await (db || prisma).giftTransaction.aggregate({
        where: { roomId: room.id, createdAt: { gte: todayUtc } },
        _sum: { totalCoins: true },
      });
      dailySendingTotal = Number(dailyAggr._sum.totalCoins || 0);
    } catch (_) {}
    room.dailySendingTotal = dailySendingTotal;
    room.roomSendingTotal = dailySendingTotal;
    room.periodTotalCoins = dailySendingTotal;
    room.trophyCoins = dailySendingTotal;

    const snapshot = buildRoomSnapshot(room, currentCount, activeUsers);
    snapshot.feedClearedAt = feedClearedAt;
    snapshot.recentGifts = recentGifts;
    snapshot.dailySendingTotal = dailySendingTotal;
    snapshot.roomSendingTotal = dailySendingTotal;
    snapshot.periodTotalCoins = dailySendingTotal;
    snapshot.trophyCoins = dailySendingTotal;
    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, {
      room: snapshot,
      ...snapshot,
      seats: snapshot.seats || [],
      members: snapshot.members || [],
      currentViewersCount: currentCount,
      viewerCount: currentCount,
      feedClearedAt,
      recentGifts,
    });

    // 6. Broadcast user joined event ONLY on genuine initial entry (not reconnects/pings)
    if (isFirstSocket) {
      const targetRoomIds = Array.from(new Set([String(roomId), String(room.id)]));
      const roomChannelNames = targetRoomIds.map((id) => `room:${id}`);
      const broadcastTarget = io
        ? io.to(roomChannelNames)
        : (socket.to ? socket.to(`room:${roomId}`) : socket);

      const entryTimestamp = new Date().toISOString();
      const entryEventId = `entry_${room.id}_${effectiveJoinedId}_${Date.now()}`;

      const userPayload = {
        id: entryEventId,
        eventId: entryEventId,
        entryId: entryEventId,
        entryEventId,
        roomId: room.id,
        clientRoomId: roomId,
        room: room.id,
        userId: effectiveJoinedId,
        user: {
          id: effectiveJoinedId,
          userId: effectiveJoinedId,
          username: clientUser.username || socket.user?.username || effectiveJoinedName,
          name: effectiveJoinedName,
          displayName: effectiveJoinedName,
          avatarUrl: effectiveJoinedAvatar,
          isVip: effectiveJoinedVip,
          nobleLevel: effectiveJoinedNoble,
          nobleTitle: effectiveJoinedNoble,
          isGuest: isGuestUser,
        },
        viewerCount: currentCount,
        count: currentCount,
        currentViewersCount: currentCount,
        timestamp: entryTimestamp,
      };

      broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
      broadcastTarget.emit('user_joined', userPayload);
      broadcastTarget.emit('user:joined', userPayload);
      broadcastTarget.emit('room_user_joined', userPayload);

      const viewerPayload = {
        roomId: room.id,
        clientRoomId: roomId,
        room: room.id,
        viewerCount: currentCount,
        count: currentCount,
        currentViewersCount: currentCount,
        timestamp: entryTimestamp,
      };

      broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
      broadcastTarget.emit('room:viewer_count', viewerPayload);
      broadcastTarget.emit('viewer_count_changed', viewerPayload);

      // 7. Broadcast system chat announcement so all room participants see "[User] has joined the party"
      const entryText = `${effectiveJoinedName} has joined the party 🎉`;
      const chatPayload = {
        id: entryEventId,
        eventId: entryEventId,
        entryId: entryEventId,
        entryEventId,
        roomId: room.id,
        clientRoomId: roomId,
        room: room.id,
        userId: effectiveJoinedId,
        senderId: effectiveJoinedId,
        sender: {
          id: effectiveJoinedId,
          userId: effectiveJoinedId,
          username: clientUser.username || socket.user?.username || effectiveJoinedName,
          name: effectiveJoinedName,
          displayName: effectiveJoinedName,
          avatarUrl: effectiveJoinedAvatar,
          isVip: effectiveJoinedVip,
          nobleLevel: effectiveJoinedNoble,
          nobleTitle: effectiveJoinedNoble,
          isGuest: isGuestUser,
        },
        user: {
          id: effectiveJoinedId,
          userId: effectiveJoinedId,
          username: clientUser.username || socket.user?.username || effectiveJoinedName,
          name: effectiveJoinedName,
          displayName: effectiveJoinedName,
          avatarUrl: effectiveJoinedAvatar,
          isVip: effectiveJoinedVip,
          nobleLevel: effectiveJoinedNoble,
          nobleTitle: effectiveJoinedNoble,
          isGuest: isGuestUser,
        },
        text: entryText,
        message: entryText,
        content: entryText,
        type: 'SYSTEM',
        isSystemMessage: true,
        timestamp: entryTimestamp,
      };

      broadcastTarget.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, chatPayload);
      broadcastTarget.emit('room:chat', chatPayload);
      broadcastTarget.emit('chat_message', chatPayload);
      broadcastTarget.emit('room_chat_message', chatPayload);

      // Ensure the entering user socket receives both events reliably if room broadcast didn't include socket
      if (socket && typeof socket.emit === 'function') {
        const socketInRoom = socket.rooms && typeof socket.rooms.has === 'function' &&
          (socket.rooms.has(`room:${room.id}`) || socket.rooms.has(`room:${roomId}`));
        if (!io || !socketInRoom) {
          socket.emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
          socket.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, chatPayload);
        }
      }
    }

    // 8. Update Authoritative User Room Presence
    if (userId && !socket.isGuest && !String(userId).startsWith('guest_')) {
      try {
        await presenceService.setUserActiveRoom(userId, room.id);
        const pres = await presenceService.getUserPresence(userId, db || prisma);
        if (io) {
          presenceService.broadcastPresenceChange(io, userId, pres);
        }
      } catch (_) {}
    }

    if (typeof callback === 'function') {
      return callback({
        success: true,
        data: snapshot,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to join room',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onLeaveRoom(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);

  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const userId = socket.userId;

    // 1. Remove socket from room
    if (typeof socket.leave === 'function') {
      socket.leave(`room:${roomId}`);
    }
    if (socket.joinedRooms) {
      socket.joinedRooms.delete(roomId);
    }

    // 2. Remove socket from presence tracker
    let isLastSocket = true;
    try {
      const pres = await presenceService.removeSocketFromRoom(roomId, userId, socket.id);
      isLastSocket = pres?.isLastSocket ?? true;
    } catch {}

    let updatedViewerCount = 0;

    // 3. If this was the user's last remaining connection, execute persistent leave
    if (isLastSocket) {
      const room = await roomRepository.findRoomById(roomId, db);
      const isHostUser = room && (room.creatorUserId === userId || room.creator?.id === userId);

      let leaveResult = null;
      try {
        leaveResult = await roomService.leaveRoom(roomId, userId, db);
      } catch (leaveErr) {
        // Safe fallback
      }

      try {
        updatedViewerCount = await presenceService.getRoomViewerCount(roomId, room?.creatorUserId);
      } catch (_) {
        updatedViewerCount = leaveResult?.currentViewersCount || 0;
      }

      const isRoomEnded = leaveResult?.status === 'ENDED';
      const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);

      if (isRoomEnded) {
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_CLOSED, {
          roomId,
          status: 'ENDED',
          reason: 'NO_MEMBERS_REMAINING',
        });
        if (io) {
          io.emit('room:closed', { roomId, status: 'ENDED' });
          io.emit('room:deleted', { roomId });
        }
      } else if (isHostUser && room) {
        // Host has left/disconnected: Room stays alive as long as viewers/speakers remain.
        const hostAwayPayload = {
          roomId,
          userId,
          status: 'LIVE',
          reason: 'HOST_AWAY',
          message: 'Host has temporarily stepped away.',
        };
        broadcastTarget.emit('room:host_away', hostAwayPayload);
        broadcastTarget.emit('room:host_left', hostAwayPayload);
        startHostAbsentTimer(roomId, room.roomType || 'LIVE_VIDEO', userId, io);
      } else {
        const leftPayload = {
          roomId: room ? room.id : roomId,
          clientRoomId: roomId,
          userId,
          id: userId,
          viewerCount: updatedViewerCount,
          count: updatedViewerCount,
          currentViewersCount: updatedViewerCount,
          user: {
            id: userId,
            displayName: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
            name: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
            username: socket.user?.username || 'user',
            avatarUrl: socket.user?.avatarUrl || null,
            isGuest: Boolean(socket.isGuest || String(userId).startsWith('guest_')),
          },
        };
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, leftPayload);
        broadcastTarget.emit('user_left', leftPayload);
        broadcastTarget.emit('user:left', leftPayload);
        broadcastTarget.emit('room_user_left', leftPayload);

        const countPayload = {
          roomId: room ? room.id : roomId,
          clientRoomId: roomId,
          viewerCount: updatedViewerCount,
          count: updatedViewerCount,
          currentViewersCount: updatedViewerCount,
        };
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, countPayload);
        broadcastTarget.emit('room:viewer_count', countPayload);
        broadcastTarget.emit('viewer_count_changed', countPayload);
      }
    }

    // 4. Update Authoritative User Room Presence on Leave & Clear Pending Mic Invites
    if (userId) {
      try {
        await micInviteService.clearPendingInvitesForUser(roomId, userId);
      } catch (_) {}
    }
    if (userId && !socket.isGuest && !String(userId).startsWith('guest_')) {
      try {
        await presenceService.clearUserActiveRoom(userId, roomId);
        const pres = await presenceService.getUserPresence(userId, db);
        if (io) {
          presenceService.broadcastPresenceChange(io, userId, pres);
        }
      } catch (_) {}
    }

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'Left room successfully' });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to leave room',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSocketDisconnect(io, socket, db) {
  try {
    const userId = socket.userId;
    if (!userId) return;

    // Track rooms cleaned up for this socket to ensure idempotency across 'disconnecting' and 'disconnect'
    socket._cleanedRooms = socket._cleanedRooms || new Set();

    const roomCandidates = new Set();
    if (socket.rooms) {
      for (const r of socket.rooms) {
        if (typeof r === 'string' && r.startsWith('room:')) {
          roomCandidates.add(r.replace(/^room:/, ''));
        }
      }
    }
    if (socket.joinedRooms) {
      for (const r of socket.joinedRooms) {
        if (typeof r === 'string') {
          roomCandidates.add(r.replace(/^room:/, ''));
        }
      }
      socket.joinedRooms.clear();
    }

    const joinedRooms = Array.from(roomCandidates);

    for (const roomId of joinedRooms) {
      if (socket._cleanedRooms.has(roomId)) {
        continue;
      }
      socket._cleanedRooms.add(roomId);

      try {
        let isLastSocket = true;
        try {
          const pres = await presenceService.removeSocketFromRoom(roomId, userId, socket.id);
          isLastSocket = pres?.isLastSocket ?? true;
        } catch {}

        if (isLastSocket) {
          const room = await roomRepository.findRoomById(roomId, db);
          if (!room || room.status !== 'LIVE') continue;

          const isHostUser = room.creatorUserId === userId || room.creator?.id === userId;
          const isAudioParty = (room.roomType || '').toUpperCase().includes('AUDIO') || (room.roomType || '').toUpperCase().includes('PARTY');

          let leaveResult = null;
          if (!isHostUser || !isAudioParty) {
            leaveResult = await roomService.leaveRoom(roomId, userId, db).catch(() => null);
          }

          let updatedViewerCount = 0;
          try {
            updatedViewerCount = await presenceService.getRoomViewerCount(roomId, room.creatorUserId);
          } catch (_) {
            updatedViewerCount = leaveResult?.currentViewersCount || 0;
          }
          const broadcastTarget = io ? io.to(`room:${roomId}`) : socket;

          if (isHostUser) {
            if (isAudioParty) {
              startHostAbsentTimer(roomId, 'AUDIO_PARTY', userId, io);
            } else {
              const hostLeftPayload = {
                roomId,
                status: 'ENDED',
                reason: 'HOST_LEFT',
                message: 'The live stream has ended by the host.',
              };
              broadcastTarget.emit(SOCKET_EVENTS.ROOM_CLOSED, hostLeftPayload);
              broadcastTarget.emit('room:closed', hostLeftPayload);
              broadcastTarget.emit('room_closed', hostLeftPayload);
              broadcastTarget.emit('stream:ended', hostLeftPayload);
              broadcastTarget.emit('room:host_left', hostLeftPayload);
              startHostAbsentTimer(roomId, 'LIVE_VIDEO', userId, io);
            }
          } else {
            const leftPayload = {
              roomId: room.id,
              clientRoomId: roomId,
              userId,
              id: userId,
              viewerCount: updatedViewerCount,
              count: updatedViewerCount,
              currentViewersCount: updatedViewerCount,
              user: {
                id: userId,
                displayName: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
                name: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
                username: socket.user?.username || 'user',
                avatarUrl: socket.user?.avatarUrl || null,
                isGuest: Boolean(socket.isGuest || String(userId).startsWith('guest_')),
              },
            };
            broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, leftPayload);
            broadcastTarget.emit('user_left', leftPayload);
            broadcastTarget.emit('user:left', leftPayload);
            broadcastTarget.emit('room_user_left', leftPayload);

            const countPayload = {
              roomId: room.id,
              clientRoomId: roomId,
              viewerCount: updatedViewerCount,
              count: updatedViewerCount,
              currentViewersCount: updatedViewerCount,
            };
            broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, countPayload);
            broadcastTarget.emit('room:viewer_count', countPayload);
            broadcastTarget.emit('viewer_count_changed', countPayload);
          }
          if (userId) {
            try {
              await micInviteService.clearPendingInvitesForUser(roomId, userId);
            } catch (_) {}
          }
        }
      } catch (innerErr) {
        console.warn(`[RoomSocket] Error handling disconnect for room ${roomId}:`, innerErr?.message);
      }
    }

    // Authoritative global connection presence cleanup
    if (!socket._cleanedGlobalPresence && userId) {
      socket._cleanedGlobalPresence = true;
      try {
        const { isLastSocket, userId: unregUserId } = await presenceService.unregisterUserSocket(userId, socket.id);
        const effectiveUserId = unregUserId || userId;
        if (isLastSocket && effectiveUserId && !socket.isGuest && !String(effectiveUserId).startsWith('guest_')) {
          await presenceService.clearUserActiveRoom(effectiveUserId);
          const pres = await presenceService.getUserPresence(effectiveUserId, db);
          if (io) {
            presenceService.broadcastPresenceChange(io, effectiveUserId, pres);
          }
        }
      } catch (presErr) {
        console.warn('[RoomSocket] Warning unregistering global socket presence:', presErr?.message);
      }
    }
  } catch (err) {
    console.error('[RoomSocket] onSocketDisconnect root error:', err);
  }
}

export async function onRequestSnapshot(socket, data, callback, db) {
  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const room = await roomRepository.findRoomById(roomId, db);
    if (!room) {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_FOUND, message: 'Room not found' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    let viewerCount = 0;
    try {
      viewerCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    } catch (_) {
      viewerCount = room.currentViewersCount || 0;
    }

    let activeUsers = [];
    try {
      activeUsers = await presenceService.getRoomActiveUsers(room.id);
    } catch (_) {}

    let feedClearedAt = null;
    try {
      feedClearedAt = await presenceService.getRoomFeedClearedAt(room.id);
    } catch (_) {}

    let recentGifts = [];
    try {
      const recentTxs = await (db || prisma).giftTransaction.findMany({
        where: { roomId: room.id },
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: {
          gift: { select: { id: true, name: true, iconUrl: true } },
          sender: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
          recipient: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
        },
      });
      recentGifts = recentTxs.reverse().map((tx) => ({
        id: tx.id,
        transactionId: tx.id,
        roomId: room.id,
        giftId: tx.giftId,
        giftName: tx.gift?.name || 'Gift',
        giftIcon: tx.gift?.iconUrl || '🎁',
        quantity: tx.giftCount,
        senderUserId: tx.senderUserId,
        senderName: tx.sender?.profile?.displayName || tx.sender?.username || 'User',
        senderAvatar: tx.sender?.avatarUrl || '',
        receiverUserId: tx.recipientUserId,
        receiverName: tx.recipient?.profile?.displayName || tx.recipient?.username || 'Host',
        receiverAvatar: tx.recipient?.avatarUrl || '',
        timestamp: tx.createdAt.toISOString(),
      }));
    } catch (_) {}

    const snapshot = buildRoomSnapshot(room, viewerCount, activeUsers);
    snapshot.feedClearedAt = feedClearedAt;
    snapshot.recentGifts = recentGifts;
    const responsePayload = {
      room: snapshot,
      ...snapshot,
      host: snapshot.host,
      seats: snapshot.seats || [],
      members: snapshot.members || [],
      currentViewersCount: viewerCount,
      viewerCount,
      feedClearedAt,
      recentGifts,
      timestamp: new Date().toISOString(),
    };

    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, responsePayload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: responsePayload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to retrieve snapshot',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onRequestActiveRooms(socket, data, callback, db = prisma) {
  try {
    const filters = {
      roomType: data?.roomType,
      category: data?.category,
      search: data?.search,
      page: data?.page || 1,
      limit: data?.limit || 50,
      isPrivate: false,
    };

    const result = await roomService.getActiveRooms(filters, db);
    const payload = {
      success: true,
      data: result.rooms,
      rooms: result.rooms,
      pagination: result.pagination,
      timestamp: new Date().toISOString(),
    };

    if (typeof callback === 'function') {
      return callback(payload);
    }
    socket.emit('rooms:active_list', payload);
    socket.emit('rooms_active_list', payload);
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to retrieve active rooms',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSendRoomEmoji(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const emoji = (data?.emoji || '').trim();
    const targetUserId = data?.targetUserId || null;

    if (!roomId || !emoji) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.VALIDATION_ERROR,
          message: 'roomId and emoji are required',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // Ensure socket is joined to room channel
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
    }

    const payload = {
      id: `emoji_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      roomId,
      emoji,
      targetUserId,
      sender: {
        id: socket.user?.id || socket.userId,
        username: socket.user?.username || 'user',
        displayName: socket.user?.displayName || socket.user?.username || 'User',
        avatarUrl: socket.user?.avatarUrl || socket.user?.profile?.avatarUrl || null,
      },
      timestamp: new Date().toISOString(),
    };

    // Broadcast to ALL room members including sender
    const broadcastTarget = io ? io.to(`room:${roomId}`) : socket;
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_EMOJI_RECEIVED, payload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to send emoji reaction',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSendRoomChat(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const text = (data?.text || '').trim();

    if (!roomId || !text) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.VALIDATION_ERROR,
          message: 'roomId and message text are required',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // Resolve canonical room ID if short ID was passed
    let canonicalRoomId = roomId;
    if (roomId && roomId.length <= 16) {
      try {
        const found = await roomRepository.findRoomById(roomId, db || prisma);
        if (found) {
          canonicalRoomId = found.id;
        }
      } catch (_) {}
    }

    // Ensure socket is joined to room channel
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
      if (canonicalRoomId !== roomId) {
        socket.join(`room:${canonicalRoomId}`);
      }
    }

    const clientSender = data?.sender || data?.user || {};
    const senderId = clientSender.id || clientSender.userId || socket.user?.id || socket.userId;
    let senderName = clientSender.displayName || clientSender.name || clientSender.username || socket.user?.displayName || socket.user?.name || socket.user?.username;
    let senderAvatar = clientSender.avatarUrl || socket.user?.avatarUrl;
    let senderVip = Boolean(clientSender.isVip || socket.user?.isVip);
    let senderNoble = clientSender.nobleTitle || clientSender.nobleLevel || socket.user?.nobleTitle || socket.user?.nobleLevel;
    let senderRole = clientSender.role || socket.user?.role;
    let senderFrame = clientSender.avatarFrame || clientSender.frameUrl || socket.user?.avatarFrame;
    let senderBubble = clientSender.chatBubble || clientSender.bubbleUrl || socket.user?.chatBubble;

    if (!senderName || senderName === 'User' || senderName === 'ZeParty Member' || senderName.startsWith('guest_')) {
      try {
        if (senderId && !String(senderId).startsWith('guest_')) {
          const dbUser = await userRepository.findById(senderId);
          if (dbUser) {
            senderName = dbUser.profile?.displayName || dbUser.name || dbUser.username || senderName;
            senderAvatar = dbUser.profile?.avatarUrl || dbUser.avatarUrl || senderAvatar;
            senderVip = Boolean(dbUser.profile?.vipLevel > 0 || dbUser.profile?.svipLevel > 0);
            senderNoble = dbUser.profile?.nobleRank || senderNoble;
            senderRole = dbUser.userType || senderRole;
          }
        }
      } catch (_) {}
    }

    if (!senderName || senderName === 'ZeParty Member') {
      senderName = `User_${String(senderId).replace('guest_', '').substring(0, 5)}`;
    }

    const payload = {
      id: data?.id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      roomId: canonicalRoomId,
      clientRoomId: roomId,
      senderUserId: senderId,
      sender: {
        id: senderId,
        userId: senderId,
        username: clientSender.username || socket.user?.username || senderName,
        name: senderName || 'User',
        displayName: senderName || 'User',
        avatarUrl: senderAvatar || null,
        avatarFrame: senderFrame || null,
        chatBubble: senderBubble || null,
        isVip: senderVip,
        nobleLevel: senderNoble || null,
        nobleTitle: senderNoble || null,
        role: senderRole || null,
      },
      text: text.substring(0, 500),
      timestamp: new Date().toISOString(),
      type: data?.type || 'text',
    };

    const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
    broadcastTarget.emit('room:chat_message', payload);
    broadcastTarget.emit('room_chat_message', payload);
    broadcastTarget.emit('chat_message', payload);
    broadcastTarget.emit('room:comment', payload);

    if (io && canonicalRoomId !== roomId) {
      io.to(`room:${canonicalRoomId}`).emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
      io.to(`room:${canonicalRoomId}`).emit('room:chat_message', payload);
      io.to(`room:${canonicalRoomId}`).emit('room_chat_message', payload);
      io.to(`room:${canonicalRoomId}`).emit('chat_message', payload);
      io.to(`room:${canonicalRoomId}`).emit('room:comment', payload);
    }

    if (!io && socket && typeof socket.emit === 'function') {
      socket.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
      socket.emit('room:chat_message', payload);
      socket.emit('room_chat_message', payload);
      socket.emit('chat_message', payload);
      socket.emit('room:comment', payload);
    }

    if (typeof callback === 'function') {
      return callback({ success: true, data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to send room chat message',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onKickUser(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const targetUserId = data?.targetUserId;
    const reason = data?.reason;
    const actorUserId = socket.userId;

    if (!roomId || !targetUserId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'roomId and targetUserId are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const result = await roomService.kickRoomUser(roomId, actorUserId, { targetUserId, reason });

    try {
      await presenceService.clearUserActiveRoom(targetUserId, roomId);
      const pres = await presenceService.getUserPresence(targetUserId);
      if (io) {
        presenceService.broadcastPresenceChange(io, targetUserId, pres);
      }
    } catch (_) {}

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'User kicked successfully', data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to kick user' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onRemoveFromMic(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const targetUserId = data?.targetUserId;
    const reason = data?.reason;
    const actorUserId = socket.userId;

    if (!roomId || !targetUserId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'roomId and targetUserId are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const result = await roomService.removeRoomUserFromMic(roomId, actorUserId, { targetUserId, reason });

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'User removed from mic successfully', data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to remove user from mic' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onMuteUser(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const targetUserId = data?.targetUserId;
    const isMuted = data?.isMuted !== undefined ? Boolean(data.isMuted) : true;
    const reason = data?.reason;
    const actorUserId = socket.userId;

    if (!roomId || !targetUserId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'roomId and targetUserId are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const result = await roomService.moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted, reason });

    if (typeof callback === 'function') {
      return callback({ success: true, message: isMuted ? 'User muted successfully' : 'User unmuted successfully', data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to update mute state' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onModerateUser(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const targetUserId = data?.targetUserId;
    const action = data?.action;
    const isMuted = data?.isMuted;
    const reason = data?.reason;
    const actorUserId = socket.userId;

    if (!roomId || !targetUserId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'roomId and targetUserId are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const result = await roomService.moderateRoomUser(roomId, actorUserId, { targetUserId, action, isMuted, reason });

    if (typeof callback === 'function') {
      return callback({ success: true, message: result.message, data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to perform moderation' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Change 13: Live Viewers Mic Invitation Handlers
// ─────────────────────────────────────────────────────────────────────────────

export async function onInviteToMic(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const targetUserId = data?.targetUserId;
    const seatIndex = data?.seatIndex !== undefined && data?.seatIndex !== null ? Number(data.seatIndex) : null;
    const actorUserId = socket.userId;

    const result = await micInviteService.createMicInvite({
      roomId,
      actorUserId,
      targetUserId,
      seatIndex,
    });

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'Invitation to mic sent successfully', data: result });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to send invitation to mic' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onAcceptMicInvite(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const invitationId = data?.invitationId;
    const userId = socket.userId;

    const result = await micInviteService.acceptMicInvite({
      roomId,
      invitationId,
      userId,
    });

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'Joined mic successfully', data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to accept mic invitation' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onDeclineMicInvite(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const invitationId = data?.invitationId;
    const reason = data?.reason || (data?.isPermissionDenied ? 'PERMISSION_DENIED' : 'DECLINED_BY_USER');
    const userId = socket.userId;

    const result = await micInviteService.declineMicInvite({
      roomId,
      invitationId,
      userId,
      reason,
    });

    if (typeof callback === 'function') {
      return callback({ success: true, message: result.message, data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to decline mic invitation' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onCancelMicInvite(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const invitationId = data?.invitationId;
    const actorUserId = socket.userId;

    const result = await micInviteService.cancelMicInvite({
      roomId,
      invitationId,
      actorUserId,
    });

    if (typeof callback === 'function') {
      return callback({ success: true, message: result.message, data: result.data });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to cancel mic invitation' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSendRoomLike(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const count = Number(data?.count) || 1;

    if (!roomId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
    }

    const sender = data?.sender && typeof data.sender === 'object' ? data.sender : {
      id: socket.user?.id || socket.userId,
      userId: socket.user?.id || socket.userId,
      username: socket.user?.username || 'user',
      name: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
      displayName: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
      avatarUrl: socket.user?.avatarUrl || socket.user?.profile?.avatarUrl || null,
      isVip: Boolean(socket.user?.isVip),
      nobleLevel: socket.user?.nobleLevel || null,
      nobleTitle: socket.user?.nobleTitle || null,
    };

    const payload = {
      roomId,
      count,
      userId: socket.user?.id || socket.userId,
      sender,
      timestamp: new Date().toISOString(),
    };

    const broadcastTarget = socket.to ? socket.to(`room:${roomId}`) : (io ? io.to(`room:${roomId}`) : socket);
    broadcastTarget.emit('room:like', payload);
    broadcastTarget.emit('room:like_sent', payload);
    broadcastTarget.emit('room_like', payload);
    broadcastTarget.emit('like_sent', payload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to send room like' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onUpdateRoomBackground(io, socket, data, callback) {
  try {
    const roomId = data?.roomId || data?.id;
    const rawBackground = data?.backgroundImageUrl !== undefined ? data.backgroundImageUrl : data?.background;
    const userId = socket.user?.id || socket.userId;

    if (!roomId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (!userId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.UNAUTHORIZED, message: 'Authentication required to update background' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const result = await roomService.updateRoomBackground(roomId, userId, {
      backgroundImageUrl: rawBackground,
    });

    const payload = {
      roomId: result.roomId,
      backgroundImageUrl: result.backgroundImageUrl,
      background: result.background,
      updatedBy: userId,
      timestamp: new Date().toISOString(),
    };

    const broadcastTarget = io ? io.to(`room:${result.roomId}`) : (socket.to ? socket.to(`room:${result.roomId}`) : socket);
    broadcastTarget.emit('room:background_updated', payload);
    broadcastTarget.emit('room_background_updated', payload);
    broadcastTarget.emit('room:update_background', payload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: result });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to update background' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onUpdateRoomLock(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: 'VALIDATION_ERROR', message: 'roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }
    const actorUserId = socket.user?.id || socket.userId;
    const result = await roomService.controlRoomLock(roomId, {
      ...data,
      actorUserId,
    });
    if (typeof callback === 'function') return callback(result);
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to update room lock settings' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onUpdateRoomDetails(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: 'VALIDATION_ERROR', message: 'roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }
    const userId = socket.user?.id || socket.userId;
    const result = await roomService.updateRoomProfile(roomId, userId, data);
    if (typeof callback === 'function') return callback(result);
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to update room profile' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export function registerRoomHandlers(io, socket) {
  // Issue 07: Room Lock Settings Realtime Socket Events
  socket.on(
    'room:update_lock',
    withRateLimit('ROOM_LOCK', 10, 1000, (s, d, cb) => onUpdateRoomLock(io, s, d, cb))
  );
  socket.on(
    'room:lock_settings',
    withRateLimit('ROOM_LOCK', 10, 1000, (s, d, cb) => onUpdateRoomLock(io, s, d, cb))
  );
  socket.on(
    'room:lock',
    withRateLimit('ROOM_LOCK', 10, 1000, (s, d, cb) => onUpdateRoomLock(io, s, d, cb))
  );

  // Issue 09: Room Details & Profile Updates Realtime Socket Events
  socket.on(
    'room:update_details',
    withRateLimit('ROOM_PROFILE', 10, 1000, (s, d, cb) => onUpdateRoomDetails(io, s, d, cb))
  );
  socket.on(
    'room:details_update',
    withRateLimit('ROOM_PROFILE', 10, 1000, (s, d, cb) => onUpdateRoomDetails(io, s, d, cb))
  );
  socket.on(
    'room:profile_update',
    withRateLimit('ROOM_PROFILE', 10, 1000, (s, d, cb) => onUpdateRoomDetails(io, s, d, cb))
  );

  socket.on(
    'room:update_background',
    withRateLimit('ROOM_BG', 10, 1000, (s, d, cb) => onUpdateRoomBackground(io, s, d, cb))
  );
  socket.on(
    'room:change_background',
    withRateLimit('ROOM_BG', 10, 1000, (s, d, cb) => onUpdateRoomBackground(io, s, d, cb))
  );
  socket.on(
    'update_room_background',
    withRateLimit('ROOM_BG', 10, 1000, (s, d, cb) => onUpdateRoomBackground(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_JOIN,
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'room_join',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'join_room',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'join:room',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_LEAVE,
    withRateLimit('ROOM_LEAVE', 10, 1000, (s, d, cb) => onLeaveRoom(io, s, d, cb))
  );
  socket.on(
    'room_leave',
    withRateLimit('ROOM_LEAVE', 10, 1000, (s, d, cb) => onLeaveRoom(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_SNAPSHOT,
    withRateLimit('ROOM_SNAPSHOT', 10, 1000, (s, d, cb) => onRequestSnapshot(s, d, cb))
  );
  socket.on(
    'room_snapshot',
    withRateLimit('ROOM_SNAPSHOT', 10, 1000, (s, d, cb) => onRequestSnapshot(s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_CHAT_SEND,
    withRateLimit('ROOM_CHAT', 25, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room_chat_send',
    withRateLimit('ROOM_CHAT', 25, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'send_room_chat',
    withRateLimit('ROOM_CHAT', 25, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_EMOJI_SEND,
    withRateLimit('ROOM_EMOJI', 30, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'room_emoji_send',
    withRateLimit('ROOM_EMOJI', 30, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );

  // Real-time Room Likes
  socket.on(
    'room:like',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );
  socket.on(
    'room:like_send',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );
  socket.on(
    'room_like',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );
  socket.on(
    'like_send',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );

  // Client user joined trigger
  socket.on(
    'room:user_joined',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'room_user_joined',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_KICK_USER,
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onKickUser(io, s, d, cb))
  );
  socket.on(
    'room:kick_user',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onKickUser(io, s, d, cb))
  );
  socket.on(
    'kick_user',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onKickUser(io, s, d, cb))
  );

  socket.on(
    'room:remove_from_mic',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onRemoveFromMic(io, s, d, cb))
  );
  socket.on(
    'room:remove_mic',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onRemoveFromMic(io, s, d, cb))
  );
  socket.on(
    'remove_from_mic',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onRemoveFromMic(io, s, d, cb))
  );

  socket.on(
    'room:mute_user',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onMuteUser(io, s, d, cb))
  );
  socket.on(
    'room:mute_participant',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onMuteUser(io, s, d, cb))
  );
  socket.on(
    'mute_user',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onMuteUser(io, s, d, cb))
  );

  socket.on(
    'room:moderate_user',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onModerateUser(io, s, d, cb))
  );
  socket.on(
    'moderate_user',
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onModerateUser(io, s, d, cb))
  );

  // Real-time Room Mic Invitations (Change 13: Direct User Delivery & Robust Room Routing)
  const handleMicInvite = async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const targetUserId = data?.targetUserId ? String(data.targetUserId) : null;
      if (!roomId || !targetUserId) {
        if (typeof callback === 'function') callback({ success: false, message: 'roomId and targetUserId required' });
        return;
      }

      // Check room and authorization
      const room = await roomRepository.findRoomById(roomId).catch(() => null);
      const isOwner = room && (room.creatorUserId === socket.userId || room.creator?.id === socket.userId);
      const isAdmin = socket.user?.isAdmin || socket.user?.role === 'ADMIN' || socket.user?.role === 'MODERATOR';

      // Permission check: only owner or authorized admin can invite viewers to mic
      if (room && !isOwner && !isAdmin) {
        const errMsg = 'Only room owner and authorized admins can invite viewers to mic.';
        socket.emit(SOCKET_EVENTS.ERROR, { code: SOCKET_ERRORS.PERMISSION_DENIED || 'PERMISSION_DENIED', message: errMsg });
        if (typeof callback === 'function') callback({ success: false, message: errMsg });
        return;
      }

      // Check seat capacity if authoritative seats are available
      if (room?.seats && Array.isArray(room.seats)) {
        const hasAvailableSeat = room.seats.some((s) => !s.occupiedUserId && !s.isLocked);
        if (!hasAvailableSeat) {
          const errMsg = 'No available mic seats in this room.';
          socket.emit(SOCKET_EVENTS.ERROR, { code: 'ROOM_FULL', message: errMsg });
          if (typeof callback === 'function') callback({ success: false, message: errMsg });
          return;
        }
      }

      const canonicalRoomId = room?.id || roomId;
      const inviterUser = data.inviter || (socket.user ? {
        id: socket.userId,
        name: socket.user.displayName || socket.user.name || socket.user.username || 'Host',
        username: socket.user.username,
        avatarUrl: socket.user.avatarUrl,
      } : { id: socket.userId, name: 'Host' });

      const payload = {
        id: data.id || `inv_${Date.now()}_${targetUserId}`,
        roomId: roomId,
        canonicalRoomId: canonicalRoomId,
        roomTitle: data.roomTitle || room?.title || 'Party Room',
        targetUserId: targetUserId,
        inviterUserId: socket.userId,
        inviter: inviterUser,
        targetUser: data.targetUser || { id: targetUserId },
        seatIndex: data.seatIndex,
        createdAt: data.createdAt || new Date().toISOString(),
      };

      // 1. Broadcast to room channel by both input roomId and canonical roomId
      io.to(`room:${roomId}`).emit('room:mic_invite', payload);
      io.to(`room:${roomId}`).emit('room_mic_invite', payload);
      if (canonicalRoomId !== roomId) {
        io.to(`room:${canonicalRoomId}`).emit('room:mic_invite', payload);
        io.to(`room:${canonicalRoomId}`).emit('room_mic_invite', payload);
      }

      // 2. CRITICAL: Direct delivery to target user's private channel user:${targetUserId}
      io.to(`user:${targetUserId}`).emit('room:mic_invite', payload);
      io.to(`user:${targetUserId}`).emit('room_mic_invite', payload);

      if (typeof callback === 'function') {
        callback({ success: true, invitation: payload });
      }
    } catch (err) {
      console.warn('[RoomSocket] handleMicInvite error:', err.message);
    }
  };

  socket.on('room:mic_invite', handleMicInvite);
  socket.on('room_mic_invite', handleMicInvite);

  const handleMicInviteResponse = async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const targetUserId = data?.targetUserId ? String(data.targetUserId) : socket.userId;
      if (!roomId) return;

      const room = await roomRepository.findRoomById(roomId).catch(() => null);
      const canonicalRoomId = room?.id || roomId;

      const payload = {
        ...data,
        roomId,
        canonicalRoomId,
        targetUserId,
      };

      // 1. Broadcast to room channels
      io.to(`room:${roomId}`).emit('room:mic_invite_response', payload);
      io.to(`room:${roomId}`).emit('room_mic_invite_response', payload);
      if (canonicalRoomId !== roomId) {
        io.to(`room:${canonicalRoomId}`).emit('room:mic_invite_response', payload);
        io.to(`room:${canonicalRoomId}`).emit('room_mic_invite_response', payload);
      }

      // 2. Direct delivery to inviter if specified to clear Pending state immediately
      const inviterId = data?.inviterUserId || data?.inviter?.id;
      if (inviterId) {
        io.to(`user:${inviterId}`).emit('room:mic_invite_response', payload);
        io.to(`user:${inviterId}`).emit('room_mic_invite_response', payload);
      }

      if (typeof callback === 'function') {
        callback({ success: true });
      }
    } catch (err) {
      console.warn('[RoomSocket] handleMicInviteResponse error:', err.message);
    }
  };

  socket.on('room:mic_invite_response', handleMicInviteResponse);
  socket.on('room_mic_invite_response', handleMicInviteResponse);

  // Authoritative Active Rooms Snapshot Request for newly connected or reconnecting clients
  socket.on(
    'rooms:get_active',
    withRateLimit('ROOM_ACTIVE_LIST', 15, 1000, (s, d, cb) => onRequestActiveRooms(s, d, cb))
  );
  socket.on(
    'rooms_get_active',
    withRateLimit('ROOM_ACTIVE_LIST', 15, 1000, (s, d, cb) => onRequestActiveRooms(s, d, cb))
  );
  socket.on(
    'rooms:list',
    withRateLimit('ROOM_ACTIVE_LIST', 15, 1000, (s, d, cb) => onRequestActiveRooms(s, d, cb))
  );

  // Change 13: Mic Invitations from Live Viewers
  socket.on(
    SOCKET_EVENTS.MIC_INVITATION_SEND,
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onInviteToMic(io, s, d, cb))
  );
  socket.on(
    'room:mic_invite',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onInviteToMic(io, s, d, cb))
  );
  socket.on(
    'room:invite_to_mic',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onInviteToMic(io, s, d, cb))
  );
  socket.on(
    'room:invite_mic',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onInviteToMic(io, s, d, cb))
  );
  socket.on(
    'invite_to_mic',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onInviteToMic(io, s, d, cb))
  );
  socket.on(
    'invite_mic',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onInviteToMic(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.MIC_INVITATION_ACCEPT,
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onAcceptMicInvite(io, s, d, cb))
  );
  socket.on(
    'room:mic_invite_accept',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onAcceptMicInvite(io, s, d, cb))
  );
  socket.on(
    'accept_mic_invite',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onAcceptMicInvite(io, s, d, cb))
  );
  socket.on(
    'mic_invite_accept',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onAcceptMicInvite(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.MIC_INVITATION_DECLINE,
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onDeclineMicInvite(io, s, d, cb))
  );
  socket.on(
    'room:mic_invite_decline',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onDeclineMicInvite(io, s, d, cb))
  );
  socket.on(
    'decline_mic_invite',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onDeclineMicInvite(io, s, d, cb))
  );
  socket.on(
    'mic_invite_decline',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onDeclineMicInvite(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.MIC_INVITATION_CANCEL,
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onCancelMicInvite(io, s, d, cb))
  );
  socket.on(
    'room:mic_invite_cancel',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onCancelMicInvite(io, s, d, cb))
  );
  socket.on(
    'cancel_mic_invite',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onCancelMicInvite(io, s, d, cb))
  );
  socket.on(
    'mic_invite_cancel',
    withRateLimit('MIC_INVITE', 10, 1000, (s, d, cb) => onCancelMicInvite(io, s, d, cb))
  );

  // Issue 28: Clear Screen / Lower Room Feed Realtime Actions
  socket.on(
    SOCKET_EVENTS.PARTY_CLEAR_SCREEN,
    withRateLimit('ROOM_MOD', 10, 1000, (s, d, cb) => onClearScreen(io, s, d, cb))
  );
  socket.on(
    'party:clear_screen',
    withRateLimit('ROOM_MOD', 10, 1000, (s, d, cb) => onClearScreen(io, s, d, cb))
  );
  socket.on(
    'room:clear_feed',
    withRateLimit('ROOM_MOD', 10, 1000, (s, d, cb) => onClearScreen(io, s, d, cb))
  );
  socket.on(
    'clear_screen',
    withRateLimit('ROOM_MOD', 10, 1000, (s, d, cb) => onClearScreen(io, s, d, cb))
  );
  socket.on(
    'clear_feed',
    withRateLimit('ROOM_MOD', 10, 1000, (s, d, cb) => onClearScreen(io, s, d, cb))
  );

  // Authoritative Broadcast Attendance Streaming Heartbeats
  socket.on('stream:heartbeat', (d, cb) => onStreamHeartbeat(io, socket, d, cb));
  socket.on('live:heartbeat', (d, cb) => onStreamHeartbeat(io, socket, d, cb));
  socket.on('room:heartbeat', (d, cb) => onStreamHeartbeat(io, socket, d, cb));

  // Issue 07: Room Lock Settings Realtime Sync
  socket.on('room:update_lock', (d, cb) => onUpdateRoomLock(io, socket, d, cb));
  socket.on('room:lock_settings', (d, cb) => onUpdateRoomLock(io, socket, d, cb));
  socket.on('room:lock', (d, cb) => onUpdateRoomLock(io, socket, d, cb));

  // Issue 09: Room Profile / Details Realtime Sync
  socket.on('room:update_details', (d, cb) => onUpdateRoomDetails(io, socket, d, cb));
  socket.on('room:details_update', (d, cb) => onUpdateRoomDetails(io, socket, d, cb));
  socket.on('room:profile_update', (d, cb) => onUpdateRoomDetails(io, socket, d, cb));

  // Issue 11: Room Seat Count & Layout Mode Realtime Sync
  socket.on('room:update_layout', (d, cb) => onUpdateRoomLayout(io, socket, d, cb));
  socket.on('room:layout_updated', (d, cb) => onUpdateRoomLayout(io, socket, d, cb));
  socket.on('room:change_layout', (d, cb) => onUpdateRoomLayout(io, socket, d, cb));

  // Handle both disconnecting (before leaveAll) and disconnect (as safety fallback)
  socket.on('disconnecting', () => onSocketDisconnect(io, socket));
  socket.on(SOCKET_EVENTS.DISCONNECT, () => onSocketDisconnect(io, socket));
}

export async function onClearScreen(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);

  try {
    const roomId = data?.roomId;
    if (!roomId || typeof roomId !== 'string') {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_ERRORS.ERROR || SOCKET_EVENTS.ERROR, err);
    }

    const actorUserId = socket.userId;
    if (!actorUserId) {
      const err = {
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Authentication is required to clear room feed' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const result = await roomService.clearRoomFeed(roomId, actorUserId, { reason: data?.reason }, db || prisma);

    if (typeof callback === 'function') {
      return callback(result);
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to clear room feed',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onStreamHeartbeat(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    const hostUserId = socket.userId;
    if (!roomId) {
      const err = { success: false, message: 'roomId is required for streaming heartbeat' };
      if (typeof callback === 'function') return callback(err);
      return socket.emit('stream:heartbeat_ack', err);
    }
    const result = await attendanceService.recordBroadcastHeartbeat({ roomId, hostUserId });
    if (typeof callback === 'function') return callback(result);
    return socket.emit('stream:heartbeat_ack', result);
  } catch (err) {
    const errPayload = { success: false, error: err.message || 'Heartbeat recording failed' };
    if (typeof callback === 'function') return callback(errPayload);
    return socket.emit('stream:heartbeat_ack', errPayload);
  }
}

export async function onUpdateRoomLayout(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: 'VALIDATION_ERROR', message: 'roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }
    const actorUserId = socket.user?.id || socket.userId || data?.userId;
    if (!actorUserId) {
      const err = { success: false, error: { code: 'UNAUTHORIZED', message: 'Authentication required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }
    const capacity = data?.capacity || data?.seatCapacity;
    const roomType = data?.roomType;
    const result = await roomService.updateRoomLayout(roomId, actorUserId, { capacity, roomType });
    if (typeof callback === 'function') return callback(result);
    return socket.emit('room:layout_updated', result?.data || result);
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to update room layout' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export default {
  buildRoomSnapshot,
  onJoinRoom,
  onLeaveRoom,
  onRequestSnapshot,
  onRequestActiveRooms,
  onSendRoomChat,
  onSendRoomEmoji,
  onSendRoomLike,
  onKickUser,
  onRemoveFromMic,
  onMuteUser,
  onModerateUser,
  onInviteToMic,
  onAcceptMicInvite,
  onDeclineMicInvite,
  onCancelMicInvite,
  onUpdateRoomBackground,
  onSocketDisconnect,
  onStreamHeartbeat,
  onClearScreen,
  onUpdateRoomLock,
  onUpdateRoomDetails,
  onUpdateRoomLayout,
  registerRoomHandlers,
};
