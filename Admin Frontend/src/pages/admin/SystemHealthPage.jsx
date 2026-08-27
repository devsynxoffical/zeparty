// ============================================================
// ZeParty Admin Portal — System Health & Infrastructure (JSX)
// Client Excel Phase F Requirements
// ============================================================

import React from 'react';
import { Activity, Server, Database, Cpu, HardDrive } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';

export function SystemHealthPage() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Activity className="h-6 w-6 text-emerald-400" />
            System Health & Infrastructure Monitor
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Mock health indicators for API servers, database clusters, streaming queues, and storage load.</p>
        </div>
        <Badge variant="success">All Systems Operational (99.98% Uptime)</Badge>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'REST API Cluster', status: 'HEALTHY', latency: '24ms', icon: Server, color: 'text-emerald-400' },
          { label: 'PostgreSQL Database', status: 'HEALTHY', latency: '12ms', icon: Database, color: 'text-emerald-400' },
          { label: 'Redis Queue Server', status: 'HEALTHY', latency: '3ms', icon: Cpu, color: 'text-emerald-400' },
          { label: 'S3 Media Storage', status: 'HEALTHY', latency: '48ms', icon: HardDrive, color: 'text-emerald-400' },
        ].map((s) => (
          <Card key={s.label} className="p-4 flex flex-col items-center text-center gap-1">
            <s.icon className={`h-8 w-8 ${s.color} mb-1`} />
            <p className="text-sm font-bold text-white">{s.label}</p>
            <p className="text-xs text-slate-400 font-mono">Latency: {s.latency}</p>
            <Badge variant="success" className="mt-2">{s.status}</Badge>
          </Card>
        ))}
      </div>
    </div>
  );
}
