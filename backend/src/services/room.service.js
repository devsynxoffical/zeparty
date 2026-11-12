import crypto from 'crypto';
import prisma from '../config/database.js';
import roomRepository from '../repositories/room.repository.js';
import userRepository from '../repositories/user.repository.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';
import {
  deriveAgoraUid,
  formatAuthoritativeUserIdentity,
  buildAgoraUidIdentityMap,
} from '../utils/agoraToken.util.js';
import {
  clearHostAbsentTimer,
  clearEmptyRoomSleepTimer,
  checkAndSchedulePartyRoomSleep,
  isPartyRoomType,
  getActiveRoomParticipantCount,
} from '../socket/roomTimer.manager.js';
import presenceService from '../socket/presence.service.js';
import micInviteService from './micInvite.service.js';
import * as attendanceService from './attendance.service.js';
import wheelService from './wheel.service.js';
import luckyBagService from './luckyBag.service.js';
import bcrypt from 'bcryptjs';
import stageService from './stage.service.js';
import roomRoleAuditService from './roomRoleAudit.service.js';
import { getNobleStyle } from './asset.service.js';
import roomLevelService from './roomLevel.service.js';
import roomTrophyService from './roomTrophy.service.js';
import { getAuthoritativeRoomSessionScore, ensureActiveRoomSession } from './roomSession.service.js';

/**
 * Enriches a room object with authoritative ZeParty identities, Agora UIDs,
 * participants array, and agoraUidMap across Party, Live, and Admin APIs.
 */
export function enrichRoomIdentitySnapshot(room, activePresenceUsers = []) {
  if (!room || typeof room !== 'object') return room;

  const hostUserId = room.creatorUserId || room.creator?.id || room.host?.id || null;
  const hostAgoraUid = hostUserId ? deriveAgoraUid(hostUserId) : 0;

  const creatorIdentity = room.creator
    ? formatAuthoritativeUserIdentity(room.creator, { role: 'HOST', isHost: true, seatIndex: 0 })
    : hostUserId
    ? formatAuthoritativeUserIdentity({ id: hostUserId, username: room.hostUsername || 'Host' }, { role: 'HOST', isHost: true, seatIndex: 0 })
    : null;

  const enrichedCreator = room.creator
    ? {
        ...room.creator,
        id: room.creator.id || hostUserId,
        userId: room.creator.id || hostUserId,
        username: creatorIdentity?.username || room.creator.username,
        displayName: creatorIdentity?.displayName || room.creator.profile?.displayName || room.creator.username,
        name: creatorIdentity?.displayName || room.creator.profile?.displayName || room.creator.username,
        avatarUrl: creatorIdentity?.avatarUrl || null,
        agoraUid: hostAgoraUid,
        uid: hostAgoraUid,
      }
    : creatorIdentity;

  const enrichedSeats = Array.isArray(room.seats)
    ? room.seats.map((s) => {
        const occRaw = s.occupiedUser || s.user || null;
        const occUserId = s.occupiedUserId || occRaw?.id || occRaw?.userId || null;
        const occIdentity = occRaw
          ? formatAuthoritativeUserIdentity(occRaw, {
              role: occUserId === hostUserId ? 'HOST' : s.seatIndex === 1 ? 'CO_HOST' : 'SPEAKER',
              seatIndex: s.seatIndex,
            })
          : occUserId
          ? formatAuthoritativeUserIdentity(
              { id: occUserId },
              {
                role: occUserId === hostUserId ? 'HOST' : s.seatIndex === 1 ? 'CO_HOST' : 'SPEAKER',
                seatIndex: s.seatIndex,
              }
            )
          : null;

        const enrichedOcc = occIdentity
          ? {
              ...(occRaw || {}),
              ...occIdentity,
              id: occIdentity.id,
              userId: occIdentity.userId,
              agoraUid: occIdentity.agoraUid,
              uid: occIdentity.uid,
              username: occIdentity.username,
              displayName: occIdentity.displayName,
              name: occIdentity.name,
              avatarUrl: occIdentity.avatarUrl,
            }
          : null;

        return {
          ...s,
          agoraUid: occIdentity?.agoraUid || null,
          uid: occIdentity?.uid || null,
          occupiedUser: enrichedOcc,
          user: enrichedOcc,
        };
      })
    : [];

  const seatedMap = new Map();
  for (const s of enrichedSeats) {
    if (s.occupiedUserId) {
      seatedMap.set(s.occupiedUserId, s);
    }
  }

  const enrichedMembers = Array.isArray(room.members)
    ? room.members.map((m) => {
        const uRaw = m.user || m;
        const mUserId = m.userId || uRaw?.id || uRaw?.userId;
        const isHost = mUserId === hostUserId;
        const seatObj = seatedMap.get(mUserId) || null;
        const mIdentity = formatAuthoritativeUserIdentity(
          {
            ...uRaw,
            id: mUserId,
          },
          {
            role: isHost ? 'HOST' : m.role || (seatObj ? 'SPEAKER' : 'VIEWER'),
            seatIndex: seatObj ? seatObj.seatIndex : null,
          }
        );

        return {
          ...m,
          id: mUserId,
          userId: mUserId,
          agoraUid: mIdentity?.agoraUid || deriveAgoraUid(mUserId),
          uid: mIdentity?.uid || deriveAgoraUid(mUserId),
          username: mIdentity?.username || uRaw?.username || mUserId,
          displayName: mIdentity?.displayName || uRaw?.displayName || uRaw?.username || mUserId,
          name: mIdentity?.name || uRaw?.displayName || uRaw?.username || mUserId,
          avatarUrl: mIdentity?.avatarUrl || null,
          role: isHost ? 'HOST' : m.role || (seatObj ? 'SPEAKER' : 'VIEWER'),
          isHost,
          seatIndex: seatObj ? seatObj.seatIndex : null,
          micOn: seatObj ? !seatObj.isMuted : false,
          user: {
            ...(m.user || {}),
            ...(mIdentity || {}),
            id: mUserId,
            userId: mUserId,
            agoraUid: mIdentity?.agoraUid || deriveAgoraUid(mUserId),
            uid: mIdentity?.uid || deriveAgoraUid(mUserId),
          },
        };
      })
    : [];

  // Build unified participants list (Host + Seated + Members + Active Presence)
  const participantMap = new Map();

  if (creatorIdentity && hostUserId) {
    const hostSeat = seatedMap.get(hostUserId) || null;
    participantMap.set(hostUserId, {
      ...creatorIdentity,
      id: hostUserId,
      userId: hostUserId,
      role: 'HOST',
      isHost: true,
      seatIndex: hostSeat ? hostSeat.seatIndex : 0,
      micOn: hostSeat ? !hostSeat.isMuted : true,
    });
  }

  for (const s of enrichedSeats) {
    if (s.occupiedUserId && s.user) {
      participantMap.set(s.occupiedUserId, {
        ...s.user,
        id: s.occupiedUserId,
        userId: s.occupiedUserId,
        role: s.occupiedUserId === hostUserId ? 'HOST' : s.seatIndex === 1 ? 'CO_HOST' : 'SPEAKER',
        isHost: s.occupiedUserId === hostUserId,
        seatIndex: s.seatIndex,
        micOn: !s.isMuted,
      });
    }
  }

  for (const m of enrichedMembers) {
    if (m.userId && !participantMap.has(m.userId)) {
      participantMap.set(m.userId, {
        ...(m.user || {}),
        id: m.userId,
        userId: m.userId,
        agoraUid: m.agoraUid,
        uid: m.uid,
        username: m.username,
        displayName: m.displayName,
        name: m.name,
        avatarUrl: m.avatarUrl,
        role: m.role || 'VIEWER',
        isHost: m.isHost,
        seatIndex: m.seatIndex,
        micOn: Boolean(m.micOn),
      });
    }
  }

  if (Array.isArray(activePresenceUsers)) {
    for (const p of activePresenceUsers) {
      const pUserId = p?.userId || p?.id;
      if (!pUserId) continue;
      if (!participantMap.has(pUserId)) {
        const seatObj = seatedMap.get(pUserId) || null;
        const pIdentity = formatAuthoritativeUserIdentity(p, {
          role: pUserId === hostUserId ? 'HOST' : seatObj ? 'SPEAKER' : 'VIEWER',
          seatIndex: seatObj ? seatObj.seatIndex : null,
        });
        if (pIdentity) {
          participantMap.set(pUserId, {
            ...pIdentity,
            seatIndex: seatObj ? seatObj.seatIndex : null,
            micOn: seatObj ? !seatObj.isMuted : false,
          });
        }
      }
    }
  }

  const participants = Array.from(participantMap.values());
  const agoraUidMap = buildAgoraUidIdentityMap(participants);

  return {
    ...room,
    agoraHostUid: hostAgoraUid,
    hostAgoraUid,
    creator: enrichedCreator,
    host: creatorIdentity
      ? {
          ...creatorIdentity,
          ...(room.host || {}),
          id: hostUserId,
          userId: hostUserId,
          agoraUid: hostAgoraUid,
          uid: hostAgoraUid,
          username: creatorIdentity.username,
          displayName: creatorIdentity.displayName,
          name: creatorIdentity.name,
          avatarUrl: creatorIdentity.avatarUrl,
        }
      : room.host || null,
    seats: enrichedSeats,
    members: enrichedMembers,
    participants,
    agoraUidMap,
  };
}

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    if (!adminId) return;
    const adminExists = await db.admin.findUnique({ where: { id: adminId } });
    if (!adminExists) return;

    await db.auditLog.create({
      data: {
        adminId,
        adminName: adminName || adminExists.name || 'System',
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
    // Non-blocking platform audit logging
  }
}

// In-process lock map to serialize concurrent session switching operations per user
const userSessionSwitchLocks = new Map();

export async function withUserSessionLock(userId, fn) {
  if (!userId) return await fn();
  while (userSessionSwitchLocks.has(userId)) {
    try {
      await userSessionSwitchLocks.get(userId);
    } catch (_) {}
  }
  let release;
  const lockPromise = new Promise((resolve) => { release = resolve; });
  userSessionSwitchLocks.set(userId, lockPromise);
  try {
    return await fn();
  } finally {
    userSessionSwitchLocks.delete(userId);
    if (release) release();
  }
}

/**
 * Handles a clean server-enforced exit when a user switches to another room or stream.
 * Releases ONLY the switching user's seat and removes ONLY them from presence.
 * Preserves the previous party room and other participants if any remain.
 * If 0 participants remain in the party room, marks it inactive immediately.
 */
export async function handleCleanExitFromPreviousRoom(userId, prevRoomId, newRoomId = null, db = prisma) {
  if (!userId || !prevRoomId) return;
  try {
    const prevRoom = await db.room.findUnique({
      where: { id: prevRoomId },
      select: { id: true, roomType: true, status: true, creatorUserId: true },
    });
    if (!prevRoom) return;

    // Release any seat user occupied in the previous room
    const occupiedSeat = await db.roomSeat.findFirst({
      where: { roomId: prevRoomId, occupiedUserId: userId },
    });
    if (occupiedSeat) {
      await db.roomSeat.update({
        where: { id: occupiedSeat.id },
        data: { occupiedUserId: null, isMuted: false, isMutedByModerator: false },
      });
      const seatPayload = { roomId: prevRoomId, seatIndex: occupiedSeat.seatIndex, userId };
      socketEmitter.emitToRoom(prevRoomId, 'room:seat_left', seatPayload);
      socketEmitter.emitToRoom(prevRoomId, 'seat:released', seatPayload);
    }

    // Leave presence and socket channel in previous room
    await presenceService.leaveRoomPresence(prevRoomId, userId);
    await socketEmitter.leaveUserSocketsFromRoom(userId, prevRoomId).catch(() => {});
    socketEmitter.emitToRoom(prevRoomId, 'room:member_left', { roomId: prevRoomId, userId });

    // Notify user socket of session termination elsewhere
    socketEmitter.emitToUser(userId, 'session:terminated_elsewhere', {
      previousRoomId: prevRoomId,
      newRoomId,
      reason: 'JOINED_ANOTHER_ROOM',
      message: 'Your previous session was ended because you joined another room.',
    });

    // Check remaining viewer count in previous room
    const remainingCount = await presenceService.getRoomViewerCount(prevRoomId, prevRoom.creatorUserId);
    const countPayload = {
      roomId: prevRoomId,
      clientRoomId: prevRoomId,
      viewerCount: remainingCount,
      count: remainingCount,
      currentViewersCount: remainingCount,
    };
    socketEmitter.emitToRoom(prevRoomId, 'room:viewer_count_changed', countPayload);
    socketEmitter.emitToRoom(prevRoomId, 'viewer_count_changed', countPayload);

    // If previous room is an AUDIO_PARTY room and 0 participants remain (host included), mark inactive immediately
    let remainingParticipants = 0;
    try {
      remainingParticipants = await getActiveRoomParticipantCount(prevRoomId, userId);
    } catch (_) {
      remainingParticipants = remainingCount;
    }
    if (prevRoom.roomType === 'AUDIO_PARTY' && remainingParticipants <= 0 && prevRoom.status === 'LIVE') {
      clearEmptyRoomSleepTimer(prevRoomId);
      await db.room.update({
        where: { id: prevRoomId },
        data: { status: 'ENDED', endedAt: new Date(), currentViewersCount: 0 },
      });
      socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CLOSED, {
        roomId: prevRoomId,
        status: 'ENDED',
        reason: 'ALL_PARTICIPANTS_LEFT',
      });
      socketEmitter.broadcastGlobal('room:closed', { roomId: prevRoomId, status: 'ENDED' });
    }
  } catch (err) {
    console.warn('[RoomService] Error cleaning exit from previous room:', err?.message);
  }
}

export async function createRoom(
  {
    userId,
    title,
    coverImageUrl,
    backgroundImageUrl,
    roomType,
    category,
    isPrivate,
    roomPin,
    forceNew = false,
    capacity,
    seatCapacity,
  },
  db = prisma
) {
  // 1. Any user can start live broadcast or audio party room freely without host registration requirement
  const hostProfile = await db.hostProfile.findUnique({
    where: { userId },
  });

  const isVideoLive = (roomType === 'LIVE_VIDEO');

  // Check if the user already has an existing AUDIO_PARTY room to resume/reactivate rather than recreating
  // Note: For AUDIO_PARTY, hosts have a persistent party room. Resuming or reopening reactivates status to LIVE
  // and retains today's gifts for daily sending rankings. LIVE_VIDEO always establishes a fresh session.
  if (!isVideoLive) {
    let existingRoom = null;
    try {
      existingRoom = await db.room.findFirst({
        where: {
          creatorUserId: userId,
          roomType: 'AUDIO_PARTY',
        },
        orderBy: { createdAt: 'desc' },
        include: {
          seats: {
            orderBy: { seatIndex: 'asc' },
          },
        },
      });
    } catch (err) {
      console.warn('[RoomService] Error querying existing party room:', err?.message);
    }

    if (existingRoom) {
      if (['CLOSED_BY_ADMIN', 'HOST_KICKED'].includes(existingRoom.status)) {
        const error = new Error('This room has been closed by administration and cannot be reopened.');
        error.statusCode = 403;
        error.code = 'ROOM_CLOSED_BY_ADMIN';
        throw error;
      }

      if (existingRoom.status !== 'LIVE' && existingRoom.status !== 'ENDED') {
        const error = new Error('Room cannot be opened from its current status');
        error.statusCode = 400;
        error.code = 'ROOM_NOT_AVAILABLE';
        throw error;
      }

      try {
        const wasSleeping = existingRoom.status === 'ENDED';
        clearHostAbsentTimer(existingRoom.id);
        clearEmptyRoomSleepTimer(existingRoom.id);
        const updateData = {};
        if (wasSleeping) {
          updateData.status = 'LIVE';
          updateData.endedAt = null;
          updateData.activeSessionId = crypto.randomUUID();
          updateData.sessionStartedAt = new Date();
        }
        if (title && typeof title === 'string' && title.trim() && title.trim() !== existingRoom.title) {
          updateData.title = title.trim();
        }
        if (coverImageUrl && typeof coverImageUrl === 'string' && coverImageUrl.trim() && coverImageUrl.trim() !== existingRoom.coverImageUrl) {
          updateData.coverImageUrl = coverImageUrl.trim();
        }
        if (backgroundImageUrl && typeof backgroundImageUrl === 'string' && backgroundImageUrl.trim() !== '' && backgroundImageUrl.trim() !== existingRoom.backgroundImageUrl) {
          updateData.backgroundImageUrl = backgroundImageUrl.trim();
        }
        if (category && category !== existingRoom.category) updateData.category = category;
        if (isPrivate !== undefined && isPrivate !== existingRoom.isPrivate) updateData.isPrivate = isPrivate;
        if (roomPin !== undefined && roomPin !== existingRoom.roomPin) updateData.roomPin = roomPin;

        if (Object.keys(updateData).length > 0) {
          await db.room.update({
            where: { id: existingRoom.id },
            data: updateData,
          });
        }

        // If capacity or seatCapacity was explicitly requested, update layout
        const requestedCap = parseInt(seatCapacity || capacity, 10);
        if (requestedCap && requestedCap >= 8 && requestedCap <= 30 && requestedCap !== existingRoom.seats.length) {
          await roomRepository.updateRoomLayoutTx({
            roomId: existingRoom.id,
            capacity: requestedCap,
            roomType: updateData.roomType || existingRoom.roomType,
          }, db);
        }

        // Ensure host is seated on Seat 0 if Seat 0 is currently unoccupied when reopening their party room
        try {
          const seat0 = (existingRoom.seats || []).find((s) => s.seatIndex === 0);
          if (seat0 && !seat0.occupiedUserId) {
            await db.roomSeat.update({
              where: { id: seat0.id },
              data: { occupiedUserId: userId, isMuted: false, isMutedByModerator: false },
            });
          }
        } catch (_) {}

        const refreshedRoom = await roomRepository.findRoomById(existingRoom.id, db);

        // Calculate authoritative session scores:
        // When reopening a sleeping room, session score starts strictly at 0.
        // When joining/resuming an awake room, session score preserves accumulated session gifts.
        const sessionScoreData = wasSleeping
          ? { sessionScore: 0, sessionId: updateData.activeSessionId, sessionStartedAt: updateData.sessionStartedAt?.toISOString() }
          : await getAuthoritativeRoomSessionScore(refreshedRoom.id, db);
        const sessionGiftCoins = sessionScoreData.sessionScore;

        let totalLikes = 0;
        try {
          totalLikes = await presenceService.getRoomLikes(refreshedRoom.id);
        } catch (_) {}

        const roomLevelData = await roomLevelService.getRoomLevelData(refreshedRoom.id, {}, db);
        const resumedPayload = {
          ...refreshedRoom,
          alreadyHasRoom: true,
          alreadyHadRoom: true,
          isExistingRoom: true,
          existingRoomId: refreshedRoom.id,
          wasSleeping,
          statusMessage: 'You already have a party room. Opening your existing room.',
          sessionId: refreshedRoom.activeSessionId || sessionScoreData.sessionId,
          sessionStartedAt: refreshedRoom.sessionStartedAt ? new Date(refreshedRoom.sessionStartedAt).toISOString() : sessionScoreData.sessionStartedAt,
          level: roomLevelData.level,
          roomLevel: roomLevelData.level,
          displayLevel: roomLevelData.displayLevel,
          roomDisplayLevel: roomLevelData.displayLevel,
          roomLevelProgress: roomLevelData,
          cumulativeRoomCoins: roomLevelData.cumulativeCoins,
          totalGifts: sessionGiftCoins,
          giftsReceivedCoins: sessionGiftCoins,
          roomSendingTotal: sessionGiftCoins,
          dailySendingTotal: sessionGiftCoins,
          periodTotalCoins: sessionGiftCoins,
          trophyCoins: sessionGiftCoins,
          dailyTrophyCoins: sessionGiftCoins,
          dailyTrophyDisplay: Number(sessionGiftCoins).toLocaleString('en-US'),
          trophyDisplay: Number(sessionGiftCoins).toLocaleString('en-US'),
          totalLikes,
          likesCount: totalLikes,
        };

        if (wasSleeping) {
          try {
            socketEmitter.broadcastGlobal('room:woke_up', resumedPayload);
            socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CREATED, resumedPayload);
            socketEmitter.broadcastGlobal('room:created', resumedPayload);
          } catch (_) {}
        }

        // Authoritatively set active session and subscribe host sockets to room channel
        await presenceService.setUserActiveSession(userId, {
          roomId: refreshedRoom.id,
          roomType: refreshedRoom.roomType,
          role: 'HOST',
          isHost: true,
          title: refreshedRoom.title,
        });
        await socketEmitter.joinUserSocketsToRoom(userId, refreshedRoom.id, refreshedRoom.creator).catch(() => {});

        return enrichRoomIdentitySnapshot(resumedPayload);
      } catch (resumeErr) {
        console.error('[RoomService] Error reopening existing room, returning safe existing payload:', resumeErr);
        const safeRoom = await roomRepository.findRoomById(existingRoom.id, db).catch(() => existingRoom);
        await presenceService.setUserActiveSession(userId, {
          roomId: existingRoom.id,
          roomType: existingRoom.roomType,
          role: 'HOST',
          isHost: true,
          title: existingRoom.title,
        }).catch(() => {});
        await socketEmitter.joinUserSocketsToRoom(userId, existingRoom.id, safeRoom?.creator).catch(() => {});
        return enrichRoomIdentitySnapshot({
          ...safeRoom,
          alreadyHasRoom: true,
          alreadyHadRoom: true,
          isExistingRoom: true,
          existingRoomId: existingRoom.id,
          wasSleeping: existingRoom.status !== 'LIVE',
          statusMessage: 'You already have a party room. Opening your existing room.',
        });
      }
    }
  }

  // If starting a camera LIVE_VIDEO broadcast, check if user is currently participating in a Party room
  if (isVideoLive) {
    try {
      const activeSeat = await db.roomSeat.findFirst({
        where: {
          occupiedUserId: userId,
          room: { status: 'LIVE', roomType: 'AUDIO_PARTY' },
        },
        include: { room: true },
      });
      const activePartyRoomId = activeSeat?.roomId || (await presenceService.getUserActiveRoom(userId));
      if (activePartyRoomId) {
        const partyRoom = activeSeat?.room || (await db.room.findUnique({ where: { id: activePartyRoomId } }));
        if (partyRoom && partyRoom.roomType === 'AUDIO_PARTY' && partyRoom.status === 'LIVE') {
          // Release ONLY switching user's seat, remove only them from presence, preserve party if others remain
          await handleCleanExitFromPreviousRoom(userId, activePartyRoomId, null, db);
          socketEmitter.emitToUser(userId, 'session:switched_to_live', {
            previousPartyRoomId: activePartyRoomId,
            reason: 'STARTED_LIVE_STREAM',
          });
        }
      }
    } catch (switchErr) {
      console.warn('[RoomService] Error transitioning from Party to Live:', switchErr?.message);
    }
  }

  // If forceNew is requested or starting a LIVE_VIDEO stream, only close lingering LIVE rooms of the same type
  try {
    const existingRooms = await db.room.findMany({
      where: {
        creatorUserId: userId,
        status: 'LIVE',
        ...(isVideoLive ? { roomType: 'LIVE_VIDEO' } : {}),
      },
      select: { id: true },
    });
    for (const er of existingRooms) {
      clearHostAbsentTimer(er.id);
      await presenceService.clearRoomLikes(er.id).catch(() => {});
      await presenceService.clearRoomPresence(er.id).catch(() => {});
      await db.room.update({
        where: { id: er.id },
        data: { status: 'ENDED', endedAt: new Date(), currentViewersCount: 0 },
      });
      socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CLOSED, {
        roomId: er.id,
        status: 'ENDED',
        reason: 'NEW_BROADCAST_CREATED',
      });
      socketEmitter.broadcastGlobal('room:closed', { roomId: er.id, status: 'ENDED' });
      socketEmitter.broadcastGlobal('room:deleted', { roomId: er.id });
    }
  } catch (err) {
    console.warn('[RoomService] Error auto-closing previous rooms:', err?.message);
  }

  const agoraChannelName = `room_${crypto.randomUUID().replace(/-/g, '')}`;

  const room = await roomRepository.createRoomWithSeats(
    {
      creatorUserId: userId,
      title,
      coverImageUrl,
      backgroundImageUrl: backgroundImageUrl && typeof backgroundImageUrl === 'string' && backgroundImageUrl.trim() ? backgroundImageUrl.trim() : null,
      roomType,
      category,
      isPrivate,
      roomPin,
      agoraChannelName,
      capacity: parseInt(seatCapacity || capacity, 10) || 10,
      seatCapacity: parseInt(seatCapacity || capacity, 10) || 10,
    },
    db
  );

  // Clear any residual Redis state for the new room ID to guarantee clean zero start
  await presenceService.clearRoomLikes(room.id).catch(() => {});
  await presenceService.clearRoomPresence(room.id).catch(() => {});

  const freshRoomProgression = roomLevelService.calculateRoomProgression(0);
  const freshSessionScores = {
    level: 0,
    roomLevel: 0,
    displayLevel: 'LV.0',
    roomDisplayLevel: 'LV.0',
    roomLevelProgress: freshRoomProgression,
    cumulativeRoomCoins: 0,
    totalGifts: 0,
    giftsReceivedCoins: 0,
    roomSendingTotal: 0,
    dailySendingTotal: 0,
    periodTotalCoins: 0,
    trophyCoins: 0,
    totalLikes: 0,
    likesCount: 0,
    sessionId: room.activeSessionId || null,
    sessionStartedAt: room.sessionStartedAt ? new Date(room.sessionStartedAt).toISOString() : null,
  };

  const newRoomPayload = enrichRoomIdentitySnapshot({
    ...room,
    ...freshSessionScores,
  });

  // Broadcast new room creation to global realtime discovery subscribers
  try {
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CREATED, newRoomPayload);
    socketEmitter.broadcastGlobal('room:created', newRoomPayload);
    socketEmitter.broadcastGlobal('room_created', newRoomPayload);
    socketEmitter.broadcastGlobal('room:started', newRoomPayload);
  } catch (err) {
    console.error('Failed to broadcast ROOM_CREATED socket event:', err);
  }

  // Authoritatively set active session and subscribe host sockets to room channel
  await presenceService.setUserActiveSession(userId, {
    roomId: room.id,
    roomType: room.roomType,
    role: 'HOST',
    isHost: true,
    title: room.title,
  });
  await socketEmitter.joinUserSocketsToRoom(userId, room.id, newRoomPayload.creator).catch(() => {});

  return newRoomPayload;
}

export async function getMyPartyRoom(userId, db = prisma) {
  if (!userId) {
    return { hasRoom: false, alreadyHasRoom: false, room: null };
  }
  const existingRoom = await db.room.findFirst({
    where: {
      creatorUserId: userId,
      roomType: 'AUDIO_PARTY',
    },
    orderBy: { createdAt: 'desc' },
    select: { id: true, status: true },
  });

  if (!existingRoom) {
    return { hasRoom: false, alreadyHasRoom: false, room: null };
  }

  const roomDetails = await getRoomDetails(existingRoom.id, db);
  const isSleeping = existingRoom.status !== 'LIVE';
  if (!isSleeping) {
    await socketEmitter.joinUserSocketsToRoom(userId, existingRoom.id, roomDetails?.creator).catch(() => {});
  }
  return {
    hasRoom: true,
    alreadyHasRoom: true,
    isExistingRoom: true,
    existingRoomId: existingRoom.id,
    isSleeping,
    sleepState: isSleeping ? 'SLEEPING' : 'ACTIVE',
    message: 'You already have an existing party room.',
    room: {
      ...roomDetails,
      alreadyHasRoom: true,
      isExistingRoom: true,
      isSleeping,
    },
  };
}

export async function getActiveRooms(filters, db = prisma) {
  const result = await roomRepository.findActiveRooms(filters, db);
  if (result && Array.isArray(result.rooms)) {
    result.rooms = result.rooms.map((r) => enrichRoomIdentitySnapshot(r));
  }
  return result;
}

export async function cleanupStaleRooms(db = prisma) {
  try {
    const cutoff = new Date(Date.now() - 4 * 60 * 60 * 1000); // 4 hours of inactivity
    // Query candidate stale rooms using valid Room fields and relation activity filters:
    // 1. Room is currently LIVE with 0 viewers
    // 2. Room was created > 4 hours ago (createdAt < cutoff)
    // 3. No seat was updated within the last 4 hours (seats.none.updatedAt >= cutoff)
    // 4. No gift was sent within the last 4 hours (giftTransactions.none.createdAt >= cutoff)
    const candidateStaleRooms = await db.room.findMany({
      where: {
        status: 'LIVE',
        createdAt: { lt: cutoff },
        currentViewersCount: { lte: 0 },
        seats: {
          none: {
            OR: [
              { updatedAt: { gte: cutoff } },
              { occupiedUserId: { not: null } },
            ],
          },
        },
        giftTransactions: {
          none: {
            createdAt: { gte: cutoff },
          },
        },
      },
      select: { id: true, roomType: true },
    });

    const staleIds = [];
    for (const r of candidateStaleRooms) {
      const activeCount = await getActiveRoomParticipantCount(r.id, null, db);
      if (activeCount <= 0) {
        staleIds.push(r.id);
      }
    }

    if (staleIds.length > 0) {
      await db.room.updateMany({
        where: { id: { in: staleIds } },
        data: {
          status: 'ENDED',
          endedAt: new Date(),
          currentViewersCount: 0,
        },
      });
      console.log(`[RoomService] Cleaned up ${staleIds.length} stale empty live rooms.`);
    }
    const staleRooms = staleIds;

    // Immediately close any dummy/test/verification rooms left LIVE from automated test runs
    // Phase 4: Only clean up rooms confirmed to be automated test data using reliable metadata
    const dummyRooms = await db.room.findMany({
      where: {
        status: 'LIVE',
        OR: [
          { title: { startsWith: 'Bug ', mode: 'insensitive' } },
          { title: { startsWith: 'Test ', mode: 'insensitive' } },
          { title: { contains: 'Verification Room', mode: 'insensitive' } },
          { title: { startsWith: 'Concurrent Room Attempt', mode: 'insensitive' } },
          { title: { startsWith: 'Room B - Owned by User B', mode: 'insensitive' } },
          { title: { startsWith: 'Room C Attempt', mode: 'insensitive' } },
          { title: { startsWith: 'Live Host Solo Broadcast', mode: 'insensitive' } },
          { title: { startsWith: 'Audio Host Party Room', mode: 'insensitive' } },
          { title: { startsWith: 'Co-Host Visibility Test Room', mode: 'insensitive' } },
          { title: { startsWith: 'Timer Test Room', mode: 'insensitive' } },
          { title: { startsWith: 'Room A - Second Room Attempt', mode: 'insensitive' } },
          { title: { contains: 'Isolation Test', mode: 'insensitive' } },
          { id: { startsWith: 'timer_room_' } },
          { id: { startsWith: 'room_ch_' } },
          { creatorUserId: { startsWith: 'bug' } },
          { creatorUserId: { startsWith: 'test_' } },
          { creatorUserId: { startsWith: 'user_concurrent_' } },
          { creatorUserId: { startsWith: 'user_owner_' } },
        ],
      },
      select: { id: true },
    });
    if (dummyRooms.length > 0) {
      const dummyIds = dummyRooms.map((r) => r.id);
      await db.room.updateMany({
        where: { id: { in: dummyIds } },
        data: {
          status: 'ENDED',
          endedAt: new Date(),
          currentViewersCount: 0,
        },
      });
      console.log(`[RoomService] Cleaned up ${dummyRooms.length} dummy/test rooms.`);
    }

    // Also close any orphaned room whose creator no longer exists
    const liveRooms = await db.room.findMany({
      where: { status: 'LIVE' },
      select: { id: true, creatorUserId: true },
    });
    const userIds = liveRooms.map((r) => r.creatorUserId);
    const existingUsers = await db.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true },
    });
    const existingSet = new Set(existingUsers.map((u) => u.id));
    const orphaned = liveRooms.filter((r) => !existingSet.has(r.creatorUserId));
    if (orphaned.length > 0) {
      const orphanedIds = orphaned.map((r) => r.id);
      await db.room.updateMany({
        where: { id: { in: orphanedIds } },
        data: {
          status: 'ENDED',
          endedAt: new Date(),
          currentViewersCount: 0,
        },
      });
      console.log(`[RoomService] Cleaned up ${orphaned.length} orphaned live rooms.`);
    }

    return { cleanedCount: staleRooms.length + orphaned.length };
  } catch (err) {
    console.warn('[RoomService] Cleanup stale rooms warning:', err?.message);
    return { error: err?.message };
  }
}

export async function getRoomDetails(roomId, db = prisma) {
  let room = await roomRepository.findRoomById(roomId, db);

  // If room wasn't found by ID, check if roomId is a host's userId who has an active or sleeping Party Room
  if (!room && roomId) {
    const activeRoomByUser = await db.room.findFirst({
      where: {
        creatorUserId: roomId,
        OR: [
          { status: 'LIVE' },
          { roomType: 'AUDIO_PARTY', status: { in: ['LIVE', 'ENDED'] } },
        ],
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });
    if (activeRoomByUser) {
      room = await roomRepository.findRoomById(activeRoomByUser.id, db);
    }
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Calculate real-time viewer count
  let viewerCount = typeof room.currentViewersCount === 'number' ? room.currentViewersCount : 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number' && presCount >= 0) {
      viewerCount = Math.max(viewerCount, presCount);
    }
  } catch (_) {}

  // Calculate gift coin total from transactions for authoritative active session
  const sessionScoreData = await getAuthoritativeRoomSessionScore(room.id, db);
  const sessionGiftCoins = sessionScoreData.sessionScore;

  // Check if any seats are muted to determine room-level mute flag
  const isRoomMuted = Array.isArray(room.seats) && room.seats.length > 0 && room.seats.every((s) => s.isMuted);

  const hasPin = Boolean(room.roomPin);
  const lockMode = hasPin ? 'PIN' : (room.isPrivate ? 'Approval' : 'NONE');
  const { roomPin: _confidentialPin, ...safeRoom } = room;

  let peakViewers = 0;
  try {
    peakViewers = await presenceService.getRoomPeakViewers(room.id);
  } catch (_) {}

  let totalLikes = 0;
  try {
    totalLikes = await presenceService.getRoomLikes(room.id);
  } catch (_) {}

  let activePresenceUsers = [];
  try {
    activePresenceUsers = await presenceService.getRoomActiveUsers(room.id);
  } catch (_) {}

  const isSleeping = room.status !== 'LIVE';
  const isParty = isPartyRoomType(room.roomType);
  const roomLevelData = await roomLevelService.getRoomLevelData(room.id, {}, db);
  return enrichRoomIdentitySnapshot(
    {
      ...safeRoom,
      status: isParty && room.status !== 'CLOSED_BY_ADMIN' ? 'LIVE' : room.status,
      dbStatus: room.status,
      level: roomLevelData.level,
      roomLevel: roomLevelData.level,
      displayLevel: roomLevelData.displayLevel,
      roomDisplayLevel: roomLevelData.displayLevel,
      roomLevelProgress: roomLevelData,
      cumulativeRoomCoins: roomLevelData.cumulativeCoins,
      isSleeping,
      sleepState: isSleeping ? 'SLEEPING' : 'ACTIVE',
      currentViewersCount: viewerCount,
      viewerCount,
      count: viewerCount,
      peakViewers: peakViewers > 0 ? peakViewers : viewerCount,
      backgroundImageUrl: room.backgroundImageUrl || null,
      background: room.backgroundImageUrl || null,
      themeUrl: room.backgroundImageUrl || null,
      theme: room.backgroundImageUrl || null,
      giftsReceivedCoins: sessionGiftCoins,
      totalGifts: sessionGiftCoins,
      roomSendingTotal: sessionGiftCoins,
      dailySendingTotal: sessionGiftCoins,
      periodTotalCoins: sessionGiftCoins,
      trophyCoins: sessionGiftCoins,
      dailyTrophyCoins: sessionGiftCoins,
      dailyTrophyDisplay: Number(sessionGiftCoins).toLocaleString('en-US'),
      trophyDisplay: Number(sessionGiftCoins).toLocaleString('en-US'),
      sessionId: sessionScoreData.sessionId,
      sessionStartedAt: sessionScoreData.sessionStartedAt,
      totalLikes,
      likesCount: totalLikes,
      seatCapacity: (room.seats || []).length || 10,
      capacity: (room.seats || []).length || 10,
      isLocked: Boolean(room.isPrivate),
      lockMode,
      isMuted: isRoomMuted,
    },
    activePresenceUsers
  );
}

export async function joinRoom(roomId, userId, { pin = null, isApproved = false, attemptId = null, isVisitor = false, explicit = false } = {}, db = prisma) {
  if (userId) {
    // 1. Check if user is currently hosting an active LIVE broadcast
    const activeLive = await db.room.findFirst({
      where: {
        creatorUserId: userId,
        status: 'LIVE',
        roomType: 'LIVE_VIDEO',
        id: { not: roomId },
      },
      select: { id: true, title: true },
    });
    if (activeLive) {
      const error = new Error('You are currently hosting a Live broadcast. Please confirm ending your broadcast to switch.');
      error.statusCode = 409;
      error.code = 'ACTIVE_LIVE_HOSTING_EXISTS';
      error.activeLiveId = activeLive.id;
      throw error;
    }

    // 2. Check if user has an active session in another room (enforce single active session)
    const prevRoomId = await presenceService.getUserActiveRoom(userId);
    if (prevRoomId && prevRoomId !== roomId) {
      await handleCleanExitFromPreviousRoom(userId, prevRoomId, roomId, db);
    }
  }

  const result = await roomRepository.joinRoomTx({ roomId, userId, pin, isApproved, attemptId, isVisitor, explicit }, db);
  if (result) {
    if (userId) {
      await presenceService.setUserActiveSession(userId, {
        roomId: result.id || roomId,
        roomType: result.roomType || 'AUDIO_PARTY',
        role: result.creatorUserId === userId ? 'HOST' : 'VIEWER',
        isHost: result.creatorUserId === userId,
        title: result.title,
      });
    }
    try {
      clearEmptyRoomSleepTimer(result.id || roomId);
    } catch (_) {}
    if (result.creatorUserId === userId) {
      try {
        clearHostAbsentTimer(result.id);
        await attendanceService.startBroadcastSession({
          roomId: result.id,
          hostUserId: userId,
          roomType: result.roomType || 'AUDIO_PARTY',
        }, db).catch(() => {});
      } catch (_) {}
    }
    if (result.wokeFromSleep) {
      try {
        socketEmitter.broadcastGlobal('room:woke_up', result);
        socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CREATED, result);
        socketEmitter.broadcastGlobal('room:created', result);
      } catch (_) {}
    }
    let viewerCount = typeof result.currentViewersCount === 'number' ? result.currentViewersCount : 0;
    try {
      const presCount = await presenceService.getRoomViewerCount(result.id || roomId, result.creatorUserId);
      if (typeof presCount === 'number' && presCount >= 0) {
        viewerCount = Math.max(viewerCount, presCount);
      }
    } catch (_) {}

    const payload = {
      roomId: result.id || roomId,
      clientRoomId: roomId,
      viewerCount,
      count: viewerCount,
      currentViewersCount: viewerCount,
    };
    try {
      socketEmitter.emitToRoom(roomId, 'room:viewer_count_changed', payload);
      socketEmitter.emitToRoom(roomId, 'room:viewer_count', payload);
      socketEmitter.emitToRoom(roomId, 'viewer_count_changed', payload);
      if (result.id && result.id !== roomId) {
        socketEmitter.emitToRoom(result.id, 'room:viewer_count_changed', payload);
        socketEmitter.emitToRoom(result.id, 'room:viewer_count', payload);
        socketEmitter.emitToRoom(result.id, 'viewer_count_changed', payload);
      }
    } catch (_) {}

    // Attach authoritative session-isolated gift, trophy, and like metrics
    const sessionScoreData = await getAuthoritativeRoomSessionScore(result.id || roomId, db);
    const sessionGiftCoins = sessionScoreData.sessionScore;

    let totalLikes = 0;
    try {
      totalLikes = await presenceService.getRoomLikes(result.id || roomId);
    } catch (_) {}

    result.totalGifts = sessionGiftCoins;
    result.giftsReceivedCoins = sessionGiftCoins;
    result.roomSendingTotal = sessionGiftCoins;
    result.dailySendingTotal = sessionGiftCoins;
    result.periodTotalCoins = sessionGiftCoins;
    result.trophyCoins = sessionGiftCoins;
    result.sessionId = sessionScoreData.sessionId;
    result.sessionStartedAt = sessionScoreData.sessionStartedAt;
    result.totalLikes = totalLikes;
    result.likesCount = totalLikes;

    if (userId) {
      await socketEmitter.joinUserSocketsToRoom(userId, result.id || roomId).catch(() => {});
    }
    if (result.creatorUserId) {
      await socketEmitter.joinUserSocketsToRoom(result.creatorUserId, result.id || roomId).catch(() => {});
    }

    let activePresenceUsers = [];
    try {
      activePresenceUsers = await presenceService.getRoomActiveUsers(result.id || roomId);
    } catch (_) {}
    return enrichRoomIdentitySnapshot(result, activePresenceUsers);
  }
  return result;
}

export async function visitRoom(roomId, userId, options = {}, db = prisma) {
  return await joinRoom(roomId, userId, { ...options, isVisitor: true, explicit: false }, db);
}

export async function joinRoomMembership(roomId, userId, options = {}, db = prisma) {
  const result = await joinRoom(roomId, userId, { ...options, explicit: true, isVisitor: false }, db);
  if (result) {
    const payload = {
      roomId: result.id || roomId,
      userId,
      role: 'MEMBER',
      joinedAt: new Date().toISOString(),
      timestamp: new Date().toISOString(),
    };
    try {
      socketEmitter.emitToRoom(roomId, 'room:member_joined', payload);
      socketEmitter.emitToRoom(roomId, 'room:role_updated', payload);
    } catch (_) {}
  }
  return {
    success: true,
    room: result,
    data: result,
    ...result,
  };
}

export async function removeRoomMember(roomId, actorUserId, targetUserId, db = prisma) {
  const result = await roomRepository.removeRoomMemberTx({ roomId, actorUserId, targetUserId }, db);
  if (result) {
    const payload = {
      roomId,
      targetUserId,
      removedByUserId: actorUserId,
      timestamp: new Date().toISOString(),
    };
    try {
      socketEmitter.emitToRoom(roomId, 'room:member_removed', payload);
      socketEmitter.emitToUser(targetUserId, 'room:member_removed', payload);
    } catch (_) {}
  }
  return result;
}

export async function leaveRoom(roomId, userId, db = prisma) {
  try {
    await presenceService.clearUserActiveRoom(userId, roomId);
  } catch (_) {}
  const result = await roomRepository.leaveRoomTx({ roomId, userId }, db);
  const targetRoomId = result?.id || roomId;

  // Clear presence, socket room membership, and roomMember membership to prevent stale viewers
  try {
    await presenceService.leaveRoomPresence(targetRoomId, userId);
  } catch (_) {}
  try {
    await socketEmitter.leaveUserSocketsFromRoom(userId, targetRoomId);
    if (roomId && roomId !== targetRoomId) {
      await socketEmitter.leaveUserSocketsFromRoom(userId, roomId);
    }
  } catch (_) {}
  try {
    await db.roomMember.deleteMany({
      where: { roomId: targetRoomId, userId },
    });
  } catch (_) {}

  let viewerCount = typeof result?.currentViewersCount === 'number' ? result.currentViewersCount : 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(targetRoomId, result?.creatorUserId);
    if (typeof presCount === 'number' && presCount >= 0) {
      viewerCount = presCount;
    }
  } catch (_) {}

  const leftPayload = {
    roomId: targetRoomId,
    clientRoomId: roomId,
    userId,
    id: userId,
    viewerCount,
    count: viewerCount,
    currentViewersCount: viewerCount,
  };

  const countPayload = {
    roomId: targetRoomId,
    clientRoomId: roomId,
    viewerCount,
    count: viewerCount,
    currentViewersCount: viewerCount,
  };

  // If the leaving user is the host, immediately stop their personal BroadcastSession attendance clock
  if (result && result.creatorUserId === userId) {
    await attendanceService.endBroadcastSession({ roomId: targetRoomId, hostUserId: userId }, db).catch(() => {});
  }

  // Clear active session for the leaving user
  await presenceService.clearUserActiveSession(userId, targetRoomId);

  // If this is a Party Room, distinguish explicit departure from unexpected network drop:
  // - Explicit departure with 0 participants remaining: immediately mark inactive!
  // - If participants remain: room continues without interruption.
  // NOTE: `viewerCount` above intentionally excludes the host (it is the audience number shown
  // in the UI). It must NOT be used to decide whether the room is empty: when the last guest
  // leaves while the host is still inside it is 0, and the old code then marked the room ENDED
  // and broadcast `room:closed` to everyone, tearing down the host's session mid-party
  // (host stopped receiving joins/chat/gifts from later users).
  let sleepSchedule = { scheduled: false, activeCount: viewerCount };
  if (result && isPartyRoomType(result.roomType)) {
    let remainingParticipants = 0;
    try {
      remainingParticipants = await getActiveRoomParticipantCount(targetRoomId, userId);
    } catch (_) {
      remainingParticipants = viewerCount;
    }
    if (remainingParticipants <= 0) {
      // Truly empty (host included): put the room to sleep right away. Sleep keeps the room
      // joinable by its permanent ID and is announced as `room:sleeping`, never `room:closed`.
      clearEmptyRoomSleepTimer(targetRoomId);
      await attendanceService.endBroadcastSession({ roomId: targetRoomId }, db).catch(() => {});
      await presenceService.clearRoomPresence(targetRoomId).catch(() => {});
      await db.room.update({
        where: { id: targetRoomId },
        data: { status: 'ENDED', endedAt: new Date(), currentViewersCount: 0 },
      });
      const sleepPayload = {
        roomId: targetRoomId,
        clientRoomId: roomId,
        status: 'SLEEPING',
        dbStatus: 'ENDED',
        isSleeping: true,
        roomStaysOpen: true,
        currentViewersCount: 0,
        viewerCount: 0,
        reason: 'EXPLICIT_DEPARTURE_EMPTY',
        message: 'Room is now sleeping because no users are inside. Join by Room ID to wake it up.',
      };
      socketEmitter.broadcastGlobal('room:sleeping', sleepPayload);
      socketEmitter.broadcastGlobal('room:updated', sleepPayload);
      sleepSchedule = { scheduled: false, activeCount: 0, sleptImmediately: true };
    } else {
      sleepSchedule = await checkAndSchedulePartyRoomSleep(targetRoomId, null, 10000, userId);
    }
  }

  const targetIds = Array.from(new Set([String(roomId), String(targetRoomId)]));
  for (const rid of targetIds) {
    try {
      socketEmitter.emitToRoom(rid, 'room:user_left', leftPayload);
      socketEmitter.emitToRoom(rid, 'user_left', leftPayload);
      socketEmitter.emitToRoom(rid, 'user:left', leftPayload);
      socketEmitter.emitToRoom(rid, 'room_user_left', leftPayload);
      socketEmitter.emitToRoom(rid, 'room:viewer_count_changed', countPayload);
      socketEmitter.emitToRoom(rid, 'room:viewer_count', countPayload);
      socketEmitter.emitToRoom(rid, 'viewer_count_changed', countPayload);
    } catch (_) {}
  }

  return {
    ...result,
    roomStaysOpen: true,
    willSleepIfEmpty: sleepSchedule.scheduled,
    sleepAfterSeconds: sleepSchedule.scheduled ? 12 : null,
  };
}

export async function occupySeat(roomId, seatIndex, userId, db = prisma) {
  const res = await roomRepository.occupySeatTx({ roomId, seatIndex, userId }, db);
  const canonicalRoomId = res?.updatedSeat?.roomId || res?.roomId || roomId;
  if (userId && canonicalRoomId) {
    await socketEmitter.joinUserSocketsToRoom(userId, canonicalRoomId).catch(() => {});
  }
  return res;
}

export async function leaveSeat(roomId, seatIndex, userId, options = {}, db = prisma) {
  const force = typeof options === 'boolean' ? options : (options?.force || false);
  const targetDb = options && typeof options === 'object' && options.$transaction ? options : db;
  return await roomRepository.leaveSeatTx({ roomId, seatIndex, userId, force }, targetDb);
}

/**
 * Generates an authoritative session summary for a live broadcast.
 * Calculates duration from persisted createdAt and endedAt timestamps.
 * Calculates peak viewers from authoritative presence tracking.
 * Calculates gift earnings from the authoritative GiftTransaction ledger.
 */
export async function getLiveSessionSummary(roomId, db = prisma) {
  let room = await db.room.findUnique({
    where: { id: roomId },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: {
            select: {
              displayName: true,
            },
          },
        },
      },
    },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: {
              select: {
                displayName: true,
              },
            },
          },
        },
      },
    });
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const startedAt = room.createdAt;
  const endedAt = room.endedAt || new Date();
  const durationSeconds = Math.max(0, Math.floor((new Date(endedAt).getTime() - new Date(startedAt).getTime()) / 1000));

  const hours = Math.floor(durationSeconds / 3600);
  const minutes = Math.floor((durationSeconds % 3600) / 60);
  const seconds = durationSeconds % 60;
  const durationFormatted = hours > 0
    ? `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`
    : `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;

  // Authoritative peak viewers tracking
  const trackedPeak = await presenceService.getRoomPeakViewers(room.id);
  const hasAuthoritativePeak = typeof trackedPeak === 'number' && trackedPeak > 0;
  const peakViewers = hasAuthoritativePeak ? trackedPeak : 0;

  // Authoritative gift coins calculation from GiftTransaction ledger strictly for this session
  let totalGiftCoins = 0;
  let totalDiamonds = 0;
  let totalGiftsCount = 0;
  const sessionStart = room.createdAt ? new Date(room.createdAt) : null;
  const sessionWhere = {
    roomId: room.id,
    ...(sessionStart ? { createdAt: { gte: sessionStart } } : {}),
  };
  try {
    const giftAggr = await db.giftTransaction.aggregate({
      where: sessionWhere,
      _sum: {
        totalCoins: true,
        hostDiamonds: true,
        giftCount: true,
      },
    });
    totalGiftCoins = Number(giftAggr._sum.totalCoins || 0);
    totalDiamonds = Number(giftAggr._sum.hostDiamonds || 0);
    totalGiftsCount = Number(giftAggr._sum.giftCount || 0);
  } catch (err) {
    console.warn(`[RoomService] Failed to aggregate gift ledger for room ${room.id}:`, err?.message);
  }

  // Top 3 contributors during this session
  let topContributors = [];
  try {
    const topGifters = await db.giftTransaction.groupBy({
      by: ['senderUserId'],
      where: sessionWhere,
      _sum: { totalCoins: true },
      orderBy: { _sum: { totalCoins: 'desc' } },
      take: 3,
    });

    if (topGifters.length > 0) {
      const userIds = topGifters.map((g) => g.senderUserId);
      const users = await db.user.findMany({
        where: { id: { in: userIds } },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: { select: { displayName: true } },
        },
      });
      const userMap = new Map(users.map((u) => [u.id, u]));

      topContributors = topGifters.map((g) => {
        const u = userMap.get(g.senderUserId);
        return {
          userId: g.senderUserId,
          coins: Number(g._sum.totalCoins || 0),
          username: u?.username || 'Unknown',
          displayName: u?.profile?.displayName || u?.username || 'Gifter',
          avatarUrl: u?.avatarUrl || null,
        };
      });
    }
  } catch (_) {}

  return {
    roomId: room.id,
    roomTitle: room.title,
    roomType: room.roomType,
    hostUserId: room.creatorUserId,
    hostUsername: room.creator?.username || null,
    hostDisplayName: room.creator?.profile?.displayName || room.creator?.username || null,
    hostAvatarUrl: room.creator?.avatarUrl || null,
    status: room.status,
    startedAt: startedAt.toISOString(),
    endedAt: (room.endedAt || endedAt).toISOString(),
    durationSeconds,
    durationFormatted,
    peakViewers,
    hasAuthoritativePeak,
    peakViewersNote: hasAuthoritativePeak
      ? null
      : 'Historical peak concurrent viewers was not tracked for this session.',
    totalGiftCoins,
    totalDiamonds,
    totalGiftsCount,
    topContributors,
  };
}

export async function closeMyRoom(roomId, userId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  if (room.creatorUserId !== userId) {
    const error = new Error('Only the room creator can close this room');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Persistent Party Room Lifecycle:
  // When the host exits a Party Room (AUDIO_PARTY / VIDEO_PARTY), only the host leaves the room.
  // Remaining users stay inside uninterrupted; the room goes to sleep 12 seconds after the last user leaves.
  if (isPartyRoomType(room.roomType)) {
    await attendanceService.endBroadcastSession({ roomId: room.id, hostUserId: userId }, db).catch(() => {});
    const leaveResult = await leaveRoom(room.id, userId, db);
    const summary = await getLiveSessionSummary(room.id, db).catch(() => null);

    if (typeof leaveResult?.vacatedSeatIndex === 'number') {
      try {
        await stageService.notifyStageReleased({
          roomId: room.id,
          seatIndex: Number(leaveResult.vacatedSeatIndex),
          userId,
          releasedByUserId: userId,
          reason: 'HOST_LEFT_ROOM',
        });
      } catch (_) {}
    }

    const hostLeftPayload = {
      roomId: room.id,
      userId,
      status: 'LIVE',
      reason: 'HOST_LEFT',
      roomStaysOpen: true,
      message: 'Host has left the room. Party continues for remaining members.',
    };
    socketEmitter.emitToRoom(room.id, 'room:host_away', hostLeftPayload);
    socketEmitter.emitToRoom(room.id, 'room:host_left', hostLeftPayload);

    const sleepCheck = await checkAndSchedulePartyRoomSleep(room.id, null, 10000, userId);

    return {
      ...leaveResult,
      status: 'LIVE',
      hostLeftOnly: true,
      roomStaysOpen: true,
      willSleepIfEmpty: sleepCheck.scheduled,
      sleepAfterSeconds: sleepCheck.scheduled ? 10 : null,
      summary,
    };
  }

  // Solo LIVE_VIDEO stream: ends immediately for all viewers when broadcaster ends stream
  clearHostAbsentTimer(roomId);
  micInviteService.clearAllInvitesForRoom(roomId);
  await attendanceService.endBroadcastSession({ roomId, hostUserId: userId }, db).catch(() => {});
  await presenceService.clearRoomLikes(roomId);
  await presenceService.clearRoomPresence(roomId).catch(() => {});
  const closedRoom = await roomRepository.closeRoomTx({ roomId, status: 'ENDED' }, db);
  const summary = await getLiveSessionSummary(roomId, db);

  const closePayload = {
    roomId,
    status: 'ENDED',
    reason: 'HOST_CLOSED',
    summary,
  };

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, closePayload);
  socketEmitter.broadcastGlobal('room:closed', closePayload);
  await socketEmitter.clearRoomSockets(roomId).catch(() => {});

  return {
    ...closedRoom,
    summary,
  };
}

export async function listRoomsForAdmin(filters, db = prisma) {
  const result = await roomRepository.findAdminRooms(filters, db);
  if (result && Array.isArray(result.rooms)) {
    result.rooms = result.rooms.map((r) => enrichRoomIdentitySnapshot(r));
  }
  return result;
}

export async function adminPinRoom(
  roomId,
  { pinnedPosition = 1, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const beforeState = { isPinnedTop: room.isPinnedTop, pinnedPosition: room.pinnedPosition };
  const updatedRoom = await roomRepository.pinRoom({ roomId, isPinnedTop: true, pinnedPosition }, db);
  const afterState = { isPinnedTop: updatedRoom.isPinnedTop, pinnedPosition: updatedRoom.pinnedPosition };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_PINNED_TOP',
      targetEntity: 'Room',
      targetEntityId: roomId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason: `Pinned at position ${pinnedPosition}`,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_PINNED, {
    roomId,
    isPinnedTop: true,
    pinnedPosition,
  });
  socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_PINNED, {
    roomId,
    isPinnedTop: true,
    pinnedPosition,
  });

  return updatedRoom;
}

export async function adminUnpinRoom(
  roomId,
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const beforeState = { isPinnedTop: room.isPinnedTop, pinnedPosition: room.pinnedPosition };
  const updatedRoom = await roomRepository.pinRoom({ roomId, isPinnedTop: false, pinnedPosition: null }, db);
  const afterState = { isPinnedTop: false, pinnedPosition: null };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_UNPINNED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_UNPINNED, {
    roomId,
    isPinnedTop: false,
    pinnedPosition: null,
  });
  socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_UNPINNED, {
    roomId,
    isPinnedTop: false,
    pinnedPosition: null,
  });

  return updatedRoom;
}

export async function adminGetPinnedPositions(db = prisma) {
  const pinnedRooms = await db.room.findMany({
    where: { isPinnedTop: true },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: { select: { displayName: true } },
        },
      },
    },
    orderBy: { pinnedPosition: 'asc' },
  });

  const positions = [1, 2, 3].map((pos) => {
    const match = pinnedRooms.find((r) => r.pinnedPosition === pos);
    return {
      position: pos,
      isOccupied: !!match,
      room: match
        ? {
            id: match.id,
            title: match.title,
            roomType: match.roomType,
            status: match.status,
            country: match.country || match.creator?.country || 'Global',
            pinnedPosition: match.pinnedPosition,
            owner: {
              userId: match.creator?.id,
              username: match.creator?.username,
              displayName: match.creator?.profile?.displayName || match.creator?.username,
              avatarUrl: match.creator?.avatarUrl,
            },
          }
        : null,
    };
  });

  return {
    totalPinned: pinnedRooms.length,
    maxPositions: 3,
    positions,
  };
}

export async function adminCloseRoom(
  roomId,
  { reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const beforeState = { status: room.status };
  await presenceService.clearRoomLikes(roomId).catch(() => {});
  await presenceService.clearRoomPresence(roomId).catch(() => {});
  const updatedRoom = await roomRepository.closeRoomTx({ roomId, status: 'CLOSED_BY_ADMIN' }, db);
  const afterState = { status: 'CLOSED_BY_ADMIN' };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_CLOSED_BY_ADMIN',
      targetEntity: 'Room',
      targetEntityId: roomId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason,
      ipAddress,
    },
    db
  );

  const summary = await getLiveSessionSummary(roomId, db);
  const closePayload = {
    roomId,
    status: 'CLOSED_BY_ADMIN',
    reason,
    summary,
  };

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, closePayload);
  socketEmitter.broadcastGlobal('room:closed', closePayload);
  await socketEmitter.clearRoomSockets(roomId).catch(() => {});

  return {
    ...updatedRoom,
    summary,
  };
}

export async function adminIssueWarning(
  roomId,
  { reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const payload = {
    roomId,
    roomTitle: room.title,
    message: reason || 'Community Guidelines Violation Warning',
    reason: reason || 'Community Guidelines Violation Warning',
    adminName: adminName || 'Admin Moderation',
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_WARNING_ISSUED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: reason || 'Official moderation warning broadcasted',
      ipAddress,
    },
    db
  );

  // Broadcast to room and global
  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_WARNING_ISSUED, payload);
  socketEmitter.emitToRoom(roomId, 'room:warning', payload);
  socketEmitter.emitToRoom(roomId, 'room_warning', payload);
  socketEmitter.broadcastGlobal('room:warning', payload);
  socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_WARNING_ISSUED, payload);

  return { success: true, message: 'Warning broadcasted successfully', data: payload };
}

export async function adminToggleRoomMute(
  roomId,
  { isMuted, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const updatedRoom = await roomRepository.updateRoomMuteStatus({ roomId, isMuted }, db);

  const payload = {
    roomId,
    isMuted: Boolean(isMuted),
    adminName: adminName || 'Admin Moderation',
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: isMuted ? 'ROOM_MUTED' : 'ROOM_UNMUTED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: isMuted ? 'Room audio muted by admin' : 'Room audio unmuted by admin',
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_MUTED, payload);
  socketEmitter.emitToRoom(roomId, 'room:muted', payload);
  socketEmitter.broadcastGlobal('room:muted', payload);

  return { success: true, isMuted: Boolean(isMuted), room: updatedRoom };
}

export async function adminMuteParticipant(
  roomId,
  { targetUserId, seatIndex, isMuted, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const parsedSeatIndex = (seatIndex !== undefined && seatIndex !== null && seatIndex !== '') ? Number(seatIndex) : null;

  if (parsedSeatIndex !== null) {
    await roomRepository.updateSeatMuteStatus({ roomId, seatIndex: parsedSeatIndex, isMuted }, db);
  }
  if (targetUserId) {
    await roomRepository.updateUserSeatMuteStatus({ roomId, userId: targetUserId, isMuted }, db);
  }

  const payload = {
    roomId,
    targetUserId: targetUserId || null,
    seatIndex: parsedSeatIndex,
    isMuted: Boolean(isMuted),
    adminName: adminName || 'Admin Moderation',
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: isMuted ? 'PARTICIPANT_MUTED' : 'PARTICIPANT_UNMUTED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: `Participant ${targetUserId || parsedSeatIndex} ${isMuted ? 'muted' : 'unmuted'} by admin`,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_MUTED, payload);
  socketEmitter.emitToRoom(roomId, 'room:user_muted', payload);
  if (targetUserId) {
    socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_MUTED, payload);
    socketEmitter.emitToUser(targetUserId, 'room:user_muted', payload);
  }
  socketEmitter.broadcastGlobal('room:user_muted', payload);

  return { success: true, data: payload };
}

export async function adminKickUser(
  roomId,
  { targetUserId, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isHost = room.creatorUserId === targetUserId;

  if (isHost) {
    // If the host is kicked, close the stream
    await roomRepository.closeRoomTx({ roomId, status: 'HOST_KICKED' }, db);

    const kickPayload = {
      roomId,
      targetUserId,
      kickedByUserId: adminId || 'admin',
      isHost: true,
      reason: reason || 'Host removed by platform moderation',
      timestamp: new Date().toISOString(),
    };

    socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
    socketEmitter.emitToRoom(roomId, 'room:user_kicked', kickPayload);
    socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
    socketEmitter.emitToUser(targetUserId, 'room:user_kicked', kickPayload);
    socketEmitter.broadcastGlobal('room:user_kicked', kickPayload);

    const summary = await getLiveSessionSummary(roomId, db).catch(() => null);
    const closePayload = {
      roomId,
      status: 'ENDED',
      reason: 'HOST_KICKED_BY_ADMIN',
      summary,
    };
    socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, closePayload);
    socketEmitter.broadcastGlobal('room:closed', closePayload);
    await socketEmitter.clearRoomSockets(roomId).catch(() => {});

    await logAudit(
      {
        adminId,
        adminName,
        action: 'HOST_KICKED_ROOM_CLOSED',
        targetEntity: 'Room',
        targetEntityId: roomId,
        reason: `Host ${targetUserId} kicked by admin moderation: ${reason || 'Violation'}`,
        ipAddress,
      },
      db
    );

    return { success: true, message: 'Host kicked and room closed', isHost: true };
  }

  // Regular participant/speaker/viewer
  await roomRepository.kickUserFromRoomTx({ roomId, targetUserId }, db);
  await socketEmitter.leaveUserSocketsFromRoom(targetUserId, roomId).catch(() => {});

  const kickPayload = {
    roomId,
    targetUserId,
    kickedByUserId: adminId || 'admin',
    isHost: false,
    reason: reason || 'Participant removed by platform moderation',
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToRoom(roomId, 'room:user_kicked', kickPayload);
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToUser(targetUserId, 'room:user_kicked', kickPayload);
  socketEmitter.broadcastGlobal('room:user_kicked', kickPayload);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'PARTICIPANT_KICKED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: `Participant ${targetUserId} kicked by admin: ${reason || 'Violation'}`,
      ipAddress,
    },
    db
  );

  return { success: true, message: 'Participant kicked successfully', isHost: false };
}

export async function adminUpdateRoomDp(
  roomId,
  { coverImageUrl, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const updatedRoom = await roomRepository.updateRoomCoverImage({ roomId, coverImageUrl }, db);

  const payload = {
    roomId,
    coverImageUrl,
    dpDeleted: !coverImageUrl,
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: coverImageUrl ? 'ROOM_DP_UPDATED' : 'ROOM_DP_DELETED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: coverImageUrl ? 'Room display picture updated by admin' : 'Room display picture removed by admin',
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_DP_UPDATED, payload);
  socketEmitter.emitToRoom(roomId, 'room:dp_updated', payload);

  return updatedRoom;
}

export async function getRoomMembers(roomId, { search, page = 1, limit = 50, onlyActive = false } = {}, db = prisma) {
  let room = await db.room.findUnique({
    where: { id: roomId },
    include: {
      creator: {
        include: { profile: true },
      },
      seats: true,
    },
  });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      include: {
        creator: {
          include: { profile: true },
        },
        seats: true,
      },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const resolvedRoomId = room.id;

  // Active socket presence
  let activePresence = [];
  let activePresenceUserIds = new Set();
  try {
    activePresence = await presenceService.getRoomActiveUsers(resolvedRoomId);
    activePresenceUserIds = new Set(activePresence.map((p) => p.userId || p.id).filter(Boolean));
  } catch (_) {}

  // Current mic seats map
  const seatedUserMap = new Map();
  if (Array.isArray(room.seats)) {
    for (const seat of room.seats) {
      if (seat.occupiedUserId) {
        seatedUserMap.set(seat.occupiedUserId, {
          seatIndex: seat.seatIndex,
          isMuted: Boolean(seat.isMuted || seat.isMutedByModerator),
        });
      }
    }
  }

  // Load all durable saved room members
  // If search query is provided, search across full saved roster
  const where = {
    roomId: resolvedRoomId,
  };

  const cleanSearch = typeof search === 'string' ? search.trim() : '';
  if (cleanSearch) {
    where.OR = [
      { userId: { equals: cleanSearch } },
      { userId: { contains: cleanSearch, mode: 'insensitive' } },
      { user: { username: { contains: cleanSearch, mode: 'insensitive' } } },
      { user: { profile: { displayName: { contains: cleanSearch, mode: 'insensitive' } } } },
    ];
  }

  const rawMembers = await db.roomMember.findMany({
    where,
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          lastLoginAt: true,
          updatedAt: true,
          profile: {
            select: {
              displayName: true,
              level: true,
              vipLevel: true,
              svipLevel: true,
              nobleRank: true,
            },
          },
        },
      },
    },
  });

  // Ensure Room Creator/Owner is included in the roster
  const creatorUserId = room.creatorUserId;
  let ownerMember = rawMembers.find((m) => m.userId === creatorUserId);

  if (!ownerMember && room.creator) {
    // Check if search matches creator
    let matchesSearch = true;
    if (cleanSearch) {
      const q = cleanSearch.toLowerCase();
      const u = room.creator;
      const dName = u.profile?.displayName || '';
      matchesSearch = (
        u.id.toLowerCase().includes(q) ||
        u.username.toLowerCase().includes(q) ||
        dName.toLowerCase().includes(q)
      );
    }

    if (matchesSearch) {
      ownerMember = {
        id: `host_member_${creatorUserId}`,
        roomId: resolvedRoomId,
        userId: creatorUserId,
        role: 'HOST',
        joinedAt: room.createdAt || new Date(0),
        user: {
          id: room.creator.id,
          username: room.creator.username,
          avatarUrl: room.creator.avatarUrl || '',
          lastLoginAt: room.creator.lastLoginAt,
          updatedAt: room.creator.updatedAt,
          profile: room.creator.profile,
        },
      };
      rawMembers.unshift(ownerMember);
    }
  }

  // Format and determine role
  const formattedList = rawMembers.map((m) => {
    const isOwner = m.userId === creatorUserId;
    let role = isOwner ? 'HOST' : 'MEMBER';
    if (!isOwner && (m.role === 'ADMIN' || m.role === 'MODERATOR')) {
      role = 'ADMIN';
    }

    const isOnline = activePresenceUserIds.has(m.userId);
    const seatInfo = seatedUserMap.get(m.userId) || null;
    const displayName = m.user?.profile?.displayName || m.user?.username || m.userId;
    const publicId = m.user?.username || m.user?.id || m.userId;

    const nobleStyle = getNobleStyle(m.user?.profile?.nobleRank);
    const mAgoraUid = deriveAgoraUid(m.userId);

    return {
      id: m.userId,
      memberId: m.id || `member_${m.userId}`,
      userId: m.userId,
      agoraUid: mAgoraUid,
      uid: mAgoraUid,
      publicUserId: publicId,
      publicId,
      username: m.user?.username || m.userId,
      name: displayName,
      displayName,
      avatarUrl: m.user?.avatarUrl || '',
      role,
      isHost: isOwner,
      isOwner,
      isAdmin: role === 'ADMIN',
      isMember: true,
      joinedAt: m.joinedAt || room.createdAt,
      level: m.user?.profile?.level || 1,
      vipLevel: m.user?.profile?.vipLevel || 0,
      svipLevel: m.user?.profile?.svipLevel || 0,
      nobleRank: m.user?.profile?.nobleRank || null,
      nobleColor: nobleStyle?.color || null,
      nobleStyle,
      isOnline,
      inRoom: isOnline,
      presenceStatus: isOnline ? 'IN_ROOM' : 'OFFLINE',
      lastSeenAt: m.user?.lastLoginAt || m.user?.updatedAt || null,
      seatIndex: seatInfo ? seatInfo.seatIndex : null,
      isOnMic: Boolean(seatInfo),
      isMutedOnMic: seatInfo ? seatInfo.isMuted : false,
      user: {
        id: m.userId,
        userId: m.userId,
        agoraUid: mAgoraUid,
        uid: mAgoraUid,
        username: m.user?.username || m.userId,
        displayName,
        avatarUrl: m.user?.avatarUrl || '',
        level: m.user?.profile?.level || 1,
        vipLevel: m.user?.profile?.vipLevel || 0,
        svipLevel: m.user?.profile?.svipLevel || 0,
        nobleRank: m.user?.profile?.nobleRank || null,
        nobleColor: nobleStyle?.color || null,
        nobleStyle,
        lastSeenAt: m.user?.lastLoginAt || null,
      },
    };
  });

  // If fetching active viewers only, include any active presence users not already in saved membership
  if (onlyActive) {
    for (const ap of activePresence) {
      const uId = ap.userId || ap.id;
      if (!uId || rawMembers.some((m) => m.userId === uId)) continue;
      const isOwner = uId === creatorUserId;
      const seatInfo = seatedUserMap.get(uId) || null;
      const dName = ap.displayName || ap.name || ap.username || `User_${String(uId).substring(0, 6)}`;
      const nobleStyle = getNobleStyle(ap.nobleRank);
      const apAgoraUid = ap.agoraUid || deriveAgoraUid(uId);
      formattedList.push({
        id: uId,
        memberId: `viewer_${uId}`,
        userId: uId,
        agoraUid: apAgoraUid,
        uid: apAgoraUid,
        publicUserId: ap.username || uId,
        publicId: ap.username || uId,
        username: ap.username || uId,
        name: dName,
        displayName: dName,
        avatarUrl: ap.avatarUrl || '',
        role: isOwner ? 'HOST' : 'MEMBER',
        isHost: isOwner,
        isOwner,
        isAdmin: false,
        isMember: false,
        joinedAt: ap.joinedAt || new Date().toISOString(),
        level: ap.level || 1,
        vipLevel: ap.vipLevel || 0,
        svipLevel: ap.svipLevel || 0,
        nobleRank: ap.nobleRank || null,
        nobleColor: nobleStyle?.color || null,
        nobleStyle,
        isOnline: true,
        inRoom: true,
        presenceStatus: 'IN_ROOM',
        lastSeenAt: new Date().toISOString(),
        seatIndex: seatInfo ? seatInfo.seatIndex : null,
        isOnMic: Boolean(seatInfo),
        isMutedOnMic: seatInfo ? seatInfo.isMuted : false,
        user: {
          id: uId,
          userId: uId,
          agoraUid: apAgoraUid,
          uid: apAgoraUid,
          username: ap.username || uId,
          displayName: dName,
          avatarUrl: ap.avatarUrl || '',
          level: ap.level || 1,
          vipLevel: ap.vipLevel || 0,
          svipLevel: ap.svipLevel || 0,
          nobleRank: ap.nobleRank || null,
          nobleColor: nobleStyle?.color || null,
          nobleStyle,
          lastSeenAt: new Date().toISOString(),
        },
      });
    }
  }

  // Filter for active users when onlyActive is requested
  const filteredList = onlyActive ? formattedList.filter((m) => m.isOnline) : formattedList;

  // Strict Roster Ordering:
  // 1. Owner first (weight 0)
  // 2. Room Admins next (weight 1)
  // 3. Ordinary Members after admins (weight 2)
  // Stable deterministic tie-breaker within each group: joinedAt asc, then userId asc
  filteredList.sort((a, b) => {
    const weightA = a.role === 'HOST' ? 0 : (a.role === 'ADMIN' ? 1 : 2);
    const weightB = b.role === 'HOST' ? 0 : (b.role === 'ADMIN' ? 1 : 2);
    if (weightA !== weightB) {
      return weightA - weightB;
    }
    const timeA = new Date(a.joinedAt || 0).getTime();
    const timeB = new Date(b.joinedAt || 0).getTime();
    if (timeA !== timeB) {
      return timeA - timeB;
    }
    return String(a.userId).localeCompare(String(b.userId));
  });

  // Total active or saved membership count
  const totalCount = filteredList.length;

  // Pagination
  const pageNum = Math.max(1, Number(page) || 1);
  const limitNum = Math.min(200, Math.max(1, Number(limit) || 50));
  const skip = (pageNum - 1) * limitNum;
  const paginatedMembers = filteredList.slice(skip, skip + limitNum);

  // Decorate with mic invite status
  let decorated = paginatedMembers;
  try {
    decorated = await micInviteService.decorateMembersWithMicInviteStatus(resolvedRoomId, paginatedMembers, db);
  } catch (_) {}

  // Online viewer count from presence
  let viewerCount = typeof room.currentViewersCount === 'number' ? room.currentViewersCount : 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(resolvedRoomId, room.creatorUserId);
    if (typeof presCount === 'number' && presCount >= 0) {
      viewerCount = presCount;
    }
  } catch (_) {}

  return {
    members: decorated,
    data: decorated,
    totalCount,
    total: totalCount,
    savedMemberCount: totalCount,
    viewerCount,
    capacity: room.capacity || 200,
    pagination: {
      page: pageNum,
      limit: limitNum,
      total: totalCount,
      totalPages: Math.ceil(totalCount / limitNum) || 1,
      hasMore: skip + paginatedMembers.length < totalCount,
    },
  };
}

export async function updateMemberRole(roomId, actorUserId, targetUserId, { role }, db = prisma) {
  let resolvedRoomId = roomId;
  let room = await db.room.findUnique({
    where: { id: roomId },
    select: { id: true, creatorUserId: true },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true, creatorUserId: true },
    });
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }
  resolvedRoomId = room.id;

  // Permission check: actor must be creator or admin
  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  if (!isOwner) {
    const actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: resolvedRoomId, userId: actorUserId } },
    });
    if (actorMember && (actorMember.role === 'ADMIN' || actorMember.role === 'MODERATOR')) {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only the room owner or room admins can manage roles');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Cannot alter room owner
  if (targetUserId === room.creatorUserId) {
    const error = new Error('Cannot change or revoke the room owner role');
    error.statusCode = 400;
    error.code = 'OWNER_ROLE_IMMUTABLE';
    throw error;
  }

  // Only owner can promote someone to ADMIN
  if (!isOwner && role === 'ADMIN') {
    const error = new Error('Only the room owner can assign room admin roles');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const targetMember = await db.roomMember.findUnique({
    where: { roomId_userId: { roomId: resolvedRoomId, userId: targetUserId } },
  });

  if (!isOwner && targetMember && (targetMember.role === 'ADMIN' || targetMember.role === 'MODERATOR') && role !== 'ADMIN') {
    const error = new Error('Admins cannot revoke other admins; only the room owner can');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Verify target user existence
  const targetUserExists = await db.user.findUnique({
    where: { id: targetUserId },
    select: { id: true },
  });
  if (!targetUserExists) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const updatedRole = role === 'ADMIN' ? 'ADMIN' : 'MEMBER';

  // Durably write and commit role assignment
  const updatedMember = await db.roomMember.upsert({
    where: { roomId_userId: { roomId: resolvedRoomId, userId: targetUserId } },
    create: {
      roomId: resolvedRoomId,
      userId: targetUserId,
      role: updatedRole,
    },
    update: {
      role: updatedRole,
    },
    include: {
      user: {
        select: { id: true, username: true, avatarUrl: true, profile: true },
      },
    },
  });

  // Record audit trail
  try {
    await roomRoleAuditService.recordRoleChange({
      roomId: resolvedRoomId,
      actorUserId,
      targetUserId,
      action: updatedRole === 'ADMIN' ? 'ROOM_ADMIN_PROMOTED' : 'ROOM_ADMIN_DEMOTED',
      role: updatedRole,
      outcome: 'SUCCESS',
    }, db);
  } catch (_) {}

  // Publish realtime role update events
  const rolePayload = {
    roomId: resolvedRoomId,
    targetUserId,
    role: updatedRole,
    timestamp: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(resolvedRoomId, 'room:role_updated', rolePayload);
    socketEmitter.emitToRoom(resolvedRoomId, 'room:member_role_changed', rolePayload);
    if (updatedRole === 'ADMIN') {
      socketEmitter.emitToRoom(resolvedRoomId, 'room:admin_promoted', rolePayload);
    } else {
      socketEmitter.emitToRoom(resolvedRoomId, 'room:admin_demoted', rolePayload);
    }
  } catch (err) {
    console.error('Failed to emit room:role_updated event:', err);
  }

  return updatedMember;
}

export async function getRoomSendingRankings(roomId, { period = 'daily', currentUserId } = {}, db = prisma) {
  let canonicalRoomId = roomId;
  let room = await db.room.findUnique({
    where: { id: roomId },
    select: { id: true, creatorUserId: true, createdAt: true, status: true },
  });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true, creatorUserId: true, createdAt: true, status: true },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }
  canonicalRoomId = room.id;

  const startDate = new Date();

  if (period === 'daily') {
    startDate.setUTCHours(0, 0, 0, 0);
  } else if (period === 'weekly') {
    const day = startDate.getUTCDay();
    const diff = startDate.getUTCDate() - day + (day === 0 ? -6 : 1);
    startDate.setUTCDate(diff);
    startDate.setUTCHours(0, 0, 0, 0);
  } else if (period === 'monthly') {
    startDate.setUTCDate(1);
    startDate.setUTCHours(0, 0, 0, 0);
  }

  // For AUDIO_PARTY, daily period covers all gifts sent today (startDate).
  // For LIVE_VIDEO broadcast sessions, isolate score & rankings to the current active session.
  let effectiveStartDate = startDate;
  if (room && room.status === 'LIVE' && room.createdAt && room.roomType !== 'AUDIO_PARTY') {
    const sessionCreatedAt = new Date(room.createdAt);
    if (sessionCreatedAt > startDate) {
      effectiveStartDate = sessionCreatedAt;
    }
  }

  const txs = await db.giftTransaction.groupBy({
    by: ['senderUserId'],
    where: {
      roomId: canonicalRoomId,
      createdAt: { gte: effectiveStartDate },
    },
    _sum: {
      totalCoins: true,
    },
    orderBy: {
      _sum: {
        totalCoins: 'desc',
      },
    },
  });

  const periodTotalResult = await db.giftTransaction.aggregate({
    where: { roomId: canonicalRoomId, createdAt: { gte: effectiveStartDate } },
    _sum: { totalCoins: true },
  });
  const periodTotalCoins = Number(periodTotalResult._sum.totalCoins || 0);

  const overallTotalResult = await db.giftTransaction.aggregate({
    where: { roomId: canonicalRoomId },
    _sum: { totalCoins: true },
  });
  const overallTotalCoins = Number(overallTotalResult._sum.totalCoins || 0);

  const senderUserIds = txs.map((t) => t.senderUserId);
  const senders = await db.user.findMany({
    where: { id: { in: senderUserIds } },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      profile: {
        select: { displayName: true },
      },
    },
  });

  const senderMap = new Map(senders.map((s) => [s.id, s]));

  const rankings = txs.map((t, idx) => {
    const s = senderMap.get(t.senderUserId);
    return {
      rank: idx + 1,
      userId: t.senderUserId,
      name: s?.profile?.displayName || s?.username || 'User',
      username: s?.username || 'user',
      avatarUrl: s?.avatarUrl || '',
      totalCoins: Number(t._sum.totalCoins || 0),
    };
  });

  let viewerRank = null;
  if (currentUserId) {
    const userIndex = rankings.findIndex((r) => r.userId === currentUserId);
    if (userIndex !== -1) {
      viewerRank = rankings[userIndex];
    } else {
      const userTx = await db.giftTransaction.aggregate({
        where: { roomId: canonicalRoomId, senderUserId: currentUserId, createdAt: { gte: startDate } },
        _sum: { totalCoins: true },
      });
      const userCoins = Number(userTx._sum.totalCoins || 0);
      viewerRank = {
        rank: userCoins > 0 ? rankings.length + 1 : 0,
        userId: currentUserId,
        name: 'You',
        avatarUrl: '',
        totalCoins: userCoins,
      };
    }
  }

  return {
    period,
    periodTotalCoins,
    overallTotalCoins,
    roomSendingTotal: periodTotalCoins,
    dailySendingTotal: periodTotalCoins,
    trophyCoins: periodTotalCoins,
    rankings,
    viewerRank,
  };
}

/**
 * Module 02: Paid Room Theme / DP Upload (100,000 Coins)
 */
export async function uploadPaidRoomTheme({ roomId, userId, themeUrl, themeType = 'GALLERY_WALLPAPER' }, db = prisma) {
  const room = await db.room.findUnique({ where: { id: roomId } });
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    throw error;
  }

  // Phase 2 Room Admin Rule: Effects and themes controls strictly prohibited for Room Admins
  if (room.creatorUserId !== userId) {
    const error = new Error('Room Admins are not permitted to change effects or custom wallpapers. Only the room owner can manage room themes.');
    error.statusCode = 403;
    error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
    throw error;
  }

  const wallet = await db.wallet.findUnique({ where: { userId } });
  const requiredCoins = 100000;

  if (!wallet || BigInt(wallet.coinBalance) < BigInt(requiredCoins)) {
    const error = new Error('Insufficient Coins. 100,000 Coins required to upload custom wallpaper from gallery.');
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_COINS';
    error.requiredCoins = requiredCoins;
    error.currentBalance = wallet ? wallet.coinBalance.toString() : '0';
    throw error;
  }

  // Deduct 100,000 coins and apply theme
  const updated = await db.$transaction(async (tx) => {
    await tx.wallet.update({
      where: { userId },
      data: { coinBalance: { decrement: BigInt(requiredCoins) } },
    });

    const updatedRoom = await tx.room.update({
      where: { id: roomId },
      data: { coverImageUrl: themeUrl, backgroundImageUrl: themeUrl },
    });

    return updatedRoom;
  });

  try {
    const payload = {
      roomId,
      backgroundImageUrl: themeUrl,
      background: themeUrl,
      updatedBy: userId,
    };
    socketEmitter.emitToRoom(roomId, 'room:background_updated', payload);
    socketEmitter.emitToRoom(roomId, 'room_background_updated', payload);
  } catch (_) {}

  return {
    success: true,
    message: 'Room Theme uploaded and 100,000 Coins deducted successfully.',
    requiredCoins,
    themeUrl,
    room: updated,
  };
}

/**
 * Module 03: Room Mic Size Preset
 */
export async function updateRoomMicConfig(roomId, { micPreset = 'LARGE', actorUserId }, db = prisma) {
  if (actorUserId) {
    const room = await roomRepository.findRoomById(roomId, db);
    if (room && room.creatorUserId !== actorUserId) {
      const error = new Error('Room Admins are not permitted to update mic configuration. Only the room owner can manage mic configuration.');
      error.statusCode = 403;
      error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
      throw error;
    }
  }

  return {
    success: true,
    roomId,
    micPreset: micPreset.toUpperCase(),
    spacing: 'GENEROUS_CIRCULAR',
    profileSize: 'PROMINENT_LARGE',
  };
}

export async function getRoomMicConfig(roomId, db = prisma) {
  return {
    roomId,
    micPreset: 'LARGE',
    seatCount: 8,
    isLargeSeats: true,
  };
}

/**
 * Module 03: Room Entry Announcement
 */
export async function getRoomAnnouncement(roomId, db = prisma) {
  return {
    roomId,
    announcement: 'Welcome to ZeParty. Please respect each other and communicate in a friendly and appropriate manner.',
    isEnabled: true,
    attachedPosition: 'BELOW_MIC_SEATS',
  };
}

export async function updateRoomAnnouncement(roomId, { announcement, isEnabled = true, actorUserId }, db = prisma) {
  if (actorUserId) {
    const room = await roomRepository.findRoomById(roomId, db);
    if (room && room.creatorUserId !== actorUserId) {
      const error = new Error('Room Admins are not permitted to update room announcements. Only the room owner can update announcements.');
      error.statusCode = 403;
      error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
      throw error;
    }
  }

  return {
    success: true,
    roomId,
    announcement: announcement || 'Welcome to ZeParty. Please respect each other and communicate in a friendly and appropriate manner.',
    isEnabled: Boolean(isEnabled),
    attachedPosition: 'BELOW_MIC_SEATS',
    updatedAt: new Date().toISOString(),
  };
}

/**
 * Module 06: Party Room Owner/Admin Controls (YouTube, Super Wheel, Lucky Bag, Lock Room)
 */
export async function controlRoomYouTube(roomId, { action, videoUrl, videoTitle, timestamp = 0, actorUserId }, db = prisma) {
  if (actorUserId) {
    const room = await roomRepository.findRoomById(roomId, db);
    if (room && room.creatorUserId !== actorUserId) {
      const error = new Error('Room Admins are not permitted to control room YouTube playback. Only the room owner can control media sessions.');
      error.statusCode = 403;
      error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
      throw error;
    }
  }

  return {
    success: true,
    roomId,
    sessionType: 'YOUTUBE_SYNC',
    action: action || 'START',
    videoUrl: videoUrl || 'https://youtube.com/watch?v=official_zeparty',
    videoTitle: videoTitle || 'ZeParty Official Audio',
    playbackState: { isPlaying: action !== 'PAUSE' && action !== 'STOP', timestamp },
  };
}

export async function controlSuperWheel(
  roomId,
  { action = 'LAUNCH', sessionId, entryCoinFee, stakeAmount, maxParticipants = 10, rewardCoins = 0, actorUserId },
  db = prisma
) {
  const upperAction = String(action || 'LAUNCH').toUpperCase();

  if (upperAction === 'LAUNCH' || upperAction === 'CREATE') {
    const fee = entryCoinFee !== undefined ? entryCoinFee : (stakeAmount || 0);
    const session = await wheelService.createWheelSession(
      roomId,
      {
        entryCoinFee: fee,
        maxParticipants,
        rewardCoins,
        actorUserId,
      },
      db
    );
    return {
      success: true,
      message: 'Super Wheel session launched',
      data: session,
    };
  }

  if (upperAction === 'JOIN') {
    return await wheelService.joinWheelSession({ sessionId, roomId, userId: actorUserId }, db);
  }

  if (upperAction === 'SPIN') {
    return await wheelService.spinWheelRound({ sessionId, roomId, actorUserId }, db);
  }

  if (upperAction === 'CANCEL') {
    return await wheelService.cancelWheelSession({ sessionId, roomId, actorUserId }, db);
  }

  const active = wheelService.getActiveWheelSession(roomId);
  return {
    success: true,
    data: active,
  };
}

export async function controlLuckyBag(
  roomId,
  {
    action = 'CREATE',
    bagId,
    mode = 'normal',
    totalCoins = 1000,
    claimCount,
    quantity,
    claimersLimit,
    taskType = 'none',
    countdownSeconds = 0,
    actorUserId,
  },
  db = prisma
) {
  const upperAction = String(action || 'CREATE').toUpperCase();

  if (upperAction === 'CREATE' || upperAction === 'DROP') {
    const bag = await luckyBagService.createLuckyBag(
      {
        roomId,
        mode,
        totalCoins,
        quantity: quantity || claimCount || claimersLimit || 10,
        taskType,
        countdownSeconds,
        creatorUserId: actorUserId,
      },
      db
    );
    return {
      success: true,
      message: 'Lucky Bag dropped successfully',
      data: bag,
    };
  }

  if (upperAction === 'CLAIM') {
    return await luckyBagService.claimLuckyBag(
      {
        bagId,
        roomId,
        claimantUserId: actorUserId,
      },
      db
    );
  }

  const bags = luckyBagService.getActiveLuckyBags(roomId);
  return {
    success: true,
    data: bags,
  };
}

export async function controlRoomLock(roomId, { isLocked = true, accessMode = 'PASSWORD', mode, pin, actorUserId }, db = prisma) {
  let room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization check: ONLY Room Owner (Creator) can configure room lock settings
  // Confirmed Phase 2 Rule: Room Admins are strictly prohibited from room lock controls
  const isCreator = room.creatorUserId === actorUserId;
  if (!isCreator) {
    const error = new Error('Room Admins are not permitted to configure room lock settings. Only the room owner can lock the room.');
    error.statusCode = 403;
    error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
    throw error;
  }

  const effectiveLockMode = (mode || accessMode || 'PIN').toUpperCase();
  const locked = Boolean(isLocked);
  let hashedPin = null;

  if (locked) {
    if (effectiveLockMode === 'PIN' || effectiveLockMode === 'PASSWORD') {
      const pinStr = String(pin !== undefined && pin !== null ? pin : '1234').trim();
      if (!/^\d{4,8}$/.test(pinStr)) {
        const error = new Error('PIN must be between 4 and 8 digits');
        error.statusCode = 400;
        error.code = 'INVALID_PIN_FORMAT';
        throw error;
      }
      hashedPin = await bcrypt.hash(pinStr, 10);
    }
  }

  await roomRepository.updateRoomLockSettings({
    roomId: room.id,
    isLocked: locked,
    roomPin: hashedPin,
  }, db);

  const payload = {
    roomId: room.id,
    clientRoomId: roomId,
    isLocked: locked,
    lockMode: locked ? (effectiveLockMode.includes('APPROVAL') ? 'Approval' : 'PIN') : 'NONE',
    hasPin: Boolean(hashedPin),
    updatedAt: new Date().toISOString(),
  };

  // Broadcast lock state to room participants
  try {
    socketEmitter.emitToRoom(room.id, 'room:lock_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:lock_status', payload);
    socketEmitter.emitToRoom(room.id, 'room:lock_settings', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:lock_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:lock_status', payload);
    }
  } catch (_) {}

  return {
    success: true,
    data: payload,
  };
}

export async function updateRoomProfile(roomId, userId, { title, coverImageUrl, coverUrl, category, roomType, backgroundImageUrl }, db = prisma) {
  let room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization: ONLY Room Owner (Creator) can update room profile
  const isCreator = room.creatorUserId === userId;
  if (!isCreator) {
    const error = new Error('Room Admins are not permitted to update room profile. Only the room owner can update room information.');
    error.statusCode = 403;
    error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
    throw error;
  }

  const finalCover = coverImageUrl !== undefined ? coverImageUrl : coverUrl;

  const updatedRoom = await roomRepository.updateRoomDetails({
    roomId: room.id,
    title,
    coverImageUrl: finalCover,
    category,
    roomType,
    backgroundImageUrl,
  }, db);

  const payload = {
    roomId: room.id,
    clientRoomId: roomId,
    title: updatedRoom.title,
    coverImageUrl: updatedRoom.coverImageUrl,
    coverUrl: updatedRoom.coverImageUrl,
    category: updatedRoom.category,
    roomType: updatedRoom.roomType,
    backgroundImageUrl: updatedRoom.backgroundImageUrl,
    updatedAt: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(room.id, 'room:details_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:profile_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:update_details', payload);
    socketEmitter.emitToRoom(room.id, 'room:details_update', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:details_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:profile_updated', payload);
    }
  } catch (_) {}

  return {
    success: true,
    data: payload,
  };
}

/**
 * Issue 11: Update Room Seat Count & Layout Mode
 */
export async function updateRoomLayout(roomId, userId, { capacity, seatCapacity, roomType }, db = prisma) {
  let room = await db.room.findUnique({
    where: { id: roomId },
    include: { creator: true },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      include: { creator: true },
    });
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization check: ONLY Room Owner (Creator) can update room layout
  const isCreator = room.creatorUserId === userId;
  if (!isCreator) {
    const error = new Error('Room Admins are not permitted to update room layout. Only the room owner can update seat capacity.');
    error.statusCode = 403;
    error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
    throw error;
  }

  const requestedCapacity = parseInt(capacity || seatCapacity, 10);
  if (!requestedCapacity || isNaN(requestedCapacity) || requestedCapacity < 8 || requestedCapacity > 50) {
    const error = new Error('Invalid seat capacity. Must be between 8 and 30');
    error.statusCode = 400;
    error.code = 'INVALID_SEAT_CAPACITY';
    throw error;
  }

  const updatedRoom = await roomRepository.updateRoomLayoutTx({
    roomId: room.id,
    capacity: requestedCapacity,
    roomType,
  }, db);

  const finalCapacity = (updatedRoom.seats || []).length;
  const payload = {
    roomId: room.id,
    clientRoomId: roomId,
    capacity: finalCapacity,
    seatCapacity: finalCapacity,
    roomType: updatedRoom.roomType,
    seats: (updatedRoom.seats || []).map((s) => {
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
    timestamp: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(room.id, 'room:layout_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room_layout_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:update_layout', payload);
    socketEmitter.emitToRoom(room.id, 'room:mic_count_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:seats_updated', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:layout_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room_layout_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:update_layout', payload);
    }
  } catch (_) {}

  return {
    success: true,
    message: 'Room layout updated successfully',
    data: payload,
  };
}

/**
 * Module 07: Room Mic Seat Management Action Sheet
 */
export async function lockRoomSeat(roomId, { seatIndex = 0, isLocked = true, actorUserId }, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Permission check: ONLY Room Owner (Creator) can lock or unlock mic seats
  // Confirmed Phase 2 Rule: Room Admins are strictly prohibited from mic seat locking
  const isCreator = room.creatorUserId === actorUserId;
  if (!isCreator) {
    const error = new Error('Room Admins are not permitted to lock or unlock mic seats. Only the room owner can manage seat locks.');
    error.statusCode = 403;
    error.code = 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
    throw error;
  }

  const sIndex = Number(seatIndex);
  if (isNaN(sIndex) || sIndex < 0 || sIndex > 30) {
    const error = new Error('Invalid seatIndex (must be 0-30)');
    error.statusCode = 400;
    error.code = 'INVALID_SEAT_INDEX';
    throw error;
  }

  const updatedSeat = await roomRepository.updateSeatLockStatus(
    { roomId: room.id, seatIndex: sIndex, isLocked: Boolean(isLocked) },
    db
  );

  const eventId = `evt-seat-lock-${room.id}-${sIndex}-${Date.now()}`;
  const payload = {
    id: eventId,
    eventId,
    roomId: room.id,
    clientRoomId: roomId,
    seatIndex: sIndex,
    isLocked: Boolean(isLocked),
    lockedByUserId: actorUserId,
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room channels
  socketEmitter.emitToRoom(room.id, 'room:seat_locked_status', payload);
  socketEmitter.emitToRoom(room.id, 'room:seat_locked', payload);
  socketEmitter.emitToRoom(room.id, 'room:lock_seat', payload);
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_UPDATED, payload);

  return {
    success: true,
    message: `Seat ${sIndex} ${isLocked ? 'locked' : 'unlocked'} successfully`,
    data: payload,
  };
}

export async function manageMicSeatAction(roomId, { seatIndex = 0, action = 'LOCK', isLocked, targetUserId, actorUserId }, db = prisma) {
  const upperAction = String(action || '').toUpperCase();
  if (['REMOVE_FROM_MIC', 'REMOVE_MIC', 'MUTE', 'UNMUTE', 'KICK'].includes(upperAction) && targetUserId) {
    return await moderateRoomUser(roomId, actorUserId, { targetUserId, action: upperAction }, db);
  }

  if (upperAction === 'LOCK' || upperAction === 'UNLOCK' || isLocked !== undefined) {
    const lockState = isLocked !== undefined ? Boolean(isLocked) : upperAction === 'LOCK';
    return await lockRoomSeat(roomId, { seatIndex, isLocked: lockState, actorUserId }, db);
  }

  return {
    success: true,
    roomId,
    seatIndex: Number(seatIndex),
    action: upperAction,
    targetUserId: targetUserId || null,
    actorUserId,
    newSeatState: {
      seatIndex: Number(seatIndex),
      isLocked: upperAction === 'LOCK',
      isMuted: upperAction === 'MUTE',
      occupiedBy: upperAction === 'TAKE' ? actorUserId : null,
    },
  };
}

/**
 * Module 08: Mic Reaction & Sticker Display Anchored to Seat
 */
export async function sendMicReaction(
  roomId,
  { seatIndex = 0, reactionId, emoji, stickerUrl, reactionType = 'EMOJI', actorUserId },
  db = prisma
) {
  const room = await roomRepository
    .resolveCanonicalRoom(roomId, { senderUserId: actorUserId, allowActiveFallback: false }, db)
    .catch(() => null);
  const canonicalRoomId = room?.id || roomId;

  let senderUser = null;
  if (actorUserId) {
    senderUser = await userRepository.findById(actorUserId, db).catch(() => null);
  }

  let resolvedSeatIndex = seatIndex !== undefined && seatIndex !== null ? Number(seatIndex) : null;
  if ((resolvedSeatIndex === null || Number.isNaN(resolvedSeatIndex)) && room && Array.isArray(room.seats)) {
    const occupiedSeat = room.seats.find((s) => s.occupiedUserId === actorUserId);
    if (occupiedSeat) {
      resolvedSeatIndex = occupiedSeat.seatIndex;
    } else if (room.creatorUserId === actorUserId) {
      resolvedSeatIndex = 0;
    }
  }

  const senderIdentity = formatAuthoritativeUserIdentity(
    senderUser || { id: actorUserId, username: 'User' },
    {
      role: room?.creatorUserId === actorUserId ? 'HOST' : resolvedSeatIndex !== null ? 'SPEAKER' : 'VIEWER',
      seatIndex: resolvedSeatIndex,
    }
  );

  const effectiveEmoji = emoji || reactionId || 'react_popular_01';
  const eventId = `evt-mic-react-${canonicalRoomId}-${actorUserId || 'anon'}-${Date.now()}`;
  const reactionPayload = {
    id: eventId,
    eventId,
    roomId: canonicalRoomId,
    sessionId: canonicalRoomId,
    clientRoomId: roomId,
    userId: actorUserId,
    senderId: actorUserId,
    senderUserId: actorUserId,
    agoraUid: senderIdentity?.agoraUid || deriveAgoraUid(actorUserId),
    uid: senderIdentity?.agoraUid || deriveAgoraUid(actorUserId),
    username: senderIdentity?.username || 'User',
    displayName: senderIdentity?.displayName || 'User',
    name: senderIdentity?.displayName || 'User',
    avatarUrl: senderIdentity?.avatarUrl || null,
    avatar: senderIdentity?.avatarUrl || null,
    seatId: resolvedSeatIndex,
    seatIndex: resolvedSeatIndex,
    micIndex: resolvedSeatIndex,
    emoji: effectiveEmoji,
    reactionId: reactionId || effectiveEmoji,
    stickerUrl: stickerUrl || null,
    reactionType,
    displayAnchor: 'OCCUPIED_MIC_TOP',
    durationSeconds: 3,
    user: senderIdentity,
    sender: senderIdentity,
    timestamp: new Date().toISOString(),
  };

  if (canonicalRoomId) {
    if (room?.creatorUserId) {
      await socketEmitter.joinUserSocketsToRoom(room.creatorUserId, canonicalRoomId).catch(() => {});
    }
    if (actorUserId) {
      await socketEmitter.joinUserSocketsToRoom(actorUserId, canonicalRoomId).catch(() => {});
    }
    socketEmitter.emitToRoom(canonicalRoomId, SOCKET_EVENTS.ROOM_EMOJI_RECEIVED, reactionPayload);
    socketEmitter.emitToRoom(canonicalRoomId, 'room:emoji', reactionPayload);
    socketEmitter.emitToRoom(canonicalRoomId, 'room:emoji_received', reactionPayload);
    socketEmitter.emitToRoom(canonicalRoomId, 'room_emoji', reactionPayload);
    socketEmitter.emitToRoom(canonicalRoomId, 'emoji_received', reactionPayload);
    socketEmitter.emitToRoom(canonicalRoomId, 'room:reaction', reactionPayload);
    socketEmitter.emitToRoom(canonicalRoomId, 'room:mic_reaction', reactionPayload);
  }

  return {
    success: true,
    ...reactionPayload,
  };
}

/**
 * Module 31: Room Entry Name & Entrance Banner Position
 */
export async function getEntryBannerConfig(roomId, db = prisma) {
  return {
    roomId,
    position: 'BELOW_MIC_GRID',
    offsetBelowMicGridDp: 16,
    offsetAboveChatDp: 14,
    nonOverlapEnforced: true,
    queueMultipleEntries: true,
  };
}

/**
 * Module 02 / Issue 02: Room Background Management
 */
export async function updateRoomBackground(roomId, userId, { backgroundImageUrl, background }, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Ensure only the room creator/owner or system admin can modify the room background
  if (room.creatorUserId !== userId) {
    const error = new Error('Only the room owner can update the room background');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Accept backgroundImageUrl or fallback to background
  const rawBg = backgroundImageUrl !== undefined ? backgroundImageUrl : background;
  const targetBackground = rawBg ? String(rawBg).trim() : null;

  const updatedRoom = await roomRepository.updateRoomBackgroundTx(
    { roomId: room.id, backgroundImageUrl: targetBackground },
    db
  );

  const payload = {
    roomId: room.id,
    backgroundImageUrl: updatedRoom.backgroundImageUrl || null,
    background: updatedRoom.backgroundImageUrl || null,
    themeUrl: updatedRoom.backgroundImageUrl || null,
    theme: updatedRoom.backgroundImageUrl || null,
    updatedBy: userId,
    timestamp: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(room.id, 'room:background_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room_background_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:update_background', payload);
    socketEmitter.emitToRoom(room.id, 'room:theme_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room_theme_updated', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:background_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room_background_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:theme_updated', payload);
    }
  } catch (_) {}

  return {
    success: true,
    message: targetBackground ? 'Room background updated successfully' : 'Room background removed successfully',
    roomId: room.id,
    backgroundImageUrl: updatedRoom.backgroundImageUrl || null,
    background: updatedRoom.backgroundImageUrl || null,
    themeUrl: updatedRoom.backgroundImageUrl || null,
    theme: updatedRoom.backgroundImageUrl || null,
  };
}

export async function removeRoomBackground(roomId, userId, db = prisma) {
  return await updateRoomBackground(roomId, userId, { backgroundImageUrl: null }, db);
}

export async function getRoomBackground(roomId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

    return {
    success: true,
    roomId: room.id,
    backgroundImageUrl: room.backgroundImageUrl || null,
    background: room.backgroundImageUrl || null,
  };
}

/**
 * =========================================================================
 * Issue 04: Room User Moderation (Remove from Mic, Mute/Unmute, Kick from Room)
 * =========================================================================
 */

function formatRoomSnapshot(room, viewerCount) {
  if (!room) return null;
  const hostUserId = room.creatorUserId;
  const hostIsOccupyingSeat = (room.seats || []).some(
    (s) => s.occupiedUserId === hostUserId
  );

  const membersList = (room.members || [])
    .filter((m) => {
      const mid = m.userId || m.user?.id;
      if (mid === hostUserId && hostIsOccupyingSeat) return false;
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
  }

  const seatsList = (room.seats || []).map((s) => ({
    id: s.id,
    seatIndex: s.seatIndex,
    occupiedUserId: s.occupiedUserId,
    isMuted: Boolean(s.isMuted),
    isMutedByModerator: Boolean(s.isMutedByModerator),
    isLocked: Boolean(s.isLocked),
    user: s.occupiedUser ? (() => {
      const uRank = s.occupiedUser.profile?.nobleRank || s.occupiedUser.nobleTitle || s.occupiedUser.nobleRank || null;
      const uStyle = getNobleStyle(uRank);
      return {
        id: s.occupiedUser.id,
        userId: s.occupiedUser.id,
        username: s.occupiedUser.username,
        displayName: s.occupiedUser.profile?.displayName || s.occupiedUser.displayName || s.occupiedUser.username,
        name: s.occupiedUser.profile?.displayName || s.occupiedUser.displayName || s.occupiedUser.username,
        avatarUrl: s.occupiedUser.avatarUrl || s.occupiedUser.profile?.avatarUrl || null,
        level: s.occupiedUser.profile?.level || s.occupiedUser.level || 1,
        vipLevel: s.occupiedUser.profile?.vipLevel || s.occupiedUser.vipLevel || 0,
        svipLevel: s.occupiedUser.profile?.svipLevel || s.occupiedUser.svipLevel || 0,
        nobleTitle: uRank,
        nobleRank: uRank,
        nobleLevel: uRank,
        nobleColor: uStyle?.color || null,
        nobleStyle: uStyle,
      };
    })() : null,
  }));

  return {
    id: room.id,
    roomId: room.id,
    creatorUserId: hostUserId,
    seats: seatsList,
    members: membersList,
    viewerCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    currentViewersCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
  };
}

export async function validateModerationPermission(roomId, actorUserId, targetUserId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(room.status);
  if (!isRoomOpen) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  if (!isOwner) {
    const actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
    });
    if (actorMember && (actorMember.role === 'ADMIN' || actorMember.role === 'HOST')) {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only the room owner or authorized room admins can perform moderation actions');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Room admins and other users cannot moderate or kick the room owner
  if (targetUserId === room.creatorUserId) {
    const error = new Error('Cannot moderate or kick the room owner');
    error.statusCode = 403;
    error.code = 'CANNOT_MODERATE_OWNER';
    throw error;
  }

  // Room admins cannot moderate themselves via moderation actions (must use leave mic)
  if (!isOwner && targetUserId === actorUserId) {
    const error = new Error('Room Admins cannot remove or moderate themselves via moderation actions; use standard leave mic endpoint');
    error.statusCode = 400;
    error.code = 'CANNOT_MODERATE_SELF';
    throw error;
  }

  // Verify target is actually in this room
  const targetMember = await db.roomMember.findUnique({
    where: { roomId_userId: { roomId: room.id, userId: targetUserId } },
  });
  const occupiedSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.occupiedUserId === targetUserId) : null;

  if (!targetMember && !occupiedSeat) {
    const error = new Error('Selected user is not currently in this room');
    error.statusCode = 404;
    error.code = 'TARGET_NOT_IN_ROOM';
    throw error;
  }

  return { room, isOwner, isAdmin, targetMember, occupiedSeat };
}

export async function removeRoomUserFromMic(roomId, actorUserId, { targetUserId, reason }, db = prisma) {
  const { room, occupiedSeat, targetMember } = await validateModerationPermission(roomId, actorUserId, targetUserId, db);

  if (!occupiedSeat) {
    const error = new Error('Selected user does not occupy a microphone seat');
    error.statusCode = 400;
    error.code = 'USER_NOT_ON_MIC';
    throw error;
  }

  // Atomically release the seat
  await db.roomSeat.update({
    where: { id: occupiedSeat.id },
    data: {
      occupiedUserId: null,
      isMuted: false,
      isMutedByModerator: false,
    },
  });

  // Ensure target user remains in the audience as listener
  if (!targetMember) {
    try {
      await db.roomMember.create({
        data: {
          roomId: room.id,
          userId: targetUserId,
          role: 'MEMBER',
        },
      });
    } catch (_) {}
  }

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const seatPayload = {
    id: `seat_rel_${room.id}_${occupiedSeat.seatIndex}_${targetUserId}_${Date.now()}`,
    eventId: `seat_rel_${room.id}_${occupiedSeat.seatIndex}_${targetUserId}_${Date.now()}`,
    roomId: room.id,
    clientRoomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    seatNumber: occupiedSeat.seatIndex,
    releasedByUserId: actorUserId,
    targetUserId,
    userId: targetUserId,
    previousUserId: targetUserId,
    isModerationAction: true,
    action: 'REMOVE_FROM_MIC',
    seats: snapshot.seats,
    members: snapshot.members,
    viewerCount,
    timestamp: new Date().toISOString(),
  };

  const notificationPayload = {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    seatNumber: occupiedSeat.seatIndex,
    removedByUserId: actorUserId,
    targetUserId,
    reason: reason || 'Removed from microphone seat by room moderator',
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room across all mobile-compatible aliases
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatPayload);
  socketEmitter.emitToRoom(room.id, 'room:seat_released', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room_seat_released', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room:seat_left', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room_seat_left', seatPayload);
  socketEmitter.emitToRoom(room.id, 'seat_released', seatPayload);
  socketEmitter.emitToRoom(room.id, 'seat:released', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room:mic_left', seatPayload);
  socketEmitter.emitToRoom(room.id, 'mic:left', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room:audience_updated', {
    roomId: room.id,
    members: snapshot.members,
    count: viewerCount,
  });

  // Direct target notification
  socketEmitter.emitToUser(targetUserId, 'room:removed_from_mic', notificationPayload);
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatPayload);
  socketEmitter.emitToUser(targetUserId, 'room:seat_released', seatPayload);
  socketEmitter.emitToUser(targetUserId, 'room:seat_left', seatPayload);
  socketEmitter.emitToUser(targetUserId, 'seat_released', seatPayload);

  // Authoritative stage release notification
  try {
    await stageService.notifyStageReleased({
      roomId: room.id,
      seatIndex: occupiedSeat.seatIndex,
      userId: targetUserId,
      releasedByUserId: actorUserId,
      reason: reason || 'REMOVED_FROM_MIC',
    }, db);
  } catch (_) {}

  await logAudit(
    {
      adminId: actorUserId,
      adminName: 'Room Moderator',
      action: 'REMOVE_FROM_MIC',
      targetEntity: 'RoomSeat',
      targetEntityId: occupiedSeat.id,
      reason: `Participant ${targetUserId} removed from mic seat ${occupiedSeat.seatIndex} by moderator: ${reason || 'Action'}`,
    },
    db
  );

  return {
    success: true,
    message: 'User removed from mic successfully',
    data: {
      roomId: room.id,
      targetUserId,
      seatIndex: occupiedSeat.seatIndex,
      seatNumber: occupiedSeat.seatIndex,
      seats: snapshot.seats,
      members: snapshot.members,
    },
  };
}

export async function moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted = true, reason }, db = prisma) {
  const shouldMute = Boolean(isMuted);

  // 1. Handle self-mute by a seated occupant (no moderator privileges required to mute/unmute one's own microphone)
  if (actorUserId && actorUserId === targetUserId) {
    const room = await roomRepository.findRoomById(roomId, db);
    if (!room) {
      const error = new Error('Room not found');
      error.statusCode = 404;
      error.code = 'ROOM_NOT_FOUND';
      throw error;
    }
    const occupiedSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.occupiedUserId === actorUserId) : null;
    if (!occupiedSeat) {
      const error = new Error('You do not occupy a microphone seat in this room');
      error.statusCode = 400;
      error.code = 'USER_NOT_ON_MIC';
      throw error;
    }
    // If the seat was muted by a moderator, the user cannot self-unmute
    if (!shouldMute && occupiedSeat.isMutedByModerator) {
      const error = new Error('Your microphone was muted by a room moderator and cannot be unmuted by yourself');
      error.statusCode = 403;
      error.code = 'MUTED_BY_MODERATOR';
      throw error;
    }

    await db.roomSeat.update({
      where: { id: occupiedSeat.id },
      data: {
        isMuted: shouldMute,
      },
    });

    const updatedRoom = await roomRepository.findRoomById(room.id, db);
    let viewerCount = updatedRoom?.currentViewersCount || 0;
    try {
      const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
      if (typeof presCount === 'number') viewerCount = presCount;
    } catch (_) {}

    const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

    const mutePayload = {
      id: `evt_mute_${room.id}_${occupiedSeat.seatIndex}_${Date.now()}`,
      eventId: `evt_mute_${room.id}_${occupiedSeat.seatIndex}_${Date.now()}`,
      roomId: room.id,
      clientRoomId: room.id,
      targetUserId,
      userId: targetUserId,
      seatIndex: occupiedSeat.seatIndex,
      seatNumber: occupiedSeat.seatIndex,
      isMuted: shouldMute,
      isMutedByModerator: Boolean(occupiedSeat.isMutedByModerator),
      moderatedByUserId: actorUserId,
      seats: snapshot.seats,
      timestamp: new Date().toISOString(),
    };

    const eventName = shouldMute ? SOCKET_EVENTS.ROOM_USER_MUTED : 'room:user_unmuted';
    socketEmitter.emitToRoom(room.id, eventName, mutePayload);
    socketEmitter.emitToRoom(room.id, shouldMute ? 'room:user_muted' : 'room:user_unmuted', mutePayload);
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_UPDATED, mutePayload);
    socketEmitter.emitToRoom(room.id, 'room:seat_updated', mutePayload);
    socketEmitter.emitToRoom(room.id, shouldMute ? 'room:seat_muted' : 'room:seat_unmuted', mutePayload);
    socketEmitter.emitToRoom(room.id, shouldMute ? 'seat_muted' : 'seat_unmuted', mutePayload);

    try {
      await stageService.broadcastStageUpdate(room.id, shouldMute ? 'MIC_MUTED' : 'MIC_UNMUTED', {
        seatIndex: occupiedSeat.seatIndex,
        userId: targetUserId,
        isMuted: shouldMute,
      }, db);
    } catch (_) {}

    return {
      success: true,
      message: shouldMute ? 'Microphone muted' : 'Microphone unmuted',
      data: mutePayload,
    };
  }

  // 2. Authoritative moderator mute/unmute
  const { room, occupiedSeat } = await validateModerationPermission(roomId, actorUserId, targetUserId, db);

  if (shouldMute) {
    const existing = await db.roomModeration.findFirst({
      where: {
        roomId: room.id,
        targetUserId,
        actionType: 'MUTE_MIC',
      },
    });
    if (!existing) {
      await db.roomModeration.create({
        data: {
          roomId: room.id,
          targetUserId,
          actionType: 'MUTE_MIC',
          reason: reason || 'Muted by room moderator',
        },
      });
    }
  } else {
    await db.roomModeration.deleteMany({
      where: {
        roomId: room.id,
        targetUserId,
        actionType: 'MUTE_MIC',
      },
    });
  }

  if (occupiedSeat) {
    await db.roomSeat.update({
      where: { id: occupiedSeat.id },
      data: {
        isMuted: shouldMute,
        isMutedByModerator: shouldMute,
      },
    });
  }

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const mutePayload = {
    id: `evt_mute_${room.id}_${occupiedSeat ? occupiedSeat.seatIndex : 'user'}_${Date.now()}`,
    eventId: `evt_mute_${room.id}_${occupiedSeat ? occupiedSeat.seatIndex : 'user'}_${Date.now()}`,
    roomId: room.id,
    clientRoomId: room.id,
    targetUserId,
    userId: targetUserId,
    seatIndex: occupiedSeat ? occupiedSeat.seatIndex : null,
    seatNumber: occupiedSeat ? occupiedSeat.seatIndex : null,
    isMuted: shouldMute,
    isMutedByModerator: shouldMute,
    moderatedByUserId: actorUserId,
    seats: snapshot.seats,
    timestamp: new Date().toISOString(),
  };

  const eventName = shouldMute ? SOCKET_EVENTS.ROOM_USER_MUTED : 'room:user_unmuted';
  socketEmitter.emitToRoom(room.id, eventName, mutePayload);
  socketEmitter.emitToRoom(room.id, shouldMute ? 'room:user_muted' : 'room:user_unmuted', mutePayload);
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_UPDATED, mutePayload);
  socketEmitter.emitToRoom(room.id, 'room:seat_updated', mutePayload);
  socketEmitter.emitToRoom(room.id, shouldMute ? 'room:seat_muted' : 'room:seat_unmuted', mutePayload);
  socketEmitter.emitToRoom(room.id, shouldMute ? 'seat_muted' : 'seat_unmuted', mutePayload);

  socketEmitter.emitToUser(targetUserId, eventName, mutePayload);
  socketEmitter.emitToUser(targetUserId, shouldMute ? 'room:user_muted' : 'room:user_unmuted', mutePayload);
  socketEmitter.emitToUser(targetUserId, 'room:seat_updated', mutePayload);

  try {
    await stageService.broadcastStageUpdate(room.id, shouldMute ? 'MIC_MUTED' : 'MIC_UNMUTED', {
      seatIndex: occupiedSeat?.seatIndex,
      userId: targetUserId,
      isMuted: shouldMute,
    }, db);
  } catch (_) {}

  await logAudit(
    {
      adminId: actorUserId,
      adminName: 'Room Moderator',
      action: shouldMute ? 'PARTICIPANT_MUTED' : 'PARTICIPANT_UNMUTED',
      targetEntity: 'RoomSeat',
      targetEntityId: occupiedSeat?.id || room.id,
      reason: `Participant ${targetUserId} ${shouldMute ? 'muted' : 'unmuted'} by room moderator: ${reason || 'Action'}`,
    },
    db
  );

  return {
    success: true,
    message: shouldMute ? 'User muted successfully' : 'User unmuted successfully',
    data: mutePayload,
  };
}

export async function kickRoomUser(roomId, actorUserId, { targetUserId, reason }, db = prisma) {
  const { room, occupiedSeat } = await validateModerationPermission(roomId, actorUserId, targetUserId, db);

  await db.$transaction(async (tx) => {
    // 1. Release any seat
    await tx.roomSeat.updateMany({
      where: { roomId: room.id, occupiedUserId: targetUserId },
      data: { occupiedUserId: null, isMuted: false, isMutedByModerator: false },
    });

    // 2. Remove room membership
    await tx.roomMember.deleteMany({
      where: { roomId: room.id, userId: targetUserId },
    });

    // 3. Decrement viewer count if > 0
    await tx.room.updateMany({
      where: { id: room.id, currentViewersCount: { gt: 0 } },
      data: { currentViewersCount: { decrement: 1 } },
    });

    // 4. Record session kick restriction
    await tx.roomModeration.create({
      data: {
        roomId: room.id,
        targetUserId,
        actionType: 'KICK',
        reason: reason || 'Kicked from room by moderator',
        expiresAt: new Date(Date.now() + 86400000),
      },
    });
  }, { maxWait: 15000, timeout: 20000 });

  try {
    await presenceService.leaveRoomPresence(room.id, targetUserId);
  } catch (_) {}
  try {
    await socketEmitter.leaveUserSocketsFromRoom(targetUserId, room.id);
  } catch (_) {}

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const kickPayload = {
    roomId: room.id,
    targetUserId,
    kickedByUserId: actorUserId,
    reason: reason || 'You were kicked from this room by a room moderator',
    seats: snapshot.seats,
    members: snapshot.members,
    viewerCount,
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToRoom(room.id, 'room:user_kicked', kickPayload);
  if (occupiedSeat) {
    const seatRelPayload = {
      roomId: room.id,
      seatIndex: occupiedSeat.seatIndex,
      releasedByUserId: actorUserId,
      targetUserId,
      seats: snapshot.seats,
    };
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatRelPayload);
    socketEmitter.emitToRoom(room.id, 'room:seat_released', seatRelPayload);
  }
  socketEmitter.emitToRoom(room.id, 'room:audience_updated', {
    roomId: room.id,
    members: snapshot.members,
    count: viewerCount,
  });
  socketEmitter.emitToRoom(room.id, 'room:viewer_count_changed', {
    roomId: room.id,
    viewerCount,
    count: viewerCount,
  });

  // Direct target notification
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToUser(targetUserId, 'room:user_kicked', kickPayload);

  await logAudit(
    {
      adminId: actorUserId,
      adminName: 'Room Moderator',
      action: 'PARTICIPANT_KICKED',
      targetEntity: 'Room',
      targetEntityId: room.id,
      reason: `Participant ${targetUserId} kicked from room by moderator: ${reason || 'Action'}`,
    },
    db
  );

  return {
    success: true,
    message: 'User kicked from room successfully',
    data: kickPayload,
  };
}

export async function moderateRoomUser(roomId, actorUserId, { targetUserId, action, isMuted, reason }, db = prisma) {
  const upperAction = String(action || '').toUpperCase();
  if (upperAction === 'REMOVE_FROM_MIC' || upperAction === 'REMOVE_MIC') {
    return await removeRoomUserFromMic(roomId, actorUserId, { targetUserId, reason }, db);
  }
  if (upperAction === 'MUTE') {
    return await moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted: true, reason }, db);
  }
  if (upperAction === 'UNMUTE') {
    return await moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted: false, reason }, db);
  }
  if (upperAction === 'KICK') {
    return await kickRoomUser(roomId, actorUserId, { targetUserId, reason }, db);
  }
  if (isMuted !== undefined) {
    return await moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted, reason }, db);
  }

  const error = new Error('Invalid moderation action specified');
  error.statusCode = 400;
  error.code = 'INVALID_MODERATION_ACTION';
  throw error;
}

export async function adminRemoveFromMic(
  roomId,
  { targetUserId, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const occupiedSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.occupiedUserId === targetUserId) : null;
  if (!occupiedSeat) {
    const error = new Error('Participant does not occupy a microphone seat');
    error.statusCode = 400;
    error.code = 'USER_NOT_ON_MIC';
    throw error;
  }

  await db.roomSeat.update({
    where: { id: occupiedSeat.id },
    data: {
      occupiedUserId: null,
      isMuted: false,
      isMutedByModerator: false,
    },
  });

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const payload = {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    releasedByUserId: adminId || 'admin',
    targetUserId,
    isModerationAction: true,
    action: 'REMOVE_FROM_MIC',
    seats: snapshot.seats,
    members: snapshot.members,
    viewerCount,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_RELEASED, payload);
  socketEmitter.emitToRoom(room.id, 'room:seat_released', payload);
  socketEmitter.emitToRoom(room.id, 'room:audience_updated', {
    roomId: room.id,
    members: snapshot.members,
    count: viewerCount,
  });

  socketEmitter.emitToUser(targetUserId, 'room:removed_from_mic', {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    removedByUserId: adminId || 'admin',
    reason: reason || 'Removed from mic by platform admin',
    timestamp: new Date().toISOString(),
  });
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_SEAT_RELEASED, payload);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'REMOVE_FROM_MIC',
      targetEntity: 'RoomSeat',
      targetEntityId: occupiedSeat.id,
      reason: `Participant ${targetUserId} removed from mic seat by admin: ${reason || 'Admin action'}`,
      ipAddress,
    },
    db
  );

  return { success: true, message: 'Participant removed from mic successfully', data: payload };
}

export async function validateRoomAdminOrOwner(roomId, actorUserId, db = prisma) {
  if (!roomId || typeof roomId !== 'string') {
    const error = new Error('Valid roomId is required');
    error.statusCode = 400;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }

  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase());
  if (!isRoomOpen) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  let actorMember = null;

  if (!isOwner) {
    actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });
    if (actorMember && (actorMember.role === 'ADMIN' || actorMember.role === 'HOST')) {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only room owner or authorized room administrators can perform this action');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  return { room, isOwner, isAdmin, actorMember };
}

export async function clearRoomFeed(roomId, actorUserId, { reason } = {}, db = prisma) {
  const { room, isOwner, isAdmin, actorMember } = await validateRoomAdminOrOwner(roomId, actorUserId, db);

  const clearedAt = new Date().toISOString();

  // Authoritatively record in presence service for stale message filtering on snapshot/reconnect
  try {
    await presenceService.setRoomFeedClearedAt(room.id, clearedAt);
    if (roomId !== room.id) {
      await presenceService.setRoomFeedClearedAt(roomId, clearedAt);
    }
  } catch (presErr) {
    console.warn('[RoomService] Error updating presence feedClearedAt:', presErr.message);
  }

  // Non-destructive room moderation audit log (reusing RoomModeration model)
  try {
    await db.roomModeration.create({
      data: {
        roomId: room.id,
        targetUserId: actorUserId,
        actionType: 'DELETE_CONTENT',
        reason: reason || 'Room feed cleared by room owner/admin',
      },
    });
  } catch (auditErr) {
    console.warn('[RoomService] Non-blocking room moderation audit log notice:', auditErr.message);
  }

  const actorDisplayName = isOwner
    ? (room.creator?.profile?.displayName || room.creator?.username || 'Room Owner')
    : (actorMember?.user?.profile?.displayName || actorMember?.user?.username || 'Room Admin');

  const clearPayload = {
    roomId: room.id,
    clientRoomId: roomId,
    room: room.id,
    clearedAt,
    timestamp: clearedAt,
    clearedBy: actorUserId,
    actorUserId,
    actor: {
      id: actorUserId,
      name: actorDisplayName,
      displayName: actorDisplayName,
      role: isOwner ? 'OWNER' : 'ADMIN',
    },
    reason: reason || 'Room feed cleared',
    isCleared: true,
  };

  // Broadcast realtime feed cleared events to all connected room participants
  try {
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.PARTY_CLEAR_SCREEN, clearPayload);
    socketEmitter.emitToRoom(room.id, 'room:feed_cleared', clearPayload);
    socketEmitter.emitToRoom(room.id, 'party:clear_screen', clearPayload);
    socketEmitter.emitToRoom(room.id, 'feed:cleared', clearPayload);
    socketEmitter.emitToRoom(room.id, 'feed_cleared', clearPayload);

    if (roomId !== room.id) {
      socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
      socketEmitter.emitToRoom(roomId, 'room:feed_cleared', clearPayload);
      socketEmitter.emitToRoom(roomId, 'party:clear_screen', clearPayload);
    }
  } catch (emitErr) {
    console.warn('[RoomService] Error emitting feed cleared socket event:', emitErr.message);
  }

  return {
    success: true,
    message: 'Room feed cleared successfully',
    roomId: room.id,
    clearedAt,
    clearedBy: actorUserId,
    data: clearPayload,
    ...clearPayload,
  };
}

export async function adminClearRoomFeed(roomId, adminId, { reason } = {}, db = prisma) {
  if (!roomId || typeof roomId !== 'string') {
    const error = new Error('Valid roomId is required');
    error.statusCode = 400;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }

  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase());
  if (!isRoomOpen) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  const clearedAt = new Date().toISOString();

  try {
    await presenceService.setRoomFeedClearedAt(room.id, clearedAt);
    if (roomId !== room.id) {
      await presenceService.setRoomFeedClearedAt(roomId, clearedAt);
    }
  } catch (_) {}

  try {
    await db.roomModeration.create({
      data: {
        roomId: room.id,
        targetUserId: adminId,
        actionType: 'DELETE_CONTENT',
        reason: reason || 'Room feed cleared by platform administrator',
      },
    });
  } catch (_) {}

  const clearPayload = {
    roomId: room.id,
    clientRoomId: roomId,
    room: room.id,
    clearedAt,
    timestamp: clearedAt,
    clearedBy: adminId,
    actorUserId: adminId,
    actor: {
      id: adminId,
      name: 'Platform Administrator',
      displayName: 'Platform Administrator',
      role: 'PLATFORM_ADMIN',
    },
    reason: reason || 'Feed cleared by platform administration',
    isCleared: true,
  };

  try {
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.PARTY_CLEAR_SCREEN, clearPayload);
    socketEmitter.emitToRoom(room.id, 'room:feed_cleared', clearPayload);
    socketEmitter.emitToRoom(room.id, 'party:clear_screen', clearPayload);
    socketEmitter.emitToRoom(room.id, 'feed:cleared', clearPayload);

    if (roomId !== room.id) {
      socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
      socketEmitter.emitToRoom(roomId, 'room:feed_cleared', clearPayload);
      socketEmitter.emitToRoom(roomId, 'party:clear_screen', clearPayload);
    }
  } catch (_) {}

  return {
    success: true,
    message: 'Room feed cleared by platform administrator',
    roomId: room.id,
    clearedAt,
    clearedBy: adminId,
    data: clearPayload,
    ...clearPayload,
  };
}

export async function unjoinRoom(roomId, userId, db = prisma) {
  return await roomRepository.unjoinRoomTx({ roomId, userId }, db);
}

export async function getUserJoinedRooms(userId, options = {}, db = prisma) {
  return await roomRepository.getUserJoinedRooms(userId, options, db);
}

/**
 * Live-to-Party switching with server-side confirmation flow support.
 *
 * Requirements (Client Specification - 4 November 2026):
 * 1. Live Host confirms: "End your Live broadcast and join this Party room?".
 * 2. Validate destination party room exists and is valid.
 * 3. End Live broadcast for all viewers (status = 'ENDED', reason = 'HOST_SWITCHED_TO_PARTY').
 * 4. Stop host camera/mic publishing, remove broadcast from discovery.
 * 5. ONLY after Live successfully ends, join selected Party Room (as participant/viewer, normal mic request flow, NO automatic mic occupancy).
 * 6. If joining fails, Live stays ended and returns a retryable error (never restart Live).
 * 7. Atomically serialized per userId using withUserSessionLock.
 */
export async function switchLiveToPartyRoom({ userId, partyRoomId, pin = null }, db = prisma) {
  if (!userId) {
    const error = new Error('Authentication required');
    error.statusCode = 401;
    throw error;
  }
  if (!partyRoomId) {
    const error = new Error('Destination partyRoomId is required');
    error.statusCode = 400;
    throw error;
  }

  return await withUserSessionLock(userId, async () => {
    // 1. Validate destination party room exists
    const partyRoom = await db.room.findUnique({
      where: { id: partyRoomId },
      select: {
        id: true,
        title: true,
        roomType: true,
        status: true,
        creatorUserId: true,
        isPrivate: true,
        roomPin: true,
      },
    });

    if (!partyRoom) {
      const error = new Error('Destination party room not found');
      error.statusCode = 404;
      error.code = 'PARTY_ROOM_NOT_FOUND';
      throw error;
    }

    // 2. Identify if user is hosting an active LIVE broadcast
    const activeLive = await db.room.findFirst({
      where: {
        creatorUserId: userId,
        status: 'LIVE',
        roomType: 'LIVE_VIDEO',
      },
    });

    // 3. If active Live broadcast exists, end it for all viewers
    if (activeLive) {
      try {
        clearHostAbsentTimer(activeLive.id);
        await presenceService.clearRoomLikes(activeLive.id).catch(() => {});
        await presenceService.clearRoomPresence(activeLive.id).catch(() => {});
        await db.room.update({
          where: { id: activeLive.id },
          data: {
            status: 'ENDED',
            endedAt: new Date(),
            currentViewersCount: 0,
          },
        });

        const endPayload = {
          roomId: activeLive.id,
          status: 'ENDED',
          reason: 'HOST_SWITCHED_TO_PARTY',
          message: 'The host has ended this Live broadcast to join a Party room.',
        };
        socketEmitter.emitToRoom(activeLive.id, 'room:closed', endPayload);
        socketEmitter.emitToRoom(activeLive.id, 'room:ended', endPayload);
        socketEmitter.emitToRoom(activeLive.id, 'live:ended', endPayload);
        socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CLOSED, endPayload);
      } catch (liveErr) {
        console.warn('[RoomService] Error ending live broadcast during switch:', liveErr?.message);
      }
    }

    // 4. Join the target Party Room
    // User joins as regular participant/viewer (no automatic mic seat)
    try {
      const joinResult = await joinRoom(
        partyRoom.id,
        userId,
        { pin, explicit: true, isVisitor: false },
        db
      );

      // Update authoritative active session
      await presenceService.setUserActiveSession(userId, {
        roomId: partyRoom.id,
        roomType: partyRoom.roomType,
        role: partyRoom.creatorUserId === userId ? 'HOST' : 'VIEWER',
        isHost: partyRoom.creatorUserId === userId,
        title: partyRoom.title,
      });

      return {
        success: true,
        switched: true,
        liveEnded: Boolean(activeLive),
        partyJoined: true,
        partyRoom: joinResult,
      };
    } catch (joinErr) {
      // If joining fails (e.g. invalid PIN or kicked), Live broadcast remains ended!
      // Never restart Live. Return retryable error payload.
      return {
        success: false,
        liveEnded: Boolean(activeLive),
        partyJoined: false,
        canRetry: true,
        code: joinErr.code || 'PARTY_JOIN_FAILED',
        error: joinErr.message,
      };
    }
  });
}

/**
 * Authoritative endpoint for active-session recovery across reconnects, retries, and network drops.
 */
export async function getUserActiveSession(userId, db = prisma) {
  return await presenceService.getUserActiveSession(userId, db);
}

/**
 * Resolves and returns the complete Agora UID <-> ZeParty User Identity map for a room.
 */
export async function getRoomIdentities(
  roomId,
  { agoraUid = null, userId = null } = {},
  db = prisma
) {
  const roomDetails = await getRoomDetails(roomId, db);
  const participants = Array.isArray(roomDetails?.participants) ? roomDetails.participants : [];
  const agoraUidMap = roomDetails?.agoraUidMap || buildAgoraUidIdentityMap(participants);

  let resolvedIdentity = null;
  if (userId) {
    resolvedIdentity = participants.find((p) => String(p.id || p.userId) === String(userId)) || null;
    if (!resolvedIdentity || !resolvedIdentity.avatarUrl) {
      const dbUser = await userRepository.findById(String(userId), db).catch(() => null);
      if (dbUser) {
        resolvedIdentity = formatAuthoritativeUserIdentity(dbUser, resolvedIdentity || {});
      }
    } else {
      resolvedIdentity = formatAuthoritativeUserIdentity(resolvedIdentity, resolvedIdentity);
    }
  } else if (agoraUid !== null && agoraUid !== undefined && agoraUid !== '') {
    const uidKey = String(agoraUid);
    resolvedIdentity = agoraUidMap[uidKey] || null;
    if (resolvedIdentity) {
      resolvedIdentity = formatAuthoritativeUserIdentity(resolvedIdentity, resolvedIdentity);
    }

    // If not yet in room snapshot map, check connected sockets for matching agoraUid
    if (!resolvedIdentity) {
      const io = socketEmitter.getSocketServerInstance?.();
      if (io?.sockets?.sockets) {
        for (const [, sock] of io.sockets.sockets) {
          const sUid = sock.agoraUid || sock.data?.agoraUid || (sock.userId ? deriveAgoraUid(sock.userId) : null);
          if (sUid && String(sUid) === uidKey && sock.userId) {
            const dbUser = await userRepository.findById(String(sock.userId), db).catch(() => null);
            if (dbUser) {
              resolvedIdentity = formatAuthoritativeUserIdentity(dbUser);
              agoraUidMap[uidKey] = resolvedIdentity;
            }
            break;
          }
        }
      }
    } else if (
      (resolvedIdentity.id || resolvedIdentity.userId) &&
      !String(resolvedIdentity.id || resolvedIdentity.userId).startsWith('guest_') &&
      (!resolvedIdentity.avatarUrl || String(resolvedIdentity.username || '').startsWith('User_'))
    ) {
      const targetUserId = String(resolvedIdentity.id || resolvedIdentity.userId);
      const dbUser = await userRepository.findById(targetUserId, db).catch(() => null);
      if (dbUser) {
        resolvedIdentity = formatAuthoritativeUserIdentity(dbUser, {
          role: resolvedIdentity.role,
          seatIndex: resolvedIdentity.seatIndex,
        });
        agoraUidMap[uidKey] = resolvedIdentity;
      }
    }
  }

  return {
    roomId: roomDetails.id,
    roomType: roomDetails.roomType,
    status: roomDetails.status,
    agoraChannelName: roomDetails.agoraChannelName,
    hostUserId: roomDetails.creatorUserId,
    agoraHostUid: roomDetails.agoraHostUid || deriveAgoraUid(roomDetails.creatorUserId),
    host: roomDetails.host || roomDetails.creator,
    participants,
    agoraUidMap,
    resolvedIdentity,
  };
}

export default {
  createRoom,
  getActiveRooms,
  cleanupStaleRooms,
  getRoomDetails,
  getRoomIdentities,
  enrichRoomIdentitySnapshot,
  joinRoom,
  leaveRoom,
  unjoinRoom,
  getUserJoinedRooms,
  switchLiveToPartyRoom,
  getUserActiveSession,
  withUserSessionLock,
  handleCleanExitFromPreviousRoom,
  occupySeat,
  leaveSeat,
  closeMyRoom,
  getLiveSessionSummary,
  getMyPartyRoom,
  listRoomsForAdmin,
  adminPinRoom,
  adminUnpinRoom,
  adminGetPinnedPositions,
  adminCloseRoom,
  adminIssueWarning,
  adminToggleRoomMute,
  adminMuteParticipant,
  adminKickUser,
  adminRemoveFromMic,
  adminUpdateRoomDp,
  getRoomMembers,
  updateMemberRole,
  getRoomSendingRankings,
  uploadPaidRoomTheme,
  updateRoomBackground,
  removeRoomBackground,
  getRoomBackground,
  updateRoomMicConfig,
  getRoomMicConfig,
  getRoomAnnouncement,
  updateRoomAnnouncement,
  controlRoomYouTube,
  controlSuperWheel,
  controlLuckyBag,
  controlRoomLock,
  updateRoomProfile,
  updateRoomLayout,
  manageMicSeatAction,
  lockRoomSeat,
  sendMicReaction,
  getEntryBannerConfig,
  validateModerationPermission,
  removeRoomUserFromMic,
  moderateRoomUserMute,
  kickRoomUser,
  moderateRoomUser,
  validateRoomAdminOrOwner,
  clearRoomFeed,
  adminClearRoomFeed,
  createMicInvite: micInviteService.createMicInvite,
  acceptMicInvite: micInviteService.acceptMicInvite,
  declineMicInvite: micInviteService.declineMicInvite,
  cancelMicInvite: micInviteService.cancelMicInvite,
  getActiveInviteForUser: micInviteService.getActiveInviteForUser,
};
