import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import { requireActiveBD } from '../middlewares/bdAuth.js';
import bdCenterController from '../controllers/bdCenter.controller.js';

export const adminBDCenterRouter = express.Router();
adminBDCenterRouter.use(authenticate);

adminBDCenterRouter.get('/policy/commission-table', requirePermission('manage_bd_centers'), bdCenterController.getCommissionPolicyTable);
adminBDCenterRouter.get('/lookup-user', requirePermission('manage_bd_centers'), bdCenterController.lookupUserForBD);
adminBDCenterRouter.get('/', requirePermission('manage_bd_centers'), bdCenterController.getBDCenters);
adminBDCenterRouter.post('/', requirePermission('manage_bd_centers'), bdCenterController.createBDCenter);
adminBDCenterRouter.get('/:id', requirePermission('manage_bd_centers'), bdCenterController.getBDCenterById);
adminBDCenterRouter.put('/:id', requirePermission('manage_bd_centers'), bdCenterController.updateBDCenter);
adminBDCenterRouter.delete('/:id', requirePermission('manage_bd_centers'), bdCenterController.removeBDRole);
adminBDCenterRouter.post('/:id/remove', requirePermission('manage_bd_centers'), bdCenterController.removeBDRole);
adminBDCenterRouter.post('/:id/invites', requirePermission('manage_bd_centers'), bdCenterController.sendInvite);
adminBDCenterRouter.get('/:id/invites', requirePermission('manage_bd_centers'), bdCenterController.getBDCenterInvites);

export const userBDCenterRouter = express.Router();
userBDCenterRouter.get('/policy/commission-table', bdCenterController.getCommissionPolicyTable);
userBDCenterRouter.get('/invite/:code', bdCenterController.validateInvite);
userBDCenterRouter.post('/invite/accept', authenticate, bdCenterController.acceptInvite);
userBDCenterRouter.get('/my-status', authenticate, bdCenterController.getMyBDStatus);

// BD Agent & Center Manager Protected Operations
userBDCenterRouter.get('/dashboard', authenticate, requireActiveBD, bdCenterController.getBDDashboard);
userBDCenterRouter.get('/agents', authenticate, requireActiveBD, bdCenterController.getBDAgentsList);
userBDCenterRouter.post('/invite', authenticate, requireActiveBD, bdCenterController.sendAgentInvitation);
userBDCenterRouter.get('/salary', authenticate, requireActiveBD, bdCenterController.getBDSalary);
userBDCenterRouter.get('/salary/history', authenticate, requireActiveBD, bdCenterController.getBDSalaryHistory);
userBDCenterRouter.get('/targets', authenticate, requireActiveBD, bdCenterController.getBDTargets);
userBDCenterRouter.get('/income', authenticate, requireActiveBD, bdCenterController.getBDIncome);
userBDCenterRouter.get('/commission', authenticate, requireActiveBD, bdCenterController.getBDCommission);
userBDCenterRouter.get('/settings', authenticate, requireActiveBD, bdCenterController.getBDSettings);
userBDCenterRouter.get('/audit-history', authenticate, requireActiveBD, bdCenterController.getBDAuditHistory);

// SVIP Control (BD Center & Admin)
userBDCenterRouter.get('/svip/search', authenticate, requireActiveBD, bdCenterController.searchUserSVIP);
userBDCenterRouter.post('/svip/manage', authenticate, requireActiveBD, bdCenterController.manageUserSVIP);
userBDCenterRouter.get('/svip/history/:userId', authenticate, requireActiveBD, bdCenterController.getSVIPHistory);

// Noble Control (BD Center & Admin)
userBDCenterRouter.get('/noble/search', authenticate, requireActiveBD, bdCenterController.searchUserNoble);
userBDCenterRouter.post('/noble/manage', authenticate, requireActiveBD, bdCenterController.manageUserNoble);
userBDCenterRouter.get('/noble/history/:userId', authenticate, requireActiveBD, bdCenterController.getNobleHistory);

// Event Management (BD Center & Admin)
userBDCenterRouter.get('/events', authenticate, requireActiveBD, bdCenterController.listEvents);
userBDCenterRouter.post('/events', authenticate, requireActiveBD, bdCenterController.createEvent);
userBDCenterRouter.get('/events/:id', authenticate, requireActiveBD, bdCenterController.getEventDetails);
userBDCenterRouter.put('/events/:id', authenticate, requireActiveBD, bdCenterController.updateEvent);
userBDCenterRouter.post('/events/:id/settle', authenticate, requireActiveBD, bdCenterController.settleEvent);
userBDCenterRouter.get('/events/:id/history', authenticate, requireActiveBD, bdCenterController.getEventHistory);

export default {
  adminBDCenterRouter,
  userBDCenterRouter,
};


