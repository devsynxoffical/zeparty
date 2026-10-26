import http from 'node:http';
import pino from 'pino';
import { config } from './config.js';
import { JwtAuthAdapter, MockAuthAdapter } from './auth/adapters.js';
import { hasDatabase } from './db/pool.js';
import { runMigrations } from './db/migrate.js';
import { GameConfigStore } from './admin/gameConfig.js';
import { MemoryWalletRepository } from './wallet/memoryRepository.js';
import { PgWalletRepository } from './wallet/pgRepository.js';
import { WalletService } from './wallet/service.js';
import { MemoryMatchStore, PgMatchStore } from './rooms/matchStore.js';
import { AchievementService } from './achievements/service.js';
import { RoomManager } from './rooms/roomManager.js';
import { MatchmakingQueue } from './matchmaking/queue.js';
import { GameSocketServer } from './websocket/server.js';
import { createApp } from './http/app.js';
import { seedCosmetics } from '../database/seeds/cosmetics.js';

const log = pino({ level: config.LOG_LEVEL });

async function main(): Promise<void> {
  const auth = config.AUTH_ADAPTER === 'jwt' ? new JwtAuthAdapter(config.JWT_SECRET, config.JWT_ISSUER) : new MockAuthAdapter(config.JWT_SECRET, config.JWT_ISSUER);

  if (hasDatabase()) {
    const ran = await runMigrations();
    log.info({ ran }, 'migrations');
  } else {
    log.warn('DATABASE_URL not set: running with in-memory stores (development only, state is lost on restart)');
  }

  const gameConfig = new GameConfigStore();
  const walletRepo = hasDatabase() ? new PgWalletRepository() : new MemoryWalletRepository();
  const wallet = new WalletService(walletRepo, gameConfig);
  const matchStore = hasDatabase() ? new PgMatchStore() : new MemoryMatchStore();
  const achievements = new AchievementService(AchievementService.defaultStore(), wallet);
  await achievements.ensureSeeded();
  await seedCosmetics(walletRepo);

  const server = http.createServer();
  const sockets = new GameSocketServer(server, auth, config.DISCONNECT_GRACE_SECONDS, log);
  const rooms = new RoomManager({ gameConfig, wallet, matchStore, achievements, outbound: sockets });
  const matchmaking = new MatchmakingQueue(rooms, gameConfig);
  sockets.rooms = rooms;
  sockets.matchmaking = matchmaking;
  matchmaking.start();

  const app = createApp({
    auth,
    gameConfig,
    wallet,
    walletRepo,
    rooms,
    matchStore,
    achievements,
    matchmaking,
    adminApiKey: config.ADMIN_API_KEY,
    onlineUserIds: () => sockets.connectedUserIds(),
  });
  server.on('request', app);
  server.listen(config.PORT, () => log.info({ port: config.PORT, auth: config.AUTH_ADAPTER, db: hasDatabase() ? 'postgres' : 'memory' }, 'zeparty games backend listening'));

  const shutdown = () => {
    log.info('shutting down');
    matchmaking.stop();
    sockets.close();
    server.close(() => process.exit(0));
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  log.error({ err }, 'fatal');
  process.exit(1);
});
