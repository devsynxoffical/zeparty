import pkService from '../services/pk.service.js';

/**
 * 1. DISCOVER OPPONENTS
 * GET /v1/pk/discover?query=...&roomType=...
 */
export async function discoverOpponent(req, res, next) {
  try {
    const { query, roomType } = req.query;
    const callerUserId = req.auth?.userId || req.user?.id;

    if (!query) {
      return res.status(400).json({
        success: false,
        code: 'INVALID_QUERY',
        error: 'Query parameter (room ID or host ID) is required.',
      });
    }

    const opponent = await pkService.discoverOpponent({
      query,
      roomType,
      callerUserId,
    });

    if (!opponent) {
      return res.status(404).json({
        success: false,
        code: 'PK_ROOM_NOT_FOUND',
        error: 'No eligible opponent found matching the query.',
      });
    }

    return res.status(200).json({
      success: true,
      data: opponent,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 2. SEND INVITATION
 * POST /v1/pk/invitations
 */
export async function sendInvitation(req, res, next) {
  try {
    const { fromRoomId, targetRoomId, targetHostUserId, durationSeconds } = req.body;
    const callerUserId = req.auth?.userId || req.user?.id;

    if (!fromRoomId || !targetRoomId || !targetHostUserId) {
      return res.status(400).json({
        success: false,
        code: 'MISSING_PARAMETERS',
        error: 'fromRoomId, targetRoomId, and targetHostUserId are required.',
      });
    }

    const result = await pkService.sendInvitation({
      fromRoomId,
      targetRoomId,
      targetHostUserId,
      durationSeconds: Number(durationSeconds) || 300,
      callerUserId,
    });

    return res.status(201).json({
      success: true,
      data: result,
      message: 'PK Match invitation sent successfully.',
    });
  } catch (error) {
    if (error.code) {
      return res.status(error.status || 400).json({
        success: false,
        code: error.code,
        error: error.message,
      });
    }
    next(error);
  }
}

/**
 * 3. RESPOND TO INVITATION (ACCEPT / REJECT)
 * POST /v1/pk/invitations/:id/respond
 */
export async function respondInvitation(req, res, next) {
  try {
    const { id: invitationId } = req.params;
    const { action, targetRoomId } = req.body;
    const responderUserId = req.auth?.userId || req.user?.id;

    const result = await pkService.respondInvitation({
      invitationId,
      responderUserId,
      action: action || 'ACCEPT',
      targetRoomId,
    });

    return res.status(200).json({
      success: true,
      data: result,
      message: `Invitation ${action === 'REJECT' ? 'rejected' : 'accepted'} successfully.`,
    });
  } catch (error) {
    if (error.code) {
      return res.status(error.status || 400).json({
        success: false,
        code: error.code,
        error: error.message,
      });
    }
    next(error);
  }
}

/**
 * 4. CANCEL PENDING INVITATION
 * POST /v1/pk/invitations/:id/cancel
 */
export async function cancelInvitation(req, res, next) {
  try {
    const { id: invitationId } = req.params;
    const { reason = 'Cancelled by inviter' } = req.body;
    const callerUserId = req.auth?.userId || req.user?.id;

    const result = await pkService.cancelInvitation({
      invitationId,
      callerUserId,
      reason,
    });

    return res.status(200).json({
      success: true,
      data: result,
      message: 'Invitation cancelled.',
    });
  } catch (error) {
    if (error.code) {
      return res.status(error.status || 400).json({
        success: false,
        code: error.code,
        error: error.message,
      });
    }
    next(error);
  }
}

/**
 * 5. CONFIRM OPERATOR READINESS & PREPARATION
 * POST /v1/pk/matches/:id/ready
 */
export async function setOperatorReady(req, res, next) {
  try {
    const { id: matchId } = req.params;
    const { roomId, isReady = true, mediaPrepared = true } = req.body;
    const userId = req.auth?.userId || req.user?.id;

    const snapshot = await pkService.setOperatorReady({
      matchId,
      userId,
      roomId,
      isReady: Boolean(isReady),
      mediaPrepared: Boolean(mediaPrepared),
    });

    return res.status(200).json({
      success: true,
      data: snapshot,
    });
  } catch (error) {
    if (error.code) {
      return res.status(error.status || 400).json({
        success: false,
        code: error.code,
        error: error.message,
      });
    }
    next(error);
  }
}

/**
 * 6. GET AUTHORITATIVE MATCH SNAPSHOT
 * GET /v1/pk/matches/:id
 */
export async function getMatchSnapshot(req, res, next) {
  try {
    const { id: matchId } = req.params;
    const snapshot = await pkService.getMatchSnapshot(matchId);

    if (!snapshot) {
      return res.status(404).json({
        success: false,
        code: 'PK_MATCH_NOT_FOUND',
        error: 'PK Match session not found.',
      });
    }

    return res.status(200).json({
      success: true,
      data: snapshot,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 7. GET ACTIVE PK MATCH FOR ROOM
 * GET /v1/pk/rooms/:roomId/active
 */
export async function getActiveMatchForRoom(req, res, next) {
  try {
    const { roomId } = req.params;
    const active = await pkService.getActiveMatchForRoom(roomId);

    return res.status(200).json({
      success: true,
      data: active || null,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 8. GET TOP SUPPORTERS
 * GET /v1/pk/matches/:id/supporters
 */
export async function getTopSupporters(req, res, next) {
  try {
    const { id: matchId } = req.params;
    const supporters = await pkService.getTopSupporters(matchId);

    return res.status(200).json({
      success: true,
      data: {
        matchId,
        ...supporters,
      },
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 9. REQUEST REMATCH
 * POST /v1/pk/matches/:id/rematch
 */
export async function requestRematch(req, res, next) {
  try {
    const { id: matchId } = req.params;
    const callerUserId = req.auth?.userId || req.user?.id;

    const result = await pkService.requestRematch({
      matchId,
      callerUserId,
    });

    return res.status(201).json({
      success: true,
      data: result,
      message: 'Rematch invitation created.',
    });
  } catch (error) {
    if (error.code) {
      return res.status(error.status || 400).json({
        success: false,
        code: error.code,
        error: error.message,
      });
    }
    next(error);
  }
}

/**
 * 10. GET PK MATCH HISTORY
 * GET /v1/pk/history
 */
export async function getHistory(req, res, next) {
  try {
    const { page = 1, limit = 20, roomId } = req.query;
    const userId = req.auth?.userId || req.user?.id;

    const history = await pkService.getHistory({
      userId,
      roomId,
      page: Number(page),
      limit: Number(limit),
    });

    return res.status(200).json({
      success: true,
      data: history.matches,
      meta: {
        total: history.total,
        page: history.page,
        limit: history.limit,
      },
    });
  } catch (error) {
    next(error);
  }
}

// ── ADMIN CONTROLLERS ───────────────────────────────────────────

/**
 * 11. ADMIN: LIST MATCHES (LIVE MONITOR & HISTORY)
 * GET /v1/admin/pk/matches
 */
export async function listAdminMatches(req, res, next) {
  try {
    const { page = 1, limit = 20, status, roomType, search } = req.query;
    const result = await pkService.listAdminMatches({
      page: Number(page),
      limit: Number(limit),
      status,
      roomType,
      search,
    });

    return res.status(200).json({
      success: true,
      data: result.matches,
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

/**
 * 12. ADMIN: FORCE STOP MATCH
 * POST /v1/admin/pk/matches/:id/force-stop
 */
export async function adminForceStop(req, res, next) {
  try {
    const { id: matchId } = req.params;
    const { reason = 'Admin Force Stop' } = req.body;
    const adminUserId = req.auth?.userId || req.user?.id || 'admin';

    const result = await pkService.adminForceStop({
      matchId,
      adminUserId,
      reason,
    });

    return res.status(200).json({
      success: true,
      data: result,
      message: 'PK Match force-stopped by platform administration.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 13. ADMIN: GET PK SETTINGS
 * GET /v1/admin/pk/settings
 */
export async function getSettings(req, res, next) {
  try {
    const settings = await pkService.getSettings();
    return res.status(200).json({
      success: true,
      data: settings,
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 14. ADMIN: UPDATE PK SETTINGS
 * PUT /v1/admin/pk/settings
 */
export async function updateSettings(req, res, next) {
  try {
    const adminUserId = req.auth?.userId || req.user?.id || 'admin';
    const updated = await pkService.updateSettings(req.body, adminUserId);

    return res.status(200).json({
      success: true,
      data: updated,
      message: 'PK settings updated successfully.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 15. ADMIN: LIST RESTRICTIONS
 * GET /v1/admin/pk/restrictions
 */
export async function listRestrictions(req, res, next) {
  try {
    const { page = 1, limit = 20, status } = req.query;
    const result = await pkService.listRestrictions({
      page: Number(page),
      limit: Number(limit),
      status,
    });

    return res.status(200).json({
      success: true,
      data: result.restrictions,
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

/**
 * 16. ADMIN: CREATE RESTRICTION
 * POST /v1/admin/pk/restrictions
 */
export async function createRestriction(req, res, next) {
  try {
    const { targetType, targetId, reason, durationHours } = req.body;
    const adminUserId = req.auth?.userId || req.user?.id || 'admin';

    if (!targetType || !targetId || !reason) {
      return res.status(400).json({
        success: false,
        error: 'targetType, targetId, and reason are required.',
      });
    }

    const restriction = await pkService.createRestriction({
      targetType,
      targetId,
      reason,
      durationHours,
      restrictedByAdminId: adminUserId,
    });

    return res.status(201).json({
      success: true,
      data: restriction,
      message: 'PK restriction applied successfully.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 17. ADMIN: REVOKE RESTRICTION
 * DELETE /v1/admin/pk/restrictions/:id
 */
export async function revokeRestriction(req, res, next) {
  try {
    const { id } = req.params;
    const revoked = await pkService.revokeRestriction(id);

    return res.status(200).json({
      success: true,
      data: revoked,
      message: 'PK restriction revoked.',
    });
  } catch (error) {
    next(error);
  }
}

/**
 * 18. ADMIN: REVISE MATCH RESULT
 * POST /v1/admin/pk/matches/:id/revise-result
 */
export async function adminReviseResult(req, res, next) {
  try {
    const { id: matchId } = req.params;
    const { reason, revisedScoreA, revisedScoreB, revisedWinnerHostId, revisedIsDraw } = req.body;
    const adminUserId = req.auth?.userId || req.user?.id || 'admin';

    if (!reason || revisedScoreA === undefined || revisedScoreB === undefined) {
      return res.status(400).json({
        success: false,
        error: 'reason, revisedScoreA, and revisedScoreB are required.',
      });
    }

    const revised = await pkService.adminReviseResult({
      matchId,
      adminUserId,
      reason,
      revisedScoreA,
      revisedScoreB,
      revisedWinnerHostId,
      revisedIsDraw,
    });

    return res.status(200).json({
      success: true,
      data: revised,
      message: 'PK match result revised and audited.',
    });
  } catch (error) {
    next(error);
  }
}

// ── BACKWARD-COMPATIBLE ALIASES ──────────────────────────────────
export const createPKSession = sendInvitation;
export const sendPKInvite = sendInvitation;
export const getInvitationDetails = getMatchSnapshot;
export const respondPKInvite = respondInvitation;
export const joinByInviteCode = (req, res) => res.status(400).json({ success: false, error: 'Legacy code join discontinued in PK 2.0.' });
export const startPKBattle = setOperatorReady;
export const getPKSession = getMatchSnapshot;
export const getRoomPKStatus = getActiveMatchForRoom;
export const endPKBattle = (req, res, next) => adminForceStop(req, res, next);
export const getAvailablePKHosts = discoverOpponent;
export const listAdminPKEvents = listAdminMatches;

export default {
  discoverOpponent,
  sendInvitation,
  respondInvitation,
  cancelInvitation,
  setOperatorReady,
  getMatchSnapshot,
  getActiveMatchForRoom,
  getTopSupporters,
  requestRematch,
  getHistory,
  listAdminMatches,
  adminForceStop,
  getSettings,
  updateSettings,
  listRestrictions,
  createRestriction,
  revokeRestriction,
  adminReviseResult,
  // Aliases
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
