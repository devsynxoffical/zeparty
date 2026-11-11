# ZeParty Real-Time Room Events & User Identity — Flutter Integration Contract

**Document Version:** 1.0 (P0 Critical Fix Alignment)  
**Scope:** Party Rooms (`AUDIO_PARTY`), Camera Live (`LIVE_VIDEO`), and PK Sessions (`PKMatch`)  
**Target Audience:** ZeParty Flutter Mobile Engineering Team

---

## 1. Socket Event Names Summary (Existing & Corrected)

The backend now normalizes and supports both canonical and mobile-compatible event aliases across Party Rooms, Camera Live, and PK sessions.

| Feature | Client-to-Server Emit Event(s) | Server-to-Client Broadcast Event(s) | Target Room / Scope |
| :--- | :--- | :--- | :--- |
| **Join Room** | `room:join` *(also auto-joined on REST join/create/token)* | `room:snapshot` *(to joining socket)*<br>`room:user_joined`, `room:presence_sync`, `room:stage_sync` *(to room)* | `room:<roomId>` |
| **Leave Room** | `room:leave` *(also auto-evicted on REST leave/kick/close)* | `room:user_left`, `room:presence_sync`, `room:stage_sync` | `room:<roomId>` |
| **Comments / Chat** | `room:chat` *(aliases: `room:comment`, `room:comment_send`, `chat:send`)* | `room:chat_message` *(aliases also emitted: `room:comment`, `room:comment_received`, `chat:new`)* | `room:<roomId>` *(+ paired PK room if in active PK)* |
| **Emoji / Reaction** | `room:emoji` *(aliases: `send_room_emoji`, `room:reaction`, `room:reaction_send`)*<br>OR REST `POST /v1/rooms/:id/mic-reaction` | `room:emoji` AND `room:emoji_received` *(aliases also emitted: `room:reaction`, `room:reaction_received`)* | `room:<roomId>` *(+ paired PK room if in active PK)* |
| **Gift Sending** | REST `POST /v1/gifts/send` *(preferred)*<br>OR Socket `gift:send` | `room:gift_sent` *(aliases also emitted: `gift:received`, `room:gift_received`, `gift:new`)*<br>`room:sending_updated` | `room:<roomId>` *(+ paired PK room `roomAId` & `roomBId` if in active PK)* |
| **PK Gift Score** | Triggered automatically by Gift Sending during `ACTIVE` PK | `pk:score_update` | `room:<roomAId>` and `room:<roomBId>` |
| **Resolve Identity** | `room:resolve_identity` *(alias: `agora:resolve_uid`)*<br>OR REST `GET /v1/rooms/:id/identities` | ACK callback with `{ ok: true, data: { agoraUidMap, resolvedIdentity, participants } }` | Requesting client |
| **Stage / Seats Sync** | `seat:occupy`, `seat:leave`, `seat:mute_toggle` | `room:stage_sync`, `seat:updated` | `room:<roomId>` |

---

## 2. Event Direction Reference

### Client-to-Server (`socket.emit`)
- `room:join` — Subscribe socket to a Party or Live room and receive an authoritative `room:snapshot`.
- `room:leave` — Unsubscribe socket from a room.
- `room:chat` / `room:comment` / `room:comment_send` / `chat:send` — Submit a room comment/chat message.
- `room:emoji` / `send_room_emoji` / `room:reaction` / `room:reaction_send` — Trigger an emoji or seat/stage reaction.
- `gift:send` — Either process a gift directly via socket OR notify/verify an already-committed REST gift transaction (`transactionId`).
- `room:resolve_identity` / `agora:resolve_uid` — Resolve an Agora RTC UID (`agoraUid`) or `userId` to the authoritative ZeParty user profile.
- `pk:sync` — Fetch the authoritative `PKMatch` snapshot and `agoraUidMap` for a room.

### Server-to-Client (`socket.on`)
- `room:snapshot` — Full authoritative room state, host identity, seats, members, stage, and `agoraUidMap`.
- `room:presence_sync` — Updated viewer count and active participant identity list (`users`).
- `room:stage_sync` — Authoritative 10-seat stage layout, host identity, `agoraHostUid`, and `agoraUidMap`.
- `room:user_joined` / `room:user_left` — Real-time participant join/leave notifications with full ZeParty identity.
- `room:chat_message` (and `room:comment`, `room:comment_received`, `chat:new`) — Confirmed room comment with authoritative sender profile.
- `room:emoji` / `room:emoji_received` (and `room:reaction`, `room:reaction_received`) — Confirmed emoji/reaction with authoritative sender profile and seat index.
- `room:gift_sent` (and `gift:received`, `room:gift_received`, `gift:new`) — Server-confirmed gift broadcast with full sender, recipient, and gift animation metadata.
- `pk:score_update` / `pk:started` / `pk:ended` / `pk:snapshot` — Authoritative PK match state and score updates.

---

## 3. Exact Payload Structures

### 3.1 Authoritative User Identity Object (`UserIdentity`)
Every participant, host, sender, and recipient across REST and Socket payloads now conforms to this structure:

```json
{
  "id": "a9d60092-b890-418c-b761-29995059334d",
  "userId": "a9d60092-b890-418c-b761-29995059334d",
  "publicId": "A9D60092",
  "numericUserId": 148291034,
  "agoraUid": 148291034,
  "uid": 148291034,
  "username": "zara_party",
  "displayName": "Zara Party Host",
  "name": "Zara Party Host",
  "avatarUrl": "https://cdn.zeparty.com/avatars/zara.png",
  "avatar": "https://cdn.zeparty.com/avatars/zara.png",
  "countryCode": "PK",
  "level": 12,
  "wealthLevel": 12,
  "vipLevel": 5,
  "svipLevel": 1,
  "isVip": true,
  "nobleRank": "VISCOUNT",
  "nobleTitle": "VISCOUNT",
  "avatarFrame": "https://cdn.zeparty.com/frames/gold.svga",
  "chatBubble": null,
  "entryEffect": null,
  "role": "HOST",
  "isHost": true,
  "seatIndex": 0
}
```

### 3.2 Gift Event (`room:gift_sent`)
- **Client-to-Server (`POST /v1/gifts/send` or `socket.emit('gift:send', payload, ack)`):**
```json
{
  "giftId": "d2f18a10-41f0-4a8e-9b1a-001122334455",
  "recipientUserId": "a9d60092-b890-418c-b761-29995059334d",
  "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "quantity": 1,
  "idempotencyKey": "optional-client-uuid-to-prevent-duplicates"
}
```
*(Note: The backend also accepts `receiverUserId` or `recipientId` for recipient, and `partyRoomId`, `liveSessionId`, `sessionId`, `channelName`, `pkId`, or `matchId` for room resolution).*

- **Server-to-Client Broadcast (`room:gift_sent`, `gift:received`, `room:gift_received`, `gift:new`):**
```json
{
  "transactionId": "9c8b7a65-4321-4abc-9def-1234567890ab",
  "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "sessionId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "giftId": "d2f18a10-41f0-4a8e-9b1a-001122334455",
  "giftName": "Golden Crown",
  "giftCategory": "POPULAR",
  "iconUrl": "https://cdn.zeparty.com/gifts/crown.png",
  "svgaAssetUrl": "https://cdn.zeparty.com/gifts/crown.svga",
  "animationUrl": "https://cdn.zeparty.com/gifts/crown.svga",
  "soundUrl": null,
  "isAnimated": true,
  "isFullScreen": true,
  "quantity": 1,
  "giftCount": 1,
  "coinValue": 100,
  "totalCoins": 100,
  "hostDiamonds": 35,
  "senderUserId": "11223344-5566-7788-99aa-bbccddeeff00",
  "senderAgoraUid": 891023412,
  "recipientUserId": "a9d60092-b890-418c-b761-29995059334d",
  "recipientAgoraUid": 148291034,
  "sender": {
    "id": "11223344-5566-7788-99aa-bbccddeeff00",
    "userId": "11223344-5566-7788-99aa-bbccddeeff00",
    "agoraUid": 891023412,
    "uid": 891023412,
    "username": "hamza_viewer",
    "displayName": "Hamza",
    "name": "Hamza",
    "avatarUrl": "https://cdn.zeparty.com/avatars/hamza.png",
    "avatarFrame": null,
    "level": 12,
    "vipLevel": 2,
    "svipLevel": 1,
    "nobleRank": "VISCOUNT"
  },
  "recipient": {
    "id": "a9d60092-b890-418c-b761-29995059334d",
    "userId": "a9d60092-b890-418c-b761-29995059334d",
    "agoraUid": 148291034,
    "uid": 148291034,
    "username": "zara_party",
    "displayName": "Zara Party Host",
    "name": "Zara Party Host",
    "avatarUrl": "https://cdn.zeparty.com/avatars/zara.png",
    "avatarFrame": null,
    "level": 12,
    "vipLevel": 5,
    "svipLevel": 1,
    "nobleRank": "VISCOUNT"
  },
  "gift": {
    "id": "d2f18a10-41f0-4a8e-9b1a-001122334455",
    "name": "Golden Crown",
    "category": "POPULAR",
    "coinValue": 100,
    "iconUrl": "https://cdn.zeparty.com/gifts/crown.png",
    "svgaAssetUrl": "https://cdn.zeparty.com/gifts/crown.svga",
    "animationUrl": "https://cdn.zeparty.com/gifts/crown.svga",
    "soundUrl": null,
    "isAnimated": true,
    "isFullScreen": true
  },
  "timestamp": "2026-11-11T03:00:00.000Z"
}
```

### 3.3 Comment / Chat Event (`room:chat` -> `room:chat_message`)
- **Client-to-Server (`room:chat`):**
```json
{
  "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "message": "Hello everyone!"
}
```
*(Accepts `message`, `text`, `comment`, or `content`, and `roomId`, `sessionId`, `liveSessionId`, `partyRoomId`, `channelName`, or `pkId`).*

- **Server-to-Client Broadcast (`room:chat_message`, `room:comment`, `room:comment_received`, `chat:new`):**
```json
{
  "id": "msg_1762812000000_ab12cd",
  "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "sessionId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "userId": "11223344-5566-7788-99aa-bbccddeeff00",
  "agoraUid": 891023412,
  "uid": 891023412,
  "username": "hamza_viewer",
  "displayName": "Hamza",
  "name": "Hamza",
  "avatarUrl": "https://cdn.zeparty.com/avatars/hamza.png",
  "avatar": "https://cdn.zeparty.com/avatars/hamza.png",
  "level": 12,
  "wealthLevel": 12,
  "vipLevel": 2,
  "svipLevel": 1,
  "isVip": true,
  "nobleRank": "VISCOUNT",
  "nobleTitle": "VISCOUNT",
  "avatarFrame": null,
  "chatBubble": null,
  "entryEffect": null,
  "sender": { "...Full UserIdentity Object..." },
  "user": { "...Full UserIdentity Object..." },
  "message": "Hello everyone!",
  "text": "Hello everyone!",
  "comment": "Hello everyone!",
  "content": "Hello everyone!",
  "timestamp": "2026-11-11T03:00:00.000Z"
}
```

### 3.4 Emoji / Reaction Event (`room:emoji` -> `room:emoji` & `room:emoji_received`)
- **Client-to-Server (`room:emoji` or `POST /v1/rooms/:id/mic-reaction`):**
```json
{
  "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "emojiId": "fire_heart",
  "emoji": "❤️‍🔥",
  "seatId": 2
}
```
- **Server-to-Client Broadcast (`room:emoji`, `room:emoji_received`, `room:reaction`, `room:reaction_received`):**
```json
{
  "id": "emoji_1762812000000_ef34gh",
  "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "sessionId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "userId": "11223344-5566-7788-99aa-bbccddeeff00",
  "agoraUid": 891023412,
  "uid": 891023412,
  "username": "hamza_viewer",
  "displayName": "Hamza",
  "name": "Hamza",
  "avatarUrl": "https://cdn.zeparty.com/avatars/hamza.png",
  "avatar": "https://cdn.zeparty.com/avatars/hamza.png",
  "avatarFrame": null,
  "level": 12,
  "vipLevel": 2,
  "svipLevel": 1,
  "nobleRank": "VISCOUNT",
  "sender": { "...Full UserIdentity Object..." },
  "user": { "...Full UserIdentity Object..." },
  "seatId": 2,
  "seatIndex": 2,
  "emojiId": "fire_heart",
  "emoji": "❤️‍🔥",
  "reaction": "❤️‍🔥",
  "timestamp": "2026-11-11T03:00:00.000Z"
}
```

---

## 4. Required Authentication

1. **Socket.IO Handshake Authentication:**
   - Pass the user's JWT access token in `auth: { token: "<jwt>" }` when initializing the Socket.IO client.
   - The backend now also accepts `auth.accessToken`, `auth.jwt`, `extraHeaders.authorization: "Bearer <jwt>"`, or `query.token`, and automatically strips any `"Bearer "` prefix.
   - Do **not** pass `"guest_anonymous"` if the user is logged into a ZeParty account.
2. **REST API Authentication:**
   - Include `Authorization: Bearer <jwt>` on all `/v1/rooms/*`, `/v1/gifts/*`, and `/v1/pk/*` requests.

---

## 5. Room & Session Joining Requirements

1. **Dual-Path Subscription Safety (Implemented on Backend):**
   - Whenever a user calls REST `POST /v1/rooms` (create), `GET /v1/rooms/my-party`, `POST /v1/rooms/:id/join`, `POST /v1/rooms/:id/visit`, `POST /v1/rooms/:id/seats/:seatIndex/occupy`, or `POST /v1/rooms/:id/agora-token`, the backend now **automatically joins all active Socket.IO connections of that user** to `room:<roomId>`.
   - Nevertheless, the Flutter client **should still emit `socket.emit('room:join', { roomId })`** upon entering a Party Room or Live stream screen so that it immediately receives `room:snapshot` and `room:presence_sync`.
2. **Identifier Flexibility:**
   - Always prefer passing the canonical `room.id` UUID as `roomId`.
   - If the mobile client passes `partyRoomId`, `liveSessionId`, `sessionId`, `channelName` (`agoraChannelName`), or `pkId` (`matchId`), the backend resolves the canonical `room.id` automatically.

---

## 6. Participant Identity & Agora UID Mapping

- **Never display Agora's numeric `remoteUid` as a username or user ID.**
- Agora RTC uses a 32-bit unsigned integer (`agoraUid`) derived deterministically on the backend from the user's ZeParty UUID (`deriveAgoraUid(userId)`).
- Every room response (`GET /v1/rooms/:id`, `POST /v1/rooms/:id/join`, `room:snapshot`, `room:stage_sync`, `pk:snapshot`) now includes:
  - `agoraHostUid`: The 32-bit integer Agora UID of the room host.
  - `agoraUidMap`: A dictionary keyed by `String(agoraUid)` mapping directly to the user's `UserIdentity` object (`id`, `userId`, `username`, `displayName`, `avatarUrl`, `role`, `seatIndex`, `vipLevel`, `nobleRank`, `avatarFrame`).
- When Agora fires `onUserJoined(RtcConnection connection, int remoteUid, int elapsed)`:
  1. Look up `agoraUidMap[remoteUid.toString()]` from the latest `room:snapshot` / `room:stage_sync`.
  2. If `remoteUid` is not yet in the local map, call either:
     - **Socket:** `socket.emit('room:resolve_identity', { roomId, agoraUid: remoteUid }, (ack) => { ... })`
     - **REST:** `GET /v1/rooms/:roomId/identities?agoraUid=<remoteUid>`
     to retrieve `resolvedIdentity` and the refreshed `agoraUidMap`.

---

## 7. Gift Confirmation & Failure Behavior

1. **Server-Authoritative Confirmation Only:**
   - Do **not** play the full-screen gift animation for the room based solely on a local button tap before the backend confirms the transaction.
   - Send `POST /v1/gifts/send` (with an `idempotencyKey` UUID) OR `socket.emit('gift:send', payload, ack)`.
   - Upon transaction commit, the backend immediately broadcasts `room:gift_sent` to **all participants in the room** (including the sender and host, plus both rooms in an active PK match).
   - If the Flutter app calls `POST /v1/gifts/send` AND then emits `socket.emit('gift:send', { ..., transactionId })`, the backend detects the already-committed `transactionId` and deduplicates it so the user is **never double-charged** and the gift is **never double-broadcast**.
2. **Failed Gifts:**
   - If the user has insufficient coins or the room has ended (`ROOM_NOT_LIVE`), the backend returns an error (`400 Bad Request` / `{ ok: false, error: { code, message } }`) and **never broadcasts `room:gift_sent`**.

---

## 8. Comment & Reaction Behavior

1. **Comments (`room:chat` -> `room:chat_message`):**
   - The backend ignores any client-spoofed `username` or `avatarUrl` and attaches the authenticated user's authoritative database profile (`id`, `username`, `displayName`, `avatarUrl`, `agoraUid`, `vipLevel`, `nobleRank`, `avatarFrame`, `chatBubble`).
   - All participants in `room:<roomId>` receive `room:chat_message` (including the sender). If the client renders an optimistic local comment, deduplicate it when `room:chat_message` arrives.
2. **Emojis & Mic Reactions (`room:emoji` / `POST /v1/rooms/:id/mic-reaction`):**
   - Whether triggered via Socket (`room:emoji` / `send_room_emoji`) or REST (`POST /v1/rooms/:id/mic-reaction`), the backend resolves the sender's seat (`seatId` / `seatIndex`) and authoritative identity, and broadcasts both `room:emoji` and `room:emoji_received` to `room:<roomId>`.

---

## 9. Reconnection & Session Recovery Expectations

1. **Automatic Socket Re-Subscription on Reconnect:**
   - When a user's Socket.IO connection drops and reconnects while they are in an active `LIVE` room, the backend's connection handler (`src/socket/index.js`) checks `presenceService.getUserActiveSession(userId)` and automatically re-subscribes the new socket to `room:<roomId>`.
2. **Recommended Client Reconnect Handler:**
   - On `socket.on('reconnect', ...)` (or `connect` while inside a room screen), re-emit `socket.emit('room:join', { roomId })` (and `socket.emit('pk:sync', { roomId })` if in PK) to refresh the local `room:snapshot`, `stage`, and `agoraUidMap`.

---

## 10. REST API Response Structures

### `POST /v1/rooms/:id/agora-token`
```json
{
  "success": true,
  "message": "Agora RTC token generated successfully",
  "data": {
    "token": "007eJxTY...",
    "channelName": "zp_live_a9d60092_1762812000",
    "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "agoraUid": 891023412,
    "uid": 891023412,
    "userId": "11223344-5566-7788-99aa-bbccddeeff00",
    "hostUserId": "a9d60092-b890-418c-b761-29995059334d",
    "hostAgoraUid": 148291034,
    "userIdentity": { "...Full UserIdentity Object..." },
    "role": "SUBSCRIBER",
    "expireAt": 1762815600
  }
}
```

### `GET /v1/rooms/:id/identities?agoraUid=<uid>&userId=<uuid>`
*(Alias: `GET /v1/rooms/:id/agora-map`)*
```json
{
  "success": true,
  "message": "Room participant identities retrieved successfully",
  "data": {
    "roomId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "agoraChannelName": "zp_live_a9d60092_1762812000",
    "hostUserId": "a9d60092-b890-418c-b761-29995059334d",
    "agoraHostUid": 148291034,
    "host": { "...Full UserIdentity Object..." },
    "participants": [ { "...Full UserIdentity Object..." } ],
    "agoraUidMap": {
      "148291034": { "...Host UserIdentity Object..." },
      "891023412": { "...Viewer UserIdentity Object..." }
    },
    "resolvedIdentity": { "...Matched UserIdentity Object or null..." }
  }
}
```

---

## 11. Required Changes Checklist for the Flutter Developer

1. **Use `agoraUidMap` / `room:resolve_identity` for Agora Video & Audio Tiles:**
   - Replace any fallback text like `"Agora User $remoteUid"` or static placeholder avatars with `agoraUidMap[remoteUid.toString()]?.displayName` and `agoraUidMap[remoteUid.toString()]?.avatarUrl`.
   - If a `remoteUid` joins the Agora channel before `room:presence_sync` arrives, emit `room:resolve_identity` with `{ roomId, agoraUid: remoteUid }` or call `GET /v1/rooms/$roomId/identities?agoraUid=$remoteUid`.
2. **Join Agora Engine Using Backend `agoraUid`:**
   - When calling `rtcEngine.joinChannel(token: data.token, channelId: data.channelName, uid: data.agoraUid, options: ...)`, always pass the exact integer `data.agoraUid` returned by `POST /v1/rooms/:id/agora-token` (never `0`), so the user's Agora stream UID matches `agoraUidMap` on all other participants' screens.
3. **Listen to Canonical Real-Time Broadcast Events:**
   - Gifts: Listen to `room:gift_sent` (or `gift:received`) and render `payload.sender.displayName`, `payload.sender.avatarUrl`, `payload.recipient.displayName`, and `payload.svgaAssetUrl` / `payload.iconUrl`.
   - Comments: Listen to `room:chat_message` (or `room:comment`) and render `payload.displayName` (`payload.sender.displayName`) and `payload.avatarUrl` (`payload.sender.avatarUrl`). Avoid duplicating the sender's own comment if optimistic UI is used (match by `message` + `userId` or render directly from `room:chat_message`).
   - Emojis/Reactions: Listen to `room:emoji` / `room:emoji_received` and render on `payload.seatIndex` / `payload.userId`.
4. **Ensure JWT Token is Passed on Socket Connect:**
   - Verify that `IO.io(url, IO.OptionBuilder().setAuth({'token': accessToken}).build())` passes the real logged-in JWT token and reconnects when the user logs in.

