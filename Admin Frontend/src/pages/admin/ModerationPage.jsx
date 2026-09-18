// ============================================================
// ZeParty Admin Portal — Moderation Page (JSX)
// Client Excel Phase E Requirements
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Shield, Search, AlertOctagon, UserX, MessageSquare, Radio, ShieldAlert } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getModerationStats,
  getModerationReports,
  updateReportStatus
} from '../../services/modules/moderation.service';

export function ModerationPage() {
  const navigate = useNavigate();
  const { addLog } = useAuditLog();
  const [stats, setStats] = useState(null);
  const [reports, setReports] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  const [actionModal, setActionModal] = useState({ open: false, report: null });
  const [viewLogModal, setViewLogModal] = useState({ open: false, report: null });
  const [actionNotes, setActionNotes] = useState('');

  useEffect(() => {
    Promise.all([getModerationStats(), getModerationReports()])
      .then(([s, r]) => {
        setStats(s);
        setReports(r);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const filteredReports = useMemo(() => {
    return reports.filter(r => {
      const matchStatus = statusFilter === 'ALL' || r.status === statusFilter;
      const matchSearch = search === '' ||
        r.targetId.toLowerCase().includes(search.toLowerCase()) ||
        r.reporter.toLowerCase().includes(search.toLowerCase());
      return matchStatus && matchSearch;
    });
  }, [reports, search, statusFilter]);

  const handleTakeAction = async (actionType) => {
    if (!actionModal.report) return;

    const newStatus = actionType === 'REJECT' ? 'REJECTED' : 'ACTIONED';
    const updated = await updateReportStatus(actionModal.report.id, newStatus);

    setReports(reports.map(r => r.id === actionModal.report.id ? updated : r));
    addLog('MODERATION_ACTION', actionModal.report.targetId, 'Moderation', `Action: ${actionType} on ${actionModal.report.targetType} ${actionModal.report.targetId}. Notes: ${actionNotes}`);

    setActionModal({ open: false, report: null });
    setActionNotes('');
  };

  const getTargetIcon = (type) => {
    switch (type) {
      case 'User': return <UserX className="h-4 w-4 text-sky-400" />;
      case 'Room': return <Radio className="h-4 w-4 text-gold-400" />;
      case 'Host': return <Shield className="h-4 w-4 text-purple-400" />;
      case 'Message': return <MessageSquare className="h-4 w-4 text-emerald-400" />;
      default: return <AlertOctagon className="h-4 w-4 text-slate-400" />;
    }
  };

  const columns = [
    { key: 'target', header: 'Reported Target', render: (row) => (
      <div className="flex items-center gap-2">
        <div className="bg-slate-800 p-1.5 rounded-lg border border-slate-700">
          {getTargetIcon(row.targetType)}
        </div>
        <div>
          <p className="font-medium text-white text-sm">{row.targetId}</p>
          <p className="text-xs text-slate-500">{row.targetType}</p>
        </div>
      </div>
    )},
    { key: 'reason', header: 'Reason', render: (row) => <span className="text-slate-300 font-medium">{row.reason}</span> },
    { key: 'reporter', header: 'Reporter', render: (row) => <span className="text-slate-400 text-sm">{row.reporter}</span> },
    { key: 'priority', header: 'Priority', render: (row) => (
      <Badge variant={row.priority === 'URGENT' ? 'danger' : row.priority === 'HIGH' ? 'warning' : 'default'}>
        {row.priority}
      </Badge>
    )},
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'date', header: 'Date', render: (row) => <span className="text-xs text-slate-500">{new Date(row.date).toLocaleString()}</span> },
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-2">
        {row.status === 'NEW' || row.status === 'REVIEWING' ? (
          <button
            onClick={() => setActionModal({ open: true, report: row })}
            className="text-xs text-amber-400 hover:underline flex items-center gap-1 font-bold"
          >
            <ShieldAlert className="h-3.5 w-3.5" /> Resolve
          </button>
        ) : (
          <button onClick={() => setViewLogModal({ open: true, report: row })} className="text-xs text-slate-400 hover:text-white hover:underline">
            View Resolution Log
          </button>
        )}
      </div>
    )}
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading Moderation...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Moderation Dashboard">
      <div>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <ShieldAlert className="h-6 w-6 text-red-400" aria-hidden="true" />
          Trust & Safety
        </h1>
        <p className="text-sm text-slate-400 mt-0.5">Manage user reports, apply restrictions, and maintain platform safety.</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Reports Today" value={stats?.reportsToday ?? 0} icon={AlertOctagon} iconColor="text-red-400" iconBg="bg-red-500/10" />
        <StatCard title="Pending Review" value={stats?.pendingReview ?? 0} icon={ShieldAlert} iconColor="text-amber-400" iconBg="bg-amber-500/10" />
        <StatCard title="Actioned Today" value={stats?.actionedToday ?? 0} icon={Shield} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Appeals Pending" value={stats?.appealsPending ?? 0} icon={MessageSquare} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-4 gap-6">
        <Card className="xl:col-span-3">
          <CardHeader title="Report Queue" description="User-generated reports and system flags">
            <div className="flex items-center gap-3">
              <select
                className="bg-slate-900 border border-slate-700 text-sm text-white py-2 px-3 rounded-lg outline-none focus:border-red-500"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="ALL">All Statuses</option>
                <option value="NEW">New</option>
                <option value="REVIEWING">Reviewing</option>
                <option value="ACTIONED">Actioned</option>
                <option value="REJECTED">Rejected</option>
              </select>
              <Input
                placeholder="Search target or reporter..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                leftIcon={Search}
                containerClassName="w-64"
              />
            </div>
          </CardHeader>
          <DataTable columns={filteredReports.length ? columns : []} data={filteredReports} isLoading={false} />
        </Card>

        <Card>
          <CardHeader title="Auto-Moderation" description="System configurations" />
          <div className="p-4 space-y-4">
            <div>
              <p className="text-sm font-medium text-white mb-1">Blocked Words Filter</p>
              <p className="text-xs text-slate-400 mb-2">Automatically flags messages containing restricted keywords.</p>
              <button
                onClick={() => navigate('/admin/chat')}
                className="w-full bg-slate-800 hover:bg-slate-700 border border-slate-700 text-white px-3 py-2 rounded-lg text-sm font-medium transition-colors"
              >
                Manage Word List →
              </button>
            </div>
            <hr className="border-slate-700/50" />
            <div>
              <p className="text-sm font-medium text-white mb-1">AI Image Scanner</p>
              <p className="text-xs text-slate-400 mb-2">Flags inappropriate profile pictures and stream thumbnails.</p>
              <div className="flex items-center justify-between bg-slate-900 p-2 rounded-lg border border-slate-700">
                <span className="text-xs text-emerald-400 font-medium">Status: Active</span>
                <span className="relative flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                </span>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <Modal isOpen={actionModal.open} onClose={() => setActionModal({ open: false, report: null })} title="Resolve Report" size="md">
        {actionModal.report && (
          <div className="space-y-4">
            <div className="bg-slate-800/50 p-4 rounded-xl border border-slate-700/50">
              <p className="text-xs text-slate-500 mb-1">Reported Entity</p>
              <p className="text-sm font-bold text-white">{actionModal.report.targetId} ({actionModal.report.targetType})</p>
              <p className="text-xs text-slate-500 mt-2 mb-1">Reason provided by {actionModal.report.reporter}</p>
              <p className="text-sm text-amber-400 font-medium">{actionModal.report.reason}</p>
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-400 mb-1">Resolution Notes (Required)</label>
              <textarea
                rows={3}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-red-500 outline-none transition-all resize-none"
                placeholder="Explain the action taken..."
                value={actionNotes}
                onChange={(e) => setActionNotes(e.target.value)}
              />
            </div>

            <div className="grid grid-cols-2 gap-3 pt-2">
              <button
                onClick={() => handleTakeAction('WARN')}
                disabled={!actionNotes}
                className="bg-amber-500 hover:bg-amber-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50"
              >
                Issue Warning
              </button>
              <button
                onClick={() => handleTakeAction('MUTE')}
                disabled={!actionNotes}
                className="bg-orange-500 hover:bg-orange-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50"
              >
                Mute / Restrict
              </button>
              <button
                onClick={() => handleTakeAction('BAN')}
                disabled={!actionNotes}
                className="bg-red-500 hover:bg-red-400 text-white px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50"
              >
                Ban Entity
              </button>
              <button
                onClick={() => handleTakeAction('REJECT')}
                disabled={!actionNotes}
                className="bg-slate-700 hover:bg-slate-600 text-white px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50"
              >
                Reject Report
              </button>
            </div>
          </div>
        )}
      </Modal>

      {viewLogModal.open && (
        <Modal isOpen={true} onClose={() => setViewLogModal({ open: false, report: null })} title="Moderation Resolution Log">
          <div className="space-y-3 text-xs text-slate-300">
            <p><strong>Report Reference:</strong> {viewLogModal.report?.id}</p>
            <p><strong>Target Entity:</strong> {viewLogModal.report?.targetId}</p>
            <p><strong>Action Executed:</strong> <span className="text-emerald-400 font-bold">{viewLogModal.report?.status}</span></p>
            <p><strong>Audit Log:</strong> Action resolved and saved to admin audit history.</p>
          </div>
        </Modal>
      )}
    </div>
  );
}
