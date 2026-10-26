import express from 'express';
import gameController from '../controllers/game.controller.js';
import { authenticate } from '../middlewares/auth.middleware.js';

export const userGameRouter = express.Router();
export const adminGameRouter = express.Router();

// ── Games service session token (zeparty_games backend, AUTH_ADAPTER=jwt) ──
userGameRouter.get('/token', authenticate, gameController.getGamesToken);

// ── Module 01: Rocket Game 5-Level Targets ──
userGameRouter.get('/rocket/progress', gameController.getRocketProgress);
userGameRouter.post('/rocket/contribute', authenticate, gameController.contributeRocket);

// ── Game Catalog (keep the parameterised route last) ──
userGameRouter.get('/', gameController.getCatalog);
userGameRouter.get('/catalog', gameController.getCatalog);
userGameRouter.get('/:id', gameController.getGameById);

// ── Admin Game Routes ──
adminGameRouter.get('/', gameController.getCatalog);
adminGameRouter.get('/rocket/targets', gameController.getRocketTargetsAdmin);
adminGameRouter.put('/rocket/targets', gameController.updateRocketTargetsAdmin);

export default { userGameRouter, adminGameRouter };
