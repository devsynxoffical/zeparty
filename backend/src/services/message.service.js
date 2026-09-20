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

export async function sendDirectMessage(senderId, targetUserId, { content }) {
  if (!content || !content.trim()) {
    const error = new Error('Message content cannot be empty.');
    error.status = 400;
    throw error;
  }

  if (senderId === targetUserId) {
    const error = new Error('Cannot send a direct message to yourself.');
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

  const message = await messageRepository.createMessage({
    senderId,
    recipientId: targetUserId,
    content: content.trim(),
  });

  const payload = {
    ...message,
    sender: {
      id: senderUser.id,
      username: senderUser.username,
      name: senderUser.name,
      displayName: senderUser.name || senderUser.username,
      avatarUrl: senderUser.avatarUrl || '',
    },
  };

  // Broadcast via Socket.IO if recipient room is connected
  try {
    const io = getIO();
    if (io) {
      io.to(`user:${targetUserId}`).emit('direct_message', payload);
      io.to(`user:${senderId}`).emit('direct_message_sent', payload);
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
