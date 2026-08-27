// ============================================================
// ZeParty Admin Portal — Live Rooms Service (JavaScript)
// ============================================================

import { MOCK_LIVE_ROOMS } from '../../mocks/liveRooms.mock';

let roomsState = [...MOCK_LIVE_ROOMS];

export async function getLiveRooms() {
  await new Promise((res) => setTimeout(res, 200));
  return [...roomsState];
}

export async function getLiveRoomById(id) {
  await new Promise((res) => setTimeout(res, 150));
  const room = roomsState.find((r) => r.id === id);
  if (!room) throw new Error('Live room not found');
  return { ...room };
}

export async function endStream(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  roomsState = roomsState.map((r) =>
    r.id === id ? { ...r, status: 'ended', endedReason: reason, viewers: 0 } : r
  );
  return { success: true };
}

export async function muteHost(id, durationMinutes) {
  await new Promise((res) => setTimeout(res, 300));
  roomsState = roomsState.map((r) =>
    r.id === id ? { ...r, isMuted: true, muteDuration: durationMinutes } : r
  );
  return { success: true };
}

export async function banRoom(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  roomsState = roomsState.map((r) =>
    r.id === id ? { ...r, status: 'banned', banReason: reason, viewers: 0 } : r
  );
  return { success: true };
}
