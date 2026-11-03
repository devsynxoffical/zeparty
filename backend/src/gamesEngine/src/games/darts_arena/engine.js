import { resolveDartsRules, x01Start } from './rules.js';
import { BOARD_GEOMETRY, BULL, SEGMENTS, computeLanding, scoreAt } from './scoring.js';
export const CRICKET_NUMBERS = [20, 19, 18, 17, 16, 15, BULL];
export const DARTS_PER_VISIT = 3;
/** Around the clock: targets 1..20 then the bull (25); `CLOCK_DONE` means the leg is won. */
export const CLOCK_BULL = 25;
export const CLOCK_DONE = 26;
const NOW = () => Date.now();
export class DartsEngine {
    now;
    gameId = 'darts_arena';
    constructor(now = NOW) {
        this.now = now;
    }
    createInitialState(players, rulesInput, _rng) {
        if (players.length < 2 || players.length > 4)
            throw new Error('darts requires 2 to 4 players');
        const rules = resolveDartsRules(rulesInput);
        const seats = players.map((p) => ({
            seat: p.seat,
            userId: p.userId,
            displayName: p.displayName,
            remaining: 0,
            inOpen: false,
            marks: {},
            points: 0,
            clockTarget: 1,
            legsWon: 0,
            finishedPlacement: null,
            consecutiveTimeouts: 0,
            forfeited: false,
            connected: true,
        }));
        const t = this.now();
        const state = {
            rules,
            format: rules.format,
            seats,
            turnSeat: seats[0].seat,
            phase: 'throw',
            leg: 1,
            legStarterSeat: seats[0].seat,
            dartIndex: 0,
            visit: [],
            visitStartRemaining: 0,
            lastVisit: null,
            legWinners: [],
            version: 0,
            placements: [],
            turnStartedAt: t,
            turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
            lastEvent: null,
            board: { ...BOARD_GEOMETRY, segments: [...SEGMENTS] },
        };
        for (const s of seats)
            this.resetSeatForLeg(state, s);
        state.visitStartRemaining = seats[0].remaining;
        return state;
    }
    resetSeatForLeg(state, s) {
        const start = x01Start(state.format);
        s.remaining = start ?? 0;
        s.inOpen = !state.rules.doubleIn;
        s.marks = Object.fromEntries(CRICKET_NUMBERS.map((n) => [String(n), 0]));
        s.points = 0;
        s.clockTarget = 1;
    }
    currentSeat(state) {
        return state.phase === 'finished' ? null : state.turnSeat;
    }
    seatState(state, seat) {
        const s = state.seats.find((x) => x.seat === seat);
        if (!s)
            throw new Error(`unknown seat ${seat}`);
        return s;
    }
    activeSeats(state) {
        return state.seats.filter((s) => !s.forfeited);
    }
    validateAction(state, seat, action) {
        if (state.phase === 'finished')
            return { ok: false, code: 'match_finished', message: 'match is over' };
        if (state.turnSeat !== seat)
            return { ok: false, code: 'not_your_turn', message: 'not your turn' };
        const me = this.seatState(state, seat);
        if (me.forfeited)
            return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
        if (action.type !== 'throw')
            return { ok: false, code: 'bad_action', message: 'unknown action' };
        const { aimX, aimY, release } = action;
        if (![aimX, aimY, release].every((v) => typeof v === 'number' && Number.isFinite(v))) {
            return { ok: false, code: 'bad_throw', message: 'aim and release must be finite numbers' };
        }
        if (Math.hypot(aimX, aimY) > BOARD_GEOMETRY.maxAimRadius)
            return { ok: false, code: 'bad_aim', message: 'aim is off the board' };
        if (release < 0 || release > 1)
            return { ok: false, code: 'bad_release', message: 'release must be within 0..1' };
        return { ok: true };
    }
    getLegalActions(state, seat) {
        if (state.phase === 'finished' || state.turnSeat !== seat)
            return [];
        // Continuous action space: return a representative throw at the bull.
        return [{ type: 'throw', aimX: 0, aimY: 0, release: 1 }];
    }
    applyAction(state, seat, action, rng) {
        const v = this.validateAction(state, seat, action);
        if (!v.ok)
            throw new Error(`${v.code}: ${v.message}`);
        const next = structuredClone(state);
        const events = [];
        this.seatState(next, seat).consecutiveTimeouts = 0;
        this.throwDart(next, seat, action.aimX, action.aimY, action.release, rng, events);
        next.version += 1;
        return { state: next, events };
    }
    // ---------------------------------------------------------------------------
    // Throw resolution
    // ---------------------------------------------------------------------------
    throwDart(state, seat, aimX, aimY, release, rng, events) {
        const landing = computeLanding(aimX, aimY, release, state.rules.baseSigma, rng);
        const score = scoreAt(landing.x, landing.y);
        const me = this.seatState(state, seat);
        const dart = {
            dartIndex: state.dartIndex,
            aim: { x: aimX, y: aimY },
            landed: { x: landing.x, y: landing.y },
            segment: score.segment,
            multiplier: score.multiplier,
            points: score.points,
            label: score.label,
        };
        if (score.multiplier === 0)
            dart.miss = true;
        let outcome;
        switch (state.format) {
            case '501':
            case '301':
                outcome = this.applyX01(state, me, score, dart);
                break;
            case 'cricket':
                outcome = this.applyCricket(state, me, score);
                break;
            case 'around_the_clock':
                outcome = this.applyClock(me, score);
                break;
        }
        if (outcome === 'bust')
            dart.bust = true;
        state.visit.push(dart);
        events.push({ type: 'dart_thrown', seat, payload: { ...dart, seat, sigma: landing.sigma } });
        state.lastEvent = 'dart_thrown';
        if (outcome === 'bust') {
            events.push({ type: 'bust', seat, payload: { remaining: me.remaining } });
            this.endVisit(state, seat, 0, events);
            return;
        }
        if (outcome === 'leg_won') {
            this.winLeg(state, seat, events);
            return;
        }
        state.dartIndex += 1;
        if (state.dartIndex >= DARTS_PER_VISIT) {
            this.endVisit(state, seat, this.visitScore(state), events);
        }
    }
    visitScore(state) {
        return state.visit.reduce((a, d) => a + (d.bust ? 0 : d.points), 0);
    }
    applyX01(state, me, score, dart) {
        const r = state.rules;
        if (!me.inOpen) {
            if (score.multiplier !== 2) {
                // Not in yet: the dart counts for nothing, no bust.
                dart.points = 0;
                return 'continue';
            }
            me.inOpen = true;
        }
        const after = me.remaining - score.points;
        if (after < 0)
            return this.bustX01(state, me);
        if (r.doubleOut) {
            if (after === 1)
                return this.bustX01(state, me);
            if (after === 0 && score.multiplier !== 2)
                return this.bustX01(state, me);
        }
        me.remaining = after;
        return after === 0 ? 'leg_won' : 'continue';
    }
    bustX01(state, me) {
        me.remaining = state.visitStartRemaining;
        return 'bust';
    }
    applyCricket(state, me, score) {
        if (score.multiplier === 0 || !CRICKET_NUMBERS.includes(score.segment))
            return 'continue';
        const key = String(score.segment);
        const value = score.segment; // bull scores 25 per mark
        const others = this.activeSeats(state).filter((s) => s.seat !== me.seat);
        for (let i = 0; i < score.multiplier; i++) {
            const have = me.marks[key] ?? 0;
            if (have < 3) {
                me.marks[key] = have + 1;
            }
            else if (others.some((o) => (o.marks[key] ?? 0) < 3)) {
                me.points += value;
            }
        }
        const allClosed = CRICKET_NUMBERS.every((n) => (me.marks[String(n)] ?? 0) >= 3);
        if (allClosed && others.every((o) => me.points >= o.points))
            return 'leg_won';
        return 'continue';
    }
    applyClock(me, score) {
        if (score.multiplier === 0)
            return 'continue';
        if (score.segment !== me.clockTarget)
            return 'continue';
        me.clockTarget = me.clockTarget === 20 ? CLOCK_BULL : me.clockTarget === CLOCK_BULL ? CLOCK_DONE : me.clockTarget + 1;
        return me.clockTarget === CLOCK_DONE ? 'leg_won' : 'continue';
    }
    // ---------------------------------------------------------------------------
    // Visits, turns, legs
    // ---------------------------------------------------------------------------
    endVisit(state, seat, visitScore, events) {
        const me = this.seatState(state, seat);
        events.push({ type: 'visit_ended', seat, payload: { visitScore, remaining: me.remaining, points: me.points, clockTarget: me.clockTarget } });
        state.lastVisit = { seat, darts: [...state.visit], score: visitScore };
        this.advanceTurn(state, events);
    }
    advanceTurn(state, events) {
        if (state.phase === 'finished')
            return;
        const order = state.seats.map((s) => s.seat);
        let idx = order.indexOf(state.turnSeat);
        for (let i = 0; i < order.length; i++) {
            idx = (idx + 1) % order.length;
            const cand = this.seatState(state, order[idx]);
            if (!cand.forfeited) {
                state.turnSeat = cand.seat;
                break;
            }
        }
        this.startVisit(state, events);
    }
    startVisit(state, events) {
        state.visit = [];
        state.dartIndex = 0;
        state.visitStartRemaining = this.seatState(state, state.turnSeat).remaining;
        this.resetTurnClock(state);
        events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, leg: state.leg } });
    }
    resetTurnClock(state) {
        const t = this.now();
        state.turnStartedAt = t;
        state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
    }
    winLeg(state, seat, events) {
        const me = this.seatState(state, seat);
        me.legsWon += 1;
        state.legWinners.push(seat);
        const visitScore = this.visitScore(state);
        events.push({ type: 'leg_won', seat, payload: { leg: state.leg, legsWon: me.legsWon, legsToWin: state.rules.legsToWin, visitScore } });
        state.lastVisit = { seat, darts: [...state.visit], score: visitScore };
        if (me.legsWon >= state.rules.legsToWin) {
            this.finishMatch(state, events, seat);
            return;
        }
        // Next leg: the player after the previous starter throws first.
        state.leg += 1;
        for (const s of state.seats)
            this.resetSeatForLeg(state, s);
        const order = state.seats.map((s) => s.seat);
        let idx = order.indexOf(state.legStarterSeat);
        for (let i = 0; i < order.length; i++) {
            idx = (idx + 1) % order.length;
            const cand = this.seatState(state, order[idx]);
            if (!cand.forfeited) {
                state.legStarterSeat = cand.seat;
                break;
            }
        }
        state.turnSeat = state.legStarterSeat;
        events.push({ type: 'leg_started', payload: { leg: state.leg, starterSeat: state.turnSeat } });
        this.startVisit(state, events);
    }
    /** Progress used to order non-winning seats: higher is better. */
    progress(state, s) {
        const legs = s.legsWon * 1_000_000;
        switch (state.format) {
            case '501':
            case '301':
                return legs + ((x01Start(state.format) ?? 0) - s.remaining);
            case 'cricket': {
                const marks = CRICKET_NUMBERS.reduce((a, n) => a + Math.min(3, s.marks[String(n)] ?? 0), 0);
                return legs + marks * 1000 + s.points;
            }
            case 'around_the_clock':
                return legs + s.clockTarget;
        }
    }
    finishMatch(state, events, winnerSeat) {
        const placements = [];
        if (winnerSeat !== null)
            placements.push(winnerSeat);
        const rest = state.seats.filter((s) => s.seat !== winnerSeat && !s.forfeited).sort((a, b) => this.progress(state, b) - this.progress(state, a));
        for (const s of rest)
            placements.push(s.seat);
        const forfeited = state.seats.filter((s) => s.forfeited && s.seat !== winnerSeat).sort((a, b) => this.progress(state, b) - this.progress(state, a));
        for (const s of forfeited)
            placements.push(s.seat);
        placements.forEach((seat, i) => {
            this.seatState(state, seat).finishedPlacement = i + 1;
        });
        state.placements = placements;
        state.phase = 'finished';
        state.turnDeadline = null;
        state.lastEvent = 'match_finished';
        events.push({ type: 'match_finished', payload: { placements: [...placements] } });
    }
    // ---------------------------------------------------------------------------
    // Timeouts and leaving
    // ---------------------------------------------------------------------------
    onTimeout(state, rng) {
        if (state.phase === 'finished')
            return { state, events: [] };
        const next = structuredClone(state);
        const events = [];
        const seat = next.turnSeat;
        const me = this.seatState(next, seat);
        me.consecutiveTimeouts += 1;
        events.push({ type: 'turn_timeout', seat, payload: { count: me.consecutiveTimeouts } });
        if (me.consecutiveTimeouts >= next.rules.timeoutsToForfeit) {
            this.forfeit(next, seat, 'timeouts', events);
            next.version += 1;
            return { state: next, events };
        }
        // Throw the rest of the visit for the idle player: low quality darts aimed loosely at the board.
        const guard = DARTS_PER_VISIT + 1;
        for (let i = 0; i < guard && next.phase === 'throw' && next.turnSeat === seat; i++) {
            const a = rng.float() * Math.PI * 2;
            const r = rng.float() * 0.5;
            this.throwDart(next, seat, Math.sin(a) * r, -Math.cos(a) * r, 0.1, rng, events);
        }
        next.version += 1;
        return { state: next, events };
    }
    forfeit(state, seat, reason, events) {
        const me = this.seatState(state, seat);
        me.forfeited = true;
        events.push({ type: 'player_forfeited', seat, payload: { reason } });
        const active = this.activeSeats(state);
        if (active.length <= 1) {
            this.finishMatch(state, events, active[0]?.seat ?? null);
            return;
        }
        if (state.turnSeat === seat) {
            state.lastVisit = state.visit.length > 0 ? { seat, darts: [...state.visit], score: this.visitScore(state) } : state.lastVisit;
            this.advanceTurn(state, events);
        }
    }
    onPlayerLeft(state, seat, _rng) {
        if (state.phase === 'finished')
            return { state, events: [] };
        const next = structuredClone(state);
        const me = this.seatState(next, seat);
        if (me.forfeited)
            return { state, events: [] };
        const events = [];
        me.connected = false;
        this.forfeit(next, seat, 'left', events);
        next.version += 1;
        return { state: next, events };
    }
    getResult(state) {
        const finished = state.phase === 'finished';
        const placements = state.seats
            .map((s) => ({ seat: s.seat, placement: s.finishedPlacement ?? state.seats.length, score: this.progress(state, s) }))
            .sort((a, b) => a.placement - b.placement);
        return { finished, placements, winnerSeats: finished && placements[0] ? [placements[0].seat] : [] };
    }
    /** Darts has no hidden information; the full state is the view. */
    getView(state, _viewerSeat) {
        return state;
    }
}
