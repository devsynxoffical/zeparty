import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import rankingRewardController from '../controllers/rankingReward.controller.js';

export const adminRankingRewardRouter = express.Router();
adminRankingRewardRouter.use(authenticate);

// Admin Event & Ranking Reward Management (Events -> Ranking Rewards)
adminRankingRewardRouter.get('/', requirePermission('view_pk_events'), rankingRewardController.getAdminRankingEvents);
adminRankingRewardRouter.post('/', requirePermission('manage_pk_events'), rankingRewardController.postAdminCreateRankingEvent);
adminRankingRewardRouter.get('/:id', requirePermission('view_pk_events'), rankingRewardController.getAdminRankingEventById);
adminRankingRewardRouter.put('/:id', requirePermission('manage_pk_events'), rankingRewardController.putAdminUpdateRankingEvent);
adminRankingRewardRouter.post('/:id/status', requirePermission('manage_pk_events'), rankingRewardController.postAdminPauseOrCancelEvent);
adminRankingRewardRouter.post('/:id/distribute', requirePermission('manage_pk_events'), rankingRewardController.postAdminDistributeRewards);

export const userRankingRewardRouter = express.Router();
userRankingRewardRouter.get('/:id/leaderboard', rankingRewardController.getUserEventLeaderboard);

export default {
  adminRankingRewardRouter,
  userRankingRewardRouter,
};
