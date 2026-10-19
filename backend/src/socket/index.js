import { Server } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import env from '../config/env.js';
import redisClient from '../config/redis.js';
import socketAuthMiddleware from './auth.js';
import socketEmitter from './socket.emitter.js';
import { registerRoomHandlers } from './room.socket.js';
import { registerSeatHandlers } from './seat.socket.js';
import { registerGiftHandlers } from './gift.socket.js';
import { registerPKHandlers } from './pk.socket.js';
import { registerWheelHandlers } from './wheel.socket.js';
import { registerLuckyBagHandlers } from './luckyBag.socket.js';
import presenceService from './presence.service.js';

let ioInstance = null;

/**
 * Initializes and configures the Socket.IO realtime server.
 * 
 * @param {import('http').Server} httpServer - Node.js HTTP server instance
 * @returns {Promise<import('socket.io').Server>}
 */
export async function initSocketServer(httpServer) {
  if (ioInstance) return ioInstance;

  const resolveSocketOrigin = (originString) => {
    if (!originString || originString === '*') return '*';
    const origins = originString.split(',').map((o) => o.trim()).filter(Boolean);
    return origins.length === 1 ? origins[0] : origins;
  };

  const corsOrigin = env.NODE_ENV === 'production' && env.SOCKET_CORS_ORIGIN !== '*'
    ? resolveSocketOrigin(env.SOCKET_CORS_ORIGIN)
    : '*';

  const io = new Server(httpServer, {
    cors: {
      origin: corsOrigin,
      methods: ['GET', 'POST'],
      credentials: true,
    },
    transports: ['websocket', 'polling'],
    pingTimeout: 20000,
    pingInterval: 25000,
  });

  // Optional Redis Adapter for Distributed Multi-Instance Deployments
  if (env.SOCKET_REDIS_ENABLED && redisClient.isOpen) {
    try {
      const pubClient = redisClient.duplicate();
      const subClient = redisClient.duplicate();
      await Promise.all([pubClient.connect(), subClient.connect()]);
      io.adapter(createAdapter(pubClient, subClient));
      console.log('✅ Socket.IO Redis adapter connected successfully');
    } catch (adapterErr) {
      console.warn('⚠️ Socket.IO Redis adapter fallback to in-memory mode:', adapterErr.message);
    }
  }

  // Socket Authentication Middleware
  io.use(socketAuthMiddleware);

  // Connection Handler
  io.on('connection', async (socket) => {
    // Automatically join authenticated user's private channel
    socket.join(`user:${socket.userId}`);

    // Register global presence tracking for registered users
    if (socket.userId && !socket.isGuest && !String(socket.userId).startsWith('guest_')) {
      try {
        const { isFirstSocket } = await presenceService.registerUserSocket(socket.userId, socket.id);
        if (isFirstSocket) {
          const pres = await presenceService.getUserPresence(socket.userId);
          presenceService.broadcastPresenceChange(io, socket.userId, pres);
        }
      } catch (presErr) {
        console.warn('[Socket] Presence register warning:', presErr.message);
      }
    }

    // Register domain handlers
    registerRoomHandlers(io, socket);
    registerSeatHandlers(io, socket);
    registerGiftHandlers(io, socket);
    registerPKHandlers(io, socket);
    registerWheelHandlers(io, socket);
    registerLuckyBagHandlers(io, socket);

    // Direct Messaging Typing Indicators
    socket.on('chat:typing', (data) => {
      if (data && data.targetUserId) {
        io.to(`user:${data.targetUserId}`).emit('chat:typing', {
          senderId: socket.userId,
          isTyping: !!data.isTyping,
        });
      }
    });

    // Real-time Agency & Host Invitation Delivery (Mutual Exclusion Guarded)
    socket.on('agency:invite_member', async (data) => {
      if (data && data.targetUserId) {
        try {
          const { validateHostingEligibility } = await import('../services/hostingEligibility.service.js');
          await validateHostingEligibility(data.targetUserId, 'JOIN_AUDIO_HOST');
        } catch (err) {
          return socket.emit('agency:error', {
            code: err.code || 'HOSTING_ROLE_CONFLICT',
            message: err.message || 'Target user is not eligible to join an agency as Audio Host.',
            conflictingRole: err.conflictingRole,
          });
        }

        const payload = {
          id: data.invitationId || `sys_inv_${Date.now()}`,
          title: data.title || 'Host Invitation (ZeParty Official)',
          content: data.content || `${data.inviterName || 'Agency'} invited you to join as a Host.`,
          body: data.content || `${data.inviterName || 'Agency'} invited you to join as a Host.`,
          category: 'Official',
          timestamp: new Date().toISOString(),
          invitationType: data.invitationType || 'Host',
          invitationId: data.invitationId || `inv_ag_${Date.now()}`,
          inviterName: data.inviterName || 'ZeParty Agency',
          inviterUserId: socket.userId,
          targetId: data.targetUserId,
          status: 'Pending',
        };

        io.to(`user:${data.targetUserId}`).emit('notification:new', payload);
        io.to(`user:${data.targetUserId}`).emit('agency:invitation_received', payload);
      }
    });

    // Real-time Agency & Host Invitation Response Handler (Mutual Exclusion Guarded)
    socket.on('agency:respond_invite', async (data) => {
      if (data && data.inviterUserId) {
        if (data.action === 'ACCEPT' || data.status === 'ACCEPTED') {
          try {
            const { validateHostingEligibility } = await import('../services/hostingEligibility.service.js');
            await validateHostingEligibility(socket.userId, 'ACCEPT_AUDIO_HOST_INVITE');
          } catch (err) {
            return socket.emit('agency:error', {
              code: err.code || 'HOSTING_ROLE_CONFLICT',
              message: err.message,
              conflictingRole: err.conflictingRole,
            });
          }
        }

        io.to(`user:${data.inviterUserId}`).emit('agency:invitation_responded', {
          ...data,
          responderUserId: socket.userId,
          timestamp: new Date().toISOString(),
        });
      }
    });

    socket.on('disconnect', (reason) => {
      // Handled in room.socket.js onSocketDisconnect
    });
  });

  socketEmitter.setSocketServerInstance(io);
  ioInstance = io;

  return io;
}

export function getIO() {
  return ioInstance;
}

export default {
  initSocketServer,
  getIO,
};
