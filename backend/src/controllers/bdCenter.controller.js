import bdCenterRepository from '../repositories/bdCenter.repository.js';
import bdCenterService from '../services/bdCenter.service.js';
import {
  createBDCenterSchema,
  updateBDCenterSchema,
  createBDInviteSchema,
  acceptBDInviteSchema,
  queryBDCentersSchema,
} from '../validators/bdCenter.validator.js';

export async function validateInvite(req, res, next) {
  try {
    const { code } = req.params;
    const invite = await bdCenterService.validateInviteCode(code);

    return res.status(200).json({
      success: true,
      message: 'Invitation code is valid',
      data: invite,
    });
  } catch (err) {
    next(err);
  }
}

export async function acceptInvite(req, res, next) {
  try {
    const validatedData = acceptBDInviteSchema.parse(req.body);
    const userId = req.auth.userId;
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdCenterService.acceptBDInvite(
      validatedData.invitationCode,
      userId,
      { ipAddress }
    );

    return res.status(200).json({
      success: true,
      message: 'BD Center invitation accepted successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDCenters(req, res, next) {
  try {
    const validatedQuery = queryBDCentersSchema.parse(req.query);
    const result = await bdCenterRepository.findBDCenters(validatedQuery);

    const serializedCenters = result.centers.map((c) => ({
      ...c,
      totalGroupDiamondsMonth: c.totalGroupDiamondsMonth ? c.totalGroupDiamondsMonth.toString() : '0',
    }));

    return res.status(200).json({
      success: true,
      message: 'BD Centers retrieved successfully',
      data: serializedCenters,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function createBDCenter(req, res, next) {
  try {
    const validatedData = createBDCenterSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const center = await bdCenterService.createBDCenter(validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'BD Center created successfully',
      data: center,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDCenterById(req, res, next) {
  try {
    const { id } = req.params;
    const center = await bdCenterService.getBDCenterDetails(id);

    return res.status(200).json({
      success: true,
      message: 'BD Center details retrieved successfully',
      data: center,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateBDCenter(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = updateBDCenterSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await bdCenterService.updateBDCenter(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'BD Center updated successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function sendInvite(req, res, next) {
  try {
    const { id: bdCenterId } = req.params;
    const { targetUserId } = req.body;
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const validatedData = createBDInviteSchema.parse({ bdCenterId, targetUserId });

    const invite = await bdCenterService.sendBDInvite(validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'BD Center invitation sent successfully',
      data: invite,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDCenterInvites(req, res, next) {
  try {
    const { id } = req.params;
    const { page, limit } = req.query;

    const result = await bdCenterRepository.findInvitesByCenter(id, {
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
    });

    return res.status(200).json({
      success: true,
      message: 'BD Center invitations retrieved successfully',
      data: result.invites,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getMyBDStatus(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getMyBDStatus(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDAgentsList(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDAgentsList(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function sendAgentInvitation(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { targetUserId, message } = req.body;
    const result = await bdCenterService.sendAgentInvitation(userId, { targetUserId, message });
    return res.status(201).json({
      success: true,
      message: 'Agent invitation sent successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDSalary(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDSalary(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDDashboard(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDDashboard(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDTargets(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDTargets(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDIncome(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDIncome(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDCommission(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDCommission(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDSalaryHistory(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDSalaryHistory(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDSettings(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDSettings(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBDAuditHistory(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const result = await bdCenterService.getBDAuditHistory(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

// ─── SVIP & Noble Control Endpoints ───

export async function searchUserSVIP(req, res, next) {
  try {
    const { query } = req.query;
    const result = await bdCenterService.searchUserForSVIP(query || '');
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function manageUserSVIP(req, res, next) {
  try {
    const operatorId = req.auth?.userId || 'ADMIN';
    const { targetUserId, level, actionType, startDate, expiryDate, reason } = req.body;
    const result = await bdCenterService.grantOrUpdateUserSVIP(operatorId, {
      targetUserId,
      level,
      actionType: actionType || 'GRANT',
      startDate,
      expiryDate,
      reason: reason || 'BD Center / Admin manual assignment',
    });
    return res.status(200).json({
      success: true,
      message: `User SVIP successfully updated to Level ${level}`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getSVIPHistory(req, res, next) {
  try {
    const { userId } = req.params;
    const result = await bdCenterService.getSVIPAuditHistory(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function searchUserNoble(req, res, next) {
  try {
    const { query } = req.query;
    const result = await bdCenterService.searchUserForNoble(query || '');
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function manageUserNoble(req, res, next) {
  try {
    const operatorId = req.auth?.userId || 'ADMIN';
    const { targetUserId, rank, actionType, startDate, expiryDate, reason } = req.body;
    const result = await bdCenterService.grantOrUpdateUserNoble(operatorId, {
      targetUserId,
      rank,
      actionType: actionType || 'GRANT',
      startDate,
      expiryDate,
      reason: reason || 'BD Center / Admin manual assignment',
    });
    return res.status(200).json({
      success: true,
      message: `User Noble status successfully updated to ${rank}`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getNobleHistory(req, res, next) {
  try {
    const { userId } = req.params;
    const result = await bdCenterService.getNobleAuditHistory(userId);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function listEvents(req, res, next) {
  try {
    const { page, limit, status, type, scope, search } = req.query;
    const result = await bdCenterService.listBDEvents({ page, limit, status, type, scope, search });
    return res.status(200).json({
      success: true,
      message: 'Events retrieved successfully',
      data: result.events,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function createEvent(req, res, next) {
  try {
    const operatorId = req.auth.userId;
    const operatorName = req.admin?.name || 'BD Manager';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdCenterService.createBDEvent(req.body, {
      operatorId,
      operatorName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Event created successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getEventDetails(req, res, next) {
  try {
    const { id } = req.params;
    const result = await bdCenterService.getBDEventDetails(id);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateEvent(req, res, next) {
  try {
    const { id } = req.params;
    const operatorId = req.auth.userId;
    const operatorName = req.admin?.name || 'BD Manager';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdCenterService.updateBDEvent(id, req.body, {
      operatorId,
      operatorName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Event updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function settleEvent(req, res, next) {
  try {
    const { id } = req.params;
    const operatorId = req.auth.userId;
    const operatorName = req.admin?.name || 'BD Manager';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdCenterService.settleBDEvent(id, {
      operatorId,
      operatorName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Event settled and final rankings locked',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getEventHistory(req, res, next) {
  try {
    const { id } = req.params;
    const result = await bdCenterService.getBDEventAuditHistory(id);
    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getCommissionPolicyTable(req, res, next) {
  try {
    const table = bdCenterService.getBDMonthlyCommissionPolicyTable();
    return res.status(200).json({
      success: true,
      message: 'BD Monthly Commission Policy Table retrieved successfully',
      data: table,
    });
  } catch (err) {
    next(err);
  }
}

export async function lookupUserForBD(req, res, next) {
  try {
    const { query } = req.query;
    const result = await bdCenterService.lookupUserForBD(query);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function removeBDRole(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await bdCenterService.removeBDRole({
      bdCenterId: id,
      adminId,
      adminName,
      reason,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export default {
  validateInvite,
  acceptInvite,
  getBDCenters,
  createBDCenter,
  getBDCenterById,
  updateBDCenter,
  sendInvite,
  getBDCenterInvites,
  getMyBDStatus,
  getBDAgentsList,
  sendAgentInvitation,
  getBDSalary,
  getBDDashboard,
  getBDTargets,
  getBDIncome,
  getBDCommission,
  getCommissionPolicyTable,
  getBDSalaryHistory,
  getBDSettings,
  getBDAuditHistory,
  searchUserSVIP,
  manageUserSVIP,
  getSVIPHistory,
  searchUserNoble,
  manageUserNoble,
  getNobleHistory,
  listEvents,
  createEvent,
  getEventDetails,
  updateEvent,
  settleEvent,
  getEventHistory,
  lookupUserForBD,
  removeBDRole,
};



