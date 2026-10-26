import express, { type NextFunction, type Request, type Response } from 'express';
import { z } from 'zod';
import type { AuthAdapter, ZePartyIdentity } from '../auth/types.js';
import { MockAuthAdapter } from '../auth/adapters.js';
import type { GameConfigStore } from '../admin/gameConfig.js';
import { GameConfigPatchSchema } from '../admin/gameConfig.js';
import { GAME_CATALOG } from '../games/registry.js';
import type { RoomManager } from '../rooms/roomManager.js';
import { RoomError } from '../rooms/roomManager.js';
import { toRoomView } from '../rooms/types.js';
import type { MatchStore } from '../rooms/matchStore.js';
import { weeklyPeriod } from '../rooms/matchStore.js';
import type { WalletService } from '../wallet/service.js';
import { WalletError, type WalletRepository } from '../wallet/types.js';
import type { AchievementService } from '../achievements/service.js';
import type { MatchmakingQueue } from '../matchmaking/queue.js';

export interface AppDeps {
  auth: AuthAdapter;
  gameConfig: GameConfigStore;
  wallet: WalletService;
  walletRepo: WalletRepository;
  rooms: RoomManager;
  matchStore: MatchStore;
  achievements: AchievementService;
  matchmaking: MatchmakingQueue;
  adminApiKey: string;
  /** Called by the demo to know which users are online. */
  onlineUserIds: () => string[];
}

interface AuthedRequest extends Request {
  identity?: ZePartyIdentity;
}

class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message?: string,
  ) {
    super(message ?? code);
  }
}

export function createApp(deps: AppDeps): express.Express {
  const app = express();
  app.use(express.json({ limit: '64kb' }));
  app.disable('x-powered-by');

  const requireAuth = async (req: AuthedRequest, _res: Response, next: NextFunction) => {
    const header = req.header('authorization') ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    const identity = token ? await deps.auth.verify(token) : null;
    if (!identity) return next(new HttpError(401, 'unauthorized'));
    req.identity = identity;
    next();
  };

  const requireAdmin = (req: Request, _res: Response, next: NextFunction) => {
    if (req.header('x-admin-key') !== deps.adminApiKey) return next(new HttpError(403, 'forbidden'));
    next();
  };

  const wrap =
    (fn: (req: AuthedRequest, res: Response) => Promise<unknown> | unknown) =>
    (req: Request, res: Response, next: NextFunction) => {
      Promise.resolve(fn(req as AuthedRequest, res))
        .then((body) => {
          if (!res.headersSent) res.json(body ?? {});
        })
        .catch(next);
    };

  const parse = <T>(schema: z.ZodType<T>, data: unknown): T => {
    const r = schema.safeParse(data);
    if (!r.success) throw new HttpError(400, 'validation_error', r.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; '));
    return r.data;
  };

  // ---------------------------------------------------------------------------------------
  app.get('/health', (_req, res) => res.json({ ok: true, time: new Date().toISOString() }));

  // Dev-only identity issuing. Disabled automatically when AUTH_ADAPTER=jwt.
  app.post(
    '/auth/dev-login',
    wrap((req) => {
      if (!(deps.auth instanceof MockAuthAdapter)) throw new HttpError(404, 'not_found');
      const body = parse(z.object({ userId: z.string().min(1).max(64), displayName: z.string().min(1).max(40), avatarUrl: z.string().url().nullable().optional() }), req.body);
      const token = deps.auth.issue({ userId: body.userId, displayName: body.displayName, avatarUrl: body.avatarUrl ?? null });
      return { token, identity: { userId: body.userId, displayName: body.displayName, avatarUrl: body.avatarUrl ?? null, roles: [] } };
    }),
  );

  app.get(
    '/me',
    requireAuth,
    wrap((req) => req.identity),
  );

  // Catalog -----------------------------------------------------------------------------
  app.get(
    '/games',
    wrap(async () => {
      const configs = await deps.gameConfig.all(GAME_CATALOG.map((g) => g.gameId));
      return {
        games: GAME_CATALOG.filter((g) => configs[g.gameId]?.enabled !== false).map((g) => ({
          ...g,
          featured: configs[g.gameId]?.featured ?? false,
          minPlayers: configs[g.gameId]?.minPlayers ?? g.minPlayers,
          maxPlayers: configs[g.gameId]?.maxPlayers ?? g.maxPlayers,
          turnTimeoutSeconds: configs[g.gameId]?.turnTimeoutSeconds,
          rewards: configs[g.gameId]?.rewards,
          rules: configs[g.gameId]?.rules,
          onlineRooms: deps.rooms.listPublicRooms(g.gameId).length,
        })),
        onlineUsers: deps.onlineUserIds().length,
      };
    }),
  );

  // Rooms (REST mirror of the WS commands for lobby screens) --------------------------------
  app.get(
    '/rooms',
    requireAuth,
    wrap((req) => ({ rooms: deps.rooms.listPublicRooms(typeof req.query['gameId'] === 'string' ? req.query['gameId'] : undefined) })),
  );
  app.post(
    '/rooms',
    requireAuth,
    wrap(async (req) => {
      const body = parse(z.object({ gameId: z.string(), isPrivate: z.boolean().optional(), maxPlayers: z.number().int().optional(), rules: z.record(z.unknown()).optional() }), req.body);
      const room = await deps.rooms.createRoom(req.identity!, body.gameId, body);
      return { room: toRoomView(room), inviteCode: room.inviteCode };
    }),
  );
  app.get(
    '/rooms/:roomId',
    requireAuth,
    wrap((req) => {
      const room = deps.rooms.getRoom(req.params['roomId'] ?? '');
      if (!room) throw new HttpError(404, 'room_not_found');
      return { room: toRoomView(room) };
    }),
  );
  app.post(
    '/rooms/:roomId/join',
    requireAuth,
    wrap((req) => {
      const body = parse(z.object({ inviteCode: z.string().optional() }), req.body ?? {});
      const room = deps.rooms.joinRoom(req.identity!, req.params['roomId'] ?? '', body.inviteCode);
      return { room: toRoomView(room) };
    }),
  );
  app.post(
    '/rooms/:roomId/invite',
    requireAuth,
    wrap((req) => {
      const body = parse(z.object({ userId: z.string() }), req.body);
      deps.rooms.invite(req.identity!.userId, req.params['roomId'] ?? '', body.userId);
      return { ok: true };
    }),
  );
  app.post(
    '/rooms/leave',
    requireAuth,
    wrap((req) => {
      deps.rooms.leaveRoom(req.identity!.userId, 'left');
      return { ok: true };
    }),
  );

  app.post(
    '/matchmaking/join',
    requireAuth,
    wrap(async (req) => {
      const body = parse(z.object({ gameId: z.string(), tableSize: z.number().int().optional() }), req.body);
      return deps.matchmaking.enqueue(req.identity!, body.gameId, body.tableSize);
    }),
  );
  app.post(
    '/matchmaking/leave',
    requireAuth,
    wrap((req) => ({ removed: deps.matchmaking.dequeue(req.identity!.userId) })),
  );
  app.get(
    '/matchmaking/status',
    requireAuth,
    wrap((req) => deps.matchmaking.status(req.identity!.userId)),
  );

  // Wallet ---------------------------------------------------------------------------------
  app.get(
    '/wallet',
    requireAuth,
    wrap((req) => deps.wallet.getBalance(req.identity!.userId)),
  );
  app.get(
    '/wallet/transactions',
    requireAuth,
    wrap(async (req) => ({
      transactions: await deps.wallet.listTransactions(req.identity!.userId, Number(req.query['limit'] ?? 50), typeof req.query['before'] === 'string' ? req.query['before'] : undefined),
    })),
  );
  app.post(
    '/wallet/daily-claim',
    requireAuth,
    wrap(async (req) => {
      const cfg = await deps.gameConfig.get('common');
      const amount = Number(cfg.rules['dailyRewardCoins'] ?? 20);
      const day = new Date().toISOString().slice(0, 10);
      const r = await deps.wallet.grantDailyReward(req.identity!.userId, day, amount);
      return { result: r?.status ?? 'disabled', amount: r?.status === 'applied' ? amount : 0, wallet: r?.wallet };
    }),
  );

  app.get(
    '/cosmetics',
    requireAuth,
    wrap(async (req) => ({ cosmetics: await deps.wallet.listCosmetics(typeof req.query['gameId'] === 'string' ? req.query['gameId'] : undefined) })),
  );
  app.get(
    '/inventory',
    requireAuth,
    wrap(async (req) => ({
      items: await deps.wallet.listInventory(req.identity!.userId),
      equipped: typeof req.query['gameId'] === 'string' ? await deps.wallet.listEquipped(req.identity!.userId, req.query['gameId']) : {},
    })),
  );
  app.post(
    '/inventory/purchase',
    requireAuth,
    wrap(async (req) => {
      const body = parse(z.object({ cosmeticId: z.string(), idempotencyKey: z.string().min(8).max(128) }), req.body);
      const r = await deps.wallet.purchaseCosmetic(req.identity!.userId, body.cosmeticId, body.idempotencyKey);
      return { status: r.status, wallet: r.wallet, item: r.item };
    }),
  );
  app.post(
    '/inventory/equip',
    requireAuth,
    wrap(async (req) => {
      const body = parse(z.object({ cosmeticId: z.string() }), req.body);
      await deps.wallet.equip(req.identity!.userId, body.cosmeticId);
      return { ok: true };
    }),
  );

  // Achievements, leaderboards, history -----------------------------------------------------
  app.get(
    '/achievements',
    requireAuth,
    wrap(async (req) => ({ achievements: await deps.achievements.list(req.identity!.userId) })),
  );
  app.post(
    '/achievements/:id/claim',
    requireAuth,
    wrap(async (req) => {
      try {
        const r = await deps.achievements.claim(req.identity!.userId, req.params['id'] ?? '');
        return { status: r?.status ?? 'no_reward', wallet: r && 'wallet' in r ? r.wallet : undefined };
      } catch (e) {
        throw new HttpError(409, (e as Error).message);
      }
    }),
  );
  app.post(
    '/achievements/tutorial-complete',
    requireAuth,
    wrap(async (req) => ({ unlocked: await deps.achievements.unlockTutorial(req.identity!.userId) })),
  );
  app.get(
    '/leaderboards/:gameId',
    requireAuth,
    wrap(async (req) => {
      const period = req.query['period'] === 'weekly' ? weeklyPeriod() : 'alltime';
      const gameId = req.params['gameId'] ?? '';
      return { period, entries: await deps.matchStore.leaderboard(gameId, period, 100), me: await deps.matchStore.userRank(gameId, period, req.identity!.userId) };
    }),
  );
  app.get(
    '/matches/history',
    requireAuth,
    wrap(async (req) => ({ matches: await deps.matchStore.history(req.identity!.userId, Number(req.query['limit'] ?? 30)) })),
  );
  app.get(
    '/matches/:matchId',
    requireAuth,
    wrap(async (req) => {
      const m = await deps.matchStore.get(req.params['matchId'] ?? '');
      if (!m) throw new HttpError(404, 'match_not_found');
      return { match: m };
    }),
  );

  // Admin ----------------------------------------------------------------------------------
  app.get(
    '/admin/config',
    requireAdmin,
    wrap(async () => deps.gameConfig.all(['common', ...GAME_CATALOG.map((g) => g.gameId)])),
  );
  app.put(
    '/admin/config/:gameId',
    requireAdmin,
    wrap(async (req) => deps.gameConfig.set(req.params['gameId'] ?? '', parse(GameConfigPatchSchema, req.body))),
  );
  app.put(
    '/admin/cosmetics/:cosmeticId',
    requireAdmin,
    wrap(async (req) => {
      const body = parse(
        z.object({ gameId: z.string(), category: z.string(), name: z.string(), description: z.string().optional(), price: z.number().int().min(0), previewAsset: z.string().nullable().optional(), enabled: z.boolean().optional() }),
        req.body,
      );
      await deps.walletRepo.upsertCosmetic({ cosmeticId: req.params['cosmeticId'] ?? '', gameId: body.gameId, category: body.category, name: body.name, description: body.description ?? '', price: body.price, previewAsset: body.previewAsset ?? null, enabled: body.enabled ?? true });
      return { ok: true };
    }),
  );
  app.post(
    '/admin/wallet/grant',
    requireAdmin,
    wrap(async (req) => {
      const body = parse(z.object({ userId: z.string(), amount: z.number().int(), idempotencyKey: z.string().min(8), reason: z.string().optional() }), req.body);
      return deps.wallet.adminAdjust(body.userId, body.amount, body.idempotencyKey, body.reason ?? '');
    }),
  );
  app.post(
    '/admin/wallet/promo',
    requireAdmin,
    wrap(async (req) => {
      const body = parse(z.object({ userId: z.string(), promoId: z.string(), amount: z.number().int().positive() }), req.body);
      return deps.wallet.grantPromo(body.userId, body.promoId, body.amount);
    }),
  );

  // Errors ---------------------------------------------------------------------------------
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof HttpError) return res.status(err.status).json({ error: err.code, message: err.message });
    if (err instanceof RoomError) return res.status(409).json({ error: err.code, message: err.message });
    if (err instanceof WalletError) return res.status(err.code === 'insufficient_funds' ? 402 : 409).json({ error: err.code, message: err.message });
    if (err instanceof SyntaxError) return res.status(400).json({ error: 'bad_json' });
    console.error(err);
    return res.status(500).json({ error: 'internal' });
  });

  return app;
}
