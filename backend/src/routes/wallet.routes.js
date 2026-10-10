import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import idempotencyMiddleware from '../middlewares/idempotency.js';
import walletController from '../controllers/wallet.controller.js';

const router = express.Router();

router.use(authenticate);

// User-facing endpoints
router.get('/balance', walletController.getBalance);
router.get('/ledger', walletController.getLedger);
router.get('/diamond-details', walletController.getDiamondDetails);
router.get('/transfer-receivers', walletController.getTransferReceivers);
router.get('/coin-records', walletController.getCoinRecords);
router.post('/diamonds/exchange', idempotencyMiddleware, walletController.exchangeDiamonds);
router.post('/diamonds/transfer', idempotencyMiddleware, walletController.transferDiamonds);

// Administrative financial endpoints
router.get('/stats', requirePermission('view_finance'), walletController.getPlatformStats);
router.post(
  '/adjust',
  requirePermission('manage_balances'),
  idempotencyMiddleware,
  walletController.adjustBalance
);

export default router;
