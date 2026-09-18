// ============================================================
// ZeParty Admin Portal — Wallet Page (JSX)
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { Wallet, Coins, Gem, ArrowRightLeft, Search, Plus, Filter, RotateCcw, ShieldCheck } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal, ConfirmDialog } from '../../components/ui/Modal';
import { formatNumber, formatCurrency } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getWalletStats,
  getWalletTransactions,
  adjustBalance,
  refundTransaction
} from '../../services/modules/wallet.service';

function AdjustBalanceModal({ isOpen, onClose, onAdjust }) {
  const [formData, setFormData] = useState({ user: '', currency: 'Coins', type: 'ADJUSTMENT', amount: 0, reason: '' });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const tx = await adjustBalance(formData);
      onAdjust(tx);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Manual Balance Adjustment" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Target User ID or Username</label>
          <Input required placeholder="E.g., User_123" value={formData.user} onChange={(e) => setFormData({...formData, user: e.target.value})} />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Currency</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.currency}
              onChange={(e) => setFormData({...formData, currency: e.target.value})}
            >
              <option value="Coins">Coins</option>
              <option value="Diamonds">Diamonds</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Amount (Use - for deduct)</label>
            <Input required type="number" value={formData.amount} onChange={(e) => setFormData({...formData, amount: parseInt(e.target.value) || 0})} />
          </div>
        </div>
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Reason (Required for Audit)</label>
          <textarea 
            required 
            rows={3}
            className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all resize-none"
            placeholder="Please provide a valid reason for this manual adjustment..."
            value={formData.reason}
            onChange={(e) => setFormData({...formData, reason: e.target.value})}
          />
        </div>
        <div className="flex justify-end gap-3 mt-6">
          <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="flex items-center gap-2 bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50">
            <ShieldCheck className="h-4 w-4" /> Confirm Adjustment
          </button>
        </div>
      </form>
    </Modal>
  );
}

export function WalletPage() {
  const { logAdminAction } = useAuditLog();
  const [stats, setStats] = useState(null);
  const [transactions, setTransactions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('ALL');
  
  const [isAdjustModalOpen, setIsAdjustModalOpen] = useState(false);
  const [refundTarget, setRefundTarget] = useState(null);
  const [refundReason, setRefundReason] = useState('');

  useEffect(() => {
    Promise.allSettled([getWalletStats(), getWalletTransactions()])
      .then(([statsRes, txRes]) => {
        if (statsRes.status === 'fulfilled') {
          setStats(statsRes.value);
        } else {
          console.error('Failed to load wallet stats:', statsRes.reason);
        }
        if (txRes.status === 'fulfilled') {
          setTransactions(txRes.value || []);
        } else {
          console.error('Failed to load wallet transactions:', txRes.reason);
        }
      })
      .finally(() => setIsLoading(false));
  }, []);

  const filtered = useMemo(() => {
    return transactions.filter(t => {
      const matchType = typeFilter === 'ALL' || t.type === typeFilter;
      const matchSearch = search === '' || 
        t.user.toLowerCase().includes(search.toLowerCase()) || 
        t.id.toLowerCase().includes(search.toLowerCase());
      return matchType && matchSearch;
    });
  }, [transactions, search, typeFilter]);

  const handleRefund = async () => {
    if (!refundTarget || !refundReason) return;
    await refundTransaction(refundTarget.id, refundReason);
    await logAdminAction({
      action: 'TRANSACTION_REFUNDED',
      module: 'Wallet',
      targetType: 'transaction',
      targetId: refundTarget.id,
      targetName: `Transaction ${refundTarget.id}`,
      reason: refundReason,
      riskLevel: 'HIGH',
      metadata: { user: refundTarget.user }
    });
    const freshTx = await getWalletTransactions();
    setTransactions(freshTx);
    setRefundTarget(null);
    setRefundReason('');
  };

  const columns = [
    { key: 'txId', header: 'Transaction', render: (row) => (
      <div>
        <p className="font-medium text-white text-sm">{row.id}</p>
        <p className="text-xs text-slate-500">{new Date(row.date).toLocaleString()}</p>
      </div>
    )},
    { key: 'type', header: 'Type', render: (row) => <Badge variant="default">{row.type}</Badge> },
    { key: 'user', header: 'User', render: (row) => <span className="font-medium text-white">{row.user}</span> },
    { key: 'flow', header: 'Flow', render: (row) => (
      <div className="flex items-center gap-1.5 text-xs text-slate-400">
        <span>{row.source}</span>
        <ArrowRightLeft className="h-3 w-3 text-slate-600" />
        <span>{row.destination}</span>
      </div>
    )},
    { key: 'amount', header: 'Changes', render: (row) => (
      <div className="flex flex-col gap-0.5">
        {row.coins !== 0 && <span className={row.coins > 0 ? "text-gold-400 text-xs font-medium" : "text-red-400 text-xs font-medium"}>{row.coins > 0 ? '+' : ''}{formatNumber(row.coins)} Coins</span>}
        {row.diamonds !== 0 && <span className={row.diamonds > 0 ? "text-purple-400 text-xs font-medium" : "text-red-400 text-xs font-medium"}>{row.diamonds > 0 ? '+' : ''}{formatNumber(row.diamonds)} Diamonds</span>}
        {row.amount !== '-' && <span className="text-slate-400 text-xs">{row.amount}</span>}
      </div>
    )},
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'operator', header: 'Operator', render: (row) => <span className="text-xs text-slate-500">{row.operator}</span> },
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-2">
        {row.type === 'RECHARGE' && row.status === 'SUCCESS' && (
          <button onClick={() => setRefundTarget(row)} className="text-xs text-amber-400 hover:underline flex items-center gap-1">
            <RotateCcw className="h-3 w-3" /> Refund
          </button>
        )}
      </div>
    )}
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading Wallet...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Wallet & Economy">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Wallet className="h-6 w-6 text-gold-400" aria-hidden="true" />
            Wallet & Economy
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage currency, view ledgers, and adjust balances.</p>
        </div>
        <button
          onClick={() => setIsAdjustModalOpen(true)}
          className="flex items-center gap-2 bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors"
        >
          <Plus className="h-4 w-4" /> Manual Adjustment
        </button>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Total Coins" value={formatNumber(stats.totalCoinsInCirculation)} icon={Coins} iconColor="text-gold-400" iconBg="bg-gold-500/10" />
        <StatCard title="Total Diamonds" value={formatNumber(stats.totalDiamonds)} icon={Gem} iconColor="text-purple-400" iconBg="bg-purple-500/10" />
        <StatCard title="Coins Purchased" value={formatNumber(stats.coinsPurchased)} icon={Wallet} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Coins Gifted" value={formatNumber(stats.coinsGifted)} icon={ArrowRightLeft} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
      </div>

      <Card>
        <CardHeader title="Transaction Ledger" description="Immutable record of all economy events">
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-2 border border-slate-700 bg-slate-900 rounded-lg px-2">
              <Filter className="h-4 w-4 text-slate-500" />
              <select
                className="bg-transparent text-sm text-white py-2 outline-none"
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
              >
                <option value="ALL">All Types</option>
                <option value="RECHARGE">Recharge</option>
                <option value="GIFT">Gift</option>
                <option value="ADJUSTMENT">Adjustment</option>
                <option value="WITHDRAWAL">Withdrawal</option>
                <option value="REFUND">Refund</option>
              </select>
            </div>
            <Input
              placeholder="Search User or TX ID..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              leftIcon={Search}
              containerClassName="w-64"
            />
          </div>
        </CardHeader>
        <DataTable columns={columns} data={filtered} isLoading={false} />
      </Card>

      <AdjustBalanceModal
        isOpen={isAdjustModalOpen}
        onClose={() => setIsAdjustModalOpen(false)}
        onAdjust={(tx) => {
          setTransactions([tx, ...transactions]);
          logAdminAction({
            action: 'MANUAL_ADJUSTMENT',
            module: 'Wallet',
            targetType: 'user',
            targetId: tx.user,
            targetName: tx.user,
            reason: tx.reason,
            riskLevel: 'HIGH',
            afterValue: { change: tx.coins || tx.diamonds, currency: tx.coins ? 'Coins' : 'Diamonds' }
          });
        }}
      />

      <Modal isOpen={!!refundTarget} onClose={() => setRefundTarget(null)} title="Refund Transaction" size="sm">
        <div className="space-y-4">
          <p className="text-sm text-slate-300">Are you sure you want to refund transaction <span className="font-mono text-white">{refundTarget?.id}</span> for <span className="font-medium text-white">{refundTarget?.user}</span>?</p>
          <div className="bg-amber-500/10 border border-amber-500/20 p-3 rounded-lg text-amber-400 text-xs">
            This action will reverse the coins and record an audit entry. Please enter a reason.
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Refund Reason</label>
            <textarea 
              rows={3}
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-amber-500 focus:ring-1 focus:ring-amber-500 outline-none transition-all resize-none"
              placeholder="e.g. Duplicate charge"
              value={refundReason}
              onChange={(e) => setRefundReason(e.target.value)}
            />
          </div>
          <div className="flex justify-end gap-3 mt-4">
            <button onClick={() => setRefundTarget(null)} className="px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Cancel</button>
            <button 
              onClick={handleRefund}
              disabled={!refundReason} 
              className="bg-amber-500 hover:bg-amber-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50"
            >
              Confirm Refund
            </button>
          </div>
        </div>
      </Modal>

    </div>
  );
}
