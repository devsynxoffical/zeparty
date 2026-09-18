// ============================================================
// ZeParty Admin Portal — Online Recharge Page (JSX)
// Client Excel Phase B Requirements
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { CreditCard, Search, RefreshCcw, CheckCircle, AlertTriangle, ArrowUpRight } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { formatNumber, formatDate } from '../../utils/format';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';
import apiClient from '../../services/api';

export function OnlineRechargePage() {
  const [recharges, setRecharges] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [investigateTx, setInvestigateTx] = useState(null);
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    apiClient
      .get('/v1/finance/transactions', { params: { transactionType: 'COIN_PURCHASE' } })
      .then((res) => {
        if (!isMounted) return;
        const items = res.data?.data || [];
        const formatted = items.map((t) => ({
          id: t.id,
          provider: t.paymentProvider || t.metadata?.provider || 'Online Gateway',
          txId: t.gatewayTxId || t.referenceId || t.id,
          user: t.user?.username || t.user?.profile?.displayName || t.userId || 'Customer',
          userId: t.userId,
          country: t.user?.country || 'US',
          amountUSD: Number(t.amountUSD || t.amount || 0),
          coins: Number(t.coins || t.coinAmount || 0),
          status: t.status || 'SUCCESS',
          reconciled: t.status === 'COMPLETED' || t.status === 'SUCCESS',
          failureReason: t.failureReason || null,
          timestamp: t.createdAt,
        }));
        setRecharges(formatted);
      })
      .catch(() => {
        if (isMounted) setRecharges([]);
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return recharges.filter((r) => {
      const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || r.country?.toLowerCase() === selectedCountry.toLowerCase();
      const matchQuery = !q || r.user.toLowerCase().includes(q) || r.txId.toLowerCase().includes(q) || r.id.toLowerCase().includes(q);
      return matchCountry && matchQuery;
    });
  }, [search, selectedCountry, recharges]);

  const handleForceReconcile = () => {
    if (!investigateTx) return;
    setRecharges(recharges.map(r =>
      r.id === investigateTx.id ? { ...r, reconciled: true, status: 'SUCCESS' } : r
    ));
    setFeedback(`Transaction ${investigateTx.id} force-reconciled and marked as SUCCESS.`);
    setInvestigateTx(null);
    setTimeout(() => setFeedback(null), 3000);
  };

  const columns = [
    {
      key: 'txId',
      header: 'Transaction Reference',
      render: (row) => (
        <div>
          <p className="text-xs font-mono font-bold text-white">{row.id}</p>
          <p className="text-[11px] font-mono text-slate-400">{row.txId}</p>
        </div>
      ),
    },
    {
      key: 'country',
      header: 'Country',
      render: (row) => (
        <div className="flex items-center gap-1.5 text-xs font-semibold text-white">
          <CountryFlag code={row.country || 'US'} className="w-4 h-3 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(row.country || 'US')}</span>
        </div>
      ),
    },
    {
      key: 'provider',
      header: 'Payment Gateway',
      render: (row) => <Badge variant="purple">{row.provider}</Badge>,
    },
    {
      key: 'user',
      header: 'Customer',
      render: (row) => <span className="text-xs font-semibold text-white">{row.user}</span>,
    },
    {
      key: 'amount',
      header: 'USD & Coins',
      render: (row) => (
        <div>
          <p className="text-xs font-bold text-emerald-400">${row.amountUSD.toFixed(2)} USD</p>
          <p className="text-[11px] text-yellow-400 font-bold">🪙 +{formatNumber(row.coins)} Coins</p>
        </div>
      ),
    },
    {
      key: 'reconciliation',
      header: 'Reconciliation',
      render: (row) => (
        <Badge variant={row.reconciled ? 'success' : 'warning'}>
          {row.reconciled ? 'Reconciled' : 'Unmatched'}
        </Badge>
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
        <Button variant="outline" size="xs" onClick={() => setInvestigateTx(row)}>
          Inspect
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-emerald-400" />
            Online Recharge Center
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Automated online payment gateway transactions, country filtering, reconciliation, and failure audit.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{feedback}</span>
          <span className="font-mono">RECONCILED</span>
        </div>
      )}

      <Card className="p-4 flex flex-col sm:flex-row items-center gap-3">
        <Input
          placeholder="Search by User or Gateway TX ID..."
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

      <DataTable columns={columns} data={filtered} isLoading={isLoading} emptyTitle="No online recharges found" emptyDescription="No transactions match your search criteria." />

      {investigateTx && (
        <Modal
          isOpen={true}
          onClose={() => setInvestigateTx(null)}
          title={`Gateway Investigation: ${investigateTx.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/50 space-y-2">
              <p><strong>Provider:</strong> {investigateTx.provider}</p>
              <p><strong>Gateway Reference:</strong> <code className="text-gold-400">{investigateTx.txId}</code></p>
              <p><strong>Customer:</strong> {investigateTx.user} ({investigateTx.userId})</p>
              <p><strong>Amount Credited:</strong> ${investigateTx.amountUSD} USD → {formatNumber(investigateTx.coins)} Coins</p>
              <p><strong>Timestamp:</strong> {formatDate(investigateTx.timestamp)}</p>
              {investigateTx.failureReason && (
                <p className="text-red-400"><strong>Failure Diagnostic:</strong> {investigateTx.failureReason}</p>
              )}
              <p><strong>Reconciled:</strong> <span className={investigateTx.reconciled ? 'text-emerald-400' : 'text-amber-400'}>{investigateTx.reconciled ? 'YES' : 'PENDING'}</span></p>
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setInvestigateTx(null)}>
                Close
              </Button>
              {!investigateTx.reconciled && (
                <Button variant="primary" size="sm" onClick={handleForceReconcile}>
                  Force Reconcile
                </Button>
              )}
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
