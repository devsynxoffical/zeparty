import express from 'express';
import { optionalAuthenticate } from '../middlewares/authenticate.js';
import leaderboardController from '../controllers/leaderboard.controller.js';

const router = express.Router();

router.get('/', optionalAuthenticate, leaderboardController.getRankings);

export default router;
