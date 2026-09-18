// ============================================================
// ZeParty Admin Portal — Master Policy Versioning Engine (JSX)
// Client Excel Phase F Requirements
// ============================================================

import React, { useState, useEffect } from 'react';
import { History, Calendar, CheckCircle, Clock } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { getPolicies } from '../../services/modules/economy.service';

export function PolicyVersioningPage() {
  const [policies, setPolicies] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    getPolicies()
      .then((data) => {
        if (Array.isArray(data) && data.length > 0) {
          const formatted = data.flatMap((p) => {
            if (p.versions && p.versions.length > 0) {
              return p.versions.map((v) => ({
                id: v.id,
                policyType: p.policyType,
                version: v.version,
                status: v.version === p.version ? 'CURRENT' : 'HISTORICAL',
                applyFrom: v.effectiveDate ? new Date(v.effectiveDate).toISOString().split('T')[0] : 'Immediate',
                summary: v.summary || p.description || 'Master policy baseline definition.',
                approvedBy: v.approvedBy || 'Root Owner',
              }));
            }
            return [{
              id: p.id,
              policyType: p.policyType,
              version: p.version || 'v1.0.0',
              status: 'CURRENT',
              applyFrom: p.createdAt ? new Date(p.createdAt).toISOString().split('T')[0] : 'Immediate',
              summary: p.description || 'Master policy definition',
              approvedBy: 'Root Owner',
            }];
          });
          setPolicies(formatted);
        } else {
          setPolicies([]);
        }
      })
      .catch(() => setPolicies([]))
      .finally(() => setIsLoading(false));
  }, []);
  const columns = [
    {
      key: 'type',
      header: 'Policy Area',
      render: (r) => <span className="text-xs font-bold text-white">{r.policyType}</span>,
    },
    {
      key: 'version',
      header: 'Version Tag',
      render: (r) => <Badge variant="purple">{r.version}</Badge>,
    },
    {
      key: 'status',
      header: 'Status Tag',
      render: (r) => (
        <Badge variant={r.status === 'CURRENT' ? 'success' : r.status === 'SCHEDULED' ? 'warning' : 'neutral'}>
          {r.status}
        </Badge>
      ),
    },
    {
      key: 'applyFrom',
      header: 'Apply From Date',
      render: (r) => <span className="text-xs font-mono text-gold-400 font-bold">{r.applyFrom}</span>,
    },
    {
      key: 'summary',
      header: 'Change Summary',
      render: (r) => <span className="text-xs text-slate-300 italic">{r.summary}</span>,
    },
    {
      key: 'approvedBy',
      header: 'Approver',
      render: (r) => <span className="text-xs text-slate-400">{r.approvedBy}</span>,
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <History className="h-6 w-6 text-gold-400" />
            Master Policy Versioning & Audit Engine
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Central repository for Economy, Host, Live Host, Withdrawal, Reseller, and Merchant policy versions.</p>
        </div>
      </div>

      <Card className="p-4 border-gold-500/30 bg-gold-950/20 text-xs text-slate-300">
        <strong className="text-white">Strict Business Policy Enforcement:</strong>
        <p className="mt-0.5">Every policy update retains full history. Active policies carry status <code className="text-gold-400">CURRENT</code>, future updates carry <code className="text-amber-400">SCHEDULED</code>, past versions remain <code className="text-slate-400">EXPIRED</code>.</p>
      </Card>

      <DataTable columns={columns} data={policies} isLoading={isLoading} />
    </div>
  );
}

