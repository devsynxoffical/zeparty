import { Router } from 'express';
import { authenticate } from '../middlewares/auth.middleware.js';
import mysteryController from '../controllers/mystery.controller.js';

const router = Router();

router.get('/status', authenticate, mysteryController.getMysteryStatus);
router.post('/purchase', authenticate, mysteryController.purchaseMysterySuit);

export default router;
