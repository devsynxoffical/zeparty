// ============================================================
// ZeParty Admin Portal — Posts Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getUserPosts(userId, params = {}) {
  const queryParams = { ...params };
  if (userId) queryParams.userId = userId;
  const res = await apiClient.get('/v1/admin/posts', { params: queryParams });
  const items = res.data?.data || [];
  return items.map((p) => ({
    id: p.id,
    userId: p.authorId || p.userId,
    content: p.caption || p.content || '',
    mediaUrl: p.mediaUrls?.[0] || p.mediaUrl || '',
    mediaUrls: p.mediaUrls || (p.mediaUrl ? [p.mediaUrl] : []),
    likesCount: Number(p.likesCount || p._count?.likes || 0),
    commentsCount: Number(p.commentsCount || p._count?.comments || 0),
    createdAt: p.createdAt,
    status: p.status || 'ACTIVE',
    author: p.author ? {
      id: p.author.id,
      username: p.author.username,
      avatarUrl: p.author.profile?.avatarUrl,
    } : null,
  }));
}

export async function deleteUserPost(postId, reason = 'Admin Moderation') {
  const res = await apiClient.delete(`/v1/admin/posts/${postId}`, {
    data: { reason },
  });
  return res.data;
}

export async function deleteUserComment(commentId, reason = 'Admin Moderation') {
  const res = await apiClient.delete(`/v1/admin/posts/comments/${commentId}`, {
    data: { reason },
  });
  return res.data;
}

export default {
  getUserPosts,
  deleteUserPost,
  deleteUserComment,
};
