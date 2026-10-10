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
    const validatedData = privacySettingsSchema.parse(req.body);
    const isPrivate = validatedData.isPrivate !== undefined
      ? validatedData.isPrivate
      : (validatedData.hideFollowList !== undefined ? validatedData.hideFollowList : false);

    const result = await socialService.updatePrivacySettings(userId, isPrivate);

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
    const { id: visitedId } = userIdParamSchema.parse(req.params);
    const visitorId = req.auth?.userId;
    const isMystery = Boolean(req.body?.isMystery);

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
    const userId = req.auth?.userId;
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 50));
    const visitors = await socialService.getProfileVisitors(userId, { limit });

    return res.status(200).json({
      success: true,
      message: 'Profile visitors retrieved successfully',
      data: visitors,
    });
  } catch (err) {
    next(err);
  }
}

export async function getProfileVisited(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const limit = Math.min(100, Math.max(1, Number(req.query.limit) || 50));
    const visited = await socialService.getProfileVisited(userId, { limit });

    return res.status(200).json({
      success: true,
      message: 'Visited profiles retrieved successfully',
      data: visited,
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
