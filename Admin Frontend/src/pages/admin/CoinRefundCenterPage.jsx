// ============================================================
// ZeParty Admin Portal — Coin Refund & Correction Center (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState } from 'react';
import { RotateCcw, Search, AlertTriangle, CheckCircle, ShieldAlert, ArrowRight, Link, FileText, Check, X } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { MOCK_COIN_REFUNDS } from '../../mocks/coinRefunds.mock';
import { formatNumber, formatDate } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';

export function CoinRefundCenterPage() {
  const { logAdminAction } = useAuditLog();
  const [cases, setCases] = useState(
    MOCK_COIN_REFUNDS.map((c, i) => ({
      ...c,
      accountType: i % 3 === 0 ? 'User' : i % 3 === 1 ? 'Coin Seller' : 'Merchant',
      country: c.country || (i % 3 === 0 ? 'US' : i % 3 === 1 ? 'AE' : 'CA'),
      originalBalance: c.coins * 3,
      correctionAmount: c.coins,
      newBalance: c.coins * 2,
      evidenceUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?q=80&w=300&auto=format&fit=crop',
      approvalRequired: c.coins > 1000000, // High-value threshold: 1M coins
      approvedBy: null,
      ledgerTxId: null
    }))
  );
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [reviewCase, setReviewCase] = useState(null);
  const [actionFeedback, setActionFeedback] = useState(null);

  const showFeedback = (msg) => {
    setActionFeedback(msg);
    setTimeout(() => setActionFeedback(null), 3500);
  };

  const handleProcessCase = async (status) => {
    if (!reviewCase) return;

    const ledgerTxId = `TXN-CORR-${Math.floor(Math.random() * 100000)}`;
    setCases(cases.map(c => c.id === reviewCase.id ? {
      ...c,
      status,
      approvedBy: c.approvalRequired ? 'Super Admin' : 'Finance Admin',
      ledgerTxId: status === 'SUCCESS' ? ledgerTxId : null
    } : c));
    
    await logAdminAction({
      action: `COIN_CORRECTION_${status}`,
      module: 'Refunds',
      targetType: 'coin_refund',
      targetId: reviewCase.id,
      targetName: reviewCase.sourceUser,
      reason: `Downstream impact case resolved as ${status}. Ledger ID: ${ledgerTxId}`,
      riskLevel: reviewCase.approvalRequired ? 'CRITICAL' : 'HIGH',
      afterValue: { status }
    });

    showFeedback(`Case ${reviewCase.id} resolved as ${status}. Ledger transaction recorded.`);
    setReviewCase(null);
  };

  const filtered = cases.filter(c => {
    const q = search.toLowerCase();
    const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || c.country?.toLowerCase() === selectedCountry.toLowerCase();
    const matchQuery = !q || c.id.toLowerCase().includes(q) || c.sourceUser.toLowerCase().includes(q) || c.reason.toLowerCase().includes(q);
    return matchCountry && matchQuery;
  });

  const columns = [
    {
      key: 'id',
      header: 'Request ID',
      render: (r) => (
        <div>
          <p className="text-xs font-mono font-bold text-white">{r.id}</p>
          <p className="text-[10px] text-slate-500 font-mono">Txn: {r.originalTxnId}</p>
        </div>
      ),
    },
    {
      key: 'country',
      header: 'Country',
      render: (r) => (
        <div className="flex items-center gap-1.5 text-xs font-semibold text-white">
          <CountryFlag code={r.country || 'US'} className="w-4 h-3 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(r.country || 'US')}</span>
        </div>
      ),
    },
    {
      key: 'user',
      header: 'Account Owner',
      render: (r) => (
        <div>
          <span className="text-xs font-semibold text-white">{r.sourceUser}</span>
          <Badge variant="purple" className="block w-max mt-0.5 text-[9px]">{r.accountType}</Badge>
        </div>
      ),
    },
    {
      key: 'balances',
      header: 'Balances Adjust',
      render: (r) => (
        <div className="font-mono text-xs text-slate-300">
          <p>Original: 🪙 {formatNumber(r.originalBalance)}</p>
          <p className="text-rose-400 font-bold">Correction: -🪙 {formatNumber(r.correctionAmount)}</p>
          <p className="text-emerald-400 font-bold">New: 🪙 {formatNumber(r.newBalance)}</p>
        </div>
      ),
    },
    {
      key: 'reason',
      header: 'Justification Reason',
      render: (r) => (
        <div>
          <span className="text-xs text-slate-300 italic">{r.reason}</span>
          {r.approvalRequired && <Badge variant="danger" className="block w-max mt-1 text-[9px]">Super Admin Auth Req</Badge>}
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Resolution Status',
      render: (r) => {
        let variant = 'neutral';
        if (r.status === 'SUCCESS' || r.status === 'approved') variant = 'success';
        if (r.status === 'pending') variant = 'warning';
        if (r.status === 'rejected') variant = 'danger';
        return <Badge variant={variant}>{r.status.toUpperCase()}</Badge>;
      },
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <div className="flex items-center gap-1.5">
          <Button variant="primary" size="xs" onClick={() => setReviewCase(r)}>
            Downstream Review
          </Button>
          {r.ledgerTxId && (
            <span className="text-[10px] font-mono text-emerald-400 flex items-center gap-0.5">
              <Link className="h-3 w-3" /> Ledger Linked
            </span>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <RotateCcw className="h-6 w-6 text-gold-400" />
            Coin Refund & Correction Center
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Process coin credit corrections, reseller chargebacks, and downstream balance ledger adjustments.</p>
        </div>
      </div>

      {actionFeedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{actionFeedback}</span>
        </div>
      )}

      <Card className="p-4 flex flex-col sm:flex-row items-center gap-3">
        <Input
          placeholder="Search by correction ID, account name, or reason..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 w-full"
        />
        <div className="flex items-center gap-2 shrink-0">
          <span className="text-xs text-slate-400 font-semibold">Filter Country:</span>
          <CountrySelect value={selectedCountry} onChange={setSelectedCountry} />
        </div>
      </Card>

      <DataTable columns={columns} data={filtered} isLoading={false} />

      {/* Downstream Review & Approval Modal */}
      {reviewCase && (
        <Modal
          isOpen={true}
          onClose={() => setReviewCase(null)}
          title={`Correction Audit Review: ${reviewCase.id}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            {reviewCase.approvalRequired && (
              <Card className="p-3.5 bg-rose-500/10 border border-rose-500/30 text-rose-300 rounded-xl flex items-center gap-2">
                <ShieldAlert className="h-5 w-5 text-rose-400" />
                <div>
                  <strong className="text-white">Super Admin / Finance Admin Signature Required</strong>
                  <p className="text-[10px] text-slate-400">High-value correction of {formatNumber(reviewCase.correctionAmount)} coins exceeds default authorization limits.</p>
                </div>
              </Card>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div className="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-1.5">
                <p><strong>Account Type:</strong> {reviewCase.accountType}</p>
                <p><strong>Source Name:</strong> {reviewCase.sourceUser}</p>
                <p><strong>Original Transaction ID:</strong> {reviewCase.originalTxnId}</p>
                <p><strong>Correction Justification:</strong> {reviewCase.reason}</p>
              </div>

              <div className="p-3 bg-slate-900 border border-slate-800 rounded-xl space-y-1.5 font-mono text-[11px]">
                <p className="text-slate-400">Original Balance: 🪙 {formatNumber(reviewCase.originalBalance)}</p>
                <p className="text-rose-400 font-bold">Adjustment Reclaimed: -🪙 {formatNumber(reviewCase.correctionAmount)}</p>
                <p className="text-emerald-400 font-bold">Post-Adjustment Balance: 🪙 {formatNumber(reviewCase.newBalance)}</p>
              </div>
            </div>

            {/* Evidence attachment */}
            <div className="space-y-1">
              <p className="font-semibold text-white">Auditable Dispute Evidence:</p>
              <img
                src={reviewCase.evidenceUrl}
                alt="Refund dispute evidence document"
                className="h-32 object-cover rounded border border-slate-800 bg-slate-950"
              />
            </div>

            <div className="flex justify-between items-center pt-3 border-t border-slate-700">
              {reviewCase.status === 'pending' ? (
                <div className="flex gap-2">
                  <Button variant="danger" size="sm" onClick={() => handleProcessCase('rejected')} leftIcon={X}>
                    Reject Correction
                  </Button>
                  <Button variant="primary" size="sm" onClick={() => handleProcessCase('SUCCESS')} leftIcon={Check}>
                    {reviewCase.approvalRequired ? 'Super Admin Approve & Reconcile' : 'Approve Correction'}
                  </Button>
                </div>
              ) : (
                <span className="text-slate-400 uppercase font-bold">Resolved Status: {reviewCase.status}</span>
              )}
              
              <Button variant="ghost" size="sm" onClick={() => setReviewCase(null)}>
                Close Audit
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
