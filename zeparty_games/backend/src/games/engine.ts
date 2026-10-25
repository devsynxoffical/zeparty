/**
 * Shared contract every ZeParty game engine implements. Engines are pure: they take state
 * and an action and return new state plus events. The room layer owns persistence,
 * sequencing, timers and broadcasting. Nothing in an engine trusts the client.
 */
export interface PlayerSeat {
  seat: number;
  userId: string;
  displayName: string;
}

export interface Rng {
  /** Integer in [min, max] inclusive. */
  int(min: number, max: number): number;
  /** Float in [0, 1). */
  float(): number;
}

export interface GameEvent {
  type: string;
  seat?: number;
  payload: Record<string, unknown>;
}

export interface EngineStep<S> {
  state: S;
  events: GameEvent[];
}

export type Validation = { ok: true } | { ok: false; code: string; message: string };

export interface MatchResult {
  finished: boolean;
  /** Seats ordered by placement, first is winner. Only meaningful when finished. */
  placements: Array<{ seat: number; placement: number; score: number }>;
  winnerSeats: number[];
}

export interface GameEngine<S, A> {
  readonly gameId: string;
  createInitialState(players: PlayerSeat[], rules: Record<string, unknown>, rng: Rng): S;
  /** Returns the seat whose action is currently expected, or null when no one (finished). */
  currentSeat(state: S): number | null;
  validateAction(state: S, seat: number, action: A): Validation;
  applyAction(state: S, seat: number, action: A, rng: Rng): EngineStep<S>;
  /** Called when the current seat's turn timer expires. Must always advance the game. */
  onTimeout(state: S, rng: Rng): EngineStep<S>;
  /** Called when a player permanently leaves. Engine decides forfeit semantics. */
  onPlayerLeft(state: S, seat: number, rng: Rng): EngineStep<S>;
  getResult(state: S): MatchResult;
  /** Projection sent to a given viewer. Hidden information must be stripped here. */
  getView(state: S, viewerSeat: number | null): unknown;
  getLegalActions(state: S, seat: number): A[];
}

/** Deterministic PRNG (mulberry32) for tests and replay. Production uses CryptoRng. */
export class SeededRng implements Rng {
  private a: number;
  constructor(seed: number) {
    this.a = seed >>> 0;
  }
  float(): number {
    let t = (this.a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }
  int(min: number, max: number): number {
    return min + Math.floor(this.float() * (max - min + 1));
  }
}

export class CryptoRng implements Rng {
  private readonly crypto = globalThis.crypto;
  float(): number {
    const buf = new Uint32Array(1);
    this.crypto.getRandomValues(buf);
    return (buf[0] ?? 0) / 4294967296;
  }
  int(min: number, max: number): number {
    // rejection sampling to avoid modulo bias
    const range = max - min + 1;
    const limit = Math.floor(4294967296 / range) * range;
    const buf = new Uint32Array(1);
    let v: number;
    do {
      this.crypto.getRandomValues(buf);
      v = buf[0] ?? 0;
    } while (v >= limit);
    return min + (v % range);
  }
}

/**
 * Real-time games (air hockey) advance on a server clock instead of player turns.
 * The room layer calls `tick` at `tickRateHz` and broadcasts accumulated events plus a
 * compact `state_tick` at `broadcastHz`. `currentSeat` should return null and
 * `turnDeadline` must be null so the turn timer stays off.
 */
export interface RealtimeEngine<S, A> extends GameEngine<S, A> {
  readonly tickRateHz: number;
  readonly broadcastHz: number;
  tick(state: S, dtMs: number, rng: Rng): EngineStep<S>;
}

export function isRealtimeEngine<S, A>(e: GameEngine<S, A>): e is RealtimeEngine<S, A> {
  return typeof (e as RealtimeEngine<S, A>).tick === 'function' && typeof (e as RealtimeEngine<S, A>).tickRateHz === 'number';
}
