import prisma from '../config/database.js';
import storageService from '../services/storage.service.js';

/**
 * Get distinct conversation summaries for a user with the latest message and unread counts.
 */
export async function getConversationsForUser(userId) {
  const now = new Date();

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

    const isExpired = Boolean(
      msg.isMediaDeleted ||
      (msg.mediaExpiresAt && now > new Date(msg.mediaExpiresAt))
    );

    if (!conversationMap.has(otherId)) {
      conversationMap.set(otherId, {
        otherUserId: otherId,
        lastMessage: {
          id: msg.id,
          content: msg.content,
          type: msg.type || (msg.mediaUrl ? (msg.mediaUrl.endsWith('.m4a') || msg.mediaUrl.endsWith('.mp3') ? 'voice' : 'image') : 'text'),
          mediaUrl: isExpired ? null : (msg.mediaUrl || null),
          durationSeconds: msg.durationSeconds || null,
          isMediaExpired: isExpired,
          isMediaDeleted: isExpired,
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
 * Get paginated chat history between two users with media expiration management.
 */
export async function getMessagesBetweenUsers(userAId, userBId, { page = 1, limit = 50 } = {}) {
  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 50));
  const skip = (pageNum - 1) * limitNum;
  const now = new Date();

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

  const sanitizedMessages = messages.reverse().map((msg) => {
    const isExpired = Boolean(
      msg.isMediaDeleted ||
      (msg.mediaExpiresAt && now > new Date(msg.mediaExpiresAt))
    );

    // Asynchronously delete physical file from storage once expired (after 1 month) to free storage
    if (isExpired && msg.mediaUrl && !msg.isMediaDeleted) {
      storageService.deleteFile(msg.mediaUrl).catch((err) => {
        console.warn('[MessageRepository] Expired media delete notice:', err.message);
      });
      prisma.message.update({
        where: { id: msg.id },
        data: { isMediaDeleted: true, mediaUrl: null },
      }).catch(() => {});
    }

    const type = msg.type || (msg.mediaUrl ? (msg.mediaUrl.endsWith('.m4a') || msg.mediaUrl.endsWith('.mp3') ? 'voice' : 'image') : 'text');

    return {
      id: msg.id,
      senderId: msg.senderId,
      recipientId: msg.recipientId,
      content: msg.content,
      type,
      mediaUrl: isExpired ? null : (msg.mediaUrl || null),
      durationSeconds: msg.durationSeconds || null,
      mediaExpiresAt: msg.mediaExpiresAt || null,
      isMediaDeleted: isExpired,
      isMediaExpired: isExpired,
      isRead: msg.isRead,
      createdAt: msg.createdAt,
    };
  });

  return {
    messages: sanitizedMessages,
    pagination: {
      page: pageNum,
      limit: limitNum,
      totalCount,
      totalPages: Math.ceil(totalCount / limitNum),
    },
  };
}

/**
 * Create and persist a new message with media retention support (30-day lifecycle).
 */
export async function createMessage({
  senderId,
  recipientId,
  content,
  type = 'text',
  mediaUrl = null,
  durationSeconds = null,
}) {
  // 30 days retention policy for media attachments (voice notes, images)
  const mediaExpiresAt = mediaUrl ? new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) : null;

  return await prisma.message.create({
    data: {
      senderId,
      recipientId,
      content,
      type: type || 'text',
      mediaUrl: mediaUrl || null,
      durationSeconds: durationSeconds ? parseInt(durationSeconds, 10) : null,
      mediaExpiresAt,
      isMediaDeleted: false,
      isRead: false,
    },
  });
}

/**
 * Batch maintenance job: Purges expired media (> 1 month old) from storage to manage disk space.
 */
export async function cleanupExpiredMessageMedia() {
  const now = new Date();
  try {
    const expiredMessages = await prisma.message.findMany({
      where: {
        mediaExpiresAt: { lt: now },
        isMediaDeleted: false,
        mediaUrl: { not: null },
      },
      take: 100,
    });

    let cleanedCount = 0;
    for (const msg of expiredMessages) {
      if (msg.mediaUrl) {
        await storageService.deleteFile(msg.mediaUrl).catch(() => {});
      }
      await prisma.message.update({
        where: { id: msg.id },
        data: { isMediaDeleted: true, mediaUrl: null },
      }).catch(() => {});
      cleanedCount++;
    }

    if (cleanedCount > 0) {
      console.log(`[MessageRepository] Purged ${cleanedCount} expired message media files (>30 days old).`);
    }
    return cleanedCount;
  } catch (err) {
    console.error('[MessageRepository] cleanupExpiredMessageMedia error:', err.message);
    return 0;
  }
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
  cleanupExpiredMessageMedia,
  markMessagesAsRead,
};
