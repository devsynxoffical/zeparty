import pkService from '../services/pk.service.js';

export async function startPK(req, res, next) {
  try {
    const { roomAId, roomBId, hostAUserId, hostBUserId, durationSeconds } = req.body;
    const pkEvent = await pkService.startPK({
      roomAId,
      roomBId,
      hostAUserId: hostAUserId || req.auth?.userId,
      hostBUserId,
      durationSeconds: Number(durationSeconds) || 300,
    });

    return res.status(201).json({
      success: true,
      data: pkEvent,
      message: 'PK battle initiated successfully in countdown state.',
    });
  } catch (error) {
    next(error);
  }
}

export async function activatePK(req, res, next) {
  try {
    const { id } = req.params;
    const updated = await pkService.activatePK(id);

    return res.status(200).json({
      success: true,
      data: updated,
      message: 'PK battle activated.',
    });
  } catch (error) {
    next(error);
  }
}

export async function getRoomPKStatus(req, res, next) {
  try {
    const { roomId } = req.params;
    const activePK = await pkService.getRoomPKStatus(roomId);

    return res.status(200).json({
      success: true,
      data: activePK,
    });
  } catch (error) {
    next(error);
  }
}

export async function endPK(req, res, next) {
  try {
    const { id } = req.params;
    const pkEvent = await pkService.endPK(id);

    return res.status(200).json({
      success: true,
      data: pkEvent,
      message: 'PK battle concluded successfully.',
    });
  } catch (error) {
    next(error);
  }
}

export async function joinMatchmaking(req, res, next) {
  try {
    const { roomId, region, hostInfo } = req.body;
    const hostUserId = req.auth?.userId;

    const result = await pkService.joinMatchmaking({
      roomId,
      hostUserId,
      region: region || 'GLOBAL',
      hostInfo: hostInfo || {},
    });

    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

export async function leaveMatchmaking(req, res, next) {
  try {
    const { roomId } = req.body;
    const result = await pkService.leaveMatchmaking(roomId);

    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

export async function sendPKInvite(req, res, next) {
  try {
    const { fromRoomId, targetRoomId, targetUserId, durationSeconds, fromHostInfo } = req.body;
    const fromHostUserId = req.auth?.userId;

    const result = await pkService.sendPKInvite({
      fromRoomId,
      fromHostUserId,
      targetRoomId,
      targetUserId,
      durationSeconds: Number(durationSeconds) || 300,
      fromHostInfo: fromHostInfo || {},
    });

    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

export async function respondPKInvite(req, res, next) {
  try {
    const { id: invitationId } = req.params;
    const { action, roomId } = req.body; // action: 'ACCEPT' | 'DECLINE'
    const responderUserId = req.auth?.userId;

    const result = await pkService.respondPKInvite({
      invitationId,
      responderUserId,
      responderRoomId: roomId,
      action: action || 'ACCEPT',
    });

    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
}

export async function getAvailablePKHosts(req, res, next) {
  try {
    const { excludeRoomId } = req.query;
    const currentUserId = req.auth?.userId;

    const hosts = await pkService.getAvailablePKHosts({
      excludeRoomId,
      excludeUserId: currentUserId,
    });

    return res.status(200).json({
      success: true,
      data: hosts,
    });
  } catch (error) {
    next(error);
  }
}

export async function listAdminPKEvents(req, res, next) {
  try {
    const { page = 1, limit = 20, status } = req.query;
    const result = await pkService.listAdminPKEvents({ page, limit, status });

    return res.status(200).json({
      success: true,
      data: result.events,
      meta: {
        total: result.total,
        page: result.page,
        limit: result.limit,
      },
    });
  } catch (error) {
    next(error);
  }
}

export default {
  startPK,
  activatePK,
  getRoomPKStatus,
  endPK,
  joinMatchmaking,
  leaveMatchmaking,
  sendPKInvite,
  respondPKInvite,
  getAvailablePKHosts,
  listAdminPKEvents,
};
