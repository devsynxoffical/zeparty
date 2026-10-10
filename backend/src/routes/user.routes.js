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
adminUserRouter.post('/verify-grant-target', requirePermission('view_users'), userController.postAdminVerifyUserForGrant);
adminUserRouter.post('/verify-unique', requirePermission('view_users'), userController.postAdminVerifyUserForGrant);
adminUserRouter.post('/grant-unique', requirePermission('view_users'), userController.postAdminGrantUniqueItem);
adminUserRouter.post('/revoke-unique', requirePermission('view_users'), userController.postAdminRevokeUniqueItem);

// User Details & Admin Controls
adminUserRouter.get('/:id/details', requirePermission('view_users'), userController.getAdminUserDetails);
adminUserRouter.put('/:id/bank-info', requirePermission('view_users'), userController.putAdminUserBankInfo);
adminUserRouter.patch('/:id/bank-info', requirePermission('view_users'), userController.putAdminUserBankInfo);
adminUserRouter.patch('/:id/ban', requirePermission('suspend_users'), userController.patchAdminUserBan);
adminUserRouter.patch('/:id/freeze', requirePermission('suspend_users'), userController.patchAdminUserFreeze);
adminUserRouter.patch('/:id/risk-status', requirePermission('view_users'), userController.patchAdminUserFraudRisk);

// Identity, Agency & Host Assignments
adminUserRouter.post('/:id/assign-agency', requirePermission('view_users'), userController.postAdminAssignAgency);
adminUserRouter.delete('/:id/remove-agency', requirePermission('view_users'), userController.deleteAdminRemoveAgency);
adminUserRouter.post('/:id/assign-host', requirePermission('view_users'), userController.postAdminAssignHost);
adminUserRouter.delete('/:id/remove-host', requirePermission('view_users'), userController.deleteAdminRemoveHost);
adminUserRouter.post('/:id/assign-parent-bo', requirePermission('view_users'), userController.postAdminAssignParentBO);

// Owned Props & Admin Actions
adminUserRouter.post('/:id/props/grant', requirePermission('view_users'), userController.postAdminGrantProp);
adminUserRouter.post('/:id/props/revoke', requirePermission('view_users'), userController.postAdminRevokeProp);
adminUserRouter.post('/:id/props/reset', requirePermission('view_users'), userController.postAdminResetProps);

// Resets (Moderation & Safety)
adminUserRouter.post('/:id/reset/avatar', requirePermission('view_users'), userController.postAdminResetAvatar);
adminUserRouter.post('/:id/reset/nickname', requirePermission('view_users'), userController.postAdminResetNickname);
adminUserRouter.post('/:id/reset/room-name', requirePermission('view_users'), userController.postAdminResetRoomName);
adminUserRouter.post('/:id/reset/room-cover', requirePermission('view_users'), userController.postAdminResetRoomCover);
adminUserRouter.post('/:id/reset/family-avatar', requirePermission('view_users'), userController.postAdminResetFamilyAvatar);
adminUserRouter.post('/:id/reset/password', requirePermission('view_users'), userController.postAdminResetPassword);

// Financial Adjustments, Refunds & Histories
adminUserRouter.post('/:id/wallet/adjust-balance', requirePermission('view_users'), userController.postAdminAdjustWalletBalance);
adminUserRouter.post('/:id/wallet/refund-correction', requirePermission('view_users'), userController.postAdminCoinRefundCorrection);
adminUserRouter.get('/:id/history/recharges', requirePermission('view_users'), userController.getAdminUserRecharges);
adminUserRouter.get('/:id/history/gifts', requirePermission('view_users'), userController.getAdminUserGifts);
adminUserRouter.get('/:id/history/withdrawals', requirePermission('view_users'), userController.getAdminUserWithdrawals);
adminUserRouter.get('/:id/earnings', requirePermission('view_users'), userController.getAdminUserEarnings);

// Dynamics, Audit Logs, Reports, Rooms & Sessions
adminUserRouter.get('/:id/dynamics', requirePermission('view_users'), userController.getAdminUserDynamics);
adminUserRouter.get('/:id/audit-logs', requirePermission('view_users'), userController.getAdminUserAuditLogs);
adminUserRouter.get('/:id/history/reports', requirePermission('view_users'), userController.getAdminUserReports);
adminUserRouter.get('/:id/history/rooms', requirePermission('view_users'), userController.getAdminUserRooms);
adminUserRouter.get('/:id/sessions', requirePermission('view_users'), userController.getAdminUserSessions);
adminUserRouter.delete('/:id/sessions/:sessionId', requirePermission('view_users'), userController.deleteAdminUserSession);
adminUserRouter.delete('/:id/sessions', requirePermission('view_users'), userController.deleteAdminAllUserSessions);

// Permissions & Admin Roles
adminUserRouter.get('/:id/permissions', requirePermission('view_users'), userController.getAdminUserPermissions);
adminUserRouter.put('/:id/permissions', requirePermission('view_users'), userController.putAdminUserPermissions);

adminUserRouter.get('/:id', requirePermission('view_users'), userController.getAdminUserById);
adminUserRouter.put('/:id', requirePermission('view_users'), userController.putAdminUser);
adminUserRouter.patch('/:id', requirePermission('view_users'), userController.putAdminUser);
adminUserRouter.post('/:id/change-country', requirePermission('view_users'), userController.postAdminChangeUserCountry);
adminUserRouter.post('/:id/country', requirePermission('view_users'), userController.postAdminChangeUserCountry);
adminUserRouter.patch('/:id/status', requirePermission('suspend_users'), userController.patchAdminUserStatus);
adminUserRouter.put('/:id/status', requirePermission('suspend_users'), userController.patchAdminUserStatus);
adminUserRouter.delete('/:id', requirePermission('suspend_users'), userController.deleteAdminUser);
adminUserRouter.post('/:id/restore', requirePermission('suspend_users'), userController.restoreAdminUser);
adminUserRouter.delete('/:id/purge', requirePermission('suspend_users'), userController.purgeAdminUser);



// User Self & Public Profile Routes
userProfileRouter.get('/search', optionalAuthenticate, userController.searchUsers);
userProfileRouter.get('/noble-palette', userController.getNoblePalette);
userProfileRouter.get('/me', authenticate, userController.getMe);
userProfileRouter.get('/me/profile-grid', authenticate, userController.getProfileGrid);
userProfileRouter.put('/me/profile-edit', authenticate, userController.putProfileEdit);
userProfileRouter.get('/me/privacy-settings', authenticate, userController.getUserPrivacySettings);
userProfileRouter.put('/me/privacy-settings', authenticate, userController.putUserPrivacySettings);
userProfileRouter.get('/me/visitors', authenticate, socialController.getProfileVisitors);
userProfileRouter.get('/me/visited', authenticate, socialController.getProfileVisited);
userProfileRouter.put('/profile', authenticate, userController.putMyProfile);
userProfileRouter.patch('/profile', authenticate, userController.putMyProfile);
userProfileRouter.post('/delete-account', authenticate, userController.deleteSelfAccount);
userProfileRouter.delete('/delete-account', authenticate, userController.deleteSelfAccount);
userProfileRouter.delete('/me', authenticate, userController.deleteSelfAccount);

// In-room profile card and level strip
userProfileRouter.get('/:id/room-profile-card', optionalAuthenticate, userController.getRoomUserProfileCard);
userProfileRouter.get('/:id/level-strip', optionalAuthenticate, userController.getUserLevelStrip);

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
