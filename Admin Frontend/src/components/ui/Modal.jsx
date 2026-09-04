// ============================================================
// ZeParty Admin Portal — Modal Component (JSX)
// ============================================================

import React, { useEffect } from 'react';
import { X } from 'lucide-react';
import { Button } from './Button';

export function Modal({
  isOpen,
  open,
  onClose,
  title,
  description,
  children,
  footer,
  size = 'md',
  className = '',
}) {
  const isModalOpen = isOpen !== undefined ? isOpen : open;

  // Close on Escape key
  useEffect(() => {
    if (!isModalOpen) return;
    const handler = (e) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [isModalOpen, onClose]);

  if (!isModalOpen) return null;

  const sizeClasses = {
    sm: 'max-w-md',
    md: 'max-w-lg',
    lg: 'max-w-2xl',
    xl: 'max-w-4xl',
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/70 backdrop-blur-sm"
        onClick={onClose}
        aria-hidden="true"
      />

      {/* Modal panel */}
      <div
        className={[
          'relative w-full rounded-2xl bg-slate-900 border border-slate-700/60 shadow-2xl',
          'flex flex-col max-h-[90vh]',
          sizeClasses[size] || sizeClasses.md,
          className,
        ].join(' ')}
      >
        {/* Header */}
        <div className="flex items-start justify-between gap-4 p-5 border-b border-slate-700/60">
          <div>
            <h2 id="modal-title" className="text-base font-semibold text-white">
              {title}
            </h2>
            {description && (
              <p className="mt-0.5 text-xs text-slate-400">{description}</p>
            )}
          </div>
          <button
            onClick={onClose}
            className="flex-shrink-0 rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white transition-colors"
            aria-label="Close modal"
          >
            <X className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto p-5">{children}</div>

        {/* Footer */}
        {footer && (
          <div className="flex items-center justify-end gap-2 p-4 border-t border-slate-700/60">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}

// ---- Confirm Dialog ----
export function ConfirmDialog({
  isOpen,
  open,
  onClose,
  onConfirm,
  title,
  description,
  confirmLabel = 'Confirm',
  confirmVariant = 'danger',
  isLoading = false,
}) {
  const isModalOpen = isOpen !== undefined ? isOpen : open;
  return (
    <Modal isOpen={isModalOpen} onClose={onClose} title={title} size="sm">
      <p className="text-sm text-slate-300">{description}</p>
      <div className="mt-5 flex justify-end gap-2">
        <Button variant="ghost" size="sm" onClick={onClose} disabled={isLoading}>
          Cancel
        </Button>
        <Button
          variant={confirmVariant}
          size="sm"
          isLoading={isLoading}
          onClick={onConfirm}
        >
          {confirmLabel}
        </Button>
      </div>
    </Modal>
  );
}
