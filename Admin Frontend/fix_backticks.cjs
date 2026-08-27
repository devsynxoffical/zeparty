const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, 'src', 'pages', 'admin');
const files = fs.readdirSync(dir).filter(f => f.endsWith('.jsx'));

for (const f of files) {
  const p = path.join(dir, f);
  let content = fs.readFileSync(p, 'utf8');
  if (content.includes('\\`')) {
    content = content.replace(/\\`/g, '`');
    fs.writeFileSync(p, content);
    console.log(`Fixed ${f}`);
  }
}
