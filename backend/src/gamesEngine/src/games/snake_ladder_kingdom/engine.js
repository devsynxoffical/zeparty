import { getLayout } from './layouts.js';
import { resolveSnakeLadderRules } from './rules.js';
export const SL_COLOR_ORDER = ['red', 'green', 'yellow', 'blue'];
export function slColorsForPlayerCount(n) {
    if (n === 2)
        return ['red', 'yellow'];
    if (n === 3)
        return ['red', 'green', 'yellow'];
    return [...SL_COLOR_ORDER];
}
const NOW = () => Date.now();
export class SnakeLadderEngine {
    now;
    gameId = 'snake_ladder_kingdom';
    constructor(now = NOW) {
        this.now = now;
    }
    createInitialState(players, rulesInput, _rng) {
        if (players.length < 2 || players.length > 4)
            throw new Error('snake & ladder requires 2 to 4 players');
        const rules = resolveSnakeLadderRules(rulesInput);
        const layout = getLayout(rules.boardSize, rules.layout);
        const colors = slColorsForPlayerCount(players.length);
        const seats = players.map((p, i) => ({
            seat: p.seat,
            userId: p.userId,
            displayName: p.displayName,
            color: colors[i],
            position: 0,
            finishedPlacement: null,
            consecutiveTimeouts: 0,
            forfeited: false,
            connected: true,
        }));
        const t = this.now();
        return {
            rules,
            layout: structuredClone(layout),
            seats,
            turnSeat: seats[0].seat,
            phase: 'roll',
            dice: null,
            version: 0,
            placements: [],
            turnStartedAt: t,
            turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
            lastEvent: null,
        };
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
    validateAction(state, seat, action) {
        if (state.phase === 'finished')
            return { ok: false, code: 'match_finished', message: 'match is over' };
        if (state.turnSeat !== seat)
            return { ok: false, code: 'not_your_turn', message: 'not your turn' };
        const me = this.seatState(state, seat);
        if (me.forfeited || me.finishedPlacement !== null)
            return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
        if (!action || action.type !== 'roll')
            return { ok: false, code: 'bad_action', message: 'unknown action' };
        return { ok: true };
    }
    getLegalActions(state, seat) {
        if (state.phase === 'finished' || state.turnSeat !== seat)
            return [];
        return [{ type: 'roll' }];
    }
    applyAction(state, seat, action, rng) {
        const v = this.validateAction(state, seat, action);
        if (!v.ok)
            throw new Error(`${v.code}: ${v.message}`);
        const next = structuredClone(state);
        const events = [];
        this.doRoll(next, seat, rng.int(1, 6), events);
        next.version += 1;
        return { state: next, events };
    }
    /**
     * Resolve a roll: entering, walking, bounce back, ladder or snake, finishing, extra turn.
     * Pure function of state + value so timeouts and actions share it.
     */
    doRoll(state, seat, value, events) {
        const r = state.rules;
        const me = this.seatState(state, seat);
        const N = r.boardSize;
        state.dice = value;
        events.push({ type: 'dice_rolled', seat, payload: { value } });
        if (me.position === 0 && r.unlockRoll > 0 && value !== r.unlockRoll) {
            events.push({ type: 'no_move', seat, payload: { value, reason: 'locked' } });
            this.advanceTurn(state, events, r.extraTurnOnSix && value === 6);
            return;
        }
        const from = me.position;
        const raw = from + value;
        let to = raw;
        const path = [];
        let bounce = null;
        if (raw > N) {
            if (r.exactFinish) {
                to = N - (raw - N);
                for (let s = from + 1; s <= N; s++)
                    path.push(s);
                for (let s = N - 1; s >= to; s--)
                    path.push(s);
                bounce = { peak: N, to };
            }
            else {
                to = N;
                for (let s = from + 1; s <= N; s++)
                    path.push(s);
            }
        }
        else {
            for (let s = from + 1; s <= to; s++)
                path.push(s);
        }
        me.position = to;
        events.push({ type: 'token_moved', seat, payload: { from, to, path, dice: value } });
        if (bounce)
            events.push({ type: 'bounce_back', seat, payload: { from: from, peak: bounce.peak, to: bounce.to } });
        const ladder = state.layout.ladders.find((l) => l.from === to);
        if (ladder) {
            me.position = ladder.to;
            events.push({ type: 'ladder_climbed', seat, payload: { from: ladder.from, to: ladder.to } });
        }
        else {
            const snake = state.layout.snakes.find((s) => s.from === to);
            if (snake) {
                me.position = snake.to;
                events.push({ type: 'snake_slid', seat, payload: { from: snake.from, to: snake.to } });
            }
        }
        let extraTurn = r.extraTurnOnSix && value === 6;
        if (me.position === N) {
            me.finishedPlacement = state.placements.length + 1;
            state.placements.push(seat);
            events.push({ type: 'player_finished', seat, payload: { placement: me.finishedPlacement } });
            extraTurn = false;
        }
        if (this.checkMatchEnd(state, events))
            return;
        this.advanceTurn(state, events, extraTurn);
    }
    activeSeats(state) {
        return state.seats.filter((s) => !s.forfeited && s.finishedPlacement === null);
    }
    checkMatchEnd(state, events) {
        const active = this.activeSeats(state);
        const finishedCount = state.placements.length;
        const end = active.length <= 1 || (state.rules.endOnFirstWinner && finishedCount >= 1) || (state.seats.length === 2 && finishedCount >= 1);
        if (!end)
            return false;
        const byProgress = [...active].sort((a, b) => b.position - a.position);
        for (const s of byProgress) {
            s.finishedPlacement = state.placements.length + 1;
            state.placements.push(s.seat);
        }
        for (const s of state.seats.filter((x) => x.forfeited && x.finishedPlacement === null)) {
            s.finishedPlacement = state.placements.length + 1;
            state.placements.push(s.seat);
        }
        state.phase = 'finished';
        state.turnDeadline = null;
        state.lastEvent = 'match_finished';
        events.push({ type: 'match_finished', payload: { placements: [...state.placements] } });
        return true;
    }
    advanceTurn(state, events, extraTurn) {
        if (state.phase === 'finished')
            return;
        state.phase = 'roll';
        if (extraTurn) {
            events.push({ type: 'extra_turn', seat: state.turnSeat, payload: {} });
            this.resetTurnClock(state);
            return;
        }
        const order = state.seats.map((s) => s.seat);
        let idx = order.indexOf(state.turnSeat);
        for (let i = 0; i < order.length; i++) {
            idx = (idx + 1) % order.length;
            const cand = this.seatState(state, order[idx]);
            if (!cand.forfeited && cand.finishedPlacement === null) {
                state.turnSeat = cand.seat;
                break;
            }
        }
        this.resetTurnClock(state);
        events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline } });
    }
    resetTurnClock(state) {
        const t = this.now();
        state.turnStartedAt = t;
        state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
    }
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
            me.forfeited = true;
            events.push({ type: 'player_forfeited', seat, payload: { reason: 'timeouts' } });
            if (!this.checkMatchEnd(next, events))
                this.advanceTurn(next, events, false);
            next.version += 1;
            return { state: next, events };
        }
        // Idle player: the server rolls for them so the match always advances.
        this.doRoll(next, seat, rng.int(1, 6), events);
        next.version += 1;
        return { state: next, events };
    }
    onPlayerLeft(state, seat, _rng) {
        if (state.phase === 'finished')
            return { state, events: [] };
        const next = structuredClone(state);
        const events = [];
        const me = this.seatState(next, seat);
        if (me.forfeited || me.finishedPlacement !== null)
            return { state, events: [] };
        me.forfeited = true;
        me.connected = false;
        events.push({ type: 'player_forfeited', seat, payload: { reason: 'left' } });
        if (!this.checkMatchEnd(next, events) && next.turnSeat === seat)
            this.advanceTurn(next, events, false);
        next.version += 1;
        return { state: next, events };
    }
    getResult(state) {
        const finished = state.phase === 'finished';
        const placements = state.seats
            .map((s) => ({ seat: s.seat, placement: s.finishedPlacement ?? state.seats.length, score: s.position }))
            .sort((a, b) => a.placement - b.placement);
        return { finished, placements, winnerSeats: finished && placements[0] ? [placements[0].seat] : [] };
    }
    /** No hidden information; the whole state is the view. */
    getView(state, _viewerSeat) {
        return state;
    }
}
