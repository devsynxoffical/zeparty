import express from 'express';
import { optionalAuthenticate } from '../middlewares/authenticate.js';
import leaderboardController from '../controllers/leaderboard.controller.js';
import socialController from '../controllers/social.controller.js';

const router = express.Router();

router.get('/lucky-records', optionalAuthenticate, leaderboardController.getLuckyGiftRecords);
router.get('/lucky-gifts', optionalAuthenticate, leaderboardController.getLuckyGiftRecords);
router.get('/cp-pairs', optionalAuthenticate, socialController.getCpPairRankings);
router.get('/', optionalAuthenticate, leaderboardController.getRankings);

export default router;
