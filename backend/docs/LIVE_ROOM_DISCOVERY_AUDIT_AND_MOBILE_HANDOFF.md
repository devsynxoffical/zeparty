# ZeParty Live Room Discovery Audit & Mobile Developer Handoff

## 1. Problem Summary

### Symptom
When a host starts a live broadcast or audio party:
1. Users who are already connected inside the mobile application receive the real-time update and can see the room.
2. A new user who opens the mobile application after the room has already started cannot see the active room.
3. Refreshing the discovery feed (`LiveDiscoveryGrid` / `BackendRepository.fetchLiveRooms`) fails to load the active rooms list for that user.
4. Rooms were only visible to clients that happened to be online when the initial room-creation broadcast occurred.

---

## 2. Confirmed Root Cause Analysis

### Primary Root Cause (Prisma Fatal Query Crash on Orphaned Foreign Key)
In `room.repository.js` -> `findActiveRooms()`, the query fetched rooms with:
```js
db.room.findMany({
  where: { status: 'LIVE' },
  take: parsedLimit, // defaults to 50 when called from mobile app
  select: { ..., creator: { select: { id: true, username: true, ... } } }
})
```
In Prisma's schema (`schema.prisma` line 956), `creator` is declared as a **required (non-nullable) relation**:
`creator User @relation("RoomCreator", fields: [creatorUserId], references: [id])`

However, the PostgreSQL database contained an orphaned room record (`id: 48bcdd0a-238b-46cf-be79-13c507e9f1b1`) created weeks prior with a legacy `creatorUserId: 'sPrRWiST9Fc0ab3bm6ryuJeau9U2'` that did not exist in the `User` table.
- When `fetchLiveRooms()` on the mobile client requested 50 rooms (`GET /v1/rooms/active?limit=50`), Prisma's Rust query engine attempted to resolve the relation for all 50 rooms.
- Because `creator` returned `null` for the orphaned record despite being marked non-nullable in the schema, Prisma threw:
  `PrismaClientUnknownRequestError: Inconsistent query result: Field creator is required to return data, got null instead.`
- This unhandled Prisma exception caused Express to return **HTTP 500 Internal Server Error**.
- In the mobile client (`backend_repository.dart` line 204), `fetchLiveRooms()` wrapped the HTTP call in:
  ```dart
  try {
    final remoteRooms = await RoomRepository.instance.getActiveRooms(...);
    ...
  } catch (_) {
    return _liveRooms; // Silently swallowed!
  }
  ```
- Because the exception was swallowed, `_liveRooms` remained an empty list `[]`. Newly connected users were greeted with an empty screen.
- In contrast, already-connected users received the live room directly via the Socket.IO broadcast event `room:created` (`socket.roomCreatedStream.listen((data) => addLiveRoom(room))`), placing the room in memory prior to the failed refresh call.

### Secondary Contributing Cause (Discovery Ordering & Inactive Room Flooding)
In `room.repository.js`, `findActiveRooms()` ordered results by:
```js
orderBy: [
  { isPinnedTop: 'desc' },
  { pinnedPosition: 'asc' },
  { currentViewersCount: 'desc' },
  { createdAt: 'desc' },
]
```
- A newly created live room naturally begins with `currentViewersCount: 0`.
- The database contained dozens of stale test rooms with artificial viewer counts (45 to 215 viewers).
- Because `currentViewersCount: 'desc'` preceded `createdAt: 'desc'`, newly started rooms were ranked behind 49 inactive rooms. When paginated (page=1, limit=20), the new room was never included on page 1.

### Tertiary Contributing Cause (Missing Automatic Stale Room Lifecycle Reaping)
`roomTimer.manager.js` maintained host absence timers in an in-memory `Map`. Whenever the backend process restarted or redeployed, in-memory timers were lost. Rooms abandoned by disconnected hosts remained stuck in `status: 'LIVE'` indefinitely with no startup or background cleanup.

### Fourth Contributing Cause (Category Normalization Overwrite)
In `room.validator.js` (`queryActiveRoomsSchema`), any query parameter containing the word `LIVE` or `PARTY` was mapped to `category: 'CHAT'`. If a client passed `category=Live`, any legitimate live room under `MUSIC` or `GAMING` was filtered out at the SQL level.

---

## 3. Backend Changes Made

### 1. `backend/src/repositories/room.repository.js`
- **Orphaned Relation Protection**: Added `creator: { id: { not: '' } }` to the `where` clause of `findActiveRooms()` and `findAdminRooms()`. This forces an inner join at the PostgreSQL level, completely preventing Prisma from encountering `null` relations and preventing `PrismaClientUnknownRequestError`.
- **Chronological Discovery Ordering**: Updated `orderBy` in `findActiveRooms()` to:
  ```js
  orderBy: [
    { isPinnedTop: 'desc' },
    { pinnedPosition: 'asc' },
    { createdAt: 'desc' },
    { currentViewersCount: 'desc' },
  ]
  ```
  Pinned rooms remain in top slots (1, 2, 3), while newly created live streams and party rooms immediately appear at the top of the feed for all users.
- **Privacy Protection**: Enforced `isPrivate: Boolean(isPrivate)` (default `false`) so private/password-protected rooms are not leaked in the public discovery feed.
- **Canonical Model Selection**: Explicitly added `creatorUserId: true` to the selected fields so `LiveRoomModel` parses the direct host ID seamlessly.

### 2. `backend/src/validators/room.validator.js`
- Fixed `category` preprocessing in `queryActiveRoomsSchema`:
  - `ALL`, `POPULAR`, `EXPLORE`, and `LIVE` no longer force `category = 'CHAT'`; they evaluate to `undefined` (matching all categories across video and audio rooms).
  - Added optional `isPrivate` boolean query parameter (defaults to `false`).

### 3. `backend/src/services/room.service.js`
- Added `cleanupStaleRooms(db = prisma)`:
  - Automatically sweeps rooms with `status: 'LIVE'` created more than 24 hours ago and marks them `ENDED`.
  - Automatically identifies and archives orphaned rooms whose creators no longer exist in the `User` table.

### 4. `backend/src/socket/room.socket.js`
- Implemented `onRequestActiveRooms`:
  - Registered real-time socket handlers for `rooms:get_active`, `rooms_get_active`, and `rooms:list`.
  - Rate-limited to 15 calls/second per socket.
  - Allows newly connected and reconnecting socket clients to retrieve the authoritative snapshot of active rooms directly over Socket.IO without relying solely on REST polling.

### 5. `backend/src/server.js`
- Wired `roomService.cleanupStaleRooms()` into the database connection startup lifecycle alongside `runStartupRecoverySweep()`.

---

## 4. API & Socket Contracts

### REST Endpoint: Get Active Live Rooms
- **Method & Path**: `GET /api/v1/rooms/active` (also available at `/v1/rooms/active` and `/api/rooms/active`)
- **Authentication**: Optional (publicly accessible by unauthenticated and authenticated users alike)
- **Query Parameters**:
  - `page` (optional integer, default: `1`)
  - `limit` (optional integer, min: 1, max: 100, default: `50`)
  - `roomType` (optional enum: `LIVE_VIDEO` | `AUDIO_PARTY`)
  - `category` (optional enum: `MUSIC` | `CHAT` | `GAMING`)
  - `search` (optional string)
  - `isPrivate` (optional boolean, default: `false`)
- **Success Response (200 OK)**:
  ```json
  {
    "success": true,
    "message": "Active rooms retrieved successfully",
    "data": [
      {
        "id": "6a8a8a70-b9d0-4fbf-9e7b-f2eeb419a97a",
        "creatorUserId": "2328172",
        "title": "Acoustic Jam Night",
        "coverImageUrl": "https://...",
        "roomType": "AUDIO_PARTY",
        "category": "MUSIC",
        "isPrivate": false,
        "agoraChannelName": "room_f6ca7b66c1c84852a422aad81f59ca19",
        "isPinnedTop": false,
        "pinnedPosition": null,
        "currentViewersCount": 12,
        "status": "LIVE",
        "createdAt": "2026-10-13T06:52:40.189Z",
        "creator": {
          "id": "2328172",
          "username": "musician_pro",
          "avatarUrl": "https://...",
          "countryCode": "GLOBAL",
          "region": "Global",
          "userType": "USER",
          "profile": {
            "displayName": "Musician Pro",
            "level": 12,
            "vipLevel": 1,
            "svipLevel": 0,
            "nobleRank": "Baron",
            "followersCount": 420,
            "followingCount": 150,
            "isPrivate": false
          }
        },
        "seats": [
          {
            "seatIndex": 0,
            "occupiedUserId": "2328172",
            "isLocked": false,
            "isMuted": false
          }
        ]
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "total": 1,
      "totalPages": 1
    }
  }
  ```

### Socket.IO Event: Request Active Rooms Snapshot
- **Event Name**: `rooms:get_active` (aliases: `rooms_get_active`, `rooms:list`)
- **Direction**: Client -> Server (with optional acknowledgement callback)
- **Request Payload**:
  ```json
  {
    "limit": 50,
    "page": 1,
    "roomType": "AUDIO_PARTY",
    "category": "CHAT"
  }
  ```
- **Response Event**: `rooms:active_list`
- **Response Payload**:
  ```json
  {
    "success": true,
    "data": [ /* Array of active LiveRoomModel objects */ ],
    "rooms": [ /* Array of active LiveRoomModel objects */ ],
    "pagination": { "page": 1, "limit": 50, "total": 1, "totalPages": 1 },
    "timestamp": "2026-10-13T12:00:00.000Z"
  }
  ```

---

## 5. Mobile Developer Action Items (Flutter)

Please review this checklist for the mobile client (`mobile app/lib/`):

1. **Verify `catch (_)` Logging in `backend_repository.dart`**:
   - In `BackendRepository.fetchLiveRooms()`, replace the silent `catch (_)` with `catch (e, stack) { debugPrint('[BackendRepo] fetchLiveRooms error: $e'); }`. Silent catch blocks conceal network and schema parsing errors.
2. **Handle Socket Reconnection Resynchronization**:
   - In `SocketService.onConnect`, emit `rooms:get_active` or call `BackendRepository.instance.fetchLiveRooms()` to refresh the active list upon network reconnection.
3. **Deduplicate `addLiveRoom` with `fetchLiveRooms`**:
   - When receiving `room:created` via socket, the client currently calls `addLiveRoom(room)` followed by `fetchLiveRooms()`. This sequence is correct and now succeeds reliably.
4. **Pull-to-Refresh Verification**:
   - In `LiveDiscoveryGrid`, pulling down to refresh triggers `BackendRepository.instance.fetchLiveRooms()`, which now returns the latest live rooms immediately.
5. **No Mobile Changes Were Made**:
   - In compliance with project boundaries, no files in `d:\Ze-Party\mobile app` were modified.

---

## 6. Verification Test Results

Targeted test suite `backend/scripts/test_live_room_discovery_spec.js` was executed:
- **Test A: Room Creation & Database Persistence**: PASSED
- **Test B: Newly Connected User Discovery via REST Snapshot**: PASSED
- **Test C: Multiple Rooms & Chronological Ordering Priority**: PASSED
- **Test D: Privacy Protection (Private Rooms Excluded)**: PASSED
- **Test E: Socket.IO Authoritative Snapshot Handler (`rooms:get_active`)**: PASSED
- **Test F: Room Termination & Discovery Exclusion**: PASSED
- **Test G: Orphaned Record Resilience**: PASSED
- **Total Test Result**: **17 / 17 tests passed (100% success rate)**.

Additionally, `backend/scripts/test_admin_analytics_spec.js` was verified:
- **Result**: **6 / 6 tests passed (100% success rate)**.

---

## 7. Ownership Boundary Confirmation

- **Backend modifications**: Fully implemented, verified, and constrained strictly to `D:\Ze-Party\backend`.
- **Mobile application**: **No Flutter/Dart files were modified.** Mobile recommendations are documented in this handoff for the mobile engineer.
