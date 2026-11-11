import crypto from 'crypto';
import agoraPkg from 'agora-token';
import env from '../config/env.js';

const pkg = agoraPkg.default || agoraPkg;
const RtcTokenBuilder = pkg.RtcTokenBuilder;
const RtcRole = pkg.RtcRole;

export const AGORA_ROLES = {
  BROADCASTER: 'BROADCASTER',
  AUDIENCE: 'AUDIENCE',
};

/**
 * Derives a deterministic, positive 32-bit integer UID for Agora from any string/UUID.
 * 
 * Agora UIDs must be positive integers (1 to 2^31 - 1).
 * Algorithm: SHA-256(userId) -> slice first 4 bytes -> readUInt32BE -> (val % 2147483640) + 1
 * 
 * @param {string} userId - The user ID or UUID
 * @returns {number} Deterministic integer UID in range [1, 2147483640]
 */
export function deriveAgoraUid(userId) {
  if (!userId) {
    throw new Error('User ID is required to derive Agora UID');
  }

  // If already an integer
  if (Number.isInteger(Number(userId)) && Number(userId) > 0 && Number(userId) <= 2147483640) {
    return Number(userId);
  }

  const hash = crypto.createHash('sha256').update(String(userId)).digest();
  const rawUint = hash.readUInt32BE(0);
  const uid = (rawUint % 2147483640) + 1;
  return uid;
}

/**
 * Extracts an equipped asset record (e.g. FRAME, CHAT_BUBBLE, ENTRY_EFFECT) from a user object.
 */
export function extractEquippedAsset(user, assetType = 'FRAME') {
  if (!user) return null;
  if (assetType === 'FRAME' && (user.avatarFrame || user.equippedFrame)) {
    return user.avatarFrame || user.equippedFrame;
  }
  if (assetType === 'CHAT_BUBBLE' && (user.chatBubble || user.equippedChatBubble)) {
    return user.chatBubble || user.equippedChatBubble;
  }
  if (assetType === 'ENTRY_EFFECT' && (user.entryEffect || user.equippedEntryEffect)) {
    return user.entryEffect || user.equippedEntryEffect;
  }

  const assets = user.userAssets || user.equippedAssets || user.profile?.userAssets || [];
  if (Array.isArray(assets) && assets.length > 0) {
    const match = assets.find((ua) => {
      const a = ua.asset || ua;
      const isEq = ua.isEquipped !== undefined ? Boolean(ua.isEquipped) : true;
      const type = String(a?.assetType || a?.type || ua?.assetType || assetType).toUpperCase();
      return isEq && type === assetType && Boolean(a?.assetUrl || a?.animationUrl || a?.previewUrl || ua?.assetUrl);
    });
    if (match) {
      const a = match.asset || match;
      return {
        id: a.id || match.assetId || match.id,
        name: a.name || assetType,
        assetType: a.assetType || assetType,
        assetUrl: a.assetUrl || a.animationUrl || a.previewUrl || null,
        animationUrl: a.animationUrl || a.assetUrl || null,
        previewUrl: a.previewUrl || a.assetUrl || null,
      };
    }
  }
  return null;
}

/**
 * Builds an authoritative ZeParty user identity object with deterministic Agora RTC UID mapping.
 * Ensures User.avatarUrl and UserProfile fields are never lost or replaced by generic Agora placeholders.
 *
 * @param {Object} user - Database User record or socket.user object
 * @param {Object} [options] - Role/seat context overrides
 * @returns {Object|null}
 */
export function formatAuthoritativeUserIdentity(user, options = {}) {
  if (!user) return null;
  const rawId = user.id || user.userId || user.publicId;
  if (!rawId) return null;

  const idStr = String(rawId);
  const isGuest = Boolean(user.isGuest || idStr.startsWith('guest_'));
  const agoraUid = deriveAgoraUid(idStr);
  const numericUserId = /^\d+$/.test(idStr) ? Number(idStr) : agoraUid;

  const username = user.username || (isGuest ? `User_${idStr.replace('guest_', '').substring(0, 5)}` : idStr);
  const displayName =
    user.profile?.displayName ||
    user.displayName ||
    user.name ||
    user.username ||
    `User_${idStr.substring(0, 6)}`;
  const avatarUrl =
    user.avatarUrl ||
    user.profile?.avatarUrl ||
    user.avatar ||
    options.fallbackAvatarUrl ||
    null;

  const level = Number(user.profile?.level ?? user.level ?? user.wealthLevel ?? 1);
  const vipLevel = Number(user.profile?.vipLevel ?? user.vipLevel ?? 0);
  const svipLevel = Number(user.profile?.svipLevel ?? user.svipLevel ?? 0);
  const nobleRank = user.profile?.nobleRank || user.nobleRank || user.nobleTitle || null;
  const avatarFrame = extractEquippedAsset(user, 'FRAME');
  const chatBubble = extractEquippedAsset(user, 'CHAT_BUBBLE');
  const entryEffect = extractEquippedAsset(user, 'ENTRY_EFFECT');

  const role = options.role || user.role || (options.isHost ? 'HOST' : 'VIEWER');
  const seatIndex = options.seatIndex !== undefined ? options.seatIndex : (user.seatIndex !== undefined ? user.seatIndex : null);

  return {
    id: idStr,
    userId: idStr,
    publicId: idStr,
    numericUserId,
    agoraUid,
    uid: agoraUid,
    username,
    displayName,
    name: displayName,
    avatarUrl,
    avatar: avatarUrl,
    countryCode: user.countryCode || user.profile?.countryCode || 'GLOBAL',
    gender: user.gender || user.profile?.gender || null,
    level,
    wealthLevel: level,
    vipLevel,
    svipLevel,
    isVip: Boolean(vipLevel > 0 || svipLevel > 0 || user.isVip),
    nobleRank,
    nobleTitle: nobleRank,
    nobleLevel: nobleRank,
    avatarFrame,
    equippedFrame: avatarFrame,
    chatBubble,
    entryEffect,
    role,
    isHost: Boolean(options.isHost ?? user.isHost ?? role === 'HOST'),
    seatIndex,
    isMuted: options.isMuted !== undefined ? Boolean(options.isMuted) : Boolean(user.isMuted),
    isGuest,
  };
}

/**
 * Builds a lookup map keyed by Agora UID (stringified) -> Authoritative ZeParty Identity
 * so clients and admin panels can resolve any Agora RTC stream UID in O(1).
 */
export function buildAgoraUidIdentityMap(participants = []) {
  const map = {};
  for (const p of participants) {
    if (!p) continue;
    const identity = formatAuthoritativeUserIdentity(p, p);
    if (identity && identity.agoraUid) {
      map[String(identity.agoraUid)] = identity;
    }
  }
  return map;
}

const PROD_AGORA_APP_ID = '970ca35de60c44645bbae8a215061401';
const PROD_AGORA_APP_CERT = '5cfd2fd1755d40ecb72977518be15d3b';

function resolveValidAgoraHex32(candidate, defaultHex) {
  if (typeof candidate === 'string' && !candidate.includes('mock_agora') && /^[0-9a-fA-F]{32}$/.test(candidate.trim())) {
    return candidate.trim();
  }
  return defaultHex;
}

/**
 * Generates a short-lived Agora RTC Token using the official Agora RTC Token v2 builder.
 * 
 * @param {Object} params
 * @param {string} [params.appId] - Agora Application ID
 * @param {string} [params.appCertificate] - Agora Application Certificate (Secret)
 * @param {string} params.channelName - Authoritative Agora channel name (e.g. Room.agoraChannelName)
 * @param {number|string} params.uid - User integer UID
 * @param {'BROADCASTER'|'AUDIENCE'} params.role - User role
 * @param {number} [params.expirySeconds=3600] - Token validity duration in seconds
 * @returns {string} The signed Agora RTC token
 */
export function generateAgoraRtcToken({
  appId = env.AGORA_APP_ID || PROD_AGORA_APP_ID,
  appCertificate = env.AGORA_APP_CERTIFICATE || PROD_AGORA_APP_CERT,
  channelName,
  uid,
  role = AGORA_ROLES.AUDIENCE,
  expirySeconds = 3600,
}) {
  const effectiveAppId = resolveValidAgoraHex32(appId || env.AGORA_APP_ID, PROD_AGORA_APP_ID);
  const effectiveAppCert = resolveValidAgoraHex32(appCertificate || env.AGORA_APP_CERTIFICATE, PROD_AGORA_APP_CERT);

  if (!channelName || typeof channelName !== 'string' || channelName.trim() === '') {
    throw new Error('channelName is required for Agora token generation');
  }

  const numericUid = deriveAgoraUid(uid);
  const agoraRole = role === AGORA_ROLES.BROADCASTER ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + Number(expirySeconds);

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      effectiveAppId,
      effectiveAppCert,
      channelName,
      numericUid,
      agoraRole,
      privilegeExpiredTs,
      privilegeExpiredTs
    );

    return token;
  } catch (err) {
    throw new Error(`Failed to generate Agora token: ${err.message}`);
  }
}

export default {
  AGORA_ROLES,
  deriveAgoraUid,
  extractEquippedAsset,
  formatAuthoritativeUserIdentity,
  buildAgoraUidIdentityMap,
  generateAgoraRtcToken,
};
