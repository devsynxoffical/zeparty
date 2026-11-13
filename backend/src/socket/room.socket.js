import roomRepository from '../repositories/room.repository.js';
import userRepository from '../repositories/user.repository.js';
import userAssetRepository from '../repositories/userAsset.repository.js';
import roomService from '../services/room.service.js';
import micInviteService from '../services/micInvite.service.js';
import cohostInviteService from '../services/cohostInvite.service.js';
import presenceService from './presence.service.js';
import prisma from '../config/database.js';
import {
  startHostAbsentTimer,
  clearHostAbsentTimer,
  clearEmptyRoomSleepTimer,
  checkAndSchedulePartyRoomSleep,
  isPartyRoomType,
} from './roomTimer.manager.js';
import {
  deriveAgoraUid,
  formatAuthoritativeUserIdentity,
  buildAgoraUidIdentityMap,
} from '../utils/agoraToken.util.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';
import * as attendanceService from '../services/attendance.service.js';
import stageService from '../services/stage.service.js';
import privacyEligibilityService from '../services/privacyEligibility.service.js';
import { getNobleStyle } from '../services/asset.service.js';
import roomTrophyService from '../services/roomTrophy.service.js';
import nobleService from '../services/noble.service.js';
import { getAuthoritativeRoomSessionScore } from '../services/roomSession.service.js';
import pkService from '../services/pk.service.js';
import { getRedisClient } from '../config/redis.js';

/**
 * Resolves the authoritative room entry effect for a user based on privilege hierarchy:
 * Priority 1: Explicitly equipped VEHICLE / ENTRY_EFFECT in userAsset
 * Priority 2: Active Noble entrance effect (Emperor, King, Duke, Marquis)
 * Priority 3: Active SVIP entrance effect (SVIP level 6+)
 * Priority 4: Default (null)
 */
export async function resolveUserRoomEntryEffect(userId, prismaInstance = prisma, preloadedUser = null) {
  if (!userId) return null;

  // 1. Explicitly equipped ride / vehicle / entry effect
  try {
    let equippedRecord = null;
    if (Array.isArray(preloadedUser?.userAssets)) {
      const now = new Date();
      equippedRecord = preloadedUser.userAssets.find((ua) => {
        if (!ua?.asset || ua.isEquipped === false) return false;
        if (ua.expiresAt && new Date(ua.expiresAt) <= now) return false;
        const t = String(ua.asset.assetType || '').toUpperCase();
        return t === 'VEHICLE' || t === 'ENTRY_EFFECT';
      }) || null;
    } else {
      equippedRecord = await userAssetRepository.findEquippedEntryEffect(userId, prismaInstance);
    }
    if (equippedRecord?.asset) {
      const a = equippedRecord.asset;
      return {
        id: a.id,
        assetId: a.id,
        name: a.name,
        source: 'EQUIPPED_VEHICLE',
        assetType: a.assetType,
        assetSubcategory: a.assetSubcategory,
        category: a.assetType === 'VEHICLE' ? 'Cars' : (a.assetSubcategory === 'BACKGROUND' ? 'Background' : 'Cars'),
        categoryName: a.assetType === 'VEHICLE' ? 'Cars' : (a.assetSubcategory === 'BACKGROUND' ? 'Background' : 'Cars'),
        thumbnailUrl: a.thumbnailUrl,
        iconUrl: a.thumbnailUrl,
        previewUrl: a.thumbnailUrl,
        animationUrl: a.animationFileUrl || null,
        videoUrl: a.animationFileUrl || null,
        mediaUrl: a.animationFileUrl || a.thumbnailUrl,
        soundUrl: a.soundFileUrl || null,
        durationSeconds: a.durationSeconds || 5,
        defaultVolumePercent: a.defaultVolumePercent || 100,
        userAssetId: equippedRecord.id,
        expiresAt: equippedRecord.expiresAt ? new Date(equippedRecord.expiresAt).toISOString() : null,
      };
    }
  } catch (_) {}

  // 2. Active Noble Entrance Privilege (Marquis, Duke, King, Emperor)
  try {
    const hasPotentialNoble = !preloadedUser?.profile || Boolean(preloadedUser.profile.nobleRank);
    if (hasPotentialNoble) {
      const activeNoble = await nobleService.getActiveNoble(userId, { checkExpiry: true }, prismaInstance);
      if (activeNoble && activeNoble.entranceEffectUrl) {
        const tierLower = String(activeNoble.nobleTier).toLowerCase();
        return {
          id: `noble_entrance_${tierLower}`,
          assetId: `noble_entrance_${tierLower}`,
          name: `${activeNoble.nobleRank || activeNoble.nobleTitle} Royal Entrance`,
          source: 'NOBLE_PRIVILEGE',
          assetType: 'NOBLE_ENTRANCE',
          assetSubcategory: 'ENTRANCE',
          category: 'Nobles',
          categoryName: 'Nobles',
          thumbnailUrl: activeNoble.badgeUrl || activeNoble.entranceEffectUrl,
          iconUrl: activeNoble.badgeUrl || activeNoble.entranceEffectUrl,
          previewUrl: activeNoble.entranceEffectUrl,
          animationUrl: activeNoble.entranceEffectUrl,
          videoUrl: activeNoble.entranceEffectUrl,
          mediaUrl: activeNoble.entranceEffectUrl,
          soundUrl: null,
          durationSeconds: 4,
          defaultVolumePercent: 100,
          nobleTier: activeNoble.nobleTier,
          nobleRank: activeNoble.nobleRank,
        };
      }
    }
  } catch (_) {}

  // 3. Active SVIP Entrance Privilege (SVIP Level 6+)
  try {
    const profile = preloadedUser?.profile !== undefined
      ? preloadedUser.profile
      : await prismaInstance.userProfile.findUnique({
          where: { userId },
          select: { svipLevel: true },
        }).catch(() => null);

    const svipLvl = Number(profile?.svipLevel || 0);
    if (svipLvl >= 6) {
      const svipAsset = `assets/svip/svip-${svipLvl}_entry.webp`;
      return {
        id: `svip_entrance_${svipLvl}`,
        assetId: `svip_entrance_${svipLvl}`,
        name: `SVIP ${svipLvl} Exclusive Entrance`,
        source: 'SVIP_PRIVILEGE',
        assetType: 'SVIP_ENTRANCE',
        assetSubcategory: 'ENTRANCE',
        category: 'SVIP',
        categoryName: 'SVIP',
        thumbnailUrl: svipAsset,
        iconUrl: svipAsset,
        previewUrl: svipAsset,
        animationUrl: svipAsset,
        videoUrl: svipAsset,
        mediaUrl: svipAsset,
        soundUrl: null,
        durationSeconds: 3,
        defaultVolumePercent: 100,
        svipLevel: svipLvl,
      };
    }
  } catch (_) {}

  return null;
}

/**
 * Resolves the authoritative equipped avatar frame for any user object.
 * Checks direct avatarFrame, equippedFrame, profile.avatarFrame, or userAssets.
 */
export function resolveUserAvatarFrame(user) {
  if (!user) return null;
  if (user.avatarFrame && user.avatarFrame !== 'none') return user.avatarFrame;
  if (user.equippedFrame && user.equippedFrame !== 'none') return user.equippedFrame;
  if (user.profile?.avatarFrame && user.profile.avatarFrame !== 'none') return user.profile.avatarFrame;
  if (user.profile?.equippedFrame && user.profile.equippedFrame !== 'none') return user.profile.equippedFrame;
  if (Array.isArray(user.userAssets)) {
    for (const ua of user.userAssets) {
      const asset = ua.asset;
      if (!asset) continue;
      const type = (asset.assetType || '').toUpperCase();
      if (type === 'FRAME' && ua.isEquipped !== false) {
        return asset.thumbnailUrl || asset.staticFileUrl || asset.animationFileUrl || asset.name || null;
      }
    }
  }
  if (Array.isArray(user.equippedAssets)) {
    for (const eq of user.equippedAssets) {
      const type = (eq.assetType || '').toUpperCase();
      if (type === 'FRAME') {
        return eq.imageUrl || eq.name || null;
      }
    }
  }
  return null;
}

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

  const activePresenceSet = new Set(
    (activePresenceUsers || []).map((u) => u.userId || u.id).filter(Boolean)
  );
  const activeSet = new Set(activePresenceSet);
  for (const s of room.seats || []) {
    if (s.occupiedUserId) activeSet.add(s.occupiedUserId);
  }
  if (hostUserId && hostIsOccupyingSeat) activeSet.add(hostUserId);

  const membersList = (room.members || [])
    .filter((m) => {
      const mid = m.userId || m.user?.id;
      // If host is occupying a seat, do not duplicate in audience list
      if (mid === hostUserId && hostIsOccupyingSeat) {
        return false;
      }
      // Stale member exclusion: when active presence list is explicitly populated, exclude departed members
      if (activePresenceSet.size > 0 && !activeSet.has(mid)) {
        return false;
      }
      return true;
    })
    .map((m) => {
      const u = m.user || {};
      const mid = m.userId || u.id;
      const isHost = mid === hostUserId;
      const displayName = u.profile?.displayName || u.displayName || u.username || (isHost ? 'Host' : 'User');
      const isRoomAdmin = (m.role === 'ADMIN' || m.role === 'MODERATOR');
      const memberFrame = resolveUserAvatarFrame(u);
      const memberAgoraUid = mid ? deriveAgoraUid(mid) : null;
      const memberAvatarUrl = u.avatarUrl || u.profile?.avatarUrl || null;
      return {
        userId: mid,
        agoraUid: memberAgoraUid,
        uid: memberAgoraUid,
        role: isHost ? 'HOST' : (isRoomAdmin ? 'ADMIN' : (m.role || 'LISTENER')),
        isHost,
        isOwner: isHost,
        user: {
          id: mid,
          userId: mid,
          agoraUid: memberAgoraUid,
          uid: memberAgoraUid,
          username: u.username || displayName,
          displayName,
          name: displayName,
          avatarUrl: memberAvatarUrl,
          avatar: memberAvatarUrl,
          avatarFrame: memberFrame,
          equippedFrame: memberFrame,
          level: u.profile?.level || 1,
          vipLevel: u.profile?.vipLevel || 0,
          svipLevel: u.profile?.svipLevel || 0,
          nobleRank: u.profile?.nobleRank || null,
          nobleTitle: u.profile?.nobleRank || null,
        },
      };
    });

  const existingMemberIds = new Set(membersList.map((m) => m.userId));

  // If host is NOT occupying a seat, ensure host is included in audience exactly once
  if (!hostIsOccupyingSeat && hostUserId && !existingMemberIds.has(hostUserId)) {
    const hostUser = room.creator || {};
    const hostDisplayName = hostUser.profile?.displayName || hostUser.displayName || hostUser.username || 'Host';
    const hostFrame = resolveUserAvatarFrame(hostUser);
    const hostAgoraUid = deriveAgoraUid(hostUserId);
    const hostAvatarUrl = hostUser.avatarUrl || hostUser.profile?.avatarUrl || null;
    membersList.unshift({
      userId: hostUserId,
      agoraUid: hostAgoraUid,
      uid: hostAgoraUid,
      role: 'HOST',
      isHost: true,
      isOwner: true,
      user: {
        id: hostUserId,
        userId: hostUserId,
        agoraUid: hostAgoraUid,
        uid: hostAgoraUid,
        username: hostUser.username || hostDisplayName,
        displayName: hostDisplayName,
        name: hostDisplayName,
        avatarUrl: hostAvatarUrl,
        avatar: hostAvatarUrl,
        avatarFrame: hostFrame,
        equippedFrame: hostFrame,
        level: hostUser.profile?.level || 1,
        vipLevel: hostUser.profile?.vipLevel || 0,
        svipLevel: hostUser.profile?.svipLevel || 0,
        nobleRank: hostUser.profile?.nobleRank || null,
        nobleTitle: hostUser.profile?.nobleRank || null,
      },
    });
    existingMemberIds.add(hostUserId);
  }

  // Merge active presence participants
  for (const pres of (activePresenceUsers || [])) {
    const pid = pres.userId || pres.id;
    if (pid && !existingMemberIds.has(pid)) {
      if (pid === hostUserId && hostIsOccupyingSeat) {
        continue;
      }
      const isHost = pid === hostUserId;
      const guestDisplayName = pres.displayName || pres.name || pres.username || (isHost ? 'Host' : `User_${String(pid).replace('guest_', '').substring(0, 5)}`);
      const guestFrame = resolveUserAvatarFrame(pres);
      const presAgoraUid = pres.agoraUid || pres.uid || deriveAgoraUid(pid);
      membersList.push({
        userId: pid,
        agoraUid: presAgoraUid,
        uid: presAgoraUid,
        role: isHost ? 'HOST' : 'LISTENER',
        isHost,
        isOwner: isHost,
        user: {
          id: pid,
          userId: pid,
          agoraUid: presAgoraUid,
          uid: presAgoraUid,
          username: pres.username || guestDisplayName,
          displayName: guestDisplayName,
          name: guestDisplayName,
          avatarUrl: pres.avatarUrl || null,
          avatar: pres.avatarUrl || null,
          avatarFrame: guestFrame,
          equippedFrame: guestFrame,
          level: pres.level || 1,
          vipLevel: pres.vipLevel || 0,
          svipLevel: pres.svipLevel || 0,
          nobleRank: pres.nobleRank || pres.nobleTitle || null,
          nobleTitle: pres.nobleTitle || pres.nobleRank || null,
        },
      });
      existingMemberIds.add(pid);
    }
  }

  const hasPin = Boolean(room.roomPin);
  const lockMode = hasPin ? 'PIN' : (room.isPrivate ? 'Approval' : 'NONE');
  const hostAgoraUid = hostUserId ? deriveAgoraUid(hostUserId) : null;
  const hostAvatarResolved = room.creator?.avatarUrl || room.creator?.profile?.avatarUrl || null;
  const hostDisplayNameResolved = room.creator?.profile?.displayName || room.creator?.displayName || room.creator?.username || 'Host';

  const formattedSeats = (room.seats || []).map((s) => {
    const u = s.occupiedUser || s.user;
    const isOccupied = Boolean(u && s.occupiedUserId);
    const seatUserFrame = isOccupied ? resolveUserAvatarFrame(u) : null;
    const occupantId = isOccupied ? (u.id || s.occupiedUserId) : null;
    const seatAgoraUid = occupantId ? deriveAgoraUid(occupantId) : null;
    const occupantAvatar = isOccupied ? (u.avatarUrl || u.profile?.avatarUrl || null) : null;
    const occupantDisplayName = isOccupied ? (u.profile?.displayName || u.displayName || u.username) : null;
    return {
      seatIndex: s.seatIndex,
      seatNumber: s.seatIndex,
      occupiedUserId: occupantId,
      agoraUid: seatAgoraUid,
      uid: seatAgoraUid,
      isLocked: Boolean(s.isLocked),
      isMuted: Boolean(s.isMuted),
      isMutedByModerator: Boolean(s.isMutedByModerator),
      user: isOccupied ? {
        id: u.id,
        userId: u.id,
        agoraUid: seatAgoraUid,
        uid: seatAgoraUid,
        username: u.username,
        displayName: occupantDisplayName,
        name: occupantDisplayName,
        avatarUrl: occupantAvatar,
        avatar: occupantAvatar,
        avatarFrame: seatUserFrame,
        equippedFrame: seatUserFrame,
        level: u.profile?.level || 1,
        vipLevel: u.profile?.vipLevel || 0,
        svipLevel: u.profile?.svipLevel || 0,
        nobleTitle: u.profile?.nobleRank || u.nobleTitle || u.nobleLevel || null,
        nobleLevel: u.profile?.nobleRank || u.nobleTitle || u.nobleLevel || null,
        nobleRank: u.profile?.nobleRank || u.nobleTitle || u.nobleLevel || null,
        nobleColor: getNobleStyle(u.profile?.nobleRank || u.nobleTitle || u.nobleLevel)?.color || null,
        nobleStyle: getNobleStyle(u.profile?.nobleRank || u.nobleTitle || u.nobleLevel),
      } : null,
    };
  });

  const hostObject = room.creator ? {
    id: room.creator.id,
    userId: room.creator.id,
    agoraUid: hostAgoraUid,
    uid: hostAgoraUid,
    username: room.creator.username,
    displayName: hostDisplayNameResolved,
    name: hostDisplayNameResolved,
    avatarUrl: hostAvatarResolved,
    avatar: hostAvatarResolved,
    avatarFrame: resolveUserAvatarFrame(room.creator),
    equippedFrame: resolveUserAvatarFrame(room.creator),
    level: room.creator.profile?.level || 1,
    vipLevel: room.creator.profile?.vipLevel || 0,
    svipLevel: room.creator.profile?.svipLevel || 0,
    nobleTitle: room.creator.profile?.nobleRank || room.creator.nobleTitle || null,
    nobleLevel: room.creator.profile?.nobleRank || room.creator.nobleTitle || null,
    nobleRank: room.creator.profile?.nobleRank || room.creator.nobleTitle || null,
  } : null;

  // Build authoritative Agora UID -> ZeParty User Identity map
  const agoraUidMap = {};
  if (hostObject && hostObject.agoraUid) {
    agoraUidMap[String(hostObject.agoraUid)] = {
      ...hostObject,
      role: 'HOST',
      isHost: true,
      seatIndex: 0,
    };
  }
  for (const s of formattedSeats) {
    if (s.agoraUid && s.user) {
      agoraUidMap[String(s.agoraUid)] = {
        ...s.user,
        role: s.seatIndex === 0 ? 'HOST' : (s.seatIndex === 1 ? 'CO_HOST' : 'SPEAKER'),
        seatIndex: s.seatIndex,
        isMuted: s.isMuted,
      };
    }
  }
  for (const m of membersList) {
    if (m.agoraUid && m.user && !agoraUidMap[String(m.agoraUid)]) {
      agoraUidMap[String(m.agoraUid)] = {
        ...m.user,
        role: m.role,
        isHost: m.isHost,
        seatIndex: null,
      };
    }
  }

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
    themeUrl: room.backgroundImageUrl || null,
    theme: room.backgroundImageUrl || null,
    coverImageUrl: room.coverImageUrl || null,
    coverUrl: room.coverImageUrl || null,
    isPinned: Boolean(room.isPinned),
    pinPosition: room.pinPosition || null,
    currentViewersCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    viewerCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    feedClearedAt: room.feedClearedAt || null,
    agoraChannelName: room.agoraChannelName || null,
    agoraHostUid: hostAgoraUid,
    agoraUidMap,
    isLocked: Boolean(room.isPrivate),
    lockMode,
    seatCapacity: (room.seats || []).length || 10,
    capacity: (room.seats || []).length || 10,
    roomSendingTotal: room.roomSendingTotal !== undefined ? room.roomSendingTotal : (room.dailySendingTotal || 0),
    dailySendingTotal: room.dailySendingTotal !== undefined ? room.dailySendingTotal : (room.roomSendingTotal || 0),
    periodTotalCoins: room.periodTotalCoins !== undefined ? room.periodTotalCoins : (room.roomSendingTotal || 0),
    trophyCoins: room.trophyCoins !== undefined ? room.trophyCoins : (room.roomSendingTotal || 0),
    sessionId: room.sessionId || room.activeSessionId || null,
    sessionStartedAt: room.sessionStartedAt ? (room.sessionStartedAt instanceof Date ? room.sessionStartedAt.toISOString() : String(room.sessionStartedAt)) : null,
    host: hostObject,
    seats: formattedSeats,
    coHost: (() => {
      const coHostSeat = (room.seats || []).find((s) => s.seatIndex === 1 && s.occupiedUserId);
      const coHostUser = coHostSeat ? (coHostSeat.occupiedUser || coHostSeat.user) : null;
      if (!coHostUser) return null;
      const dName = coHostUser.profile?.displayName || coHostUser.displayName || coHostUser.username || 'Co-Host';
      const coHostFrame = resolveUserAvatarFrame(coHostUser);
      const agoraUid = deriveAgoraUid(coHostUser.id);
      const coHostAvatar = coHostUser.avatarUrl || coHostUser.profile?.avatarUrl || null;
      return {
        id: coHostUser.id,
        userId: coHostUser.id,
        username: coHostUser.username,
        displayName: dName,
        name: dName,
        avatarUrl: coHostAvatar,
        avatar: coHostAvatar,
        avatarFrame: coHostFrame,
        equippedFrame: coHostFrame,
        seatIndex: 1,
        seatNumber: 1,
        isCoHost: true,
        role: 'CO_HOST',
        agoraUid,
        uid: agoraUid,
        mediaUid: agoraUid,
        hasAudio: true,
        hasVideo: true,
        videoState: 'active',
        audioState: 'active',
        connectionState: 'CONNECTED',
      };
    })(),
    cohosts: (() => {
      const coHostSeat = (room.seats || []).find((s) => s.seatIndex === 1 && s.occupiedUserId);
      const coHostUser = coHostSeat ? (coHostSeat.occupiedUser || coHostSeat.user) : null;
      if (!coHostUser) return [];
      const dName = coHostUser.profile?.displayName || coHostUser.displayName || coHostUser.username || 'Co-Host';
      const coHostFrame = resolveUserAvatarFrame(coHostUser);
      const agoraUid = deriveAgoraUid(coHostUser.id);
      const coHostAvatar = coHostUser.avatarUrl || coHostUser.profile?.avatarUrl || null;
      return [{
        id: coHostUser.id,
        userId: coHostUser.id,
        username: coHostUser.username,
        displayName: dName,
        name: dName,
        avatarUrl: coHostAvatar,
        avatar: coHostAvatar,
        avatarFrame: coHostFrame,
        equippedFrame: coHostFrame,
        seatIndex: 1,
        seatNumber: 1,
        isCoHost: true,
        role: 'CO_HOST',
        agoraUid,
        uid: agoraUid,
        mediaUid: agoraUid,
        hasAudio: true,
        hasVideo: true,
        videoState: 'active',
        audioState: 'active',
        connectionState: 'CONNECTED',
      }];
    })(),
    stage: (room.seats || []).map((s) => {
      const u = s.occupiedUser || s.user;
      const isOccupied = Boolean(u && s.occupiedUserId);
      const stageUid = isOccupied ? deriveAgoraUid(u.id || s.occupiedUserId) : null;
      const stageAvatar = isOccupied ? (u.avatarUrl || u.profile?.avatarUrl || null) : null;
      return {
        slotIndex: s.seatIndex,
        seatIndex: s.seatIndex,
        seatNumber: s.seatIndex,
        occupiedUserId: isOccupied ? (u.id || s.occupiedUserId) : null,
        userId: isOccupied ? (u.id || s.occupiedUserId) : null,
        user: isOccupied ? {
          id: u.id,
          userId: u.id,
          agoraUid: stageUid,
          uid: stageUid,
          username: u.username,
          displayName: u.profile?.displayName || u.displayName || u.username,
          name: u.profile?.displayName || u.displayName || u.username,
          avatarUrl: stageAvatar,
          avatar: stageAvatar,
        } : null,
        isLocked: Boolean(s.isLocked),
        isMuted: Boolean(s.isMuted),
        isCoHost: s.seatIndex === 1 && isOccupied,
        agoraUid: stageUid,
        uid: stageUid,
      };
    }),
    isCoHosting: Boolean((room.seats || []).some((s) => s.seatIndex === 1 && s.occupiedUserId)),
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


/** RTC-DIAG: userIds of the sockets currently subscribed to a room channel (local adapter view). */
export function describeRoomChannel(socket, roomId) {
  try {
    const ids = socket.nsp?.adapter?.rooms?.get(`room:${roomId}`);
    if (!ids) return 'members=0 []';
    const users = [];
    for (const sid of ids) {
      const s = socket.nsp.sockets.get(sid);
      users.push(`${s?.userId ?? '?'}@${sid.slice(0, 6)}`);
    }
    return `members=${users.length} [${users.join(', ')}]`;
  } catch (e) {
    return `members=? (${e?.message})`;
  }
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
    const attemptId = data?.attemptId || null;
    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [ROOM_JOIN_REQ] socket=${socket.id} user=${userId} room=${roomId} isGuest=${socket.isGuest}`);

    // 1. Authoritative Room Existence and Lifecycle Check
    let room = await roomRepository.findRoomById(roomId, db || prisma);
    if (!room) {
      const err = { success: false, attemptId, error: { code: SOCKET_ERRORS.ROOM_NOT_FOUND, message: 'Room not found', stage: 'ROOM_LIFECYCLE', recoverable: false } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    clearEmptyRoomSleepTimer(room.id);

    if (room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(room.status.toUpperCase())) {
      // Persistent Party Room Wake-from-Sleep:
      // Only legitimately sleeping rooms (status === 'ENDED') may wake up.
      // Moderation-restricted rooms (CLOSED_BY_ADMIN, HOST_KICKED) must never wake.
      if (isPartyRoomType(room.roomType) && room.status.toUpperCase() === 'ENDED') {
        await (db || prisma).room.updateMany({
          where: { id: room.id, status: 'ENDED' },
          data: { status: 'LIVE', endedAt: null },
        }).catch(() => {});
        const refreshed = await roomRepository.findRoomById(room.id, db || prisma);
        if (refreshed) {
          room = refreshed;
        } else {
          room.status = 'LIVE';
        }
      } else {
        // For solo LIVE_VIDEO, auto-resolve to creator's active live room session if available
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
          const err = { success: false, attemptId, error: { code: SOCKET_ERRORS.ROOM_NOT_LIVE, message: 'Room is not available or has ended', stage: 'ROOM_LIFECYCLE', recoverable: false } };
          if (typeof callback === 'function') return callback(err);
          return socket.emit(SOCKET_EVENTS.ERROR, err);
        }
      }
    }

    // 2. Persistent RoomMember registration via authoritative Room Service
    let joinResult = null;
    try {
      const pin = data?.pin || data?.password || data?.roomPin;
      const isApproved = Boolean(data?.isApproved);
      const explicit = Boolean(data?.explicit);
      const isVisitor = data?.isVisitor !== undefined ? Boolean(data.isVisitor) : !explicit;
      joinResult = await roomService.joinRoom(
        room.id,
        userId,
        { pin, isApproved, attemptId, explicit, isVisitor },
        db || prisma
      );
    } catch (joinErr) {
      console.error(`[RoomSocket] Error joining room ${roomId} for user ${userId}:`, joinErr.message || joinErr);
      throw joinErr;
    }

    // 3. Immediately subscribe socket to room channel after successful roomService.joinRoom()
    if (typeof socket.join === 'function') {
      await socket.join(`room:${room.id}`);
      if (room.id !== roomId) {
        await socket.join(`room:${roomId}`);
      }
    }
    socket.joinedRooms = socket.joinedRooms || new Set();
    socket.joinedRooms.add(roomId);
    socket.joinedRooms.add(room.id);
    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [ROOM_JOIN_SUCCESS] socket=${socket.id} user=${userId} room=${room.id} ${describeRoomChannel(socket, room.id)}`);

    // Cancel any active host absence timer if host returned
    const isHostUser = room.creatorUserId === userId || room.creator?.id === userId;
    if (isHostUser) {
      clearHostAbsentTimer(room.id, io);
    }

    const clientUser = data?.user || {};
    const effectiveJoinedId = userId;
    const isGuestUser = Boolean(socket.isGuest || String(effectiveJoinedId).startsWith('guest_'));
    const fallbackGuestName = String(effectiveJoinedId).startsWith('guest_')
      ? `User_${String(effectiveJoinedId).replace('guest_', '').substring(0, 5)}`
      : `User_${String(effectiveJoinedId).substring(0, 6)}`;

    let dbJoinedUser = null;
    if (!isGuestUser && effectiveJoinedId) {
      if (socket.user && socket.user.id === effectiveJoinedId && socket.user.username && socket.user.profile) {
        dbJoinedUser = socket.user;
      } else {
        try {
          const lookupFn = userRepository.findByIdForIdentity || userRepository.findById;
          dbJoinedUser = await lookupFn(effectiveJoinedId);
        } catch (_) {}
      }
    }

    // Authoritative ZeParty user identity takes strict precedence over unverified client fields
    const effectiveJoinedUsername =
      dbJoinedUser?.username ||
      (!isGuestUser ? socket.user?.username : null) ||
      clientUser.username ||
      fallbackGuestName;
    const effectiveJoinedName =
      dbJoinedUser?.profile?.displayName ||
      dbJoinedUser?.displayName ||
      dbJoinedUser?.username ||
      (!isGuestUser ? (socket.user?.displayName || socket.user?.name || socket.user?.username) : null) ||
      clientUser.displayName ||
      clientUser.name ||
      clientUser.username ||
      fallbackGuestName;
    const effectiveJoinedAvatar =
      dbJoinedUser?.avatarUrl ||
      dbJoinedUser?.profile?.avatarUrl ||
      (!isGuestUser ? (socket.user?.avatarUrl || socket.user?.profile?.avatarUrl) : null) ||
      clientUser.avatarUrl ||
      null;
    const effectiveJoinedVip = Boolean(
      (dbJoinedUser?.profile?.vipLevel ?? 0) > 0 ||
      (dbJoinedUser?.profile?.svipLevel ?? 0) > 0 ||
      socket.user?.isVip ||
      clientUser.isVip
    );
    const effectiveJoinedNoble =
      dbJoinedUser?.profile?.nobleRank ||
      socket.user?.nobleTitle ||
      socket.user?.nobleRank ||
      clientUser.nobleTitle ||
      null;
    const joinedAgoraUid = effectiveJoinedId ? deriveAgoraUid(effectiveJoinedId) : null;

    // 4. Ephemeral Presence Tracking with rich user metadata
    let isFirstSocket = true;
    try {
      const pres = await presenceService.addSocketToRoom(room.id, effectiveJoinedId, socket.id, {
        id: effectiveJoinedId,
        userId: effectiveJoinedId,
        agoraUid: joinedAgoraUid,
        uid: joinedAgoraUid,
        username: effectiveJoinedUsername,
        displayName: effectiveJoinedName,
        name: effectiveJoinedName,
        avatarUrl: effectiveJoinedAvatar,
        nobleRank: effectiveJoinedNoble,
        nobleTitle: effectiveJoinedNoble,
        vipLevel: dbJoinedUser?.profile?.vipLevel || socket.user?.vipLevel || 0,
        svipLevel: dbJoinedUser?.profile?.svipLevel || socket.user?.svipLevel || 0,
        level: dbJoinedUser?.profile?.level || socket.user?.level || 1,
        isGuest: isGuestUser,
        joinedAt: new Date().toISOString(),
      });
      isFirstSocket = pres?.isFirstSocket ?? true;
    } catch (_) {}

    // 5. Generate and Send Authoritative Room Snapshot (parallelized to minimize DB round-trip latency)
    const sessionStart = room.createdAt ? new Date(room.createdAt) : new Date(0);
    const [
      currentCountResult,
      activeUsersResult,
      feedClearedAtResult,
      recentTxsResult,
      trophyDataResult,
      totalLikesResult,
      activePkBattleResult,
      stageSnapResult,
    ] = await Promise.all([
      presenceService.getRoomViewerCount(room.id, room.creatorUserId).catch(() => null),
      presenceService.getRoomActiveUsers(room.id).catch(() => []),
      presenceService.getRoomFeedClearedAt(room.id).catch(() => null),
      (db || prisma).giftTransaction.findMany({
        where: { roomId: room.id, createdAt: { gte: sessionStart } },
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: {
          gift: { select: { id: true, name: true, iconUrl: true } },
          sender: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
          recipient: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
        },
      }).catch(() => []),
      joinResult?.roomSendingTotal !== undefined
        ? Promise.resolve({
            sessionScore: joinResult.roomSendingTotal,
            sessionId: joinResult.sessionId || null,
            sessionStartedAt: joinResult.sessionStartedAt || null,
          })
        : getAuthoritativeRoomSessionScore(room.id, db || prisma).catch(() => ({ sessionScore: 0, sessionId: null, sessionStartedAt: null })),
      joinResult?.totalLikes !== undefined
        ? Promise.resolve(joinResult.totalLikes)
        : presenceService.getRoomLikes(room.id).catch(() => 0),
      pkService.getActiveMatchForRoom(room.id).catch(() => null),
      stageService.getStageSnapshot(room, db || prisma).catch(() => null),
    ]);

    const currentCount = typeof currentCountResult === 'number'
      ? currentCountResult
      : (typeof joinResult?.currentViewersCount === 'number'
        ? joinResult.currentViewersCount
        : (typeof room.currentViewersCount === 'number' ? room.currentViewersCount : 1));
    const activeUsers = Array.isArray(activeUsersResult) ? activeUsersResult : [];
    const feedClearedAt = feedClearedAtResult || null;
    const recentGifts = (Array.isArray(recentTxsResult) ? recentTxsResult : []).slice().reverse().map((tx) => ({
      id: tx.id,
      transactionId: tx.id,
      eventId: `hist_gift_${tx.id}`,
      isHistorical: true,
      isLive: false,
      playbackType: 'HISTORY_ONLY',
      replayAnimation: false,
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

    const sessionScore = trophyDataResult?.sessionScore || 0;
    const activeSessionId = trophyDataResult?.sessionId || room.activeSessionId || null;
    const activeSessionStartedAt = trophyDataResult?.sessionStartedAt || (room.sessionStartedAt ? new Date(room.sessionStartedAt).toISOString() : null);

    room.dailySendingTotal = sessionScore;
    room.roomSendingTotal = sessionScore;
    room.periodTotalCoins = sessionScore;
    room.trophyCoins = sessionScore;
    room.sessionId = activeSessionId;
    room.sessionStartedAt = activeSessionStartedAt;

    const totalLikes = totalLikesResult || 0;
    const activePkBattle = activePkBattleResult || null;

    const snapshot = buildRoomSnapshot(room, currentCount, activeUsers);
    snapshot.attemptId = attemptId;
    snapshot.feedClearedAt = feedClearedAt;
    snapshot.recentGifts = recentGifts;
    snapshot.dailySendingTotal = sessionScore;
    snapshot.roomSendingTotal = sessionScore;
    snapshot.periodTotalCoins = sessionScore;
    snapshot.trophyCoins = sessionScore;
    snapshot.sessionId = activeSessionId;
    snapshot.sessionStartedAt = activeSessionStartedAt;
    snapshot.totalLikes = totalLikes;
    snapshot.likesCount = totalLikes;
    if (activePkBattle) {
      snapshot.activePkBattle = activePkBattle;
      snapshot.pkBattle = activePkBattle;
    }
    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, {
      room: snapshot,
      ...snapshot,
      activePkBattle,
      pkBattle: activePkBattle,
      seats: snapshot.seats || [],
      members: snapshot.members || [],
      currentViewersCount: currentCount,
      viewerCount: currentCount,
      feedClearedAt,
      recentGifts,
      totalLikes,
      likesCount: totalLikes,
    });

    if (stageSnapResult) {
      socket.emit('room:stage_snapshot', stageSnapResult);
      socket.emit('stage:snapshot', stageSnapResult);
      socket.emit('room:stage_updated', stageSnapResult);
    }

    // 6. Broadcast user joined event and authoritative viewer count to all room participants
    const targetRoomIds = Array.from(new Set([String(roomId), String(room.id)]));
    const roomChannelNames = targetRoomIds.map((id) => `room:${id}`);
    const broadcastTarget = io
      ? io.to(roomChannelNames)
      : (socket.to ? socket.to(`room:${roomId}`) : socket);

    const entryTimestamp = new Date().toISOString();
    const entryEventId = `entry_${room.id}_${effectiveJoinedId}_${Date.now()}`;

    // Authoritative Viewer Count Payload: ALWAYS broadcast to all room channels
    const viewerPayload = {
      roomId: room.id,
      clientRoomId: roomId,
      room: room.id,
      viewerCount: currentCount,
      count: currentCount,
      currentViewersCount: currentCount,
      timestamp: entryTimestamp,
    };

    if (io) {
      io.to(roomChannelNames).emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
      io.to(roomChannelNames).emit('room:viewer_count', viewerPayload);
      io.to(roomChannelNames).emit('viewer_count_changed', viewerPayload);
    } else if (socket.to) {
      socket.to(roomChannelNames).emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
    }
    if (socket && typeof socket.emit === 'function') {
      socket.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
      socket.emit('room:viewer_count', viewerPayload);
      socket.emit('viewer_count_changed', viewerPayload);
    }

    // Always broadcast user joined on explicit room join

      // Resolve stealth entry & room-entry effect in parallel (using preloaded dbJoinedUser to avoid redundant DB queries)
      let isStealthEntry = false;
      let equippedEntryEffect = null;
      if (!isGuestUser && effectiveJoinedId) {
        const [stealthCheck, resolvedEffect] = await Promise.all([
          (async () => {
            try {
              const prefs = await privacyEligibilityService.getUserPreferences(effectiveJoinedId, prisma);
              if (prefs.ROOM_INVISIBLE || prefs.STEALTH_ENTRY) {
                const eligibility = await privacyEligibilityService.checkUserEligibility(effectiveJoinedId, 'ROOM_INVISIBLE', prisma);
                return Boolean(eligibility.isEligible);
              }
            } catch (_) {}
            return false;
          })(),
          resolveUserRoomEntryEffect(effectiveJoinedId, prisma, dbJoinedUser).catch(() => null),
        ]);
        isStealthEntry = stealthCheck;
        if (!isStealthEntry) {
          equippedEntryEffect = resolvedEffect;
        }
      }

      // Reconnect Debounce Check (10-second cooldown window to prevent animation/audio spam on socket reconnect)
      let isDebouncedReconnect = false;
      if (effectiveJoinedId && room.id) {
        const debounceKey = `presence:entry_debounced:${room.id}:${effectiveJoinedId}`;
        try {
          const client = getRedisClient();
          if (client && client.isOpen) {
            const debounced = await client.get(debounceKey);
            if (debounced) {
              isDebouncedReconnect = true;
            } else {
              await client.set(debounceKey, '1', { EX: 10 });
            }
          }
        } catch (_) {}
      }

      const suppressAnimation = Boolean(isDebouncedReconnect);
      const activeEntryEffect = equippedEntryEffect ? {
        ...equippedEntryEffect,
        suppressAnimation,
        isDebouncedReconnect,
      } : null;

      const joinedFrame = resolveUserAvatarFrame(dbJoinedUser) ||
        resolveUserAvatarFrame(socket.user) ||
        resolveUserAvatarFrame(clientUser) ||
        socket.user?.avatarFrame ||
        socket.user?.equippedFrame ||
        clientUser.avatarFrame ||
        clientUser.equippedFrame ||
        null;

      const userPayload = {
        id: entryEventId,
        eventId: entryEventId,
        entryId: entryEventId,
        entryEventId,
        dedupKey: `${room.id}:${effectiveJoinedId}:${entryEventId}`,
        roomId: room.id,
        clientRoomId: roomId,
        room: room.id,
        userId: effectiveJoinedId,
        agoraUid: joinedAgoraUid,
        uid: joinedAgoraUid,
        avatarFrame: joinedFrame,
        equippedFrame: joinedFrame,
        user: {
          id: effectiveJoinedId,
          userId: effectiveJoinedId,
          username: effectiveJoinedUsername,
          name: effectiveJoinedName,
          displayName: effectiveJoinedName,
          avatarUrl: effectiveJoinedAvatar,
          avatar: effectiveJoinedAvatar,
          avatarFrame: joinedFrame,
          equippedFrame: joinedFrame,
          isVip: effectiveJoinedVip,
          nobleLevel: effectiveJoinedNoble,
          nobleTitle: effectiveJoinedNoble,
          nobleRank: effectiveJoinedNoble,
          nobleColor: getNobleStyle(effectiveJoinedNoble)?.color || null,
          nobleStyle: getNobleStyle(effectiveJoinedNoble),
          isGuest: isGuestUser,
          agoraUid: joinedAgoraUid,
          uid: joinedAgoraUid,
        },
        nobleColor: getNobleStyle(effectiveJoinedNoble)?.color || null,
        nobleStyle: getNobleStyle(effectiveJoinedNoble),
        suppressAnimation,
        isDebouncedReconnect,
        entryEffect: activeEntryEffect,
        equippedRide: activeEntryEffect,
        entryEffectId: activeEntryEffect?.id || null,
        entryEffectName: activeEntryEffect?.name || null,
        viewerCount: currentCount,
        count: currentCount,
        currentViewersCount: currentCount,
        timestamp: entryTimestamp,
        isStealth: isStealthEntry,
      };

      if (!isStealthEntry) {
        if (io) {
          io.to(roomChannelNames).emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
          io.to(roomChannelNames).emit('user_joined', userPayload);
        } else if (socket.to) {
          socket.to(roomChannelNames).emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
        }
      }

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
        dedupKey: `${room.id}:${effectiveJoinedId}:${entryEventId}`,
        suppressAnimation,
        isDebouncedReconnect,
        entryEffect: activeEntryEffect,
        equippedRide: activeEntryEffect,
        entryEffectId: activeEntryEffect?.id || null,
        text: entryText,
        message: entryText,
        content: entryText,
        type: 'SYSTEM',
        isSystemMessage: true,
        timestamp: entryTimestamp,
      };

      if (!isStealthEntry) {
        if (io) {
          io.to(roomChannelNames).emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, chatPayload);
          io.to(roomChannelNames).emit('room:chat', chatPayload);
        } else if (socket.to) {
          socket.to(roomChannelNames).emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, chatPayload);
        }
      }

      // Ensure the entering user socket receives both events reliably if room broadcast didn't include socket
      if (socket && typeof socket.emit === 'function') {
        const socketInRoom = socket.rooms && typeof socket.rooms.has === 'function' &&
          (socket.rooms.has(`room:${room.id}`) || socket.rooms.has(`room:${roomId}`));
        if (!io || !socketInRoom) {
          socket.emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
          socket.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, chatPayload);
        }
      }

    // 8. Update Authoritative User Room Presence
    if (userId && !socket.isGuest && !String(userId).startsWith('guest_')) {
      try {
        await presenceService.setUserActiveRoom(userId, room.id);
        presenceService
          .getUserPresence(userId, db || prisma)
          .then((pres) => {
            if (io && pres) presenceService.broadcastPresenceChange(io, userId, pres);
          })
          .catch(() => {});
      } catch (_) {}
    }

    if (typeof callback === 'function') {
      return callback({
        ok: true,
        success: true,
        data: snapshot,
        attemptId: attemptId || data?.attemptId,
        room: snapshot,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      attemptId: data?.attemptId || null,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to join room',
        stage: ['ROOM_LOCKED_PIN_REQUIRED', 'INVALID_ROOM_PIN', 'ROOM_APPROVAL_REQUIRED'].includes(err.code) ? 'ROOM_AUTH' : 'ROOM_JOIN',
        recoverable: !['ROOM_LOCKED_PIN_REQUIRED', 'INVALID_ROOM_PIN', 'ROOM_APPROVAL_REQUIRED', 'ROOM_NOT_LIVE', 'ROOM_KICKED', 'ROOM_BANNED', 'FORBIDDEN'].includes(err.code),
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
    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [ROOM_LEAVE_REQ] socket=${socket.id} user=${userId} room=${roomId} before: ${describeRoomChannel(socket, roomId)}`);

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
      const targetRoomIds = Array.from(new Set([String(roomId), String(room ? room.id : roomId)]));
      const roomChannelNames = targetRoomIds.map((id) => `room:${id}`);
      const broadcastTarget = io ? io.to(roomChannelNames) : (socket.to ? socket.to(`room:${roomId}`) : socket);

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
        // Host has left: stop host attendance timer, keep Party Room open for remaining users (or schedule 12s sleep if empty)
        await attendanceService.endBroadcastSession({ roomId: room.id, hostUserId: userId }, db).catch(() => {});
        const hostAwayPayload = {
          roomId: room.id,
          clientRoomId: roomId,
          userId,
          id: userId,
          viewerCount: updatedViewerCount,
          count: updatedViewerCount,
          currentViewersCount: updatedViewerCount,
          status: 'LIVE',
          roomStaysOpen: isPartyRoomType(room.roomType),
          reason: 'HOST_AWAY',
          message: isPartyRoomType(room.roomType)
            ? 'Host has left the room. Party continues for remaining members.'
            : 'Host has temporarily stepped away.',
        };
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, hostAwayPayload);
        broadcastTarget.emit('user_left', hostAwayPayload);
        broadcastTarget.emit('room:host_away', hostAwayPayload);
        broadcastTarget.emit('room:host_left', hostAwayPayload);
        startHostAbsentTimer(room.id, room.roomType || 'AUDIO_PARTY', userId, io);
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

        if (room && isPartyRoomType(room.roomType)) {
          await checkAndSchedulePartyRoomSleep(room.id, io, 10000, userId);
        }
      }

      // If the leaving user was occupying a microphone seat, broadcast authoritative seat release across all aliases
      if (typeof leaveResult?.vacatedSeatIndex === 'number') {
        let updatedSnapshot = null;
        try {
          const freshRoom = await roomRepository.findRoomById(room ? room.id : roomId, db);
          if (freshRoom) {
            updatedSnapshot = buildRoomSnapshot(freshRoom, updatedViewerCount);
          }
        } catch (_) {}

        const seatRelPayload = {
          id: `seat_rel_${roomId}_${leaveResult.vacatedSeatIndex}_${userId}_${Date.now()}`,
          eventId: `seat_rel_${roomId}_${leaveResult.vacatedSeatIndex}_${userId}_${Date.now()}`,
          roomId: room ? room.id : roomId,
          canonicalRoomId: room ? room.id : roomId,
          clientRoomId: roomId,
          seatIndex: leaveResult.vacatedSeatIndex,
          seatNumber: leaveResult.vacatedSeatIndex,
          releasedByUserId: userId,
          userId,
          previousUserId: userId,
          seats: updatedSnapshot ? updatedSnapshot.seats : [],
          timestamp: new Date().toISOString(),
        };

        broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatRelPayload);
        broadcastTarget.emit('room_seat_released', seatRelPayload);
        broadcastTarget.emit('room:seat_left', seatRelPayload);
        broadcastTarget.emit('room_seat_left', seatRelPayload);
        broadcastTarget.emit('seat_released', seatRelPayload);
        broadcastTarget.emit('seat:released', seatRelPayload);
        broadcastTarget.emit('room:mic_left', seatRelPayload);
        broadcastTarget.emit('mic:left', seatRelPayload);
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
    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [DISCONNECT] socket=${socket.id} user=${userId} reason=${socket._disconnectReason ?? 'unknown'} rooms=${[...(socket.rooms ?? [])].filter((r) => String(r).startsWith('room:')).join(',')}`);

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

          const leaveResult = await roomService.leaveRoom(roomId, userId, db).catch(() => null);

          let updatedViewerCount = 0;
          try {
            updatedViewerCount = await presenceService.getRoomViewerCount(roomId, room.creatorUserId);
          } catch (_) {
            updatedViewerCount = leaveResult?.currentViewersCount || 0;
          }
          const targetRoomIds = Array.from(new Set([String(roomId), String(room ? room.id : roomId)]));
          const roomChannelNames = targetRoomIds.map((id) => `room:${id}`);
          const broadcastTarget = io ? io.to(roomChannelNames) : socket;

          if (isHostUser) {
            await attendanceService.endBroadcastSession({ roomId: room.id, hostUserId: userId }, db).catch(() => {});
            if (isAudioParty) {
              const hostAwayPayload = {
                roomId: room.id,
                clientRoomId: roomId,
                userId,
                id: userId,
                viewerCount: updatedViewerCount,
                count: updatedViewerCount,
                currentViewersCount: updatedViewerCount,
                status: 'LIVE',
                roomStaysOpen: true,
                reason: 'HOST_AWAY',
                message: 'Host has left the room. Party continues for remaining members.',
              };
              broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, hostAwayPayload);
              broadcastTarget.emit('user_left', hostAwayPayload);
              broadcastTarget.emit('room:host_away', hostAwayPayload);
              broadcastTarget.emit('room:host_left', hostAwayPayload);
              startHostAbsentTimer(room.id, 'AUDIO_PARTY', userId, io);
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

            if (isAudioParty) {
              await checkAndSchedulePartyRoomSleep(room.id, io, 10000, userId);
            }
          }

          // If the disconnecting user was occupying a microphone seat, broadcast authoritative seat release across all aliases
          if (typeof leaveResult?.vacatedSeatIndex === 'number') {
            let updatedSnapshot = null;
            try {
              const freshRoom = await roomRepository.findRoomById(room.id, db);
              if (freshRoom) {
                updatedSnapshot = buildRoomSnapshot(freshRoom, updatedViewerCount);
              }
            } catch (_) {}

            const seatRelPayload = {
              id: `seat_rel_${roomId}_${leaveResult.vacatedSeatIndex}_${userId}_${Date.now()}`,
              eventId: `seat_rel_${roomId}_${leaveResult.vacatedSeatIndex}_${userId}_${Date.now()}`,
              roomId: room.id,
              canonicalRoomId: room.id,
              clientRoomId: roomId,
              seatIndex: leaveResult.vacatedSeatIndex,
              seatNumber: leaveResult.vacatedSeatIndex,
              releasedByUserId: userId,
              userId,
              previousUserId: userId,
              seats: updatedSnapshot ? updatedSnapshot.seats : [],
              timestamp: new Date().toISOString(),
            };

            broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatRelPayload);
            broadcastTarget.emit('room_seat_released', seatRelPayload);
            broadcastTarget.emit('room:seat_left', seatRelPayload);
            broadcastTarget.emit('room_seat_left', seatRelPayload);
            broadcastTarget.emit('seat_released', seatRelPayload);
            broadcastTarget.emit('seat:released', seatRelPayload);
            broadcastTarget.emit('room:mic_left', seatRelPayload);
            broadcastTarget.emit('mic:left', seatRelPayload);
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
    const sessionStart = room.createdAt ? new Date(room.createdAt) : new Date(0);
    try {
      const recentTxs = await (db || prisma).giftTransaction.findMany({
        where: { roomId: room.id, createdAt: { gte: sessionStart } },
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
        eventId: `hist_gift_${tx.id}`,
        isHistorical: true,
        isLive: false,
        playbackType: 'HISTORY_ONLY',
        replayAnimation: false,
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

    const sessionScoreRes = await getAuthoritativeRoomSessionScore(room.id, db || prisma).catch(() => ({ sessionScore: 0, sessionId: null, sessionStartedAt: null }));
    const sessionScore = sessionScoreRes.sessionScore;
    const activeSessionId = sessionScoreRes.sessionId || room.activeSessionId || null;
    const activeSessionStartedAt = sessionScoreRes.sessionStartedAt || (room.sessionStartedAt ? new Date(room.sessionStartedAt).toISOString() : null);

    room.dailySendingTotal = sessionScore;
    room.roomSendingTotal = sessionScore;
    room.periodTotalCoins = sessionScore;
    room.trophyCoins = sessionScore;
    room.sessionId = activeSessionId;
    room.sessionStartedAt = activeSessionStartedAt;

    let totalLikes = 0;
    try {
      totalLikes = await presenceService.getRoomLikes(room.id);
    } catch (_) {}

    const snapshot = buildRoomSnapshot(room, viewerCount, activeUsers);
    snapshot.feedClearedAt = feedClearedAt;
    snapshot.recentGifts = recentGifts;
    snapshot.dailySendingTotal = sessionScore;
    snapshot.roomSendingTotal = sessionScore;
    snapshot.periodTotalCoins = sessionScore;
    snapshot.trophyCoins = sessionScore;
    snapshot.sessionId = activeSessionId;
    snapshot.sessionStartedAt = activeSessionStartedAt;
    snapshot.totalLikes = totalLikes;
    snapshot.likesCount = totalLikes;
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
      dailySendingTotal: sessionScore,
      roomSendingTotal: sessionScore,
      periodTotalCoins: sessionScore,
      trophyCoins: sessionScore,
      sessionId: activeSessionId,
      sessionStartedAt: activeSessionStartedAt,
      totalLikes,
      likesCount: totalLikes,
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
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const rawRoomId =
      data?.roomId ||
      data?.sessionId ||
      data?.liveSessionId ||
      data?.partyRoomId ||
      data?.channelName ||
      data?.pkId ||
      data?.matchId ||
      socket.currentRoomId;
    const emojiId = data?.emojiId || data?.emoji || data?.reaction || data?.icon || null;
    const emoji = (data?.emoji || data?.reaction || data?.icon || data?.emojiId || '').trim();
    const targetUserId = data?.targetUserId || null;

    if (!rawRoomId || !emoji) {
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

    const senderId = (!socket.isGuest && socket.userId)
      ? socket.userId
      : (socket.user?.id || socket.userId || data?.senderId || data?.userId);

    // Resolve canonical room & validate session lifecycle
    let canonicalRoomId = String(rawRoomId);
    let room = null;
    try {
      room = await (roomRepository.resolveCanonicalRoom
        ? roomRepository.resolveCanonicalRoom(rawRoomId, { senderUserId: senderId }, db || prisma)
        : roomRepository.findRoomById(rawRoomId, db || prisma));
      if (room) {
        canonicalRoomId = room.id;
      }
    } catch (_) {}

    if (room && room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase())) {
      const statusUpper = String(room.status).toUpperCase();
      if (statusUpper === 'CLOSED_BY_ADMIN' || statusUpper === 'HOST_KICKED') {
        const err = {
          success: false,
          error: {
            code: 'ROOM_RESTRICTED',
            message: 'Room has been closed by moderation and cannot receive reactions',
            recoverable: false,
          },
        };
        if (typeof callback === 'function') return callback(err);
        return socket.emit(SOCKET_EVENTS.ERROR, err);
      }

      // If room is ENDED, do not independently wake the room.
      // Check if an in-progress wake or activation already completed in database
      const refreshed = await (roomRepository.findRoomById
        ? roomRepository.findRoomById(canonicalRoomId, db || prisma)
        : null).catch(() => null);
      if (refreshed && ['LIVE', 'ACTIVE', 'OPEN'].includes(String(refreshed.status).toUpperCase())) {
        room = refreshed;
      } else {
        const err = {
          success: false,
          error: {
            code: SOCKET_ERRORS.ROOM_NOT_LIVE,
            message: 'Room session is currently inactive or waking up. Please wait for room to reopen.',
            recoverable: true,
            retryable: true,
          },
        };
        if (typeof callback === 'function') return callback(err);
        return socket.emit(SOCKET_EVENTS.ERROR, err);
      }
    }

    // Ensure sender socket and host socket are subscribed to the canonical room channel
    if (typeof socket.join === 'function') {
      await socket.join(`room:${rawRoomId}`);
      if (canonicalRoomId !== rawRoomId) {
        await socket.join(`room:${canonicalRoomId}`);
      }
    }
    if (io && typeof io.in === 'function' && room?.creatorUserId) {
      try {
        io.in(`user:${room.creatorUserId}`).socketsJoin(`room:${canonicalRoomId}`);
      } catch (_) {}
    }

    // Authoritative sender identity lookup
    let dbSender = null;
    if (senderId && !String(senderId).startsWith('guest_') && !socket.isGuest) {
      if (socket.user && (socket.user.id === senderId || socket.userId === senderId) && socket.user.username) {
        dbSender = socket.user;
      } else {
        try {
          dbSender = await userRepository.findById(senderId);
        } catch (_) {}
      }
    }

    const senderAgoraUid = senderId ? deriveAgoraUid(senderId) : null;
    const senderUsername =
      dbSender?.username ||
      (!socket.isGuest ? socket.user?.username : null) ||
      data?.sender?.username ||
      `User_${String(senderId || '').replace('guest_', '').substring(0, 5)}`;
    const senderDisplayName =
      dbSender?.profile?.displayName ||
      dbSender?.displayName ||
      dbSender?.username ||
      (!socket.isGuest ? (socket.user?.displayName || socket.user?.name || socket.user?.username) : null) ||
      data?.sender?.displayName ||
      data?.sender?.name ||
      senderUsername;
    const senderAvatarUrl =
      dbSender?.avatarUrl ||
      dbSender?.profile?.avatarUrl ||
      (!socket.isGuest ? (socket.user?.avatarUrl || socket.user?.profile?.avatarUrl) : null) ||
      data?.sender?.avatarUrl ||
      null;
    const senderFrame =
      resolveUserAvatarFrame(dbSender) ||
      resolveUserAvatarFrame(socket.user) ||
      data?.sender?.avatarFrame ||
      null;

    // Resolve seatId / seatIndex if sender is seated or is the room host
    const rawSeatCandidate = data?.seatId ?? data?.seatIndex ?? data?.micIndex;
    let resolvedSeatId =
      typeof rawSeatCandidate === 'number'
        ? rawSeatCandidate
        : (rawSeatCandidate != null && !isNaN(parseInt(rawSeatCandidate, 10))
          ? parseInt(rawSeatCandidate, 10)
          : null);

    if (resolvedSeatId === null && room && senderId) {
      const occupiedSeat = (room.seats || []).find((s) => s.occupiedUserId === senderId);
      if (occupiedSeat) {
        resolvedSeatId = occupiedSeat.seatIndex;
      } else if (room.creatorUserId === senderId) {
        resolvedSeatId = 0;
      }
    }

    const senderIdentity = {
      id: senderId,
      userId: senderId,
      agoraUid: senderAgoraUid,
      uid: senderAgoraUid,
      username: senderUsername,
      displayName: senderDisplayName,
      name: senderDisplayName,
      avatarUrl: senderAvatarUrl,
      avatar: senderAvatarUrl,
      avatarFrame: senderFrame,
      equippedFrame: senderFrame,
      level: dbSender?.profile?.level || socket.user?.level || 1,
      vipLevel: dbSender?.profile?.vipLevel || socket.user?.vipLevel || 0,
      svipLevel: dbSender?.profile?.svipLevel || socket.user?.svipLevel || 0,
      nobleRank: dbSender?.profile?.nobleRank || socket.user?.nobleRank || null,
      isHost: Boolean(room && room.creatorUserId === senderId),
    };

    const payload = {
      id: `emoji_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      roomId: canonicalRoomId,
      sessionId: canonicalRoomId,
      clientRoomId: rawRoomId,
      emojiId: emojiId || emoji,
      emoji,
      reaction: emoji,
      targetUserId,
      seatId: resolvedSeatId,
      seatIndex: resolvedSeatId,
      micIndex: resolvedSeatId,
      gameResult: typeof data?.gameResult === 'number' ? data.gameResult : (data?.gameResult != null && !isNaN(parseInt(data.gameResult, 10)) ? parseInt(data.gameResult, 10) : null),
      senderId,
      senderUserId: senderId,
      userId: senderId,
      agoraUid: senderAgoraUid,
      uid: senderAgoraUid,
      username: senderUsername,
      displayName: senderDisplayName,
      name: senderDisplayName,
      avatarUrl: senderAvatarUrl,
      avatar: senderAvatarUrl,
      senderName: senderDisplayName,
      senderUsername,
      senderAvatar: senderAvatarUrl,
      sender: senderIdentity,
      user: senderIdentity,
      timestamp: new Date().toISOString(),
    };

    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [EMOJI_SEND] socket=${socket.id} sender=${senderId} emoji=${emoji} room=${canonicalRoomId}`);
    const targetRoomIds = new Set([String(rawRoomId), String(canonicalRoomId)]);

    // If this room is in an active PK match and reaction was sent during PK, also deliver to paired PK room
    try {
      const activePk = await pkService.getActiveMatchForRoom(canonicalRoomId);
      if (activePk && activePk.status === 'ACTIVE') {
        if (activePk.roomAId) targetRoomIds.add(String(activePk.roomAId));
        if (activePk.roomBId) targetRoomIds.add(String(activePk.roomBId));
        if (activePk.id) targetRoomIds.add(String(activePk.id));
        payload.pkMatchId = activePk.id;
      }
    } catch (_) {}

    const targetChannels = Array.from(targetRoomIds).map((r) => `room:${r}`);
    if (io) {
      let broadcast = io;
      for (const ch of targetChannels) {
        broadcast = broadcast.to(ch);
      }
      broadcast.emit(SOCKET_EVENTS.ROOM_EMOJI_RECEIVED, payload);
      broadcast.emit('room:emoji_received', payload);
      broadcast.emit('room:emoji', payload);
      broadcast.emit('emoji_received', payload);
      broadcast.emit('room:reaction', payload);
    } else if (socket.to) {
      let broadcast = socket.to(targetChannels);
      broadcast.emit(SOCKET_EVENTS.ROOM_EMOJI_RECEIVED, payload);
      broadcast.emit('room:emoji', payload);
    }

    if (socket && typeof socket.emit === 'function') {
      const socketInRoom = socket.rooms && typeof socket.rooms.has === 'function' &&
        (socket.rooms.has(`room:${canonicalRoomId}`) || socket.rooms.has(`room:${rawRoomId}`));
      if (!io || !socketInRoom) {
        socket.emit(SOCKET_EVENTS.ROOM_EMOJI_RECEIVED, payload);
        socket.emit('room:emoji_received', payload);
        socket.emit('room:emoji', payload);
        socket.emit('emoji_received', payload);
      }
    }

    if (typeof callback === 'function') {
      return callback({ ok: true, success: true, data: payload });
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
    const rawRoomId =
      data?.roomId ||
      data?.sessionId ||
      data?.liveSessionId ||
      data?.partyRoomId ||
      data?.channelName ||
      data?.pkId ||
      data?.matchId ||
      socket.currentRoomId;
    const text = (data?.text || data?.message || data?.content || data?.comment || '').trim();

    if (!rawRoomId || !text) {
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

    const clientSender = data?.sender || data?.user || {};
    // Authoritative sender ID: authenticated socket user always takes precedence over client payload
    const senderId = (!socket.isGuest && socket.userId)
      ? socket.userId
      : (socket.user?.id || socket.userId || clientSender.id || clientSender.userId);

    // Resolve canonical room ID and check room lifecycle & moderation
    let canonicalRoomId = String(rawRoomId);
    let room = null;
    try {
      room = await (roomRepository.resolveCanonicalRoom
        ? roomRepository.resolveCanonicalRoom(rawRoomId, { senderUserId: senderId }, db || prisma)
        : roomRepository.findRoomById(rawRoomId, db || prisma));
      if (room) {
        canonicalRoomId = room.id;
      }
    } catch (_) {}

    if (room && room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase())) {
      const statusUpper = String(room.status).toUpperCase();
      if (statusUpper === 'CLOSED_BY_ADMIN' || statusUpper === 'HOST_KICKED') {
        const err = {
          success: false,
          error: {
            code: 'ROOM_RESTRICTED',
            message: 'Room has been closed by moderation and cannot receive chat messages',
            recoverable: false,
          },
        };
        if (typeof callback === 'function') return callback(err);
        return socket.emit(SOCKET_EVENTS.ERROR, err);
      }

      // If room is ENDED, do not independently wake the room.
      // Check if an in-progress wake or activation already completed in database
      const refreshed = await (roomRepository.findRoomById
        ? roomRepository.findRoomById(canonicalRoomId, db || prisma)
        : null).catch(() => null);
      if (refreshed && ['LIVE', 'ACTIVE', 'OPEN'].includes(String(refreshed.status).toUpperCase())) {
        room = refreshed;
      } else {
        const err = {
          success: false,
          error: {
            code: SOCKET_ERRORS.ROOM_NOT_LIVE,
            message: 'Room session is currently inactive or waking up. Please wait for room to reopen.',
            recoverable: true,
            retryable: true,
          },
        };
        if (typeof callback === 'function') return callback(err);
        return socket.emit(SOCKET_EVENTS.ERROR, err);
      }
    }

    // Check active chat mute or kick moderation in this room
    if (canonicalRoomId && senderId && !String(senderId).startsWith('guest_')) {
      try {
        const now = new Date();
        const activeMod = await (db || prisma).roomModeration?.findFirst?.({
          where: {
            roomId: canonicalRoomId,
            targetUserId: String(senderId),
            actionType: { in: ['KICK', 'BAN_ROOM', 'RESTRICT_FEATURE'] },
            AND: [
              {
                OR: [
                  { expiresAt: null },
                  { expiresAt: { gt: now } },
                ],
              },
            ],
          },
        });
        if (activeMod) {
          const isRemoval = activeMod.actionType === 'KICK' || activeMod.actionType === 'BAN_ROOM';
          const err = {
            success: false,
            error: {
              code: isRemoval ? 'ROOM_KICKED' : 'CHAT_MUTED',
              message: isRemoval
                ? 'You have been removed from this room session'
                : 'You are muted from chatting in this room',
            },
          };
          if (typeof callback === 'function') return callback(err);
          return socket.emit(SOCKET_EVENTS.ERROR, err);
        }

        // Also check account-level restrictions (CHAT_BLOCK, COMMENT_BLOCK, MUTE, BAN)
        const activeUserRestriction = await (db || prisma).restriction?.findFirst?.({
          where: {
            OR: [
              { userId: String(senderId) },
              { targetId: String(senderId) },
            ],
            type: { in: ['CHAT_BLOCK', 'COMMENT_BLOCK', 'MUTE', 'BAN'] },
            status: 'ACTIVE',
            startsAt: { lte: now },
            AND: [
              {
                OR: [
                  { expiresAt: null },
                  { expiresAt: { gt: now } },
                ],
              },
            ],
          },
        });
        if (activeUserRestriction) {
          const isBan = activeUserRestriction.type === 'BAN';
          const err = {
            success: false,
            error: {
              code: isBan ? 'USER_BANNED' : 'CHAT_MUTED',
              message: activeUserRestriction.reason || 'You are restricted from chatting',
            },
          };
          if (typeof callback === 'function') return callback(err);
          return socket.emit(SOCKET_EVENTS.ERROR, err);
        }
      } catch (_) {}
    }

    // Ensure sender socket and host socket are joined to canonical room channel
    if (typeof socket.join === 'function') {
      await socket.join(`room:${rawRoomId}`);
      if (canonicalRoomId !== rawRoomId) {
        await socket.join(`room:${canonicalRoomId}`);
      }
    }
    if (io && typeof io.in === 'function' && room?.creatorUserId) {
      try {
        io.in(`user:${room.creatorUserId}`).socketsJoin(`room:${canonicalRoomId}`);
      } catch (_) {}
    }

    // Resolve authoritative user identity from PostgreSQL database / verified socket.user
    let dbUser = null;
    if (senderId && !String(senderId).startsWith('guest_')) {
      if (socket.user && socket.user.id === senderId && socket.user.username && socket.user.profile) {
        dbUser = socket.user;
      } else {
        try {
          const lookupFn = userRepository.findByIdForIdentity || userRepository.findById;
          dbUser = await lookupFn(senderId);
        } catch (_) {}
      }
    }

    const isHostSender = Boolean(room && room.creatorUserId === senderId);
    const senderAgoraUid = senderId ? deriveAgoraUid(senderId) : null;
    const senderUsername =
      dbUser?.username ||
      (!socket.isGuest ? socket.user?.username : null) ||
      clientSender.username ||
      `User_${String(senderId).replace('guest_', '').substring(0, 5)}`;

    let senderName =
      dbUser?.profile?.displayName ||
      dbUser?.displayName ||
      dbUser?.name ||
      dbUser?.username ||
      (!socket.isGuest ? (socket.user?.displayName || socket.user?.name || socket.user?.username) : null) ||
      clientSender.displayName ||
      clientSender.name ||
      clientSender.username;

    if (!senderName || senderName === 'ZeParty Member' || senderName.startsWith('guest_')) {
      senderName = `User_${String(senderId).replace('guest_', '').substring(0, 5)}`;
    }

    const senderAvatar =
      dbUser?.avatarUrl ||
      dbUser?.profile?.avatarUrl ||
      (!socket.isGuest ? (socket.user?.avatarUrl || socket.user?.profile?.avatarUrl) : null) ||
      clientSender.avatarUrl ||
      null;

    const senderVip = Boolean(
      (dbUser?.profile?.vipLevel ?? 0) > 0 ||
      (dbUser?.profile?.svipLevel ?? 0) > 0 ||
      socket.user?.isVip ||
      clientSender.isVip
    );
    const senderNoble =
      dbUser?.profile?.nobleRank ||
      socket.user?.nobleTitle ||
      socket.user?.nobleLevel ||
      clientSender.nobleTitle ||
      clientSender.nobleLevel ||
      null;
    const senderRole = isHostSender
      ? 'HOST'
      : (dbUser?.userType || socket.user?.role || clientSender.role || 'USER');
    const senderFrame =
      resolveUserAvatarFrame(dbUser) ||
      resolveUserAvatarFrame(socket.user) ||
      resolveUserAvatarFrame(clientSender) ||
      socket.user?.avatarFrame ||
      clientSender.avatarFrame ||
      clientSender.frameUrl ||
      null;
    const senderBubble =
      socket.user?.chatBubble ||
      clientSender.chatBubble ||
      clientSender.bubbleUrl ||
      null;

    const senderNobleStyle = getNobleStyle(senderNoble);
    const senderIdentity = {
      id: senderId,
      userId: senderId,
      agoraUid: senderAgoraUid,
      uid: senderAgoraUid,
      username: senderUsername,
      name: senderName || 'User',
      displayName: senderName || 'User',
      avatarUrl: senderAvatar || null,
      avatar: senderAvatar || null,
      avatarFrame: senderFrame || null,
      equippedFrame: senderFrame || null,
      chatBubble: senderBubble || null,
      level: dbUser?.profile?.level || socket.user?.level || 1,
      vipLevel: dbUser?.profile?.vipLevel || socket.user?.vipLevel || 0,
      svipLevel: dbUser?.profile?.svipLevel || socket.user?.svipLevel || 0,
      isVip: senderVip,
      isHost: isHostSender,
      nobleLevel: senderNoble || null,
      nobleTitle: senderNoble || null,
      nobleRank: senderNoble || null,
      nobleColor: senderNobleStyle?.color || null,
      nobleStyle: senderNobleStyle,
      role: senderRole || null,
    };

    const cleanText = text.substring(0, 500);
    const payload = {
      id: data?.id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      clientMessageId: data?.clientMessageId || data?.clientMsgId || null,
      roomId: canonicalRoomId,
      sessionId: canonicalRoomId,
      clientRoomId: rawRoomId,
      senderUserId: senderId,
      senderId,
      userId: senderId,
      agoraUid: senderAgoraUid,
      uid: senderAgoraUid,
      username: senderUsername,
      displayName: senderName || 'User',
      name: senderName || 'User',
      avatarUrl: senderAvatar || null,
      avatar: senderAvatar || null,
      senderName: senderName || 'User',
      senderUsername,
      senderAvatar: senderAvatar || null,
      sender: senderIdentity,
      user: senderIdentity,
      avatarFrame: senderFrame || null,
      equippedFrame: senderFrame || null,
      text: cleanText,
      message: cleanText,
      comment: cleanText,
      content: cleanText,
      timestamp: new Date().toISOString(),
      type: data?.type || 'text',
    };

    console.log(`[RTC-DIAG][SERVER] ${new Date().toISOString()} [CHAT_SEND] socket=${socket.id} sender=${senderId} room=${canonicalRoomId} msgId=${payload.id} ${describeRoomChannel(socket, canonicalRoomId)}`);
    const targetRoomIds = new Set([String(rawRoomId), String(canonicalRoomId)]);

    // If this comment was sent in an active PK match, broadcast to both PK sides so all PK participants see it
    try {
      const activePk = await pkService.getActiveMatchForRoom(canonicalRoomId);
      if (activePk && activePk.status === 'ACTIVE') {
        if (activePk.roomAId) targetRoomIds.add(String(activePk.roomAId));
        if (activePk.roomBId) targetRoomIds.add(String(activePk.roomBId));
        if (activePk.id) targetRoomIds.add(String(activePk.id));
        payload.pkMatchId = activePk.id;
      }
    } catch (_) {}

    const targetChannels = Array.from(targetRoomIds).map((r) => `room:${r}`);
    if (io) {
      let broadcast = io;
      for (const ch of targetChannels) {
        broadcast = broadcast.to(ch);
      }
      broadcast.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
      broadcast.emit('room:chat_message', payload);
      broadcast.emit('room_chat_message', payload);
      broadcast.emit('chat_message', payload);
      broadcast.emit('room:chat', payload);
      broadcast.emit('room:comment', payload);
    } else if (socket.to) {
      let broadcast = socket.to(targetChannels);
      broadcast.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
      broadcast.emit('room:chat_message', payload);
      broadcast.emit('room:chat', payload);
    }

    if (socket && typeof socket.emit === 'function') {
      const socketInRoom = socket.rooms && typeof socket.rooms.has === 'function' &&
        (socket.rooms.has(`room:${canonicalRoomId}`) || socket.rooms.has(`room:${rawRoomId}`));
      if (!io || !socketInRoom) {
        socket.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
        socket.emit('room:chat_message', payload);
        socket.emit('room_chat_message', payload);
        socket.emit('chat_message', payload);
        socket.emit('room:comment', payload);
      }
    }

    if (typeof callback === 'function') {
      return callback({ ok: true, success: true, data: payload });
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

    // Resolve canonical room ID if short ID was passed
    let canonicalRoomId = roomId;
    if (roomId && roomId.length <= 16) {
      try {
        const found = await roomRepository.findRoomById(roomId);
        if (found) {
          canonicalRoomId = found.id;
        }
      } catch (_) {}
    }

    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
      if (canonicalRoomId !== roomId) {
        socket.join(`room:${canonicalRoomId}`);
      }
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

    let totalLikes = count;
    try {
      totalLikes = await presenceService.incrementRoomLikes(canonicalRoomId || roomId, count);
    } catch (_) {}

    const payload = {
      roomId: canonicalRoomId,
      clientRoomId: roomId,
      count,
      totalLikes,
      likesCount: totalLikes,
      userId: socket.user?.id || socket.userId,
      sender,
      timestamp: new Date().toISOString(),
    };

    const targetRooms = Array.from(new Set([String(roomId), String(canonicalRoomId)]));
    const channelNames = targetRooms.map((r) => `room:${r}`);
    if (io) {
      io.to(channelNames).emit('room:like', payload);
    } else {
      socket.emit('room:like', payload);
    }

    if (typeof callback === 'function') {
      return callback({ ok: true, success: true, data: payload });
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
      themeUrl: result.themeUrl || result.backgroundImageUrl || null,
      theme: result.theme || result.background || null,
      updatedBy: userId,
      timestamp: new Date().toISOString(),
    };

    const broadcastTarget = io ? io.to(`room:${result.roomId}`) : (socket.to ? socket.to(`room:${result.roomId}`) : socket);
    broadcastTarget.emit('room:background_updated', payload);
    broadcastTarget.emit('room_background_updated', payload);
    broadcastTarget.emit('room:update_background', payload);
    broadcastTarget.emit('room:theme_updated', payload);
    broadcastTarget.emit('room_theme_updated', payload);

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
    withRateLimit('ROOM_JOIN', 30, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'room_join',
    withRateLimit('ROOM_JOIN', 30, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'join_room',
    withRateLimit('ROOM_JOIN', 30, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'join:room',
    withRateLimit('ROOM_JOIN', 30, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
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
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room_chat_send',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'send_room_chat',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room:comment',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room:comment_send',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'chat:send',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room:chat',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room_chat',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'send_chat',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'comment:send',
    withRateLimit('ROOM_CHAT', 60, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_EMOJI_SEND,
    withRateLimit('ROOM_EMOJI', 60, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'room_emoji_send',
    withRateLimit('ROOM_EMOJI', 60, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'send_room_emoji',
    withRateLimit('ROOM_EMOJI', 60, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'room:emoji',
    withRateLimit('ROOM_EMOJI', 60, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'room:reaction',
    withRateLimit('ROOM_EMOJI', 60, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'room:reaction_send',
    withRateLimit('ROOM_EMOJI', 60, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );

  // Authoritative Agora UID / User Identity Resolution
  socket.on(
    'room:resolve_identity',
    withRateLimit('ROOM_IDENTITY', 30, 1000, (s, d, cb) => onResolveIdentity(io, s, d, cb))
  );
  socket.on(
    'agora:resolve_uid',
    withRateLimit('ROOM_IDENTITY', 30, 1000, (s, d, cb) => onResolveIdentity(io, s, d, cb))
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
    withRateLimit('ROOM_JOIN', 30, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'room_user_joined',
    withRateLimit('ROOM_JOIN', 30, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
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

  // Bug #48: Live Co-Host Invitation Realtime Handlers
  const handleCoHostInvite = async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const targetUserId = data?.targetUserId || data?.recipientId;
      if (!roomId || !targetUserId) {
        if (typeof callback === 'function') callback({ success: false, error: 'roomId and targetUserId are required' });
        return;
      }

      const inviterUserId = socket.userId || data?.inviter?.id || data?.inviter?.userId;
      const invitation = await cohostInviteService.createCoHostInvite({
        roomId,
        actorUserId: inviterUserId,
        targetUserId: String(targetUserId),
        seatIndex: data?.seatIndex || 1,
      });

      if (typeof callback === 'function') {
        callback({ success: true, invitation });
      }
    } catch (err) {
      console.warn('[RoomSocket] handleCoHostInvite error:', err.message);
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code });
      }
    }
  };

  socket.on('room:cohost_invite', handleCoHostInvite);
  socket.on('cohost_invite', handleCoHostInvite);

  const handleCoHostInviteResponse = async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const invitationId = data?.invitationId || data?.id;
      const accepted = data?.accepted === true || data?.status === 'accepted';
      const userId = socket.userId || data?.targetUserId;

      if (!roomId) {
        if (typeof callback === 'function') callback({ success: false, error: 'roomId is required' });
        return;
      }

      let result;
      if (accepted) {
        result = await cohostInviteService.acceptCoHostInvite({
          roomId,
          invitationId,
          userId,
        });
      } else {
        result = await cohostInviteService.declineCoHostInvite({
          roomId,
          invitationId,
          userId,
          reason: data?.reason,
        });
      }

      if (typeof callback === 'function') {
        callback({ success: true, ...result });
      }
    } catch (err) {
      console.warn('[RoomSocket] handleCoHostInviteResponse error:', err.message);
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code });
      }
    }
  };

  socket.on('room:cohost_invite_response', handleCoHostInviteResponse);
  socket.on('cohost_invite_response', handleCoHostInviteResponse);

  const handleCoHostLeave = async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const userId = socket.userId || data?.userId;
      if (!roomId) {
        if (typeof callback === 'function') callback({ success: false, error: 'roomId is required' });
        return;
      }
      const result = await cohostInviteService.leaveCoHost({ roomId, userId });
      if (typeof callback === 'function') callback({ success: true, ...result });
    } catch (err) {
      console.warn('[RoomSocket] handleCoHostLeave error:', err.message);
      if (typeof callback === 'function') callback({ success: false, error: err.message, code: err.code });
    }
  };
  socket.on('room:cohost_leave', handleCoHostLeave);
  socket.on('cohost_leave', handleCoHostLeave);

  const handleCoHostRemove = async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const targetUserId = data?.targetUserId || data?.userId;
      const requesterUserId = socket.userId || data?.requesterUserId;
      if (!roomId) {
        if (typeof callback === 'function') callback({ success: false, error: 'roomId is required' });
        return;
      }
      const result = await cohostInviteService.removeCoHost({ roomId, targetUserId, requesterUserId });
      if (typeof callback === 'function') callback({ success: true, ...result });
    } catch (err) {
      console.warn('[RoomSocket] handleCoHostRemove error:', err.message);
      if (typeof callback === 'function') callback({ success: false, error: err.message, code: err.code });
    }
  };
  socket.on('room:cohost_remove', handleCoHostRemove);
  socket.on('cohost_remove', handleCoHostRemove);

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

  // Bug #49: Authoritative Stage State Realtime Synchronization
  socket.on('stage:get', (d, cb) => onGetStageSnapshot(io, socket, d, cb));
  socket.on('room:stage_snapshot', (d, cb) => onGetStageSnapshot(io, socket, d, cb));
  socket.on('stage:snapshot', (d, cb) => onGetStageSnapshot(io, socket, d, cb));

  socket.on('stage:mic_toggle', (d, cb) => onStageMicToggle(io, socket, d, cb));
  socket.on('room:stage_mic_toggle', (d, cb) => onStageMicToggle(io, socket, d, cb));

  socket.on('stage:camera_toggle', (d, cb) => onStageCameraToggle(io, socket, d, cb));
  socket.on('room:stage_camera_toggle', (d, cb) => onStageCameraToggle(io, socket, d, cb));

  // Handle both disconnecting (before leaveAll) and disconnect (as safety fallback)
  socket.on('disconnecting', (reason) => { socket._disconnectReason = reason; return onSocketDisconnect(io, socket); });
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
    socket.emit('room:layout_updated', result?.data || result);
    socket.emit('room_layout_updated', result?.data || result);
    socket.emit('room:mic_count_updated', result?.data || result);
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to update room layout' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onGetStageSnapshot(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: 'INVALID_ROOM_ID', message: 'roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit('stage:error', err);
    }
    const snapshot = await stageService.getStageSnapshot(roomId);
    if (typeof callback === 'function') {
      return callback({ success: true, data: snapshot });
    }
    return socket.emit('room:stage_snapshot', snapshot);
  } catch (err) {
    const errPayload = { success: false, error: err.message || 'Failed to get stage snapshot' };
    if (typeof callback === 'function') return callback(errPayload);
    return socket.emit('stage:error', errPayload);
  }
}

export async function onStageMicToggle(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    const actorUserId = socket.userId;
    const targetUserId = data?.targetUserId || actorUserId;
    const isMuted = data?.isMuted !== undefined ? Boolean(data.isMuted) : true;
    const reason = data?.reason || null;

    if (!roomId) {
      const err = { success: false, error: { code: 'INVALID_ROOM_ID', message: 'roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit('stage:error', err);
    }

    const result = await stageService.updateStageMicState({
      roomId,
      actorUserId,
      targetUserId,
      isMuted,
      reason,
    });

    if (typeof callback === 'function') return callback(result);
    return socket.emit('stage:mic_updated', result);
  } catch (err) {
    const errPayload = { success: false, error: err.message || 'Failed to update mic state' };
    if (typeof callback === 'function') return callback(errPayload);
    return socket.emit('stage:error', errPayload);
  }
}

export async function onStageCameraToggle(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    const actorUserId = socket.userId;
    const isCameraOn = data?.isCameraOn !== undefined ? Boolean(data.isCameraOn) : true;

    if (!roomId) {
      const err = { success: false, error: { code: 'INVALID_ROOM_ID', message: 'roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit('stage:error', err);
    }

    const result = await stageService.updateStageCameraState({
      roomId,
      actorUserId,
      isCameraOn,
    });

    if (typeof callback === 'function') return callback(result);
    return socket.emit('stage:camera_updated', result);
  } catch (err) {
    const errPayload = { success: false, error: err.message || 'Failed to update camera state' };
    if (typeof callback === 'function') return callback(errPayload);
    return socket.emit('stage:error', errPayload);
  }
}

export async function onResolveIdentity(arg1, arg2, arg3, arg4, arg5) {
  const { socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId || data?.sessionId || data?.liveSessionId || socket.currentRoomId;
    const requestedAgoraUid = data?.agoraUid ?? data?.uid ?? null;
    const requestedUserId = data?.userId || data?.id || null;

    if (roomId) {
      const result = await roomService.getRoomIdentities(roomId, {
        agoraUid: requestedAgoraUid,
        userId: requestedUserId,
      }, db || prisma);

      socket.emit('room:identity_resolved', result);
      if (typeof callback === 'function') {
        return callback({ ok: true, success: true, data: result });
      }
      return;
    }

    if (requestedUserId) {
      const u = await userRepository.findById(String(requestedUserId));
      const identity = formatAuthoritativeUserIdentity(u);
      const res = { identity, agoraUidMap: identity ? { [String(identity.agoraUid)]: identity } : {} };
      socket.emit('room:identity_resolved', res);
      if (typeof callback === 'function') {
        return callback({ ok: true, success: true, data: res });
      }
      return;
    }

    const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'roomId, userId, or agoraUid is required' } };
    if (typeof callback === 'function') return callback(err);
    return socket.emit(SOCKET_EVENTS.ERROR, err);
  } catch (err) {
    const errPayload = { success: false, error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to resolve identity' } };
    if (typeof callback === 'function') return callback(errPayload);
    return socket.emit(SOCKET_EVENTS.ERROR, errPayload);
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
  onGetStageSnapshot,
  onStageMicToggle,
  onStageCameraToggle,
  onResolveIdentity,
  registerRoomHandlers,
};
