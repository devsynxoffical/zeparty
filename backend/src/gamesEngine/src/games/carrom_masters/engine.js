import { BASELINE_X_MAX, BASELINE_X_MIN, BASELINE_Y, BOARD_SIZE, CENTER, COIN_MASS, COIN_RADIUS, MAX_SHOT_SPEED, POCKETS, POCKET_RADIUS, QUEEN_ID, STRIKER_ID, STRIKER_MASS, STRIKER_RADIUS, edgeForSeat, freeSpotNearCenter, initialRack, shotDirection, sideForSeat, toBoard, toFrame, vectorToBoard, } from './layout.js';
import { DEFAULT_BOARD, circlesOverlap, simulateShot } from './physics.js';
import { resolveCarromRules } from './rules.js';
const NOW = () => Date.now();
export function otherSide(side) {
    return side === 'white' ? 'black' : 'white';
}
export class CarromEngine {
    now;
    gameId = 'carrom_masters';
    constructor(now = NOW) {
        this.now = now;
    }
    createInitialState(players, rulesInput, _rng) {
        if (players.length !== 2 && players.length !== 4)
            throw new Error('carrom requires 2 or 4 players');
        const rules = resolveCarromRules(rulesInput);
        const seats = players.map((p) => ({
            seat: p.seat,
            userId: p.userId,
            displayName: p.displayName,
            side: sideForSeat(p.seat),
            edge: edgeForSeat(p.seat, players.length),
            consecutiveTimeouts: 0,
            forfeited: false,
            connected: true,
        }));
        const t = this.now();
        return {
            rules,
            seats,
            table: {
                size: BOARD_SIZE,
                pocketRadius: POCKET_RADIUS,
                pockets: POCKETS.map((p) => ({ ...p })),
                coinRadius: COIN_RADIUS,
                strikerRadius: STRIKER_RADIUS,
                baselineY: BASELINE_Y,
                baselineXMin: BASELINE_X_MIN,
                baselineXMax: BASELINE_X_MAX,
                maxShotSpeed: MAX_SHOT_SPEED,
            },
            coins: this.rack(rules),
            turnSeat: seats[0].seat,
            phase: 'aim',
            strikesThisTurn: 0,
            queen: { status: 'board', pendingBy: null, coveredBy: null },
            dues: { white: 0, black: 0 },
            boardsWon: { white: 0, black: 0 },
            boardNumber: 1,
            winnerSide: null,
            version: 0,
            placements: [],
            turnStartedAt: t,
            turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
            lastEvent: null,
        };
    }
    rack(rules) {
        return initialRack(rules.coinsPerSide).map((c) => ({ ...c, pocketed: false, pocketedBy: null }));
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
    // ---------------------------------------------------------------------------
    // Placement helpers
    // ---------------------------------------------------------------------------
    /** Striker centre in board coordinates for a baseline x in the shooter frame. */
    strikerPlacement(state, seat, x) {
        const edge = this.seatState(state, seat).edge;
        return toBoard(edge, { x, y: BASELINE_Y });
    }
    /** Coins currently on the playfield. */
    onBoard(state) {
        return state.coins.filter((c) => !c.pocketed);
    }
    placementBlocked(state, placement) {
        const striker = { ...placement, r: STRIKER_RADIUS };
        return this.onBoard(state).some((c) => circlesOverlap(striker, { x: c.x, y: c.y, r: COIN_RADIUS }));
    }
    validateAction(state, seat, action) {
        if (state.phase === 'finished')
            return { ok: false, code: 'match_finished', message: 'match is over' };
        if (state.turnSeat !== seat)
            return { ok: false, code: 'not_your_turn', message: 'not your turn' };
        const me = this.seatState(state, seat);
        if (me.forfeited)
            return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
        if (!action || action.type !== 'shot')
            return { ok: false, code: 'bad_action', message: 'unknown action' };
        if (typeof action.x !== 'number' || !Number.isFinite(action.x) || action.x < BASELINE_X_MIN || action.x > BASELINE_X_MAX) {
            return { ok: false, code: 'bad_x', message: `striker x must be within [${BASELINE_X_MIN}, ${BASELINE_X_MAX}]` };
        }
        if (typeof action.angle !== 'number' || !Number.isFinite(action.angle))
            return { ok: false, code: 'bad_angle', message: 'angle must be a finite number of radians' };
        if (typeof action.power !== 'number' || !Number.isFinite(action.power) || action.power <= 0 || action.power > 1) {
            return { ok: false, code: 'bad_power', message: 'power must be in (0, 1]' };
        }
        if (this.placementBlocked(state, this.strikerPlacement(state, seat, action.x))) {
            return { ok: false, code: 'striker_overlap', message: 'striker overlaps a coin at that position' };
        }
        return { ok: true };
    }
    /** The action space is continuous; these are representative legal placements for bots and hints. */
    getLegalActions(state, seat) {
        if (state.phase === 'finished' || state.turnSeat !== seat)
            return [];
        const out = [];
        for (const x of [50, 34, 66, 26, 74, 20, 80]) {
            if (!this.placementBlocked(state, this.strikerPlacement(state, seat, x)))
                out.push({ type: 'shot', x, angle: Math.PI / 2, power: 0.5 });
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
        this.doShot(next, seat, action, events);
        next.version += 1;
        return { state: next, events };
    }
    /** Run the simulation for a validated shot and apply every rule consequence. */
    doShot(state, seat, action, events) {
        const me = this.seatState(state, seat);
        const side = me.side;
        const opp = otherSide(side);
        const placement = this.strikerPlacement(state, seat, action.x);
        const dir = vectorToBoard(me.edge, shotDirection(action.angle));
        const speed = action.power * MAX_SHOT_SPEED;
        const velocity = { x: dir.x * speed, y: dir.y * speed };
        const bodies = [
            ...this.onBoard(state).map((c) => ({ id: c.id, x: c.x, y: c.y, vx: 0, vy: 0, r: COIN_RADIUS, mass: COIN_MASS })),
            { id: STRIKER_ID, x: placement.x, y: placement.y, vx: 0, vy: 0, r: STRIKER_RADIUS, mass: STRIKER_MASS },
        ];
        const result = simulateShot(DEFAULT_BOARD, bodies, velocity, STRIKER_ID);
        // Settle resting positions.
        for (const f of result.final) {
            const c = state.coins.find((x) => x.id === f.id);
            if (c) {
                c.x = f.x;
                c.y = f.y;
            }
        }
        const outcome = { result, placement, velocity, pocketedOwn: [], pocketedOpp: [], queenPocketed: false, strikerPocketed: false, fouls: [] };
        const pocketedPayload = [];
        for (const p of result.pocketed) {
            if (p.id === STRIKER_ID) {
                outcome.strikerPocketed = true;
                pocketedPayload.push({ id: p.id, by: null, t: p.t, pocket: p.pocket });
                continue;
            }
            const coin = state.coins.find((x) => x.id === p.id);
            if (!coin)
                continue;
            coin.pocketed = true;
            if (coin.kind === 'queen') {
                outcome.queenPocketed = true;
                coin.pocketedBy = null;
                pocketedPayload.push({ id: p.id, by: null, t: p.t, pocket: p.pocket });
            }
            else if (coin.kind === side) {
                coin.pocketedBy = side;
                outcome.pocketedOwn.push(coin.id);
                pocketedPayload.push({ id: p.id, by: side, t: p.t, pocket: p.pocket });
            }
            else {
                coin.pocketedBy = opp;
                outcome.pocketedOpp.push(coin.id);
                pocketedPayload.push({ id: p.id, by: opp, t: p.t, pocket: p.pocket });
            }
        }
        if (outcome.strikerPocketed)
            outcome.fouls.push('striker_pocketed');
        if (outcome.pocketedOpp.length > 0)
            outcome.fouls.push('opponent_coin');
        const foul = outcome.fouls.length > 0;
        const returned = [];
        // Queen.
        let queenCovered = false;
        const queen = state.coins.find((c) => c.id === QUEEN_ID);
        if (outcome.queenPocketed) {
            if (!state.rules.queenRequired) {
                this.coverQueen(state, queen, side);
                queenCovered = true;
            }
            else if (!foul && outcome.pocketedOwn.length > 0) {
                this.coverQueen(state, queen, side);
                queenCovered = true;
            }
            else if (!foul) {
                state.queen = { status: 'pending', pendingBy: side, coveredBy: null };
            }
            else {
                this.returnCoin(state, queen, returned, 'queen_uncovered');
                state.queen = { status: 'board', pendingBy: null, coveredBy: null };
            }
        }
        else if (state.queen.status === 'pending') {
            if (!foul && outcome.pocketedOwn.length > 0 && state.queen.pendingBy === side) {
                this.coverQueen(state, queen, side);
                queenCovered = true;
            }
            else {
                this.returnCoin(state, queen, returned, 'queen_uncovered');
                state.queen = { status: 'board', pendingBy: null, coveredBy: null };
            }
        }
        // Striker penalty.
        if (outcome.strikerPocketed && state.rules.penaltyOnStrikerPocket) {
            const mine = state.coins.find((c) => c.pocketed && c.kind === side && c.pocketedBy === side);
            if (mine)
                this.returnCoin(state, mine, returned, 'striker_penalty');
            else
                state.dues[side] += 1;
        }
        // Pay outstanding dues from this strike's gains.
        if (!foul && outcome.pocketedOwn.length > 0) {
            while (state.dues[side] > 0) {
                const mine = state.coins.find((c) => c.pocketed && c.kind === side && c.pocketedBy === side);
                if (!mine)
                    break;
                this.returnCoin(state, mine, returned, 'due_paid');
                state.dues[side] -= 1;
            }
        }
        const extraStrike = !foul && (outcome.pocketedOwn.length > 0 || outcome.queenPocketed) && state.phase !== 'finished';
        state.lastEvent = 'shot_resolved';
        events.push({
            type: 'shot_resolved',
            seat,
            payload: {
                side,
                placement,
                velocity,
                action: { x: action.x, angle: action.angle, power: action.power },
                frames: result.frames,
                pocketed: pocketedPayload,
                fouls: outcome.fouls,
                strikerPocketed: outcome.strikerPocketed,
                queenPocketed: outcome.queenPocketed,
                queenCovered,
                queenPending: state.queen.status === 'pending',
                collisions: result.collisions,
                final: result.final,
                duration: result.duration,
                extraStrike,
            },
        });
        if (returned.length > 0)
            events.push({ type: 'coins_returned', seat, payload: { coins: returned } });
        if (outcome.fouls.length > 0)
            events.push({ type: 'foul', seat, payload: { fouls: outcome.fouls, dues: { ...state.dues } } });
        if (this.checkBoardEnd(state, seat, events))
            return;
        if (extraStrike) {
            state.strikesThisTurn += 1;
            this.resetTurnClock(state);
            events.push({ type: 'extra_strike', seat, payload: { strikes: state.strikesThisTurn, queenPending: state.queen.status === 'pending' } });
            return;
        }
        this.advanceTurn(state, events);
    }
    coverQueen(state, queen, side) {
        queen.pocketed = true;
        queen.pocketedBy = side;
        state.queen = { status: 'covered', pendingBy: null, coveredBy: side };
    }
    returnCoin(state, coin, returned, reason) {
        const occupied = this.onBoard(state).map((c) => ({ x: c.x, y: c.y, r: COIN_RADIUS }));
        const spot = freeSpotNearCenter(occupied, COIN_RADIUS);
        coin.pocketed = false;
        coin.pocketedBy = null;
        coin.x = spot.x;
        coin.y = spot.y;
        returned.push({ id: coin.id, x: spot.x, y: spot.y, reason });
    }
    remaining(state, side) {
        return state.coins.filter((c) => c.kind === side && !c.pocketed).length;
    }
    pocketedCount(state, side) {
        return state.coins.filter((c) => c.kind === side && c.pocketed).length;
    }
    /**
     * A board ends when a side has no coins left on the playfield. If the queen is
     * still on the board at that moment, that side loses the board (standard rule);
     * otherwise it wins it. The non-shooting side is checked first so a foul that
     * clears the opponent's last coin hands them the board.
     */
    checkBoardEnd(state, shooterSeat, events) {
        if (state.phase === 'finished')
            return true;
        const shooter = this.seatState(state, shooterSeat).side;
        const order = [otherSide(shooter), shooter];
        let winner = null;
        for (const side of order) {
            if (this.remaining(state, side) > 0)
                continue;
            winner = state.queen.status === 'covered' ? side : otherSide(side);
            break;
        }
        if (!winner)
            return false;
        state.boardsWon[winner] += 1;
        state.winnerSide = winner;
        events.push({
            type: 'board_finished',
            payload: { winnerSide: winner, boardNumber: state.boardNumber, boardsWon: { ...state.boardsWon }, queenCoveredBy: state.queen.coveredBy },
        });
        if (state.boardsWon[winner] >= state.rules.pointsToWin) {
            this.finishMatch(state, winner, events);
            return true;
        }
        // Re-rack for the next board; the turn passes on normally.
        state.boardNumber += 1;
        state.coins = this.rack(state.rules);
        state.queen = { status: 'board', pendingBy: null, coveredBy: null };
        state.dues = { white: 0, black: 0 };
        events.push({ type: 'board_started', payload: { boardNumber: state.boardNumber, coins: state.coins.map((c) => ({ id: c.id, x: c.x, y: c.y })) } });
        this.advanceTurn(state, events);
        return true;
    }
    finishMatch(state, winner, events) {
        const active = (s) => !s.forfeited;
        const win = state.seats.filter((s) => s.side === winner && active(s)).map((s) => s.seat);
        const lose = state.seats.filter((s) => s.side !== winner && active(s)).map((s) => s.seat);
        const forfeited = state.seats.filter((s) => !active(s)).map((s) => s.seat);
        state.placements = [...win, ...lose, ...forfeited];
        state.winnerSide = winner;
        state.phase = 'finished';
        state.turnDeadline = null;
        state.lastEvent = 'match_finished';
        events.push({ type: 'match_finished', payload: { placements: [...state.placements], winnerSide: winner, boardsWon: { ...state.boardsWon } } });
    }
    activeSeatsOf(state, side) {
        return state.seats.filter((s) => s.side === side && !s.forfeited);
    }
    /** When a whole side has forfeited the other side wins immediately. */
    checkForfeitEnd(state, events) {
        if (state.phase === 'finished')
            return true;
        const whiteOut = this.activeSeatsOf(state, 'white').length === 0;
        const blackOut = this.activeSeatsOf(state, 'black').length === 0;
        if (!whiteOut && !blackOut)
            return false;
        const winner = whiteOut && blackOut ? 'white' : whiteOut ? 'black' : 'white';
        this.finishMatch(state, winner, events);
        return true;
    }
    advanceTurn(state, events) {
        if (state.phase === 'finished')
            return;
        state.strikesThisTurn = 0;
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
        this.resetTurnClock(state);
        events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, side: this.seatState(state, state.turnSeat).side } });
    }
    resetTurnClock(state) {
        const t = this.now();
        state.turnStartedAt = t;
        state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
    }
    // ---------------------------------------------------------------------------
    // Timeouts and leaving
    // ---------------------------------------------------------------------------
    /** A weak, legal shot aimed roughly at the centre, used when a player times out. */
    randomLegalShot(state, seat, rng) {
        let x = null;
        for (let i = 0; i < 24 && x === null; i++) {
            const cand = rng.int(BASELINE_X_MIN, BASELINE_X_MAX);
            if (!this.placementBlocked(state, this.strikerPlacement(state, seat, cand)))
                x = cand;
        }
        if (x === null) {
            for (let cand = BASELINE_X_MIN; cand <= BASELINE_X_MAX && x === null; cand += 1) {
                if (!this.placementBlocked(state, this.strikerPlacement(state, seat, cand)))
                    x = cand;
            }
        }
        if (x === null)
            return null;
        const edge = this.seatState(state, seat).edge;
        const target = toFrame(edge, CENTER);
        const dx = target.x - x;
        const dy = target.y - BASELINE_Y;
        const angle = Math.atan2(-dy, dx) + (rng.float() - 0.5) * 0.3;
        const power = 0.22 + rng.float() * 0.12;
        return { type: 'shot', x, angle, power };
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
            if (!this.checkForfeitEnd(next, events))
                this.advanceTurn(next, events);
            next.version += 1;
            return { state: next, events };
        }
        const shot = this.randomLegalShot(next, seat, rng);
        if (shot) {
            // A queen pending cover is forfeited by an idle player like any missed strike.
            this.doShot(next, seat, shot, events);
        }
        else {
            if (next.queen.status === 'pending') {
                const queen = next.coins.find((c) => c.id === QUEEN_ID);
                const returned = [];
                this.returnCoin(next, queen, returned, 'queen_uncovered');
                next.queen = { status: 'board', pendingBy: null, coveredBy: null };
                events.push({ type: 'coins_returned', seat, payload: { coins: returned } });
            }
            this.advanceTurn(next, events);
        }
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
        if (!this.checkForfeitEnd(next, events) && next.turnSeat === seat) {
            if (next.queen.status === 'pending') {
                const queen = next.coins.find((c) => c.id === QUEEN_ID);
                const returned = [];
                this.returnCoin(next, queen, returned, 'queen_uncovered');
                next.queen = { status: 'board', pendingBy: null, coveredBy: null };
                events.push({ type: 'coins_returned', seat, payload: { coins: returned } });
            }
            this.advanceTurn(next, events);
        }
        next.version += 1;
        return { state: next, events };
    }
    // ---------------------------------------------------------------------------
    // Result and view
    // ---------------------------------------------------------------------------
    /** Score: boards won weigh most, then coins pocketed for the side, then the queen. */
    scoreFor(state, side) {
        return state.boardsWon[side] * 100 + this.pocketedCount(state, side) + (state.queen.coveredBy === side ? 3 : 0);
    }
    getResult(state) {
        const finished = state.phase === 'finished';
        const placementOf = (seat) => {
            const idx = state.placements.indexOf(seat);
            if (idx === -1)
                return state.seats.length;
            const s = this.seatState(state, seat);
            // Team mates share a placement.
            const first = state.placements.findIndex((p) => this.seatState(state, p).side === s.side && !this.seatState(state, p).forfeited);
            return (s.forfeited ? idx : first === -1 ? idx : first) + 1;
        };
        const placements = state.seats
            .map((s) => ({ seat: s.seat, placement: placementOf(s.seat), score: this.scoreFor(state, s.side) }))
            .sort((a, b) => a.placement - b.placement || a.seat - b.seat);
        const winnerSeats = finished && state.winnerSide ? state.seats.filter((s) => s.side === state.winnerSide && !s.forfeited).map((s) => s.seat) : [];
        return { finished, placements, winnerSeats };
    }
    /** Carrom has no hidden information; the full state is the view. */
    getView(state, _viewerSeat) {
        return state;
    }
}
