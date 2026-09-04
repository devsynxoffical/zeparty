import express from 'express';
import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import authRoutes from './auth.routes.js';
import ownerRoutes from './owner.routes.js';
import adminRoutes from './admin.routes.js';
import walletRoutes from './wallet.routes.js';
import financeRoutes from './finance.routes.js';
import approvalRoutes from './approval.routes.js';
import policyRoutes from './policy.routes.js';
import economyRoutes from './economy.routes.js';
import jobsRoutes from './jobs.routes.js';
import { adminHostRouter, userHostRouter } from './host.routes.js';
import { adminAgencyRouter, userAgencyRouter } from './agency.routes.js';
import { adminBDCenterRouter, userBDCenterRouter } from './bdCenter.routes.js';
import { adminSellerRouter, userSellerRouter } from './seller.routes.js';
import { adminMerchantRouter } from './merchant.routes.js';
import { adminGiftRouter, userGiftRouter } from './gift.routes.js';
import { adminAssetRouter, userBackpackRouter } from './asset.routes.js';
import { adminStoreRouter, userStoreRouter } from './store.routes.js';

const router = express.Router();

// Register authentication, owner & admin routes
router.use('/v1/auth', authRoutes);
router.use('/auth', authRoutes);

router.use('/v1/owner', ownerRoutes);
router.use('/owner', ownerRoutes);

router.use('/v1/admin/approvals', approvalRoutes);
router.use('/admin/approvals', approvalRoutes);

router.use('/v1/admin/policies', policyRoutes);
router.use('/admin/policies', policyRoutes);

router.use('/v1/admin/economy', economyRoutes);
router.use('/admin/economy', economyRoutes);

router.use('/v1/admin/jobs', jobsRoutes);
router.use('/admin/jobs', jobsRoutes);

// Phase 8 Admin routes
router.use('/v1/admin/hosts', adminHostRouter);
router.use('/admin/hosts', adminHostRouter);

router.use('/v1/admin/agencies', adminAgencyRouter);
router.use('/admin/agencies', adminAgencyRouter);

router.use('/v1/admin/bd-centers', adminBDCenterRouter);
router.use('/admin/bd-centers', adminBDCenterRouter);

router.use('/v1/admin/sellers', adminSellerRouter);
router.use('/admin/sellers', adminSellerRouter);

router.use('/v1/admin/merchants', adminMerchantRouter);
router.use('/admin/merchants', adminMerchantRouter);

// Phase 9 Admin routes
router.use('/v1/admin/gifts', adminGiftRouter);
router.use('/admin/gifts', adminGiftRouter);

router.use('/v1/admin/assets', adminAssetRouter);
router.use('/admin/assets', adminAssetRouter);

router.use('/v1/admin/store', adminStoreRouter);
router.use('/admin/store', adminStoreRouter);

router.use('/v1/admin', adminRoutes);
router.use('/admin', adminRoutes);

// Phase 8 User / Mobile routes
router.use('/v1/hosts', userHostRouter);
router.use('/hosts', userHostRouter);

router.use('/v1/agencies', userAgencyRouter);
router.use('/agencies', userAgencyRouter);

router.use('/v1/bd-centers', userBDCenterRouter);
router.use('/bd-centers', userBDCenterRouter);

router.use('/v1/sellers', userSellerRouter);
router.use('/sellers', userSellerRouter);

// Phase 9 User / Mobile routes
router.use('/v1/gifts', userGiftRouter);
router.use('/gifts', userGiftRouter);

router.use('/v1/store', userStoreRouter);
router.use('/store', userStoreRouter);

router.use('/v1/users/me/assets', userBackpackRouter);
router.use('/users/me/assets', userBackpackRouter);

// Register wallet & financial routes
router.use('/v1/wallet', walletRoutes);
router.use('/wallet', walletRoutes);

router.use('/v1/finance', financeRoutes);
router.use('/finance', financeRoutes);


// Simple ping endpoint for fast process checks
router.get('/health/ping', (req, res) => {
  return res.status(200).json({
    success: true,
    message: 'pong',
  });
});

// Comprehensive system health check
router.get('/health', async (req, res) => {
  const services = {
    api: 'up',
    database: 'down',
    redis: 'down',
  };

  let hasError = false;

  // Verify PostgreSQL / Prisma
  try {
    await prisma.$queryRaw`SELECT 1`;
    services.database = 'up';
  } catch (error) {
    req.log.error('Health Check - Database unreachable:', error);
    hasError = true;
  }

  // Verify Redis
  try {
    if (!redisClient.isOpen) {
      await redisClient.connect();
    }
    const pingResult = await redisClient.ping();
    if (pingResult === 'PONG') {
      services.redis = 'up';
    }
  } catch (error) {
    req.log.error('Health Check - Redis unreachable:', error);
    hasError = true;
  }

  const statusCode = hasError ? 503 : 200;

  return res.status(statusCode).json({
    success: !hasError,
    status: hasError ? 'degraded' : 'healthy',
    services,
  });
});

export default router;
