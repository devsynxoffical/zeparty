# Backend Developer Specification Report: Room Controls, Games & Lucky Bag
**Repository**: ZeParty (Backend & Socket Architecture)  
**Scope**: Items 03, 04, 05, 06, 07  
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

## 2. Item 04 — Mic Seat Indexing Alignment
### Frontend Changes
- Canonical zero-based indexing standard enforced across all widgets:
  - `index = 0`: Host Mic
  - `index = 1`: Co-Host Mic
  - `index >= 2`: `Mic ${index - 1}` (e.g. index 2 = Mic 1, index 3 = Mic 2, index 8 = Mic 7)
- Mic lock, unlock, mute, and invite endpoints now pass the exact 0-indexed integer `seatIndex`.

### Backend Socket Requirements
- Ensure `room:lock_seat` and `room:unlock_seat` payload handlers:
  ```json
  {
    "roomId": "room_123",
    "seatIndex": 2, // 0-based integer
    "isLocked": true
  }
  ```
- Broadcast `room:seat_locked_status` with `seatIndex` matching the exact grid index so all devices update the corresponding seat.

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
