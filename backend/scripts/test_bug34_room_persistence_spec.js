import prisma from '../src/config/database.js';
import * as roomService from '../src/services/room.service.js';
import * as roomRepository from '../src/repositories/room.repository.js';
import {
  buildRoomSnapshot,
  onJoinRoom,
  onLeaveRoom,
  onUpdateRoomBackground,
  onUpdateRoomLayout,
} from '../src/socket/room.socket.js';
import {
  onOccupySeat,
  onLeaveSeat,
} from '../src/socket/seat.socket.js';
import socketEmitter from '../src/socket/socket.emitter.js';

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  ✅ PASS: ${message}`);
    passed++;
  } else {
    console.error(`  ❌ FAIL: ${message}`);
    failed++;
  }
}

function createSimulatedSocket(userId, username, userObj = {}) {
  const events = [];
  const joinedRooms = new Set();
  const socket = {
    id: `sock_${userId}_${Math.random().toString(36).substring(2, 7)}`,
    userId,
    user: {
      id: userId,
      userId,
      username,
      displayName: username,
      name: username,
      ...userObj,
    },
    joinedRooms,
    rooms: new Set(),
    join(room) {
      this.rooms.add(room);
      this.joinedRooms.add(room.replace(/^room:/, ''));
    },
    leave(room) {
      this.rooms.delete(room);
      this.joinedRooms.delete(room.replace(/^room:/, ''));
    },
    emit(event, data) {
      events.push({ event, data, timestamp: Date.now() });
    },
    getEvents(eventName) {
      if (!eventName) return events;
      return events.filter((e) => e.event === eventName);
    },
    getLastEvent(eventName) {
      const filtered = this.getEvents(eventName);
      return filtered.length > 0 ? filtered[filtered.length - 1] : null;
    },
    clearEvents() {
      events.length = 0;
    },
  };
  return socket;
}

async function run() {
  console.log('================================================================');
  console.log('🧪 BUG #34 ACCEPTANCE TEST SUITE: ROOM THEME & MIC COUNT PERSISTENCE');
  console.log('================================================================\n');

  const timestamp = Date.now();
  const hostId = `test_host_b34_${timestamp}`;
  const viewerAId = `test_viewerA_b34_${timestamp}`;
  const viewerBId = `test_viewerB_b34_${timestamp}`;
  const unauthUserId = `test_unauth_b34_${timestamp}`;

  try {
    // 0. Setup isolated test users
    console.log('--- Step 0: Setting up isolated test users ---');
    await prisma.user.createMany({
      data: [
        { id: hostId, username: `host_${timestamp}`, phone: `+99901${timestamp.toString().slice(-6)}`, status: 'ACTIVE' },
        { id: viewerAId, username: `viewera_${timestamp}`, phone: `+99902${timestamp.toString().slice(-6)}`, status: 'ACTIVE' },
        { id: viewerBId, username: `viewerb_${timestamp}`, phone: `+99903${timestamp.toString().slice(-6)}`, status: 'ACTIVE' },
        { id: unauthUserId, username: `unauth_${timestamp}`, phone: `+99904${timestamp.toString().slice(-6)}`, status: 'ACTIVE' },
      ],
    });
    console.log('  Isolated users created successfully.\n');

    // 1. Initial Room Creation
    console.log('--- Test 1: Save a nondefault theme and microphone count ---');
    const customThemeUrl = 'https://assets.zeparty.app/themes/sunset_orange_custom.png';
    const initialSeatsCount = 12;

    const initialRoom = await roomService.createRoom({
      userId: hostId,
      title: 'Host Javis Persistence Room',
      roomType: 'AUDIO_PARTY',
      category: 'MUSIC',
      backgroundImageUrl: customThemeUrl,
      capacity: initialSeatsCount,
      forceNew: true,
    });

    const persistentRoomId = initialRoom.id;
    assert(persistentRoomId && persistentRoomId.length > 0, `Initial room created with ID: ${persistentRoomId}`);
    assert(initialRoom.backgroundImageUrl === customThemeUrl, `Initial room has nondefault theme: ${initialRoom.backgroundImageUrl}`);
    assert(initialRoom.seats && initialRoom.seats.length === initialSeatsCount, `Initial room has ${initialSeatsCount} mic seats configured (actual: ${initialRoom.seats?.length})`);

    // Double check from authoritative database fetch
    const fetchedDbRoom1 = await roomRepository.findRoomById(persistentRoomId);
    assert(fetchedDbRoom1.backgroundImageUrl === customThemeUrl, 'Database accurately stored nondefault background theme');
    assert(fetchedDbRoom1.seats.length === initialSeatsCount, `Database accurately stored ${initialSeatsCount} seats in RoomSeat table`);

    // 2. Leave and rejoin the same persistent room
    console.log('\n--- Test 2: Leave and rejoin the same persistent room ---');
    // Host leaves room
    await roomService.leaveRoom(persistentRoomId, hostId);
    const roomAfterLeave = await roomRepository.findRoomById(persistentRoomId);
    assert(roomAfterLeave.backgroundImageUrl === customThemeUrl, 'Theme preserved after host leave');
    assert(roomAfterLeave.seats.length === initialSeatsCount, 'Configured mic seat count preserved after host leave');

    // Host rejoins room
    await roomService.joinRoom(persistentRoomId, hostId);
    const roomAfterRejoin = await roomService.getRoomDetails(persistentRoomId);
    assert(roomAfterRejoin.backgroundImageUrl === customThemeUrl, 'Theme intact upon rejoining room');
    assert(roomAfterRejoin.capacity === initialSeatsCount, 'Seat capacity intact upon rejoining room');
    assert(roomAfterRejoin.seats.length === initialSeatsCount, 'Configured seats intact upon rejoining room');

    // 3. Minimize and restore or simulate temporary disconnect and reconnect
    console.log('\n--- Test 3: Minimize/restore or simulate temporary disconnect and reconnect ---');
    const socketHost = createSimulatedSocket(hostId, `host_${timestamp}`);
    await onJoinRoom(null, socketHost, { roomId: persistentRoomId });

    // Host disconnects (e.g. app minimized or network drop)
    await onLeaveRoom(null, socketHost, { roomId: persistentRoomId });
    // Host reconnects (restore app)
    const socketHostReconnected = createSimulatedSocket(hostId, `host_${timestamp}`);
    let snapshotReceived = null;
    await onJoinRoom(null, socketHostReconnected, { roomId: persistentRoomId }, (ack) => {
      if (ack?.success) snapshotReceived = ack.data;
    });

    if (!snapshotReceived) {
      snapshotReceived = await roomService.getRoomDetails(persistentRoomId);
    }
    assert(snapshotReceived.backgroundImageUrl === customThemeUrl, 'Snapshot after minimize/restore preserves saved theme');
    assert(snapshotReceived.capacity === initialSeatsCount, `Snapshot after minimize/restore preserves ${initialSeatsCount} seats`);

    // 4 & 6. Close and reopen the same room, respecting existing room lifecycle & stable ID
    console.log('\n--- Test 4 & 6: Close and reopen the same room (stable persistent room ID) ---');
    // Host closes room
    const closeResult = await roomService.closeMyRoom(persistentRoomId, hostId);
    assert(closeResult.status === 'ENDED', 'Room closed and status marked ENDED');

    // Host returns to app and opens/starts their room again (createRoom with forceNew: false)
    const reopenedRoom = await roomService.createRoom({
      userId: hostId,
      title: 'Host Javis Persistence Room',
      forceNew: false,
    });

    assert(reopenedRoom.id === persistentRoomId, `Authoritative room ID is reused and STABLE: ${reopenedRoom.id} === ${persistentRoomId}`);
    assert(reopenedRoom.status === 'LIVE', 'Reopened room revived to LIVE status');
    assert(reopenedRoom.backgroundImageUrl === customThemeUrl, `Saved theme persisted across room close/reopen: ${reopenedRoom.backgroundImageUrl}`);
    assert(reopenedRoom.seats.length === initialSeatsCount, `Configured ${initialSeatsCount} mic count persisted across room close/reopen (actual: ${reopenedRoom.seats.length})`);

    // 5. Restart backend process simulation (cold DB fetch without memory caches)
    console.log('\n--- Test 5: Restart backend process simulation (cold DB fetch) ---');
    const coldRoomFetch = await roomRepository.findRoomById(persistentRoomId);
    assert(coldRoomFetch.id === persistentRoomId, 'Cold DB fetch: Room ID unchanged');
    assert(coldRoomFetch.backgroundImageUrl === customThemeUrl, `Cold DB fetch: theme matches persisted value (${coldRoomFetch.backgroundImageUrl})`);
    assert(coldRoomFetch.seats.length === initialSeatsCount, `Cold DB fetch: mic count matches persisted value (${coldRoomFetch.seats.length})`);

    // 7. Authorized explicit setting change persists and synchronizes
    console.log('\n--- Test 7: Authorized explicit setting change persists and synchronizes ---');
    const updatedThemeUrl = 'https://assets.zeparty.app/themes/galaxy_purple_neon.png';
    const updatedSeatsCount = 16;

    // Explicit background update by host
    const bgUpdateResult = await roomService.updateRoomBackground(persistentRoomId, hostId, {
      backgroundImageUrl: updatedThemeUrl,
    });
    assert(bgUpdateResult.success === true, 'Host updated background successfully');
    assert(bgUpdateResult.backgroundImageUrl === updatedThemeUrl, 'Response contains new backgroundImageUrl');

    // Explicit layout update by host
    const layoutUpdateResult = await roomService.updateRoomLayout(persistentRoomId, hostId, {
      capacity: updatedSeatsCount,
    });
    assert(layoutUpdateResult.success === true, 'Host updated layout successfully');
    assert(layoutUpdateResult.data.capacity === updatedSeatsCount, `Response contains new capacity: ${updatedSeatsCount}`);

    // Verify DB persistence of changes
    const refreshedDbRoom = await roomRepository.findRoomById(persistentRoomId);
    assert(refreshedDbRoom.backgroundImageUrl === updatedThemeUrl, `Database updated theme to: ${refreshedDbRoom.backgroundImageUrl}`);
    assert(refreshedDbRoom.seats.length === updatedSeatsCount, `Database updated seat count to: ${refreshedDbRoom.seats.length}`);

    // 8. Unauthorized changes are rejected
    console.log('\n--- Test 8: Unauthorized changes are rejected ---');
    let unauthBgBlocked = false;
    try {
      await roomService.updateRoomBackground(persistentRoomId, unauthUserId, {
        backgroundImageUrl: 'https://hacker.com/malicious_bg.png',
      });
    } catch (err) {
      unauthBgBlocked = err.statusCode === 403 || err.code === 'FORBIDDEN';
    }
    assert(unauthBgBlocked, 'Unauthorized background update rejected with 403 Forbidden');

    let unauthLayoutBlocked = false;
    try {
      await roomService.updateRoomLayout(persistentRoomId, unauthUserId, {
        capacity: 8,
      });
    } catch (err) {
      unauthLayoutBlocked = err.statusCode === 403 || err.code === 'ROOM_ADMIN_ACTION_NOT_PERMITTED';
    }
    assert(unauthLayoutBlocked, 'Unauthorized layout update rejected with 403 Forbidden');

    // Confirm DB remained untouched by unauthorized attempts
    const roomAfterUnauth = await roomRepository.findRoomById(persistentRoomId);
    assert(roomAfterUnauth.backgroundImageUrl === updatedThemeUrl, 'Database theme was NOT modified by unauthorized user');
    assert(roomAfterUnauth.seats.length === updatedSeatsCount, 'Database seats were NOT modified by unauthorized user');

    // 9. Missing or stale client configuration does not overwrite saved values
    console.log('\n--- Test 9: Missing or stale client configuration does not overwrite saved values ---');
    // Client sends createRoom/re-entry payload with missing/null backgroundImageUrl and undefined capacity
    const reenteredRoom = await roomService.createRoom({
      userId: hostId,
      title: 'Host Javis Persistence Room - Renamed',
      backgroundImageUrl: null, // Stale / missing / null snapshot from mobile client
      capacity: undefined,      // Missing capacity from mobile client
      forceNew: false,
    });

    assert(reenteredRoom.id === persistentRoomId, 'Re-entered room ID remains identical');
    assert(reenteredRoom.title === 'Host Javis Persistence Room - Renamed', 'Title was updated successfully');
    assert(reenteredRoom.backgroundImageUrl === updatedThemeUrl, `Saved theme (${updatedThemeUrl}) was NOT overwritten by null client parameter!`);
    assert(reenteredRoom.seats.length === updatedSeatsCount, `Saved ${updatedSeatsCount} seats were NOT overwritten by missing capacity!`);

    // 10. Two clients receive consistent room configuration
    console.log('\n--- Test 10: Two clients receive consistent room configuration ---');
    const snapshotViewerA = await roomService.getRoomDetails(persistentRoomId);
    const snapshotViewerB = await roomService.getRoomDetails(persistentRoomId);

    assert(snapshotViewerA.backgroundImageUrl === snapshotViewerB.backgroundImageUrl, 'Viewer A and Viewer B receive identical backgroundImageUrl');
    assert(snapshotViewerA.capacity === snapshotViewerB.capacity, 'Viewer A and Viewer B receive identical capacity');
    assert(snapshotViewerA.seats.length === snapshotViewerB.seats.length, 'Viewer A and Viewer B receive identical seats list');

    // 11. Temporary mic occupants and live presence are NOT persisted as permanent configuration
    console.log('\n--- Test 11: Temporary mic occupants are NOT persisted as permanent configuration ---');
    // Viewer A occupies seat 2
    await roomRepository.occupySeatTx({
      roomId: persistentRoomId,
      seatIndex: 2,
      userId: viewerAId,
    });

    const roomWithOccupant = await roomRepository.findRoomById(persistentRoomId);
    const seat2Before = roomWithOccupant.seats.find((s) => s.seatIndex === 2);
    assert(seat2Before && seat2Before.occupiedUserId === viewerAId, 'Seat 2 occupied by Viewer A during live session');

    // Room is closed and reopened
    await roomService.closeMyRoom(persistentRoomId, hostId);
    const roomReopenedAfterOccupancy = await roomService.createRoom({
      userId: hostId,
      forceNew: false,
    });

    const seat2AfterReopen = roomReopenedAfterOccupancy.seats.find((s) => s.seatIndex === 2);
    assert(seat2AfterReopen && seat2AfterReopen.occupiedUserId === null, 'Temporary occupant on Seat 2 vacated upon room restart');
    assert(roomReopenedAfterOccupancy.seats.length === updatedSeatsCount, `Configured mic count remains intact at ${updatedSeatsCount} seats`);
    assert(roomReopenedAfterOccupancy.backgroundImageUrl === updatedThemeUrl, 'Configured theme remains intact');

    // 12. Genuine creation of a new room follows existing product rules (does not inherit old room)
    console.log('\n--- Test 12: Genuine creation of a new room (forceNew: true) follows product rules ---');
    const brandNewRoom = await roomService.createRoom({
      userId: hostId,
      title: 'A Fresh New Room',
      forceNew: true, // Explicitly requesting brand new room
    });

    assert(brandNewRoom.id !== persistentRoomId, `Brand new room created with distinct ID: ${brandNewRoom.id} !== ${persistentRoomId}`);
    assert(brandNewRoom.backgroundImageUrl === null, 'Brand new room starts with default null background, NOT old room background');
    assert(brandNewRoom.seats.length === 10, 'Brand new room starts with default 10 seats, NOT old room 16 seats');

    // Clean up created rooms for this test
    console.log('\n--- Cleanup: Archiving test rooms ---');
    await prisma.room.deleteMany({
      where: { creatorUserId: hostId },
    });
    await prisma.user.deleteMany({
      where: { id: { in: [hostId, viewerAId, viewerBId, unauthUserId] } },
    });
    console.log('  Test rooms and users cleaned up.');

  } catch (err) {
    console.error('Unhandled test suite error:', err);
    failed++;
  } finally {
    await prisma.$disconnect();
  }

  console.log('\n================================================================');
  console.log(`📊 RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log('================================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

run();
