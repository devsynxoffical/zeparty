# Backend Developer Specification Report: Room Controls, Games & Lucky Bag
**Repository**: ZeParty (Backend & Socket Architecture)  
**Scope**: Items 03, 04 (including Mic 7 & 8 Lock Fix), 05, 06, 07, 08, 09, 10, 11  
**Frontend Status**: Completed purely on Flutter client. No backend code modified.  

---

## 1. Item 03 — Room Routine Actions (Mic Mute, Audio Toggle)
### Frontend Changes
- Success toasts/snackbars were removed on the client for routine toggles (`mute/unmute mic`, `room audio on/off`).
- State is reflected purely via UI icon and local audio stream changes.

### Backend Socket Expectations
- Keep socket handlers idempotent: `room:toggle_mute`, `room:audio_stream_state`.
- Emit error events only on actual state change failure (`room:action_error`) with error code and rollback message.

---

## 2. Item 04 — Mic Seat Indexing Alignment & Addendum (Seat 7 & 8 Locking)
### Frontend Changes & Root Cause Analysis
- **The Issue**: In standard 10-mic party rooms, users reported that **Seat 7 and Seat 8 were not locking** (`04 MA 7 8 SEAT LOCK NI HO RAI US CHZ KO BHI CHK KRO`).
- **Root Cause Identified**:
  1. Standard party rooms have 8 audience mics + Host + Co-Host = **10 total mic seats** (`seatIndex` 0 to 9).
  2. The room grid (`MultiRoleSeatGrid`) rendered all 10 seats (0 = Host, 1 = Co-Host, 2..9 = Mics 1..8).
  3. However, `_showSeatLockDialog` was querying `itemCount = activeRoom.seatCapacity` (which was stored as 8). Because only 8 items were rendered in the lock modal (indices 0..7), **Seat 7 (index 8) and Seat 8 (index 9) were completely excluded from the dialog!**
  4. Furthermore, index 1 was labeled `Seat 2`, index 2 labeled `Seat 3`, creating a 1-off visual shift.
- **Frontend Resolution**:
  - Enforced effective capacity minimum of 10 for standard rooms: `totalSeats = [10, 15, 20, 30].contains(activeRoom.seatCapacity) ? activeRoom.seatCapacity : 10;`.
  - Canonical zero-based indexing standard enforced across all widgets:
    - `index = 0`: **Host Mic**
    - `index = 1`: **Co-Host Mic**
    - `index = 2`: **Mic 1**
    - `index = 3`: **Mic 2**
    - `index = 4`: **Mic 3**
    - `index = 5`: **Mic 4**
    - `index = 6`: **Mic 5**
    - `index = 7`: **Mic 6**
    - `index = 8`: **Mic 7 (Seat 7)** — Now renders and toggles properly in lock dialog
    - `index = 9`: **Mic 8 (Seat 8)** — Now renders and toggles properly in lock dialog
  - Mic lock, unlock, mute, and invite endpoints now pass the exact 0-indexed integer `seatIndex`.

### Backend Socket Requirements
- Ensure `room:lock_seat` and `room:unlock_seat` payload handlers accept `seatIndex` from 0 up to `seatCapacity - 1` (e.g. 0 to 9 for 10-seat rooms, 0 to 14 for 15-seat rooms, etc.):
  ```json
  {
    "roomId": "room_123",
    "seatIndex": 8, // 0-based integer (Seat 7 = index 8, Seat 8 = index 9)
    "isLocked": true
  }
  ```
- Broadcast `room:seat_locked_status` with `seatIndex` matching the exact grid index so all devices update the corresponding seat:
  ```json
  {
    "roomId": "room_123",
    "seatIndex": 8,
    "isLocked": true
  }
  ```
- Server must persist the set of locked seat indices in Redis or DB room document (`lockedSeats: [8, 9]`) and deliver it in the initial `room:snapshot` upon user connection.

---

## 3. Item 05 — Participant Elimination Lucky Wheel
### Overview
The simple instant Super Wheel is upgraded to a multi-round Participant Elimination Lucky Wheel.

### Socket Events & Contracts Needed
1. **Create/Open Wheel Lobby**:
   - `wheel:create_session`:
     ```json
     {
       "roomId": "room_123",
       "hostId": "user_host",
       "entryCoinFee": 0, // or 50, 100, 200, 500, etc.
       "maxParticipants": 10,
       "onlySeatedMics": false
     }
     ```
   - Server broadcasts `wheel:session_created` to all room participants.

2. **Participant Join**:
   - `wheel:join_session`:
     ```json
     {
       "sessionId": "wheel_session_abc",
       "userId": "user_456"
     }
     ```
   - Server checks wallet balance (if `entryCoinFee > 0`), deducts entry fee atomically, prevents duplicate joins, and broadcasts `wheel:participant_joined` with updated participant array.

3. **Spin & Elimination (Server-Determined)**:
   - `wheel:spin_round`: Host triggers spin for the current round.
   - Server randomly selects 1 remaining participant to be eliminated:
     ```json
     {
       "sessionId": "wheel_session_abc",
       "roundNumber": 1,
       "eliminatedUserId": "user_456",
       "remainingUserIds": ["user_1", "user_2", ...],
       "targetAngleDegrees": 142.5 // or segment index
     }
     ```
   - Server emits `wheel:round_eliminated` to all clients before animation completes.

4. **Winner & Reward Settlement**:
   - When only 1 participant remains, server marks `wheel:session_completed`:
     ```json
     {
       "sessionId": "wheel_session_abc",
       "winnerUserId": "user_1",
       "rewardCoins": 500 // total pot or configured prize
     }
     ```
   - Server credits winner balance atomically. If session cancelled, refund entry fees.

---

## 4. Item 06 — Normal vs. World Lucky Bag Modes
### Overview
The Lucky Bag creation UI is separated into two tabs:
1. **Normal Lucky Bag**: In-room only.
2. **World Lucky Bag**: Global cross-room notification banner + shared claim pool.

### Required Fields & Parameters
- **Mode**: `"normal"` | `"world"`
- **Total Coins**: Configurable budget (e.g. 500 to 100,000 coins). Deducted once from sender's wallet upon creation.
- **Quantity**: Max claims (e.g. 5 to 100 users).
- **Task Requirement**:
  - `"none"`: Anyone can claim.
  - `"follow_sender"`: Claimant must follow the bag creator.
  - `"follow_room"`: Claimant must follow the room/host.
- **Countdown Timer**:
  - `0`: Available immediately.
  - `300`: 5 minutes countdown before claims open.

### Socket & API Contracts
1. **Creation**:
   - `POST /api/lucky-bag/create` or socket `luckybag:create`:
     ```json
     {
       "roomId": "room_123",
       "creatorId": "user_abc",
       "mode": "world", // or "normal"
       "totalCoins": 5000,
       "quantity": 20,
       "taskType": "follow_sender", // "none" | "follow_sender" | "follow_room"
       "countdownSeconds": 300
     }
     ```
2. **Broadcast Behavior**:
   - **Normal**: Emitted to `room_${roomId}` socket room only: `luckybag:normal_created`.
   - **World**: Emitted to global socket channel `world:global_event`:
     ```json
     {
       "type": "world_lucky_bag",
       "bagId": "bag_987",
       "sourceRoomId": "room_123",
       "sourceRoomTitle": "VIP Party Lounge",
       "creator": { "id": "user_abc", "name": "Host Alex", "avatar": "..." },
       "totalCoins": 5000,
       "remainingClaims": 20,
       "opensAt": 1776250000000
     }
     ```
3. **Claiming**:
   - Socket `luckybag:claim`:
     ```json
     {
       "bagId": "bag_987",
       "userId": "user_claimant"
     }
     ```
   - Server validates:
     - Countdown has elapsed (`now >= opensAt`).
     - Task completed (verify follow relationship).
     - User has not already claimed (`claimedUserIds`).
     - `remainingClaims > 0` and remaining budget > 0.
   - Server generates random coin share (sum equal to totalCoins, bounded between min 1 and remaining budget).
   - Server credits claimant wallet atomically and decrements claims.
   - Emits `luckybag:claimed` with claimant info, amount won, and remaining claims.

---

## 5. Item 07 — Room Lock Settings & Access Verification
### Overview
Room locking persists in database and is enforced whenever any user attempts entry.

### Required Database & State Fields
- `LiveRoom.isLocked`: boolean (true/false)
- `LiveRoom.lockMode`: `"pin"` | `"approval"`
- `LiveRoom.pinCode`: string (4-digit hash, never returned in public room listings)
- `LiveRoom.pendingApprovalUserIds`: array of user IDs requesting entry

### API / Socket Requirements
1. **Update Lock Settings**:
   - `POST /api/rooms/:id/lock-settings` or socket `room:update_lock`:
     ```json
     {
       "roomId": "room_123",
       "isLocked": true,
       "lockMode": "pin", // or "approval"
       "pinCode": "1234"
     }
     ```
   - Persists on room document in MongoDB/Redis.
   - Emits `room:lock_updated` to all connected clients in the room.

2. **Room Entry Verification Flow**:
   - In Party / Room list:
     - Include `isLocked: true`, `lockMode: "pin" | "approval"` in public room payload.
     - **NEVER** expose `pinCode` in the list payload.
   - When user enters room:
     - If `isLocked == false` or user is Owner/Admin: Admit directly.
     - If `lockMode == "pin"`:
       - Validate entered 4-digit PIN against room `pinCode`. Reject with `INVALID_PIN` if wrong.
     - If `lockMode == "approval"`:
       - User sends `room:request_entry`. Server notifies owner/admins via push/socket.
       - Owner accepts `room:approve_entry`: Server admits user.

---

## 6. Item 01 — Real-Time Room Event Broadcasting (Gifts & Chat Messages)
### Overview
When gifts or chat messages are sent in a party room, all participants (sender, recipient, host, and all other room members) must receive the event in real-time on their device feed without needing to refresh or rejoin.

### Real-Time Gift Event Contract
1. **Trigger**:
   - When a gift transaction is authorized and ledger-posted via `POST /api/gifts/send` or realtime client emission `room:gift_send`.
   - **Important**: Only confirmed, successful gifts must be broadcast. Failed or rejected transactions must never emit to the room.
2. **Authoritative Socket Broadcast**:
   - Emit `room:gift_sent` (supported aliases: `gift:sent`, `room:gift`) to the room socket room `room:${roomId}`.
   - **Payload Specification**:
     ```json
     {
       "transactionId": "tx_1729012345678_user123",
       "id": "tx_1729012345678_user123",
       "roomId": "room_123",
       "giftId": "gift_magic_wand",
       "giftName": "Magic Wand",
       "giftIcon": "🪄",
       "quantity": 1,
       "sender": {
         "id": "user_alexa",
         "name": "Alexa",
         "username": "alexa",
         "avatarUrl": "https://..."
       },
       "senderUserId": "user_alexa",
       "senderName": "Alexa",
       "senderAvatar": "https://...",
       "receiver": {
         "id": "user_javis",
         "name": "Javis",
         "username": "javis",
         "avatarUrl": "https://..."
       },
       "receiverUserId": "user_javis",
       "receiverName": "Javis",
       "receiverAvatar": "https://...",
       "timestamp": "2026-10-15T10:30:00.000Z"
     }
     ```
3. **Idempotency & Deduplication**:
   - Every broadcast must include a stable `transactionId` (or `id`).
   - Clients track processed `transactionId`s to prevent duplicate feed entries on reconnect or alias reflection.

### Real-Time Chat Message Contract
1. **Socket Broadcast**:
   - Server listens for `room:chat_send` and immediately broadcasts `room:chat_message` to the room room channel.
   - **Payload Specification**:
     ```json
     {
       "id": "msg_1729012345678_user_alexa",
       "clientMessageId": "msg_1729012345678_user_alexa",
       "roomId": "room_123",
       "text": "hi",
       "type": "text",
       "sender": {
         "id": "user_alexa",
         "name": "Alexa",
         "username": "alexa",
         "avatarUrl": "https://..."
       },
       "senderUserId": "user_alexa",
       "senderName": "Alexa",
       "createdAt": "2026-10-15T10:30:05.000Z"
     }
     ```
2. **Room History Window on Reconnect / Initial Join**:
   - In `room:snapshot` (or `GET /api/rooms/:id/snapshot`):
     - Include `messages`: array of the last 50 room events (chat messages, gift activities, system announcements) ordered by `createdAt ASC`.
     - When rejoining or recovering from brief disconnects, clients merge recent events by `id`, ensuring zero missing messages and zero duplicate entries.

---

## 6. Item 08 — Room Trophy Counter & Daily Sending Total Sync
### Frontend Changes & Root Cause Analysis
- **The Issue**: Room trophy counter in the room header stayed at `0` despite active gift sending, while opening the daily ranking sheet correctly showed the accumulated total (e.g. `6.8K`).
- **Root Cause Identified**:
  - The room header trophy counter was previously bound to `activeRoom.host.diamonds` (the host's personal diamond wallet balance, which was `0`).
  - The true room sending volume is an aggregate of all gifts sent in the room during the active period (matching the daily ranking sheet calculation).
- **Frontend Resolution**:
  - Bound header trophy counter directly to `livePartyProvider.roomSendingTotal`.
  - Displayed via compact numeric formatter (`6.8K`, `1.2M`, etc.).
  - On room join (`joinParty`), the client fetches the authoritative daily total via `RoomRepository.instance.getRoomSendingRankings` and initializes `roomSendingTotal` from the Daily tab's total.
  - When confirmed gift events arrive (`room:gift_sent` / confirmed gift sends), `roomSendingTotal` increments automatically and is persisted in `RoomConfigManager` on device.
  - Client also listens to real-time `room:sending_total_updated` socket events.

### Backend Requirements & Contracts
1. **Room Initial State / Snapshot**:
   - `GET /api/rooms/:id` and `room:snapshot` must include the current session / daily room sending total:
     ```json
     {
       "id": "room_123",
       "sendingTotal": 6800,
       "dailySendingTotal": 6800
     }
     ```
2. **Real-Time Increment Event**:
   - Whenever a gift is settled in the room, the backend must emit `room:sending_total_updated` to `room:${roomId}`:
     ```json
     {
       "roomId": "room_123",
       "sendingTotal": 6800,
       "incrementAmount": 200,
       "senderId": "user_alexa",
       "receiverId": "user_javis",
       "timestamp": "2026-10-15T12:00:00.000Z"
     }
     ```
3. **Idempotency**:
   - Server must calculate `sendingTotal` atomically in Redis (`INCRBY room:sending_total:<roomId> <coinValue>`) to ensure absolute accuracy across concurrent gift animations.

---

## 7. Item 09 — Room Title & Cover DP Permanent Persistence & Global Sync
### Frontend Changes & Root Cause Analysis
- **The Issue**: Changing room name and DP in `RoomSettingsScreen` was lost upon leaving and rejoining the room, and was not reflected on Party cards on the home screen or the floating minimized room overlay.
- **Root Cause Identified**:
  - Room edits were only held in temporary in-memory state of the active provider.
  - When rejoining, `RoomRepository.getPartyRooms()` or `fetchLiveRoomById()` fetched the original room metadata from backend mock/DB without local cache overrides.
  - Party cards and floating mini player did not listen to room update broadcasts.
- **Frontend Resolution**:
  - Created `RoomConfigManager` singleton backed by `SharedPreferences`.
  - Added `RoomConfigManager.instance.applyOverrides(LiveRoomModel)` to transparently apply persistent custom title and cover URL across:
    1. Room Header in `LivePartyRoomScreen`.
    2. Room Settings initial state in `RoomSettingsScreen`.
    3. Home and Party Explore cards in `PartyRoomCard`.
    4. Floating minimized picture-in-picture player in `FloatingRoomOverlay`.
  - When host/admin modifies title or cover in settings, `LivePartyProvider` persists the changes to `RoomConfigManager` and emits `room:details_update` over the socket.
  - Client listens for `room:details_updated` and applies updates in real time to all room members.

### Backend Requirements & Contracts
1. **REST Update Endpoint**:
   - When room settings are saved, client calls `PUT /api/rooms/:id` (or `PUT /api/rooms/:id/profile`):
     ```http
     PUT /api/rooms/room_123 HTTP/1.1
     Content-Type: application/json
     Authorization: Bearer <token>

     {
       "title": "VIP Star Lounge ✨",
       "coverUrl": "https://cdn.zeparty.com/room_covers/room_123_dp.jpg",
       "announcement": "Welcome to our party!",
       "membershipFee": 0
     }
     ```
   - Server must authenticate that the user is the room creator/host or an authorized room admin (`allowAdminEditSettings: true`), update the database document, and respond with HTTP 200.
2. **Socket Broadcast Contract**:
   - Server broadcasts `room:details_updated` to the room channel and to the global party lobby:
     ```json
     {
       "roomId": "room_123",
       "title": "VIP Star Lounge ✨",
       "coverUrl": "https://cdn.zeparty.com/room_covers/room_123_dp.jpg",
       "announcement": "Welcome to our party!",
       "seatCapacity": 10,
       "roomType": "AUDIO_PARTY",
       "updatedBy": "user_host_101",
       "timestamp": "2026-10-15T12:05:00.000Z"
     }
     ```
   - When all party room lists (`GET /api/party/rooms`) are requested, the updated title and cover URL must be returned immediately.

---

## 8. Item 10 — Gift Box Dismissal Keyboard Decoupling
### Frontend Changes & Root Cause Analysis
- **The Issue**: Closing the gift dialog was automatically popping up the chat input keyboard and placing focus in the text field without user intention.
- **Root Cause Identified**:
  - The bottom bar in `LivePartyRoomScreen` included an embedded `TextField` that lacked an explicit dedicated `FocusNode` and had `readOnly: false`.
  - When Flutter dismissed the modal bottom sheet (`GiftDialog`), the widget tree's focus traversal returned focus to the first available editable widget (`TextField`) in the underlying screen, triggering the soft keyboard popup.
- **Frontend Resolution**:
  - Created a dedicated `FocusNode _chatFocusNode` specifically for the party room screen.
  - Set `readOnly: true` on the bottom bar chat placeholder `TextField`, routing chat input through the dedicated `_showChatInputDialog(context)` bottom sheet on explicit user tap.
  - In `_openGiftDialog()`:
    1. Explicitly unfocused `_chatFocusNode` and `FocusScope.of(context).unfocus()` prior to opening `GiftDialog`.
    2. Added an unfocus call in `.then((_) { ... })` upon modal dismissal:
       ```dart
       _chatFocusNode.unfocus();
       FocusScope.of(context).unfocus();
       ```
- **Backend Impact**:
  - Purely client UI/focus lifecycle management. No backend socket or REST adjustments required.

---

## 9. Item 11 — Mic Seat Capacity Multi-Device Realtime Sync & Persistence
### Frontend Changes & Root Cause Analysis
- **The Issue**: When host changed seat capacity (e.g. switching from 10 to 15, 20, or 30 seats), the mic count reset back to 8/10 on re-entry and other connected users did not see the expanded mic grid.
- **Root Cause Identified**:
  - Capacity update did not persist to local storage or backend DB; upon re-joining, room model reloaded with default capacity.
  - No socket event was broadcast to other connected room members to rebuild their `MultiRoleSeatGrid`.
- **Frontend Resolution**:
  - Durable persistence: `RoomConfigManager.instance.saveRoomLayout(roomId, capacity: ..., roomType: ...)` persists the new capacity to `SharedPreferences`.
  - Added socket emission: `SocketService.instance.emitRoomLayoutUpdate(roomId: ..., capacity: ..., roomType: ...)`.
  - Added socket stream: `SocketService.instance.onRoomLayoutUpdated`.
  - `LivePartyProvider` subscribes to `onRoomLayoutUpdated`: updates `_activeRoom`, updates `RoomConfigManager`, and calls `notifyListeners()`, causing all connected users to dynamically expand their mic grid.

### Backend Requirements & Contracts
1. **REST Layout Endpoint**:
   - `PUT /api/rooms/:id/layout`:
     ```http
     PUT /api/rooms/room_123/layout HTTP/1.1
     Content-Type: application/json
     Authorization: Bearer <token>

     {
       "seatCapacity": 15,
       "roomType": "AUDIO_PARTY"
     }
     ```
   - Valid capacities: `10`, `15`, `20`, `30`.
   - Server updates `seatCapacity` in the room record so subsequent calls to `GET /api/rooms/:id` return the new capacity.
2. **Socket Event Contract**:
   - Client sends `room:layout_update`:
     ```json
     {
       "roomId": "room_123",
       "seatCapacity": 15,
       "roomType": "AUDIO_PARTY"
     }
     ```
   - Server verifies caller is room host or authorized admin (`allowAdminChangeMode: true`).
   - Server broadcasts `room:layout_updated` to `room:${roomId}`:
     ```json
     {
       "roomId": "room_123",
       "seatCapacity": 15,
       "roomType": "AUDIO_PARTY",
       "updatedBy": "user_host_101",
       "timestamp": "2026-10-15T12:10:00.000Z"
     }
     ```
   - Any mics that were locked beyond the new capacity (e.g., if downsized) should have their locks released.


