// ============================================================
// ZeParty Admin Portal — Avatar Component (JSX)
// ============================================================

import React from 'react';
import { avatarColor, getInitials } from '../../utils/format';

const sizeClasses = {
  xs: 'h-6 w-6 text-xs',
  sm: 'h-8 w-8 text-xs',
  md: 'h-9 w-9 text-sm',
  lg: 'h-11 w-11 text-base',
  xl: 'h-14 w-14 text-lg',
};

export function Avatar({ name, src, size = 'md', className = '' }) {
  const initials = getInitials(name);
  const bg = avatarColor(name || 'User');
  const sizeClass = sizeClasses[size] || sizeClasses.md;

  return (
    <span
      className={['relative inline-flex rounded-full flex-shrink-0', sizeClass, className].join(' ')}
      aria-label={name}
    >
      {src ? (
        <img
          src={src}
          alt={name}
          className="h-full w-full rounded-full object-cover"
        />
      ) : (
        <span
          className="h-full w-full rounded-full flex items-center justify-center font-semibold text-white select-none"
          style={{ backgroundColor: bg }}
          aria-hidden="true"
        >
          {initials}
        </span>
      )}
    </span>
  );
}
