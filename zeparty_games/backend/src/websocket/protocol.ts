import { z } from 'zod';

/**
 * Client -> server messages. Every message may carry `reqId` which is echoed in errors so
 * the client can correlate. Documented in docs/api/websocket.md.
 */
export const ClientMessageSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('auth'), reqId: z.string().optional(), token: z.string().min(1) }),
  z.object({ type: z.literal('ping'), reqId: z.string().optional(), t: z.number().optional() }),
  z.object({ type: z.literal('room.create'), reqId: z.string().optional(), gameId: z.string(), isPrivate: z.boolean().optional(), maxPlayers: z.number().int().optional(), rules: z.record(z.unknown()).optional() }),
  z.object({ type: z.literal('room.join'), reqId: z.string().optional(), roomId: z.string(), inviteCode: z.string().optional() }),
  z.object({ type: z.literal('room.spectate'), reqId: z.string().optional(), roomId: z.string() }),
  z.object({ type: z.literal('room.leave'), reqId: z.string().optional() }),
  z.object({ type: z.literal('room.ready'), reqId: z.string().optional(), ready: z.boolean() }),
  z.object({ type: z.literal('room.invite'), reqId: z.string().optional(), roomId: z.string(), userId: z.string() }),
  z.object({ type: z.literal('room.kick'), reqId: z.string().optional(), userId: z.string() }),
  z.object({ type: z.literal('room.start'), reqId: z.string().optional() }),
  z.object({ type: z.literal('room.rematch'), reqId: z.string().optional() }),
  z.object({ type: z.literal('room.resync'), reqId: z.string().optional(), afterSeq: z.number().int().min(0).optional() }),
  z.object({ type: z.literal('voice.state'), reqId: z.string().optional(), micActive: z.boolean(), muted: z.boolean() }),
  z.object({ type: z.literal('matchmaking.join'), reqId: z.string().optional(), gameId: z.string(), tableSize: z.number().int().optional() }),
  z.object({ type: z.literal('matchmaking.leave'), reqId: z.string().optional() }),
  z.object({
    type: z.literal('game.action'),
    reqId: z.string().optional(),
    roomId: z.string(),
    matchId: z.string(),
    /** Version the client believes the state is at; mismatches are rejected and resynced. */
    version: z.number().int().optional(),
    action: z.unknown(),
  }),
]);

export type ClientMessage = z.infer<typeof ClientMessageSchema>;
