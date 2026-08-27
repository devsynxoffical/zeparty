// ============================================================
// ZeParty Admin Portal — Withdrawal Center & Settlement (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import {
  Wallet, Search, CheckCircle, XCircle, Pause, Play, DollarSign, Download,
  ShieldCheck, Eye, ArrowRight, History, Lock, Globe, UserCheck, Image, Link as LinkIcon
} from 'lucide-react';
import { usePermission } from '../../hooks/usePermission';
import { getWithdrawals } from '../../services/modules/monetization.service';
import { useAuditLog } from '../../context/AuditLogContext';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { formatCurrency, formatDate, formatNumber } from '../../utils/format';
import { CURRENT_WITHDRAWAL_POLICY } from '../../mocks/policyConfig.mock';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { getCountryShortName } from '../../constants/countries.data';

const getSLATimer = (requestedAt) => {
  const reqDate = new Date(requestedAt);
  const targetDate = new Date(reqDate.getTime() + 15 * 24 * 60 * 60 * 1000);
  const today = new Date('2026-08-24T12:00:00Z'); // Static context time anchor
  const diffTime = targetDate - today;
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  return {
    targetDate: targetDate.toISOString().split('T')[0],
    daysLeft: diffDays,
    isBreaching: diffDays <= 3,
    isOverdue: diffDays < 0
  };
};

export function WithdrawalsPage() {
  const { canPerformAction, isSuperAdmin } = usePermission();
  const { logAdminAction } = useAuditLog();

  const [withdrawals, setWithdrawals] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [statusFilter, setStatusFilter] = useState('all');
  const [actionModal, setActionModal] = useState({ open: false, withdrawal: null, actionType: null });
  const [selectedWithdrawal, setSelectedWithdrawal] = useState(null);
  
  // Custom interactive workflow states
  const [holdingPeriodHours, setHoldingPeriodHours] = useState('24');
  const [assignResellerModal, setAssignResellerModal] = useState({ open: false, withdrawal: null });
  const [selectedReseller, setSelectedReseller] = useState('');
  const [paymentProofModal, setPaymentProofModal] = useState({ open: false, withdrawal: null });
  const [paymentProofUrl, setPaymentProofUrl] = useState('https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=300&auto=format&fit=crop');
  
  const [actionReason, setActionReason] = useState('');
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    getWithdrawals()
      .then((data) => {
        // Map mock data to assign roles (Host, User, Merchant, Coin Seller) and requested dates
        const formatted = data.map((w, i) => {
          const roleType = i % 4 === 0 ? 'Host' : i % 4 === 1 ? 'User' : i % 4 === 2 ? 'Merchant' : 'Coin Seller';
          
          // Generate request dates to show different timer phases (active, warning, overdue)
          const daysAgo = i * 4 + 2; 
          const requestedAtDate = new Date();
          requestedAtDate.setDate(requestedAtDate.getDate() - daysAgo);
          
          return {
            ...w,
            roleType,
            requestedAt: requestedAtDate.toISOString().split('T')[0],
            country: w.country || (i % 2 === 0 ? 'US' : 'CN'),
            status: w.status === 'paid' ? 'Paid/Settled' : w.status === 'approved' ? 'Approved' : 'Pending',
            resellerId: w.resellerId || null,
            resellerName: w.resellerName || null,
            paymentProof: w.paymentProof || null,
            ledgerChainId: w.ledgerChainId || null
          };
        });
        setWithdrawals(formatted);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const patchWithdrawal = (id, patch) => {
    setWithdrawals((prev) =>
      prev.map((w) => (w.id === id ? { ...w, ...patch } : w))
    );
  };

  // Step 1: Send to Holding Period
  const handleSendToHolding = async (w) => {
    patchWithdrawal(w.id, { status: 'Holding', holdingUntil: new Date(Date.now() + Number(holdingPeriodHours) * 3600 * 1000).toISOString() });
    await logAdminAction({
      action: 'WITHDRAWAL_HOLDING',
      module: 'Withdrawals',
      targetType: 'withdrawal',
      targetId: w.id,
      targetName: `Withdrawal ${w.id}`,
      reason: `Entered holding period of ${holdingPeriodHours} hours.`,
      riskLevel: 'MEDIUM',
    });
    showFeedback(`Withdrawal ${w.id} is now placed in Holding status.`);
  };

  // Step 2: Approve Withdrawal (Move from Holding/Pending to Approved)
  const handleApproveWithdrawal = async (w) => {
    patchWithdrawal(w.id, { status: 'Approved' });
    await logAdminAction({
      action: 'WITHDRAWAL_APPROVED',
      module: 'Withdrawals',
      targetType: 'withdrawal',
      targetId: w.id,
      targetName: `Withdrawal ${w.id}`,
      reason: `Approved via 4-Eyes security review.`,
      riskLevel: 'HIGH',
    });
    showFeedback(`Withdrawal ${w.id} approved. Awaiting Reseller Assignment.`);
  };

  // Step 3: Assign Reseller/Merchant for Payment Routing
  const handleAssignReseller = async () => {
    const { withdrawal } = assignResellerModal;
    if (!withdrawal || !selectedReseller) return;

    patchWithdrawal(withdrawal.id, {
      status: 'Assigned',
      resellerName: selectedReseller,
      resellerId: `res-${Math.floor(Math.random() * 1000)}`
    });

    await logAdminAction({
      action: 'WITHDRAWAL_RESELLER_ASSIGNED',
      module: 'Withdrawals',
      targetType: 'withdrawal',
      targetId: withdrawal.id,
      targetName: `Withdrawal ${withdrawal.id}`,
      reason: `Assigned settlement partner ${selectedReseller} for country routing`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Withdrawal ${withdrawal.id} assigned to ${selectedReseller}.`);
    setAssignResellerModal({ open: false, withdrawal: null });
    setSelectedReseller('');
  };

  // Step 4: Submit Payment Proof
  const handleSubmitPaymentProof = async () => {
    const { withdrawal } = paymentProofModal;
    if (!withdrawal) return;

    patchWithdrawal(withdrawal.id, {
      status: 'Payment Submitted',
      paymentProof: paymentProofUrl
    });

    await logAdminAction({
      action: 'WITHDRAWAL_PAYMENT_SUBMITTED',
      module: 'Withdrawals',
      targetType: 'withdrawal',
      targetId: withdrawal.id,
      targetName: `Withdrawal ${withdrawal.id}`,
      reason: `Payment receipt proof uploaded by reseller`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Payment proof submitted for withdrawal ${withdrawal.id}.`);
    setPaymentProofModal({ open: false, withdrawal: null });
  };

  // Step 5: Verify Payment Proof & Mark Paid/Settled
  const handleVerifyAndSettle = async (w) => {
    const chainId = `chn-${Math.floor(Math.random() * 1000000)}`;
    patchWithdrawal(w.id, {
      status: 'Paid/Settled',
      ledgerChainId: chainId
    });

    await logAdminAction({
      action: 'WITHDRAWAL_PAID_SETTLED',
      module: 'Withdrawals',
      targetType: 'withdrawal',
      targetId: w.id,
      targetName: `Withdrawal ${w.id}`,
      reason: `Payment verified. Ledger transaction created: ${chainId}`,
      riskLevel: 'CRITICAL',
    });

    showFeedback(`Withdrawal ${w.id} verified and settled. Ledger created.`);
  };

  // Rejection / Hold Terminals
  const handleExecuteTerminalAction = async () => {
    if (!actionModal.withdrawal) return;
    const { id } = actionModal.withdrawal;
    const { actionType } = actionModal;

    let newStatus = 'Rejected';
    if (actionType === 'hold') newStatus = 'Held';

    patchWithdrawal(id, { status: newStatus, note: actionReason });

    await logAdminAction({
      action: `WITHDRAWAL_${actionType.toUpperCase()}`,
      module: 'Withdrawals',
      targetType: 'withdrawal',
      targetId: id,
      targetName: `Withdrawal ${id}`,
      reason: actionReason,
      riskLevel: 'HIGH',
    });

    showFeedback(`Withdrawal ${id} status updated to ${newStatus}.`);
    setActionModal({ open: false, withdrawal: null, actionType: null });
    setActionReason('');
  };

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return withdrawals.filter((w) => {
      const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || w.country?.toLowerCase() === selectedCountry.toLowerCase();
      const matchStatus = statusFilter === 'all' || w.status.toLowerCase() === statusFilter.toLowerCase() || (statusFilter === 'paid' && w.status === 'Paid/Settled');
      const matchSearch =
        !q ||
        w.hostName?.toLowerCase().includes(q) ||
        w.hostUsername?.toLowerCase().includes(q) ||
        w.id?.toLowerCase().includes(q);
      return matchCountry && matchStatus && matchSearch;
    });
  }, [withdrawals, search, selectedCountry, statusFilter]);

  const columns = [
    {
      key: 'host',
      header: 'Requestor & Account Type',
      render: (row) => {
        let badgeColor = 'purple';
        if (row.roleType === 'User') badgeColor = 'info';
        if (row.roleType === 'Merchant') badgeColor = 'warning';
        if (row.roleType === 'Coin Seller') badgeColor = 'success';
        
        return (
          <div>
            <p className="font-bold text-white text-sm">{row.hostName}</p>
            <div className="flex flex-wrap items-center gap-1.5 mt-1">
              <span className="text-[10px] text-slate-400">ID: {row.id}</span>
              <Badge variant={badgeColor} className="text-[9px] uppercase">{row.roleType || 'Host'}</Badge>
              <Badge variant="default" className="text-[9px] font-semibold flex items-center gap-1">
                <CountryFlag code={row.country} className="w-3 h-2 object-cover rounded-sm shrink-0" />
                <span>{getCountryShortName(row.country)}</span>
              </Badge>
            </div>
          </div>
        );
      },
    },
    {
      key: 'amount',
      header: 'Conversion USD',
      render: (row) => (
        <div>
          <span className="font-mono text-sm font-bold text-emerald-400">
            {formatCurrency(row.amount)}
          </span>
          <p className="text-[10px] text-slate-400">Request: {row.requestedAt}</p>
        </div>
      ),
    },
    {
      key: 'slaTimer',
      header: '15-Day SLA Countdown',
      render: (row) => {
        if (row.status === 'Paid/Settled') {
          return <Badge variant="success">Completed within SLA</Badge>;
        }
        
        const sla = getSLATimer(row.requestedAt || '2026-08-20');
        let badgeVariant = 'default';
        if (sla.isOverdue) badgeVariant = 'danger';
        else if (sla.isBreaching) badgeVariant = 'warning';
        
        return (
          <div>
            <Badge variant={badgeVariant} className="font-mono text-[10px]">
              {sla.isOverdue 
                ? `OVERDUE BY ${Math.abs(sla.daysLeft)} DAYS!` 
                : sla.isBreaching 
                  ? `${sla.daysLeft} days left (WARNING)` 
                  : `${sla.daysLeft} days remaining`
              }
            </Badge>
            <p className="text-[10px] text-slate-500 font-mono mt-0.5">Deadline: {sla.targetDate}</p>
          </div>
        );
      }
    },
    {
      key: 'route',
      header: 'Settlement Partner',
      render: (row) => (
        <div>
          {row.resellerName ? (
            <div>
              <p className="text-xs font-semibold text-slate-200">{row.resellerName}</p>
              <span className="text-[10px] text-slate-500 font-mono">Reseller Routing</span>
            </div>
          ) : (
            <span className="text-xs text-slate-500 italic">Not Assigned</span>
          )}
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Workflow Stage',
      render: (row) => {
        let variant = 'neutral';
        if (row.status === 'Paid/Settled') variant = 'success';
        if (row.status === 'Approved') variant = 'info';
        if (row.status === 'Holding') variant = 'warning';
        if (row.status === 'Assigned') variant = 'purple';
        if (row.status === 'Payment Submitted') variant = 'warning';
        if (row.status === 'Rejected' || row.status === 'Held') variant = 'danger';
        return <Badge variant={variant}>{row.status.toUpperCase()}</Badge>;
      },
    },
    {
      key: 'actions',
      header: 'Workflow Actions',
      render: (row) => (
        <div className="flex flex-wrap items-center gap-1.5">
          <Button variant="outline" size="xs" onClick={() => setSelectedWithdrawal(row)}>
            Review
          </Button>

          {row.status === 'Pending' && (
            <>
              <Button variant="outline" size="xs" onClick={() => handleSendToHolding(row)} className="text-amber-400">
                Hold Period
              </Button>
              <Button variant="primary" size="xs" onClick={() => handleApproveWithdrawal(row)}>
                Approve
              </Button>
              <Button variant="danger" size="xs" onClick={() => setActionModal({ open: true, withdrawal: row, actionType: 'reject' })}>
                Reject
              </Button>
            </>
          )}

          {row.status === 'Holding' && (
            <Button variant="primary" size="xs" onClick={() => handleApproveWithdrawal(row)}>
              4-Eyes Approve
            </Button>
          )}

          {row.status === 'Approved' && (
            <Button variant="secondary" size="xs" onClick={() => setAssignResellerModal({ open: true, withdrawal: row })}>
              Route Reseller
            </Button>
          )}

          {row.status === 'Assigned' && (
            <Button variant="warning" size="xs" onClick={() => setPaymentProofModal({ open: true, withdrawal: row })}>
              Upload Receipt
            </Button>
          )}

          {row.status === 'Payment Submitted' && (
            <Button variant="success" size="xs" onClick={() => handleVerifyAndSettle(row)} leftIcon={ShieldCheck}>
              Verify & Settle
            </Button>
          )}

          {row.status === 'Paid/Settled' && row.ledgerChainId && (
            <span className="text-[10px] font-mono text-emerald-400 flex items-center gap-0.5">
              <LinkIcon className="h-3 w-3" /> Ledger Link
            </span>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Wallet className="h-7 w-7 text-emerald-400" />
            Settlement & Withdrawal Center
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Process creator payouts via country authorized Coin Sellers, enforce 4-eyes reviews, and publish transaction ledgers.
          </p>
        </div>

        <div className="flex items-center gap-2 bg-slate-900 border border-slate-800 p-2 rounded-xl">
          <span className="text-xs text-slate-400 font-bold whitespace-nowrap">Holding Period:</span>
          <select
            className="bg-slate-800 border border-slate-700 text-xs rounded px-2.5 py-1 text-white focus:outline-none"
            value={holdingPeriodHours}
            onChange={(e) => setHoldingPeriodHours(e.target.value)}
          >
            <option value="12">12 Hours</option>
            <option value="24">24 Hours</option>
            <option value="48">48 Hours</option>
          </select>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2 animate-pulse">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Policy Card */}
      <Card className="p-4 bg-emerald-950/20 border-emerald-500/30">
        <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-2 text-xs text-slate-300">
          <div>
            <span className="font-bold text-white flex items-center gap-1.5">
              <ShieldCheck className="h-4 w-4 text-emerald-400" />
              Ecosystem Payout Settings:
            </span>
            <p className="text-slate-400 mt-0.5 font-mono">
              Rate: 10,000 Diamonds = $1.00 USD • Min Payout limit: ${CURRENT_WITHDRAWAL_POLICY.minWithdrawalUSD} • Max daily cap: ${CURRENT_WITHDRAWAL_POLICY.maxWithdrawalDailyUSD}
            </p>
          </div>
          <Badge variant="success">Country-Authorized Reseller Routing Active</Badge>
        </div>
      </Card>

      {/* Filter Bar */}
      <Card className="p-4 flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
        <Input
          placeholder="Search by Host name, username, or request ID…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md"
        />

        <div className="flex items-center gap-2 overflow-x-auto">
          <CountrySelect value={selectedCountry} onChange={setSelectedCountry} />
          <span className="text-xs text-slate-500 font-bold">Filter:</span>
          {['all', 'pending', 'holding', 'approved', 'assigned', 'paid'].map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-2.5 py-1 rounded text-xs font-semibold uppercase border transition-colors ${
                statusFilter === s
                  ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-400 font-bold'
                  : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </Card>

      {/* Main Table */}
      <DataTable
        columns={columns}
        data={filtered}
        isLoading={isLoading}
        emptyTitle="No payouts found"
        emptyDescription="No withdrawals match the filters."
      />

      {/* Detail Review Modal */}
      {selectedWithdrawal && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedWithdrawal(null)}
          title={`payout Request: ${selectedWithdrawal.id}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 flex justify-between items-center">
              <div>
                <p className="text-base font-bold text-white">{selectedWithdrawal.hostName}</p>
                <p className="text-slate-400 flex items-center gap-1.5 mt-0.5">
                  <span>@{selectedWithdrawal.hostUsername}</span>
                  <span>·</span>
                  <span className="flex items-center gap-1">
                    <CountryFlag code={selectedWithdrawal.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0 inline-block" />
                    <span>{getCountryShortName(selectedWithdrawal.country)}</span>
                  </span>
                </p>
              </div>
              <Badge variant="purple">{selectedWithdrawal.status.toUpperCase()}</Badge>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Settlement Amount</p>
                <p className="text-sm font-bold text-emerald-400 font-mono mt-0.5">{formatCurrency(selectedWithdrawal.amount)}</p>
              </Card>
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Debited diamonds</p>
                <p className="text-sm font-bold text-yellow-400 font-mono mt-0.5">💎 {formatNumber(selectedWithdrawal.diamonds || selectedWithdrawal.amount * 10000)}</p>
              </Card>
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Payment Gateway</p>
                <p className="text-xs font-semibold text-slate-200 mt-1">{selectedWithdrawal.payoutMethod || 'Bank Wire'}</p>
              </Card>
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Beneficiary Details</p>
                <p className="text-xs font-mono text-slate-300 mt-1 truncate">{selectedWithdrawal.accountDetail || '**** 9982'}</p>
              </Card>
            </div>

            {selectedWithdrawal.paymentProof && (
              <div className="p-3 rounded-xl bg-slate-800/30 border border-slate-700/50 space-y-1">
                <p className="font-semibold text-white">Submitted Payment Proof:</p>
                <img
                  src={selectedWithdrawal.paymentProof}
                  alt="Receipt proof"
                  className="h-40 object-cover rounded border border-slate-800 bg-slate-900"
                />
              </div>
            )}

            {selectedWithdrawal.ledgerChainId && (
              <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 text-[11px]">
                <p className="text-slate-400">Immutable Ledger record ID:</p>
                <code className="text-emerald-400 font-bold font-mono">{selectedWithdrawal.ledgerChainId}</code>
              </div>
            )}

            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedWithdrawal(null)}>
                Close Details
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Route Reseller Modal */}
      {assignResellerModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setAssignResellerModal({ open: false, withdrawal: null })}
          title={`Assign Authorized Reseller: ${assignResellerModal.withdrawal?.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Select an authorized Coin Seller to route this withdrawal payment. Only Resellers matching country code <strong className="text-white">({assignResellerModal.withdrawal?.country})</strong> are shown.
            </p>

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">Select Reseller</label>
              <select
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none"
                value={selectedReseller}
                onChange={(e) => setSelectedReseller(e.target.value)}
              >
                <option value="">-- Choose Reseller --</option>
                {assignResellerModal.withdrawal?.country === 'US' ? (
                  <>
                    <option value="Apex Global Reseller (US)">Apex Global Reseller (US)</option>
                    <option value="Vance & Co Distributions (US)">Vance & Co Distributions (US)</option>
                  </>
                ) : (
                  <>
                    <option value="SilkRoad Pay Enterprise (CN)">SilkRoad Pay Enterprise (CN)</option>
                    <option value="Li Wei Sovereign Coins (CN)">Li Wei Sovereign Coins (CN)</option>
                  </>
                )}
              </select>
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setAssignResellerModal({ open: false, withdrawal: null })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleAssignReseller}>
                Assign & Route Settlement
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Upload Payment Proof Modal */}
      {paymentProofModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setPaymentProofModal({ open: false, withdrawal: null })}
          title={`Upload Payment Proof Receipt`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Attach the external payment submit proof (receipt screenshot image URL).
            </p>
            <Input
              label="Payment Proof Receipt URL"
              value={paymentProofUrl}
              onChange={(e) => setPaymentProofUrl(e.target.value)}
            />
            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setPaymentProofModal({ open: false, withdrawal: null })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSubmitPaymentProof}>
                Submit Receipt Proof
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Action Execution Modal (Terminal: Reject / Hold) */}
      {actionModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setActionModal({ open: false, withdrawal: null, actionType: null })}
          title={`Execute Payout Action: ${actionModal.actionType?.toUpperCase()}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Are you sure you want to perform <strong>{actionModal.actionType?.toUpperCase()}</strong> on payout request{' '}
              <strong className="text-white">{actionModal.withdrawal?.id}</strong>?
            </p>

            <Input
              label="Compliance Justification / Note"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              placeholder="Provide reason for audit trails…"
              required
            />

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setActionModal({ open: false, withdrawal: null, actionType: null })}>
                Cancel
              </Button>
              <Button
                variant={actionModal.actionType === 'reject' ? 'danger' : 'primary'}
                size="sm"
                onClick={handleExecuteTerminalAction}
              >
                Confirm {actionModal.actionType?.toUpperCase()}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
