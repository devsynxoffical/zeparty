// ============================================================
// ZeParty Admin Portal — Button Component (JSX)
// ============================================================

import React from 'react';

const variantClasses = {
  primary:
    'bg-gold-500 text-slate-950 font-semibold hover:bg-gold-400 focus-visible:ring-gold-500 shadow-sm shadow-gold-500/20',
  secondary:
    'bg-slate-700 text-slate-100 hover:bg-slate-600 focus-visible:ring-slate-500',
  ghost:
    'bg-transparent text-slate-300 hover:bg-slate-800 hover:text-white focus-visible:ring-slate-500',
  danger:
    'bg-red-600 text-white hover:bg-red-500 focus-visible:ring-red-500 shadow-sm',
  outline:
    'border border-slate-600 bg-transparent text-slate-300 hover:bg-slate-800 hover:text-white focus-visible:ring-slate-500',
};

const sizeClasses = {
  xs: 'h-7 px-2 py-0.5 text-xs gap-1 font-semibold',
  sm: 'h-8 px-3 text-xs gap-1.5',
  md: 'h-9 px-4 text-sm gap-2',
  lg: 'h-11 px-6 text-base gap-2',
};

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  leftIcon: LeftIcon,
  rightIcon: RightIcon,
  disabled,
  children,
  className = '',
  ...props
}) {
  const isDisabled = disabled || isLoading;
  const iconClass = size === 'xs' ? 'h-3.5 w-3.5 flex-shrink-0' : 'h-4 w-4 flex-shrink-0';

  return (
    <button
      disabled={isDisabled}
      aria-disabled={isDisabled}
      className={[
        'inline-flex items-center justify-center font-medium rounded-lg',
        'transition-colors duration-150',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-slate-900',
        'disabled:opacity-50 disabled:cursor-not-allowed',
        variantClasses[variant] || variantClasses.primary,
        sizeClasses[size] || sizeClasses.md,
        className,
      ].join(' ')}
      {...props}
    >
      {isLoading ? (
        <>
          <svg
            className={`animate-spin ${iconClass}`}
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            aria-hidden="true"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="4"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
          <span>Loading...</span>
        </>
      ) : (
        <>
          {LeftIcon && <LeftIcon className={iconClass} aria-hidden="true" />}
          {children}
          {RightIcon && <RightIcon className={iconClass} aria-hidden="true" />}
        </>
      )}
    </button>
  );
}
