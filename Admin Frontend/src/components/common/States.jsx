// ============================================================
// ZeParty Admin Portal — Loading, Empty & Error States (JSX)
// ============================================================

import React from 'react';
import { AlertCircle, Inbox, Loader2, RefreshCw } from 'lucide-react';
import { Button } from '../ui/Button';

export function LoadingState({ message = 'Loading...', className = '' }) {
  return (
    <div
      className={['flex flex-col items-center justify-center gap-3 py-16 text-slate-400', className].join(' ')}
      aria-busy="true"
      aria-live="polite"
    >
      <Loader2 className="h-8 w-8 animate-spin text-indigo-400" aria-hidden="true" />
      <p className="text-sm">{message}</p>
    </div>
  );
}

export function Skeleton({ className = '' }) {
  return (
    <div
      className={['rounded-md bg-slate-700/60 animate-pulse', className].join(' ')}
      aria-hidden="true"
    />
  );
}

export function EmptyState({
  title = 'No data found',
  description = 'There is nothing to display here yet.',
  icon: Icon = Inbox,
  action,
  className = '',
}) {
  return (
    <div
      className={['flex flex-col items-center justify-center gap-4 py-16 text-center', className].join(' ')}
    >
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-slate-800 text-slate-500">
        <Icon className="h-8 w-8" aria-hidden="true" />
      </div>
      <div>
        <p className="text-sm font-medium text-slate-300">{title}</p>
        <p className="mt-1 text-xs text-slate-500">{description}</p>
      </div>
      {action && (
        <Button variant="outline" size="sm" onClick={action.onClick}>
          {action.label}
        </Button>
      )}
    </div>
  );
}

export function ErrorState({
  title = 'Something went wrong',
  description = 'An unexpected error occurred. Please try again.',
  onRetry,
  className = '',
}) {
  return (
    <div
      className={['flex flex-col items-center justify-center gap-4 py-16 text-center', className].join(' ')}
      role="alert"
    >
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-red-500/10 text-red-400">
        <AlertCircle className="h-8 w-8" aria-hidden="true" />
      </div>
      <div>
        <p className="text-sm font-medium text-slate-300">{title}</p>
        <p className="mt-1 text-xs text-slate-500">{description}</p>
      </div>
      {onRetry && (
        <Button variant="outline" size="sm" leftIcon={RefreshCw} onClick={onRetry}>
          Try again
        </Button>
      )}
    </div>
  );
}
