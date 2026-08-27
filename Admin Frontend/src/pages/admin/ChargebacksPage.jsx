// ============================================================
// ZeParty Admin Portal — Chargebacks & Dispute Center (JSX)
// Client Excel Phase C Requirements
// ============================================================

import React, { useState } from 'react';
import { AlertCircle, Search, ShieldAlert, Lock, CheckCircle } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { MOCK_CHARGEBACKS } from '../../mocks/coinRefunds.mock';
import { formatCurrency, formatDate } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';

export function ChargebacksPage() {
  const { logAdminAction } = useAuditLog();
  const [disputes, setDisputes] = useState(
    (MOCK_CHARGEBACKS || []).map((d, i) => ({
      ...d,
      country: d.country || (i % 2 === 0 ? 'US' : 'GB')
    }))
  );
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [selectedDispute, setSelectedDispute] = useState(null);
  const [feedback, setFeedback] = useState(null);

  const handleResolveDispute = async (resolution) => {
    if (!selectedDispute) return;
    setDisputes(disputes.map(d => d.id === selectedDispute.id ? { ...d, status: resolution } : d));
    
    await logAdminAction({
      action: 'CHARGEBACK_DISPUTE_RESOLVED',
      module: 'Finance',
      targetType: 'chargeback',
      targetId: selectedDispute.id,
      targetName: selectedDispute.user,
      reason: `Dispute resolved with action: ${resolution}`,
      riskLevel: 'CRITICAL',
      afterValue: { status: resolution }
    });

    setFeedback(`Dispute ${selectedDispute.id} updated with resolution: ${resolution}.`);
    setSelectedDispute(null);
    setTimeout(() => setFeedback(null), 3000);
  };

  const filtered = disputes.filter(d => {
    const q = search.toLowerCase();
    const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || d.country?.toLowerCase() === selectedCountry.toLowerCase();
    const matchQuery = !q || d.id.toLowerCase().includes(q) || d.disputeId.toLowerCase().includes(q) || d.user.toLowerCase().includes(q);
    return matchCountry && matchQuery;
  });

  const columns = [
    {
      key: 'id',
      header: 'Dispute Reference',
      render: (r) => (
        <div>
          <p className="text-xs font-mono font-bold text-white">{r.id}</p>
          <p className="text-[11px] font-mono text-slate-400">{r.disputeId}</p>
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
      key: 'gateway',
      header: 'Payment Gateway',
      render: (r) => <Badge variant="purple">{r.gateway}</Badge>,
    },
    {
      key: 'user',
      header: 'Target Account',
      render: (r) => <span className="text-xs font-semibold text-white">{r.user} ({r.userId})</span>,
    },
    {
      key: 'amount',
      header: 'Disputed Amount',
      render: (r) => (
        <div>
          <p className="text-xs font-bold text-red-400">{formatCurrency(r.amountUSD)}</p>
          <p className="text-[11px] text-yellow-400 font-bold">🪙 {r.coinsInvolved.toLocaleString()} Coins Frozen</p>
        </div>
      ),
    },
    {
      key: 'state',
      header: 'Reversal State',
      render: (r) => <Badge variant="danger">{r.reversalState}</Badge>,
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
        <Button variant="outline" size="xs" onClick={() => setSelectedDispute(r)}>
          Resolve Dispute
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <AlertCircle className="h-6 w-6 text-red-400" />
            Chargebacks & Payment Disputes
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Payment provider chargebacks, bank disputes, and account hold enforcement.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{feedback}</span>
          <span className="font-mono">RESOLVED</span>
        </div>
      )}

      {/* Difference Banner */}
      <Card className="p-4 border-red-500/30 bg-red-950/20 text-xs text-slate-300">
        <div className="flex items-center gap-2 mb-1">
          <ShieldAlert className="h-4 w-4 text-red-400" />
          <strong className="text-white">Business Distinctions: REFUND vs CHARGEBACK</strong>
        </div>
        <p>
          <span className="text-gold-400 font-bold">REFUND:</span> Voluntary platform repayment initiated by support/finance. <br />
          <span className="text-red-400 font-bold">CHARGEBACK:</span> Involuntary bank/gateway dispute. Triggers automatic account hold and balance freezing.
        </p>
      </Card>

      <Card className="p-4 flex flex-col sm:flex-row items-center gap-3">
        <Input
          placeholder="Search by dispute ID, user, or reference..."
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

      {selectedDispute && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedDispute(null)}
          title={`Resolve Dispute: ${selectedDispute.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>Select resolution action for gateway chargeback on <strong className="text-white">{selectedDispute.gateway}</strong> ({formatCurrency(selectedDispute.amountUSD)}):</p>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedDispute(null)}>
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={() => handleResolveDispute('LOST_ACCEPT')}>
                Accept Chargeback
              </Button>
              <Button variant="primary" size="sm" onClick={() => handleResolveDispute('WON_DISPUTE')}>
                Submit Evidence & Challenge
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
