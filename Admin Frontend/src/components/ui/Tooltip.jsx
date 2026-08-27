// ============================================================
// ZeParty Admin Portal — Interactive Hover Tooltip Component (JSX)
// ============================================================

import React from 'react';

export function Tooltip({ children, content, position = 'top', className = '' }) {
  if (!content) return children;

  const positionClasses = {
    top: 'bottom-full mb-2 left-1/2 -translate-x-1/2',
    bottom: 'top-full mt-2 left-1/2 -translate-x-1/2',
    left: 'right-full mr-2 top-1/2 -translate-y-1/2',
    right: 'left-full ml-2 top-1/2 -translate-y-1/2',
  };

  const arrowClasses = {
    top: 'top-full left-1/2 -translate-x-1/2 -mt-1 border-t-slate-800 border-x-transparent border-b-transparent',
    bottom: 'bottom-full left-1/2 -translate-x-1/2 -mb-1 border-b-slate-800 border-x-transparent border-t-transparent',
    left: 'left-full top-1/2 -translate-y-1/2 -ml-1 border-l-slate-800 border-y-transparent border-r-transparent',
    right: 'right-full top-1/2 -translate-y-1/2 -mr-1 border-r-slate-800 border-y-transparent border-l-transparent',
  };

  return (
    <div className={`relative inline-flex group ${className}`}>
      {children}
      <div
        className={`absolute ${positionClasses[position]} pointer-events-none opacity-0 group-hover:opacity-100 scale-95 group-hover:scale-100 transition-all duration-150 ease-out z-50`}
      >
        <div className="bg-slate-950/95 border border-slate-700/80 text-slate-100 text-[11px] font-semibold px-2.5 py-1 rounded-md shadow-2xl whitespace-nowrap flex items-center gap-1 backdrop-blur-md">
          {content}
        </div>
        {/* Arrow pointer */}
        <div className={`absolute w-0 h-0 border-4 ${arrowClasses[position]}`} />
      </div>
    </div>
  );
}
