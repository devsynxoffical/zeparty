import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import socialController from '../controllers/social.controller.js';

export const socialRouter = express.Router();

// ============================================================
// SOCIAL PROFILE, PRIVACY, FOLLOWS & BLOCKS
// ============================================================

// Social Profile (Optionally authenticated for isFollowing / isBlocked status)
socialRouter.get('/users/:id/social-profile', authenticate, socialController.getSocialProfile);

// Privacy Settings
socialRouter.put('/users/me/privacy', authenticate, socialController.putPrivacySettings);

// Follow / Unfollow
socialRouter.post('/users/:id/follow', authenticate, socialController.postFollow);
socialRouter.delete('/users/:id/follow', authenticate, socialController.deleteFollow);
socialRouter.get('/users/:id/followers', authenticate, socialController.getFollowers);
socialRouter.get('/users/:id/following', authenticate, socialController.getFollowing);

// Blocks
socialRouter.get('/users/me/blocked', authenticate, socialController.getBlockedUsers);
socialRouter.post('/users/:id/block', authenticate, socialController.postBlock);
socialRouter.delete('/users/:id/block', authenticate, socialController.deleteBlock);

// CP / Relationships
socialRouter.get('/relationship/me', authenticate, socialController.getRelationship);
socialRouter.get('/users/:userId/relationship', authenticate, socialController.getRelationship);
socialRouter.get('/relationship/cards', socialController.getRelationshipCards);
socialRouter.post('/relationship/purchase-and-send', authenticate, socialController.purchaseAndSendRelationshipCard);
socialRouter.post('/relationship/request', authenticate, socialController.requestRelationship);
socialRouter.post('/relationship/respond', authenticate, socialController.respondRelationship);
socialRouter.post('/relationship/dissolve', authenticate, socialController.dissolveRelationship);

export default socialRouter;
