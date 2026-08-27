// ============================================================
// ZeParty Admin Portal — Privacy & Compliance Page (JSX)
// Client Excel Phase F Requirements
// ============================================================

import React from 'react';
import { ShieldCheck, FileText } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';

export function PrivacyCompliancePage() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ShieldCheck className="h-6 w-6 text-emerald-400" />
            Privacy & Compliance Governance
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">GDPR/CCPA compliance, terms of service placeholder updates, and user consent history.</p>
        </div>
      </div>

      <Card className="p-5 space-y-3">
        <h2 className="text-sm font-bold text-white">Active Compliance Terms & Versions</h2>
        <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/50 flex justify-between items-center">
          <div>
            <p className="text-xs font-bold text-white">Terms of Service</p>
            <p className="text-[11px] text-slate-400">Version 3.1.0 • Applied Jan 1, 2026</p>
          </div>
          <Badge variant="success">Active</Badge>
        </div>
        <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/50 flex justify-between items-center">
          <div>
            <p className="text-xs font-bold text-white">Privacy Policy</p>
            <p className="text-[11px] text-slate-400">Version 2.8.0 • Applied Jan 1, 2026</p>
          </div>
          <Badge variant="success">Active</Badge>
        </div>
      </Card>
    </div>
  );
}
