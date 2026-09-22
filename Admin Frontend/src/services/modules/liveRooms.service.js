// ============================================================
// ZeParty Admin Portal — Live Rooms Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getLiveRooms(params = {}) {
  const res = await apiClient.get('/v1/admin/rooms', { params });
  const items = res.data?.data || [];
  return items.map((r) => {
    const isParty = r.roomType === 'AUDIO_PARTY' || r.roomType === 'party' || r.type === 'party';
    return {
      id: r.id,
      title: r.title || (isParty ? `Party Room ${r.id.slice(0, 6)}` : `Live Room ${r.id.slice(0, 6)}`),
      roomType: isParty ? 'party' : 'live',
      hostId: r.creatorUserId || r.hostUserId || r.creator?.id,
      hostName: r.creator?.profile?.displayName || r.creator?.username || r.hostName || 'Host',
      hostUsername: r.creator?.username || r.hostUsername || 'host',
      hostAvatar: r.creator?.avatarUrl || r.creator?.profile?.avatarUrl || r.hostAvatar || '',
      coverImage: r.coverImageUrl || r.coverUrl || r.coverImage || '',
      country: r.creator?.countryCode || r.countryCode || 'PK',
      category: r.category || (isParty ? 'Entertainment' : 'Talk Show'),
      viewers: Number(r.currentViewersCount || r.activeMembersCount || r.viewers || 0),
      giftsReceived: Number(r.giftsReceivedCoins || r.totalGifts || 0),
      likes: Number(r.likesCount || 0),
      status: (r.status || 'LIVE').toLowerCase() === 'live' ? 'active' : (r.status || 'active').toLowerCase(),
      isPinned: Boolean(r.isPinnedTop || r.isPinned),
      pinnedOrder: Number(r.pinnedPosition || r.pinnedOrder || 0),
      startedAt: r.createdAt,
      tags: r.tags || [isParty ? 'Party' : 'Live', 'Chat'],
      isMuted: Boolean(r.isMuted),
      seats: r.seats || [],
      members: r.members || [],
    };
  });
}

export async function getLiveRoomById(id) {
  const res = await apiClient.get(`/v1/admin/rooms/${id}`);
  const r = res.data?.data;
  if (!r) return null;
  const isParty = r.roomType === 'AUDIO_PARTY' || r.roomType === 'party';

  // Calculate duration string
  let durationStr = '00:00';
  if (r.createdAt) {
    const start = new Date(r.createdAt).getTime();
    const now = Date.now();
    const diffSec = Math.max(0, Math.floor((now - start) / 1000));
    const mins = Math.floor(diffSec / 60);
    const secs = diffSec % 60;
    const hrs = Math.floor(mins / 60);
    if (hrs > 0) {
      durationStr = `${hrs}h ${mins % 60}m ${secs}s`;
    } else {
      durationStr = `${mins}m ${secs}s`;
    }
  }

  return {
    id: r.id,
    title: r.title,
    roomType: isParty ? 'party' : 'live',
    hostId: r.creatorUserId || r.hostUserId || r.creator?.id,
    hostName: r.creator?.profile?.displayName || r.creator?.username || r.hostName || 'Host',
    hostUsername: r.creator?.username || r.hostUsername || 'host',
    hostAvatar: r.creator?.avatarUrl || r.creator?.profile?.avatarUrl || '',
    coverImage: r.coverImageUrl || r.coverUrl || r.coverImage || '',
    country: r.creator?.countryCode || r.countryCode || 'PK',
    region: r.creator?.countryCode || r.countryCode || 'PK',
    category: r.category || 'General',
    viewers: Number(r.currentViewersCount || r.activeMembersCount || 0),
    giftsReceived: Number(r.giftsReceivedCoins || r.totalGifts || 0),
    duration: durationStr,
    status: (r.status || 'LIVE').toLowerCase() === 'live' ? 'active' : (r.status || 'active').toLowerCase(),
    isPinned: Boolean(r.isPinnedTop || r.isPinned),
    isMuted: Boolean(r.isMuted),
    startedAt: r.createdAt,
    agoraChannelName: r.agoraChannelName,
    members: r.members || [],
    seats: r.seats || [],
    creator: r.creator,
  };
}

export async function pinRoom(id, pinnedOrder = 1) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/pin`, { pinnedOrder });
  return res.data;
}

export async function unpinRoom(id) {
  const res = await apiClient.delete(`/v1/admin/rooms/${id}/pin`);
  return res.data;
}

export async function endStream(id, reason) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/close`, {
    reason: reason || 'Stream closed by administrator',
  });
  return res.data;
}

export async function issueRoomWarning(id, reason) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/warn`, {
    reason: reason || 'Community Guidelines Violation Warning',
  });
  return res.data;
}

export async function toggleRoomMute(id, isMuted) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/mute`, {
    isMuted: Boolean(isMuted),
  });
  return res.data;
}

export async function muteParticipant(id, { targetUserId, seatIndex, isMuted }) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/mute-participant`, {
    targetUserId,
    seatIndex,
    isMuted: Boolean(isMuted),
  });
  return res.data;
}

export async function kickParticipant(id, targetUserId, reason) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/kick`, {
    targetUserId,
    reason: reason || 'Participant removed by admin moderation',
  });
  return res.data;
}

export async function updateRoomCoverDp(id, coverImageUrl) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/dp`, {
    coverImageUrl,
  });
  return res.data;
}

export async function deleteRoomCoverDp(id) {
  const res = await apiClient.delete(`/v1/admin/rooms/${id}/dp`);
  return res.data;
}

export async function getAdminAgoraToken(id) {
  const res = await apiClient.get(`/v1/admin/rooms/${id}/agora-token`);
  return res.data?.data;
}

export async function muteHost(id, durationMinutes) {
  const res = await apiClient.post(`/v1/admin/moderation/user`, {
    targetUserId: id,
    action: 'MUTE',
    reason: `Muted in live room for ${durationMinutes} minutes`,
    durationMinutes: Number(durationMinutes || 60),
  });
  return res.data;
}

export async function banRoom(id, reason) {
  const res = await apiClient.post(`/v1/admin/rooms/${id}/close`, {
    reason: reason || 'Banned by platform moderation',
  });
  return res.data;
}

export default {
  getLiveRooms,
  getLiveRoomById,
  pinRoom,
  unpinRoom,
  endStream,
  issueRoomWarning,
  toggleRoomMute,
  muteParticipant,
  kickParticipant,
  updateRoomCoverDp,
  deleteRoomCoverDp,
  getAdminAgoraToken,
  muteHost,
  banRoom,
};
