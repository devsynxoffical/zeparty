let ioInstance = null;

/**
 * A Socket.IO packet whose event name is not a string is rejected by every client as a
 * "parse error", and the client then drops the whole connection. An undefined constant
 * emitted after each gift did exactly that to every socket in the room (the host stopped
 * receiving joins, chats and gifts until they re-entered). Never let that happen again.
 */
function validEvent(event, where) {
  if (typeof event === 'string' && event.length > 0) return true;
  console.error(`[SocketEmitter] refusing to ${where} an event with an invalid name:`, event, new Error().stack?.split('\n')[2]?.trim());
  return false;
}

/**
 * Sets the global Socket.IO server instance.
 */
export function setSocketServerInstance(io) {
  ioInstance = io;
}

/**
 * Gets the global Socket.IO server instance.
 */
export function getSocketServerInstance() {
  return ioInstance;
}

/**
 * Emits an event to all connected sockets in a specific room.
 * 
 * @param {string} roomId - Room identifier
 * @param {string} event - Event name from SOCKET_EVENTS
 * @param {Object} payload - Event payload
 */
export function emitToRoom(roomId, event, payload) {
  if (!ioInstance || !roomId || !validEvent(event, 'emitToRoom')) return false;
  try {
    ioInstance.to(`room:${roomId}`).emit(event, payload);
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * Emits an event to all connected sockets for a specific user.
 * 
 * @param {string} userId - User identifier
 * @param {string} event - Event name from SOCKET_EVENTS
 * @param {Object} payload - Event payload
 */
export function emitToUser(userId, event, payload) {
  if (!ioInstance || !userId || !validEvent(event, 'emitToUser')) return false;
  try {
    ioInstance.to(`user:${userId}`).emit(event, payload);
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * Broadcasts an event globally to all connected sockets on the server.
 * 
 * @param {string} event - Event name
 * @param {Object} payload - Event payload
 */
export function broadcastGlobal(event, payload) {
  if (!ioInstance || !validEvent(event, 'broadcastGlobal')) return false;
  try {
    ioInstance.emit(event, payload);
    return true;
  } catch (err) {
    return false;
  }
}

export const emitToAll = broadcastGlobal;

export default {
  setSocketServerInstance,
  getSocketServerInstance,
  emitToRoom,
  emitToUser,
  broadcastGlobal,
  emitToAll,
};
