// ============================================================
// ZeParty Admin Portal — Select Component (JSX)
// ============================================================

import React, { forwardRef } from 'react';

export const Select = forwardRef(function Select(
  {
    label,
    error,
    hint,
    containerClassName = '',
    className = '',
    id,
    required,
    children,
    ...props
  },
  ref
) {
  const inputId = id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);

  return (
    <div className={['flex flex-col gap-1.5', containerClassName].join(' ')}>
      {label && (
        <label htmlFor={inputId} className="text-xs font-medium text-slate-300">
          {label}
          {required && <span className="ml-0.5 text-red-400">*</span>}
        </label>
      )}
      <select
        ref={ref}
        id={inputId}
        required={required}
        aria-invalid={error ? 'true' : undefined}
        className={[
          'w-full rounded-lg border bg-slate-800 text-sm text-white',
          'px-3 py-2 h-9',
          'transition-colors duration-150',
          'focus:outline-none focus:ring-2 focus:ring-gold-500 focus:border-transparent',
          'disabled:opacity-50 disabled:cursor-not-allowed',
          error ? 'border-red-500' : 'border-slate-700',
          className,
        ].join(' ')}
        {...props}
      >
        {children}
      </select>
      {error && (
        <p className="text-xs text-red-400" role="alert">{error}</p>
      )}
      {hint && !error && (
        <p className="text-xs text-slate-500">{hint}</p>
      )}
    </div>
  );
});

// ---- Textarea Component ----
export const Textarea = forwardRef(function Textarea(
  {
    label,
    error,
    hint,
    containerClassName = '',
    className = '',
    id,
    required,
    rows = 3,
    ...props
  },
  ref
) {
  const inputId = id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);

  return (
    <div className={['flex flex-col gap-1.5', containerClassName].join(' ')}>
      {label && (
        <label htmlFor={inputId} className="text-xs font-medium text-slate-300">
          {label}
          {required && <span className="ml-0.5 text-red-400">*</span>}
        </label>
      )}
      <textarea
        ref={ref}
        id={inputId}
        required={required}
        rows={rows}
        className={[
          'w-full rounded-lg border bg-slate-800 text-sm text-white placeholder:text-slate-500',
          'px-3 py-2 resize-none',
          'transition-colors duration-150',
          'focus:outline-none focus:ring-2 focus:ring-gold-500 focus:border-transparent',
          'disabled:opacity-50 disabled:cursor-not-allowed',
          error ? 'border-red-500' : 'border-slate-700',
          className,
        ].join(' ')}
        {...props}
      />
      {error && (
        <p className="text-xs text-red-400" role="alert">{error}</p>
      )}
      {hint && !error && (
        <p className="text-xs text-slate-500">{hint}</p>
      )}
    </div>
  );
});
