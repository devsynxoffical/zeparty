import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import hostController from '../controllers/host.controller.js';

export const adminHostRouter = express.Router();
adminHostRouter.use(authenticate);

adminHostRouter.get('/', requirePermission('view_hosts'), hostController.getHosts);
adminHostRouter.get('/applications', requirePermission('review_hosts'), hostController.getHostApplications);
adminHostRouter.put('/applications/:id', requirePermission('approve_reject_hosts'), hostController.reviewHostApplication);
adminHostRouter.get('/:id', requirePermission('view_hosts'), hostController.getHostById);
adminHostRouter.put('/:id/status', requirePermission('approve_reject_hosts'), hostController.updateHostStatus);

export const userHostRouter = express.Router();
userHostRouter.get('/policy/agency-table', hostController.getAgencyHostPolicyTable);
userHostRouter.get('/policy/live-host-table', hostController.getLiveHostPolicyTable);
userHostRouter.post('/apply', authenticate, hostController.applyHost);
userHostRouter.get('/profile', authenticate, hostController.getMyHostProfile);
userHostRouter.get('/application', authenticate, hostController.getMyHostApplication);
userHostRouter.get('/center/income', authenticate, hostController.getHostIncomeDashboard);
userHostRouter.post('/become-live-host', authenticate, hostController.becomeLiveHost);

export default {
  adminHostRouter,
  userHostRouter,
};
