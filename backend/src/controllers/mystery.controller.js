import mysteryService from '../services/mystery.service.js';

export async function getMysteryStatus(req, res, next) {
  try {
    const userId = req.auth.userId;
    const status = await mysteryService.getMysteryStatus({ userId });
    return res.status(200).json({
      success: true,
      data: status,
    });
  } catch (err) {
    next(err);
  }
}

export async function purchaseMysterySuit(req, res, next) {
  try {
    const userId = req.auth.userId;
    const isDukeFreeClaim = Boolean(req.body?.isDukeFreeClaim);
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await mysteryService.purchaseMysterySuit({
      userId,
      isDukeFreeClaim,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Mystery Suit activated successfully!',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getMysteryStatus,
  purchaseMysterySuit,
};
