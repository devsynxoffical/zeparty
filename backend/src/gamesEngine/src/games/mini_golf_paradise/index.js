import { MiniGolfEngine } from './engine.js';
export { MiniGolfEngine, rankSeats, totalStrokes, holesWon, angleToHole } from './engine.js';
export { COURSES, courseByIndex, validateCourse, pointInPolygon, pointInTurf, pointInAny, rectPoly, outlineWalls } from './courses.js';
export { simulateStroke, obstacleValues, obstacleSegments, circleSegmentContact, surfaceFriction } from './physics.js';
export { MiniGolfRulesSchema, DEFAULT_MINI_GOLF_RULES, resolveMiniGolfRules, MINI_GOLF_COURSE_COUNT } from './rules.js';
export const engine = new MiniGolfEngine();
