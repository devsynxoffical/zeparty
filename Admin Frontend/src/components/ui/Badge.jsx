// ============================================================
// ZeParty Admin Portal — Badge & StatusBadge Components (JSX)
// ============================================================

import React from 'react';

const badgeVariantClasses = {
  default: 'bg-slate-700 text-slate-300',
  primary: 'bg-gold-500/15 text-gold-400 ring-1 ring-gold-500/30',
  success: 'bg-emerald-500/20 text-emerald-400 ring-1 ring-emerald-500/30',
  warning: 'bg-amber-500/20 text-amber-400 ring-1 ring-amber-500/30',
  danger: 'bg-red-500/20 text-red-400 ring-1 ring-red-500/30',
  info: 'bg-sky-500/20 text-sky-400 ring-1 ring-sky-500/30',
  muted: 'bg-slate-700 text-slate-400',
};

export function Badge({ children, variant = 'default', className = '' }) {
  return (
    <span
      className={[
        'inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium',
        badgeVariantClasses[variant] || badgeVariantClasses.default,
        className,
      ].join(' ')}
    >
      {children}
    </span>
  );
}

const statusConfig = {
  active: { label: 'Active', variant: 'success' },
  inactive: { label: 'Inactive', variant: 'muted' },
  pending: { label: 'Pending', variant: 'warning' },
  approved: { label: 'Approved', variant: 'success' },
  rejected: { label: 'Rejected', variant: 'danger' },
  suspended: { label: 'Suspended', variant: 'warning' },
  banned: { label: 'Banned', variant: 'danger' },
  completed: { label: 'Completed', variant: 'info' },
  failed: { label: 'Failed', variant: 'danger' },
};

export function StatusBadge({ status, className = '' }) {
  const config = statusConfig[status] || { label: status, variant: 'default' };
  return (
    <Badge variant={config.variant} className={className}>
      <span className="mr-1 h-1.5 w-1.5 rounded-full bg-current inline-block" aria-hidden="true" />
      {config.label}
    </Badge>
  );
}
