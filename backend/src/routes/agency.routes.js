import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import agencyController from '../controllers/agency.controller.js';

export const adminAgencyRouter = express.Router();
adminAgencyRouter.use(authenticate);

adminAgencyRouter.get('/', requirePermission('view_agencies'), agencyController.getAgencies);
adminAgencyRouter.post('/', requirePermission('approve_reject_agencies'), agencyController.createAgency);
adminAgencyRouter.get('/:id', requirePermission('view_agencies'), agencyController.getAgencyById);
adminAgencyRouter.put('/:id', requirePermission('approve_reject_agencies'), agencyController.updateAgency);
adminAgencyRouter.post('/:id/transfer-host', requirePermission('approve_reject_agencies'), agencyController.transferHostAgency);
adminAgencyRouter.get('/:id/members', requirePermission('view_agencies'), agencyController.getAgencyMembers);

export const userAgencyRouter = express.Router();
userAgencyRouter.get('/', agencyController.getPublicAgencies);
userAgencyRouter.get('/public', agencyController.getPublicAgencies);
userAgencyRouter.get('/my-agency', authenticate, agencyController.getMyAgency);
userAgencyRouter.get('/me', authenticate, agencyController.getMyAgency);
userAgencyRouter.get('/wallet', authenticate, agencyController.getMyAgencyWallet);
userAgencyRouter.post('/wallet/withdraw', authenticate, agencyController.withdrawMyAgencyCommission);
userAgencyRouter.get('/:id/wallet', authenticate, agencyController.getAgencyWallet);
userAgencyRouter.post('/:id/wallet/withdraw', authenticate, agencyController.withdrawAgencyCommission);
userAgencyRouter.post('/apply', authenticate, agencyController.applyRegisterAgency);
userAgencyRouter.post('/', authenticate, agencyController.applyRegisterAgency);
userAgencyRouter.post('/join', authenticate, agencyController.joinAgency);


export default {
  adminAgencyRouter,
  userAgencyRouter,
};

