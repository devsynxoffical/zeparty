// ============================================================
// ZeParty Admin Portal — Fraud & Risk Center Page (JSX)
// Client Excel Phase C Requirements
// ============================================================

import React, { useState, useEffect } from 'react';
import { ShieldAlert, Search, AlertTriangle, Lock, CheckCircle, Eye } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { formatDate } from '../../utils/format';
import apiClient from '../../services/api';

export function FraudRiskPage() {
  const [alerts, setAlerts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [activeAlert, setActiveAlert] = useState(null);
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    apiClient.get('/v1/admin/reports')
      .then((res) => {
        if (mounted) {
          const items = res.data?.data || [];
          setAlerts(items.map((r) => ({
            id: r.id,
            user: r.targetUser?.username || r.targetUserId || 'Flagged Subject',
            userId: r.targetUserId,
            reason: r.reason || 'Safety / Risk Alert',
            riskScore: r.riskScore || 75,
            severity: r.severity?.toLowerCase() || 'medium',
            status: r.status?.toLowerCase() || 'pending',
            date: r.createdAt || new Date().toISOString(),
            actionTaken: r.resolution || null,
          })));
          setLoading(false);
        }
      })
      .catch(() => {
        if (mounted) {
          setAlerts([]);
          setLoading(false);
        }
      });
    return () => { mounted = false; };
  }, []);

  const handleAction = (newStatus, msg) => {
    if (!activeAlert) return;
    setAlerts(alerts.map(a => a.id === activeAlert.id ? { ...a, status: newStatus } : a));
    setFeedback(msg);
    setActiveAlert(null);
    setTimeout(() => setFeedback(null), 3000);
  };

  const columns = [
    {
      key: 'id',
      header: 'Alert ID',
      render: (r) => <span className="text-xs font-mono font-bold text-white">{r.id}</span>,
    },
    {
      key: 'user',
      header: 'Flagged User',
      render: (r) => <span className="text-xs font-semibold text-white">{r.user} ({r.userId})</span>,
    },
    {
      key: 'riskType',
      header: 'Detection Trigger',
      render: (r) => <Badge variant="warning">{r.riskType}</Badge>,
    },
    {
      key: 'riskScore',
      header: 'Risk Score',
      render: (r) => (
        <span className={`text-xs font-bold font-mono ${r.riskScore > 90 ? 'text-red-400' : 'text-amber-400'}`}>
          {r.riskScore} / 100
        </span>
      ),
    },
    {
      key: 'status',
      header: 'State',
      render: (r) => <StatusBadge status={r.status.toLowerCase()} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <Button variant="primary" size="xs" onClick={() => setActiveAlert(r)}>
          Inspect Alert
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ShieldAlert className="h-6 w-6 text-red-400" />
            Fraud & Risk Intelligence Center
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Automated detection for self-gifting, abnormal transfers, multi-account IP collusion, and device risk.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{feedback}</span>
          <span className="font-mono">PROCESSED</span>
        </div>
      )}

      <Card className="p-4">
        <Input
          placeholder="Search risk alert ID, user, or trigger..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={alerts} isLoading={false} />

      {activeAlert && (
        <Modal
          isOpen={true}
          onClose={() => setActiveAlert(null)}
          title={`Risk Intelligence Case: ${activeAlert.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 rounded-xl bg-slate-800 border border-slate-700 space-y-1.5">
              <p><strong>Flagged Target:</strong> {activeAlert.user}</p>
              <p><strong>Risk Score:</strong> <span className="text-red-400 font-bold">{activeAlert.riskScore}/100</span></p>
              <p><strong>Trigger Reason:</strong> {activeAlert.flaggedReason}</p>
              <p><strong>Detected:</strong> {formatDate(activeAlert.timestamp)}</p>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => handleAction('DISMISSED', `Risk alert ${activeAlert.id} dismissed.`)}>
                Dismiss Flag
              </Button>
              <Button variant="outline" size="sm" onClick={() => handleAction('CLEARED', `Risk score for ${activeAlert.user} cleared.`)}>
                Clear Risk Score
              </Button>
              <Button variant="danger" size="sm" onClick={() => handleAction('FROZEN', `Selective balance freeze applied to ${activeAlert.user}.`)}>
                Freeze Affected Balance
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
