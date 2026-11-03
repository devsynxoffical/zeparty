import { START_FEN, findMove, fromAlgebraic, generateLegalMoves, hasMatingMaterial, inCheck, insufficientMaterial, legalMoveMap, makeMove, parseFen, repetitionKey, toAlgebraic, toCoord, toFen, toSan, } from './chess.js';
import { resolveChessRules } from './rules.js';
const NOW = () => Date.now();
const PROMO = ['q', 'r', 'b', 'n'];
export class ChessEngine {
    now;
    gameId = 'chess_legends';
    constructor(now = NOW) {
        this.now = now;
    }
    createInitialState(players, rulesInput, _rng) {
        if (players.length !== 2)
            throw new Error('chess requires exactly 2 players');
        const rules = resolveChessRules(rulesInput);
        const sorted = [...players].sort((a, b) => a.seat - b.seat);
        const seats = sorted.map((p, i) => ({
            seat: p.seat,
            userId: p.userId,
            displayName: p.displayName,
            color: i === 0 ? 'w' : 'b',
            connected: true,
        }));
        const t = this.now();
        const ms = rules.initialSeconds * 1000;
        const pos = parseFen(START_FEN);
        const state = {
            rules,
            seats,
            fen: START_FEN,
            turn: 'w',
            turnSeat: seats[0].seat,
            phase: 'playing',
            clocks: { w: ms, b: ms },
            turnStartedAt: t,
            turnDeadline: rules.clockEnabled ? t + ms : null,
            moves: [],
            san: [],
            uci: [],
            captured: { w: [], b: [] },
            check: false,
            lastMove: null,
            drawOffer: null,
            repetition: { [repetitionKey(pos)]: 1 },
            result: null,
            placements: [],
            version: 0,
        };
        return state;
    }
    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------
    seatFor(state, color) {
        return state.seats.find((s) => s.color === color);
    }
    seatState(state, seat) {
        const s = state.seats.find((x) => x.seat === seat);
        if (!s)
            throw new Error(`unknown seat ${seat}`);
        return s;
    }
    currentSeat(state) {
        return state.phase === 'finished' ? null : state.turnSeat;
    }
    position(state) {
        return parseFen(state.fen);
    }
    // ---------------------------------------------------------------------------
    // Validation
    // ---------------------------------------------------------------------------
    validateAction(state, seat, action) {
        if (state.phase === 'finished')
            return { ok: false, code: 'match_finished', message: 'match is over' };
        if (!state.seats.some((s) => s.seat === seat))
            return { ok: false, code: 'bad_seat', message: 'not a player' };
        if (!action || typeof action !== 'object')
            return { ok: false, code: 'bad_action', message: 'unknown action' };
        switch (action.type) {
            case 'move': {
                if (state.turnSeat !== seat)
                    return { ok: false, code: 'not_your_turn', message: 'not your turn' };
                const from = fromAlgebraic(action.from);
                const to = fromAlgebraic(action.to);
                if (from < 0 || to < 0)
                    return { ok: false, code: 'bad_square', message: 'squares must be a1..h8' };
                if (action.promotion !== undefined && !PROMO.includes(action.promotion)) {
                    return { ok: false, code: 'bad_promotion', message: 'promotion must be q, r, b or n' };
                }
                const legal = generateLegalMoves(this.position(state));
                if (!findMove(legal, from, to, action.promotion))
                    return { ok: false, code: 'illegal_move', message: 'illegal move' };
                return { ok: true };
            }
            case 'resign':
                return { ok: true };
            case 'offer_draw':
                if (state.drawOffer !== null)
                    return { ok: false, code: 'offer_pending', message: 'a draw offer is already pending' };
                return { ok: true };
            case 'accept_draw':
            case 'decline_draw':
                if (state.drawOffer === null)
                    return { ok: false, code: 'no_offer', message: 'no draw offer to answer' };
                if (state.drawOffer === seat)
                    return { ok: false, code: 'own_offer', message: 'cannot answer your own offer' };
                return { ok: true };
            default:
                return { ok: false, code: 'bad_action', message: 'unknown action' };
        }
    }
    getLegalActions(state, seat) {
        if (state.phase === 'finished' || !state.seats.some((s) => s.seat === seat))
            return [];
        const out = [];
        if (state.turnSeat === seat) {
            for (const m of generateLegalMoves(this.position(state))) {
                const a = { type: 'move', from: toAlgebraic(m.from), to: toAlgebraic(m.to) };
                if (m.promotion)
                    a.promotion = m.promotion;
                out.push(a);
            }
        }
        out.push({ type: 'resign' });
        if (state.drawOffer === null)
            out.push({ type: 'offer_draw' });
        else if (state.drawOffer !== seat)
            out.push({ type: 'accept_draw' }, { type: 'decline_draw' });
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
        switch (action.type) {
            case 'move':
                this.doMove(next, seat, action, events);
                break;
            case 'resign':
                this.finish(next, events, { outcome: this.seatState(next, seat).color === 'w' ? 'black' : 'white', reason: 'resignation' }, [{ type: 'resigned', seat, payload: { seat } }]);
                break;
            case 'offer_draw':
                next.drawOffer = seat;
                events.push({ type: 'draw_offered', seat, payload: { seat } });
                break;
            case 'accept_draw':
                this.finish(next, events, { outcome: 'draw', reason: 'agreement' }, [{ type: 'draw_accepted', seat, payload: { seat } }]);
                break;
            case 'decline_draw':
                next.drawOffer = null;
                events.push({ type: 'draw_declined', seat, payload: { seat } });
                break;
        }
        next.version += 1;
        return { state: next, events };
    }
    /** Clock bookkeeping for the side that just completed its move. Returns false if its flag fell. */
    chargeClock(state, color, now) {
        if (!state.rules.clockEnabled)
            return true;
        const spent = Math.max(0, now - state.turnStartedAt);
        const remaining = state.clocks[color] - spent;
        if (remaining <= 0) {
            state.clocks[color] = 0;
            return false;
        }
        state.clocks[color] = remaining + state.rules.incrementSeconds * 1000;
        return true;
    }
    startTurn(state, now) {
        state.turnStartedAt = now;
        state.turnDeadline = state.rules.clockEnabled && state.phase === 'playing' ? now + state.clocks[state.turn] : null;
    }
    doMove(state, seat, action, events) {
        const now = this.now();
        const mover = this.seatState(state, seat);
        const color = mover.color;
        if (!this.chargeClock(state, color, now)) {
            // The move arrived after the flag fell: adjudicate exactly like onTimeout.
            this.flagFall(state, events, color);
            return;
        }
        const pos = this.position(state);
        const legal = generateLegalMoves(pos);
        const m = findMove(legal, fromAlgebraic(action.from), fromAlgebraic(action.to), action.promotion);
        const san = toSan(pos, m, legal);
        const nextPos = makeMove(pos, m);
        const check = inCheck(nextPos);
        const opponentMoves = generateLegalMoves(nextPos);
        const checkmate = check && opponentMoves.length === 0;
        const stalemate = !check && opponentMoves.length === 0;
        const record = {
            ply: state.moves.length,
            color,
            san,
            uci: toCoord(m),
            from: toAlgebraic(m.from),
            to: toAlgebraic(m.to),
            piece: m.piece,
            check,
            checkmate,
        };
        if (m.captured)
            record.captured = m.captured;
        if (m.promotion)
            record.promotion = m.promotion;
        if (m.castle)
            record.castle = m.castle;
        if (m.enPassant)
            record.enPassant = true;
        state.fen = toFen(nextPos);
        state.turn = nextPos.turn;
        state.turnSeat = this.seatFor(state, nextPos.turn).seat;
        state.moves.push(record);
        state.san.push(san);
        state.uci.push(record.uci);
        if (m.captured)
            state.captured[color].push(m.captured);
        state.check = check;
        state.lastMove = { from: record.from, to: record.to };
        // Making a move silently declines any pending offer from the opponent and withdraws your own.
        state.drawOffer = null;
        const key = repetitionKey(nextPos);
        const count = (state.repetition[key] ?? 0) + 1;
        state.repetition[key] = count;
        const payload = { from: record.from, to: record.to, san, piece: m.piece, check, checkmate };
        if (m.captured)
            payload['captured'] = m.captured;
        if (m.promotion)
            payload['promotion'] = m.promotion;
        if (m.castle)
            payload['castle'] = m.castle;
        if (m.enPassant)
            payload['enPassant'] = true;
        events.push({ type: 'move', seat, payload });
        const winner = color === 'w' ? 'white' : 'black';
        if (checkmate) {
            this.finish(state, events, { outcome: winner, reason: 'checkmate' }, [{ type: 'checkmate', seat, payload: { winnerSeat: seat } }]);
            return;
        }
        if (check)
            events.push({ type: 'check', seat: state.turnSeat, payload: { kingSeat: state.turnSeat } });
        if (stalemate) {
            this.finish(state, events, { outcome: 'draw', reason: 'stalemate' }, [{ type: 'stalemate', payload: {} }]);
            return;
        }
        if (insufficientMaterial(nextPos)) {
            this.finish(state, events, { outcome: 'draw', reason: 'insufficient_material' });
            return;
        }
        if (count >= 3) {
            this.finish(state, events, { outcome: 'draw', reason: 'threefold_repetition' });
            return;
        }
        if (nextPos.halfmove >= 100) {
            this.finish(state, events, { outcome: 'draw', reason: 'fifty_move' });
            return;
        }
        this.startTurn(state, now);
        events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, clocks: { ...state.clocks } } });
    }
    flagFall(state, events, color) {
        const flagged = this.seatFor(state, color);
        const opp = color === 'w' ? 'b' : 'w';
        state.clocks[color] = 0;
        const pos = this.position(state);
        const outcome = hasMatingMaterial(pos, opp) ? (opp === 'w' ? 'white' : 'black') : 'draw';
        this.finish(state, events, { outcome, reason: 'timeout' }, [{ type: 'flag_fell', seat: flagged.seat, payload: { seat: flagged.seat } }]);
    }
    finish(state, events, result, lead = []) {
        const white = this.seatFor(state, 'w');
        const black = this.seatFor(state, 'b');
        const winnerSeat = result.outcome === 'white' ? white.seat : result.outcome === 'black' ? black.seat : null;
        state.result = { ...result, winnerSeat };
        state.phase = 'finished';
        state.turnDeadline = null;
        state.drawOffer = null;
        state.placements = winnerSeat === null ? [white.seat, black.seat] : [winnerSeat, winnerSeat === white.seat ? black.seat : white.seat];
        events.push(...lead);
        if (result.outcome === 'draw')
            events.push({ type: 'draw', payload: { reason: result.reason } });
        events.push({ type: 'match_finished', payload: { placements: [...state.placements], outcome: result.outcome, reason: result.reason, winnerSeat } });
    }
    // ---------------------------------------------------------------------------
    // Room hooks
    // ---------------------------------------------------------------------------
    /** The side to move ran out of time. */
    onTimeout(state, _rng) {
        if (state.phase === 'finished')
            return { state, events: [] };
        const next = structuredClone(state);
        const events = [];
        this.flagFall(next, events, next.turn);
        next.version += 1;
        return { state: next, events };
    }
    onPlayerLeft(state, seat, _rng) {
        if (state.phase === 'finished')
            return { state, events: [] };
        const me = state.seats.find((s) => s.seat === seat);
        if (!me)
            return { state, events: [] };
        const next = structuredClone(state);
        const events = [];
        this.seatState(next, seat).connected = false;
        this.finish(next, events, { outcome: me.color === 'w' ? 'black' : 'white', reason: 'abandoned' }, [{ type: 'resigned', seat, payload: { seat, reason: 'left' } }]);
        next.version += 1;
        return { state: next, events };
    }
    getResult(state) {
        const finished = state.phase === 'finished';
        const r = state.result;
        const placements = state.seats
            .map((s) => {
            const won = r?.winnerSeat === s.seat;
            const draw = r?.outcome === 'draw';
            return { seat: s.seat, placement: draw || won ? 1 : finished ? 2 : 1, score: won ? 2 : draw ? 1 : 0 };
        })
            .sort((a, b) => a.placement - b.placement || a.seat - b.seat);
        return { finished, placements, winnerSeats: finished && r?.winnerSeat !== null && r?.winnerSeat !== undefined ? [r.winnerSeat] : [] };
    }
    /** Chess has no hidden information. The side to move additionally receives its legal moves. */
    getView(state, viewerSeat) {
        if (viewerSeat === null || state.phase === 'finished' || state.turnSeat !== viewerSeat)
            return state;
        return { ...state, legalMoves: legalMoveMap(this.position(state)) };
    }
}
