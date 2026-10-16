import exchangeTransferService from '../services/exchangeTransfer.service.js';

export async function getAdminExchangeTransferControl(req, res, next) {
  try {
    const data = await exchangeTransferService.getAdminControlState();
    return res.status(200).json({
      success: true,
      message: 'Exchange and transfer rate control state retrieved successfully',
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminPreviewCalculation(req, res, next) {
  try {
    const { type, amount, countryCode } = req.body;
    const normalizedType = String(type || '').toUpperCase();
    if (
      normalizedType === 'EXCHANGE' ||
      normalizedType === 'COINS_TO_DIAMONDS' ||
      normalizedType === 'DIAMONDS_TO_COINS'
    ) {
      return res.status(400).json({
        success: false,
        message: 'Coin and Diamond exchange is strictly prohibited. Diamonds are for display within ZeParty only.',
        error: {
          code: 'EXCHANGE_PROHIBITED',
        },
      });
    }

    const preview = await exchangeTransferService.previewRateCalculation({ type, amount, countryCode });
    return res.status(200).json({
      success: true,
      message: 'Preview calculation computed successfully',
      data: preview,
    });
  } catch (err) {
    if (err.code === 'EXCHANGE_PROHIBITED' || err.statusCode === 400) {
      return res.status(400).json({
        success: false,
        message: err.message,
        error: { code: err.code || 'EXCHANGE_PROHIBITED' },
      });
    }
    next(err);
  }
}

export async function postAdminPublishConfiguration(req, res, next) {
  try {
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await exchangeTransferService.publishConfiguration(req.body, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Exchange and transfer rate policy published successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminRollbackConfiguration(req, res, next) {
  try {
    const { targetVersion, reason } = req.body;
    const adminId = req.auth?.userId || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    if (!targetVersion) {
      return res.status(400).json({
        success: false,
        message: 'targetVersion is required for rollback',
      });
    }

    const result = await exchangeTransferService.rollbackConfiguration(targetVersion, {
      adminId,
      adminName,
      ipAddress,
      reason,
    });

    return res.status(200).json({
      success: true,
      message: `Configuration successfully rolled back to ${targetVersion}`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getUserExchangeTransferStatus(req, res, next) {
  try {
    const userCountryCode = req.user?.countryCode || req.query.countryCode || 'GLOBAL';
    const userId = req.auth?.userId;

    const result = await exchangeTransferService.getUserExchangeTransferStatus({
      userCountryCode,
      userId,
    });

    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postUserExecuteConversion(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const { type, amount } = req.body;
    const numAmount = Number(amount);
    if (!numAmount || numAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid amount is required for conversion',
      });
    }

    const normalizedType = String(type || '').toUpperCase();
    if (
      normalizedType === 'EXCHANGE' ||
      normalizedType === 'COINS_TO_DIAMONDS' ||
      normalizedType === 'DIAMONDS_TO_COINS' ||
      normalizedType.includes('COIN') ||
      normalizedType.includes('DIAMOND')
    ) {
      return res.status(400).json({
        success: false,
        message: 'Coin and Diamond exchange is strictly prohibited. Diamonds are for display within ZeParty only.',
        error: {
          code: 'EXCHANGE_PROHIBITED',
        },
      });
    }

    const result = await exchangeTransferService.previewRateCalculation({ type, amount: numAmount });
    
    return res.status(200).json({
      success: true,
      message: `Conversion calculation processed successfully for ${numAmount}`,
      data: result,
    });
  } catch (err) {
    if (err.code === 'EXCHANGE_PROHIBITED' || err.statusCode === 400) {
      return res.status(400).json({
        success: false,
        message: err.message,
        error: { code: err.code || 'EXCHANGE_PROHIBITED' },
      });
    }
    next(err);
  }
}

export default {
  getAdminExchangeTransferControl,
  postAdminPreviewCalculation,
  postAdminPublishConfiguration,
  postAdminRollbackConfiguration,
  getUserExchangeTransferStatus,
  postUserExecuteConversion,
};
