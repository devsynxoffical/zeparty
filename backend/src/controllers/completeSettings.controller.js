import completeSettingsService from '../services/completeSettings.service.js';

export async function getAllCompleteSettings(req, res, next) {
  try {
    const data = await completeSettingsService.getAllCompleteSettings();
    return res.status(200).json({
      success: true,
      message: 'All complete settings retrieved successfully',
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function getSettingsByCategory(req, res, next) {
  try {
    const { category } = req.params;
    const data = await completeSettingsService.getSettingsByCategory(category);
    return res.status(200).json({
      success: true,
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateSingleSetting(req, res, next) {
  try {
    const { key } = req.params;
    const { value, isEnabled, applyFromDate, reason } = req.body;
    const adminId = req.auth?.userId || req.admin?.id || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await completeSettingsService.updateSingleSetting(
      key,
      { value, isEnabled, applyFromDate, reason },
      { adminId, adminName, ipAddress }
    );

    return res.status(200).json({
      success: true,
      message: `Setting ${key} updated successfully`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function batchUpdateSettings(req, res, next) {
  try {
    const { settings, applyFromDate, version, reason } = req.body;
    const adminId = req.auth?.userId || req.admin?.id || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await completeSettingsService.batchUpdateSettings(
      settings || [],
      { applyFromDate, version, reason },
      { adminId, adminName, ipAddress }
    );

    return res.status(200).json({
      success: true,
      message: 'Batch settings updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function publishNewPolicyVersion(req, res, next) {
  try {
    const { version, applyFromDate, description } = req.body;
    const adminId = req.auth?.userId || req.admin?.id || 'ADMIN';
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await completeSettingsService.publishNewPolicyVersion(
      { version, applyFromDate, description },
      { adminId, adminName, ipAddress }
    );

    return res.status(200).json({
      success: true,
      message: `Policy version ${version} published successfully`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getPolicyVersionHistory(req, res, next) {
  try {
    const data = await completeSettingsService.getPolicyVersionHistory();
    return res.status(200).json({
      success: true,
      data,
    });
  } catch (err) {
    next(err);
  }
}

export async function calculateHostEarningsPreview(req, res, next) {
  try {
    const { hostType, diamonds, daysCompleted, validHours } = req.body;
    const data = await completeSettingsService.calculateHostEarningsPreview(
      hostType,
      diamonds,
      daysCompleted,
      validHours
    );
    return res.status(200).json({
      success: true,
      data,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getAllCompleteSettings,
  getSettingsByCategory,
  updateSingleSetting,
  batchUpdateSettings,
  publishNewPolicyVersion,
  getPolicyVersionHistory,
  calculateHostEarningsPreview,
};
