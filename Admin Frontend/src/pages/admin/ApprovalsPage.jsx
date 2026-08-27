// ============================================================
// ZeParty Admin Portal — Central Approval Center (JSX)
// 4-Eyes Principle + Audit Trail + Action-Level RBAC
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import {
  ShieldCheck,
  Search,
  Filter,
  CheckCircle2,
  XCircle,
  Clock,
  AlertTriangle,
  ArrowRight,
  User,
  DollarSign,
  Coins,
  Gamepad2,
  FileText,
  PauseCircle,
  TrendingUp,
  Lock,
  Layers,
  Eye,
  Check,
  X
} from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { formatCurrency, formatDate, formatNumber } from '../../utils/format';
import { usePermission } from '../../hooks/usePermission';
import { useAuth } from '../../hooks/useAuth';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getApprovals,
  processApprovalStep,
  createApprovalRequest
} from '../../services/modules/approvals.service';
import {
  APPROVAL_CATEGORIES,
  APPROVAL_STATUSES
} from '../../mocks/approvals.mock';

export function ApprovalsPage() {
  const { admin } = useAuth();
  const { isSuperAdmin, hasPermission } = usePermission();
  const { logAdminAction } = useAuditLog();

  const [approvals, setApprovals] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [categoryFilter, setCategoryFilter] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [actionModal, setActionModal] = useState({ open: false, type: null, request: null });
  const [decisionNote, setDecisionNote] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);
  const [feedback, setFeedback] = useState(null);
  const [errorMessage, setErrorMessage] = useState('');

  const currentAdminName = admin?.displayName || admin?.name || 'Super Admin';
  const currentAdminRole = admin?.roleName || (isSuperAdmin ? 'Super Admin' : 'Finance Admin');

  useEffect(() => {
    loadApprovals();
  }, []);

  async function loadApprovals() {
    setIsLoading(true);
    try {
      const data = await getApprovals();
      setApprovals(data);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  }

  const showNotification = (msg, isError = false) => {
    if (isError) {
      setErrorMessage(msg);
      setTimeout(() => setErrorMessage(''), 4000);
    } else {
      setFeedback(msg);
      setTimeout(() => setFeedback(null), 4000);
    }
  };

  const filteredApprovals = useMemo(() => {
    return approvals.filter((item) => {
      const matchCat = categoryFilter === 'ALL' || item.category === categoryFilter;
      const matchStatus = statusFilter === 'ALL' || item.status === statusFilter;
      const q = search.toLowerCase();
      const matchSearch =
        !q ||
        item.id.toLowerCase().includes(q) ||
        item.title.toLowerCase().includes(q) ||
        item.requesterName.toLowerCase().includes(q) ||
        item.targetName.toLowerCase().includes(q);
      return matchCat && matchStatus && matchSearch;
    });
  }, [approvals, categoryFilter, statusFilter, search]);

  const handleDecision = async (actionType) => {
    if (!actionModal.request) return;
    setIsProcessing(true);
    setErrorMessage('');

    try {
      const req = actionModal.request;
      // 4-Eyes Check: Ensure same operator doesn't sign off both steps
      if (
        actionType === 'APPROVE' &&
        req.approvalModel === 'FOUR_EYES' &&
        req.completedSteps === 1 &&
        req.reviewer1 === currentAdminName
      ) {
        throw new Error('Four-Eyes Enforcement: The second reviewer must be a different administrator.');
      }

      const updated = await processApprovalStep(
        req.id,
        actionType,
        currentAdminName,
        currentAdminRole,
        decisionNote.trim()
      );

      setApprovals((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));

      if (selectedRequest?.id === updated.id) {
        setSelectedRequest(updated);
      }

      await logAdminAction({
        action: `APPROVAL_${actionType}`,
        module: 'Approvals',
        targetType: 'approval_request',
        targetId: req.id,
        targetName: req.title,
        reason: decisionNote || `Performed ${actionType} on ${req.id}`,
        riskLevel: req.riskLevel,
      });

      showNotification(`Action "${actionType}" successfully executed for ${req.id}.`);
      setActionModal({ open: false, type: null, request: null });
      setDecisionNote('');
    } catch (err) {
      showNotification(err.message || 'Operation failed.', true);
    } finally {
      setIsProcessing(false);
    }
  };

  const getRiskBadge = (risk) => {
    switch (risk) {
      case 'CRITICAL':
        return <Badge variant="danger" className="font-bold">CRITICAL</Badge>;
      case 'HIGH':
        return <Badge variant="warning" className="font-bold">HIGH RISK</Badge>;
      case 'MEDIUM':
        return <Badge variant="purple">MEDIUM</Badge>;
      default:
        return <Badge variant="outline">LOW RISK</Badge>;
    }
  };

  const columns = [
    {
      key: 'id',
      header: 'Request Reference',
      render: (row) => (
        <div>
          <div className="flex items-center gap-1.5">
            <span className="font-mono text-xs font-bold text-white">{row.id}</span>
            {row.approvalModel === 'FOUR_EYES' && (
              <span className="px-1.5 py-0.5 rounded bg-indigo-500/20 text-indigo-300 text-[10px] font-mono border border-indigo-500/40">
                4-EYES
              </span>
            )}
          </div>
          <p className="text-xs text-slate-400 mt-0.5 max-w-[200px] truncate">{row.title}</p>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Category & Type',
      render: (row) => (
        <div>
          <Badge variant="purple" className="text-[10px]">{row.category}</Badge>
          <p className="text-xs text-slate-300 font-medium mt-0.5">{row.type}</p>
        </div>
      ),
    },
    {
      key: 'requester',
      header: 'Requester & Target',
      render: (row) => (
        <div>
          <p className="text-xs font-semibold text-white">{row.requesterName}</p>
          <p className="text-[11px] text-slate-400">Target: <span className="text-slate-200">{row.targetName}</span></p>
        </div>
      ),
    },
    {
      key: 'amount',
      header: 'Amount / Value',
      render: (row) => (
        <div>
          {row.amountUSD ? (
            <span className="text-xs font-mono font-bold text-emerald-400">
              {formatCurrency(row.amountUSD)}
            </span>
          ) : row.amountCoins ? (
            <span className="text-xs font-mono font-bold text-yellow-400">
              🪙 {formatNumber(row.amountCoins)}
            </span>
          ) : (
            <span className="text-xs text-slate-400 font-mono">Policy / Economics</span>
          )}
        </div>
      ),
    },
    {
      key: 'risk',
      header: 'Risk Level',
      render: (row) => getRiskBadge(row.riskLevel),
    },
    {
      key: 'steps',
      header: 'Workflow Stage',
      render: (row) => (
        <div>
          <div className="flex items-center gap-1 text-xs">
            <span className="font-bold text-white">{row.completedSteps}</span>
            <span className="text-slate-400">/ {row.requiredSteps} Approvals</span>
          </div>
          <div className="w-24 bg-slate-800 rounded-full h-1.5 mt-1 overflow-hidden">
            <div
              className={`h-full ${row.status === 'REJECTED' ? 'bg-red-500' : 'bg-gold-500'}`}
              style={{ width: `${(row.completedSteps / row.requiredSteps) * 100}%` }}
            />
          </div>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status.toLowerCase()} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex items-center gap-1">
          <Button
            variant="outline"
            size="xs"
            onClick={() => setSelectedRequest(row)}
            leftIcon={Eye}
          >
            Review
          </Button>
          {(row.status === 'PENDING' || row.status === 'UNDER_REVIEW') && (
            <>
              <button
                title="Quick Approve"
                onClick={() => setActionModal({ open: true, type: 'APPROVE', request: row })}
                className="p-1.5 rounded-lg text-slate-400 hover:text-emerald-400 hover:bg-slate-800 transition-colors"
              >
                <Check className="h-4 w-4" />
              </button>
              <button
                title="Quick Reject"
                onClick={() => setActionModal({ open: true, type: 'REJECT', request: row })}
                className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-800 transition-colors"
              >
                <X className="h-4 w-4" />
              </button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6 max-w-screen-2xl mx-auto" aria-label="Approval Center">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ShieldCheck className="h-7 w-7 text-gold-400" />
            Governance & Approval Center
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Four-Eyes verification queue, financial approval workflows, and immutable administrative sign-offs.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="purple" className="px-3 py-1.5 text-xs font-mono">
            Active Operator: {currentAdminName} ({currentAdminRole})
          </Badge>
        </div>
      </div>

      {/* Notifications */}
      {feedback && (
        <div className="p-4 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="h-5 w-5 shrink-0" />
            <span>{feedback}</span>
          </div>
          <span className="font-mono text-[11px]">AUDITED</span>
        </div>
      )}

      {errorMessage && (
        <div className="p-4 rounded-xl bg-red-500/20 border border-red-500/40 text-red-400 text-xs font-bold flex items-center gap-2">
          <AlertTriangle className="h-5 w-5 shrink-0" />
          <span>{errorMessage}</span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Total Pending Review</p>
          <p className="text-2xl font-bold text-gold-400 mt-1">
            {approvals.filter((a) => a.status === 'PENDING' || a.status === 'UNDER_REVIEW').length}
          </p>
        </Card>
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Four-Eyes (2-Admin) Queue</p>
          <p className="text-2xl font-bold text-indigo-400 mt-1">
            {approvals.filter((a) => a.approvalModel === 'FOUR_EYES' && a.status !== 'APPROVED').length}
          </p>
        </Card>
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Approved This Week</p>
          <p className="text-2xl font-bold text-emerald-400 mt-1">
            {approvals.filter((a) => a.status === 'APPROVED' || a.status === 'COMPLETED').length}
          </p>
        </Card>
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Rejected / Escalated</p>
          <p className="text-2xl font-bold text-red-400 mt-1">
            {approvals.filter((a) => a.status === 'REJECTED' || a.status === 'ESCALATED').length}
          </p>
        </Card>
      </div>

      {/* Category Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-1 border-b border-slate-800">
        {APPROVAL_CATEGORIES.map((cat) => (
          <button
            key={cat}
            onClick={() => setCategoryFilter(cat)}
            className={`px-3.5 py-2 rounded-t-lg text-xs font-semibold whitespace-nowrap transition-colors border-b-2 ${
              categoryFilter === cat
                ? 'text-gold-400 border-gold-500 bg-gold-500/10'
                : 'text-slate-400 border-transparent hover:text-white'
            }`}
          >
            {cat.replace('_', ' ')}
          </button>
        ))}
      </div>

      {/* Filters Bar */}
      <Card className="p-4 flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
        <Input
          placeholder="Search by ID, title, requester, or target…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md"
        />

        <div className="flex items-center gap-2 overflow-x-auto">
          <span className="text-xs text-slate-400 whitespace-nowrap">Status:</span>
          {APPROVAL_STATUSES.map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-2.5 py-1 rounded-lg text-xs font-medium capitalize border transition-colors ${
                statusFilter === st
                  ? 'bg-gold-500/20 border-gold-500/50 text-gold-400 font-bold'
                  : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
              }`}
            >
              {st.toLowerCase().replace('_', ' ')}
            </button>
          ))}
        </div>
      </Card>

      {/* Table */}
      <DataTable
        columns={columns}
        data={filteredApprovals}
        isLoading={isLoading}
        emptyTitle="No approval requests found"
        emptyDescription="All pending requests have been reviewed or match filters."
      />

      {/* Detailed Review Modal */}
      {selectedRequest && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedRequest(null)}
          title={`Approval Review: ${selectedRequest.id}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            {/* Header info */}
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-700/60 flex flex-col md:flex-row justify-between gap-3">
              <div>
                <span className="text-lg font-bold text-white">{selectedRequest.title}</span>
                <p className="text-xs text-slate-400 mt-0.5">
                  Category: <strong className="text-gold-400">{selectedRequest.category}</strong> • Reference: <code className="text-slate-300 font-mono">{selectedRequest.id}</code>
                </p>
              </div>
              <div className="flex items-center gap-2">
                {getRiskBadge(selectedRequest.riskLevel)}
                <StatusBadge status={selectedRequest.status.toLowerCase()} />
              </div>
            </div>

            {/* Workflow / 4-Eyes Progress */}
            <div className="p-3.5 rounded-xl bg-slate-800/60 border border-slate-700/50 space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-bold text-white flex items-center gap-1.5">
                  <Lock className="h-4 w-4 text-gold-400" />
                  Approval Model: {selectedRequest.approvalModel === 'FOUR_EYES' ? 'Four-Eyes (2 Administrators Required)' : 'Single Administrator Sign-Off'}
                </span>
                <span className="font-mono text-gold-400 font-bold">
                  {selectedRequest.completedSteps} / {selectedRequest.requiredSteps} Steps Completed
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 text-[11px] pt-1">
                <div className="p-2 rounded bg-slate-900 border border-slate-800">
                  <p className="text-slate-400">Step 1 Reviewer:</p>
                  <p className="font-bold text-white">{selectedRequest.reviewer1 || 'Pending Review'}</p>
                </div>
                <div className="p-2 rounded bg-slate-900 border border-slate-800">
                  <p className="text-slate-400">Step 2 Final Approver:</p>
                  <p className="font-bold text-white">{selectedRequest.reviewer2 || selectedRequest.approver || (selectedRequest.approvalModel === 'FOUR_EYES' ? 'Awaiting Step 2' : 'Pending Approval')}</p>
                </div>
              </div>
            </div>

            {/* Key Entities & Transaction Traceability */}
            <div className="grid grid-cols-2 gap-3 p-3.5 rounded-xl bg-slate-800/40 border border-slate-700/40">
              <div>
                <p className="text-slate-400">Requested By:</p>
                <p className="font-bold text-white">{selectedRequest.requesterName} <span className="text-slate-400 font-normal">({selectedRequest.requesterRole})</span></p>
                <p className="text-[11px] text-slate-400 mt-1">Submitted: {formatDate(selectedRequest.createdAt)}</p>
              </div>
              <div>
                <p className="text-slate-400">Affected Target:</p>
                <p className="font-bold text-white">{selectedRequest.targetName}</p>
                <p className="text-[11px] text-slate-400 mt-1">Target ID: <code className="font-mono text-slate-300">{selectedRequest.targetId}</code></p>
              </div>
              {selectedRequest.relatedTxId && (
                <div className="col-span-2 border-t border-slate-700/40 pt-2">
                  <p className="text-slate-400">Related Transaction / Document ID:</p>
                  <p className="font-mono text-emerald-400 font-bold">{selectedRequest.relatedTxId}</p>
                </div>
              )}
            </div>

            {/* Reason & Evidence */}
            <div className="p-3.5 rounded-xl bg-slate-800/40 border border-slate-700/40 space-y-1.5">
              <p className="text-slate-400 font-semibold">Justification / Reason:</p>
              <p className="text-slate-200">{selectedRequest.reason}</p>
              {selectedRequest.evidence && (
                <div className="mt-2 pt-2 border-t border-slate-700/40">
                  <p className="text-slate-400 font-semibold">Supporting Evidence / Verification:</p>
                  <p className="text-slate-300 italic">{selectedRequest.evidence}</p>
                </div>
              )}
            </div>

            {/* Before vs After Values */}
            {(selectedRequest.beforeValue || selectedRequest.afterValue) && (
              <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-700/60 space-y-2">
                <p className="font-bold text-white flex items-center gap-1.5">
                  <ArrowRight className="h-4 w-4 text-gold-400" />
                  State Mutation Comparison (Before vs After)
                </p>
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-2.5 rounded bg-slate-800/80 border border-red-500/20">
                    <span className="text-[10px] font-bold text-red-400 uppercase tracking-wider block mb-1">State Before Change</span>
                    <pre className="text-[11px] font-mono text-slate-300 whitespace-pre-wrap">
                      {JSON.stringify(selectedRequest.beforeValue, null, 2)}
                    </pre>
                  </div>
                  <div className="p-2.5 rounded bg-slate-800/80 border border-emerald-500/20">
                    <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wider block mb-1">Proposed State After Change</span>
                    <pre className="text-[11px] font-mono text-emerald-300 whitespace-pre-wrap">
                      {JSON.stringify(selectedRequest.afterValue, null, 2)}
                    </pre>
                  </div>
                </div>
              </div>
            )}

            {/* Audit History Log */}
            <div className="space-y-1.5">
              <p className="font-bold text-white">Approval History Timeline:</p>
              <div className="space-y-1.5 max-h-36 overflow-y-auto pr-1">
                {selectedRequest.history?.map((h, i) => (
                  <div key={i} className="p-2 rounded-lg bg-slate-800/50 border border-slate-700/40 flex justify-between items-start text-[11px]">
                    <div>
                      <span className="font-bold text-white">{h.action}</span> by <strong className="text-gold-400">{h.operator}</strong> ({h.role})
                      <p className="text-slate-400 mt-0.5">{h.note}</p>
                    </div>
                    <span className="text-slate-500 font-mono text-[10px]">{formatDate(h.timestamp)}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Action Bar */}
            <div className="flex flex-wrap items-center justify-between gap-2 pt-3 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedRequest(null)}>
                Close
              </Button>

              {(selectedRequest.status === 'PENDING' || selectedRequest.status === 'UNDER_REVIEW') && (
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setActionModal({ open: true, type: 'HOLD', request: selectedRequest })}
                  >
                    Hold
                  </Button>
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={() => setActionModal({ open: true, type: 'REJECT', request: selectedRequest })}
                  >
                    Reject
                  </Button>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={() => setActionModal({ open: true, type: 'APPROVE', request: selectedRequest })}
                  >
                    {selectedRequest.approvalModel === 'FOUR_EYES' && selectedRequest.completedSteps === 0
                      ? 'Confirm First Approval'
                      : 'Authorize Final Approval'}
                  </Button>
                </div>
              )}
            </div>
          </div>
        </Modal>
      )}

      {/* Decision Confirmation Modal */}
      {actionModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setActionModal({ open: false, type: null, request: null })}
          title={`Confirm Action: ${actionModal.type}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Are you sure you want to perform <strong>{actionModal.type}</strong> on approval request{' '}
              <strong className="text-white">{actionModal.request?.id}</strong> ({actionModal.request?.title})?
            </p>

            {actionModal.type === 'APPROVE' && actionModal.request?.approvalModel === 'FOUR_EYES' && (
              <div className="p-3 rounded-lg bg-indigo-500/10 border border-indigo-500/30 text-indigo-300">
                <p className="font-bold">4-Eyes Governance Notice:</p>
                <p className="mt-0.5">
                  {actionModal.request?.completedSteps === 0
                    ? 'This will record your sign-off as Step 1 Reviewer. A second administrator will be required to finalize the approval.'
                    : `You (${currentAdminName}) are acting as the Second Administrator to finalize this transaction.`}
                </p>
              </div>
            )}

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Audit Note / Reason (Mandatory for compliance)
              </label>
              <textarea
                rows={3}
                value={decisionNote}
                onChange={(e) => setDecisionNote(e.target.value)}
                placeholder="Enter justification for audit records…"
                className="w-full rounded-lg border border-slate-700 bg-slate-800 p-2.5 text-xs text-white focus:outline-none focus:ring-1 focus:ring-gold-500"
                required
              />
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setActionModal({ open: false, type: null, request: null })}
                disabled={isProcessing}
              >
                Cancel
              </Button>
              <Button
                variant={actionModal.type === 'REJECT' ? 'danger' : 'primary'}
                size="sm"
                onClick={() => handleDecision(actionModal.type)}
                isLoading={isProcessing}
              >
                Confirm {actionModal.type}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
