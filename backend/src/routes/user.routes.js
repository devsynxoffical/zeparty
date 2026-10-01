import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import userController from '../controllers/user.controller.js';
import socialController from '../controllers/social.controller.js';
import { optionalAuthenticate } from '../middlewares/authenticate.js';

export const adminUserRouter = express.Router();
export const userProfileRouter = express.Router();

// Admin User Management Routes (require authenticate + RBAC)
adminUserRouter.use(authenticate);
adminUserRouter.get('/', requirePermission('view_users'), userController.getAdminUsers);
adminUserRouter.post('/', requirePermission('view_users'), userController.postAdminUser);
adminUserRouter.get('/:id', requirePermission('view_users'), userController.getAdminUserById);
adminUserRouter.put('/:id', requirePermission('view_users'), userController.putAdminUser);
adminUserRouter.patch('/:id', requirePermission('view_users'), userController.putAdminUser);
adminUserRouter.patch('/:id/status', requirePermission('suspend_users'), userController.patchAdminUserStatus);
adminUserRouter.put('/:id/status', requirePermission('suspend_users'), userController.patchAdminUserStatus);
adminUserRouter.delete('/:id', requirePermission('suspend_users'), userController.deleteAdminUser);
adminUserRouter.post('/:id/restore', requirePermission('suspend_users'), userController.restoreAdminUser);
adminUserRouter.delete('/:id/purge', requirePermission('suspend_users'), userController.purgeAdminUser);

// User Self & Public Profile Routes
userProfileRouter.get('/search', optionalAuthenticate, userController.searchUsers);
userProfileRouter.get('/me', authenticate, userController.getMe);
userProfileRouter.get('/me/visitors', authenticate, socialController.getProfileVisitors);
userProfileRouter.get('/me/visited', authenticate, socialController.getProfileVisited);
userProfileRouter.put('/profile', authenticate, userController.putMyProfile);
userProfileRouter.patch('/profile', authenticate, userController.putMyProfile);
userProfileRouter.post('/delete-account', authenticate, userController.deleteSelfAccount);
userProfileRouter.delete('/delete-account', authenticate, userController.deleteSelfAccount);
userProfileRouter.delete('/me', authenticate, userController.deleteSelfAccount);

// Social, Follows, Followers, Visitors, & Blocks (mounted directly on /users/:id)
userProfileRouter.get('/:id/social-profile', optionalAuthenticate, socialController.getSocialProfile);
userProfileRouter.post('/:id/visit', authenticate, socialController.recordProfileVisit);
userProfileRouter.post('/:id/follow', authenticate, socialController.postFollow);
userProfileRouter.delete('/:id/follow', authenticate, socialController.deleteFollow);
userProfileRouter.get('/:id/followers', optionalAuthenticate, socialController.getFollowers);
userProfileRouter.get('/:id/following', optionalAuthenticate, socialController.getFollowing);
userProfileRouter.post('/:id/block', authenticate, socialController.postBlock);
userProfileRouter.delete('/:id/block', authenticate, socialController.deleteBlock);

userProfileRouter.get('/:id', authenticate, userController.getPublicUserById);

export default {
  adminUserRouter,
  userProfileRouter,
};
