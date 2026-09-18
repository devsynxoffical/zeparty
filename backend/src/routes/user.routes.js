import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import userController from '../controllers/user.controller.js';

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

// User Self & Public Profile Routes
userProfileRouter.get('/me', authenticate, userController.getMe);
userProfileRouter.put('/profile', authenticate, userController.putMyProfile);
userProfileRouter.patch('/profile', authenticate, userController.putMyProfile);
userProfileRouter.get('/:id', authenticate, userController.getPublicUserById);

export default {
  adminUserRouter,
  userProfileRouter,
};
