const fs = require('fs');
const path = require('path');

const pages = [
  'PKEventsPage',
  'WalletPage',
  'FinancePage',
  'StorePage',
  'BannersPage',
  'ModerationPage',
  'ReportsPage',
  'SupportPage',
  'AuditLogsPage'
];

const dir = path.join(__dirname, 'src', 'pages', 'admin');

pages.forEach(page => {
  const content = `// ============================================================
// ZeParty Admin Portal - ${page}
// ============================================================

import React from 'react';

export function ${page}() {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-white mb-6">${page.replace('Page', '')}</h1>
      <div className="bg-slate-800/50 rounded-xl border border-slate-700/50 p-6 flex flex-col items-center justify-center min-h-[400px]">
        <p className="text-slate-400">This module is currently being implemented.</p>
      </div>
    </div>
  );
}
`;
  fs.writeFileSync(path.join(dir, `${page}.jsx`), content);
});

console.log('Pages created successfully.');
