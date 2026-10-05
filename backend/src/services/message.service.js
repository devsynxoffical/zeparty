import messageRepository from '../repositories/message.repository.js';
import userRepository from '../repositories/user.repository.js';
import { getIO } from '../socket/index.js';

export async function getUserConversations(userId) {
  return await messageRepository.getConversationsForUser(userId);
}

export async function getConversationMessages(userId, targetUserId, options = {}) {
  // Mark messages from targetUser to user as read
  await messageRepository.markMessagesAsRead(targetUserId, userId);
  return await messageRepository.getMessagesBetweenUsers(userId, targetUserId, options);
}

export async function sendDirectMessage(senderId, targetUserId, { content, type = 'text', mediaUrl = null, durationSeconds = null }) {
  if (!content || !content.trim()) {
    const error = new Error('Message content cannot be empty.');
    error.status = 400;
    throw error;
  }

  // Check if target user exists
  const targetUser = await userRepository.findUserById(targetUserId);
  if (!targetUser) {
    const error = new Error('Recipient user not found.');
    error.status = 404;
    throw error;
  }

  const senderUser = await userRepository.findUserById(senderId);
  const resolvedSenderId = senderUser?.id || senderId;
  const resolvedTargetId = targetUser.id;

  if (resolvedSenderId === resolvedTargetId) {
    const error = new Error('Cannot send a direct message to yourself.');
    error.status = 400;
    throw error;
  }

  const message = await messageRepository.createMessage({
    senderId: resolvedSenderId,
    recipientId: resolvedTargetId,
    content: content.trim(),
    type: type || 'text',
    mediaUrl: mediaUrl || null,
    durationSeconds: durationSeconds ? parseInt(durationSeconds, 10) : null,
  });

  const payload = {
    ...message,
    type: type || message.type || 'text',
    mediaUrl: message.mediaUrl || mediaUrl || null,
    durationSeconds: message.durationSeconds || durationSeconds || null,
    isMediaDeleted: false,
    isMediaExpired: false,
    sender: {
      id: senderUser?.id || resolvedSenderId,
      username: senderUser?.username || 'user',
      name: senderUser?.profile?.displayName || senderUser?.username || 'ZeParty User',
      displayName: senderUser?.profile?.displayName || senderUser?.username || 'ZeParty User',
      avatarUrl: senderUser?.avatarUrl || '',
    },
  };

  // Broadcast via Socket.IO if recipient room is connected
  try {
    const io = getIO();
    if (io) {
      io.to(`user:${resolvedTargetId}`).emit('direct_message', payload);
      io.to(`user:${resolvedSenderId}`).emit('direct_message_sent', payload);
    }
  } catch (socketErr) {
    // Socket emit failure is non-fatal
    console.warn('[MessageService] Socket notification notice:', socketErr.message);
  }

  return payload;
}

export async function markConversationAsRead(userId, targetUserId) {
  return await messageRepository.markMessagesAsRead(targetUserId, userId);
}

export default {
  getUserConversations,
  getConversationMessages,
  sendDirectMessage,
  markConversationAsRead,
};
