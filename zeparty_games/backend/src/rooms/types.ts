import type { GameEvent } from '../games/engine.js';

export type RoomStatus = 'waiting' | 'playing' | 'finished';

export interface RoomPlayer {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  seat: number;
  ready: boolean;
  connected: boolean;
  /** Set while disconnected during an active match; cleared on reconnect. */
  disconnectedAt: number | null;
  /** Voice state mirrored from the host app; informational overlay for other players. */
  micActive: boolean;
  muted: boolean;
}

export interface SequencedEvent {
  seq: number;
  at: number;
  actorSeat: number | null;
  event: GameEvent;
}

export interface MatchRuntime {
  matchId: string;
  gameId: string;
  state: unknown;
  /** Last sequence number assigned. Events are 1-based. */
  seq: number;
  events: SequencedEvent[];
  startedAt: number;
  endedAt: number | null;
  rewardsGranted: boolean;
}

export interface Room {
  roomId: string;
  gameId: string;
  hostUserId: string;
  isPrivate: boolean;
  inviteCode: string;
  rules: Record<string, unknown>;
  maxPlayers: number;
  minPlayers: number;
  players: RoomPlayer[];
  spectators: string[];
  invitedUserIds: string[];
  status: RoomStatus;
  match: MatchRuntime | null;
  createdAt: number;
  /** Set when the previous match finished and players vote for a rematch. */
  rematchVotes: string[];
}

export interface RoomSummary {
  roomId: string;
  gameId: string;
  hostUserId: string;
  isPrivate: boolean;
  status: RoomStatus;
  playerCount: number;
  maxPlayers: number;
  createdAt: number;
}

/** Public projection of a room for clients. */
export function toRoomView(room: Room): Omit<Room, 'match' | 'inviteCode'> & { inviteCode: string | null; matchId: string | null } {
  const { match, inviteCode, ...rest } = room;
  return { ...rest, inviteCode: room.isPrivate ? inviteCode : null, matchId: match?.matchId ?? null };
}
