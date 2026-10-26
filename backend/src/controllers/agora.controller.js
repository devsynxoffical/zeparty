import agoraService from '../services/agora.service.js';

export async function getAgoraToken(req, res, next) {
  try {
    const { id: roomId } = req.params;
    const userId = req.auth.userId;
    const attemptId = req.body?.attemptId || req.headers['x-attempt-id'] || null;

    const result = await agoraService.issueRoomAgoraToken({ roomId, userId });

    return res.status(200).json({
      success: true,
      message: 'Agora RTC token generated successfully.',
      attemptId,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postRefreshAgoraToken(req, res, next) {
  try {
    const { id: roomId } = req.params;
    const userId = req.auth.userId;
    const attemptId = req.body?.attemptId || req.headers['x-attempt-id'] || null;

    const result = await agoraService.refreshRoomAgoraToken({ roomId, userId });

    return res.status(200).json({
      success: true,
      message: 'Agora RTC token refreshed successfully.',
      attemptId,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export default {
  getAgoraToken,
  postRefreshAgoraToken,
};
