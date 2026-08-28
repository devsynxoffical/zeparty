// ============================================================
// ZeParty Admin Portal — Posts Service (JavaScript)
// ============================================================

import { MOCK_USER_POSTS } from '../../mocks/posts.mock';

let postsState = [...MOCK_USER_POSTS];

export async function getUserPosts(userId) {
  await new Promise((res) => setTimeout(res, 200));
  if (!userId) return [...postsState];

  // Try exact match
  const userSpecific = postsState.filter((p) => p.userId === userId);
  if (userSpecific.length > 0) return userSpecific;

  // Fallback match by number or default sample set so posts tab always demonstrates working data
  const normalized = String(userId).toLowerCase().replace(/[^0-9]/g, '');
  if (normalized === '1' || normalized === '001') {
    return postsState.filter((p) => p.userId === 'usr-001');
  } else if (normalized === '2' || normalized === '002') {
    return postsState.filter((p) => p.userId === 'usr-002');
  } else if (normalized === '3' || normalized === '003') {
    return postsState.filter((p) => p.userId === 'usr-003');
  }

  // General fallback sample posts mapped to requested user
  return postsState.slice(0, 3).map((p, idx) => ({
    ...p,
    id: `post-gen-${userId}-${idx}`,
    userId: userId
  }));
}

export async function deleteUserPost(postId, reason = 'Admin Moderation') {
  await new Promise((res) => setTimeout(res, 300));
  const postIndex = postsState.findIndex((p) => p.id === postId);
  if (postIndex !== -1) {
    const deleted = postsState[postIndex];
    postsState = postsState.filter((p) => p.id !== postId);
    return { success: true, deletedPost: deleted, reason };
  }
  return { success: true, reason };
}

export async function updatePostVisibility(postId, visibility) {
  await new Promise((res) => setTimeout(res, 200));
  postsState = postsState.map((p) => (p.id === postId ? { ...p, visibility } : p));
  return { success: true };
}
