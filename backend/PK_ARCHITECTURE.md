# ZE PARTY — PK BATTLE ARCHITECTURE & FLOW SPECIFICATION

## 1. Core Business Rules
- **Live Host Exclusivity**: PK Battle is **NOT** a public activity. Only active live hosts can initiate and start a PK Battle. Random viewers cannot create, start, or join an arbitrary PK battle as a participant.
- **Participant Limits**: Minimum **2** participants, Maximum **4** participants.
- **Path A (Host vs Host)**: An active live host invites another active live host directly from the live streams list.
- **Path B (Host Invites User)**: An active live host generates a shareable invite code/link (`zeparty://pk/invite/<code>`). Any user who accepts enters the PK as an authorized participant (does not gain host status).
- **Party Room / Live Stream Transition**: Initiating a PK transitions the active room/session into a PK Battle without creating duplicate sessions.
- **Authoritative Timer Rule**: The battle timer **MUST NOT** start at PK creation, when invitation is sent, or when waiting for participants. The timer starts **ONLY** when the host explicitly starts the battle and status transitions to `STARTED` with an authoritative `startedAt` server timestamp. Reconnection recalculates remaining time from `startedAt`.
- **Spectator Discovery**: Spectators can discover and watch live PK battles on discovery feeds, but opening a PK does **NOT** grant participant RTC/seat permissions.

---

## 2. PK Participant State Machine
```
[CREATED] (1 Participant: Host)
   ↓ (Host sends invites / shares code)
[INVITING]
   ↓ (1 or more participants accept; total participants >= 2)
[READY] (Timer remains stopped)
   ↓ (Host explicitly triggers Start)
[STARTED] (authoritative startedAt set, countdown begins)
   ↓ (Duration expires or Host ends)
[ENDED] (Authoritative scores calculated, winner announced)
```

---

## 3. Backend Endpoints (REST API)

| Method | Endpoint | Authorization | Description |
|---|---|---|---|
| `POST` | `/v1/pk/create` | Host Only | Creates a new host PK session (`CREATED` state). |
| `POST` | `/v1/pk/invite` | Host Only | Invites an active live host or user (max 4 enforced). |
| `GET` | `/v1/pk/invite/:id` | Authenticated | Fetches invitation details. |
| `POST` | `/v1/pk/invite/:id/respond` | Target User | Accepts or declines a PK invitation. |
| `POST` | `/v1/pk/join-by-code` | Authenticated | Joins an active PK session via invite code. |
| `POST` | `/v1/pk/:id/start` | Initiator Host | Transitions PK from `READY` to `STARTED` (stamps `startedAt`). |
| `POST` | `/v1/pk/:id/end` | Initiator Host | Ends the PK battle authoritatively. |
| `GET` | `/v1/pk/:id` | Authenticated | Fetches authoritative PK session state and remaining time. |
| `GET` | `/v1/pk/available-hosts` | Authenticated | Lists currently active live hosts for Path A. |

---

## 4. Real-time Events (Socket.IO)

| Event Name | Direction | Payload | Description |
|---|---|---|---|
| `pk:created` | Server → Room | `PKBattleModel` | PK session created by host |
| `pk:invitation_received` | Server → User | `{ inviteId, inviter }` | Push notification / dialog to invited user |
| `pk:participant_joined` | Server → Room | `PKBattleModel` | New participant joined slot |
| `pk:ready` | Server → Room | `PKBattleModel` | PK has >= 2 participants and is ready to start |
| `pk:started` | Server → Room | `PKBattleModel` with `startedAt` | Battle officially started, timer starts |
| `pk:score_updated` | Server → Room | `{ participants, scoreA, scoreB }` | Scores updated in real time from gifts |
| `pk:ended` | Server → Room | `{ pkId, winnerHostUserId, ranking }` | Battle ended, winner declared |

---

## 5. Mobile Dynamic UI Layout
- **2 Participants**: 2-way horizontal split (Left vs Right).
- **3 Participants**: 3-way layout (Top 1 host, Bottom 2 opponents side-by-side).
- **4 Participants**: 4-way 2x2 grid layout.
- Each participant card displays avatar/video, host badge, following button, score indicator, and dedicated support gift button.
