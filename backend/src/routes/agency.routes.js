import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import { requirePermission } from '../middlewares/requirePermission.js';
import agencyController from '../controllers/agency.controller.js';
import sellerController from '../controllers/seller.controller.js';

export const adminAgencyRouter = express.Router();
adminAgencyRouter.use(authenticate);

// ── Agency Applications Queue & Actions (MUST come before /:id to avoid shadowing) ──
adminAgencyRouter.get('/applications', requirePermission('view_agencies'), agencyController.getAgencyApplications);
adminAgencyRouter.get('/applications/:id', requirePermission('view_agencies'), agencyController.getAgencyApplicationById);
adminAgencyRouter.post('/applications/:id/approve', requirePermission('approve_reject_agencies'), agencyController.approveAgencyApplication);
adminAgencyRouter.post('/applications/:id/reject', requirePermission('approve_reject_agencies'), agencyController.rejectAgencyApplication);

// ── Existing Agency CRUD ──
adminAgencyRouter.get('/', requirePermission('view_agencies'), agencyController.getAgencies);
adminAgencyRouter.post('/', requirePermission('approve_reject_agencies'), agencyController.createAgency);
adminAgencyRouter.get('/:id', requirePermission('view_agencies'), agencyController.getAgencyById);
adminAgencyRouter.put('/:id', requirePermission('approve_reject_agencies'), agencyController.updateAgency);
adminAgencyRouter.post('/:id/transfer-host', requirePermission('approve_reject_agencies'), agencyController.transferHostAgency);
adminAgencyRouter.get('/:id/members', requirePermission('view_agencies'), agencyController.getAgencyMembers);

export const userAgencyRouter = express.Router();
userAgencyRouter.get('/', agencyController.getPublicAgencies);
userAgencyRouter.get('/public', agencyController.getPublicAgencies);

// Coin Sellers route requested by Flutter CoinAgencyProvider
userAgencyRouter.get('/sellers', authenticate, sellerController.getPublicSellers);
userAgencyRouter.get('/eligibility', authenticate, agencyController.getHostingEligibility);
userAgencyRouter.get('/my-agency', authenticate, agencyController.getMyAgency);
userAgencyRouter.get('/me', authenticate, agencyController.getMyAgency);
userAgencyRouter.get('/wallet', authenticate, agencyController.getMyAgencyWallet);
userAgencyRouter.post('/wallet/withdraw', authenticate, agencyController.withdrawMyAgencyCommission);
userAgencyRouter.get('/:id/wallet', authenticate, agencyController.getAgencyWallet);
userAgencyRouter.post('/:id/wallet/withdraw', authenticate, agencyController.withdrawAgencyCommission);

// Application submission & status tracking
userAgencyRouter.post('/apply', authenticate, agencyController.submitAgencyApplication);
userAgencyRouter.post('/application', authenticate, agencyController.submitAgencyApplication);
userAgencyRouter.post('/', authenticate, agencyController.submitAgencyApplication);
userAgencyRouter.get('/application/status', authenticate, agencyController.getMyAgencyApplication);
userAgencyRouter.get('/application/me', authenticate, agencyController.getMyAgencyApplication);
userAgencyRouter.get('/application', authenticate, agencyController.getMyAgencyApplication);

userAgencyRouter.post('/join', authenticate, agencyController.joinAgency);


export default {
  adminAgencyRouter,
  userAgencyRouter,
};

