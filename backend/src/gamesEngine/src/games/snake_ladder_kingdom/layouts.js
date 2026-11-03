export const LAYOUTS = {
    100: {
        kingdom_a: {
            id: 'kingdom_a',
            boardSize: 100,
            ladders: [
                { from: 4, to: 14 },
                { from: 9, to: 31 },
                { from: 20, to: 38 },
                { from: 28, to: 84 },
                { from: 40, to: 59 },
                { from: 51, to: 67 },
                { from: 63, to: 81 },
                { from: 71, to: 91 },
            ],
            snakes: [
                { from: 17, to: 7 },
                { from: 54, to: 34 },
                { from: 62, to: 19 },
                { from: 64, to: 60 },
                { from: 87, to: 24 },
                { from: 93, to: 73 },
                { from: 95, to: 75 },
                { from: 99, to: 78 },
            ],
        },
        kingdom_b: {
            id: 'kingdom_b',
            boardSize: 100,
            ladders: [
                { from: 3, to: 22 },
                { from: 11, to: 26 },
                { from: 15, to: 44 },
                { from: 36, to: 57 },
                { from: 47, to: 66 },
                { from: 56, to: 77 },
                { from: 70, to: 90 },
                { from: 82, to: 98 },
            ],
            snakes: [
                { from: 27, to: 5 },
                { from: 41, to: 21 },
                { from: 52, to: 30 },
                { from: 68, to: 49 },
                { from: 79, to: 58 },
                { from: 88, to: 67 },
                { from: 94, to: 71 },
                { from: 97, to: 86 },
            ],
        },
    },
    64: {
        kingdom_a: {
            id: 'kingdom_a',
            boardSize: 64,
            ladders: [
                { from: 3, to: 17 },
                { from: 8, to: 26 },
                { from: 19, to: 38 },
                { from: 29, to: 47 },
                { from: 42, to: 60 },
                { from: 50, to: 55 },
            ],
            snakes: [
                { from: 14, to: 4 },
                { from: 24, to: 11 },
                { from: 35, to: 21 },
                { from: 46, to: 31 },
                { from: 58, to: 40 },
                { from: 63, to: 52 },
            ],
        },
        kingdom_b: {
            id: 'kingdom_b',
            boardSize: 64,
            ladders: [
                { from: 5, to: 20 },
                { from: 12, to: 33 },
                { from: 22, to: 41 },
                { from: 30, to: 52 },
                { from: 37, to: 57 },
                { from: 49, to: 62 },
            ],
            snakes: [
                { from: 16, to: 2 },
                { from: 27, to: 9 },
                { from: 39, to: 18 },
                { from: 45, to: 28 },
                { from: 56, to: 36 },
                { from: 61, to: 44 },
            ],
        },
    },
};
export function getLayout(boardSize, id) {
    return LAYOUTS[boardSize][id];
}
export function columnsFor(boardSize) {
    return Math.round(Math.sqrt(boardSize));
}
/**
 * Boustrophedon path. Square 1 is bottom-left (row 0, col 0); row 0 runs left to right,
 * row 1 right to left, and so on. Row 0 is the bottom row; the renderer flips y.
 */
export function cellForSquare(square, boardSize) {
    const cols = columnsFor(boardSize);
    const idx = square - 1;
    const row = Math.floor(idx / cols);
    const inRow = idx % cols;
    const col = row % 2 === 0 ? inRow : cols - 1 - inRow;
    return { row, col };
}
/** Validates the structural invariants of a layout; throws with a reason on violation. */
export function validateLayout(layout) {
    const used = new Map();
    const claim = (sq, what) => {
        if (sq < 1 || sq > layout.boardSize)
            throw new Error(`${what} square ${sq} out of range`);
        const prev = used.get(sq);
        if (prev)
            throw new Error(`square ${sq} used by ${prev} and ${what}`);
        used.set(sq, what);
    };
    for (const l of layout.ladders) {
        if (l.from >= l.to)
            throw new Error(`ladder ${l.from}->${l.to} must go up`);
        if (l.from === 1)
            throw new Error('ladder cannot start on square 1');
        if (l.to === layout.boardSize)
            throw new Error('ladder cannot end on the final square');
        claim(l.from, `ladder ${l.from}->${l.to} bottom`);
        claim(l.to, `ladder ${l.from}->${l.to} top`);
    }
    for (const s of layout.snakes) {
        if (s.from <= s.to)
            throw new Error(`snake ${s.from}->${s.to} must go down`);
        if (s.from === layout.boardSize)
            throw new Error('snake head cannot sit on the final square');
        if (s.to === 1)
            throw new Error('snake cannot end on square 1');
        claim(s.from, `snake ${s.from}->${s.to} head`);
        claim(s.to, `snake ${s.from}->${s.to} tail`);
    }
}
