import express from 'express';
import authenticate, { optionalAuthenticate } from '../middlewares/authenticate.js';
import leaderboardController from '../controllers/leaderboard.controller.js';
import socialController from '../controllers/social.controller.js';

export const userLeaderboardRouter = express.Router();
userLeaderboardRouter.get('/lucky-records', optionalAuthenticate, leaderboardController.getLuckyGiftRecords);
userLeaderboardRouter.get('/lucky-gifts', optionalAuthenticate, leaderboardController.getLuckyGiftRecords);
userLeaderboardRouter.get('/cp-pairs', optionalAuthenticate, socialController.getCpPairRankings);
userLeaderboardRouter.get('/', optionalAuthenticate, leaderboardController.getRankings);

export const adminLeaderboardRouter = express.Router();
adminLeaderboardRouter.use(authenticate);
adminLeaderboardRouter.get('/lucky-records', leaderboardController.getLuckyGiftRecords);
adminLeaderboardRouter.get('/lucky-gifts', leaderboardController.getLuckyGiftRecords);
adminLeaderboardRouter.get('/', leaderboardController.getAdminRankings);

export default userLeaderboardRouter;
