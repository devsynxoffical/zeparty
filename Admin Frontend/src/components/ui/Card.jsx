// ============================================================
// ZeParty Admin Portal — Card Component (JSX)
// ============================================================

import React from 'react';

const paddingClasses = {
  none: '',
  sm: 'p-4',
  md: 'p-5',
  lg: 'p-6',
};

export function Card({ children, className = '', padding = 'md' }) {
  return (
    <div
      className={[
        'bg-slate-800/50 border border-slate-700/60 rounded-xl',
        paddingClasses[padding] || paddingClasses.md,
        className,
      ].join(' ')}
    >
      {children}
    </div>
  );
}

export function CardHeader({ title, description, action, className = '' }) {
  return (
    <div className={['flex items-start justify-between gap-4', className].join(' ')}>
      <div>
        <h3 className="text-sm font-semibold text-white">{title}</h3>
        {description && <p className="mt-0.5 text-xs text-slate-400">{description}</p>}
      </div>
      {action && <div className="flex-shrink-0">{action}</div>}
    </div>
  );
}
