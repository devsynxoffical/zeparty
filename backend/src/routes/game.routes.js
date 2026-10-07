import express from 'express';
import gameController from '../controllers/game.controller.js';
import { authenticate } from '../middlewares/auth.middleware.js';

export const userGameRouter = express.Router();
export const adminGameRouter = express.Router();

// ── Game Catalog ──
userGameRouter.get('/', gameController.getCatalog);
userGameRouter.get('/catalog', gameController.getCatalog);
userGameRouter.get('/:id', gameController.getGameById);

// ── Sessions & Anti-Cheat ──
userGameRouter.post('/sessions', authenticate, gameController.createSession);
userGameRouter.post('/sessions/:id/events', authenticate, gameController.recordEvents);
userGameRouter.post('/sessions/:id/finish', authenticate, gameController.finishSession);

// ── Reward Points & Shop ──
userGameRouter.get('/rp/wallet', authenticate, gameController.getRpWallet);
userGameRouter.get('/shop', authenticate, gameController.getShop);
userGameRouter.post('/shop/buy', authenticate, gameController.buyShopItem);

// ── Energy & Refills ──
userGameRouter.get('/energy', authenticate, gameController.getEnergy);
userGameRouter.post('/energy/refill', authenticate, gameController.refillEnergy);

// ── Leaderboards & Missions ──
userGameRouter.get('/leaderboards/:id', gameController.getLeaderboard);
userGameRouter.get('/missions', authenticate, gameController.getMissions);
userGameRouter.post('/missions/:id/claim', authenticate, gameController.claimMission);

// ── Admin Game Routes ──
adminGameRouter.get('/', gameController.getCatalog);

export default { userGameRouter, adminGameRouter };
