import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import exchangeTransferController from '../controllers/exchangeTransfer.controller.js';

export const adminExchangeTransferRouter = express.Router();
adminExchangeTransferRouter.use(authenticate);

// Admin Exchange & Transfer Rate Control (Wallet & Finance)
adminExchangeTransferRouter.get('/', requirePermission('manage_finance'), exchangeTransferController.getAdminExchangeTransferControl);
adminExchangeTransferRouter.post('/preview', requirePermission('manage_finance'), exchangeTransferController.postAdminPreviewCalculation);
adminExchangeTransferRouter.post('/publish', requirePermission('manage_finance'), exchangeTransferController.postAdminPublishConfiguration);
adminExchangeTransferRouter.post('/rollback', requirePermission('manage_finance'), exchangeTransferController.postAdminRollbackConfiguration);

export const userExchangeTransferRouter = express.Router();
userExchangeTransferRouter.get('/status', exchangeTransferController.getUserExchangeTransferStatus);
userExchangeTransferRouter.post('/preview', exchangeTransferController.postAdminPreviewCalculation);

export default {
  adminExchangeTransferRouter,
  userExchangeTransferRouter,
};
