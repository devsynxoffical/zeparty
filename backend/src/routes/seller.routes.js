import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import idempotency from '../middlewares/idempotency.js';
import { requireActiveSeller } from '../middlewares/sellerAuth.js';
import sellerController from '../controllers/seller.controller.js';

export const adminSellerRouter = express.Router();
adminSellerRouter.use(authenticate);

adminSellerRouter.get('/', requirePermission('view_sellers'), sellerController.getSellers);
adminSellerRouter.post('/', requirePermission('manage_sellers'), sellerController.createSeller);
adminSellerRouter.get('/:id', requirePermission('view_sellers'), sellerController.getSellerById);
adminSellerRouter.put('/:id', requirePermission('manage_sellers'), sellerController.updateSeller);
adminSellerRouter.delete('/:id', requirePermission('manage_sellers'), sellerController.deleteSeller);
adminSellerRouter.put('/:id/status', requirePermission('manage_sellers'), sellerController.updateSellerStatus);
adminSellerRouter.patch('/:id/status', requirePermission('manage_sellers'), sellerController.updateSellerStatus);
adminSellerRouter.post('/:id/allocate', requirePermission('issue_coins'), idempotency, sellerController.allocateCoins);
adminSellerRouter.post('/:id/correct', requirePermission('reseller_corrections'), idempotency, sellerController.correctBalance);

export const userSellerRouter = express.Router();

// Public / User seller directory (Authenticated with server-side country filtering)
userSellerRouter.get('/', authenticate, sellerController.getPublicSellers);
userSellerRouter.get('/public', authenticate, sellerController.getPublicSellers);
userSellerRouter.get('/:id', authenticate, sellerController.getSellerByIdAndVerify);

// Authenticated Seller Portal (Requires authoritative active CoinSeller association)
userSellerRouter.get('/me', authenticate, requireActiveSeller, sellerController.getMySellerPortal);
userSellerRouter.get('/me/portal', authenticate, requireActiveSeller, sellerController.getMySellerPortal);
userSellerRouter.get('/recharge/verify-recipient', authenticate, requireActiveSeller, sellerController.verifyRecipient);
userSellerRouter.post('/recharge/transfer', authenticate, requireActiveSeller, idempotency, sellerController.transferCoins);

export default {
  adminSellerRouter,
  userSellerRouter,
};

