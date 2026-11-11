import test, { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import crypto from 'node:crypto';
import WebSocket from 'ws';
import jwt from 'jsonwebtoken';

import app from '../src/app.js';
import env from '../src/config/env.js';
import prisma from '../src/config/database.js';
import { initSocketServer } from '../src/socket/index.js';
import {
  deriveAgoraUid,
  formatAuthoritativeUserIdentity,
  buildAgoraUidIdentityMap,
} from '../src/utils/agoraToken.util.js';

// Ensure BigInt values serialize cleanly to JSON
if (!BigInt.prototype.toJSON) {
  BigInt.prototype.toJSON = function () {
    return Number(this);
  };
}

/**
 * Lightweight Engine.IO v4 + Socket.IO v4 WebSocket Test Client
 * Connects to the real Socket.IO server over WebSocket and parses/emits Socket.IO packets.
 */
class SocketIOTestClient {
  constructor(port, authPayload = {}) {
    this.port = port;
    this.authPayload = authPayload;
    this.ws = null;
    this.sid = null;
    this.events = [];
    this.waiters = [];
    this.ackCounter = 1;
    this.pendingAcks = new Map();
  }

  connect() {
    return new Promise((resolve, reject) => {
      const wsUrl = `ws://127.0.0.1:${this.port}/socket.io/?EIO=4&transport=websocket`;
      this.ws = new WebSocket(wsUrl);
      let connected = false;

      const timeout = setTimeout(() => {
        if (!connected) {
          reject(new Error('Socket.IO test client connection timed out'));
        }
      }, 90000);

      this.ws.on('error', (err) => {
        clearTimeout(timeout);
        if (!connected) reject(err);
      });

      this.ws.on('message', (raw) => {
        const str = raw.toString();
        if (!str) return;

        // Engine.IO OPEN packet ('0{...}')
        if (str.startsWith('0')) {
          // Send Socket.IO CONNECT ('40' + auth JSON)
          this.ws.send(`40${JSON.stringify(this.authPayload)}`);
          return;
        }

        // Engine.IO PING ('2') -> reply PONG ('3')
        if (str === '2') {
          this.ws.send('3');
          return;
        }

        // Socket.IO CONNECT ACK ('40{"sid":"..."}')
        if (str.startsWith('40')) {
          const jsonPart = str.slice(2);
          try {
            const parsed = jsonPart ? JSON.parse(jsonPart) : {};
            this.sid = parsed.sid || 'connected';
          } catch (_) {
            this.sid = 'connected';
          }
          connected = true;
          clearTimeout(timeout);
          resolve(this);
          return;
        }

        // Socket.IO CONNECT ERROR ('44{...}')
        if (str.startsWith('44')) {
          clearTimeout(timeout);
          reject(new Error(`Socket.IO connect_error: ${str.slice(2)}`));
          return;
        }

        // Socket.IO EVENT ('42...' or '42<ackId>[...]')
        if (str.startsWith('42')) {
          const rest = str.slice(2);
          const bracketIdx = rest.indexOf('[');
          if (bracketIdx === -1) return;
          const jsonStr = rest.slice(bracketIdx);
          try {
            const [eventName, payload] = JSON.parse(jsonStr);
            const record = { eventName, payload, receivedAt: Date.now() };
            this.events.push(record);
            for (let i = this.waiters.length - 1; i >= 0; i--) {
              const w = this.waiters[i];
              if (w.eventName === eventName && (!w.predicate || w.predicate(payload))) {
                this.waiters.splice(i, 1);
                clearTimeout(w.timer);
                w.resolve(payload);
              }
            }
          } catch (_) {}
          return;
        }

        // Socket.IO ACK ('43<ackId>[...]')
        if (str.startsWith('43')) {
          const rest = str.slice(2);
          const bracketIdx = rest.indexOf('[');
          if (bracketIdx === -1) return;
          const ackId = Number(rest.slice(0, bracketIdx));
          const jsonStr = rest.slice(bracketIdx);
          const pending = this.pendingAcks.get(ackId);
          if (pending) {
            this.pendingAcks.delete(ackId);
            clearTimeout(pending.timer);
            try {
              const args = JSON.parse(jsonStr);
              pending.resolve(args[0]);
            } catch (e) {
              pending.reject(e);
            }
          }
        }
      });
    });
  }

  emitWithAck(eventName, payload, timeoutMs = 120000) {
    return new Promise((resolve, reject) => {
      const ackId = this.ackCounter++;
      const timer = setTimeout(() => {
        this.pendingAcks.delete(ackId);
        reject(new Error(`Timeout waiting for ACK on ${eventName}`));
      }, timeoutMs);
      this.pendingAcks.set(ackId, { resolve, reject, timer });
      this.ws.send(`42${ackId}${JSON.stringify([eventName, payload])}`);
    });
  }

  waitForEvent(eventName, predicate = null, timeoutMs = 45000) {
    // Check already-received events first
    const existing = this.events.find(
      (e) => e.eventName === eventName && (!predicate || predicate(e.payload))
    );
    if (existing) {
      return Promise.resolve(existing.payload);
    }
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const idx = this.waiters.findIndex((w) => w.timer === timer);
        if (idx !== -1) this.waiters.splice(idx, 1);
        reject(new Error(`Timeout waiting for event "${eventName}"`));
      }, timeoutMs);
      this.waiters.push({ eventName, predicate, resolve, reject, timer });
    });
  }

  clearEvents() {
    this.events = [];
  }

  hasReceivedEvent(eventName, predicate = null) {
    return this.events.some(
      (e) => e.eventName === eventName && (!predicate || predicate(e.payload))
    );
  }

  close() {
    if (this.ws) {
      try {
        this.ws.close();
      } catch (_) {}
    }
  }
}

describe('P0 Critical Fix: Real-Time Room Events & Authoritative User Identity', () => {
  let server;
  let io;
  let port;
  const createdUserIds = [];
  const createdRoomIds = [];
  const createdGiftIds = [];
  const createdMatchIds = [];
  const clients = [];

  let hostParty;
  let hostLiveA;
  let hostLiveB;
  let viewerA;
  let viewerB;
  let poorViewer;
  let testGift;

  let partyRoom;
  let liveRoomA;
  let liveRoomB;
  let pkMatch;

  async function createTestUser({ usernamePrefix, displayName, avatarUrl, coins = 5000n, vipLevel = 2 }) {
    const suffix = crypto.randomUUID().slice(0, 8);
    const userId = crypto.randomUUID();
    const sessionId = crypto.randomUUID();
    const username = `${usernamePrefix}_${suffix}`;

    const user = await prisma.user.create({
      data: {
        id: userId,
        username,
        email: `${username}@test.zeparty.local`,
        status: 'ACTIVE',
        userType: 'HOST',
        countryCode: 'PK',
        avatarUrl,
        profile: {
          create: {
            displayName,
            level: 12,
            vipLevel,
            svipLevel: 1,
            nobleRank: 'VISCOUNT',
          },
        },
        wallet: {
          create: {
            coinBalance: coins,
            diamondBalance: 0n,
          },
        },
        sessions: {
          create: {
            id: sessionId,
            refreshToken: `refresh_${sessionId}`,
            expiresAt: new Date(Date.now() + 3600 * 1000),
          },
        },
      },
      include: {
        profile: true,
        wallet: true,
      },
    });

    createdUserIds.push(user.id);

    const token = jwt.sign(
      {
        sub: user.id,
        sessionId,
        type: 'USER',
        role: 'HOST',
      },
      env.JWT_SECRET,
      { expiresIn: '1h' }
    );

    return { user, sessionId, token, agoraUid: deriveAgoraUid(user.id) };
  }

  async function apiRequest(method, path, token, body = null) {
    const headers = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers.Authorization = `Bearer ${token}`;
    }
    const res = await fetch(`http://127.0.0.1:${port}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    const json = await res.json().catch(() => ({}));
    return { status: res.status, body: json };
  }

  before(async () => {
    await prisma.$connect();

    server = http.createServer(app);
    io = await initSocketServer(server);
    await new Promise((resolve) => {
      server.listen(0, '127.0.0.1', () => {
        port = server.address().port;
        resolve();
      });
    });

    // Create isolated test users and test gift in parallel
    [hostParty, hostLiveA, hostLiveB, viewerA, viewerB, poorViewer, testGift] = await Promise.all([
      createTestUser({
        usernamePrefix: 'party_host',
        displayName: 'Zara Party Host',
        avatarUrl: 'https://cdn.zeparty.test/avatars/zara_host.png',
        coins: 10000n,
        vipLevel: 5,
      }),
      createTestUser({
        usernamePrefix: 'live_host_a',
        displayName: 'Ali Camera Host A',
        avatarUrl: 'https://cdn.zeparty.test/avatars/ali_host_a.png',
        coins: 10000n,
        vipLevel: 4,
      }),
      createTestUser({
        usernamePrefix: 'live_host_b',
        displayName: 'Sara Camera Host B',
        avatarUrl: 'https://cdn.zeparty.test/avatars/sara_host_b.png',
        coins: 10000n,
        vipLevel: 4,
      }),
      createTestUser({
        usernamePrefix: 'viewer_a',
        displayName: 'Hamza Viewer A',
        avatarUrl: 'https://cdn.zeparty.test/avatars/hamza_a.png',
        coins: 5000n,
        vipLevel: 2,
      }),
      createTestUser({
        usernamePrefix: 'viewer_b',
        displayName: 'Ayesha Viewer B',
        avatarUrl: 'https://cdn.zeparty.test/avatars/ayesha_b.png',
        coins: 5000n,
        vipLevel: 3,
      }),
      createTestUser({
        usernamePrefix: 'poor_viewer',
        displayName: 'NoCoins Viewer',
        avatarUrl: 'https://cdn.zeparty.test/avatars/nocoins.png',
        coins: 5n,
        vipLevel: 0,
      }),
      prisma.gift.create({
        data: {
          name: `Test Golden Crown ${crypto.randomUUID().slice(0, 6)}`,
          coinValue: 100n,
          iconUrl: 'https://cdn.zeparty.test/gifts/crown.png',
          svgaAssetUrl: 'https://cdn.zeparty.test/gifts/crown.svga',
          giftCategory: 'POPULAR',
          isAnimated: true,
          isFullScreen: true,
          isActive: true,
        },
      }),
    ]);
    createdGiftIds.push(testGift.id);
  });

  after(async () => {
    for (const c of clients) {
      c.close();
    }
    if (io) {
      await new Promise((resolve) => io.close(() => resolve()));
    }
    if (server && server.listening) {
      await new Promise((resolve) => server.close(() => resolve()));
    }

    // Clean up test records in reverse dependency order
    try {
      if (createdMatchIds.length > 0) {
        await prisma.pKGiftContribution.deleteMany({ where: { matchId: { in: createdMatchIds } } });
        await prisma.pKLifecycleAudit.deleteMany({ where: { matchId: { in: createdMatchIds } } });
        await prisma.pKInvitation.deleteMany({ where: { matchId: { in: createdMatchIds } } });
        await prisma.pKMatch.deleteMany({ where: { id: { in: createdMatchIds } } });
      }
      if (createdUserIds.length > 0) {
        await prisma.giftTransaction.deleteMany({
          where: {
            OR: [
              { senderUserId: { in: createdUserIds } },
              { recipientUserId: { in: createdUserIds } },
            ],
          },
        });
        await prisma.walletLedger.deleteMany({
          where: {
            wallet: { userId: { in: createdUserIds } },
          },
        });
      }
      if (createdRoomIds.length > 0) {
        await prisma.roomSeat.deleteMany({ where: { roomId: { in: createdRoomIds } } });
        await prisma.roomMember.deleteMany({ where: { roomId: { in: createdRoomIds } } });
        await prisma.room.deleteMany({ where: { id: { in: createdRoomIds } } });
      }
      if (createdGiftIds.length > 0) {
        await prisma.gift.deleteMany({ where: { id: { in: createdGiftIds } } });
      }
      if (createdUserIds.length > 0) {
        await prisma.user.deleteMany({ where: { id: { in: createdUserIds } } });
      }
    } catch (cleanupErr) {
      console.warn('Test cleanup warning:', cleanupErr.message);
    }
    await prisma.$disconnect();
  });

  it('1. Identity Mapping: Deterministically maps ZeParty userId <-> Agora UID and returns actual user profiles', async () => {
    const formattedA = formatAuthoritativeUserIdentity(viewerA.user, { role: 'VIEWER' });
    const formattedB = formatAuthoritativeUserIdentity(viewerB.user, { role: 'VIEWER' });

    assert.equal(formattedA.id, viewerA.user.id);
    assert.equal(formattedA.userId, viewerA.user.id);
    assert.equal(formattedA.username, viewerA.user.username);
    assert.equal(formattedA.displayName, 'Hamza Viewer A');
    assert.equal(formattedA.avatarUrl, 'https://cdn.zeparty.test/avatars/hamza_a.png');
    assert.equal(typeof formattedA.agoraUid, 'number');
    assert.ok(formattedA.agoraUid > 0);
    assert.notEqual(formattedA.agoraUid, formattedB.agoraUid);

    const uidMap = buildAgoraUidIdentityMap([formattedA, formattedB]);
    assert.equal(uidMap[String(formattedA.agoraUid)].userId, viewerA.user.id);
    assert.equal(uidMap[String(formattedB.agoraUid)].userId, viewerB.user.id);

    // Create Party Room and two Camera Live rooms via REST API in parallel
    const [createPartyRes, createLiveARes, createLiveBRes] = await Promise.all([
      apiRequest('POST', '/v1/rooms', hostParty.token, {
        title: 'Zara VIP Party Room',
        roomType: 'AUDIO_PARTY',
        category: 'CHAT',
      }),
      apiRequest('POST', '/v1/rooms', hostLiveA.token, {
        title: 'Ali Camera Live Stream',
        roomType: 'LIVE_VIDEO',
        category: 'MUSIC',
      }),
      apiRequest('POST', '/v1/rooms', hostLiveB.token, {
        title: 'Sara Camera Live Stream',
        roomType: 'LIVE_VIDEO',
        category: 'MUSIC',
      }),
    ]);
    assert.equal(createPartyRes.status, 201);
    partyRoom = createPartyRes.body.data;
    createdRoomIds.push(partyRoom.id);

    assert.equal(partyRoom.creatorUserId, hostParty.user.id);
    assert.equal(partyRoom.agoraHostUid, hostParty.agoraUid);
    assert.equal(partyRoom.creator.id, hostParty.user.id);
    assert.equal(partyRoom.creator.username, hostParty.user.username);
    assert.equal(partyRoom.creator.displayName, 'Zara Party Host');
    assert.equal(partyRoom.creator.avatarUrl, 'https://cdn.zeparty.test/avatars/zara_host.png');
    assert.equal(partyRoom.creator.agoraUid, hostParty.agoraUid);
    assert.ok(partyRoom.agoraUidMap[String(hostParty.agoraUid)]);

    assert.equal(createLiveARes.status, 201);
    liveRoomA = createLiveARes.body.data;
    createdRoomIds.push(liveRoomA.id);

    assert.equal(createLiveBRes.status, 201);
    liveRoomB = createLiveBRes.body.data;
    createdRoomIds.push(liveRoomB.id);
  });

  it('2. REST Join + Agora Token + Identity Lookup APIs subscribe sockets and return authoritative identities', async () => {
    // Connect Socket.IO clients for Host Party, Viewer A, Viewer B, and Host Live A/B
    // Test Bearer prefix in auth.token and accessToken fallback
    const [
      hostPartySocket,
      viewerASocket,
      viewerBSocket,
      poorViewerSocket,
    ] = await Promise.all([
      new SocketIOTestClient(port, { token: `Bearer ${hostParty.token}` }).connect(),
      new SocketIOTestClient(port, { accessToken: viewerA.token }).connect(),
      new SocketIOTestClient(port, { token: viewerB.token }).connect(),
      new SocketIOTestClient(port, { token: poorViewer.token }).connect(),
    ]);

    clients.push(hostPartySocket, viewerASocket, viewerBSocket, poorViewerSocket);

    // Host joins their Party room via Socket.IO
    const hostJoinAck = await hostPartySocket.emitWithAck('room:join', {
      roomId: partyRoom.id,
    });
    assert.equal(hostJoinAck.ok, true);
    assert.equal(hostJoinAck.data.host.id, hostParty.user.id);
    assert.equal(hostJoinAck.data.host.displayName, 'Zara Party Host');
    assert.equal(hostJoinAck.data.host.avatarUrl, 'https://cdn.zeparty.test/avatars/zara_host.png');
    assert.equal(hostJoinAck.data.host.agoraUid, hostParty.agoraUid);

    // Viewer A joins Party Room ONLY via REST POST /v1/rooms/:id/join (simulating mobile client that skips socket room:join)
    const restJoinA = await apiRequest('POST', `/v1/rooms/${partyRoom.id}/join`, viewerA.token, {});
    assert.equal(restJoinA.status, 200);

    // Viewer B joins Party Room via REST + requests Agora Token via POST /v1/rooms/:id/agora-token
    const restJoinB = await apiRequest('POST', `/v1/rooms/${partyRoom.id}/join`, viewerB.token, {});
    assert.equal(restJoinB.status, 200);
    const agoraTokenB = await apiRequest('POST', `/v1/rooms/${partyRoom.id}/agora-token`, viewerB.token, {});
    assert.equal(agoraTokenB.status, 200);
    assert.equal(agoraTokenB.body.data.agoraUid, viewerB.agoraUid);
    assert.equal(agoraTokenB.body.data.hostUserId, hostParty.user.id);
    assert.equal(agoraTokenB.body.data.hostAgoraUid, hostParty.agoraUid);
    assert.equal(agoraTokenB.body.data.userIdentity.id, viewerB.user.id);
    assert.equal(agoraTokenB.body.data.userIdentity.avatarUrl, 'https://cdn.zeparty.test/avatars/ayesha_b.png');

    // Poor viewer joins Party Room via Socket.IO
    const poorJoinAck = await poorViewerSocket.emitWithAck('room:join', {
      roomId: partyRoom.id,
    });
    assert.equal(poorJoinAck.ok, true);

    // Verify GET /v1/rooms/:id/identities and socket room:resolve_identity
    const identitiesRes = await apiRequest(
      'GET',
      `/v1/rooms/${partyRoom.id}/identities?agoraUid=${viewerA.agoraUid}`,
      viewerB.token
    );
    assert.equal(identitiesRes.status, 200);
    assert.equal(identitiesRes.body.data.resolvedIdentity.id, viewerA.user.id);
    assert.equal(identitiesRes.body.data.resolvedIdentity.username, viewerA.user.username);
    assert.equal(identitiesRes.body.data.resolvedIdentity.displayName, 'Hamza Viewer A');
    assert.equal(identitiesRes.body.data.resolvedIdentity.avatarUrl, 'https://cdn.zeparty.test/avatars/hamza_a.png');

    const resolveAck = await viewerBSocket.emitWithAck('room:resolve_identity', {
      roomId: partyRoom.id,
      agoraUid: hostParty.agoraUid,
    });
    assert.equal(resolveAck.ok, true);
    assert.equal(resolveAck.data.resolvedIdentity.id, hostParty.user.id);
    assert.equal(resolveAck.data.resolvedIdentity.displayName, 'Zara Party Host');

    // Save references for next tests
    partyRoom.sockets = { hostPartySocket, viewerASocket, viewerBSocket, poorViewerSocket };
  });

  it('3. Comment Broadcasting & Session Isolation: Comments reach Host + Viewers with real identity and never leak to other rooms', async () => {
    const { hostPartySocket, viewerASocket, viewerBSocket } = partyRoom.sockets;

    // Connect Host Live A to Live Room A (unrelated session)
    const hostLiveASocket = await new SocketIOTestClient(port, {
      token: hostLiveA.token,
    }).connect();
    clients.push(hostLiveASocket);
    const liveJoinAck = await hostLiveASocket.emitWithAck('room:join', {
      roomId: liveRoomA.id,
    });
    assert.equal(liveJoinAck.ok, true);
    liveRoomA.hostSocket = hostLiveASocket;

    hostPartySocket.clearEvents();
    viewerASocket.clearEvents();
    viewerBSocket.clearEvents();
    hostLiveASocket.clearEvents();

    // Viewer A sends a comment using partyRoomId alias + tries to spoof username/avatarUrl in client payload
    const commentText = 'Assalam-o-Alaikum everyone in Party Room!';
    const chatAck = await viewerASocket.emitWithAck('room:chat', {
      partyRoomId: partyRoom.id,
      message: commentText,
      username: 'SPOOFED_FAKE_USER',
      avatarUrl: 'https://spoofed.invalid/fake.png',
    });
    assert.equal(chatAck.ok, true);

    // Host, Viewer A, and Viewer B must all receive room:chat_message
    const [hostMsg, viewerAMsg, viewerBMsg] = await Promise.all([
      hostPartySocket.waitForEvent('room:chat_message', (p) => p.message === commentText),
      viewerASocket.waitForEvent('room:chat_message', (p) => p.message === commentText),
      viewerBSocket.waitForEvent('room:chat_message', (p) => p.message === commentText),
    ]);

    for (const msg of [hostMsg, viewerAMsg, viewerBMsg]) {
      assert.equal(msg.roomId, partyRoom.id);
      assert.equal(msg.userId, viewerA.user.id);
      assert.equal(msg.agoraUid, viewerA.agoraUid);
      // Authoritative DB identity MUST override spoofed client fields
      assert.equal(msg.username, viewerA.user.username);
      assert.equal(msg.displayName, 'Hamza Viewer A');
      assert.equal(msg.avatarUrl, 'https://cdn.zeparty.test/avatars/hamza_a.png');
      assert.equal(msg.sender.id, viewerA.user.id);
      assert.equal(msg.sender.agoraUid, viewerA.agoraUid);
    }

    // Unrelated Live Room A must NOT have received the Party Room comment
    assert.equal(
      hostLiveASocket.hasReceivedEvent('room:chat_message', (p) => p.message === commentText),
      false
    );
  });

  it('4. Emoji & Reaction Broadcasting: Socket room:emoji and REST /mic-reaction reach all participants with actual sender identity', async () => {
    const { hostPartySocket, viewerASocket, viewerBSocket } = partyRoom.sockets;
    const hostLiveASocket = liveRoomA.hostSocket;

    hostPartySocket.clearEvents();
    viewerASocket.clearEvents();
    viewerBSocket.clearEvents();
    hostLiveASocket.clearEvents();

    // 4a. Socket room:emoji from Viewer B
    const emojiAck = await viewerBSocket.emitWithAck('room:emoji', {
      roomId: partyRoom.id,
      emojiId: 'fire_heart',
      emoji: '❤️‍🔥',
    });
    assert.equal(emojiAck.ok, true);

    const [hostEmoji, viewerAEmoji, viewerBEmoji] = await Promise.all([
      hostPartySocket.waitForEvent('room:emoji', (p) => p.emojiId === 'fire_heart'),
      viewerASocket.waitForEvent('room:emoji', (p) => p.emojiId === 'fire_heart'),
      viewerBSocket.waitForEvent('room:emoji', (p) => p.emojiId === 'fire_heart'),
    ]);

    for (const ev of [hostEmoji, viewerAEmoji, viewerBEmoji]) {
      assert.equal(ev.roomId, partyRoom.id);
      assert.equal(ev.userId, viewerB.user.id);
      assert.equal(ev.agoraUid, viewerB.agoraUid);
      assert.equal(ev.username, viewerB.user.username);
      assert.equal(ev.displayName, 'Ayesha Viewer B');
      assert.equal(ev.avatarUrl, 'https://cdn.zeparty.test/avatars/ayesha_b.png');
    }

    // 4b. REST POST /v1/rooms/:id/mic-reaction from Host Party
    const micReactionRes = await apiRequest(
      'POST',
      `/v1/rooms/${partyRoom.id}/mic-reaction`,
      hostParty.token,
      { emoji: '🎉', seatIndex: 0 }
    );
    assert.equal(micReactionRes.status, 200);

    const [viewerAReaction, viewerBReaction] = await Promise.all([
      viewerASocket.waitForEvent('room:emoji_received', (p) => p.emoji === '🎉'),
      viewerBSocket.waitForEvent('room:emoji_received', (p) => p.emoji === '🎉'),
    ]);
    assert.equal(viewerAReaction.userId, hostParty.user.id);
    assert.equal(viewerAReaction.displayName, 'Zara Party Host');
    assert.equal(viewerAReaction.avatarUrl, 'https://cdn.zeparty.test/avatars/zara_host.png');
    assert.equal(viewerAReaction.agoraUid, hostParty.agoraUid);
    assert.equal(viewerBReaction.userId, hostParty.user.id);

    // Unrelated Live Room A must NOT have received any Party emojis
    assert.equal(hostLiveASocket.hasReceivedEvent('room:emoji'), false);
    assert.equal(hostLiveASocket.hasReceivedEvent('room:emoji_received'), false);
  });

  it('5. Gift Broadcasting, Failure Isolation & Idempotency: Confirmed gifts reach all participants; failed/duplicate gifts do not double-charge or fake-broadcast', async () => {
    const { hostPartySocket, viewerASocket, viewerBSocket, poorViewerSocket } = partyRoom.sockets;
    const hostLiveASocket = liveRoomA.hostSocket;

    hostPartySocket.clearEvents();
    viewerASocket.clearEvents();
    viewerBSocket.clearEvents();
    hostLiveASocket.clearEvents();

    // 5a. Failed gift (insufficient balance) must be rejected and NEVER broadcast
    const failedGiftRes = await apiRequest('POST', '/v1/gifts/send', poorViewer.token, {
      giftId: testGift.id,
      recipientUserId: hostParty.user.id,
      roomId: partyRoom.id,
      quantity: 1,
    });
    assert.equal(failedGiftRes.status, 400);
    assert.equal(hostPartySocket.hasReceivedEvent('room:gift_sent'), false);
    assert.equal(viewerASocket.hasReceivedEvent('room:gift_sent'), false);

    // 5b. Successful gift via REST + follow-up Socket notification with same transactionId (idempotency test)
    const walletBefore = await prisma.wallet.findUnique({ where: { userId: viewerA.user.id } });
    const idempotencyKey = `idem_${crypto.randomUUID()}`;

    const sendGiftRes = await apiRequest('POST', '/v1/gifts/send', viewerA.token, {
      giftId: testGift.id,
      recipientUserId: hostParty.user.id,
      partyRoomId: partyRoom.id,
      quantity: 2,
      idempotencyKey,
    });
    assert.equal(sendGiftRes.status, 200);
    const txId = sendGiftRes.body.data.transactionId;
    assert.ok(txId);

    // Host, Viewer A, and Viewer B must all receive confirmed room:gift_sent
    const [hostGift, viewerAGift, viewerBGift] = await Promise.all([
      hostPartySocket.waitForEvent('room:gift_sent', (p) => p.transactionId === txId),
      viewerASocket.waitForEvent('room:gift_sent', (p) => p.transactionId === txId),
      viewerBSocket.waitForEvent('room:gift_sent', (p) => p.transactionId === txId),
    ]);

    for (const g of [hostGift, viewerAGift, viewerBGift]) {
      assert.equal(g.roomId, partyRoom.id);
      assert.equal(g.giftId, testGift.id);
      assert.equal(g.quantity, 2);
      assert.equal(Number(g.totalCoins), 200);
      assert.equal(g.svgaAssetUrl, 'https://cdn.zeparty.test/gifts/crown.svga');
      assert.equal(g.sender.id, viewerA.user.id);
      assert.equal(g.sender.username, viewerA.user.username);
      assert.equal(g.sender.displayName, 'Hamza Viewer A');
      assert.equal(g.sender.avatarUrl, 'https://cdn.zeparty.test/avatars/hamza_a.png');
      assert.equal(g.sender.agoraUid, viewerA.agoraUid);
      assert.equal(g.recipient.id, hostParty.user.id);
      assert.equal(g.recipient.username, hostParty.user.username);
      assert.equal(g.recipient.displayName, 'Zara Party Host');
      assert.equal(g.recipient.avatarUrl, 'https://cdn.zeparty.test/avatars/zara_host.png');
      assert.equal(g.recipient.agoraUid, hostParty.agoraUid);
    }

    // 5c. Duplicate REST request with same idempotencyKey + follow-up Socket gift:send with committed transactionId
    const dupRestRes = await apiRequest('POST', '/v1/gifts/send', viewerA.token, {
      giftId: testGift.id,
      recipientUserId: hostParty.user.id,
      partyRoomId: partyRoom.id,
      quantity: 2,
      idempotencyKey,
    });
    assert.equal(dupRestRes.status, 200);
    assert.equal(dupRestRes.body.data.transactionId, txId);

    const dupSocketAck = await viewerASocket.emitWithAck('gift:send', {
      giftId: testGift.id,
      recipientUserId: hostParty.user.id,
      roomId: partyRoom.id,
      quantity: 2,
      transactionId: txId,
    });
    assert.equal(dupSocketAck.ok, true);
    assert.equal(dupSocketAck.data.deduplicated, true);

    // Wallet must only have been debited ONCE (2 * 100 = 200 coins)
    const walletAfter = await prisma.wallet.findUnique({ where: { userId: viewerA.user.id } });
    assert.equal(Number(walletBefore.coinBalance - walletAfter.coinBalance), 200);

    // Unrelated Live Room A must NOT have received the Party gift
    assert.equal(hostLiveASocket.hasReceivedEvent('room:gift_sent'), false);
  });

  it('6. PK Session Cross-Room Broadcasting & Isolation: Gifts during an ACTIVE PK match reach both paired PK rooms and update PK scores', async () => {
    const hostLiveASocket = liveRoomA.hostSocket;
    const hostLiveBSocket = await new SocketIOTestClient(port, {
      token: hostLiveB.token,
    }).connect();
    clients.push(hostLiveBSocket);

    const liveBJoinAck = await hostLiveBSocket.emitWithAck('room:join', {
      roomId: liveRoomB.id,
    });
    assert.equal(liveBJoinAck.ok, true);

    // Create an ACTIVE PKMatch between liveRoomA (Host A) and liveRoomB (Host B)
    pkMatch = await prisma.pKMatch.create({
      data: {
        roomAId: liveRoomA.id,
        roomBId: liveRoomB.id,
        hostAUserId: hostLiveA.user.id,
        hostBUserId: hostLiveB.user.id,
        operatorAUserId: hostLiveA.user.id,
        operatorBUserId: hostLiveB.user.id,
        roomType: 'LIVE_VIDEO',
        status: 'ACTIVE',
        durationSeconds: 300,
        startAt: new Date(),
        endAt: new Date(Date.now() + 300 * 1000),
      },
    });
    createdMatchIds.push(pkMatch.id);

    hostLiveASocket.clearEvents();
    hostLiveBSocket.clearEvents();
    partyRoom.sockets.hostPartySocket.clearEvents();

    // Viewer B sends a gift to Host Live A referencing pkId (without even passing roomId!)
    const pkGiftRes = await apiRequest('POST', '/v1/gifts/send', viewerB.token, {
      giftId: testGift.id,
      recipientUserId: hostLiveA.user.id,
      pkId: pkMatch.id,
      quantity: 1,
    });
    assert.equal(pkGiftRes.status, 200);
    const pkTxId = pkGiftRes.body.data.transactionId;

    // Both Host Live A (in roomA) AND Host Live B (in roomB) must receive room:gift_sent AND pk:score_update!
    const [hostAGift, hostBGift, hostAScore, hostBScore] = await Promise.all([
      hostLiveASocket.waitForEvent('room:gift_sent', (p) => p.transactionId === pkTxId),
      hostLiveBSocket.waitForEvent('room:gift_sent', (p) => p.transactionId === pkTxId),
      hostLiveASocket.waitForEvent('pk:score_update', (p) => p.matchId === pkMatch.id),
      hostLiveBSocket.waitForEvent('pk:score_update', (p) => p.matchId === pkMatch.id),
    ]);

    assert.equal(hostAGift.sender.id, viewerB.user.id);
    assert.equal(hostAGift.recipient.id, hostLiveA.user.id);
    assert.equal(hostBGift.sender.id, viewerB.user.id);
    assert.equal(Number(hostAScore.scoreA), 100);
    assert.equal(Number(hostBScore.scoreA), 100);

    // Party room must NOT receive PK events from Live rooms A & B
    assert.equal(partyRoom.sockets.hostPartySocket.hasReceivedEvent('pk:score_update'), false);
  });

  it('7. Stale Membership Cleanup: Leaving a room via REST evicts sockets so departed users no longer receive room events', async () => {
    const { hostPartySocket, viewerASocket, viewerBSocket } = partyRoom.sockets;

    // Viewer A leaves Party Room via REST POST /v1/rooms/:id/leave
    const leaveRes = await apiRequest('POST', `/v1/rooms/${partyRoom.id}/leave`, viewerA.token, {});
    assert.equal(leaveRes.status, 200);

    viewerASocket.clearEvents();
    viewerBSocket.clearEvents();
    hostPartySocket.clearEvents();

    // Viewer B sends a new chat message in Party Room
    const afterLeaveMsg = 'Message after Viewer A left the room';
    const chatAck = await viewerBSocket.emitWithAck('room:chat', {
      roomId: partyRoom.id,
      message: afterLeaveMsg,
    });
    assert.equal(chatAck.ok, true);

    // Host and Viewer B receive it
    await Promise.all([
      hostPartySocket.waitForEvent('room:chat_message', (p) => p.message === afterLeaveMsg),
      viewerBSocket.waitForEvent('room:chat_message', (p) => p.message === afterLeaveMsg),
    ]);

    // Departed Viewer A must NOT receive the new room chat message
    assert.equal(
      viewerASocket.hasReceivedEvent('room:chat_message', (p) => p.message === afterLeaveMsg),
      false
    );
  });
});
