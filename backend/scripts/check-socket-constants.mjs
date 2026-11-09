// Fails when any SOCKET_EVENTS.X / SOCKET_ERRORS.X used in src/ is not defined in socket.constants.js.
// An undefined event name reaches clients as a malformed packet and disconnects them.
import fs from 'fs';
import path from 'path';
const root = path.resolve(new URL('..', import.meta.url).pathname, 'src');
const consts = fs.readFileSync(path.join(root, 'socket/socket.constants.js'), 'utf8');
const defined = new Set([...consts.matchAll(/^\s+([A-Z_0-9]+):/gm)].map((m) => m[1]));
const bad = [];
const walk = (d) => { for (const f of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, f.name); if (f.isDirectory()) walk(p); else if (p.endsWith('.js')) { const s = fs.readFileSync(p, 'utf8'); for (const m of s.matchAll(/SOCKET_(EVENTS|ERRORS)\.([A-Z_0-9]+)/g)) if (!defined.has(m[2])) bad.push(`${path.relative(root, p)}: SOCKET_${m[1]}.${m[2]}`); } } };
walk(root);
if (bad.length) { console.error('Undefined socket constants:\n  ' + [...new Set(bad)].join('\n  ')); process.exit(1); }
console.log('socket constants OK');
