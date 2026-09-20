import messageService from '../services/message.service.js';

export async function getConversations(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const conversations = await messageService.getUserConversations(userId);
    return res.status(200).json({
      success: true,
      data: conversations,
    });
  } catch (error) {
    next(error);
  }
}

export async function getMessages(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { targetUserId } = req.params;
    const { page, limit } = req.query;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const result = await messageService.getConversationMessages(userId, targetUserId, { page, limit });
    return res.status(200).json({
      success: true,
      data: result.messages,
      pagination: result.pagination,
    });
  } catch (error) {
    next(error);
  }
}

export async function sendMessage(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { targetUserId } = req.params;
    const { content } = req.body;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const message = await messageService.sendDirectMessage(userId, targetUserId, { content });
    return res.status(201).json({
      success: true,
      data: message,
      message: 'Message sent successfully.',
    });
  } catch (error) {
    next(error);
  }
}

export async function markAsRead(req, res, next) {
  try {
    const userId = req.auth?.userId;
    const { targetUserId } = req.params;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required.',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    await messageService.markConversationAsRead(userId, targetUserId);
    return res.status(200).json({
      success: true,
      message: 'Messages marked as read.',
    });
  } catch (error) {
    next(error);
  }
}

export default {
  getConversations,
  getMessages,
  sendMessage,
  markAsRead,
};
