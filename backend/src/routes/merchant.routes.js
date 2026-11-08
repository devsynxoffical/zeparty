import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import { requireActiveMerchant } from '../middlewares/merchantAuth.js';
import merchantController from '../controllers/merchant.controller.js';

export const adminMerchantRouter = express.Router();
adminMerchantRouter.use(authenticate);

adminMerchantRouter.get('/', requirePermission('view_merchants'), merchantController.getMerchants);
adminMerchantRouter.post('/', requirePermission('manage_merchants'), merchantController.createMerchant);
adminMerchantRouter.get('/:id', requirePermission('view_merchants'), merchantController.getMerchantById);
adminMerchantRouter.put('/:id', requirePermission('manage_merchants'), merchantController.updateMerchant);
adminMerchantRouter.patch('/:id', requirePermission('manage_merchants'), merchantController.updateMerchant);
adminMerchantRouter.post('/:id/adjust-balance', requirePermission('manage_merchants'), merchantController.adjustBalance);
adminMerchantRouter.post('/:id/balance', requirePermission('manage_merchants'), merchantController.adjustBalance);
adminMerchantRouter.delete('/:id', requirePermission('manage_merchants'), merchantController.deleteMerchant);

export const userMerchantRouter = express.Router();

// Merchant Self Portal & Recharge (Authoritative active Merchant required)
userMerchantRouter.get('/me', authenticate, requireActiveMerchant, merchantController.getMyMerchantCenter);
userMerchantRouter.get('/me/dashboard', authenticate, requireActiveMerchant, merchantController.getMerchantDashboard);
userMerchantRouter.get('/ledger', authenticate, requireActiveMerchant, merchantController.getMerchantLedger);
userMerchantRouter.post('/recharge', authenticate, requireActiveMerchant, merchantController.executeMerchantRecharge);
userMerchantRouter.get('/recharge/verify', authenticate, merchantController.verifyMerchantRecharge);

export default {
  adminMerchantRouter,
  userMerchantRouter,
};
