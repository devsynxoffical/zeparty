import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import bdCenterController from '../controllers/bdCenter.controller.js';

export const adminBDCenterRouter = express.Router();
adminBDCenterRouter.use(authenticate);

adminBDCenterRouter.get('/policy/commission-table', requirePermission('manage_bd_centers'), bdCenterController.getCommissionPolicyTable);
adminBDCenterRouter.get('/', requirePermission('manage_bd_centers'), bdCenterController.getBDCenters);
adminBDCenterRouter.post('/', requirePermission('manage_bd_centers'), bdCenterController.createBDCenter);
adminBDCenterRouter.get('/:id', requirePermission('manage_bd_centers'), bdCenterController.getBDCenterById);
adminBDCenterRouter.put('/:id', requirePermission('manage_bd_centers'), bdCenterController.updateBDCenter);
adminBDCenterRouter.post('/:id/invites', requirePermission('manage_bd_centers'), bdCenterController.sendInvite);
adminBDCenterRouter.get('/:id/invites', requirePermission('manage_bd_centers'), bdCenterController.getBDCenterInvites);

export const userBDCenterRouter = express.Router();
userBDCenterRouter.get('/policy/commission-table', bdCenterController.getCommissionPolicyTable);
userBDCenterRouter.get('/invite/:code', bdCenterController.validateInvite);
userBDCenterRouter.post('/invite/accept', authenticate, bdCenterController.acceptInvite);
userBDCenterRouter.get('/my-status', authenticate, bdCenterController.getMyBDStatus);
userBDCenterRouter.get('/dashboard', authenticate, bdCenterController.getBDDashboard);
userBDCenterRouter.get('/agents', authenticate, bdCenterController.getBDAgentsList);
userBDCenterRouter.post('/invite', authenticate, bdCenterController.sendAgentInvitation);
userBDCenterRouter.get('/salary', authenticate, bdCenterController.getBDSalary);
userBDCenterRouter.get('/salary/history', authenticate, bdCenterController.getBDSalaryHistory);
userBDCenterRouter.get('/targets', authenticate, bdCenterController.getBDTargets);
userBDCenterRouter.get('/income', authenticate, bdCenterController.getBDIncome);
userBDCenterRouter.get('/commission', authenticate, bdCenterController.getBDCommission);
userBDCenterRouter.get('/settings', authenticate, bdCenterController.getBDSettings);
userBDCenterRouter.get('/audit-history', authenticate, bdCenterController.getBDAuditHistory);

// SVIP Control (BD Center & Admin)
userBDCenterRouter.get('/svip/search', authenticate, bdCenterController.searchUserSVIP);
userBDCenterRouter.post('/svip/manage', authenticate, bdCenterController.manageUserSVIP);
userBDCenterRouter.get('/svip/history/:userId', authenticate, bdCenterController.getSVIPHistory);

// Noble Control (BD Center & Admin)
userBDCenterRouter.get('/noble/search', authenticate, bdCenterController.searchUserNoble);
userBDCenterRouter.post('/noble/manage', authenticate, bdCenterController.manageUserNoble);
userBDCenterRouter.get('/noble/history/:userId', authenticate, bdCenterController.getNobleHistory);

// Event Management (BD Center & Admin)
userBDCenterRouter.get('/events', authenticate, bdCenterController.listEvents);
userBDCenterRouter.post('/events', authenticate, bdCenterController.createEvent);
userBDCenterRouter.get('/events/:id', authenticate, bdCenterController.getEventDetails);
userBDCenterRouter.put('/events/:id', authenticate, bdCenterController.updateEvent);
userBDCenterRouter.post('/events/:id/settle', authenticate, bdCenterController.settleEvent);
userBDCenterRouter.get('/events/:id/history', authenticate, bdCenterController.getEventHistory);

export default {
  adminBDCenterRouter,
  userBDCenterRouter,
};


