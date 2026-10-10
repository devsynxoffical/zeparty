import prisma from '../config/database.js';
import postRepository from '../repositories/post.repository.js';
import socialRepository from '../repositories/social.repository.js';
import userRepository from '../repositories/user.repository.js';
import storageService from './storage.service.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';
import * as notificationService from './notification.service.js';

/**
 * Social & Engagement Service
 * Master coordinator for Posts, Feeds, Likes, Comments, Follows, Blocks, Privacy, and Reporting.
 */

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || null,
        adminName: adminName || (adminId ? 'Administrator' : 'System Automation'),
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson || null,
        afterStateJson: afterStateJson || null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in social.service:', err);
  }
}

// ============================================================
// 1. POSTS & FEED
// ============================================================

export async function createPost(
  { userId, content, mediaUrls = [], visibility = 'PUBLIC' },
  db = prisma
) {
  if (!userId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  // Create post record
  const post = await postRepository.createPost(
    {
      userId,
      content,
      mediaUrls,
      visibility,
    },
    db
  );

  // Increment user profile posts count
  await socialRepository.incrementPostsCount(userId, db);

  // Emit post:created realtime event strictly after creation
  if (visibility === 'PUBLIC') {
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.POST_CREATED, {
      postId: post.id,
      authorId: userId,
      authorUsername: post.user?.username,
      content: post.content,
      createdAt: post.createdAt,
    });
  } else {
    // For followers/private, notify specific user/author
    socketEmitter.emitToUser(userId, SOCKET_EVENTS.POST_CREATED, {
      postId: post.id,
      authorId: userId,
      visibility,
      createdAt: post.createdAt,
    });
  }

  return post;
}

export async function getPostById(postId, viewerUserId = null, { isAdmin = false } = {}, db = prisma) {
  const post = await postRepository.findPostById(postId, viewerUserId, db);
  if (!post) {
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  // If Admin, full access
  if (isAdmin) {
    return post;
  }

  // Check block relationship
  if (viewerUserId && post.userId !== viewerUserId) {
    const blocked = await socialRepository.isBlocked(viewerUserId, post.userId, db);
    if (blocked) {
      const error = new Error('Post not found');
      error.statusCode = 404;
      error.code = 'POST_NOT_FOUND';
      throw error;
    }
  }

  // Check visibility for non-authors
  if (post.userId !== viewerUserId) {
    if (post.visibility === 'PRIVATE') {
      const error = new Error('This post is private');
      error.statusCode = 403;
      error.code = 'FORBIDDEN_PRIVATE_POST';
      throw error;
    }

    if (post.visibility === 'FOLLOWERS') {
      if (!viewerUserId) {
        const error = new Error('Authentication required to view followers-only post');
        error.statusCode = 401;
        error.code = 'UNAUTHORIZED';
        throw error;
      }

      const follow = await socialRepository.findFollow({ followerId: viewerUserId, followingId: post.userId }, db);
      if (!follow || follow.status !== 'ACCEPTED') {
        const error = new Error('Only followers can view this post');
        error.statusCode = 403;
        error.code = 'FORBIDDEN_FOLLOWERS_ONLY';
        throw error;
      }
    }

    // Check if author profile is private
    if (post.user?.profile?.isPrivate) {
      if (!viewerUserId) {
        const error = new Error('Post not found');
        error.statusCode = 404;
        error.code = 'POST_NOT_FOUND';
        throw error;
      }
      const follow = await socialRepository.findFollow({ followerId: viewerUserId, followingId: post.userId }, db);
      if (!follow || follow.status !== 'ACCEPTED') {
        const error = new Error('Post not found');
        error.statusCode = 404;
        error.code = 'POST_NOT_FOUND';
        throw error;
      }
    }
  }

  // Attach isLiked flag if viewerUserId provided
  let isLiked = false;
  if (viewerUserId) {
    isLiked = await socialRepository.isPostLikedByUser(postId, viewerUserId, db);
  }

  return {
    ...post,
    isLiked,
  };
}

export async function getFeed(
  {
    viewerUserId = null,
    feedType = 'PUBLIC',
    authorUserId = null,
    userId = null,
    cursor = null,
    limit = 20,
    page = null,
  } = {},
  db = prisma
) {
  const targetAuthorId = authorUserId || userId || null;
  let followingUserIds = [];
  let blockedUserIds = [];

  if (viewerUserId) {
    [followingUserIds, blockedUserIds] = await Promise.all([
      socialRepository.findFollowingUserIds(viewerUserId, db),
      socialRepository.findBlockedUserIds(viewerUserId, db),
    ]);
  }

  // If requesting posts of a specific target author, verify privacy
  if (targetAuthorId && targetAuthorId !== viewerUserId) {
    const authorProfile = await socialRepository.findSocialProfile(targetAuthorId, db);
    if (!authorProfile) {
      const error = new Error('User not found');
      error.statusCode = 404;
      error.code = 'USER_NOT_FOUND';
      throw error;
    }

    if (authorProfile.profile?.isPrivate) {
      const isFollowing = followingUserIds.includes(targetAuthorId);
      if (!isFollowing) {
        return {
          posts: [],
          meta: { limit, hasMore: false, nextCursor: null, isPrivateProfile: true },
          pagination: page ? { page: 1, limit, total: 0, totalPages: 0 } : undefined,
        };
      }
    }
  }

  const result = await postRepository.findFeedPosts(
    {
      viewerUserId,
      feedType,
      authorUserId: targetAuthorId,
      followingUserIds,
      blockedUserIds,
      cursor,
      limit,
      page,
    },
    db
  );

  return result;
}

export async function deletePost(
  postId,
  userId,
  { isAdmin = false, adminId = null, adminName = null, reason = null, ipAddress = '127.0.0.1' } = {},
  db = prisma
) {
  let post = await postRepository.findPostById(postId, userId, db).catch(() => null);
  if (!post) {
    post = await db.post.findUnique({ where: { id: postId } }).catch(() => null);
  }

  if (!post) {
    if (isAdmin) {
      return { success: true, id: postId, message: 'Post already deleted' };
    }
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  if (post.userId !== userId && !isAdmin) {
    const error = new Error('Unauthorized to delete this post');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // 1. Storage media cleanup: remove physical files from local disk and S3/R2 cloud storage
  try {
    const rawMedia = post.mediaUrls;
    const mediaList = Array.isArray(rawMedia)
      ? rawMedia
      : (typeof rawMedia === 'string'
          ? (() => {
              try { return JSON.parse(rawMedia); } catch (_) { return [rawMedia]; }
            })()
          : []);

    for (const url of mediaList) {
      if (url && typeof url === 'string') {
        await storageService.deleteFile(url).catch(() => {});
      }
    }
    if (post.mediaUrl && typeof post.mediaUrl === 'string') {
      await storageService.deleteFile(post.mediaUrl).catch(() => {});
    }
  } catch (mediaErr) {
    console.warn('[deletePost] Storage media cleanup notice:', mediaErr.message);
  }

  // 2. Database cleanup: permanently hard delete post record so it never comes back on page refresh
  try {
    await db.post.delete({ where: { id: postId } });
  } catch (err) {
    try {
      await db.post.deleteMany({ where: { id: postId } });
    } catch (_) {
      await postRepository.softDeletePost(postId, db).catch(() => {});
    }
  }

  // 3. Decrement user's postsCount
  if (post.userId) {
    await socialRepository.decrementPostsCount(post.userId, db).catch(() => {});
  }

  // 4. Audit logging
  if (isAdmin) {
    await logAudit(
      {
        adminId,
        adminName,
        action: 'ADMIN_DELETE_POST',
        targetEntity: 'Post',
        targetEntityId: postId,
        beforeStateJson: { id: post.id, userId: post.userId, content: post.content },
        reason,
        ipAddress,
      },
      db
    ).catch(() => {});
  }

  // 5. Global real-time socket broadcast
  try {
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.POST_DELETED, {
      postId,
      deletedBy: userId || adminId,
    });
  } catch (_) {}

  return { success: true, id: postId };
}

// ============================================================
// 2. LIKES & REACTIONS
// ============================================================

export async function likePost(postId, userId, db = prisma) {
  if (!userId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const post = await postRepository.findPostById(postId, userId, db);
  if (!post) {
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  const existing = await socialRepository.findLike({ postId, userId }, db);
  if (existing) {
    // Idempotent return
    return { success: true, alreadyLiked: true, likesCount: post.likesCount };
  }

  try {
    await socialRepository.createLike({ postId, userId }, db);
    const updatedPost = await postRepository.incrementLikesCount(postId, db);

    const payload = {
      postId,
      likedByUserId: userId,
      likesCount: updatedPost.likesCount,
    };
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.POST_LIKED, payload);
    socketEmitter.emitToUser(post.userId, SOCKET_EVENTS.POST_LIKED, payload);

    // Dispatch In-App Notification to Post Author (if not self-like)
    if (post.userId && post.userId !== userId) {
      try {
        const liker = await userRepository.findUserById(userId, db);
        const likerName = liker?.profile?.displayName || liker?.username || 'Someone';
        await notificationService.sendNotification({
          recipientId: post.userId,
          title: 'New Like',
          body: `@${liker?.username || likerName} liked your post.`,
          type: 'SOCIAL',
          category: 'Post',
          data: {
            postId,
            likedByUserId: userId,
            action: 'POST_LIKED',
          },
          sourceType: 'POST',
          sourceId: postId,
        }, db);
      } catch (notifErr) {
        console.warn('[SocialService] Like notification dispatch error:', notifErr.message);
      }
    }

    return { success: true, alreadyLiked: false, likesCount: updatedPost.likesCount };
  } catch (err) {
    if (err.code === 'P2002') {
      // Prisma Unique constraint race condition handled gracefully
      return { success: true, alreadyLiked: true, likesCount: post.likesCount };
    }
    throw err;
  }
}

export async function unlikePost(postId, userId, db = prisma) {
  if (!userId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const post = await postRepository.findPostById(postId, userId, db);
  if (!post) {
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  const existing = await socialRepository.findLike({ postId, userId }, db);
  if (!existing) {
    return { success: true, alreadyUnliked: true, likesCount: post.likesCount };
  }

  try {
    await socialRepository.deleteLike({ postId, userId }, db);
    const updatedPost = await postRepository.decrementLikesCount(postId, db);

    const payload = {
      postId,
      unlikedByUserId: userId,
      likesCount: updatedPost.likesCount,
    };
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.POST_UNLIKED, payload);
    socketEmitter.emitToUser(post.userId, SOCKET_EVENTS.POST_UNLIKED, payload);

    return { success: true, alreadyUnliked: false, likesCount: updatedPost.likesCount };
  } catch (err) {
    if (err.code === 'P2025') {
      return { success: true, alreadyUnliked: true, likesCount: post.likesCount };
    }
    throw err;
  }
}

// ============================================================
// 3. COMMENTS & REPLIES
// ============================================================

export async function createComment(
  { postId, userId, content, parentId = null },
  db = prisma
) {
  if (!userId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const post = await postRepository.findPostById(postId, userId, db);
  if (!post) {
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  // Validate parent comment if nested reply
  if (parentId) {
    const parent = await socialRepository.findCommentById(parentId, db);
    if (!parent || parent.postId !== postId) {
      const error = new Error('Parent comment not found for this post');
      error.statusCode = 400;
      error.code = 'INVALID_PARENT_COMMENT';
      throw error;
    }
  }

  const comment = await socialRepository.createComment(
    { postId, userId, content, parentId },
    db
  );

  await postRepository.incrementCommentsCount(postId, db);

  const commentPayload = {
    id: comment.id,
    commentId: comment.id,
    postId,
    authorId: userId,
    authorUsername: comment.user?.username || 'User',
    authorName: comment.user?.profile?.displayName || comment.user?.username || 'User',
    authorAvatar: comment.user?.profile?.avatarUrl || null,
    user: {
      id: comment.user?.id || userId,
      username: comment.user?.username || 'User',
      displayName: comment.user?.profile?.displayName || comment.user?.username || 'User',
      avatarUrl: comment.user?.profile?.avatarUrl || null,
    },
    content: comment.content,
    text: comment.content,
    parentId,
    createdAt: comment.createdAt,
    likesCount: 0,
    isLiked: false,
  };

  socketEmitter.broadcastGlobal(SOCKET_EVENTS.COMMENT_CREATED, commentPayload);
  socketEmitter.emitToUser(post.userId, SOCKET_EVENTS.COMMENT_CREATED, commentPayload);

  // Dispatch In-App Notification to Post Author (if not self-comment)
  if (post.userId && post.userId !== userId) {
    try {
      const commenterName = comment.user?.profile?.displayName || comment.user?.username || 'Someone';
      const snippet = content.length > 50 ? `${content.substring(0, 47)}...` : content;
      await notificationService.sendNotification({
        recipientId: post.userId,
        title: 'New Comment',
        body: `@${comment.user?.username || commenterName} commented on your post: "${snippet}"`,
        type: 'SOCIAL',
        category: 'Post',
        data: {
          postId,
          commentId: comment.id,
          commenterId: userId,
          action: 'POST_COMMENTED',
        },
        sourceType: 'POST',
        sourceId: postId,
      }, db);
    } catch (notifErr) {
      console.warn('[SocialService] Comment notification dispatch error:', notifErr.message);
    }
  }

  return comment;
}

export async function getPostComments(
  postId,
  { viewerUserId = null, page = 1, limit = 20, parentId = null } = {},
  db = prisma
) {
  const post = await postRepository.findPostById(postId, viewerUserId, db);
  if (!post) {
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  return socialRepository.findCommentsByPostId(postId, {
    viewerUserId,
    page: Number(page),
    limit: Number(limit),
    parentId,
  }, db);
}

export async function deleteComment(
  commentId,
  userId,
  { isAdmin = false, adminId = null, adminName = null, ipAddress = null } = {},
  db = prisma
) {
  const comment = await socialRepository.findCommentById(commentId, db);
  if (!comment) {
    const error = new Error('Comment not found');
    error.statusCode = 404;
    error.code = 'COMMENT_NOT_FOUND';
    throw error;
  }

  if (!isAdmin && comment.userId !== userId) {
    const error = new Error('Forbidden: You cannot delete this comment');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  await socialRepository.deleteComment(commentId, db);
  await postRepository.decrementCommentsCount(comment.postId, db);

  if (isAdmin) {
    await logAudit(
      {
        adminId,
        adminName,
        action: 'ADMIN_DELETE_COMMENT',
        targetEntity: 'Comment',
        targetEntityId: commentId,
        beforeStateJson: { id: comment.id, userId: comment.userId, content: comment.content },
        ipAddress,
      },
      db
    );
  }

  const deletePayload = {
    id: commentId,
    commentId,
    postId: comment.postId,
    deletedBy: userId || adminId,
  };

  socketEmitter.broadcastGlobal(SOCKET_EVENTS.COMMENT_DELETED, deletePayload);
  socketEmitter.emitToUser(comment.userId, SOCKET_EVENTS.COMMENT_DELETED, deletePayload);

  return { success: true, id: commentId };
}

// ============================================================
// 4. FOLLOW / UNFOLLOW SYSTEM
// ============================================================

export async function followUser(followerId, followingId, db = prisma) {
  if (!followerId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  if (followerId === followingId) {
    const error = new Error('You cannot follow yourself');
    error.statusCode = 400;
    error.code = 'CANNOT_FOLLOW_SELF';
    throw error;
  }

  const targetUser = await socialRepository.findSocialProfile(followingId, db);
  if (!targetUser) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // Check if blocked
  const blocked = await socialRepository.isBlocked(followerId, followingId, db);
  if (blocked) {
    const error = new Error('Cannot follow this user');
    error.statusCode = 403;
    error.code = 'USER_BLOCKED';
    throw error;
  }

  const existing = await socialRepository.findFollow({ followerId, followingId }, db);
  if (existing) {
    return { success: true, alreadyFollowing: true, status: existing.status };
  }

  const status = 'ACCEPTED';

  try {
    const follow = await socialRepository.createFollow({ followerId, followingId, status }, db);

    await Promise.all([
      socialRepository.incrementFollowingCount(followerId, db),
      socialRepository.incrementFollowersCount(followingId, db),
    ]);

    socketEmitter.emitToUser(followingId, SOCKET_EVENTS.FOLLOW_CREATED, {
      followerId,
      status,
      timestamp: new Date().toISOString(),
    });

    // Dispatch In-App Notification to Followed User
    try {
      const follower = await userRepository.findUserById(followerId, db);
      const followerName = follower?.profile?.displayName || follower?.username || 'Someone';
      await notificationService.sendNotification({
        recipientId: followingId,
        title: 'New Follower',
        body: `@${follower?.username || followerName} started following you.`,
        type: 'SOCIAL',
        category: 'Follower',
        data: {
          followerId,
          action: 'FOLLOW',
        },
        sourceType: 'USER',
        sourceId: followerId,
      }, db);
    } catch (notifErr) {
      console.warn('[SocialService] Follow notification dispatch error:', notifErr.message);
    }

    return { success: true, alreadyFollowing: false, status: follow.status };
  } catch (err) {
    if (err.code === 'P2002') {
      return { success: true, alreadyFollowing: true, status };
    }
    throw err;
  }
}

export async function unfollowUser(followerId, followingId, db = prisma) {
  if (!followerId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const existing = await socialRepository.findFollow({ followerId, followingId }, db);
  if (!existing) {
    return { success: true, alreadyUnfollowed: true };
  }

  try {
    await socialRepository.deleteFollow({ followerId, followingId }, db);

    if (existing.status === 'ACCEPTED') {
      await Promise.all([
        socialRepository.decrementFollowingCount(followerId, db),
        socialRepository.decrementFollowersCount(followingId, db),
      ]);
    }

    socketEmitter.emitToUser(followingId, SOCKET_EVENTS.FOLLOW_REMOVED, {
      followerId,
      timestamp: new Date().toISOString(),
    });

    return { success: true, alreadyUnfollowed: false };
  } catch (err) {
    if (err.code === 'P2025') {
      return { success: true, alreadyUnfollowed: true };
    }
    throw err;
  }
}

export async function getFollowers(userId, { viewerUserId = null, page = 1, limit = 20 } = {}, db = prisma) {
  const profile = await socialRepository.findSocialProfile(userId, db);
  if (!profile) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // If user turned on private / hidden follow list and viewer is not the profile owner
  if (profile.profile?.isPrivate && userId !== viewerUserId) {
    return {
      followers: [],
      isPrivate: true,
      message: 'This user has set their followers list to private',
      pagination: {
        page: Number(page) || 1,
        limit: Number(limit) || 20,
        total: profile.profile?.followersCount || 0,
        totalPages: 0,
      },
    };
  }

  const result = await socialRepository.findFollowers(userId, { page, limit }, db);
  return {
    ...result,
    isPrivate: false,
  };
}

export async function getFollowing(userId, { viewerUserId = null, page = 1, limit = 20 } = {}, db = prisma) {
  const profile = await socialRepository.findSocialProfile(userId, db);
  if (!profile) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // If user turned on private / hidden follow list and viewer is not the profile owner
  if (profile.profile?.isPrivate && userId !== viewerUserId) {
    return {
      following: [],
      isPrivate: true,
      message: 'This user has set their following list to private',
      pagination: {
        page: Number(page) || 1,
        limit: Number(limit) || 20,
        total: profile.profile?.followingCount || 0,
        totalPages: 0,
      },
    };
  }

  const result = await socialRepository.findFollowing(userId, { page, limit }, db);
  return {
    ...result,
    isPrivate: false,
  };
}

// ============================================================
// 5. SOCIAL PROFILE & PRIVACY
// ============================================================

export async function getSocialProfile(targetUserId, viewerUserId = null, db = prisma) {
  const user = await socialRepository.findSocialProfile(targetUserId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  let isFollowing = false;
  let isFollowedBy = false;
  let isBlockedByViewer = false;

  if (viewerUserId && viewerUserId !== targetUserId) {
    const [follow, reverseFollow, blocked] = await Promise.all([
      socialRepository.findFollow({ followerId: viewerUserId, followingId: targetUserId }, db),
      socialRepository.findFollow({ followerId: targetUserId, followingId: viewerUserId }, db),
      socialRepository.isBlocked(viewerUserId, targetUserId, db),
    ]);
    isFollowing = Boolean(follow && follow.status === 'ACCEPTED');
    isFollowedBy = Boolean(reverseFollow && reverseFollow.status === 'ACCEPTED');
    isBlockedByViewer = blocked;
  }

  const [followersCount, followingCount] = await Promise.all([
    db.follow.count({ where: { followingId: targetUserId, status: 'ACCEPTED' } }),
    db.follow.count({ where: { followerId: targetUserId, status: 'ACCEPTED' } }),
  ]);

  const isPrivate = Boolean(user.profile?.isPrivate);
  const canViewPosts = !isPrivate || isFollowing || viewerUserId === targetUserId;

  return {
    id: user.id,
    username: user.username,
    avatarUrl: user.avatarUrl,
    bio: user.bio,
    displayName: user.profile?.displayName || user.username,
    level: user.profile?.level || 1,
    vipLevel: user.profile?.vipLevel || 0,
    svipLevel: user.profile?.svipLevel || 0,
    nobleRank: user.profile?.nobleRank || null,
    isPrivate,
    followersCount,
    followingCount,
    postsCount: user.profile?.postsCount || 0,
    isFollowing,
    isFollowedBy,
    isBlocked: isBlockedByViewer,
    canViewPosts,
    createdAt: user.createdAt,
  };
}

export async function updatePrivacySettings(userId, isPrivate, db = prisma) {
  if (!userId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  const updated = await socialRepository.updateUserPrivacy(userId, isPrivate, db);
  return {
    success: true,
    isPrivate: updated.isPrivate,
  };
}

// ============================================================
// 6. BLOCKS & REPORTING
// ============================================================

export async function blockUser(blockerId, blockedId, db = prisma) {
  if (blockerId === blockedId) {
    const error = new Error('You cannot block yourself');
    error.statusCode = 400;
    error.code = 'CANNOT_BLOCK_SELF';
    throw error;
  }

  // Remove any existing follow relationships
  await Promise.all([
    socialRepository.deleteFollow({ followerId: blockerId, followingId: blockedId }, db).catch(() => {}),
    socialRepository.deleteFollow({ followerId: blockedId, followingId: blockerId }, db).catch(() => {}),
  ]);

  try {
    await socialRepository.createBlock({ blockerId, blockedId }, db);
    return { success: true, message: 'User blocked successfully' };
  } catch (err) {
    if (err.code === 'P2002') {
      return { success: true, message: 'User already blocked' };
    }
    throw err;
  }
}

export async function unblockUser(blockerId, blockedId, db = prisma) {
  try {
    await socialRepository.deleteBlock({ blockerId, blockedId }, db);
    return { success: true, message: 'User unblocked successfully' };
  } catch (err) {
    if (err.code === 'P2025') {
      return { success: true, message: 'User already not blocked' };
    }
    throw err;
  }
}

export async function getBlockedUsers(userId, db = prisma) {
  const blockedUserIds = await socialRepository.findBlockedUserIds(userId, db);
  if (!blockedUserIds || blockedUserIds.length === 0) return [];

  const users = await userRepository.findUsersByIds(blockedUserIds, db);
  return users.map((u) => ({
    id: u.id,
    name: u.name || u.username || 'User',
    username: u.username || '',
    avatarUrl: u.profile?.avatarUrl || '',
    displayId: u.displayId || u.id,
  }));
}

export async function reportContent(
  { reporterUserId, targetType, targetId, violationType, description, screenshotUrl },
  db = prisma
) {
  if (!reporterUserId) {
    const error = new Error('User authentication is required');
    error.statusCode = 401;
    error.code = 'UNAUTHORIZED';
    throw error;
  }

  let reportedUserId = null;
  let reportedPostId = null;
  let reportedCommentId = null;

  if (targetType === 'USER') {
    reportedUserId = targetId;
  } else if (targetType === 'POST') {
    reportedPostId = targetId;
    const post = await postRepository.findPostById(targetId, null, db);
    if (!post) {
      const error = new Error('Target post not found');
      error.statusCode = 404;
      error.code = 'POST_NOT_FOUND';
      throw error;
    }
    reportedUserId = post.userId;
  } else if (targetType === 'COMMENT') {
    reportedCommentId = targetId;
    const comment = await socialRepository.findCommentById(targetId, db);
    if (!comment) {
      const error = new Error('Target comment not found');
      error.statusCode = 404;
      error.code = 'COMMENT_NOT_FOUND';
      throw error;
    }
    reportedUserId = comment.userId;
  }

  const report = await socialRepository.createReport(
    {
      reporterUserId,
      reportedUserId,
      reportedPostId,
      reportedCommentId,
      violationType,
      description,
      screenshotUrl,
    },
    db
  );

  return {
    success: true,
    message: 'Report submitted successfully. Our moderation team will review it.',
    reportId: report.id,
  };
}

export async function sharePost(postId, userId = null, db = prisma) {
  const post = await postRepository.findPostById(postId, userId, db);
  if (!post) {
    const error = new Error('Post not found');
    error.statusCode = 404;
    error.code = 'POST_NOT_FOUND';
    throw error;
  }

  const updated = await postRepository.incrementSharesCount(postId, db);
  const newSharesCount = updated?.sharesCount ?? ((post.sharesCount ?? post.shares ?? 0) + 1);

  const payload = {
    postId,
    sharesCount: newSharesCount,
    sharedByUserId: userId,
  };

  try {
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.POST_SHARED, payload);
  } catch (_) {}

  return {
    success: true,
    message: 'Post shared successfully',
    data: {
      postId,
      sharesCount: newSharesCount,
    },
  };
}

export async function recordProfileVisit({ visitorId, visitedId, isMystery = false }, db = prisma) {
  if (!visitorId || !visitedId || visitorId === visitedId) return null;
  return await socialRepository.recordProfileVisit({ visitorId, visitedId, isMystery }, db);
}

export async function getProfileVisitors(userId, { limit = 50 } = {}, db = prisma) {
  return await socialRepository.findProfileVisitors(userId, { limit }, db);
}

export async function getProfileVisited(userId, { limit = 50 } = {}, db = prisma) {
  return await socialRepository.findProfileVisited(userId, { limit }, db);
}

// ============================================================
// CP / RELATIONSHIP ENGINE
// ============================================================

export async function getRelationship(userId, db = prisma) {
  if (!userId) return null;

  // Check user profile
  const user = await db.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      profile: true,
    },
  });

  if (!user) return null;

  // Query highest mutual gift partner as active CP or top relationship
  const sentGifts = await db.giftTransaction.groupBy({
    by: ['recipientUserId'],
    where: { senderUserId: userId },
    _sum: { totalCoins: true },
    orderBy: { _sum: { totalCoins: 'desc' } },
    take: 1,
  });

  if (sentGifts.length > 0) {
    const partnerId = sentGifts[0].recipientUserId;
    const partner = await db.user.findUnique({
      where: { id: partnerId },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        profile: {
          select: {
            displayName: true,
            level: true,
            vipLevel: true,
            svipLevel: true,
          },
        },
      },
    });

    if (partner) {
      const sentPoints = Number(sentGifts[0]._sum.totalCoins || 0);
      const recvGifts = await db.giftTransaction.aggregate({
        where: { senderUserId: partnerId, recipientUserId: userId },
        _sum: { totalCoins: true },
      });
      const recvPoints = Number(recvGifts._sum.totalCoins || 0);
      const totalCpPoints = sentPoints + recvPoints;
      const cpLevel = Math.max(1, Math.min(50, Math.floor(Math.sqrt(totalCpPoints / 100)) + 1));

      return {
        hasRelationship: true,
        relationType: 'COUPLE',
        relationTitle: 'Love Couple',
        partner: {
          id: partner.id,
          username: partner.username,
          displayName: partner.profile?.displayName || partner.username,
          avatarUrl: partner.avatarUrl || '',
          level: partner.profile?.level || 1,
          vipLevel: partner.profile?.vipLevel || 0,
          svipLevel: partner.profile?.svipLevel || 0,
        },
        cpPoints: totalCpPoints,
        cpLevel,
        daysTogether: Math.max(1, Math.floor((Date.now() - new Date(user.profile?.createdAt || Date.now()).getTime()) / (1000 * 60 * 60 * 24))),
        ringBadge: cpLevel >= 20 ? 'ETERNAL_DIAMOND' : cpLevel >= 10 ? 'GOLDEN_HEART' : 'SILVER_LOVE',
        privileges: [
          'Paired Couple Avatar Frame',
          'In-Room Couple Entrance Effect',
          'Exclusive Couple Gift Box',
          'CP Leaderboard Ranking',
        ],
      };
    }
  }

  return {
    hasRelationship: false,
    relationType: null,
    partner: null,
    cpPoints: 0,
    cpLevel: 0,
    daysTogether: 0,
    privileges: [],
  };
}

export async function requestRelationship({ requesterId, targetUserId, relationType = 'COUPLE', message }, db = prisma) {
  if (!requesterId || !targetUserId) {
    const error = new Error('Requester and target user IDs are required');
    error.statusCode = 400;
    throw error;
  }

  if (requesterId === targetUserId) {
    const error = new Error('You cannot form a CP relationship with yourself');
    error.statusCode = 400;
    throw error;
  }

  const target = await db.user.findUnique({
    where: { id: targetUserId },
    select: { id: true, username: true },
  });

  if (!target) {
    const error = new Error('Target user not found');
    error.statusCode = 404;
    throw error;
  }

  const requester = await db.user.findUnique({
    where: { id: requesterId },
    select: { id: true, username: true, avatarUrl: true },
  });

  try {
    socketEmitter.emitToUser(targetUserId, 'relationship:request_received', {
      requesterId,
      requesterName: requester?.username,
      requesterAvatar: requester?.avatarUrl,
      relationType,
      message: message || 'Wants to build a Couple Relationship with you!',
      timestamp: new Date().toISOString(),
    });
  } catch (_) {}

  return {
    success: true,
    message: `Relationship request sent to @${target.username}`,
    data: {
      requesterId,
      targetUserId,
      relationType,
      status: 'PENDING',
    },
  };
}

export async function respondRelationship({ userId, targetUserId, accept }, db = prisma) {
  if (!userId || !targetUserId) {
    const error = new Error('Target user ID is required');
    error.statusCode = 400;
    throw error;
  }

  try {
    socketEmitter.emitToUser(targetUserId, 'relationship:response_received', {
      responderId: userId,
      accepted: !!accept,
      timestamp: new Date().toISOString(),
    });
  } catch (_) {}

  return {
    success: true,
    message: accept ? 'Relationship accepted! You are now connected.' : 'Relationship request declined.',
    data: {
      accepted: !!accept,
      relationType: accept ? 'COUPLE' : null,
    },
  };
}

export async function dissolveRelationship({ userId, reason }, db = prisma) {
  if (!userId) {
    const error = new Error('Authentication required');
    error.statusCode = 401;
    throw error;
  }

  return {
    success: true,
    message: 'Relationship dissolved successfully.',
    data: {
      dissolvedAt: new Date().toISOString(),
      reason: reason || 'User requested separation',
    },
  };
}

/**
 * Module 10: Relationship Card Catalog
 */
export async function getRelationshipCardCatalog() {
  return [
    { id: 'card_cp', key: 'CP_LOVE', name: 'CP Relationship Card', priceCoins: 50000, durationDays: 30, limit: 'ONLY_ONE', icon: '💍', badge: 'CP' },
    { id: 'card_bestie', key: 'BEST_FRIEND', name: 'Best Friend Card', priceCoins: 20000, durationDays: 30, limit: 5, icon: '🌟', badge: 'BESTIE' },
    { id: 'card_bro_sis', key: 'BRO_SIS', name: 'Bro / Sis Card', priceCoins: 15000, durationDays: 30, limit: 5, icon: '🤝', badge: 'BRO/SIS' },
    { id: 'card_game_friend', key: 'GAME_FRIEND', name: 'Game Friend Card', priceCoins: 10000, durationDays: 30, limit: 10, icon: '🎮', badge: 'GAME' },
    { id: 'card_good_friend', key: 'GOOD_FRIEND', name: 'Good Friend Card', priceCoins: 5000, durationDays: 30, limit: 20, icon: '🌸', badge: 'FRIEND' },
  ];
}

/**
 * Module 10: Purchase & Send Relationship Card
 */
export async function purchaseAndSendRelationshipCard({ senderUserId, recipientUserId, cardType = 'CP_LOVE', deductCoins = true }, db = prisma) {
  const cards = await getRelationshipCardCatalog();
  const card = cards.find((c) => c.key === cardType || c.id === cardType) || cards[0];

  const recipient = await db.user.findUnique({
    where: { id: recipientUserId },
    select: { id: true, username: true, avatarUrl: true },
  });

  return {
    success: true,
    message: `Relationship card ${card.name} sent to @${recipient?.username || recipientUserId}. Awaiting acceptance.`,
    data: {
      invitationId: `INV_${Date.now()}`,
      senderUserId,
      recipientUserId,
      recipientUsername: recipient?.username,
      card,
      priceDeducted: deductCoins ? card.priceCoins : 0,
      status: 'PENDING_ACCEPTANCE',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    },
  };
}

/**
 * Module 29: Relationship / CP Pair Leaderboards
 */
export async function getCpPairRankings({ period = 'daily' } = {}, db = prisma) {
  const mockTop3 = [
    {
      rank: 1,
      cpScore: 895000,
      pair: {
        user1: { id: '3001001', username: 'DanialKhan', displayName: 'Danial Khan', avatarUrl: 'https://example.com/danial.jpg' },
        user2: { id: '3001002', username: 'SophiaRose', displayName: 'Sophia Rose', avatarUrl: 'https://example.com/sophia.jpg' },
        relationshipType: 'CP_LOVE',
        relationshipBadge: '💍 Eternal Love',
        ringFrame: 'ETERNAL_DIAMOND',
      },
    },
    {
      rank: 2,
      cpScore: 672000,
      pair: {
        user1: { id: '3001003', username: 'AlexRivera', displayName: 'Alex Rivera', avatarUrl: 'https://example.com/alex.jpg' },
        user2: { id: '3001004', username: 'ElenaRostova', displayName: 'Elena Rostova', avatarUrl: 'https://example.com/elena.jpg' },
        relationshipType: 'BEST_FRIEND',
        relationshipBadge: '🌟 Golden Besties',
        ringFrame: 'GOLDEN_HEART',
      },
    },
    {
      rank: 3,
      cpScore: 540000,
      pair: {
        user1: { id: '3001005', username: 'MarcusVance', displayName: 'Marcus Vance', avatarUrl: 'https://example.com/marcus.jpg' },
        user2: { id: '3001006', username: 'SaraStar', displayName: 'Sara Star', avatarUrl: 'https://example.com/sara.jpg' },
        relationshipType: 'BRO_SIS',
        relationshipBadge: '🤝 True Loyalty',
        ringFrame: 'SILVER_LOVE',
      },
    },
  ];

  return {
    period,
    top3: mockTop3,
    rankings: mockTop3,
    myPairRank: { rank: 12, cpScore: 145000, distanceToNextRank: 5000 },
  };
}

export default {
  createPost,
  getPostById,
  getFeed,
  deletePost,
  likePost,
  unlikePost,
  sharePost,
  createComment,
  getPostComments,
  deleteComment,
  followUser,
  unfollowUser,
  getFollowers,
  getFollowing,
  getSocialProfile,
  updatePrivacySettings,
  blockUser,
  unblockUser,
  getBlockedUsers,
  reportContent,
  recordProfileVisit,
  getProfileVisitors,
  getProfileVisited,
  getRelationship,
  requestRelationship,
  respondRelationship,
  dissolveRelationship,
  getRelationshipCardCatalog,
  purchaseAndSendRelationshipCard,
  getCpPairRankings,
};
