const fs = require('fs');
const path = require('path');

const baseDir = path.resolve('assets/svip');
const animDir = 'C:\\Users\\Danial\\Downloads\\zeparty_animations_all\\zeparty_animations\\svip';

console.log('--- AUDITING SVIP ASSETS ---');
for (let i = 1; i <= 16; i++) {
  const tag = path.join(baseDir, `svip${i}_tag.png`);
  const card = path.join(baseDir, `svip${i}_card.webp`);
  const bubble = path.join(baseDir, `svip${i}_chat_bubble.webp`);
  const frame = path.join(baseDir, `svip${i}_frame.webp`);
  const entry = path.join(baseDir, `svip${i}_entry.webp`);
  const pad = i < 10 ? '0' + i : '' + i;
  const badge = path.join(baseDir, `SVIP${pad}_badge_live.webp`);

  console.log(`SVIP ${i}:`);
  console.log(`  Tag:    ${fs.existsSync(tag) ? fs.statSync(tag).size + ' B' : 'MISSING'}`);
  console.log(`  Card:   ${fs.existsSync(card) ? fs.statSync(card).size + ' B' : 'MISSING'}`);
  console.log(`  Bubble: ${fs.existsSync(bubble) ? fs.statSync(bubble).size + ' B' : 'MISSING'}`);
  console.log(`  Frame:  ${fs.existsSync(frame) ? fs.statSync(frame).size + ' B' : 'MISSING'}`);
  console.log(`  Entry:  ${fs.existsSync(entry) ? fs.statSync(entry).size + ' B' : 'MISSING'}`);
  console.log(`  Badge:  ${fs.existsSync(badge) ? fs.statSync(badge).size + ' B' : 'MISSING'}`);
}
