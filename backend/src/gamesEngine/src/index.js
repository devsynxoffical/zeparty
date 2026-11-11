import crypto from 'node:crypto';

// Polyfill global WebCrypto for Prisma WASM Query Engine & Rust getrandom
if (typeof globalThis.crypto === 'undefined' || !globalThis.crypto.getRandomValues) {
  globalThis.crypto = crypto.webcrypto;
}
if (typeof global.crypto === 'undefined' || !global.crypto.getRandomValues) {
  global.crypto = crypto.webcrypto;
}

import pino from 'pino';
import env from '../../config/env.js';
import { MockAuthAdapter } from './auth/adapters.js';
import { GameConfigStore } from './admin/gameConfig.js';
import { MemoryWalletRepository } from './wallet/memoryRepository.js';
import { WalletService } from './wallet/service.js';
import { MemoryMatchStore } from './rooms/matchStore.js';
import { AchievementService, MemoryAchievementStore } from './achievements/service.js';
import { RoomManager } from './rooms/roomManager.js';
import { MatchmakingQueue } from './matchmaking/queue.js';
import { GameSocketServer } from './websocket/server.js';
import { createApp } from './http/app.js';
import { seedCosmetics } from '../database/seeds/cosmetics.js';

const log = pino({ level: process.env.LOG_LEVEL || 'info' });
const auth = new MockAuthAdapter(env.GAMES_JWT_SECRET, env.GAMES_JWT_ISSUER);
const gameConfig = new GameConfigStore(false);
const walletRepo = new MemoryWalletRepository();
const wallet = new WalletService(walletRepo, gameConfig);
const matchStore = new MemoryMatchStore();
const achievements = new AchievementService(new MemoryAchievementStore(), wallet);

seedCosmetics(walletRepo).catch((err) => {
  log.warn({ err }, 'Failed to seed game cosmetics');
});

let activeSockets = null;

const outboundProxy = {
  toUser(userId, message) {
    if (activeSockets) activeSockets.toUser(userId, message);
  },
  toRoom(room, message, except) {
    if (activeSockets) activeSockets.toRoom(room, message, except);
  },
};

const rooms = new RoomManager({
  gameConfig,
  wallet,
  matchStore,
  achievements,
  outbound: outboundProxy,
});

const matchmaking = new MatchmakingQueue(rooms, gameConfig, 3000);
matchmaking.start(1000);

export const gamesSubApp = createApp({
  auth,
  gameConfig,
  wallet,
  walletRepo,
  rooms,
  matchStore,
  achievements,
  matchmaking,
  adminApiKey: process.env.ADMIN_API_KEY || 'zeparty-admin-key',
  onlineUserIds: () => (activeSockets ? activeSockets.connectedUserIds() : []),
});

const rootGamePrefixes = [
  '/me',
  '/games',
  '/rooms',
  '/matchmaking',
  '/wallet',
  '/cosmetics',
  '/inventory',
  '/achievements',
  '/leaderboards',
  '/matches',
];

/**
 * Express middleware that routes `/api/games-hub/*`, `/api/v1/games-hub/*`,
 * and root game client requests (`/games`, `/rooms`, `/matchmaking/*`, etc.)
 * to the embedded Games Engine HTTP app.
 */
export function gamesHttpMiddleware(req, res, next) {
  if (
    rootGamePrefixes.some(
      (prefix) => req.path === prefix || req.path.startsWith(`${prefix}/`)
    )
  ) {
    return gamesSubApp(req, res, next);
  }
  return next();
}

/**
 * Attaches the multiplexed `/ws` WebSocket server to the main HTTP server.
 */
export function attachGamesWebSocketServer(httpServer) {
  if (activeSockets) return activeSockets;
  activeSockets = new GameSocketServer(httpServer, auth, 60, log);
  activeSockets.rooms = rooms;
  activeSockets.matchmaking = matchmaking;
  console.log('🎮 Embedded ZeParty Multiplayer Games Engine listening on /api/games-hub and /ws');
  return activeSockets;
}

export function shutdownGamesEngine() {
  matchmaking.stop();
  if (activeSockets) {
    activeSockets.close();
    activeSockets = null;
  }
}
