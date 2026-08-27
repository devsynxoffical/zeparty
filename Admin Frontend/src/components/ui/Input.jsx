// ============================================================
// ZeParty Admin Portal — Input Component (JSX)
// ============================================================

import React, { forwardRef } from 'react';

export const Input = forwardRef(function Input(
  {
    label,
    error,
    hint,
    leftIcon: LeftIcon,
    rightIcon: RightIcon,
    containerClassName = '',
    className = '',
    id,
    required,
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
      <div className="relative">
        {LeftIcon && (
          <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <LeftIcon className="h-4 w-4 text-slate-400" aria-hidden="true" />
          </div>
        )}
        <input
          ref={ref}
          id={inputId}
          required={required}
          aria-invalid={error ? 'true' : undefined}
          aria-describedby={error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined}
          className={[
            'w-full rounded-lg border bg-slate-800 text-sm text-white placeholder:text-slate-500',
            'px-3 py-2 h-9',
            'transition-colors duration-150',
            'focus:outline-none focus:ring-2 focus:ring-gold-500 focus:border-transparent',
            'disabled:opacity-50 disabled:cursor-not-allowed',
            LeftIcon ? 'pl-9' : '',
            RightIcon ? 'pr-9' : '',
            error
              ? 'border-red-500 focus:ring-red-500'
              : 'border-slate-700 focus:border-gold-500',
            className,
          ].join(' ')}
          {...props}
        />
        {RightIcon && (
          <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
            <RightIcon className="h-4 w-4 text-slate-400" aria-hidden="true" />
          </div>
        )}
      </div>
      {error && (
        <p id={`${inputId}-error`} className="text-xs text-red-400" role="alert">
          {error}
        </p>
      )}
      {hint && !error && (
        <p id={`${inputId}-hint`} className="text-xs text-slate-500">
          {hint}
        </p>
      )}
    </div>
  );
});
