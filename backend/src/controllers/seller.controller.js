import sellerRepository from '../repositories/seller.repository.js';
import sellerService from '../services/seller.service.js';
import {
  createSellerSchema,
  updateSellerStatusSchema,
  allocateSellerCoinsSchema,
  correctSellerBalanceSchema,
  querySellersSchema,
  sellerTransferCoinsSchema,
  verifyRecipientQuerySchema,
} from '../validators/seller.validator.js';

export async function getPublicSellers(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to view authorized coin sellers in your country',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const { page, limit, search, q } = req.query;
    const result = await sellerService.getEligibleSellersForUser({
      userId,
      search: (search || q || '').trim(),
      page: page ? Number(page) : 1,
      limit: limit ? Number(limit) : 20,
    });

    return res.status(200).json({
      success: true,
      message: result.message,
      data: result.sellers,
      userCountry: result.userCountry,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getSellerByIdAndVerify(req, res, next) {
  try {
    const clientUserId = req.auth?.userId;
    const { id } = req.params;
    const { seller, sellerCountry } = await sellerService.validateSellerEligibility(id, clientUserId);

    return res.status(200).json({
      success: true,
      data: {
        id: seller.id,
        sellerId: seller.id,
        userId: seller.userId,
        name: seller.businessName || seller.user?.profile?.displayName || seller.user?.username || 'Authorized Seller',
        businessName: seller.businessName,
        avatarUrl: seller.user?.avatarUrl || '',
        region: sellerCountry.name,
        country: sellerCountry.code,
        countryCode: sellerCountry.code,
        type: 'official',
        status: 'approved',
        isVisible: true,
        paymentMethods: ['Direct Transfer', 'Bank Transfer'],
        stockCoins: Number(seller.resellerBalanceCoins || seller.user?.wallet?.sellerBalanceCoins || 0),
        user: {
          id: seller.user?.id,
          username: seller.user?.username,
          displayName: seller.user?.profile?.displayName || seller.user?.username,
          avatarUrl: seller.user?.avatarUrl,
          countryCode: sellerCountry.code,
          region: sellerCountry.name,
        },
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function getSellers(req, res, next) {
  try {
    const validatedQuery = querySellersSchema.parse(req.query);
    const result = await sellerRepository.findSellers(validatedQuery);

    const serializedSellers = result.sellers.map((s) => ({
      ...s,
      resellerBalanceCoins: s.resellerBalanceCoins ? s.resellerBalanceCoins.toString() : '0',
      creditLimitUSD: s.creditLimitUSD ? s.creditLimitUSD.toString() : '0.00',
      user: s.user
        ? {
            ...s.user,
            wallet: s.user.wallet
              ? {
                  sellerBalanceCoins: s.user.wallet.sellerBalanceCoins
                    ? s.user.wallet.sellerBalanceCoins.toString()
                    : '0',
                  coinBalance: s.user.wallet.coinBalance ? s.user.wallet.coinBalance.toString() : '0',
                }
              : null,
          }
        : null,
    }));

    return res.status(200).json({
      success: true,
      message: 'Coin sellers retrieved successfully',
      data: serializedSellers,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function createSeller(req, res, next) {
  try {
    const validatedData = createSellerSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const seller = await sellerService.createSeller(validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Coin seller created successfully',
      data: {
        ...seller,
        resellerBalanceCoins: seller.resellerBalanceCoins ? seller.resellerBalanceCoins.toString() : '0',
        creditLimitUSD: seller.creditLimitUSD ? seller.creditLimitUSD.toString() : '0.00',
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function getSellerById(req, res, next) {
  try {
    const { id } = req.params;
    const seller = await sellerRepository.findSellerById(id);

    if (!seller) {
      return res.status(404).json({
        success: false,
        message: 'Coin seller not found',
        error: { code: 'SELLER_NOT_FOUND' },
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Coin seller details retrieved successfully',
      data: {
        ...seller,
        resellerBalanceCoins: seller.resellerBalanceCoins ? seller.resellerBalanceCoins.toString() : '0',
        creditLimitUSD: seller.creditLimitUSD ? seller.creditLimitUSD.toString() : '0.00',
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function updateSellerStatus(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = updateSellerStatusSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await sellerService.updateSellerStatus(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Coin seller status updated successfully',
      data: {
        ...updated,
        resellerBalanceCoins: updated.resellerBalanceCoins ? updated.resellerBalanceCoins.toString() : '0',
        creditLimitUSD: updated.creditLimitUSD ? updated.creditLimitUSD.toString() : '0.00',
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function allocateCoins(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = allocateSellerCoinsSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const isOwner = Boolean(req.auth?.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await sellerService.allocateCoinsToSeller(id, validatedData, {
      adminId,
      adminName,
      isOwner,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: result.requiresApproval
        ? 'Coin allocation submitted for maker-checker approval'
        : 'Coins allocated to reseller successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function correctBalance(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = correctSellerBalanceSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const isOwner = Boolean(req.auth?.isOwner);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await sellerService.correctSellerBalance(id, validatedData, {
      adminId,
      adminName,
      isOwner,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: result.requiresApproval
        ? 'Coin correction submitted for maker-checker approval'
        : 'Reseller balance corrected successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateSeller(req, res, next) {
  try {
    const { id } = req.params;
    const validatedData = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const updated = await sellerService.updateSeller(id, validatedData, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Coin seller updated successfully',
      data: {
        ...updated,
        resellerBalanceCoins: updated.resellerBalanceCoins ? updated.resellerBalanceCoins.toString() : '0',
        creditLimitUSD: updated.creditLimitUSD ? updated.creditLimitUSD.toString() : '0.00',
      },
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteSeller(req, res, next) {
  try {
    const { id } = req.params;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await sellerService.deleteSeller(id, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Coin seller removed successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getMySellerPortal(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const portal = await sellerService.getSellerPortalByUserId(userId);
    return res.status(200).json({
      success: true,
      message: 'Seller portal details retrieved successfully',
      data: portal,
    });
  } catch (err) {
    next(err);
  }
}

export async function verifyRecipient(req, res, next) {
  try {
    const validated = verifyRecipientQuerySchema.parse(req.query);
    const recipient = await sellerService.verifyRechargeRecipient(validated.userId);

    return res.status(200).json({
      success: true,
      message: 'Recipient verified successfully',
      data: recipient,
    });
  } catch (err) {
    next(err);
  }
}

export async function transferCoins(req, res, next) {
  try {
    const sellerUserId = req.auth?.userId;
    if (!sellerUserId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const validatedData = sellerTransferCoinsSchema.parse(req.body);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await sellerService.executeSellerRechargeTransfer(sellerUserId, validatedData, { ipAddress });

    return res.status(200).json({
      success: true,
      message: 'Coins recharged to recipient successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getPublicSellers,
  getSellerByIdAndVerify,
  getSellers,
  createSeller,
  getSellerById,
  updateSeller,
  updateSellerStatus,
  deleteSeller,
  allocateCoins,
  correctBalance,
  verifyRecipient,
  getMySellerPortal,
  transferCoins,
};

