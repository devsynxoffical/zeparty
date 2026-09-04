// ============================================================
// ZeParty Admin Portal — Resellers & Coin Sellers Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo } from 'react';
import { Store, Plus, Search, ShieldCheck, Coins, CheckCircle, Package, Globe, UserCheck, AlertTriangle, UserPlus, UserMinus, History, FileText, DollarSign, Wallet, Power } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Tooltip } from '../../components/ui/Tooltip';
import { MOCK_COIN_SELLERS } from '../../mocks/leaderboards.mock';
import { formatNumber, formatCurrency, formatDate } from '../../utils/format';
import { CURRENT_COINS_SELLER_POLICY } from '../../mocks/policyConfig.mock';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { getCountryShortName } from '../../constants/countries.data';

const PACKAGES = [
  { value: '300', label: '$300 Package', coins: 2205000, profit: '5%' },
  { value: '500', label: '$500 Package', coins: 3675000, profit: '5%' },
  { value: '1000', label: '$1,000 Package', coins: 7700000, profit: '10%' },
];

export function CoinSellersPage() {
  const { logAdminAction } = useAuditLog();
  const [sellers, setSellers] = useState(
    MOCK_COIN_SELLERS.map((s, idx) => ({
      ...s,
      country: s.country || (idx % 2 === 0 ? 'US' : 'AE'),
      insuranceStatus: 'verified',
      policyInfraction: false,
      packageTier: s.packageTier || '$1,000 Reseller Tier',
      profitPercent: s.profitPercent || 10,
      totalIssued: s.totalSold || 7700000,
      currentBalance: Math.floor((s.totalSold || 7700000) * 0.25),
      distributedCoins: Math.floor((s.totalSold || 7700000) * 0.75),
      creditLimit: 20000000,
      correctionsHistory: [
        { date: '2026-08-20', type: 'COIN_CREDIT', amount: 500000, note: 'Approved operational credit buffer' },
        { date: '2026-08-15', type: 'TIER_ADJUSTMENT', amount: 0, note: 'Upgraded to 10% Profit Tier' }
      ]
    }))
  );

  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');
  
  // Modals
  const [addResellerModal, setAddResellerModal] = useState(false);
  const [newResellerForm, setNewResellerForm] = useState({
    username: '',
    sellerName: '',
    country: 'US',
    initialCredit: '500000',
    creditLimit: '10000000'
  });

  const [issueModal, setIssueModal] = useState({ open: false, seller: null });
  const [customCoins, setCustomCoins] = useState('');
  const [issueReason, setIssueReason] = useState('');
  const [usePreset, setUsePreset] = useState(false);
  const [selectedPkg, setSelectedPkg] = useState('1000');

  const [balanceModal, setBalanceModal] = useState({ open: false, seller: null, customBalance: '', creditLimit: '' });

  const [countryModal, setCountryModal] = useState({ open: false, seller: null, newCountry: 'US' });
  const [historyModal, setHistoryModal] = useState({ open: false, seller: null });
  const [adjustModal, setAdjustModal] = useState({ open: false, type: 'DEDUCTION', amount: '', reason: '' });
  const [feedback, setFeedback] = useState(null);

  const handleExecuteAdjustment = () => {
    const seller = historyModal.seller;
    if (!seller) return;

    if (!adjustModal.amount || Number(adjustModal.amount) <= 0) {
      alert('Please enter a valid positive coin amount.');
      return;
    }

    const amt = Number(adjustModal.amount);
    const isDeduct = adjustModal.type === 'DEDUCTION';
    const noteReason = adjustModal.reason.trim() || (isDeduct ? 'Manual coin deduction correction' : 'Manual coin credit adjustment');

    const updatedSellers = sellers.map((s) => {
      if (s.id === seller.id) {
        const newBalance = isDeduct ? Math.max(0, (s.currentBalance || 0) - amt) : (s.currentBalance || 0) + amt;
        const newTotal = isDeduct ? Math.max(0, (s.totalIssued || 0) - amt) : (s.totalIssued || 0) + amt;
        const newHistory = [
          {
            date: new Date().toISOString().split('T')[0],
            type: isDeduct ? 'MANUAL_COIN_DEDUCTION' : 'MANUAL_COIN_CREDIT',
            amount: isDeduct ? -amt : amt,
            note: noteReason,
          },
          ...(s.correctionsHistory || []),
        ];
        return {
          ...s,
          currentBalance: newBalance,
          totalIssued: newTotal,
          correctionsHistory: newHistory,
        };
      }
      return s;
    });

    setSellers(updatedSellers);
    const updatedSeller = updatedSellers.find((s) => s.id === seller.id);
    setHistoryModal({ open: true, seller: updatedSeller });
    setAdjustModal({ open: false, type: 'DEDUCTION', amount: '', reason: '' });

    logAdminAction({
      action: 'RESELLER_PAYMENT_ADJUSTED',
      module: 'CoinSellers',
      targetType: 'reseller',
      targetId: seller.id,
      targetName: seller.sellerName,
      reason: `Manual adjustment (${isDeduct ? 'Deducted' : 'Added'} ${amt} coins): ${noteReason}`,
      riskLevel: 'HIGH',
    });
  };

  const filtered = useMemo(() => {
    return sellers.filter((s) => {
      const q = search.toLowerCase();
      const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || s.country?.toLowerCase() === selectedCountry.toLowerCase();
      const matchQuery = !q || s.sellerName.toLowerCase().includes(q) || s.username.toLowerCase().includes(q) || (s.id && s.id.toLowerCase().includes(q));
      return matchCountry && matchQuery;
    });
  }, [search, selectedCountry, sellers]);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  // Add new Reseller role
  const handleAddResellerRole = async () => {
    if (!newResellerForm.username || !newResellerForm.sellerName) return;

    const newSeller = {
      id: `seller-${Date.now()}`,
      username: newResellerForm.username.replace('@', ''),
      sellerName: newResellerForm.sellerName,
      country: newResellerForm.country,
      status: 'active',
      insuranceStatus: 'verified',
      policyInfraction: false,
      packageTier: 'Custom Coin Policy',
      profitPercent: 10,
      totalIssued: Number(newResellerForm.initialCredit) || 0,
      currentBalance: Number(newResellerForm.initialCredit) || 0,
      distributedCoins: 0,
      creditLimit: Number(newResellerForm.creditLimit) || 10000000,
      correctionsHistory: [
        { date: new Date().toISOString().split('T')[0], type: 'ROLE_ASSIGNED', amount: Number(newResellerForm.initialCredit), note: 'Assigned reseller role and initial coin credit' }
      ]
    };

    setSellers([newSeller, ...sellers]);
    setAddResellerModal(false);
    setNewResellerForm({ username: '', sellerName: '', country: 'US', initialCredit: '500000', creditLimit: '10000000' });

    await logAdminAction({
      action: 'RESELLER_ROLE_ADDED',
      module: 'Recharge',
      targetType: 'reseller',
      targetId: newSeller.username,
      targetName: newSeller.sellerName,
      reason: `Assigned Reseller role with initial credit of ${newSeller.currentBalance} coins`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Reseller role assigned to @${newSeller.username}.`);
  };

  // Remove Reseller role
  const handleRemoveResellerRole = async (seller) => {
    setSellers(sellers.filter((s) => s.username !== seller.username));

    await logAdminAction({
      action: 'RESELLER_ROLE_REMOVED',
      module: 'Recharge',
      targetType: 'reseller',
      targetId: seller.username,
      targetName: seller.sellerName,
      reason: `Revoked Reseller role`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Reseller role revoked for @${seller.username}.`);
  };

  // Issue custom coin amount
  const handleIssueCoins = async () => {
    if (!issueModal.seller) return;
    let coinsToIssue = 0;

    if (usePreset) {
      const pkg = PACKAGES.find(p => p.value === selectedPkg);
      coinsToIssue = pkg ? pkg.coins : 0;
    } else {
      coinsToIssue = Number(customCoins);
    }

    if (!coinsToIssue || coinsToIssue <= 0) return;

    setSellers(sellers.map(s => {
      if (s.username === issueModal.seller.username) {
        const newTotalIssued = (s.totalIssued || 0) + coinsToIssue;
        const newBalance = (s.currentBalance || 0) + coinsToIssue;
        const newHistory = [
          { date: new Date().toISOString().split('T')[0], type: 'CUSTOM_COINS_ISSUED', amount: coinsToIssue, note: issueReason || 'Issued custom coin allocation' },
          ...(s.correctionsHistory || [])
        ];
        return {
          ...s,
          totalIssued: newTotalIssued,
          currentBalance: newBalance,
          correctionsHistory: newHistory
        };
      }
      return s;
    }));

    await logAdminAction({
      action: 'RESELLER_COINS_ISSUED',
      module: 'Recharge',
      targetType: 'reseller',
      targetId: issueModal.seller?.username,
      targetName: issueModal.seller?.sellerName,
      reason: issueReason || `Issued ${formatNumber(coinsToIssue)} custom reseller coins`,
      riskLevel: 'HIGH',
      afterValue: { coinsIssued: coinsToIssue }
    });

    showFeedback(`Issued ${formatNumber(coinsToIssue)} coins to ${issueModal.seller?.sellerName}.`);
    setIssueModal({ open: false, seller: null });
    setCustomCoins('');
    setIssueReason('');
  };

  // Assign Custom Coin Balance / Credit
  const handleUpdateBalanceAndCredit = async () => {
    const { seller, customBalance, creditLimit } = balanceModal;
    if (!seller) return;

    const newBal = Number(customBalance);
    const newLimit = Number(creditLimit);

    setSellers(sellers.map(s => {
      if (s.username === seller.username) {
        return {
          ...s,
          currentBalance: isNaN(newBal) ? s.currentBalance : newBal,
          creditLimit: isNaN(newLimit) ? s.creditLimit : newLimit,
          correctionsHistory: [
            { date: new Date().toISOString().split('T')[0], type: 'BALANCE_CREDIT_SET', amount: newBal, note: `Custom balance updated to ${newBal}` },
            ...(s.correctionsHistory || [])
          ]
        };
      }
      return s;
    }));

    await logAdminAction({
      action: 'RESELLER_BALANCE_UPDATED',
      module: 'Recharge',
      targetType: 'reseller',
      targetId: seller.username,
      targetName: seller.sellerName,
      reason: `Updated balance to ${newBal} coins, limit to ${newLimit}`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Updated balance & credit limits for ${seller.sellerName}.`);
    setBalanceModal({ open: false, seller: null, customBalance: '', creditLimit: '' });
  };

  const handleUpdateCountry = async () => {
    const { seller, newCountry } = countryModal;
    if (!seller) return;

    setSellers(sellers.map(s => s.username === seller.username ? { ...s, country: newCountry } : s));

    await logAdminAction({
      action: 'RESELLER_COUNTRY_MAPPED',
      module: 'Recharge',
      targetType: 'reseller',
      targetId: seller.username,
      targetName: seller.sellerName,
      reason: `Mapped reseller to country ${newCountry}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Reseller ${seller.sellerName} mapped to ${newCountry}.`);
    setCountryModal({ open: false, seller: null, newCountry: 'US' });
  };

  const handleToggleStatus = async (seller) => {
    const newStatus = seller.status === 'active' ? 'suspended' : 'active';
    setSellers(sellers.map(s => s.username === seller.username ? { ...s, status: newStatus } : s));

    await logAdminAction({
      action: `RESELLER_${newStatus.toUpperCase()}`,
      module: 'Recharge',
      targetType: 'reseller',
      targetId: seller.username,
      targetName: seller.sellerName,
      reason: `Administrator set status to ${newStatus}`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Reseller ${seller.sellerName} is now ${newStatus}.`);
  };

  const columns = [
    {
      key: 'seller',
      header: 'Reseller ID & Handle',
      render: (row) => (
        <div>
          <p className="text-sm font-bold text-white">{row.sellerName}</p>
          <p className="text-xs text-slate-400">@{row.username} • ID: <span className="font-mono text-slate-300">{row.id}</span></p>
        </div>
      ),
    },
    {
      key: 'country',
      header: 'Country',
      render: (row) => (
        <div className="flex items-center gap-1.5 text-xs font-semibold text-white">
          <CountryFlag code={row.country} className="w-4 h-3 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(row.country)}</span>
        </div>
      ),
    },
    {
      key: 'balances',
      header: 'Balance / Issued / Distributed',
      render: (row) => (
        <div className="text-xs space-y-0.5">
          <p className="text-emerald-400 font-bold">Avail: 🪙 {formatNumber(row.currentBalance)}</p>
          <p className="text-slate-300">Issued: {formatNumber(row.totalIssued)}</p>
          <p className="text-slate-400 text-[11px]">Dist: {formatNumber(row.distributedCoins)} / Limit: {formatNumber(row.creditLimit)}</p>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex items-center gap-1 shrink-0">
          <Tooltip content="Issue Custom Coins">
            <button
              onClick={() => { setCustomCoins('500000'); setUsePreset(false); setIssueModal({ open: true, seller: row }); }}
              className="px-2 py-1 rounded-lg text-xs font-bold bg-amber-500/10 text-amber-400 hover:bg-amber-500/20 border border-amber-500/30 transition-all flex items-center gap-1"
            >
              <Coins className="h-3.5 w-3.5" />
              <span>Issue</span>
            </button>
          </Tooltip>
          
          <Tooltip content="Set Balance & Credit Limit">
            <button
              onClick={() => setBalanceModal({ open: true, seller: row, customBalance: String(row.currentBalance), creditLimit: String(row.creditLimit) })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-emerald-400 hover:bg-slate-800 transition-colors"
            >
              <Wallet className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Correction History & Ledger">
            <button
              onClick={() => setHistoryModal({ open: true, seller: row })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-indigo-400 hover:bg-slate-800 transition-colors"
            >
              <History className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Map Reseller Country">
            <button
              onClick={() => setCountryModal({ open: true, seller: row, newCountry: row.country || 'US' })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-sky-400 hover:bg-slate-800 transition-colors"
            >
              <Globe className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content={row.status === 'active' ? 'Suspend Reseller' : 'Activate Reseller'}>
            <button
              onClick={() => handleToggleStatus(row)}
              className={`p-1.5 rounded-lg transition-colors ${row.status === 'active' ? 'text-slate-400 hover:text-rose-400 hover:bg-slate-800' : 'text-emerald-400 hover:bg-emerald-500/20'}`}
            >
              <Power className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Remove Reseller Role">
            <button
              onClick={() => handleRemoveResellerRole(row)}
              className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-800 transition-colors"
            >
              <UserMinus className="h-3.5 w-3.5" />
            </button>
          </Tooltip>
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Store className="h-6 w-6 text-emerald-400" />
            Resellers & Coin Sellers Management
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage Coin Sellers/Resellers without forcing fixed packages. Assign custom coin amounts according to business policy.
          </p>
        </div>
        <Button variant="primary" size="sm" onClick={() => setAddResellerModal(true)}>
          <UserPlus className="h-4 w-4 mr-1.5" /> Add Reseller Role
        </Button>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 flex-shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Policy Header Banner */}
      <Card className="p-4 border-emerald-500/30 bg-emerald-950/20">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Coins className="h-5 w-5 text-emerald-400" />
            <div>
              <h2 className="text-sm font-bold text-white">Custom Coin Allocation & Flexibility Enabled</h2>
              <p className="text-xs text-slate-300">
                Admin can issue any coin amount according to configured business policy. All financial and permission-sensitive actions are logged.
              </p>
            </div>
          </div>
          <Badge variant="success">Flexible Amounts Enabled</Badge>
        </div>
      </Card>

      <Card className="p-4 flex flex-col sm:flex-row items-center gap-3">
        <Input
          placeholder="Search reseller by User ID, handle, or name…"
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

      <DataTable
        columns={columns}
        data={filtered}
        emptyTitle="No coin resellers found"
        emptyDescription="No authorized coin sellers match your search query."
      />

      {/* Add Reseller Modal */}
      {addResellerModal && (
        <Modal
          isOpen={true}
          onClose={() => setAddResellerModal(false)}
          title="Add Reseller Role to User"
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="User ID / Username Handle *"
              value={newResellerForm.username}
              onChange={(e) => setNewResellerForm({ ...newResellerForm, username: e.target.value })}
              placeholder="e.g. alex_reseller or user-9021"
            />
            <Input
              label="Display / Organization Name *"
              value={newResellerForm.sellerName}
              onChange={(e) => setNewResellerForm({ ...newResellerForm, sellerName: e.target.value })}
              placeholder="e.g. Global Apex Distribution"
            />
            <div className="grid grid-cols-2 gap-3">
              <CountrySelect
                label="Country"
                value={newResellerForm.country}
                onChange={(code) => setNewResellerForm({ ...newResellerForm, country: code })}
              />
              <Input
                label="Initial Coin Credit"
                type="number"
                value={newResellerForm.initialCredit}
                onChange={(e) => setNewResellerForm({ ...newResellerForm, initialCredit: e.target.value })}
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setAddResellerModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleAddResellerRole}>
                Assign Reseller Role
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Issue Custom Coins Modal */}
      {issueModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setIssueModal({ open: false, seller: null })}
          title={`Issue Coins: ${issueModal.seller?.sellerName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Issue coins with a <strong className="text-white">custom amount</strong> or choose an optional policy preset.
            </p>

            <div className="flex items-center gap-3 py-1">
              <label className="flex items-center gap-1.5 cursor-pointer">
                <input
                  type="radio"
                  checked={!usePreset}
                  onChange={() => setUsePreset(false)}
                  className="text-emerald-500 focus:ring-emerald-500"
                />
                <span>Custom Coin Amount</span>
              </label>
              <label className="flex items-center gap-1.5 cursor-pointer">
                <input
                  type="radio"
                  checked={usePreset}
                  onChange={() => setUsePreset(true)}
                  className="text-emerald-500 focus:ring-emerald-500"
                />
                <span>Package Presets</span>
              </label>
            </div>

            {!usePreset ? (
              <Input
                label="Custom Coin Amount *"
                type="number"
                value={customCoins}
                onChange={(e) => setCustomCoins(e.target.value)}
                placeholder="e.g. 1500000"
              />
            ) : (
              <div>
                <label className="block text-slate-400 mb-1 font-semibold">Select Package Preset</label>
                <select
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white focus:outline-none"
                  value={selectedPkg}
                  onChange={(e) => setSelectedPkg(e.target.value)}
                >
                  {PACKAGES.map(pkg => (
                    <option key={pkg.value} value={pkg.value}>
                      {pkg.label} — {formatNumber(pkg.coins)} Coins ({pkg.profit} Profit)
                    </option>
                  ))}
                </select>
              </div>
            )}

            <Input
              label="Issuance Reason / Note"
              value={issueReason}
              onChange={(e) => setIssueReason(e.target.value)}
              placeholder="e.g. Approved regional credit top-up"
            />

            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setIssueModal({ open: false, seller: null })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleIssueCoins}>
                Confirm & Issue Coins
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Set Balance & Credit Limits Modal */}
      {balanceModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setBalanceModal({ open: false, seller: null, customBalance: '', creditLimit: '' })}
          title={`Assign Balance & Credit: ${balanceModal.seller?.sellerName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Custom Available Coin Balance"
              type="number"
              value={balanceModal.customBalance}
              onChange={(e) => setBalanceModal({ ...balanceModal, customBalance: e.target.value })}
            />
            <Input
              label="Reseller Credit Limit (Coins)"
              type="number"
              value={balanceModal.creditLimit}
              onChange={(e) => setBalanceModal({ ...balanceModal, creditLimit: e.target.value })}
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setBalanceModal({ open: false, seller: null, customBalance: '', creditLimit: '' })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleUpdateBalanceAndCredit}>
                Save Balance & Limits
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* History & Transaction Ledger Modal */}
      {historyModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setHistoryModal({ open: false, seller: null })}
          title={`Reseller History & Transaction Ledger: ${historyModal.seller?.sellerName}`}
          size="lg"
        >
          <div className="space-y-4 text-xs">
            <div className="p-4 bg-slate-900 border border-slate-800 rounded-xl text-slate-300 space-y-3">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-bold text-white text-base">
                      @{historyModal.seller?.username ? historyModal.seller.username.replace(/^@+/, '') : 'seller'}
                    </p>
                    <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-purple-500/20 text-purple-300 border border-purple-500/30 whitespace-nowrap">
                      {historyModal.seller?.profitPercent || 10}% Profit Tier
                    </span>
                    <Badge variant="purple">Logged & Audited</Badge>
                  </div>
                  <p className="text-xs text-slate-400 mt-1">{historyModal.seller?.sellerName}</p>
                </div>

                <Button
                  variant="danger"
                  size="sm"
                  className="shrink-0 whitespace-nowrap"
                  onClick={() => setAdjustModal({ open: true, type: 'DEDUCTION', amount: '', reason: '' })}
                >
                  Adjust Payment / Deduct Coins
                </Button>
              </div>

              <div className="flex flex-wrap items-center gap-4 text-xs font-mono text-slate-400">
                <div className="bg-slate-950 px-3 py-1.5 rounded-lg border border-slate-800">
                  Total Issued: <strong className="text-gold-400 font-mono ml-1">{formatNumber(historyModal.seller?.totalIssued)} coins</strong>
                </div>
                <div className="bg-slate-950 px-3 py-1.5 rounded-lg border border-slate-800">
                  Available Balance: <strong className="text-emerald-400 font-mono ml-1">{formatNumber(historyModal.seller?.currentBalance)} coins</strong>
                </div>
              </div>
            </div>

            {/* Adjust Payment Inline Form */}
            {adjustModal.open && (
              <div className="p-3.5 bg-slate-950 border border-rose-500/30 rounded-xl space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-white text-xs">Manual Payment / Coin Adjustment</span>
                  <button
                    onClick={() => setAdjustModal({ open: false, type: 'DEDUCTION', amount: '', reason: '' })}
                    className="text-slate-400 hover:text-white text-xs font-bold"
                  >
                    Cancel
                  </button>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-[11px] text-slate-400 font-semibold mb-1">Adjustment Action</label>
                    <select
                      className="w-full bg-slate-900 border border-slate-700 rounded px-2.5 py-1.5 text-white text-xs"
                      value={adjustModal.type}
                      onChange={(e) => setAdjustModal({ ...adjustModal, type: e.target.value })}
                    >
                      <option value="DEDUCTION">Deduct Mistaken Coins (-)</option>
                      <option value="CREDIT">Add Coin Credit (+)</option>
                    </select>
                  </div>
                  <Input
                    label="Coin Amount *"
                    type="number"
                    value={adjustModal.amount}
                    onChange={(e) => setAdjustModal({ ...adjustModal, amount: e.target.value })}
                    placeholder="e.g. 500000"
                  />
                </div>

                <Input
                  label="Adjustment Reason / Audit Note *"
                  value={adjustModal.reason}
                  onChange={(e) => setAdjustModal({ ...adjustModal, reason: e.target.value })}
                  placeholder="e.g. Corrected mistaken duplicate coin grant"
                />

                <div className="flex justify-end pt-1">
                  <Button variant="danger" size="xs" onClick={handleExecuteAdjustment}>
                    Execute Adjustment & Audit Log
                  </Button>
                </div>
              </div>
            )}

            {/* Detailed Transaction & Payment History Stream */}
            <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
              <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Historical Allocation & Payment Log</p>
              {historyModal.seller?.correctionsHistory?.map((h, i) => (
                <div key={i} className="p-3 bg-slate-900/80 border border-slate-800 rounded-lg flex justify-between items-center">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className={`font-bold text-xs ${h.amount < 0 || h.type?.includes('DEDUCTION') ? 'text-rose-400' : 'text-emerald-400'}`}>
                        {h.type}
                      </span>
                      <span className="text-[10px] text-slate-500 font-mono">{h.date}</span>
                    </div>
                    <p className="text-slate-300 text-[11px] mt-0.5">{h.note}</p>
                  </div>
                  {h.amount !== undefined && (
                    <span className={`font-mono font-bold text-xs ${h.amount < 0 || h.type?.includes('DEDUCTION') ? 'text-rose-400' : 'text-gold-400'}`}>
                      🪙 {h.amount > 0 ? '+' : ''}{formatNumber(h.amount)}
                    </span>
                  )}
                </div>
              ))}
            </div>

            <div className="flex justify-between items-center pt-2 border-t border-slate-800">
              <span className="text-[11px] text-slate-500 italic">Audit Log ID: AUD-{historyModal.seller?.id || '001'}</span>
              <Button variant="ghost" size="sm" onClick={() => setHistoryModal({ open: false, seller: null })}>
                Close Ledger
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Country Modal */}
      {countryModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setCountryModal({ open: false, seller: null, newCountry: 'US' })}
          title={`Set Reseller Country: ${countryModal.seller?.sellerName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <CountrySelect
              label="Select Country"
              value={countryModal.newCountry}
              onChange={(code) => setCountryModal({ ...countryModal, newCountry: code })}
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setCountryModal({ open: false, seller: null, newCountry: 'US' })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleUpdateCountry}>
                Confirm Country Mapping
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
