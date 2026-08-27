// ============================================================
// ZeParty Admin Portal — Reseller Coin Corrections Page (JSX)
// Client Excel Phase C Requirements
// ============================================================

import React, { useState } from 'react';
import { ShieldAlert, Search, Lock, CheckCircle2, RotateCcw } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';

const INITIAL_CORRECTIONS = [
  {
    id: 'RSC-301',
    resellerName: 'CoinMaster Pro',
    username: 'coinmaster_pro',
    country: 'US',
    issueType: 'Excess Reseller Coins Assigned',
    excessCoins: 1000000,
    originalTxnId: 'TXN-77120',
    affectedBalanceFrozen: true,
    status: 'READY_FOR_APPROVAL',
  },
  {
    id: 'RSC-302',
    resellerName: 'Emirates Coin Hub',
    username: 'emirates_coins',
    country: 'AE',
    issueType: 'Package Tier Profit Adjustment',
    excessCoins: 500000,
    originalTxnId: 'TXN-88231',
    affectedBalanceFrozen: true,
    status: 'READY_FOR_APPROVAL',
  },
];

export function ResellerCorrectionsPage() {
  const { logAdminAction } = useAuditLog();
  const [corrections, setCorrections] = useState(INITIAL_CORRECTIONS);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [activeCorrection, setActiveCorrection] = useState(null);
  const [auditMsg, setAuditMsg] = useState(null);

  const handleApproveCorrection = async () => {
    if (!activeCorrection) return;
    setCorrections(corrections.map(c => c.id === activeCorrection.id ? { ...c, status: 'COMPLETED', affectedBalanceFrozen: false } : c));
    
    await logAdminAction({
      action: 'RESELLER_CORRECTION_COMPLETED',
      module: 'Recharge',
      targetType: 'reseller_correction',
      targetId: activeCorrection.id,
      targetName: activeCorrection.resellerName,
      reason: 'Executed reseller package correction workflow',
      riskLevel: 'CRITICAL',
      afterValue: { status: 'COMPLETED', excessCoinsRemoved: activeCorrection.excessCoins }
    });

    setAuditMsg(`Correction ${activeCorrection.id} executed cleanly. Audit record written.`);
    setActiveCorrection(null);
    setTimeout(() => setAuditMsg(null), 3000);
  };

  const filtered = corrections.filter(c => {
    const q = search.toLowerCase();
    const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || c.country?.toLowerCase() === selectedCountry.toLowerCase();
    const matchQuery = !q || c.id.toLowerCase().includes(q) || c.resellerName.toLowerCase().includes(q) || c.username.toLowerCase().includes(q);
    return matchCountry && matchQuery;
  });

  const columns = [
    {
      key: 'reseller',
      header: 'Reseller Handle',
      render: (r) => (
        <div>
          <p className="text-xs font-bold text-white">{r.resellerName}</p>
          <p className="text-[11px] text-slate-400">@{r.username}</p>
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
      key: 'issue',
      header: 'Correction Trigger',
      render: (r) => <Badge variant="warning">{r.issueType}</Badge>,
    },
    {
      key: 'excess',
      header: 'Excess Coins',
      render: (r) => <span className="text-xs font-mono font-bold text-red-400">🪙 -{formatNumber(r.excessCoins)}</span>,
    },
    {
      key: 'freeze',
      header: 'Balance State',
      render: (r) => (
        <Badge variant={r.affectedBalanceFrozen ? 'danger' : 'neutral'}>
          {r.affectedBalanceFrozen ? 'BALANCE FROZEN' : 'ACTIVE'}
        </Badge>
      ),
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
        <Button variant="primary" size="xs" onClick={() => setActiveCorrection(r)}>
          Execute Correction Workflow
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
            Reseller Coin Correction Center
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Strict multi-step correction workflow for package mismatch and excess reseller credit.</p>
        </div>
        <Badge variant="purple">Requires Finance / Super Admin Approval</Badge>
      </div>

      {auditMsg && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{auditMsg}</span>
          <span className="font-mono">AUDIT WRITTEN</span>
        </div>
      )}

      <Card className="p-4 flex flex-col sm:flex-row items-center gap-3">
        <Input
          placeholder="Search reseller handle or correction ID..."
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

      {activeCorrection && (
        <Modal
          isOpen={true}
          onClose={() => setActiveCorrection(null)}
          title={`6-Step Correction Workflow: ${activeCorrection.id}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 rounded-xl bg-slate-800 border border-slate-700 space-y-2">
              <p className="flex items-center gap-2 text-emerald-400 font-bold">
                <CheckCircle2 className="h-4 w-4" /> 1. Balance Frozen: Affected balance in lock mode
              </p>
              <p className="flex items-center gap-2 text-emerald-400 font-bold">
                <CheckCircle2 className="h-4 w-4" /> 2. Original Txn Verified: {activeCorrection.originalTxnId}
              </p>
              <p className="flex items-center gap-2 text-emerald-400 font-bold">
                <CheckCircle2 className="h-4 w-4" /> 3. Correction Calculated: -{formatNumber(activeCorrection.excessCoins)} Coins
              </p>
              <p className="flex items-center gap-2 text-gold-400 font-bold">
                <Lock className="h-4 w-4" /> 4. Operator Approval: Super Admin Confirmation Needed
              </p>
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setActiveCorrection(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleApproveCorrection}>
                Approve & Write Audit Record
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
