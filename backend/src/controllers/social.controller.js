import socialService from '../services/social.service.js';
import {
  userIdParamSchema,
  privacySettingsSchema,
} from '../validators/post.validator.js';

// ============================================================
// SOCIAL CONTROLLER (PROFILES, PRIVACY, FOLLOWS, BLOCKS)
// ============================================================

export async function getSocialProfile(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const viewerUserId = req.auth?.userId || null;

    const profile = await socialService.getSocialProfile(id, viewerUserId);

    return res.status(200).json({
      success: true,
      message: 'Social profile retrieved successfully',
      data: profile,
    });
  } catch (err) {
    next(err);
  }
}

export async function putPrivacySettings(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      const error = new Error('User authentication is required');
      error.statusCode = 401;
      error.code = 'UNAUTHORIZED';
      throw error;
    }

    const validatedData = privacySettingsSchema.parse(req.body);
    const result = await socialService.updatePrivacySettings(userId, validatedData);
    const isPrivate = Boolean(result?.isPrivate);

    return res.status(200).json({
      success: true,
      message: `Privacy settings updated successfully (${isPrivate ? 'PRIVATE' : 'PUBLIC'})`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postFollow(req, res, next) {
  try {
    const { id: followingId } = userIdParamSchema.parse(req.params);
    const followerId = req.auth?.userId;

    const result = await socialService.followUser(followerId, followingId);

    return res.status(200).json({
      success: true,
      message: result.alreadyFollowing ? 'Already following user' : 'User followed successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteFollow(req, res, next) {
  try {
    const { id: followingId } = userIdParamSchema.parse(req.params);
    const followerId = req.auth?.userId;

    const result = await socialService.unfollowUser(followerId, followingId);

    return res.status(200).json({
      success: true,
      message: result.alreadyUnfollowed ? 'Already unfollowed user' : 'User unfollowed successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getFollowers(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const viewerUserId = req.auth?.userId || null;
    const page = req.query.page || 1;
    const limit = req.query.limit || 20;

    const result = await socialService.getFollowers(id, { viewerUserId, page, limit });

    return res.status(200).json({
      success: true,
      message: result.message || 'Followers retrieved successfully',
      data: result.followers,
      followers: result.followers,
      isPrivate: result.isPrivate ?? false,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getFollowing(req, res, next) {
  try {
    const { id } = userIdParamSchema.parse(req.params);
    const viewerUserId = req.auth?.userId || null;
    const page = req.query.page || 1;
    const limit = req.query.limit || 20;

    const result = await socialService.getFollowing(id, { viewerUserId, page, limit });

    return res.status(200).json({
      success: true,
      message: result.message || 'Following list retrieved successfully',
      data: result.following,
      following: result.following,
      isPrivate: result.isPrivate ?? false,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function postBlock(req, res, next) {
  try {
    const { id: blockedId } = userIdParamSchema.parse(req.params);
    const blockerId = req.auth?.userId;

    const result = await socialService.blockUser(blockerId, blockedId);

    return res.status(200).json({
      success: true,
      message: result.message,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteBlock(req, res, next) {
  try {
    const { id: blockedId } = userIdParamSchema.parse(req.params);
    const blockerId = req.auth?.userId;

    const result = await socialService.unblockUser(blockerId, blockedId);

    return res.status(200).json({
      success: true,
      message: result.message,
    });
  } catch (err) {
    next(err);
  }
}

export async function getBlockedUsers(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const blockedUsers = await socialService.getBlockedUsers(userId);

    return res.status(200).json({
      success: true,
      message: 'Blocked users retrieved successfully',
      data: blockedUsers,
    });
  } catch (err) {
    next(err);
  }
}

export async function recordProfileVisit(req, res, next) {
  try {
    const visitedId = req.params.id || req.body?.visitedId;
    const visitorId = req.auth?.userId;
    const isMystery = Boolean(req.body?.isMystery);

    if (!visitedId) {
      return res.status(400).json({ success: false, message: 'Visited user ID is required' });
    }

    if (visitorId && visitorId !== visitedId) {
      await socialService.recordProfileVisit({ visitorId, visitedId, isMystery });
    }

    return res.status(200).json({
      success: true,
      message: 'Profile visit recorded',
    });
  } catch (err) {
    next(err);
  }
}

export async function getProfileVisitors(req, res, next) {
  try {
    const authenticatedUserId = req.auth?.userId;
    if (!authenticatedUserId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to view visitor history',
        code: 'UNAUTHORIZED',
        error: { code: 'UNAUTHORIZED', statusCode: 401 },
      });
    }

    const requestedId = req.params.id || req.params.userId || req.query.userId || req.query.targetUserId;
    if (requestedId && requestedId !== 'me' && requestedId !== authenticatedUserId) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You are not authorized to view another user's visitor history",
        code: 'FORBIDDEN',
        error: { code: 'FORBIDDEN', statusCode: 403 },
      });
    }

    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 50));
    const result = await socialService.getProfileVisitors(authenticatedUserId, {
      page,
      limit,
      viewerUserId: authenticatedUserId,
    });

    res.setHeader('Cache-Control', 'private, no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    return res.status(200).json({
      success: true,
      message: 'Profile visitors retrieved successfully',
      data: result.data || [],
      visitors: result.visitors || result.data || [],
      pagination: result.pagination || { page, limit, total: result.data?.length || 0, totalPages: 1, hasMore: false },
    });
  } catch (err) {
    next(err);
  }
}

export async function getProfileVisited(req, res, next) {
  try {
    const authenticatedUserId = req.auth?.userId;
    if (!authenticatedUserId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to view visited profiles',
        code: 'UNAUTHORIZED',
        error: { code: 'UNAUTHORIZED', statusCode: 401 },
      });
    }

    const requestedId = req.params.id || req.params.userId || req.query.userId || req.query.targetUserId;
    if (requestedId && requestedId !== 'me' && requestedId !== authenticatedUserId) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You are not authorized to view another user's visited profiles",
        code: 'FORBIDDEN',
        error: { code: 'FORBIDDEN', statusCode: 403 },
      });
    }

    const page = Math.max(1, Number(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 50));
    const result = await socialService.getProfileVisited(authenticatedUserId, {
      page,
      limit,
      viewerUserId: authenticatedUserId,
    });

    res.setHeader('Cache-Control', 'private, no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');

    return res.status(200).json({
      success: true,
      message: 'Visited profiles retrieved successfully',
      data: result.data || [],
      visited: result.visited || result.data || [],
      pagination: result.pagination || { page, limit, total: result.data?.length || 0, totalPages: 1, hasMore: false },
    });
  } catch (err) {
    next(err);
  }
}

export async function getRelationship(req, res, next) {
  try {
    const targetUserId = req.params.userId || req.auth?.userId;
    const rel = await socialService.getRelationship(targetUserId);

    return res.status(200).json({
      success: true,
      data: rel,
    });
  } catch (err) {
    next(err);
  }
}

export async function requestRelationship(req, res, next) {
  try {
    const requesterId = req.auth?.userId;
    const { targetUserId, relationType, message } = req.body;
    const result = await socialService.requestRelationship({
      requesterId,
      targetUserId,
      relationType,
      message,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function respondRelationship(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const targetUserId = req.body.targetUserId || req.body.requesterId;
    const accept = req.body.accept !== undefined ? req.body.accept : (req.body.action === 'ACCEPT' || req.body.status === 'ACCEPT');
    const result = await socialService.respondRelationship({
      userId,
      targetUserId,
      accept,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function dissolveRelationship(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { reason } = req.body;
    const result = await socialService.dissolveRelationship({ userId, reason });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getRelationshipCards(req, res, next) {
  try {
    const cards = await socialService.getRelationshipCardCatalog();
    return res.status(200).json({ success: true, data: cards });
  } catch (err) {
    next(err);
  }
}

export async function purchaseAndSendRelationshipCard(req, res, next) {
  try {
    const senderUserId = req.auth?.userId;
    const { recipientUserId, cardType, deductCoins } = req.body;
    const result = await socialService.purchaseAndSendRelationshipCard({
      senderUserId,
      recipientUserId,
      cardType,
      deductCoins: deductCoins !== false,
    });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getCpPairRankings(req, res, next) {
  try {
    const { period } = req.query;
    const result = await socialService.getCpPairRankings({ period });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export default {
  getSocialProfile,
  putPrivacySettings,
  postFollow,
  deleteFollow,
  getFollowers,
  getFollowing,
  postBlock,
  deleteBlock,
  getBlockedUsers,
  recordProfileVisit,
  getProfileVisitors,
  getProfileVisited,
  getRelationship,
  requestRelationship,
  respondRelationship,
  dissolveRelationship,
  getRelationshipCards,
  purchaseAndSendRelationshipCard,
  getCpPairRankings,
};
