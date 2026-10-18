import prisma from '../config/database.js';
import merchantRepository from '../repositories/merchant.repository.js';
import merchantService, { sanitizeMerchant } from '../services/merchant.service.js';
import {
  createMerchantSchema,
  updateMerchantSchema,
  adjustMerchantBalanceSchema,
  queryMerchantsSchema,
} from '../validators/merchant.validator.js';

export async function getMerchants(req, res, next) {
  try {
    const validatedQuery = queryMerchantsSchema.parse(req.query);
    const result = await merchantRepository.findMerchants(validatedQuery);

    const sanitized = result.merchants.map(sanitizeMerchant);

    return res.status(200).json({
      success: true,
      message: 'Merchants retrieved successfully',
      data: sanitized,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function createMerchant(req, res, next) {
  try {
    const validatedData = createMerchantSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await merchantService.createMerchant(validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Merchant account created and API credentials generated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getMerchantById(req, res, next) {
  try {
    const { id } = req.params;
    const merchant = await merchantService.getMerchantDetails(id);

    return res.status(200).json({
      success: true,
      message: 'Merchant details retrieved successfully',
      data: merchant,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateMerchant(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = updateMerchantSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await merchantService.updateMerchant(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Merchant updated successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function adjustBalance(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = adjustMerchantBalanceSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await merchantService.adjustMerchantBalance(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Merchant balance adjusted successfully',
      data: updated,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteMerchant(req, res, next) {
  try {
    const { id } = req.params;
    const { reason } = req.body || {};
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await merchantService.deleteMerchant(id, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: result.message || 'Merchant deleted successfully',
      data: null,
    });
  } catch (err) {
    next(err);
  }
}

export async function verifyMerchantRecharge(req, res, next) {
  try {
    const { type = 'USER', id, userId } = req.query;
    const targetId = (id || userId || '').trim();
    if (!targetId) {
      return res.status(400).json({
        success: false,
        message: 'Recipient ID or identifier is required',
        error: { code: 'INVALID_RECIPIENT_ID' },
      });
    }

    const clean = targetId.replace('@', '');
    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { id: clean },
          { username: { equals: clean, mode: 'insensitive' } },
          { phone: clean },
        ],
      },
      include: { profile: true },
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: `Recipient user not found for identifier '${clean}'`,
        error: { code: 'RECIPIENT_NOT_FOUND' },
      });
    }

    return res.status(200).json({
      success: true,
      data: {
        recipientType: type || 'USER',
        recipientId: user.id,
        username: user.username,
        name: user.profile?.displayName || user.username,
        displayName: user.profile?.displayName || user.username,
        avatarUrl: user.avatarUrl,
        countryCode: user.countryCode,
        status: user.status,
        isVerified: user.status === 'ACTIVE',
      },
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getMerchants,
  createMerchant,
  getMerchantById,
  updateMerchant,
  adjustBalance,
  deleteMerchant,
  verifyMerchantRecharge,
};
