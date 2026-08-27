// ============================================================
// ZeParty Admin Portal — Global Audit Logs Page (JSX)
// Complete Traceability + Before/After Diff + 4-Eyes Sign-Off
// ============================================================

import React, { useState, useMemo } from 'react';
import {
  ShieldCheck,
  Search,
  Activity,
  UserCog,
  AlertTriangle,
  Filter,
  ArrowRight,
  FileText,
  Lock,
  DollarSign
} from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { useAuditLog } from '../../context/AuditLogContext';
import { formatDate } from '../../utils/format';

const DiffViewer = ({ before, after }) => {
  if (!before && !after) return <p className="text-xs text-slate-500 italic">No direct state change recorded.</p>;

  const keys = new Set([...Object.keys(before || {}), ...Object.keys(after || {})]);

  return (
    <div className="bg-slate-950/60 rounded-xl border border-slate-800 overflow-hidden text-xs font-mono">
      <div className="grid grid-cols-2 bg-slate-900 border-b border-slate-800 text-[11px] text-slate-400 font-bold tracking-wider">
        <div className="p-2.5 border-r border-slate-800 text-center text-red-400">STATE BEFORE</div>
        <div className="p-2.5 text-center text-emerald-400">STATE AFTER</div>
      </div>
      {Array.from(keys).map((key) => {
        const valBefore = before?.[key];
        const valAfter = after?.[key];
        const changed = JSON.stringify(valBefore) !== JSON.stringify(valAfter);

        return (
          <div
            key={key}
            className={`grid grid-cols-2 border-b border-slate-800/60 last:border-0 ${
              changed ? 'bg-amber-500/10' : ''
            }`}
          >
            <div className="p-2.5 border-r border-slate-800/60 break-all text-slate-400">
              <span className="text-slate-500 mr-1.5">{key}:</span>
              <span className={changed ? 'text-red-400 line-through' : 'text-slate-300'}>
                {valBefore !== undefined ? JSON.stringify(valBefore) : 'null'}
              </span>
            </div>
            <div className="p-2.5 break-all text-slate-300">
              <span className="text-slate-500 mr-1.5">{key}:</span>
              <span className={changed ? 'text-emerald-400 font-bold' : 'text-slate-300'}>
                {valAfter !== undefined ? JSON.stringify(valAfter) : 'null'}
              </span>
            </div>
          </div>
        );
      })}
    </div>
  );
};

export function AuditLogsPage() {
  const { logs } = useAuditLog();
  const [search, setSearch] = useState('');
  const [filters, setFilters] = useState({
    module: 'ALL',
    riskLevel: 'ALL',
    status: 'ALL',
  });
  const [selectedLog, setSelectedLog] = useState(null);

  const updateFilter = (key, value) => {
    setFilters((prev) => ({ ...prev, [key]: value }));
  };

  const filteredLogs = useMemo(() => {
    return logs.filter((log) => {
      const matchModule = filters.module === 'ALL' || log.module === filters.module;
      const matchRisk = filters.riskLevel === 'ALL' || log.riskLevel === filters.riskLevel;
      const matchStatus = filters.status === 'ALL' || log.status === filters.status;
      const q = search.toLowerCase();
      const matchSearch =
        search === '' ||
        log.id?.toLowerCase().includes(q) ||
        log.action?.toLowerCase().includes(q) ||
        log.targetId?.toLowerCase().includes(q) ||
        log.targetName?.toLowerCase().includes(q) ||
        log.operatorName?.toLowerCase().includes(q) ||
        log.reason?.toLowerCase().includes(q);

      return matchModule && matchRisk && matchStatus && matchSearch;
    });
  }, [logs, search, filters]);

  const stats = useMemo(() => {
    return {
      total: logs.length,
      today: logs.filter((l) => new Date(l.timestamp).toDateString() === new Date().toDateString()).length,
      sensitive: logs.filter((l) => l.riskLevel === 'HIGH' || l.riskLevel === 'CRITICAL').length,
      operators: new Set(logs.map((l) => l.operatorId || l.operatorName)).size,
    };
  }, [logs]);

  const uniqueModules = useMemo(() => [...new Set(logs.map((l) => l.module))].sort(), [logs]);

  const columns = [
    {
      key: 'timestamp',
      header: 'Audit ID & Time',
      render: (row) => (
        <div>
          <span className="font-mono text-xs font-bold text-white">{row.id}</span>
          <p className="text-[11px] text-slate-400 mt-0.5">{formatDate(row.timestamp)}</p>
        </div>
      ),
    },
    {
      key: 'operator',
      header: 'Administrator',
      render: (row) => (
        <div>
          <p className="font-semibold text-white text-xs">{row.operatorName}</p>
          <p className="text-[11px] text-slate-400">{row.operatorRole}</p>
        </div>
      ),
    },
    {
      key: 'module',
      header: 'Module',
      render: (row) => <Badge variant="purple" className="text-[10px]">{row.module}</Badge>,
    },
    {
      key: 'action',
      header: 'Action Executed',
      render: (row) => (
        <span
          className={`text-xs font-bold font-mono ${
            row.riskLevel === 'CRITICAL'
              ? 'text-red-400'
              : row.riskLevel === 'HIGH'
              ? 'text-amber-400'
              : 'text-emerald-400'
          }`}
        >
          {row.action}
        </span>
      ),
    },
    {
      key: 'target',
      header: 'Target Entity',
      render: (row) => (
        <div>
          <p className="text-xs font-semibold text-slate-200">{row.targetName || '-'}</p>
          <p className="font-mono text-[10px] text-gold-400">{row.targetId}</p>
        </div>
      ),
    },
    {
      key: 'riskLevel',
      header: 'Risk Level',
      render: (row) => (
        <Badge
          variant={
            row.riskLevel === 'CRITICAL' || row.riskLevel === 'HIGH'
              ? 'danger'
              : row.riskLevel === 'MEDIUM'
              ? 'warning'
              : 'default'
          }
          className="text-[10px]"
        >
          {row.riskLevel}
        </Badge>
      ),
    },
    {
      key: 'actions',
      header: 'Details',
      render: (row) => (
        <button
          onClick={() => setSelectedLog(row)}
          className="text-xs text-gold-400 hover:text-white font-semibold underline underline-offset-2"
        >
          Inspect
        </button>
      ),
    },
  ];

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Global Audit Logs">
      <div>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <ShieldCheck className="h-7 w-7 text-gold-400" aria-hidden="true" />
          Centralized Audit & Compliance Trail
        </h1>
        <p className="text-sm text-slate-400 mt-0.5">
          Immutable event log tracing operator actions, before/after states, four-eyes sign-offs, and financial mutations.
        </p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Total Audited Events" value={stats.total} icon={Activity} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Actions Recorded Today" value={stats.today} icon={Activity} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
        <StatCard title="Critical / High-Risk Operations" value={stats.sensitive} icon={AlertTriangle} iconColor="text-red-400" iconBg="bg-red-500/10" />
        <StatCard title="Active Administrators" value={stats.operators} icon={UserCog} iconColor="text-purple-400" iconBg="bg-purple-500/10" />
      </div>

      <Card>
        <CardHeader title="Action Event Records" description="Chronological log of platform mutations">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex items-center gap-2 border border-slate-700 bg-slate-900 rounded-lg px-2">
              <Filter className="h-3.5 w-3.5 text-slate-500" />
              <select
                className="bg-transparent text-xs text-white py-2 outline-none"
                value={filters.module}
                onChange={(e) => updateFilter('module', e.target.value)}
              >
                <option value="ALL">All Modules</option>
                {uniqueModules.map((m) => (
                  <option key={m} value={m}>{m}</option>
                ))}
              </select>
            </div>
            <div className="flex items-center gap-2 border border-slate-700 bg-slate-900 rounded-lg px-2">
              <select
                className="bg-transparent text-xs text-white py-2 outline-none"
                value={filters.riskLevel}
                onChange={(e) => updateFilter('riskLevel', e.target.value)}
              >
                <option value="ALL">All Risk Levels</option>
                <option value="LOW">Low Risk</option>
                <option value="MEDIUM">Medium Risk</option>
                <option value="HIGH">High Risk</option>
                <option value="CRITICAL">Critical Risk</option>
              </select>
            </div>
            <Input
              placeholder="Search audit records…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              leftIcon={Search}
              containerClassName="w-64"
            />
          </div>
        </CardHeader>
        <DataTable
          columns={columns}
          data={filteredLogs}
          isLoading={false}
          emptyTitle="No Audit Logs"
          emptyDescription="No records match the current filters."
        />
      </Card>

      {/* Detailed Inspection Modal */}
      {selectedLog && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedLog(null)}
          title={`Audit Record: ${selectedLog.id}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 p-3.5 bg-slate-900 rounded-xl border border-slate-700/60">
              <div>
                <p className="text-[10px] uppercase font-bold text-slate-500">Log ID</p>
                <p className="font-mono text-xs font-bold text-white mt-0.5">{selectedLog.id}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-bold text-slate-500">Timestamp</p>
                <p className="text-xs text-white mt-0.5">{formatDate(selectedLog.timestamp)}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-bold text-slate-500">Risk Assessment</p>
                <Badge variant={selectedLog.riskLevel === 'CRITICAL' || selectedLog.riskLevel === 'HIGH' ? 'danger' : 'default'} className="mt-0.5">
                  {selectedLog.riskLevel}
                </Badge>
              </div>
              <div>
                <p className="text-[10px] uppercase font-bold text-slate-500">Approved By</p>
                <p className="text-xs font-bold text-emerald-400 mt-0.5">{selectedLog.approvedBy || 'System / Auto'}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 p-3 rounded-xl bg-slate-800/60 border border-slate-700/50">
              <div>
                <p className="text-slate-400 font-semibold">Operator Details:</p>
                <p className="text-white font-bold">{selectedLog.operatorName} <span className="text-slate-400 font-normal">({selectedLog.operatorRole})</span></p>
                <p className="text-[11px] text-slate-400">ID: {selectedLog.operatorId} · IP: {selectedLog.deviceIp || '127.0.0.1'}</p>
              </div>
              <div>
                <p className="text-slate-400 font-semibold">Target Entity:</p>
                <p className="text-white font-bold">{selectedLog.targetName}</p>
                <p className="text-[11px] text-slate-400">ID: <code className="font-mono text-gold-400">{selectedLog.targetId}</code> ({selectedLog.targetType})</p>
              </div>
              {(selectedLog.requestId || selectedLog.transactionId || selectedLog.amount) && (
                <div className="col-span-2 border-t border-slate-700/50 pt-2 flex gap-4 text-[11px]">
                  {selectedLog.requestId && <span>Request ID: <strong className="text-indigo-400">{selectedLog.requestId}</strong></span>}
                  {selectedLog.transactionId && <span>Tx Ref: <strong className="text-emerald-400">{selectedLog.transactionId}</strong></span>}
                  {selectedLog.amount && <span>Amount: <strong className="text-yellow-400">{selectedLog.amount}</strong></span>}
                </div>
              )}
            </div>

            <div className="p-3 rounded-xl bg-slate-800/40 border border-slate-700/40 space-y-1">
              <p className="text-slate-400 font-semibold">Action & Reason:</p>
              <p className="text-emerald-400 font-mono font-bold">{selectedLog.action}</p>
              <p className="text-slate-200 mt-1 italic">{selectedLog.reason || 'Routine administrator operation.'}</p>
              {selectedLog.evidence && (
                <p className="text-slate-400 mt-1 pt-1 border-t border-slate-700/40">
                  Evidence: <span className="text-slate-300">{selectedLog.evidence}</span>
                </p>
              )}
            </div>

            {/* Diff Viewer */}
            <div className="space-y-1.5">
              <p className="font-bold text-white flex items-center gap-1">
                <ArrowRight className="h-4 w-4 text-gold-400" />
                State Mutation (Before vs After Comparison)
              </p>
              <DiffViewer before={selectedLog.beforeValue} after={selectedLog.afterValue} />
            </div>

            <div className="flex justify-end pt-2">
              <button
                onClick={() => setSelectedLog(null)}
                className="bg-slate-700 hover:bg-slate-600 text-white px-4 py-2 rounded-lg text-xs font-bold transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
