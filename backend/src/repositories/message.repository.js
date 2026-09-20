import prisma from '../config/database.js';

/**
 * Get distinct conversation summaries for a user with the latest message and unread counts.
 */
export async function getConversationsForUser(userId) {
  // Find all messages involving the user
  const messages = await prisma.message.findMany({
    where: {
      OR: [
        { senderId: userId },
        { recipientId: userId },
      ],
    },
    orderBy: { createdAt: 'desc' },
  });

  // Group by other user ID
  const conversationMap = new Map();
  const otherUserIds = new Set();

  for (const msg of messages) {
    const otherId = msg.senderId === userId ? msg.recipientId : msg.senderId;
    otherUserIds.add(otherId);

    if (!conversationMap.has(otherId)) {
      conversationMap.set(otherId, {
        otherUserId: otherId,
        lastMessage: {
          id: msg.id,
          content: msg.content,
          senderId: msg.senderId,
          recipientId: msg.recipientId,
          createdAt: msg.createdAt,
          isRead: msg.isRead,
        },
        unreadCount: 0,
        otherUser: null,
      });
    }

    if (msg.recipientId === userId && !msg.isRead) {
      const conv = conversationMap.get(otherId);
      conv.unreadCount += 1;
    }
  }

  if (otherUserIds.size === 0) {
    return [];
  }

  // Fetch all other users' profiles in a single query
  const users = await prisma.user.findMany({
    where: {
      id: { in: Array.from(otherUserIds) },
      status: 'ACTIVE',
    },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      bio: true,
      gender: true,
      dob: true,
      profile: {
        select: {
          displayName: true,
          signature: true,
          level: true,
          vipLevel: true,
        },
      },
    },
  });

  const userMap = new Map(users.map((u) => [u.id, u]));

  const result = [];
  for (const [otherId, conv] of conversationMap.entries()) {
    const user = userMap.get(otherId);
    if (user) {
      conv.otherUser = {
        id: user.id,
        username: user.username,
        name: user.profile?.displayName || user.username,
        displayName: user.profile?.displayName || user.username,
        avatarUrl: user.avatarUrl || '',
        bio: user.bio || user.profile?.signature || '',
        gender: user.gender || 'Not Specified',
        dob: user.dob,
        isVip: (user.profile?.vipLevel || 0) > 0,
        vipLevel: user.profile?.vipLevel ? `VIP ${user.profile.vipLevel}` : 'None',
      };
      result.push(conv);
    }
  }

  return result;
}

/**
 * Get paginated chat history between two users.
 */
export async function getMessagesBetweenUsers(userAId, userBId, { page = 1, limit = 50 } = {}) {
  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 50));
  const skip = (pageNum - 1) * limitNum;

  const [messages, totalCount] = await Promise.all([
    prisma.message.findMany({
      where: {
        OR: [
          { senderId: userAId, recipientId: userBId },
          { senderId: userBId, recipientId: userAId },
        ],
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limitNum,
    }),
    prisma.message.count({
      where: {
        OR: [
          { senderId: userAId, recipientId: userBId },
          { senderId: userBId, recipientId: userAId },
        ],
      },
    }),
  ]);

  return {
    messages: messages.reverse(), // chronological order
    pagination: {
      page: pageNum,
      limit: limitNum,
      totalCount,
      totalPages: Math.ceil(totalCount / limitNum),
    },
  };
}

/**
 * Create and persist a new message.
 */
export async function createMessage({ senderId, recipientId, content }) {
  return await prisma.message.create({
    data: {
      senderId,
      recipientId,
      content,
      isRead: false,
    },
  });
}

/**
 * Mark messages from senderId to recipientId as read.
 */
export async function markMessagesAsRead(senderId, recipientId) {
  return await prisma.message.updateMany({
    where: {
      senderId,
      recipientId,
      isRead: false,
    },
    data: {
      isRead: true,
    },
  });
}

export default {
  getConversationsForUser,
  getMessagesBetweenUsers,
  createMessage,
  markMessagesAsRead,
};
