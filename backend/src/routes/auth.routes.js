import express from 'express';
import authController from '../controllers/auth.controller.js';
import authenticate from '../middlewares/authenticate.js';

const router = express.Router();

// Public authentication routes
router.post('/request-otp', authController.requestOtp);
router.post('/otp/send', authController.requestOtp); // Blueprint alias

router.post('/verify-otp', authController.verifyOtp);
router.post('/otp/verify', authController.verifyOtp); // Blueprint alias

// App user sync / registration routes for Firebase, Google, Email, Apple & Guest accounts
router.post('/sync', authController.syncAppUser);
router.post('/firebase-sync', authController.syncAppUser);
router.post('/social-login', authController.syncAppUser);
router.post('/register-app-user', authController.syncAppUser);

router.post('/refresh', authController.refresh);
router.post('/admin/login', authController.adminLogin);

router.post('/logout', authController.logout);
router.get('/me', authenticate, authController.me);

export default router;

