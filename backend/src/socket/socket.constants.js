/**
 * Canonical Realtime Socket.IO Event Constants and Error Codes
 */

export const SOCKET_EVENTS = {
  // Connection & Core
  CONNECT: 'connect',
  DISCONNECT: 'disconnect',
  ERROR: 'error',

  // Room Lifecycle & Subscription
  ROOM_JOIN: 'room:join',
  ROOM_LEAVE: 'room:leave',
  ROOM_SNAPSHOT: 'room:snapshot',
  ROOM_USER_JOINED: 'room:user_joined',
  ROOM_USER_LEFT: 'room:user_left',
  ROOM_VIEWER_COUNT_CHANGED: 'room:viewer_count_changed',
  ROOM_CREATED: 'room:created',
  ROOM_STARTED: 'room:started',
  ROOM_CLOSED: 'room:closed',

  // Seat Management
  ROOM_SEAT_OCCUPY: 'room:seat_occupy',
  ROOM_SEAT_LEAVE: 'room:seat_leave',
  ROOM_SEAT_OCCUPIED: 'room:seat_occupied',
  ROOM_SEAT_RELEASED: 'room:seat_released',
  ROOM_SEAT_UPDATED: 'room:seat_updated',

  // Admin Controls
  ROOM_PINNED: 'room:pinned',
  ROOM_UNPINNED: 'room:unpinned',

  // In-Room Chat & Messaging
  ROOM_CHAT_SEND: 'room:chat_send',
  ROOM_CHAT_MESSAGE: 'room:chat_message',
  ROOM_CHAT_RECEIVE: 'room:chat_message',
  ROOM_FEED_CLEARED: 'room:feed_cleared',
  PARTY_CLEAR_SCREEN: 'party:clear_screen',

  // Gifting & Tipping
  ROOM_GIFT_SEND: 'room:gift_send',
  ROOM_GIFT_SENT: 'room:gift_sent',

  // Moderation & Seat/User Management
  ROOM_KICK_USER: 'room:kick_user',
  ROOM_USER_KICKED: 'room:user_kicked',
  ROOM_WARNING: 'room:warning',
  ROOM_WARNING_ISSUED: 'room:warning',
  ROOM_MUTED: 'room:muted',
  ROOM_USER_MUTED: 'room:user_muted',
  ROOM_DP_UPDATED: 'room:dp_updated',

  // Emoji Reactions
  ROOM_EMOJI_SEND: 'room:emoji_send',
  ROOM_EMOJI_RECEIVED: 'room:emoji',

  // PK Battles (Phase 19 & 2.0 Redesign)
  PK_INVITATION_RECEIVED: 'pk:invitation_received',
  PK_INVITATION_RESPONDED: 'pk:invitation_responded',
  PK_INVITATION_CANCELLED: 'pk:invitation_cancelled',
  PK_INVITATION_EXPIRED: 'pk:invitation_expired',
  PK_PREPARING: 'pk:preparing',
  PK_READY_CHANGED: 'pk:ready_changed',
  PK_COUNTDOWN_STARTED: 'pk:countdown_started',
  PK_MATCH_STARTED: 'pk:match_started',
  PK_SCORE_UPDATED: 'pk:score_updated',
  PK_HOST_CONNECTION_CHANGED: 'pk:host_connection_changed',
  PK_MATCH_FINISHED: 'pk:match_finished',
  PK_MATCH_FORFEITED: 'pk:match_forfeited',
  PK_MATCH_ABORTED: 'pk:match_aborted',
  PK_START: 'pk:start',
  PK_STARTED: 'pk:started',
  PK_ACTIVATE: 'pk:activate',
  PK_ACTIVE: 'pk:active',
  PK_END: 'pk:end',
  PK_ENDED: 'pk:ended',

  // Mic Invitations (Change 13: Room Live Viewers)
  MIC_INVITATION_SEND: 'room:mic_invite',
  MIC_INVITATION_RECEIVED: 'room:mic_invitation',
  MIC_INVITATION_ACCEPT: 'room:accept_mic_invite',
  MIC_INVITATION_ACCEPTED: 'room:mic_invite_accepted',
  MIC_INVITATION_DECLINE: 'room:decline_mic_invite',
  MIC_INVITATION_DECLINED: 'room:mic_invite_declined',
  MIC_INVITATION_CANCEL: 'room:cancel_mic_invite',
  MIC_INVITATION_CANCELLED: 'room:mic_invite_cancelled',

  // Settlements & Payroll
  SETTLEMENT_CREATED: 'settlement:created',
  SETTLEMENT_CALCULATED: 'settlement:calculated',
  SETTLEMENT_APPROVED: 'settlement:approved',
  SETTLEMENT_PAID: 'settlement:paid',
  SETTLEMENT_ADJUSTED: 'settlement:adjusted',

  // Social & Community
  POST_CREATED: 'post:created',
  POST_DELETED: 'post:deleted',
  POST_LIKED: 'post:liked',
  POST_UNLIKED: 'post:unliked',
  POST_SHARED: 'post:shared',
  COMMENT_CREATED: 'comment:created',
  COMMENT_DELETED: 'comment:deleted',
  FOLLOW_CREATED: 'follow:created',
  FOLLOW_REMOVED: 'follow:removed',

  // Moderation, Safety & Restrictions (Phase 8)
  MODERATION_RESTRICTION: 'moderation:restriction',
  MODERATION_BAN: 'moderation:ban',
  MODERATION_UNBAN: 'moderation:unban',
  MODERATION_ACTION: 'moderation:action',
  REPORT_CREATED: 'report:created',
  REPORT_UPDATED: 'report:updated',
  REPORT_RESOLVED: 'report:resolved',
  TICKET_CREATED: 'ticket:created',
  TICKET_UPDATED: 'ticket:updated',
  TICKET_MESSAGE: 'ticket:message',
  TICKET_ASSIGNED: 'ticket:assigned',
  TICKET_RESOLVED: 'ticket:resolved',

  // Notifications & FCM Delivery (Phase 9)
  NOTIFICATION_NEW: 'notification:new',
  NOTIFICATION_READ: 'notification:read',
  NOTIFICATION_READ_ALL: 'notification:read_all',
  NOTIFICATION_BROADCAST: 'notification:broadcast',
};

export const SOCKET_ERRORS = {
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  USER_NOT_ACTIVE: 'USER_NOT_ACTIVE',
  ROOM_NOT_FOUND: 'ROOM_NOT_FOUND',
  ROOM_NOT_LIVE: 'ROOM_NOT_LIVE',
  INVALID_SEAT_INDEX: 'INVALID_SEAT_INDEX',
  SEAT_OCCUPIED: 'SEAT_OCCUPIED',
  SEAT_RELEASE_DENIED: 'SEAT_RELEASE_DENIED',
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  INSUFFICIENT_FUNDS: 'INSUFFICIENT_FUNDS',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  PENDING_INVITE_EXISTS: 'PENDING_INVITE_EXISTS',
  INVITATION_EXPIRED: 'INVITATION_EXPIRED',
  INVITATION_NOT_FOUND: 'INVITATION_NOT_FOUND',
  ROOM_FULL: 'ROOM_FULL',
  NO_AVAILABLE_SEATS: 'NO_AVAILABLE_SEATS',
  ALREADY_ON_MIC: 'ALREADY_ON_MIC',
  CANNOT_INVITE_SELF: 'CANNOT_INVITE_SELF',
  CANNOT_INVITE_OWNER: 'CANNOT_INVITE_OWNER',
  TARGET_NOT_IN_ROOM: 'TARGET_NOT_IN_ROOM',
};

export default {
  SOCKET_EVENTS,
  SOCKET_ERRORS,
};
