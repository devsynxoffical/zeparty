// ============================================================
// ZeParty Admin Portal — Country Flag Component (JSX)
// ============================================================

import React from 'react';
import { Globe } from 'lucide-react';

export function CountryFlag({ code, className = "w-4 h-3 object-cover rounded-sm inline-block shrink-0 shadow-sm" }) {
  if (!code || code === 'All' || code === 'GLOBAL' || code === 'Global') {
    return <Globe className="h-4 w-4 text-sky-400 shrink-0 inline-block" />;
  }
  const c = code.toLowerCase().trim();
  return (
    <img
      src={`https://flagcdn.com/w40/${c}.png`}
      srcSet={`https://flagcdn.com/w80/${c}.png 2x`}
      alt={code}
      className={className}
      loading="lazy"
      onError={(e) => {
        e.target.onerror = null;
        e.target.style.display = 'none';
      }}
    />
  );
}
