import { clamp, nearestFreeSpot, placementBlocked, simulateShot } from './physics.js';
import { resolvePoolRules } from './rules.js';
import { BALL_RADIUS, CUE, EIGHT, FOOT_SPOT, HEAD_SPOT, HEAD_STRING_X, RACK_APEX_SLOT, RACK_BACK_CORNERS, RACK_EIGHT_SLOT, isSolid, isStripe, rackSlots, round3, tableSpec, } from './table.js';
const NOW = () => Date.now();
export function groupOf(id) {
    if (id === CUE)
        return 'cue';
    if (id === EIGHT)
        return 'eight';
    return isSolid(id) ? 'solids' : 'stripes';
}
export function otherGroup(g) {
    return g === 'solids' ? 'stripes' : 'solids';
}
export class PoolEliteEngine {
    now;
    gameId = 'pool_elite';
    constructor(now = NOW) {
        this.now = now;
    }
    // ---------------------------------------------------------------------------
    // Setup
    // ---------------------------------------------------------------------------
    createInitialState(players, rulesInput, rng) {
        if (players.length !== 2)
            throw new Error('pool requires exactly 2 players');
        const rules = resolvePoolRules(rulesInput);
        const seats = players.map((p) => ({
            seat: p.seat,
            userId: p.userId,
            displayName: p.displayName,
            group: null,
            fouls: 0,
            consecutiveTimeouts: 0,
            forfeited: false,
            connected: true,
        }));
        const t = this.now();
        return {
            rules,
            table: tableSpec(),
            seats,
            balls: rackBalls(rng),
            turnSeat: seats[0].seat,
            phase: 'break',
            openTable: true,
            ballInHand: true,
            cueBehindHeadString: true,
            shotCount: 0,
            lastShot: null,
            winnerSeat: null,
            finishReason: null,
            placements: [],
            version: 0,
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
    opponentOf(state, seat) {
        const o = state.seats.find((x) => x.seat !== seat);
        if (!o)
            throw new Error('no opponent');
        return o;
    }
    // ---------------------------------------------------------------------------
    // Validation
    // ---------------------------------------------------------------------------
    validateAction(state, seat, action) {
        if (state.phase === 'finished')
            return { ok: false, code: 'match_finished', message: 'match is over' };
        if (state.turnSeat !== seat)
            return { ok: false, code: 'not_your_turn', message: 'not your turn' };
        const me = this.seatState(state, seat);
        if (me.forfeited)
            return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
        if (action.type === 'shot') {
            if (!Number.isFinite(action.angle))
                return { ok: false, code: 'bad_angle', message: 'angle must be a finite number' };
            if (!Number.isFinite(action.power) || action.power < 0 || action.power > 1)
                return { ok: false, code: 'bad_power', message: 'power must be within 0..1' };
            if (action.spin !== undefined) {
                const { x, y } = action.spin;
                if (!Number.isFinite(x) || !Number.isFinite(y) || Math.abs(x) > 1 || Math.abs(y) > 1)
                    return { ok: false, code: 'bad_spin', message: 'spin components must be within -1..1' };
            }
            return { ok: true };
        }
        if (action.type === 'place_cue') {
            if (!state.ballInHand)
                return { ok: false, code: 'not_ball_in_hand', message: 'cue ball is not in hand' };
            if (!Number.isFinite(action.x) || !Number.isFinite(action.y))
                return { ok: false, code: 'bad_position', message: 'position must be finite' };
            return this.validatePlacement(state, action.x, action.y);
        }
        return { ok: false, code: 'bad_action', message: 'unknown action' };
    }
    validatePlacement(state, x, y) {
        const others = state.balls.filter((b) => !b.pocketed && b.id !== CUE);
        if (state.cueBehindHeadString && x > HEAD_STRING_X)
            return { ok: false, code: 'behind_head_string', message: 'cue ball must be placed behind the head string' };
        if (placementBlocked(x, y, others))
            return { ok: false, code: 'bad_placement', message: 'cue ball must be on the cloth and clear of other balls' };
        return { ok: true };
    }
    getLegalActions(state, seat) {
        if (state.phase === 'finished' || state.turnSeat !== seat)
            return [];
        const out = [this.autoShot(state, seat, null)];
        if (state.ballInHand) {
            const cue = this.cueBall(state);
            out.push({ type: 'place_cue', x: cue.x, y: cue.y });
        }
        return out;
    }
    // ---------------------------------------------------------------------------
    // Actions
    // ---------------------------------------------------------------------------
    applyAction(state, seat, action, _rng) {
        const v = this.validateAction(state, seat, action);
        if (!v.ok)
            throw new Error(`${v.code}: ${v.message}`);
        const next = structuredClone(state);
        const events = [];
        if (action.type === 'place_cue') {
            const cue = this.cueBall(next);
            cue.x = round3(action.x);
            cue.y = round3(action.y);
            cue.pocketed = false;
            events.push({ type: 'cue_placed', seat, payload: { x: cue.x, y: cue.y } });
            next.lastEvent = 'cue_placed';
        }
        else {
            this.resolveShot(next, seat, action, events);
        }
        next.version += 1;
        return { state: next, events };
    }
    cueBall(state) {
        const c = state.balls.find((b) => b.id === CUE);
        if (!c)
            throw new Error('cue ball missing');
        return c;
    }
    onTable(state) {
        return state.balls.filter((b) => !b.pocketed);
    }
    remainingOf(state, group) {
        return state.balls.filter((b) => !b.pocketed && groupOf(b.id) === group).length;
    }
    /** Balls the shooter may legally contact first. */
    legalFirstContacts(state, seat) {
        const me = this.seatState(state, seat);
        const live = this.onTable(state).filter((b) => b.id !== CUE);
        if (state.phase === 'break')
            return live.map((b) => b.id);
        if (state.openTable || me.group === null)
            return live.filter((b) => b.id !== EIGHT).map((b) => b.id);
        const own = live.filter((b) => groupOf(b.id) === me.group);
        if (own.length > 0)
            return own.map((b) => b.id);
        return live.filter((b) => b.id === EIGHT).map((b) => b.id);
    }
    resolveShot(state, seat, action, events) {
        const me = this.seatState(state, seat);
        const opp = this.opponentOf(state, seat);
        const isBreak = state.phase === 'break';
        const legalFirst = new Set(this.legalFirstContacts(state, seat));
        const ownRemainingBefore = me.group ? this.remainingOf(state, me.group) : null;
        const spin = { x: clamp(action.spin?.x ?? 0, -1, 1), y: clamp(action.spin?.y ?? 0, -1, 1) };
        const bodies = this.onTable(state).map((b) => ({ id: b.id, x: b.x, y: b.y }));
        const sim = simulateShot(bodies, { angle: action.angle, power: action.power, spin });
        // Apply final positions.
        const pocketedIds = new Set(sim.pocketed.map((p) => p.id));
        for (const b of state.balls) {
            if (b.pocketed)
                continue;
            if (pocketedIds.has(b.id)) {
                b.pocketed = true;
                continue;
            }
            const f = sim.final.find((x) => x.id === b.id);
            if (f) {
                b.x = f.x;
                b.y = f.y;
            }
        }
        const objectPocketed = sim.pocketed.map((p) => p.id).filter((id) => id !== CUE);
        // Fouls
        const fouls = [];
        if (sim.cueScratched)
            fouls.push('scratch');
        if (sim.firstContact === null)
            fouls.push('no_contact');
        else if (!legalFirst.has(sim.firstContact))
            fouls.push('wrong_first_contact');
        if (sim.firstContact !== null && objectPocketed.length === 0 && !sim.railAfterContact)
            fouls.push('no_rail');
        if (fouls.length > 0)
            me.fouls += 1;
        state.shotCount += 1;
        state.ballInHand = false;
        state.cueBehindHeadString = false;
        state.lastShot = { seat, pocketed: sim.pocketed.map((p) => p.id), fouls, firstContact: sim.firstContact, railContacted: sim.railAfterContact, cueScratched: sim.cueScratched, isBreak };
        state.lastEvent = 'shot_resolved';
        const payload = {
            frames: sim.frames,
            collisions: sim.collisions,
            pocketed: sim.pocketed.map((p) => ({ id: p.id, by: seat, pocket: p.pocket, t: p.t })),
            fouls,
            firstContact: sim.firstContact,
            railContacted: sim.railAfterContact,
            cueScratched: sim.cueScratched,
            isBreak,
            duration: sim.duration,
            final: sim.final,
            shot: { angle: action.angle, power: action.power, spin },
        };
        events.push({ type: 'shot_resolved', seat, payload });
        const eightPocketed = objectPocketed.includes(EIGHT);
        if (isBreak) {
            state.phase = 'play';
            if (eightPocketed) {
                if (state.rules.eightOnBreak === 'win' && fouls.length === 0) {
                    this.finish(state, seat, 'eight_on_break', events);
                    return;
                }
                this.respotEight(state, events);
            }
            if (fouls.length > 0) {
                this.giveBallInHand(state, opp.seat, sim.cueScratched, !state.rules.ballInHandAnywhere, events);
                this.changeTurn(state, opp.seat, events);
                return;
            }
            if (objectPocketed.some((id) => id !== EIGHT)) {
                this.continueTurn(state, seat, events);
                return;
            }
            this.changeTurn(state, opp.seat, events);
            return;
        }
        if (eightPocketed) {
            const cleared = me.group !== null && ownRemainingBefore === 0;
            if (cleared && fouls.length === 0) {
                this.finish(state, seat, 'eight_ball', events);
            }
            else if (!cleared) {
                this.finish(state, opp.seat, 'early_eight', events);
            }
            else if (sim.cueScratched) {
                this.finish(state, opp.seat, 'scratch_on_eight', events);
            }
            else {
                this.finish(state, opp.seat, 'foul_on_eight', events);
            }
            return;
        }
        // Group assignment on the first legal pocket after the break.
        if (state.openTable && fouls.length === 0) {
            const solids = objectPocketed.filter(isSolid).length;
            const stripes = objectPocketed.filter(isStripe).length;
            if (solids + stripes > 0) {
                let g;
                if (solids !== stripes)
                    g = solids > stripes ? 'solids' : 'stripes';
                else
                    g = groupOf(objectPocketed.find((id) => id !== EIGHT));
                me.group = g;
                opp.group = otherGroup(g);
                state.openTable = false;
                const byIndex = {};
                for (const s of state.seats)
                    byIndex[`seat${s.seat}`] = s.group;
                events.push({ type: 'groups_assigned', seat, payload: { ...byIndex, assignedTo: seat, group: g } });
            }
        }
        if (fouls.length > 0) {
            this.giveBallInHand(state, opp.seat, sim.cueScratched, false, events);
            this.changeTurn(state, opp.seat, events);
            return;
        }
        const keeps = objectPocketed.some((id) => id !== EIGHT && (me.group === null || groupOf(id) === me.group));
        if (keeps)
            this.continueTurn(state, seat, events);
        else
            this.changeTurn(state, opp.seat, events);
    }
    respotEight(state, events) {
        const eight = state.balls.find((b) => b.id === EIGHT);
        const others = this.onTable(state).filter((b) => b.id !== EIGHT);
        const spot = nearestFreeSpot(FOOT_SPOT.x, FOOT_SPOT.y, others, true);
        eight.pocketed = false;
        eight.x = round3(spot.x);
        eight.y = round3(spot.y);
        events.push({ type: 'eight_respotted', payload: { x: eight.x, y: eight.y } });
    }
    giveBallInHand(state, seat, cueScratched, behindHeadString, events) {
        state.ballInHand = true;
        state.cueBehindHeadString = behindHeadString;
        const cue = this.cueBall(state);
        if (cueScratched || cue.pocketed) {
            const others = this.onTable(state).filter((b) => b.id !== CUE);
            const spot = nearestFreeSpot(HEAD_SPOT.x, HEAD_SPOT.y, others, false);
            cue.pocketed = false;
            cue.x = round3(behindHeadString ? Math.min(spot.x, HEAD_STRING_X) : spot.x);
            cue.y = round3(spot.y);
        }
        events.push({ type: 'ball_in_hand', seat, payload: { behindHeadString, x: cue.x, y: cue.y } });
    }
    continueTurn(state, seat, events) {
        this.resetTurnClock(state);
        events.push({ type: 'continue_turn', seat, payload: { deadline: state.turnDeadline } });
    }
    changeTurn(state, seat, events) {
        if (state.phase === 'finished')
            return;
        state.turnSeat = seat;
        this.resetTurnClock(state);
        events.push({ type: 'turn_changed', seat, payload: { deadline: state.turnDeadline, ballInHand: state.ballInHand } });
    }
    resetTurnClock(state) {
        const t = this.now();
        state.turnStartedAt = t;
        state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
    }
    finish(state, winnerSeat, reason, events) {
        const loser = this.opponentOf(state, winnerSeat);
        state.phase = 'finished';
        state.winnerSeat = winnerSeat;
        state.finishReason = reason;
        state.placements = [winnerSeat, loser.seat];
        state.ballInHand = false;
        state.turnDeadline = null;
        state.lastEvent = 'match_finished';
        events.push({ type: 'match_finished', seat: winnerSeat, payload: { placements: [...state.placements], reason, winnerSeat } });
    }
    // ---------------------------------------------------------------------------
    // Timeouts and leaving
    // ---------------------------------------------------------------------------
    /** A weak, roughly aimed shot at the nearest legal target; used when the shooter idles. */
    autoShot(state, seat, rng) {
        const cue = this.cueBall(state);
        const targets = this.legalFirstContacts(state, seat);
        const live = this.onTable(state);
        let best = null;
        let bestD = Infinity;
        for (const id of targets) {
            const b = live.find((x) => x.id === id);
            if (!b)
                continue;
            const d = (b.x - cue.x) ** 2 + (b.y - cue.y) ** 2;
            if (d < bestD) {
                bestD = d;
                best = b;
            }
        }
        let angle = best ? Math.atan2(best.y - cue.y, best.x - cue.x) : 0;
        // Enough pace to reach the target and still drive something to a rail, never a slam.
        let power = clamp(0.22 + Math.sqrt(bestD === Infinity ? 0 : bestD) / 220, 0.25, 0.7);
        if (rng) {
            angle += (rng.float() - 0.5) * 0.06;
            power = clamp(power + (rng.float() - 0.5) * 0.1, 0.2, 0.8);
        }
        return { type: 'shot', angle: round3(angle), power: round3(power) };
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
            this.finish(next, this.opponentOf(next, seat).seat, 'forfeit', events);
            next.version += 1;
            return { state: next, events };
        }
        this.resolveShot(next, seat, this.autoShot(next, seat, rng), events);
        next.version += 1;
        return { state: next, events };
    }
    onPlayerLeft(state, seat, _rng) {
        if (state.phase === 'finished')
            return { state, events: [] };
        const next = structuredClone(state);
        const events = [];
        const me = this.seatState(next, seat);
        if (me.forfeited)
            return { state, events: [] };
        me.forfeited = true;
        me.connected = false;
        events.push({ type: 'player_forfeited', seat, payload: { reason: 'left' } });
        this.finish(next, this.opponentOf(next, seat).seat, 'forfeit', events);
        next.version += 1;
        return { state: next, events };
    }
    // ---------------------------------------------------------------------------
    // Result and view
    // ---------------------------------------------------------------------------
    getResult(state) {
        const finished = state.phase === 'finished';
        const scoreOf = (s) => (s.group ? 7 - this.remainingOf(state, s.group) : 0) + (state.winnerSeat === s.seat ? 1 : 0);
        const placements = state.seats
            .map((s) => ({
            seat: s.seat,
            placement: finished ? state.placements.indexOf(s.seat) + 1 : 1,
            score: scoreOf(s),
        }))
            .sort((a, b) => a.placement - b.placement);
        return { finished, placements, winnerSeats: finished && state.winnerSeat !== null ? [state.winnerSeat] : [] };
    }
    /** Pool has no hidden information; the full state is the view. */
    getView(state, _viewerSeat) {
        return state;
    }
}
/**
 * Rack: 1 on the apex, 8 in the middle of the third row, one solid and one stripe on the
 * back corners, the rest shuffled with the match rng. Cue ball on the head spot.
 */
export function rackBalls(rng) {
    const slots = rackSlots();
    const solids = [2, 3, 4, 5, 6, 7];
    const stripes = [9, 10, 11, 12, 13, 14, 15];
    const cornerSolid = solids.splice(rng.int(0, solids.length - 1), 1)[0];
    const cornerStripe = stripes.splice(rng.int(0, stripes.length - 1), 1)[0];
    const rest = [...solids, ...stripes];
    for (let i = rest.length - 1; i > 0; i--) {
        const j = rng.int(0, i);
        const tmp = rest[i];
        rest[i] = rest[j];
        rest[j] = tmp;
    }
    const bySlot = new Map();
    bySlot.set(RACK_APEX_SLOT, 1);
    bySlot.set(RACK_EIGHT_SLOT, EIGHT);
    bySlot.set(RACK_BACK_CORNERS[0], cornerSolid);
    bySlot.set(RACK_BACK_CORNERS[1], cornerStripe);
    let k = 0;
    for (let s = 0; s < slots.length; s++) {
        if (bySlot.has(s))
            continue;
        bySlot.set(s, rest[k++]);
    }
    const balls = [{ id: CUE, x: HEAD_SPOT.x, y: HEAD_SPOT.y, pocketed: false }];
    for (let s = 0; s < slots.length; s++) {
        balls.push({ id: bySlot.get(s), x: slots[s].x, y: slots[s].y, pocketed: false });
    }
    balls.sort((a, b) => a.id - b.id);
    return balls;
}
export { BALL_RADIUS };
