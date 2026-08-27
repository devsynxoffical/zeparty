// ============================================================
// ZeParty Admin Portal — Coming Soon Stub (JSX)
// ============================================================

import React from 'react';
import { Construction } from 'lucide-react';

export function ComingSoon({ moduleName, description }) {
  return (
    <div className="flex h-full min-h-[60vh] flex-col items-center justify-center gap-5 text-center p-8">
      <div className="flex h-20 w-20 items-center justify-center rounded-2xl bg-indigo-500/10 border border-indigo-500/20">
        <Construction className="h-10 w-10 text-indigo-400" aria-hidden="true" />
      </div>
      <div>
        <h2 className="text-xl font-semibold text-white">{moduleName}</h2>
        <p className="mt-2 text-sm text-slate-400 max-w-sm mx-auto">
          {description ||
            `The ${moduleName} module is planned for a future phase. The architecture is ready to receive this module.`}
        </p>
      </div>
      <div className="flex flex-wrap gap-2 justify-center">
        {['Phase 3+', 'Coming Soon'].map((tag) => (
          <span
            key={tag}
            className="inline-flex items-center px-2.5 py-1 rounded-full bg-slate-800 text-slate-500 text-xs font-medium border border-slate-700"
          >
            {tag}
          </span>
        ))}
      </div>
    </div>
  );
}
