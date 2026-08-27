// ============================================================
// ZeParty Admin Portal — StatCard Component (JSX)
// ============================================================

import React from 'react';
import { TrendingDown, TrendingUp } from 'lucide-react';
import { formatCompact, formatPercent } from '../../utils/format';

export function StatCard({
  title,
  value,
  icon: Icon,
  iconColor = 'text-gold-400',
  iconBg = 'bg-gold-500/10',
  change,
  changeLabel = 'vs last month',
  subValue,
  isLoading = false,
}) {
  const displayValue =
    typeof value === 'number' ? formatCompact(value) : value;

  const isPositive = change !== undefined && change >= 0;
  const TrendIcon = isPositive ? TrendingUp : TrendingDown;
  const trendColor = isPositive ? 'text-emerald-400' : 'text-red-400';

  if (isLoading) {
    return (
      <div className="bg-slate-800/50 border border-slate-700/60 rounded-xl p-5 animate-pulse">
        <div className="flex items-start justify-between">
          <div className="space-y-2">
            <div className="h-3 w-24 rounded bg-slate-700" />
            <div className="h-7 w-16 rounded bg-slate-700" />
          </div>
          <div className="h-10 w-10 rounded-lg bg-slate-700" />
        </div>
        <div className="mt-3 h-3 w-32 rounded bg-slate-700" />
      </div>
    );
  }

  return (
    <div className="bg-slate-800/50 border border-slate-700/60 rounded-xl p-5 group hover:border-slate-600 transition-colors duration-200">
      <div className="flex items-start justify-between">
        <div className="min-w-0">
          <p className="text-xs font-medium text-slate-400 uppercase tracking-wider truncate">
            {title}
          </p>
          <p className="mt-1.5 text-2xl font-bold text-white tabular-nums">
            {displayValue}
          </p>
        </div>
        {Icon && (
          <div
            className={[
              'flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-lg',
              iconBg,
            ].join(' ')}
            aria-hidden="true"
          >
            <Icon className={['h-5 w-5', iconColor].join(' ')} />
          </div>
        )}
      </div>

      <div className="mt-3 flex items-center gap-3">
        {change !== undefined && (
          <span className={['inline-flex items-center gap-1 text-xs font-medium', trendColor].join(' ')}>
            <TrendIcon className="h-3 w-3" aria-hidden="true" />
            {formatPercent(Math.abs(change))}
          </span>
        )}
        {(change !== undefined || subValue) && (
          <span className="text-xs text-slate-500">
            {subValue || changeLabel}
          </span>
        )}
      </div>
    </div>
  );
}
