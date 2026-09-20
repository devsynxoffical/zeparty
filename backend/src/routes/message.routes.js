import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import messageController from '../controllers/message.controller.js';

export const messageRouter = express.Router();

messageRouter.use(authenticate);

// List conversations
messageRouter.get('/conversations', messageController.getConversations);

// Get messages in a conversation with target user
messageRouter.get('/:targetUserId', messageController.getMessages);

// Send message to target user
messageRouter.post('/:targetUserId', messageController.sendMessage);

// Mark conversation as read
messageRouter.patch('/:targetUserId/read', messageController.markAsRead);

export default messageRouter;
