// ============================================================
// ZeParty Admin Portal — Transaction Ledger & Chain Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo } from 'react';
import { Layers, Search, ArrowRightLeft, ShieldCheck, FileText, Eye, Filter, RefreshCw, AlertTriangle, ArrowRight, Link } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { MOCK_LEDGER_CHAIN } from '../../mocks/transactionLedger.mock';
import { formatNumber, formatDate } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

export function TransactionLedgerPage() {
  const { logAdminAction } = useAuditLog();
  const [ledger, setLedger] = useState(
    MOCK_LEDGER_CHAIN.map((tx) => ({
      ...tx,
      sellerId: tx.sellerId || null,
      merchantId: tx.merchantId || null,
      withdrawalId: tx.withdrawalId || null,
      rate: tx.rate || '10,000/$1',
      operator: tx.operator || 'System Automated',
      linkedRecords: tx.relatedTxnIds || []
    }))
  );
  
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [inspectTx, setInspectTx] = useState(null);
  const [reversalModal, setReversalModal] = useState({ open: false, txn: null, reason: '', reversalAmountUSD: '' });
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return ledger.filter((tx) => {
      const matchType = typeFilter === 'ALL' || tx.type === typeFilter;
      const matchSearch =
        !q ||
        tx.txnId.toLowerCase().includes(q) ||
        tx.chainId.toLowerCase().includes(q) ||
        (tx.user && tx.user.toLowerCase().includes(q)) ||
        (tx.hostId && tx.hostId.toLowerCase().includes(q));
      return matchType && matchSearch;
    });
  }, [search, typeFilter, ledger]);

  const handleCreateReversal = async () => {
    const { txn, reason, reversalAmountUSD } = reversalModal;
    if (!txn || !reason || !reversalAmountUSD) return;

    const amt = Number(reversalAmountUSD);
    const reversalTxId = `TXN-REV-${Math.floor(Math.random() * 100000)}`;

    const adjustmentRecord = {
      txnId: reversalTxId,
      timestamp: new Date().toISOString(),
      type: 'REVERSAL_ADJUSTMENT',
      user: txn.user || 'System',
      userId: txn.userId || null,
      source: txn.destination,
      destination: txn.source,
      amountUSD: -amt,
      coinsAdded: txn.coinsSpent ? txn.coinsSpent : 0,
      coinsSpent: txn.coinsAdded ? txn.coinsAdded : 0,
      status: 'SUCCESS',
      chainId: txn.chainId,
      relatedTxnIds: [txn.txnId],
      linkedRecords: [txn.txnId],
      rate: txn.rate,
      operator: 'Finance Admin',
      note: `Reversal Correction: ${reason}`
    };

    setLedger((prev) => [adjustmentRecord, ...prev]);

    await logAdminAction({
      action: 'LEDGER_TXN_REVERSED',
      module: 'Ledger',
      targetType: 'transaction',
      targetId: txn.txnId,
      targetName: txn.txnId,
      reason: `Reversal adjust: ${reason} (Amount: -$${amt})`,
      riskLevel: 'HIGH',
      afterValue: { reversalTxId }
    });

    showFeedback(`Reversal transaction ${reversalTxId} successfully appended to ledger.`);
    setReversalModal({ open: false, txn: null, reason: '', reversalAmountUSD: '' });
  };

  const columns = [
    {
      key: 'txnId',
      header: 'Transaction ID',
      render: (row) => (
        <div>
          <p className="text-xs font-mono font-bold text-white">{row.txnId}</p>
          <p className="text-[10px] text-slate-500 font-mono">Chain: {row.chainId}</p>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      render: (row) => {
        let variant = 'purple';
        if (row.type === 'REVERSAL_ADJUSTMENT') variant = 'danger';
        if (row.type === 'RECHARGE') variant = 'success';
        if (row.type === 'HOST_EARNING') variant = 'info';
        return <Badge variant={variant}>{row.type}</Badge>;
      },
    },
    {
      key: 'flow',
      header: 'Source → Destination',
      render: (row) => (
        <div className="flex items-center gap-1 text-[11px] text-slate-300">
          <span className="truncate max-w-[100px]">{row.source}</span>
          <ArrowRight className="h-3 w-3 text-gold-400 shrink-0" />
          <span className="truncate max-w-[100px]">{row.destination}</span>
        </div>
      ),
    },
    {
      key: 'value',
      header: 'Ledger Balances',
      render: (row) => (
        <div className="font-mono text-xs">
          {row.amountUSD && <p className={`font-bold ${row.amountUSD > 0 ? 'text-emerald-400' : 'text-rose-400'}`}>{row.amountUSD > 0 ? '+' : ''}${row.amountUSD.toFixed(2)} USD</p>}
          {row.coinsAdded > 0 && <p className="text-yellow-400 font-bold">🪙 +{formatNumber(row.coinsAdded)}</p>}
          {row.coinsSpent > 0 && <p className="text-red-400 font-bold">🪙 -{formatNumber(row.coinsSpent)}</p>}
          {row.diamondsAdded > 0 && <p className="text-purple-400 font-bold">💎 +{formatNumber(row.diamondsAdded)}</p>}
        </div>
      ),
    },
    {
      key: 'timestamp',
      header: 'Timestamp',
      render: (row) => <span className="text-xs text-slate-400">{formatDate(row.timestamp)}</span>,
    },
    {
      key: 'operator',
      header: 'Operator',
      render: (row) => <span className="text-xs text-slate-300">{row.operator}</span>,
    },
    {
      key: 'actions',
      header: 'Audits',
      render: (row) => (
        <div className="flex gap-1">
          <Button variant="outline" size="xs" onClick={() => setInspectTx(row)}>
            Trace
          </Button>
          {row.type !== 'REVERSAL_ADJUSTMENT' && row.status === 'SUCCESS' && (
            <Button
              variant="danger"
              size="xs"
              onClick={() => setReversalModal({ open: true, txn: row, reason: '', reversalAmountUSD: Math.abs(row.amountUSD || 0) })}
            >
              Reversal
            </Button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      {/* Visual Flow Indicator */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Layers className="h-6 w-6 text-gold-400" />
            Immutable Transaction Ledger
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">End-to-end transaction chain auditing with strict reversal correction records.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Visual Chain map */}
      <Card className="p-4 bg-slate-900 border border-slate-800">
        <p className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">Ecosystem Transaction Flow Chain Map</p>
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-slate-300 bg-slate-950 p-3 rounded-lg border border-slate-900">
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="success">1</Badge> Recharge
          </div>
          <ArrowRight className="h-3 w-3 text-slate-600" />
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="purple">2</Badge> Coins Purchase
          </div>
          <ArrowRight className="h-3 w-3 text-slate-600" />
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="purple">3</Badge> Gifts/Games/PK
          </div>
          <ArrowRight className="h-3 w-3 text-slate-600" />
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="info">4</Badge> Host Earnings
          </div>
          <ArrowRight className="h-3 w-3 text-slate-600" />
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="purple">5</Badge> Diamonds Wallet
          </div>
          <ArrowRight className="h-3 w-3 text-slate-600" />
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="warning">6</Badge> Withdrawal
          </div>
          <ArrowRight className="h-3 w-3 text-slate-600" />
          <div className="flex items-center gap-1.5 p-1 rounded hover:bg-slate-900">
            <Badge variant="success">7</Badge> External Settlement
          </div>
        </div>
      </Card>

      <Card className="p-4 flex flex-col sm:flex-row gap-3">
        <Input
          placeholder="Search by Txn ID, Chain ID, User ID, Host ID..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1"
        />
        <div className="flex items-center gap-2 border border-slate-700 bg-slate-900 rounded-lg px-2">
          <Filter className="h-4 w-4 text-slate-500" />
          <select
            className="bg-transparent text-sm text-white py-2 outline-none"
            value={typeFilter}
            onChange={(e) => setTypeFilter(e.target.value)}
          >
            <option value="ALL">All Types</option>
            <option value="RECHARGE">Recharge</option>
            <option value="GIFT_SEND">Gift Send</option>
            <option value="AGENCY_COMMISSION">Agency Commission</option>
            <option value="HOST_EARNING">Host Earning</option>
            <option value="WITHDRAWAL_REQUEST">Withdrawal Request</option>
            <option value="REVERSAL_ADJUSTMENT">Reversal Adjustment</option>
          </select>
        </div>
      </Card>

      <DataTable columns={columns} data={filtered} isLoading={false} />

      {/* Trace Details Modal */}
      {inspectTx && (
        <Modal
          isOpen={true}
          onClose={() => setInspectTx(null)}
          title={`Ledger Chain Trace: ${inspectTx.txnId}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 rounded bg-slate-900 border border-slate-800 space-y-1.5">
              <p><strong>Chain ID:</strong> <code className="font-mono text-gold-400 font-bold">{inspectTx.chainId}</code></p>
              <p><strong>Transaction ID:</strong> <code className="font-mono text-slate-200">{inspectTx.txnId}</code></p>
              <p><strong>Conversion Rate:</strong> {inspectTx.rate}</p>
              <p><strong>Executing Operator:</strong> {inspectTx.operator}</p>
              {inspectTx.note && <p className="text-amber-400"><strong>Note:</strong> {inspectTx.note}</p>}
            </div>

            <div className="p-3 bg-slate-800/40 border border-slate-700/50 rounded-xl space-y-2">
              <p className="font-bold text-white flex items-center gap-1.5">
                <Link className="h-3.5 w-3.5 text-gold-400" /> Linked Related Txn IDs
              </p>
              <div className="flex flex-wrap gap-2">
                {inspectTx.linkedRecords?.map((linkId) => (
                  <Badge key={linkId} variant="purple" className="font-mono">{linkId}</Badge>
                ))}
              </div>
            </div>

            {inspectTx.splitDetails && (
              <div className="p-4 rounded-xl bg-purple-950/20 border border-purple-500/30">
                <p className="text-xs font-bold text-white mb-2">Automated Revenue Split Verification</p>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
                  <div className="p-2 rounded bg-slate-900 border border-slate-800">
                    <p className="text-[10px] text-slate-400">Platform ({inspectTx.splitDetails.platformSharePercent}%)</p>
                    <p className="text-xs font-bold text-white">${inspectTx.splitDetails.platformShareUSD}</p>
                  </div>
                  <div className="p-2 rounded bg-slate-900 border border-slate-800">
                    <p className="text-[10px] text-slate-400">Agency ({inspectTx.splitDetails.agencySharePercent}%)</p>
                    <p className="text-xs font-bold text-gold-400">${inspectTx.splitDetails.agencyShareUSD}</p>
                  </div>
                  <div className="p-2 rounded bg-slate-900 border border-slate-800">
                    <p className="text-[10px] text-slate-400">Room ({inspectTx.splitDetails.roomRewardPercent}%)</p>
                    <p className="text-xs font-bold text-emerald-400">${inspectTx.splitDetails.roomRewardUSD}</p>
                  </div>
                  <div className="p-2 rounded bg-slate-900 border border-slate-800">
                    <p className="text-[10px] text-slate-400">Host Backup ({inspectTx.splitDetails.hostBackupPercent}%)</p>
                    <p className="text-xs font-bold text-purple-400">${inspectTx.splitDetails.hostBackupUSD}</p>
                  </div>
                </div>
              </div>
            )}

            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => setInspectTx(null)}>
                Close Trace
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Reversal Modal */}
      {reversalModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setReversalModal({ open: false, txn: null, reason: '', reversalAmountUSD: '' })}
          title={`Generate Correction Reversal`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 bg-rose-500/10 border border-rose-500/30 rounded-xl flex items-start gap-2.5">
              <AlertTriangle className="h-5 w-5 text-rose-400 shrink-0" />
              <p className="text-[11px] text-rose-300">
                <strong>Attention:</strong> You are creating an adjusting reversal entry for transaction <code className="font-mono text-white font-bold">{reversalModal.txn?.txnId}</code>. This action creates a new compensating ledger entry and does not overwrite history.
              </p>
            </div>

            <Input
              label="Reversal Adjust Amount (USD)"
              type="number"
              value={reversalModal.reversalAmountUSD}
              onChange={(e) => setReversalModal({ ...reversalModal, reversalAmountUSD: e.target.value })}
            />

            <Input
              label="Correction Justification Reason"
              value={reversalModal.reason}
              onChange={(e) => setReversalModal({ ...reversalModal, reason: e.target.value })}
              placeholder="e.g. Chargeback compensation adjustment"
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setReversalModal({ open: false, txn: null, reason: '', reversalAmountUSD: '' })}>
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={handleCreateReversal}>
                Post Reversal Entry
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
