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
    const preview = await exchangeTransferService.previewRateCalculation({ type, amount, countryCode });
    return res.status(200).json({
      success: true,
      message: 'Preview calculation computed successfully',
      data: preview,
    });
  } catch (err) {
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

export default {
  getAdminExchangeTransferControl,
  postAdminPreviewCalculation,
  postAdminPublishConfiguration,
  postAdminRollbackConfiguration,
  getUserExchangeTransferStatus,
};
