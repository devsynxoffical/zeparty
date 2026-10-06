import pkService from '../services/pk.service.js';

/**
 * 1. Create a new PK Battle Session (Host-Only)
 */
export async function createPKSession(req, res, next) {
  try {
    const { roomId, durationSeconds, hostInfo } = req.body;
    const hostUserId = req.auth?.userId;

    const session = await pkService.createPKSession({
      hostUserId,
      roomId,
      durationSeconds: Number(durationSeconds) || 300,
      hostInfo: hostInfo || {},
    });

    return res.status(201).json({
      success: true,
      data: session,
      message: 'PK Battle session created. Waiting for participants to join.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 2. Send PK Invitation to another Host or User
 */
export async function sendPKInvite(req, res, next) {
  try {
    const { pkId, fromRoomId, targetRoomId, targetUserId, durationSeconds, fromHostInfo } = req.body;
    const fromHostUserId = req.auth?.userId;

    const result = await pkService.sendPKInvite({
      pkId,
      fromHostUserId,
      fromRoomId,
      targetRoomId,
      targetUserId,
      durationSeconds: Number(durationSeconds) || 300,
      fromHostInfo: fromHostInfo || {},
    });

    return res.status(200).json({
      success: true,
      data: result,
      message: 'PK Battle invitation sent successfully.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 3. Get / Validate Invitation Details by invitationId
 */
export async function getInvitationDetails(req, res, next) {
  try {
    const { id: invitationId } = req.params;
    const details = await pkService.getInvitationDetails(invitationId);

    return res.status(200).json({
      success: true,
      data: details,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 4. Respond to PK Invitation (Accept / Decline)
 */
export async function respondPKInvite(req, res, next) {
  try {
    const { id: invitationId } = req.params;
    const { action, roomId, userInfo } = req.body; // action: 'ACCEPT' | 'DECLINE'
    const responderUserId = req.auth?.userId;

    const result = await pkService.respondPKInvite({
      invitationId,
      responderUserId,
      responderRoomId: roomId,
      responderInfo: userInfo || {},
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

/**
 * 5. Join PK Battle by Invite Code / Link
 */
export async function joinByInviteCode(req, res, next) {
  try {
    const { inviteCode, roomId, userInfo } = req.body;
    const userId = req.auth?.userId;

    const session = await pkService.joinByInviteCode({
      inviteCode,
      userId,
      userInfo: userInfo || {},
      roomId,
    });

    return res.status(200).json({
      success: true,
      data: session,
      message: 'Joined PK Battle session successfully.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 6. Explicitly Start PK Battle (Sets Authoritative Timer & Started State)
 */
export async function startPKBattle(req, res, next) {
  try {
    const { id: pkId } = req.params;
    const hostUserId = req.auth?.userId;

    const session = await pkService.startPKBattle({
      pkId,
      hostUserId,
    });

    return res.status(200).json({
      success: true,
      data: session,
      message: 'PK Battle started! Timer is now active.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 7. Get Authoritative PK Session by ID (For Reconnect & State Recovery)
 */
export async function getPKSession(req, res, next) {
  try {
    const { id: pkId } = req.params;
    const session = await pkService.getPKSession(pkId);

    if (!session) {
      return res.status(404).json({
        success: false,
        message: 'PK Battle session not found.',
      });
    }

    return res.status(200).json({
      success: true,
      data: session,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 8. Get Active PK for a Live Room (Spectator & Participant View)
 */
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

/**
 * 9. End PK Battle
 */
export async function endPKBattle(req, res, next) {
  try {
    const { id: pkId } = req.params;
    const session = await pkService.endPKBattle(pkId);

    return res.status(200).json({
      success: true,
      data: session,
      message: 'PK Battle concluded successfully.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 10. Discover Available Live Hosts for Host vs Host Battle
 */
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

/**
 * 11. List PK Events for Admin Oversight
 */
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
  createPKSession,
  sendPKInvite,
  getInvitationDetails,
  respondPKInvite,
  joinByInviteCode,
  startPKBattle,
  getPKSession,
  getRoomPKStatus,
  endPKBattle,
  getAvailablePKHosts,
  listAdminPKEvents,
};
