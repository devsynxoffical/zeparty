// ============================================================
// ZeParty Admin Portal — Refund Requests Page (JSX)
// Client Excel Phase C Requirements
// ============================================================

import React, { useState } from 'react';
import { RotateCcw, Search, CheckCircle, XCircle, FileText } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

const INITIAL_REQUESTS = [
  {
    id: 'REQ-401',
    requester: 'BlazingRose (usr-003)',
    txnId: 'TXN-55102',
    coins: 100000,
    amountUSD: 10.0,
    reason: 'Accidental double tap on coin gift during lag',
    status: 'PENDING_REVIEW',
  },
];

export function RefundRequestsPage() {
  const { logAdminAction } = useAuditLog();
  const [requests, setRequests] = useState(INITIAL_REQUESTS);
  const [search, setSearch] = useState('');
  const [selectedReq, setSelectedReq] = useState(null);
  const [feedback, setFeedback] = useState(null);

  const handleAction = async (status) => {
    if (!selectedReq) return;
    setRequests(requests.map(r => r.id === selectedReq.id ? { ...r, status } : r));
    
    await logAdminAction({
      action: `REFUND_REQUEST_${status}`,
      module: 'Refunds',
      targetType: 'refund_request',
      targetId: selectedReq.id,
      targetName: selectedReq.requester,
      reason: `Refund request evaluated as ${status}`,
      riskLevel: 'HIGH',
      afterValue: { status }
    });

    setFeedback(`Refund request ${selectedReq.id} marked as ${status}.`);
    setSelectedReq(null);
    setTimeout(() => setFeedback(null), 3000);
  };

  const columns = [
    {
      key: 'id',
      header: 'Request Reference',
      render: (r) => (
        <div>
          <p className="text-xs font-mono font-bold text-white">{r.id}</p>
          <p className="text-[11px] text-slate-400 font-mono">TX: {r.txnId}</p>
        </div>
      ),
    },
    {
      key: 'requester',
      header: 'Requester',
      render: (r) => <span className="text-xs font-semibold text-white">{r.requester}</span>,
    },
    {
      key: 'coins',
      header: 'Requested Coins',
      render: (r) => <span className="text-xs font-mono font-bold text-yellow-400">🪙 {formatNumber(r.coins)} (${r.amountUSD})</span>,
    },
    {
      key: 'reason',
      header: 'Reason',
      render: (r) => <span className="text-xs text-slate-300 italic">{r.reason}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <StatusBadge status={r.status.toLowerCase()} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <Button variant="primary" size="xs" onClick={() => setSelectedReq(r)}>
          Review Request
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <RotateCcw className="h-6 w-6 text-gold-400" />
            User & Merchant Refund Requests
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Review, partial/full refund controls, and ticket escalation.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{feedback}</span>
          <span className="font-mono">UPDATED</span>
        </div>
      )}

      <Card className="p-4">
        <Input
          placeholder="Search by requester or request ID..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={requests} isLoading={false} />

      {selectedReq && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedReq(null)}
          title={`Review Refund Request: ${selectedReq.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 rounded-xl bg-slate-800 border border-slate-700 space-y-1.5">
              <p><strong>Requester:</strong> {selectedReq.requester}</p>
              <p><strong>Transaction:</strong> <code className="text-gold-400">{selectedReq.txnId}</code></p>
              <p><strong>Coins Claimed:</strong> 🪙 {formatNumber(selectedReq.coins)} (${selectedReq.amountUSD})</p>
              <p><strong>Reason:</strong> {selectedReq.reason}</p>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedReq(null)}>
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={() => handleAction('REJECTED')}>
                Reject
              </Button>
              <Button variant="outline" size="sm" onClick={() => handleAction('PARTIAL_REFUND')}>
                Partial Refund
              </Button>
              <Button variant="primary" size="sm" onClick={() => handleAction('APPROVED')}>
                Full Refund
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
