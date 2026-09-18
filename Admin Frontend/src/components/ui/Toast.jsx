// ============================================================
// ZeParty Admin Portal — In-App Toast Notification Component (JSX)
// Modern floating popup notification without browser alerts
// ============================================================

import React, { useEffect } from 'react';
import { CheckCircle2, AlertTriangle, Info, XCircle, X } from 'lucide-react';

export function Toast({ toast, onClose }) {
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => {
      onClose();
    }, toast.duration || 4000);
    return () => clearTimeout(timer);
  }, [toast, onClose]);

  if (!toast) return null;

  const isSuccess = toast.type === 'success' || !toast.type;
  const isError = toast.type === 'error';
  const isWarning = toast.type === 'warning';

  return (
    <div className="fixed top-6 right-6 z-[9999] max-w-md w-full animate-in fade-in slide-in-from-top-4 duration-300 pointer-events-auto">
      <div
        className={`flex items-start gap-3 p-4 rounded-xl border shadow-2xl backdrop-blur-xl transition-all ${
          isSuccess
            ? 'bg-slate-900/95 border-emerald-500/40 text-white shadow-emerald-950/40'
            : isError
            ? 'bg-slate-900/95 border-red-500/40 text-white shadow-red-950/40'
            : isWarning
            ? 'bg-slate-900/95 border-amber-500/40 text-white shadow-amber-950/40'
            : 'bg-slate-900/95 border-indigo-500/40 text-white shadow-indigo-950/40'
        }`}
      >
        <div className="shrink-0 mt-0.5">
          {isSuccess && (
            <div className="h-8 w-8 rounded-lg bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center text-emerald-400">
              <CheckCircle2 className="h-5 w-5" />
            </div>
          )}
          {isError && (
            <div className="h-8 w-8 rounded-lg bg-red-500/20 border border-red-500/30 flex items-center justify-center text-red-400">
              <XCircle className="h-5 w-5" />
            </div>
          )}
          {isWarning && (
            <div className="h-8 w-8 rounded-lg bg-amber-500/20 border border-amber-500/30 flex items-center justify-center text-amber-400">
              <AlertTriangle className="h-5 w-5" />
            </div>
          )}
          {!isSuccess && !isError && !isWarning && (
            <div className="h-8 w-8 rounded-lg bg-indigo-500/20 border border-indigo-500/30 flex items-center justify-center text-indigo-400">
              <Info className="h-5 w-5" />
            </div>
          )}
        </div>

        <div className="flex-1 min-w-0 pr-1">
          <p className="text-xs font-bold uppercase tracking-wider text-slate-400">
            {toast.title || (isSuccess ? 'Success' : isError ? 'Action Failed' : 'Notice')}
          </p>
          <p className="text-sm font-medium text-slate-100 mt-0.5 leading-snug break-words">
            {toast.message}
          </p>
        </div>

        <button
          onClick={onClose}
          className="shrink-0 -mr-1 -mt-1 p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800/60 transition-colors"
        >
          <X className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}

export default Toast;
