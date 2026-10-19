import prisma from '../config/database.js';
import agencyRepository from '../repositories/agency.repository.js';
import agencyService from '../services/agency.service.js';
import hostRepository from '../repositories/host.repository.js';
import hostingEligibilityService, {
  validateHostingEligibility,
} from '../services/hostingEligibility.service.js';
import {
  createAgencySchema,
  updateAgencySchema,
  transferHostSchema,
  queryAgenciesSchema,
  submitAgencyApplicationSchema,
  rejectAgencyApplicationSchema,
  queryAgencyApplicationsSchema,
} from '../validators/agency.validator.js';

export async function getPublicAgencies(req, res, next) {
  try {
    const { search, page, limit } = req.query;
    const result = await agencyRepository.findAgencies({
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
      search: search || '',
      status: 'ACTIVE',
    });

    return res.status(200).json({
      success: true,
      message: 'Active agencies retrieved successfully',
      data: result.agencies,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function joinAgency(req, res, next) {
  try {
    const { agencyCode } = req.body;
    const userId = req.auth.userId;
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    if (!agencyCode) {
      return res.status(400).json({
        success: false,
        message: 'Agency code is required',
        error: { code: 'MISSING_AGENCY_CODE' },
      });
    }

    const agency = await agencyRepository.findAgencyByCode(agencyCode);
    if (!agency || agency.status !== 'ACTIVE') {
      return res.status(404).json({
        success: false,
        message: 'Active agency with this code not found',
        error: { code: 'AGENCY_NOT_FOUND' },
      });
    }

    // 1. Enforce Shared Server-Side Eligibility Validator
    // Active Live Host or Pending Live Host request is blocked immediately!
    await validateHostingEligibility(userId, 'JOIN_AUDIO_HOST', prisma);

    // 2. Ensure Audio Host profile exists for membership binding
    let host = await hostRepository.findHostProfileByUserId(userId);
    if (!host) {
      host = await prisma.hostProfile.create({
        data: {
          userId,
          hostType: 'AUDIO_HOST',
          hostStatus: 'ACTIVE',
          hostLevel: 1,
        },
      });
      await prisma.user.update({
        where: { id: userId },
        data: { userType: 'HOST' },
      });
    }

    const member = await agencyService.bindHostToAgency(
      { agencyId: agency.id, hostProfileId: host.id },
      { adminId: userId, adminName: 'Host Self-Join', ipAddress }
    );

    return res.status(200).json({
      success: true,
      message: 'Joined agency successfully',
      data: member,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAgencies(req, res, next) {
  try {
    const validatedQuery = queryAgenciesSchema.parse(req.query);
    const result = await agencyRepository.findAgencies(validatedQuery);

    return res.status(200).json({
      success: true,
      message: 'Agencies list retrieved successfully',
      data: result.agencies,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function createAgency(req, res, next) {
  try {
    const validatedData = createAgencySchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const agency = await agencyService.createAgency(validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Agency created successfully',
      data: agency,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAgencyById(req, res, next) {
  try {
    const { id } = req.params;
    const agency = await agencyService.getAgencyDetails(id);

    return res.status(200).json({
      success: true,
      message: 'Agency details retrieved successfully',
      data: agency,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateAgency(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = updateAgencySchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await agencyService.updateAgency(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Agency updated successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function transferHostAgency(req, res, next) {
  try {
    const validatedData = transferHostSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const member = await agencyService.transferHostBetweenAgencies(validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Host transferred to new agency successfully',
      data: member,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAgencyMembers(req, res, next) {
  try {
    const { id } = req.params;
    const { page, limit } = req.query;

    const result = await agencyRepository.findAgencyMembers(id, {
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
    });

    return res.status(200).json({
      success: true,
      message: 'Agency members list retrieved successfully',
      data: result.members,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getMyAgency(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const agency = await agencyRepository.findAgencyByOwnerUserId(userId);
    return res.status(200).json({
      success: true,
      data: agency || null,
    });
  } catch (err) {
    next(err);
  }
}

export async function submitAgencyApplication(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const validatedData = submitAgencyApplicationSchema.parse(req.body);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const application = await agencyService.submitAgencyApplication(
      validatedData,
      { userId, ipAddress }
    );

    return res.status(201).json({
      success: true,
      message: 'Agency application submitted successfully and is pending administrative review.',
      data: application,
    });
  } catch (err) {
    if (err.name === 'ZodError') {
      return res.status(400).json({
        success: false,
        message: err.errors?.[0]?.message || 'Validation error in agency application',
        error: {
          code: 'VALIDATION_ERROR',
          details: err.errors,
        },
      });
    }
    next(err);
  }
}

// Backwards compatibility alias for existing mobile route POST /v1/agencies/apply
export async function applyRegisterAgency(req, res, next) {
  return await submitAgencyApplication(req, res, next);
}

export async function getMyAgencyApplication(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const application = await agencyService.getMyAgencyApplication(userId);
    return res.status(200).json({
      success: true,
      data: application || null,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAgencyApplications(req, res, next) {
  try {
    const validatedQuery = queryAgencyApplicationsSchema.parse(req.query);
    const result = await agencyService.getAgencyApplications(validatedQuery);

    return res.status(200).json({
      success: true,
      message: 'Agency applications retrieved successfully',
      data: result.applications,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAgencyApplicationById(req, res, next) {
  try {
    const { id } = req.params;
    const application = await agencyService.getAgencyApplicationById(id);

    return res.status(200).json({
      success: true,
      data: application,
    });
  } catch (err) {
    next(err);
  }
}

export async function approveAgencyApplication(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth?.userId || req.admin?.id;
    const adminName = req.admin?.name || req.auth?.role || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await agencyService.approveAgencyApplication(id, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Agency application approved successfully. Agency activated and owner assigned.',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function rejectAgencyApplication(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = rejectAgencyApplicationSchema.parse(req.body);
    const adminId = req.auth?.userId || req.admin?.id;
    const adminName = req.admin?.name || req.auth?.role || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await agencyService.rejectAgencyApplication(id, {
      reason: validatedData.reason,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Agency application rejected.',
      data: updated,
    });
  } catch (err) {
    if (err.name === 'ZodError') {
      return res.status(400).json({
        success: false,
        message: err.errors?.[0]?.message || 'Validation error in rejection reason',
        error: { code: 'VALIDATION_ERROR', details: err.errors },
      });
    }
    next(err);
  }
}

export async function getAgencyWallet(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId;
    const result = await agencyService.getAgencyWallet(id, userId);
    return res.status(200).json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
}

export async function withdrawAgencyCommission(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId;
    const { amountUSD, recipientId, recipientRole } = req.body;
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await agencyService.withdrawAgencyCommission({
      agencyId: id,
      userId,
      amountUSD,
      recipientId,
      recipientRole,
      ipAddress,
    });

    return res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getMyAgencyWallet(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const agency = await agencyRepository.findAgencyByOwnerUserId(userId);
    if (!agency) {
      return res.status(404).json({
        success: false,
        message: 'No active agency found owned by your account.',
        error: { code: 'NO_OWNED_AGENCY' },
      });
    }

    const result = await agencyService.getAgencyWallet(agency.id, userId);
    return res.status(200).json({ success: true, ...result });
  } catch (err) {
    next(err);
  }
}

export async function withdrawMyAgencyCommission(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const agency = await agencyRepository.findAgencyByOwnerUserId(userId);
    if (!agency) {
      return res.status(404).json({
        success: false,
        message: 'No active agency found owned by your account.',
        error: { code: 'NO_OWNED_AGENCY' },
      });
    }

    const { amountUSD, recipientId, recipientRole } = req.body;
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await agencyService.withdrawAgencyCommission({
      agencyId: agency.id,
      userId,
      amountUSD,
      recipientId,
      recipientRole,
      ipAddress,
    });

    return res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getHostingEligibility(req, res, next) {
  try {
    const userId = req.auth.userId;
    const eligibility = await hostingEligibilityService.getHostingEligibilityOverview(userId);

    return res.status(200).json({
      success: true,
      message: 'Hosting eligibility retrieved successfully',
      data: eligibility,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getPublicAgencies,
  joinAgency,
  getHostingEligibility,
  getMyAgency,
  applyRegisterAgency,
  submitAgencyApplication,
  getMyAgencyApplication,
  getAgencyApplications,
  getAgencyApplicationById,
  approveAgencyApplication,
  rejectAgencyApplication,
  getAgencies,
  createAgency,
  getAgencyById,
  updateAgency,
  transferHostAgency,
  getAgencyMembers,
  getAgencyWallet,
  withdrawAgencyCommission,
  getMyAgencyWallet,
  withdrawMyAgencyCommission,
};

