// ============================================================
// ZeParty Admin Portal — AccessDenied Component (JSX)
// ============================================================

import React from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldAlert, LayoutDashboard, ArrowLeft } from 'lucide-react';
import { Button } from '../ui/Button';

export function AccessDenied({
  title = 'Access Denied',
  message = 'You do not have administrative permission to view this section. Please contact your Super Admin if you believe this is an error.',
}) {
  const navigate = useNavigate();

  return (
    <div className="flex min-h-[70vh] flex-col items-center justify-center p-6 text-center">
      <div className="flex h-20 w-20 items-center justify-center rounded-2xl bg-red-500/10 border border-red-500/30 text-red-400 mb-6 animate-pulse">
        <ShieldAlert className="h-10 w-10" aria-hidden="true" />
      </div>

      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-gold-500/15 text-gold-400 border border-gold-500/30 mb-3">
        Authorization Error 403
      </span>

      <h1 className="text-2xl font-bold text-white tracking-tight">{title}</h1>
      <p className="mt-2 text-sm text-slate-400 max-w-md leading-relaxed">{message}</p>

      <div className="mt-8 flex items-center gap-3">
        <Button
          variant="outline"
          size="sm"
          leftIcon={ArrowLeft}
          onClick={() => navigate(-1)}
        >
          Go Back
        </Button>
        <Button
          variant="primary"
          size="sm"
          leftIcon={LayoutDashboard}
          onClick={() => navigate('/admin')}
        >
          Return to Dashboard
        </Button>
      </div>
    </div>
  );
}
