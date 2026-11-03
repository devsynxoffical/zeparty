/**
 * Table geometry for 8 Ball Pool Elite. Everything is in "table units": the playing
 * surface is 200 x 100 (2:1), origin at the top left corner of the cloth, x to the right
 * (towards the foot rail), y downwards. The head string is at x = 50, the foot spot at
 * x = 150. The client draws the exact same geometry so hit areas line up with the sim.
 */
export const TABLE_WIDTH = 200;
export const TABLE_HEIGHT = 100;
/** Real pool ratio: ball diameter 2.25" on a 9 ft (100" x 50") cloth -> 2.25 / 100 * 200 / 2. */
export const BALL_RADIUS = 2.86;
export const HEAD_STRING_X = 50;
export const HEAD_SPOT = { x: 50, y: 50 };
export const FOOT_SPOT = { x: 150, y: 50 };
export const CORNER_POCKET_RADIUS = 5.2;
export const SIDE_POCKET_RADIUS = 4.6;
/** Half width of a corner mouth measured along each adjoining rail from the corner. */
export const CORNER_MOUTH = 5.6;
/** Half width of a side mouth measured along the rail from the rail centre. */
export const SIDE_MOUTH = 4.9;
/** Pocket centres sit this far outside the cushion line so the mouth is on the line. */
const CORNER_OFFSET = 1.6;
const SIDE_OFFSET = 2.0;
export const POCKETS = [
    { id: 0, x: -CORNER_OFFSET, y: -CORNER_OFFSET, r: CORNER_POCKET_RADIUS, kind: 'corner' },
    { id: 1, x: TABLE_WIDTH / 2, y: -SIDE_OFFSET, r: SIDE_POCKET_RADIUS, kind: 'side' },
    { id: 2, x: TABLE_WIDTH + CORNER_OFFSET, y: -CORNER_OFFSET, r: CORNER_POCKET_RADIUS, kind: 'corner' },
    { id: 3, x: -CORNER_OFFSET, y: TABLE_HEIGHT + CORNER_OFFSET, r: CORNER_POCKET_RADIUS, kind: 'corner' },
    { id: 4, x: TABLE_WIDTH / 2, y: TABLE_HEIGHT + SIDE_OFFSET, r: SIDE_POCKET_RADIUS, kind: 'side' },
    { id: 5, x: TABLE_WIDTH + CORNER_OFFSET, y: TABLE_HEIGHT + CORNER_OFFSET, r: CORNER_POCKET_RADIUS, kind: 'corner' },
];
/** Jaw geometry: corner jaws run 45 degrees into the pocket, side jaws angle inwards. */
const CORNER_JAW = 2.5;
const SIDE_JAW_DX = 1.4;
const SIDE_JAW_DY = 3.0;
function buildCushions() {
    const W = TABLE_WIDTH;
    const H = TABLE_HEIGHT;
    const cm = CORNER_MOUTH;
    const sm = SIDE_MOUTH;
    const segs = [];
    const add = (x1, y1, x2, y2) => segs.push({ x1, y1, x2, y2 });
    // Top rail (y = 0)
    add(cm, 0, W / 2 - sm, 0);
    add(W / 2 + sm, 0, W - cm, 0);
    // Bottom rail (y = H)
    add(cm, H, W / 2 - sm, H);
    add(W / 2 + sm, H, W - cm, H);
    // Left and right rails
    add(0, cm, 0, H - cm);
    add(W, cm, W, H - cm);
    // Corner jaws
    add(cm, 0, cm - CORNER_JAW, -CORNER_JAW);
    add(0, cm, -CORNER_JAW, cm - CORNER_JAW);
    add(W - cm, 0, W - cm + CORNER_JAW, -CORNER_JAW);
    add(W, cm, W + CORNER_JAW, cm - CORNER_JAW);
    add(cm, H, cm - CORNER_JAW, H + CORNER_JAW);
    add(0, H - cm, -CORNER_JAW, H - cm + CORNER_JAW);
    add(W - cm, H, W - cm + CORNER_JAW, H + CORNER_JAW);
    add(W, H - cm, W + CORNER_JAW, H - cm + CORNER_JAW);
    // Side jaws
    add(W / 2 - sm, 0, W / 2 - sm + SIDE_JAW_DX, -SIDE_JAW_DY);
    add(W / 2 + sm, 0, W / 2 + sm - SIDE_JAW_DX, -SIDE_JAW_DY);
    add(W / 2 - sm, H, W / 2 - sm + SIDE_JAW_DX, H + SIDE_JAW_DY);
    add(W / 2 + sm, H, W / 2 + sm - SIDE_JAW_DX, H + SIDE_JAW_DY);
    return segs;
}
export const CUSHIONS = buildCushions();
/** Anything beyond this box is off the table (safety net for balls escaping through a mouth). */
export const OFF_TABLE_MARGIN = 4;
export function tableSpec() {
    return {
        width: TABLE_WIDTH,
        height: TABLE_HEIGHT,
        ballRadius: BALL_RADIUS,
        headStringX: HEAD_STRING_X,
        footSpot: { ...FOOT_SPOT },
        headSpot: { ...HEAD_SPOT },
        pockets: POCKETS.map((p) => ({ ...p })),
        cushions: CUSHIONS.map((s) => ({ ...s })),
    };
}
/** Rack slot positions: apex on the foot spot, rows growing towards the foot rail. */
export function rackSlots() {
    const r = BALL_RADIUS + 0.01; // hair of spacing so nothing starts overlapping
    const slots = [];
    for (let row = 0; row < 5; row++) {
        const x = FOOT_SPOT.x + row * r * Math.sqrt(3);
        for (let j = 0; j <= row; j++) {
            const y = FOOT_SPOT.y + (j - row / 2) * 2 * r;
            slots.push({ x: round3(x), y: round3(y) });
        }
    }
    return slots;
}
/** Index into rackSlots of the slot in the middle of the third row (where the 8 goes). */
export const RACK_EIGHT_SLOT = 4;
/** Indices of the two back corners (one solid, one stripe). */
export const RACK_BACK_CORNERS = [10, 14];
export const RACK_APEX_SLOT = 0;
export function round3(v) {
    return Math.round(v * 1000) / 1000;
}
export function isSolid(id) {
    return id >= 1 && id <= 7;
}
export function isStripe(id) {
    return id >= 9 && id <= 15;
}
export const EIGHT = 8;
export const CUE = 0;
