import { z } from 'zod';

export const createRoomSchema = z.object({
  title: z.string().trim().min(1, 'Title is required').max(100),
  coverImageUrl: z.string().max(1000).optional().or(z.literal('')),
  backgroundImageUrl: z.string().max(2000).optional().nullable().or(z.literal('')),
  roomType: z.preprocess((val) => {
    if (typeof val === 'string') {
      const u = val.toUpperCase().trim();
      if (u.includes('AUDIO') || u.includes('PARTY') || u.includes('VOICE')) return 'AUDIO_PARTY';
      if (u.includes('VIDEO') || u.includes('LIVE')) return 'LIVE_VIDEO';
    }
    return val;
  }, z.enum(['LIVE_VIDEO', 'AUDIO_PARTY']).default('LIVE_VIDEO')),
  category: z.preprocess((val) => {
    if (typeof val === 'string') {
      const u = val.toUpperCase().trim();
      if (u.includes('MUSIC')) return 'MUSIC';
      if (u.includes('GAME') || u.includes('GAMING') || u.includes('PK')) return 'GAMING';
      return 'CHAT';
    }
    return val;
  }, z.enum(['MUSIC', 'CHAT', 'GAMING']).default('CHAT')),
  isPrivate: z.boolean().default(false),
  roomPin: z.string().max(10).optional().or(z.literal('')),
});

export const updateRoomBackgroundSchema = z.object({
  backgroundImageUrl: z.string().max(2000).optional().nullable().or(z.literal('')),
  background: z.string().max(2000).optional().nullable().or(z.literal('')),
});

export const queryActiveRoomsSchema = z.object({
  roomType: z.preprocess((val) => {
    if (!val || val === '' || val === 'all' || val === 'ALL') return undefined;
    if (typeof val === 'string') {
      const u = val.toUpperCase().trim();
      if (u.includes('AUDIO') || u.includes('PARTY') || u.includes('VOICE')) return 'AUDIO_PARTY';
      if (u.includes('VIDEO') || u.includes('LIVE')) return 'LIVE_VIDEO';
    }
    return undefined;
  }, z.enum(['LIVE_VIDEO', 'AUDIO_PARTY']).optional()),
  category: z.preprocess((val) => {
    if (!val || val === '' || val === 'all' || val === 'ALL' || val === 'all categories') return undefined;
    if (typeof val === 'string') {
      const u = val.toUpperCase().trim();
      if (u === 'ALL' || u === 'POPULAR' || u === 'EXPLORE' || u === 'LIVE') return undefined;
      if (u.includes('MUSIC')) return 'MUSIC';
      if (u.includes('GAME') || u.includes('GAMING') || u.includes('PK')) return 'GAMING';
      if (u.includes('CHAT') || u.includes('TALK') || u.includes('FRIEND') || u.includes('HANG') || u.includes('SOCIAL')) return 'CHAT';
    }
    return undefined;
  }, z.enum(['MUSIC', 'CHAT', 'GAMING']).optional()),
  search: z.string().trim().optional(),
  isPrivate: z.preprocess((val) => {
    if (val === 'true' || val === true || val === 1 || val === '1') return true;
    if (val === 'false' || val === false || val === 0 || val === '0') return false;
    return false;
  }, z.boolean()).default(false),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
});

export const queryAdminRoomsSchema = z.object({
  search: z.string().trim().optional(),
  status: z.preprocess((val) => {
    if (!val || val === 'all' || val === 'ALL') return undefined;
    return val;
  }, z.enum(['LIVE', 'ENDED', 'CLOSED_BY_ADMIN']).optional()),
  roomType: z.preprocess((val) => {
    if (!val || val === 'all' || val === 'ALL') return undefined;
    if (typeof val === 'string') {
      const u = val.toUpperCase().trim();
      if (u.includes('AUDIO') || u.includes('PARTY') || u.includes('VOICE')) return 'AUDIO_PARTY';
      if (u.includes('VIDEO') || u.includes('LIVE')) return 'LIVE_VIDEO';
    }
    return undefined;
  }, z.enum(['LIVE_VIDEO', 'AUDIO_PARTY']).optional()),
  isPinnedTop: z.string().optional(),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const occupySeatParamSchema = z.object({
  id: z.string().min(1, 'Room ID is required'),
  seatIndex: z.coerce.number().int().min(0, 'Seat index must be between 0 and 30').max(30, 'Seat index must be between 0 and 30'),
});

export const pinRoomSchema = z.object({
  pinnedPosition: z.coerce.number().int().min(1).max(3).default(1),
});

export const adminCloseRoomSchema = z.object({
  reason: z.string().trim().max(500).optional(),
});

export const adminWarnRoomSchema = z.object({
  reason: z.string().trim().max(500).optional(),
});

export const adminMuteRoomSchema = z.object({
  isMuted: z.boolean().default(true),
});

export const adminMuteParticipantSchema = z.object({
  targetUserId: z.string().nullable().optional(),
  seatIndex: z.coerce.number().int().nullable().optional(),
  isMuted: z.boolean().default(true),
});

export const adminKickUserSchema = z.object({
  targetUserId: z.string().min(1, 'Target user ID is required'),
  reason: z.string().trim().max(500).optional(),
});

export const roomModerationSchema = z.object({
  targetUserId: z.string().min(1, 'Target user ID is required'),
  action: z.enum(['REMOVE_FROM_MIC', 'REMOVE_MIC', 'MUTE', 'UNMUTE', 'KICK']).optional(),
  isMuted: z.boolean().optional(),
  reason: z.string().trim().max(500).optional(),
});

export const roomModerationTargetSchema = z.object({
  targetUserId: z.string().min(1, 'Target user ID is required'),
  reason: z.string().trim().max(500).optional(),
});

export const roomModerationMuteSchema = z.object({
  targetUserId: z.string().min(1, 'Target user ID is required'),
  isMuted: z.boolean().default(true),
  reason: z.string().trim().max(500).optional(),
});

export const adminUpdateDpSchema = z.object({
  coverImageUrl: z.string().max(1000).nullable().optional().or(z.literal('')),
});

export const roomIdParamSchema = z.object({
  id: z.string().min(1, 'Room ID is required'),
});

export default {
  createRoomSchema,
  queryActiveRoomsSchema,
  queryAdminRoomsSchema,
  occupySeatParamSchema,
  pinRoomSchema,
  adminCloseRoomSchema,
  adminWarnRoomSchema,
  adminMuteRoomSchema,
  adminMuteParticipantSchema,
  adminKickUserSchema,
  roomModerationSchema,
  roomModerationTargetSchema,
  roomModerationMuteSchema,
  adminUpdateDpSchema,
  roomIdParamSchema,
};
