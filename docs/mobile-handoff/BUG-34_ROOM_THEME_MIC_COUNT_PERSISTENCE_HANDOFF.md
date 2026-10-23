# Mobile Developer Handoff: Bug #34 — Room Theme and Configured Microphone Count Persistence

**Author:** Senior Backend & Realtime Systems Engineer  
**Scope:** Backend API, Socket.IO Realtime Gateway, and Flutter Mobile Application Integration  
**Document Reference:** `docs/mobile-handoff/BUG-34_ROOM_THEME_MIC_COUNT_PERSISTENCE_HANDOFF.md`  
**Date:** October 23, 2026  
**Status:** BACKEND RESOLVED & VERIFIED / AWAITING MOBILE CLIENT HANDOFF  

---

## 1. Executive Summary & Root Cause Confirmation

In Bug #34, room background themes and configured microphone counts were observed reverting after users left and returned, minimized/restored the app, restarted the application, or closed and reopened the same room.

Inspection of the PostgreSQL database records for host **Javis (`creatorUserId: "9202535"`)** revealed the precise cause:
- **Screen 1:** Orange theme, 11 seats, Room ID `b0fad442-f4d2-443e-a793-3f728c5cc513` (ended at `2026-10-20T09:25:26.744Z`).
- **Screen 2:** Purple default theme, 10 default seats, Room ID `a2cdb114-6251-4087-9949-c09be95b3d78` (created at `2026-10-20T09:25:27.112Z` — exactly 368 milliseconds later).

### The Root Causes:
1. **Room Identity Abandonment on Reopen:** In `backend/src/services/room.service.js`, `createRoom` previously searched only for active rooms where `status === 'LIVE'`. When a host ended or closed their room (`status === 'ENDED'`), opening the room again failed to locate the persistent room, generating a brand new UUID room, abandoning the host's configured 11 seats, and defaulting `backgroundImageUrl` to `null` (which the mobile app displays as the default purple background).
2. **Missing Seat Capacity in Creation/Reopening Handlers:** `createRoom` and `createRoomSchema` previously discarded `capacity` and `seatCapacity` parameters, forcing `createRoomWithSeats` to always fall back to startup defaults (10 seats).
3. **Null/Missing Parameter Theme Overwrite:** If a client re-entered or resumed without explicitly sending `backgroundImageUrl` (e.g. `backgroundImageUrl: null` or `""`), the backend previously allowed empty values to overwrite the persistent saved theme URL.

### Backend Fix Applied:
- Resuming or reopening a room (`createRoom` with `forceNew: false`) now locates the host's authoritative persistent room record, transitions it back to `'LIVE'`, retains the stable room UUID (`b0fad4...`), regenerates a fresh Agora channel, and preserves the saved `backgroundImageUrl` and configured `RoomSeat` count.
- Stale temporary seat occupants (`occupiedUserId`, temporary mute flags) are vacated, placing only the host on Seat 0 for audio parties.
- `capacity` and `seatCapacity` (8 to 30) are now accepted and persisted.
- Stale or missing client fields will **never** overwrite a valid saved theme or seat count.
- Theme aliases (`themeUrl`, `theme`, `background`, `backgroundImageUrl`) and layout aliases (`seatCapacity`, `capacity`, `seats`) are included in all REST snapshots and Socket.IO payloads.

---

## 2. Relevant Existing Backend Endpoints & Realtime Events

### 2.1 REST Endpoints

| Method | Endpoint | Description | Permitted Roles | Key Request Fields | Key Response Fields |
|---|---|---|---|---|---|
| `POST` | `/api/v1/rooms` | Create, resume, or reopen persistent room | Authenticated User | `title`, `roomType`, `category`, `backgroundImageUrl` *(optional)*, `capacity` *(optional)*, `forceNew` *(default: false)* | Full authoritative room record (`id`, `backgroundImageUrl`, `seatCapacity`, `seats`, etc.) |
| `GET` | `/api/v1/rooms/:id` | Fetch authoritative room snapshot | Public / Authenticated | None | `id`, `backgroundImageUrl`, `themeUrl`, `background`, `seatCapacity`, `capacity`, `seats` |
| `POST` | `/api/v1/rooms/:id/join` | Join room session | Authenticated User | `pin` *(if private)* | Room record, `currentViewersCount` |
| `POST` | `/api/v1/rooms/:id/leave` | Leave room session | Authenticated User | None | Updated room snapshot |
| `POST` | `/api/v1/rooms/:id/close` | Explicitly end room session | Room Owner Only | None | `status: "ENDED"`, `summary` |
| `PUT` / `POST` | `/api/v1/rooms/:id/background` | Update persistent background theme | Room Owner Only | `backgroundImageUrl` or `background` | `success: true`, `backgroundImageUrl`, `themeUrl` |
| `DELETE` | `/api/v1/rooms/:id/background` | Remove custom background | Room Owner Only | None | `success: true`, `backgroundImageUrl: null` |
| `PUT` / `POST` | `/api/v1/rooms/:id/layout` | Update mic seat count / layout | Room Owner Only | `capacity` or `seatCapacity` (8–30) | `success: true`, `capacity`, `seatCapacity`, `seats` |

### 2.2 Realtime Socket.IO Events

#### Client to Server (Emitters)
- `room:join` / `join_room`: `{ roomId, pin }` — Subscribes socket to room channel and triggers authoritative `ROOM_SNAPSHOT`.
- `room:leave` / `leave_room`: `{ roomId }` — Unsubscribes socket and triggers authoritative seat release if user occupied a mic.
- `room:request_snapshot`: `{ roomId }` — Explicitly requests a fresh authoritative room snapshot.
- `room:update_background`: `{ roomId, backgroundImageUrl }` — Explicitly updates room background theme (Owner only).
- `room:update_layout` / `room:change_layout`: `{ roomId, capacity }` — Explicitly updates microphone seat count (Owner only).

#### Server to Client (Listeners)
- `ROOM_SNAPSHOT` / `room:snapshot`:
  ```json
  {
    "id": "b0fad442-f4d2-443e-a793-3f728c5cc513",
    "roomId": "b0fad442-f4d2-443e-a793-3f728c5cc513",
    "creatorUserId": "9202535",
    "title": "Javis's Party",
    "status": "LIVE",
    "backgroundImageUrl": "https://assets.zeparty.app/themes/sunset_orange_custom.png",
    "themeUrl": "https://assets.zeparty.app/themes/sunset_orange_custom.png",
    "background": "https://assets.zeparty.app/themes/sunset_orange_custom.png",
    "theme": "https://assets.zeparty.app/themes/sunset_orange_custom.png",
    "seatCapacity": 12,
    "capacity": 12,
    "seats": [
      { "seatIndex": 0, "isLocked": false, "isMuted": false, "occupiedUserId": "9202535", "user": { ... } },
      ...
      { "seatIndex": 11, "isLocked": false, "isMuted": false, "occupiedUserId": null, "user": null }
    ]
  }
  ```
- `room:background_updated` / `room:theme_updated`:
  ```json
  {
    "roomId": "b0fad442-f4d2-443e-a793-3f728c5cc513",
    "backgroundImageUrl": "https://assets.zeparty.app/themes/sunset_orange_custom.png",
    "themeUrl": "https://assets.zeparty.app/themes/sunset_orange_custom.png",
    "updatedBy": "9202535",
    "timestamp": "2026-10-23T13:15:00.000Z"
  }
  ```
- `room:layout_updated` / `room:mic_count_updated`:
  ```json
  {
    "roomId": "b0fad442-f4d2-443e-a793-3f728c5cc513",
    "capacity": 12,
    "seatCapacity": 12,
    "seats": [ ... ],
    "timestamp": "2026-10-23T13:15:00.000Z"
  }
  ```

---

## 3. Client Fetch and Update Lifecycle

To eliminate any visual flickering or inadvertent resetting to defaults, the Flutter application must adhere to the following contract:

```
[User Taps 'Go Live' / 'Open Room']
                │
                ▼
      POST /api/v1/rooms
      { "forceNew": false } ──────────────► Backend returns authoritative persistent room
                │                           (Same UUID, saved theme, saved seat count)
                ▼
   Initialize UI with returned room
   (Do NOT reset theme to purple or seats to 10!)
                │
                ▼
   Connect Socket & Emit room:join
                │
                ▼
   Receive ROOM_SNAPSHOT ────────────────► Reconcile any realtime seat occupants
```

### 3.1 Distinguishing Loading State from Saved Settings
1. **Never render purple background or 10-seat grid as a fallback during active fetch.**
   - While awaiting the response from `POST /api/v1/rooms` or `GET /api/v1/rooms/:id`, display a lightweight shimmer / translucent placeholder overlay over the cached room view.
   - Do **NOT** initialize state variables with hardcoded `purpleTheme` or `seats = 10` before the HTTP response or socket snapshot arrives.
2. **Authoritative Null Check:**
   - A background theme should only be rendered as the default color if the backend explicitly returns:
     `backgroundImageUrl == null && themeUrl == null` **after** loading has completed (`isLoading == false`).
   - If `backgroundImageUrl` is a valid string URL, immediately render that image using cached network image with memory caching enabled.
3. **Seat Count Derivation:**
   - Seat count must strictly be derived from `snapshot.seatCapacity ?? snapshot.seats?.length ?? 10`.
   - Never truncate the seat list to a hardcoded 8 or 10 seats if the backend returns 12, 16, or 20 seats.

---

## 4. Required Mobile UI Behavior

### 4.1 On Leave & Rejoin
- When the host or a viewer leaves a room, clear the local live playback state (Agora audio/video channels).
- When re-entering the room, call `GET /api/v1/rooms/:id` and emit `room:join`.
- Populate the view directly with the persisted `backgroundImageUrl` and configured `seats` from the response.

### 4.2 On Minimize & Restore
- ZeParty maintains a **3-minute host absence grace period** upon minimizing or temporary network loss.
- When the mobile app is brought back to the foreground:
  1. Verify Socket.IO connection status. If disconnected, reconnect socket.
  2. Emit `room:request_snapshot` with `{ roomId }`.
  3. When `ROOM_SNAPSHOT` is received, smoothly update the mic seats and viewer list.
  4. The background theme must remain unchanged; do not trigger a rebuild that reverts to purple.

### 4.3 On App Kill & Restart
- If the host closed the room or the app was terminated:
  - When the host returns and taps "Start Live" / "Audio Party", the mobile app calls `POST /api/v1/rooms` with `{ forceNew: false }`.
  - The backend revives the host's persistent room with the **same Room ID**.
  - The returned payload contains the saved `backgroundImageUrl` and configured `capacity`.
  - The mobile app should resume directly into this room without generating a local placeholder state.

---

## 5. Mobile-Side Fix Checklist & Contract Mismatches

| # | Inspection Point | Mobile Side Required Action |
|---|---|---|
| 1 | `POST /api/v1/rooms` Payload | Do **NOT** send `backgroundImageUrl: ""` or `backgroundImageUrl: null` when reopening. Either omit the key or send the cached URL. |
| 2 | Room ID Caching | Do not generate client-side temporary UUIDs for rooms. The room UUID generated by the backend is persistent and authoritative. |
| 3 | Theme Event Subscriptions | Ensure Flutter listens to both `room:background_updated` and `room:theme_updated`. Both events are emitted simultaneously by the backend. |
| 4 | Layout Event Subscriptions | Ensure Flutter listens to `room:layout_updated`, `room_layout_updated`, and `room:mic_count_updated`. |
| 5 | State Redux / Riverpod / Bloc | Ensure `RoomState.initial()` does not overwrite an existing room model with default values when navigating between screens. |

---

## 6. Manual Two-Phone Verification Steps

Perform this exact test sequence to verify cross-device persistence and visual synchronization:

### Equipment
- **Phone A:** Host device running ZeParty Flutter App.
- **Phone B:** Viewer device running ZeParty Flutter App.

### Steps:
1. **Phone A (Host Setup):**
   - Log in as Host (e.g. Javis).
   - Tap "Go Live" / "Audio Party".
   - Note the Room ID displayed in room info (e.g. `b0fad4...`).
   - Open Room Settings -> Change Theme -> Select "Sunset Orange" theme.
   - Open Room Settings -> Change Layout -> Select **12 Seats** (or 16 Seats).
   - Verify Phone A displays the Orange theme and 12 microphone seats.
2. **Phone B (Viewer Verification):**
   - Open ZeParty Discovery. Join Host's room.
   - Verify Phone B immediately displays the Orange theme and 12 microphone seats.
3. **Phone A (Minimize & Restore):**
   - Press the Home button on Phone A to minimize the app for 15 seconds.
   - Restore ZeParty on Phone A.
   - Verify Phone A still displays the Orange theme, 12 seats, and stable Room ID.
4. **Phone A (Leave & Rejoin):**
   - On Phone A, tap the exit icon to leave the room.
   - From the main screen, tap "Return to Live Room" or "Start Live".
   - Verify the Room ID is unchanged (`b0fad4...`).
   - Verify the Orange theme and 12 seats load immediately without reverting to purple.
5. **Phone A (App Termination & Reopen):**
   - On Phone A, end the room session.
   - Force kill the ZeParty mobile app from the OS task switcher.
   - Relaunch the ZeParty app.
   - Tap "Start Live" / "Audio Party".
   - Verify the room is reopened with the **exact same persistent Room ID**, the **Orange background theme**, and **12 microphone seats**.
6. **Phone B (Cross-Device Confirmation):**
   - On Phone B, verify the room appears in the discovery feed.
   - Re-enter the room on Phone B.
   - Confirm Phone B displays the identical Orange theme and 12 microphone seats.
