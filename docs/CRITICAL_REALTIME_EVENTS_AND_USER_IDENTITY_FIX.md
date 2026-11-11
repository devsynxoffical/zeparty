# ZeParty P0 Critical Bug Fix Report: Real-Time Room Events & Authoritative User Identity

**Scope:** Backend (`backend/`) + Admin Panel (`Admin Frontend/`) ONLY  
**Date:** 11 November 2026  
**Status:** Verified & Complete (Zero Flutter/Mobile files modified)

---

## 1. Root Cause Analysis

### 1.1 Bug 1: Real-Time Events (Gifts, Comments, Emojis/Reactions) Only Visible to Sender

Tracing the end-to-end event lifecycle (`Sender Request → Backend Validation → Business Logic → Event Emission → Room Recipients`) across Party Rooms (`AUDIO_PARTY`), Camera Live (`LIVE_VIDEO`), and PK sessions (`PKMatch`) revealed **six compounding root causes**:

1. **REST-Only Room Joining Left User Sockets Unsubscribed from `room:<roomId>`:**
   - When hosts or viewers created/joined a Party Room or Live Stream via REST (`POST /v1/rooms`, `GET /v1/rooms/my-party`, `POST /v1/rooms/:id/join`, `POST /v1/rooms/:id/visit`, `POST /v1/rooms/:id/seats/:seatIndex/occupy`, or `POST /v1/rooms/:id/agora-token`) without emitting `socket.emit('room:join')` on the current socket instance (or after a socket reconnect), their Socket.IO connection was only in `user:<userId>` and **not** in `room:<roomId>`.
   - Consequently, any broadcast to `io.to("room:${roomId}")` failed to reach them, while the sender saw their own optimistic local UI animation/comment.
2. **Double-Transaction & Invalid Prisma Field Failure in Socket Gift Handler (`src/socket/gift.socket.js`):**
   - When the mobile app sent a gift via REST `POST /v1/gifts/send` and then emitted `socket.emit('gift:send')` to trigger real-time broadcasting, `onSendGift` called `giftService.sendGift` a second time (charging the wallet twice or failing on insufficient balance).
   - Furthermore, `syncAndBroadcastRoomSendingTotal` in `src/socket/gift.socket.js` attempted to execute `db.room.update({ data: { roomSendingTotal: ... } })` on a non-existent Prisma column `roomSendingTotal` on `Room`, throwing an unhandled error before room broadcasting completed.
3. **Identifier Mismatch Across Party, Live, and PK (`roomId` vs `sessionId` / `partyRoomId` / `liveSessionId` / `channelName` / `pkId`):**
   - Clients in Camera Live, Party Rooms, or PK battles frequently passed `sessionId`, `liveSessionId`, `partyRoomId`, `channelName` (`agoraChannelName`), or `pkId`/`matchId` instead of `roomId`, or sent gifts where `sendGiftSchema` rejected extra identifier keys.
   - When `roomId` was missing or passed under an alias, `gift.service.js` and `room.socket.js` failed to resolve the canonical `room.id`, causing `room:gift_sent`, `room:chat_message`, and `room:emoji` to either be skipped or emitted to `room:<wrongIdentifier>`.
4. **Missing Cross-Room Broadcasting During Active PK Sessions:**
   - During an active `PKMatch` between `roomAId` and `roomBId`, gifts sent in `roomA` only emitted `room:gift_sent` to `room:${roomAId}` and not to the paired `room:${roomBId}` (or failed to resolve the room when only `pkId`/`matchId` was provided).
5. **Event Name Alias Mismatches (`room:chat` / `room:emoji` / `POST /v1/rooms/:id/mic-reaction`):**
   - `src/socket/room.socket.js` only listened to `room:chat` and `room:emoji`, ignoring mobile event aliases (`room:comment`, `room:comment_send`, `chat:send`, `send_room_emoji`, `room:reaction`, `room:reaction_send`), and only emitted `room:emoji` while `POST /v1/rooms/:id/mic-reaction` only emitted `room:emoji_received`.
6. **Socket Handshake Token Extraction Edge Cases (`src/socket/auth.js`):**
   - If the client passed `"Bearer <jwt>"` inside `socket.handshake.auth.token`, passed the token via `auth.accessToken` / `auth.jwt`, or left `auth.token = "guest_anonymous"` while providing a valid `Authorization` header, `socketAuthMiddleware` either failed JWT verification or downgraded the user to an anonymous guest.

---

### 1.2 Bug 2: Actual User Identities Not Displayed (Generic Agora Users & Static Avatars)

1. **Missing Authoritative `agoraUid` <-> ZeParty User Identity Mapping:**
   - While `src/services/agora.service.js` generated a deterministic 32-bit integer `agoraUid` via `deriveAgoraUid(userId)`, **none** of the room REST APIs (`GET /v1/rooms`, `GET /v1/rooms/:id`, `POST /v1/rooms/:id/join`, `GET /v1/rooms/my-party`) or Socket payloads (`room:snapshot`, `room:stage_sync`, `room:presence_sync`, `room:user_joined`, `room:chat_message`, `room:emoji`, `room:gift_sent`, `pk:snapshot`) included `agoraUid` or an `agoraUidMap` lookup table.
   - When the Agora RTC SDK fired `onUserJoined(remoteUid)` on mobile, the client only had the raw 32-bit integer `remoteUid` with no mapping to the ZeParty account (`id`, `username`, `displayName`, `avatarUrl`), forcing it to display generic `"Agora User <uid>"` labels and static default avatars.
2. **Broken `avatarUrl` Resolution (`user.avatarUrl` vs `user.profile.avatarUrl`):**
   - In `prisma/schema.prisma`, `avatarUrl` is a column on `User`, whereas `displayName`, `level`, `vipLevel`, `svipLevel`, and `nobleRank` are on `UserProfile`.
   - Multiple backend files (`src/socket/auth.js`, `src/socket/room.socket.js`, `src/services/stage.service.js`, `src/repositories/pk.repository.js`) looked up `user.profile?.avatarUrl` (which is always `undefined`) instead of `user.avatarUrl || user.profile?.avatarUrl`, returning `null` for `host.avatarUrl` and participant avatars!
3. **Missing `occupiedUser` Selection on Room Creation & Active Room Queries:**
   - `createRoomWithSeats` in `src/repositories/room.repository.js` did not include `occupiedUser` on `seats`, so newly created rooms returned seats without host profile data.
4. **Admin Panel Identity Stripping & Placeholder Fallbacks:**
   - `Admin Frontend/src/services/modules/liveRooms.service.js`, `LiveRoomsPage.jsx`, `LiveRoomDetailPage.jsx`, and `PKEventsPage.jsx` stripped `agoraHostUid`, `agoraUidMap`, `username`, and `avatarUrl` from participant tables and used broken `https://via.placeholder.com/...` URLs.

---

## 2. Files Inspected

### Backend (`d:\Ze-Party\backend`)
- `package.json`, `src/server.js`, `src/app.js`, `src/config/env.js`, `prisma/schema.prisma`
- `src/utils/agoraToken.util.js`
- `src/services/agora.service.js`, `src/services/room.service.js`, `src/services/stage.service.js`, `src/services/gift.service.js`, `src/services/pk.service.js`
- `src/repositories/room.repository.js`, `src/repositories/pk.repository.js`
- `src/controllers/room.controller.js`, `src/controllers/gift.controller.js`, `src/routes/room.routes.js`, `src/routes/gift.routes.js`
- `src/validators/gift.validator.js`, `src/validators/room.validator.js`
- `src/socket/index.js`, `src/socket/auth.js`, `src/socket/socket.emitter.js`, `src/socket/presence.service.js`, `src/socket/room.socket.js`, `src/socket/seat.socket.js`, `src/socket/gift.socket.js`, `src/socket/pk.socket.js`

### Admin Panel (`d:\Ze-Party\Admin Frontend`)
- `src/services/modules/liveRooms.service.js`, `src/services/modules/pkEvents.service.js`
- `src/pages/admin/LiveRoomsPage.jsx`, `src/pages/admin/LiveRoomDetailPage.jsx`, `src/pages/admin/PKEventsPage.jsx`
- `src/components/common/AgoraVideoPlayer.jsx`

---

## 3. Files Modified & Created

### Backend Modified (16 files)
1. [backend/src/utils/agoraToken.util.js](file:///d:/Ze-Party/backend/src/utils/agoraToken.util.js)
2. [backend/src/socket/auth.js](file:///d:/Ze-Party/backend/src/socket/auth.js)
3. [backend/src/socket/socket.emitter.js](file:///d:/Ze-Party/backend/src/socket/socket.emitter.js)
4. [backend/src/socket/index.js](file:///d:/Ze-Party/backend/src/socket/index.js)
5. [backend/src/socket/presence.service.js](file:///d:/Ze-Party/backend/src/socket/presence.service.js)
6. [backend/src/services/stage.service.js](file:///d:/Ze-Party/backend/src/services/stage.service.js)
7. [backend/src/repositories/room.repository.js](file:///d:/Ze-Party/backend/src/repositories/room.repository.js)
8. [backend/src/repositories/pk.repository.js](file:///d:/Ze-Party/backend/src/repositories/pk.repository.js)
9. [backend/src/socket/room.socket.js](file:///d:/Ze-Party/backend/src/socket/room.socket.js)
10. [backend/src/validators/gift.validator.js](file:///d:/Ze-Party/backend/src/validators/gift.validator.js)
11. [backend/src/services/gift.service.js](file:///d:/Ze-Party/backend/src/services/gift.service.js)
12. [backend/src/socket/gift.socket.js](file:///d:/Ze-Party/backend/src/socket/gift.socket.js)
13. [backend/src/services/agora.service.js](file:///d:/Ze-Party/backend/src/services/agora.service.js)
14. [backend/src/services/room.service.js](file:///d:/Ze-Party/backend/src/services/room.service.js)
15. [backend/src/controllers/room.controller.js](file:///d:/Ze-Party/backend/src/controllers/room.controller.js)
16. [backend/src/routes/room.routes.js](file:///d:/Ze-Party/backend/src/routes/room.routes.js)

### Admin Panel Modified (4 files)
17. [Admin Frontend/src/services/modules/liveRooms.service.js](file:///d:/Ze-Party/Admin%20Frontend/src/services/modules/liveRooms.service.js)
18. [Admin Frontend/src/pages/admin/LiveRoomsPage.jsx](file:///d:/Ze-Party/Admin%20Frontend/src/pages/admin/LiveRoomsPage.jsx)
19. [Admin Frontend/src/pages/admin/LiveRoomDetailPage.jsx](file:///d:/Ze-Party/Admin%20Frontend/src/pages/admin/LiveRoomDetailPage.jsx)
20. [Admin Frontend/src/pages/admin/PKEventsPage.jsx](file:///d:/Ze-Party/Admin%20Frontend/src/pages/admin/PKEventsPage.jsx)

### Tests & Documentation Created (3 files)
21. [backend/tests/critical_realtime_and_identity.test.js](file:///d:/Ze-Party/backend/tests/critical_realtime_and_identity.test.js)
22. [docs/FLUTTER_REALTIME_INTEGRATION_CONTRACT.md](file:///d:/Ze-Party/docs/FLUTTER_REALTIME_INTEGRATION_CONTRACT.md)
23. [docs/CRITICAL_REALTIME_EVENTS_AND_USER_IDENTITY_FIX.md](file:///d:/Ze-Party/docs/CRITICAL_REALTIME_EVENTS_AND_USER_IDENTITY_FIX.md)

---

## 4. Detailed Backend Changes Implemented

1. **Authoritative User Identity & Agora UID Mapping ([agoraToken.util.js](file:///d:/Ze-Party/backend/src/utils/agoraToken.util.js)):**
   - Added `formatAuthoritativeUserIdentity(user, options)` and `buildAgoraUidIdentityMap(participants)`.
   - Deterministically computes `agoraUid = deriveAgoraUid(userId)` and populates `id`, `userId`, `publicId`, `numericUserId`, `agoraUid`, `uid`, `username`, `displayName`, `name`, `avatarUrl` (`user.avatarUrl || user.profile?.avatarUrl`), `avatar`, `countryCode`, `level`, `wealthLevel`, `vipLevel`, `svipLevel`, `isVip`, `nobleRank`, `nobleTitle`, `avatarFrame`, `chatBubble`, `entryEffect`, `role`, `isHost`, and `seatIndex`.
2. **Automatic Socket Room Subscription & Cleanup ([socket.emitter.js](file:///d:/Ze-Party/backend/src/socket/socket.emitter.js), [index.js](file:///d:/Ze-Party/backend/src/socket/index.js), [room.service.js](file:///d:/Ze-Party/backend/src/services/room.service.js), [agora.service.js](file:///d:/Ze-Party/backend/src/services/agora.service.js)):**
   - Added `joinUserSocketsToRoom`, `leaveUserSocketsFromRoom`, and `clearRoomSockets` in `socket.emitter.js`.
   - Wired `joinUserSocketsToRoom` into `createRoom`, `getMyPartyRoom`, `joinRoom`, `occupySeat`, and `issueRoomAgoraToken`.
   - Wired `leaveUserSocketsFromRoom` and `clearRoomSockets` into `leaveRoom`, `handleCleanExitFromPreviousRoom`, `kickRoomUser`, `adminKickUser`, `closeMyRoom`, and `adminCloseRoom`.
   - Updated `socket/index.js` so reconnecting sockets with an active `LIVE` session automatically join `room:<roomId>`.
3. **Canonical Room Resolution & Session Isolation ([room.repository.js](file:///d:/Ze-Party/backend/src/repositories/room.repository.js)):**
   - Added `resolveCanonicalRoom(identifier, { senderUserId, recipientUserId, allowActiveFallback }, db)` to resolve canonical `room.id` by UUID, prefix, `agoraChannelName`, active `PKMatch` ID, or active `LIVE` room of `creatorUserId`, while rejecting ended/closed rooms so stale sessions never receive events.
4. **Gift Validation, Idempotency & Cross-Room PK Broadcasting ([gift.validator.js](file:///d:/Ze-Party/backend/src/validators/gift.validator.js), [gift.service.js](file:///d:/Ze-Party/backend/src/services/gift.service.js), [gift.socket.js](file:///d:/Ze-Party/backend/src/socket/gift.socket.js)):**
   - Added idempotency protection (`idempotencyKey` / `transactionId`) in `gift.service.js` and `gift.socket.js` so duplicate requests or REST-then-Socket notifications never double-charge or double-broadcast.
   - Removed the broken `db.room.update({ data: { roomSendingTotal } })` call in `gift.socket.js`.
   - Broadcasts `room:gift_sent` (plus aliases `gift:received`, `room:gift_received`, `gift:new`) only after DB transaction commit, including full `sender` and `recipient` identities and `agoraUid`s, to `room:<canonicalRoomId>` and both paired PK rooms (`roomAId` and `roomBId`).
   - Preserved all existing coin conversion, wallet policies, commission splits, and ledger rules unchanged.
5. **Comments, Emojis & Identity Lookup Endpoints ([room.socket.js](file:///d:/Ze-Party/backend/src/socket/room.socket.js), [room.service.js](file:///d:/Ze-Party/backend/src/services/room.service.js), [room.routes.js](file:///d:/Ze-Party/backend/src/routes/room.routes.js)):**
   - Updated `onSendRoomChat` and `onSendRoomEmoji` to always fetch authoritative DB sender identity, auto-subscribe sender & host sockets to `room:<canonicalRoomId>`, and broadcast to the active session (and paired PK room when applicable).
   - Updated `POST /v1/rooms/:id/mic-reaction` (`sendMicReaction`) to broadcast authoritative sender identity on both `room:emoji_received` and `room:emoji`.
   - Added Socket `room:resolve_identity` (`agora:resolve_uid`) and REST `GET /v1/rooms/:id/identities` (`GET /v1/rooms/:id/agora-map`).

---

## 5. Socket Contracts & User Identity Mapping

See [docs/FLUTTER_REALTIME_INTEGRATION_CONTRACT.md](file:///d:/Ze-Party/docs/FLUTTER_REALTIME_INTEGRATION_CONTRACT.md) for the complete event table, payload schemas, and `agoraUidMap` lookup contract.

---

## 6. Admin Panel Changes

1. **[liveRooms.service.js](file:///d:/Ze-Party/Admin%20Frontend/src/services/modules/liveRooms.service.js):** Preserved `agoraChannelName`, `agoraHostUid`, `agoraUidMap`, and `participants` in `getLiveRooms` and `getLiveRoomById`.
2. **[LiveRoomsPage.jsx](file:///d:/Ze-Party/Admin%20Frontend/src/pages/admin/LiveRoomsPage.jsx):** Updated the Host column to display the host's profile picture (`hostAvatar`), display name, `@username`, ZeParty User ID, and `agoraHostUid`.
3. **[LiveRoomDetailPage.jsx](file:///d:/Ze-Party/Admin%20Frontend/src/pages/admin/LiveRoomDetailPage.jsx):** Enriched the participants list with `username`, `avatarUrl`, and `agoraUid` across host, seated speakers, members, and active presence participants, and updated the `User Identity` column to display avatar, display name, `@username`, ZeParty User ID (`ID`), and Agora UID (`Agora`).
4. **[PKEventsPage.jsx](file:///d:/Ze-Party/Admin%20Frontend/src/pages/admin/PKEventsPage.jsx):** Replaced broken `via.placeholder.com` URLs with real `avatarUrl`s and clean initial-badge fallbacks, and displayed `@username`, Host ID, and `agoraUid` for Side A, Side B, and Top Supporters.
5. **Build Verification:** Executed `npm run build` in `Admin Frontend` — compiled cleanly with `0` errors.

---

## 7. Database Changes

- **None required.** All fixes were implemented using the existing Prisma schema (`User`, `UserProfile`, `Room`, `RoomSeat`, `RoomMember`, `Gift`, `GiftTransaction`, `PKMatch`) without any destructive migrations or schema alterations.

---

## 8. Tests Executed & Results

Executed automated integration tests in [backend/tests/critical_realtime_and_identity.test.js](file:///d:/Ze-Party/backend/tests/critical_realtime_and_identity.test.js) covering:
1. **Identity Mapping:** Deterministic `userId` <-> `agoraUid` mapping, `agoraUidMap` generation, and full `creator` / `participants` profile fields (`id`, `username`, `displayName`, `avatarUrl`, `agoraUid`) on room creation.
2. **REST Join + Agora Token + Identity Lookup APIs:** Verifies that joining via REST `POST /v1/rooms/:id/join` and requesting `POST /v1/rooms/:id/agora-token` automatically subscribes the user's Socket.IO client to `room:<roomId>`, and verifies `GET /v1/rooms/:id/identities?agoraUid=...` and Socket `room:resolve_identity`.
3. **Comment Broadcasting & Session Isolation:** Verifies that `room:chat` (even when referencing `partyRoomId` and containing spoofed client `username`/`avatarUrl`) broadcasts `room:chat_message` with authoritative DB identity to Host, Viewer A, and Viewer B, and never leaks to unrelated Live rooms.
4. **Emoji & Reaction Broadcasting:** Verifies that both Socket `room:emoji` and REST `POST /v1/rooms/:id/mic-reaction` reach all authorized participants in the room with accurate sender identity and seat index, and never leak across rooms.
5. **Gift Broadcasting, Failure Isolation & Idempotency:** Verifies that confirmed gifts reach Host, Viewer A, and Viewer B with full sender/recipient identities and animation URLs; failed gifts (insufficient balance) are rejected with `400` and never broadcast; duplicate requests (`idempotencyKey` and Socket `gift:send` with committed `transactionId`) are deduplicated with zero double-charging.
6. **PK Session Cross-Room Broadcasting & Isolation:** Verifies that gifts sent during an `ACTIVE` `PKMatch` (even referencing only `pkId`) broadcast `room:gift_sent` and `pk:score_update` to both `roomA` and `roomB` while remaining isolated from unrelated Party rooms.
7. **Stale Membership Cleanup:** Verifies that leaving a room (`POST /v1/rooms/:id/leave`) evicts the user's sockets from `room:<roomId>` so they do not receive subsequent events.

---

## 9. Remaining Mobile Integration Dependencies

Because Flutter mobile source files (`mobile app/`) are strictly outside the scope of this task, the Flutter developer should follow [docs/FLUTTER_REALTIME_INTEGRATION_CONTRACT.md](file:///d:/Ze-Party/docs/FLUTTER_REALTIME_INTEGRATION_CONTRACT.md) to:
1. Pass `data.agoraUid` (returned by `POST /v1/rooms/:id/agora-token`) when calling `rtcEngine.joinChannel(...)`.
2. Resolve remote Agora UIDs via `agoraUidMap[remoteUid.toString()]` or `socket.emit('room:resolve_identity', { roomId, agoraUid })` / `GET /v1/rooms/:id/identities?agoraUid=...` instead of displaying `"Agora User <uid>"`.
3. Render gift animations, comments, and emojis from the server-confirmed broadcast payloads (`room:gift_sent`, `room:chat_message`, `room:emoji` / `room:emoji_received`).

