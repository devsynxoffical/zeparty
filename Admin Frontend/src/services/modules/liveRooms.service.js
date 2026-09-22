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
    category: r.category || 'General',
    viewers: Number(r.currentViewersCount || r.activeMembersCount || 0),
    status: (r.status || 'LIVE').toLowerCase() === 'live' ? 'active' : (r.status || 'active').toLowerCase(),
    isPinned: Boolean(r.isPinnedTop || r.isPinned),
    startedAt: r.createdAt,
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
  muteHost,
  banRoom,
};
