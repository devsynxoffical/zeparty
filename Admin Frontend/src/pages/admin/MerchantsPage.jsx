// ============================================================
// ZeParty Admin Portal — Merchant Management Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo } from 'react';
import { ShoppingCart, Search, ShieldCheck, Coins, CheckCircle, Clock, Edit, ToggleLeft, ToggleRight, Eye, Plus, Globe, Link, CreditCard, History, UserCheck, Sliders, Power } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Tooltip } from '../../components/ui/Tooltip';
import { formatNumber, formatDate } from '../../utils/format';
import { CURRENT_MERCHANT_POLICY } from '../../mocks/policyConfig.mock';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { getCountryShortName } from '../../constants/countries.data';
import { useAuditLog } from '../../context/AuditLogContext';

const INITIAL_MERCHANTS = [
  {
    id: 'merch-001',
    userRef: 'usr-9012',
    merchantName: 'Apex Global Merchant',
    contactPerson: 'Marcus Vance',
    email: 'marcus@apexmerchant.com',
    status: 'active',
    packagePriceUSD: 3000,
    coinRatio: 8400,
    totalCoins: 25200000,
    coinAllocation: 25200000,
    targetUSD: 1000,
    salesThisMonthUSD: 2450.0,
    workingPeriodDays: 45,
    joinedAt: '2026-07-01',
    country: 'US',
    paymentMethods: ['Bank Wire Transfer', 'USDT (TRC20)', 'PayPal Express'],
    dailySettlementLimitUSD: 10000,
    linkedToWithdrawalSettlement: true,
    minPortalAmountUSD: 300,
    history: [
      { date: '2026-08-20', type: 'ALLOCATION_SET', details: 'Assigned 25.2M coin allocation' },
      { date: '2026-08-01', type: 'SETTLEMENT_LINKED', details: 'Linked to Bank Wire & USDT Settlement' }
    ]
  },
  {
    id: 'merch-002',
    userRef: 'usr-7741',
    merchantName: 'SilkRoad Pay Enterprise',
    contactPerson: 'Li Wei',
    email: 'liwei@silkroadpay.cn',
    status: 'active',
    packagePriceUSD: 3000,
    coinRatio: 8400,
    totalCoins: 25200000,
    coinAllocation: 20000000,
    targetUSD: 1000,
    salesThisMonthUSD: 1820.0,
    workingPeriodDays: 32,
    joinedAt: '2026-07-15',
    country: 'CN',
    paymentMethods: ['Bank Wire Transfer', 'Local E-Wallet'],
    dailySettlementLimitUSD: 5000,
    linkedToWithdrawalSettlement: true,
    minPortalAmountUSD: 300,
    history: [
      { date: '2026-08-15', type: 'ALLOCATION_SET', details: 'Assigned 20M coin allocation' }
    ]
  },
  {
    id: 'merch-003',
    userRef: 'usr-3319',
    merchantName: 'NovaPay Solutions',
    contactPerson: 'Aisha Rahman',
    email: 'aisha@novapay.io',
    status: 'suspended',
    packagePriceUSD: 3000,
    coinRatio: 8400,
    totalCoins: 25200000,
    coinAllocation: 10000000,
    targetUSD: 1000,
    salesThisMonthUSD: 320.0,
    workingPeriodDays: 15,
    joinedAt: '2026-08-01',
    country: 'CA',
    paymentMethods: ['USDT (TRC20)'],
    dailySettlementLimitUSD: 3000,
    linkedToWithdrawalSettlement: false,
    minPortalAmountUSD: 300,
    history: [
      { date: '2026-08-10', type: 'STATUS_SUSPENDED', details: 'Suspended pending monthly target review' }
    ]
  },
];

export function MerchantsPage() {
  const { logAdminAction } = useAuditLog();
  const [merchants, setMerchants] = useState(INITIAL_MERCHANTS);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');

  // Modals
  const [selectedMerchant, setSelectedMerchant] = useState(null);
  const [editModal, setEditModal] = useState(null);
  const [addModal, setAddModal] = useState(false);
  const [configModal, setConfigModal] = useState({ open: false, merchant: null });
  const [allocationModal, setAllocationModal] = useState({ open: false, merchant: null, newAllocation: '' });
  const [historyModal, setHistoryModal] = useState({ open: false, merchant: null });
  const [adjustModal, setAdjustModal] = useState({ open: false, type: 'DEDUCTION', amount: '', reason: '' });
  const [feedback, setFeedback] = useState(null);

  const handleExecuteMerchantAdjustment = () => {
    const merchant = historyModal.merchant;
    if (!merchant) return;

    if (!adjustModal.amount || Number(adjustModal.amount) <= 0) {
      alert('Please enter a valid positive coin amount.');
      return;
    }

    const amt = Number(adjustModal.amount);
    const isDeduct = adjustModal.type === 'DEDUCTION';
    const noteReason = adjustModal.reason.trim() || (isDeduct ? 'Manual coin deduction correction' : 'Manual coin credit adjustment');

    const updatedMerchants = merchants.map((m) => {
      if (m.id === merchant.id) {
        const newAllocation = isDeduct ? Math.max(0, (m.coinAllocation || 0) - amt) : (m.coinAllocation || 0) + amt;
        const newHistory = [
          {
            date: new Date().toISOString().split('T')[0],
            type: isDeduct ? 'MANUAL_COIN_DEDUCTION' : 'MANUAL_COIN_CREDIT',
            details: `Manual adjustment (${isDeduct ? 'Deducted' : 'Added'} ${amt.toLocaleString()} coins): ${noteReason}`,
          },
          ...(m.history || []),
        ];
        return {
          ...m,
          coinAllocation: newAllocation,
          history: newHistory,
        };
      }
      return m;
    });

    setMerchants(updatedMerchants);
    const updatedMerchant = updatedMerchants.find((m) => m.id === merchant.id);
    setHistoryModal({ open: true, merchant: updatedMerchant });
    setAdjustModal({ open: false, type: 'DEDUCTION', amount: '', reason: '' });

    logAdminAction({
      action: 'MERCHANT_PAYMENT_ADJUSTED',
      module: 'Merchants',
      targetType: 'merchant',
      targetId: merchant.id,
      targetName: merchant.merchantName,
      reason: `Manual adjustment (${isDeduct ? 'Deducted' : 'Added'} ${amt} coins): ${noteReason}`,
      riskLevel: 'HIGH',
    });
  };

  const [editForm, setEditForm] = useState({});
  const [newForm, setNewForm] = useState({
    userRef: '',
    merchantName: '',
    contactPerson: '',
    email: '',
    country: 'US',
    initialAllocation: '25200000'
  });

  const [configForm, setConfigForm] = useState({
    country: 'US',
    dailyLimitUSD: '10000',
    paymentMethods: 'Bank Wire Transfer, USDT (TRC20)'
  });

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return merchants.filter((m) => {
      const matchCountry = !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || m.country?.toLowerCase() === selectedCountry.toLowerCase();
      const matchQuery = !q || m.merchantName.toLowerCase().includes(q) || m.contactPerson.toLowerCase().includes(q) || m.email.toLowerCase().includes(q) || (m.userRef && m.userRef.toLowerCase().includes(q));
      return matchCountry && matchQuery;
    });
  }, [search, selectedCountry, merchants]);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleToggleStatus = async (merchant) => {
    const newStatus = merchant.status === 'active' ? 'suspended' : 'active';
    setMerchants(merchants.map(m => m.id === merchant.id ? { ...m, status: newStatus } : m));

    await logAdminAction({
      action: `MERCHANT_${newStatus.toUpperCase()}`,
      module: 'Recharge',
      targetType: 'merchant',
      targetId: merchant.id,
      targetName: merchant.merchantName,
      reason: `Set merchant status to ${newStatus}`,
      riskLevel: 'HIGH',
    });

    showFeedback(`${merchant.merchantName} is now ${newStatus}.`);
  };

  const handleToggleWithdrawalLink = async (merchant) => {
    const newVal = !merchant.linkedToWithdrawalSettlement;
    setMerchants(merchants.map(m => m.id === merchant.id ? { ...m, linkedToWithdrawalSettlement: newVal } : m));

    await logAdminAction({
      action: 'MERCHANT_SETTLEMENT_LINK_TOGGLED',
      module: 'Recharge',
      targetType: 'merchant',
      targetId: merchant.id,
      targetName: merchant.merchantName,
      reason: `Updated withdrawal settlement linking to ${newVal}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Withdrawal settlement linking for ${merchant.merchantName} is now ${newVal ? 'LINKED' : 'UNLINKED'}.`);
  };

  const handleOpenEdit = (merchant) => {
    setEditForm({ merchantName: merchant.merchantName, contactPerson: merchant.contactPerson, email: merchant.email, userRef: merchant.userRef || '' });
    setEditModal(merchant);
  };

  const handleSaveEdit = async () => {
    setMerchants(merchants.map(m =>
      m.id === editModal.id ? { ...m, ...editForm } : m
    ));

    await logAdminAction({
      action: 'MERCHANT_PROFILE_UPDATED',
      module: 'Recharge',
      targetType: 'merchant',
      targetId: editModal.id,
      targetName: editForm.merchantName,
      reason: 'Updated merchant profile information',
      riskLevel: 'MEDIUM',
    });

    setEditModal(null);
    showFeedback(`Merchant profile updated for ${editForm.merchantName}.`);
  };

  const handleSaveConfig = async () => {
    const { merchant } = configModal;
    if (!merchant) return;

    const methodsArray = configForm.paymentMethods.split(',').map(s => s.trim()).filter(Boolean);

    setMerchants(merchants.map(m => {
      if (m.id === merchant.id) {
        return {
          ...m,
          country: configForm.country,
          dailySettlementLimitUSD: Number(configForm.dailyLimitUSD) || m.dailySettlementLimitUSD,
          paymentMethods: methodsArray
        };
      }
      return m;
    }));

    await logAdminAction({
      action: 'MERCHANT_CONFIG_UPDATED',
      module: 'Recharge',
      targetType: 'merchant',
      targetId: merchant.id,
      targetName: merchant.merchantName,
      reason: `Configured country ${configForm.country}, limit $${configForm.dailyLimitUSD}`,
      riskLevel: 'HIGH',
    });

    setConfigModal({ open: false, merchant: null });
    showFeedback(`Configuration saved for ${merchant.merchantName}.`);
  };

  const handleSaveAllocation = async () => {
    const { merchant, newAllocation } = allocationModal;
    if (!merchant) return;

    const numAlloc = Number(newAllocation);
    if (isNaN(numAlloc)) return;

    setMerchants(merchants.map(m => {
      if (m.id === merchant.id) {
        return {
          ...m,
          coinAllocation: numAlloc,
          history: [
            { date: new Date().toISOString().split('T')[0], type: 'CUSTOM_ALLOCATION_SET', details: `Assigned custom allocation of ${formatNumber(numAlloc)} coins` },
            ...(m.history || [])
          ]
        };
      }
      return m;
    }));

    await logAdminAction({
      action: 'MERCHANT_ALLOCATION_ASSIGNED',
      module: 'Recharge',
      targetType: 'merchant',
      targetId: merchant.id,
      targetName: merchant.merchantName,
      reason: `Assigned custom coin allocation of ${numAlloc}`,
      riskLevel: 'HIGH',
    });

    setAllocationModal({ open: false, merchant: null, newAllocation: '' });
    showFeedback(`Coin allocation updated for ${merchant.merchantName}.`);
  };

  const handleAddMerchant = async () => {
    if (!newForm.merchantName || !newForm.contactPerson || !newForm.email) return;

    const newMerchant = {
      id: `merch-${Date.now()}`,
      userRef: newForm.userRef || `usr-${Math.floor(1000 + Math.random() * 9000)}`,
      merchantName: newForm.merchantName,
      contactPerson: newForm.contactPerson,
      email: newForm.email,
      country: newForm.country || 'US',
      status: 'active',
      packagePriceUSD: 3000,
      coinRatio: 8400,
      totalCoins: 25200000,
      coinAllocation: Number(newForm.initialAllocation) || 25200000,
      targetUSD: 1000,
      salesThisMonthUSD: 0,
      workingPeriodDays: 0,
      joinedAt: new Date().toISOString().split('T')[0],
      paymentMethods: ['Bank Wire Transfer', 'USDT (TRC20)'],
      dailySettlementLimitUSD: 10000,
      linkedToWithdrawalSettlement: true,
      minPortalAmountUSD: 300,
      history: [
        { date: new Date().toISOString().split('T')[0], type: 'MERCHANT_CREATED', details: 'Added merchant by user account reference' }
      ]
    };

    setMerchants([newMerchant, ...merchants]);

    await logAdminAction({
      action: 'MERCHANT_ADDED',
      module: 'Recharge',
      targetType: 'merchant',
      targetId: newMerchant.id,
      targetName: newMerchant.merchantName,
      reason: `Added merchant with account ref ${newMerchant.userRef}`,
      riskLevel: 'HIGH',
    });

    setAddModal(false);
    setNewForm({ userRef: '', merchantName: '', contactPerson: '', email: '', country: 'US', initialAllocation: '25200000' });
    showFeedback(`New merchant "${newMerchant.merchantName}" added.`);
  };

  const columns = [
    {
      key: 'merchant',
      header: 'Merchant Profile & User Ref',
      render: (row) => (
        <div>
          <p className="text-sm font-bold text-white">{row.merchantName}</p>
          <p className="text-xs text-slate-400">Contact: {row.contactPerson} • Ref: <span className="font-mono text-emerald-400">{row.userRef}</span></p>
          <p className="text-[11px] text-slate-500">{row.email}</p>
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
      key: 'allocation',
      header: 'Coin Allocation',
      render: (row) => (
        <div>
          <span className="text-xs font-bold text-yellow-400">🪙 {formatNumber(row.coinAllocation)}</span>
          <p className="text-[10px] text-slate-400">Limit: ${row.dailySettlementLimitUSD}/day</p>
        </div>
      ),
    },
    {
      key: 'settlement',
      header: 'Withdrawal Settlement',
      render: (row) => (
        <div className="flex items-center gap-1">
          <Badge variant={row.linkedToWithdrawalSettlement ? 'success' : 'neutral'}>
            {row.linkedToWithdrawalSettlement ? 'Linked' : 'Unlinked'}
          </Badge>
        </div>
      ),
    },
    {
      key: 'compliance',
      header: 'Sales vs Target',
      render: (row) => {
        const pct = Math.min(100, Math.round((row.salesThisMonthUSD / row.targetUSD) * 100));
        return (
          <div className="w-28">
            <div className="flex justify-between text-xs mb-1">
              <span className="text-emerald-400 font-bold">${row.salesThisMonthUSD}</span>
              <span className="text-slate-400">/ ${row.targetUSD}</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-1.5">
              <div className="bg-emerald-500 h-1.5 rounded-full" style={{ width: `${pct}%` }} />
            </div>
          </div>
        );
      },
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
          <Tooltip content="View Merchant Profile">
            <button
              onClick={() => setSelectedMerchant(row)}
              className="px-2 py-1 rounded-lg text-xs font-bold bg-indigo-500/10 text-indigo-400 hover:bg-indigo-500/20 border border-indigo-500/30 transition-all flex items-center gap-1"
            >
              <Eye className="h-3.5 w-3.5" />
              <span>Profile</span>
            </button>
          </Tooltip>

          <Tooltip content="Assign Custom Coin Allocation">
            <button
              onClick={() => setAllocationModal({ open: true, merchant: row, newAllocation: String(row.coinAllocation) })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-amber-400 hover:bg-slate-800 transition-colors"
            >
              <Coins className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Configure Limits & Payment Methods">
            <button
              onClick={() => {
                setConfigForm({
                  country: row.country,
                  dailyLimitUSD: String(row.dailySettlementLimitUSD),
                  paymentMethods: (row.paymentMethods || []).join(', ')
                });
                setConfigModal({ open: true, merchant: row });
              }}
              className="p-1.5 rounded-lg text-slate-400 hover:text-sky-400 hover:bg-slate-800 transition-colors"
            >
              <Sliders className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content={row.linkedToWithdrawalSettlement ? 'Linked to Withdrawal Settlement (Click to toggle)' : 'Not Linked to Withdrawal Settlement (Click to toggle)'}>
            <button
              onClick={() => handleToggleWithdrawalLink(row)}
              className={`p-1.5 rounded-lg transition-colors ${row.linkedToWithdrawalSettlement ? 'text-emerald-400 hover:bg-emerald-500/20' : 'text-slate-400 hover:text-white hover:bg-slate-800'}`}
            >
              <Link className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Transaction Ledger & Audit">
            <button
              onClick={() => setHistoryModal({ open: true, merchant: row })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-purple-400 hover:bg-slate-800 transition-colors"
            >
              <History className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content={row.status === 'active' ? 'Suspend Merchant' : 'Activate Merchant'}>
            <button
              onClick={() => handleToggleStatus(row)}
              className={`p-1.5 rounded-lg transition-colors ${row.status === 'active' ? 'text-slate-400 hover:text-rose-400 hover:bg-slate-800' : 'text-emerald-400 hover:bg-emerald-500/20'}`}
            >
              <Power className="h-3.5 w-3.5" />
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
            <ShoppingCart className="h-6 w-6 text-gold-400" />
            Merchant Management & External Settlement
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage Merchants who can receive/issue configured coin allocations and participate in external settlement.
          </p>
        </div>
        <Button variant="primary" size="sm" onClick={() => setAddModal(true)}>
          <Plus className="h-4 w-4 mr-1.5" /> Add Merchant
        </Button>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 flex-shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Policy Rules Banner */}
      <Card className="p-4 border-gold-500/30 bg-gold-950/20">
        <div className="flex items-center gap-2 mb-2">
          <Coins className="h-5 w-5 text-gold-400" />
          <h2 className="text-base font-bold text-white">Merchant Settlement Policy Overview</h2>
          <Badge variant="warning">Super Admin Logging Active</Badge>
        </div>
        <div className="grid md:grid-cols-4 gap-4 text-xs">
          <div className="p-2.5 rounded-lg bg-slate-900/80 border border-slate-700/60">
            <p className="text-slate-400">Default Allocation Price</p>
            <p className="text-base font-bold text-white">${CURRENT_MERCHANT_POLICY.priceUSD} USD</p>
          </div>
          <div className="p-2.5 rounded-lg bg-slate-900/80 border border-slate-700/60">
            <p className="text-slate-400">Profit Margin</p>
            <p className="text-base font-bold text-emerald-400">{CURRENT_MERCHANT_POLICY.profitPercent}%</p>
          </div>
          <div className="p-2.5 rounded-lg bg-slate-900/80 border border-slate-700/60">
            <p className="text-slate-400">Default Coins</p>
            <p className="text-base font-bold text-yellow-400">{formatNumber(CURRENT_MERCHANT_POLICY.totalCoins)}</p>
          </div>
          <div className="p-2.5 rounded-lg bg-slate-900/80 border border-slate-700/60">
            <p className="text-slate-400">Min Target</p>
            <p className="text-base font-bold text-white">${CURRENT_MERCHANT_POLICY.monthlySalesTargetUSD}</p>
          </div>
        </div>
      </Card>

      <Card className="p-4 flex flex-col sm:flex-row items-center gap-3">
        <Input
          placeholder="Search merchant name, contact, email, or User ID ref..."
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

      {/* Add Merchant Modal */}
      {addModal && (
        <Modal isOpen={true} onClose={() => setAddModal(false)} title="Add Merchant by User/Account Reference" size="sm">
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="User ID / Account Reference *"
              value={newForm.userRef}
              onChange={(e) => setNewForm({ ...newForm, userRef: e.target.value })}
              placeholder="e.g. usr-8812 or handle"
            />
            <Input
              label="Organization Name *"
              value={newForm.merchantName}
              onChange={(e) => setNewForm({ ...newForm, merchantName: e.target.value })}
              placeholder="e.g. Global Pay Ltd"
            />
            <Input
              label="Contact Person *"
              value={newForm.contactPerson}
              onChange={(e) => setNewForm({ ...newForm, contactPerson: e.target.value })}
              placeholder="e.g. Marcus Vance"
            />
            <Input
              label="Email *"
              value={newForm.email}
              onChange={(e) => setNewForm({ ...newForm, email: e.target.value })}
              placeholder="e.g. marcus@globalpay.com"
            />
            <div className="grid grid-cols-2 gap-3">
              <CountrySelect
                label="Country"
                value={newForm.country}
                onChange={(code) => setNewForm({ ...newForm, country: code })}
              />
              <Input
                label="Initial Coin Allocation"
                type="number"
                value={newForm.initialAllocation}
                onChange={(e) => setNewForm({ ...newForm, initialAllocation: e.target.value })}
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setAddModal(false)}>Cancel</Button>
              <Button variant="primary" size="sm" onClick={handleAddMerchant}>Create Merchant</Button>
            </div>
          </div>
        </Modal>
      )}

      {/* View Merchant Profile Modal */}
      {selectedMerchant && (
        <Modal isOpen={true} onClose={() => setSelectedMerchant(null)} title={`Merchant Profile: ${selectedMerchant.merchantName}`} size="md">
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-base font-bold text-white">{selectedMerchant.merchantName}</span>
                <StatusBadge status={selectedMerchant.status} />
              </div>
              <p><strong>Account Reference:</strong> <span className="font-mono text-emerald-400">{selectedMerchant.userRef}</span></p>
              <p><strong>Contact Person:</strong> {selectedMerchant.contactPerson} ({selectedMerchant.email})</p>
              <p><strong>Country:</strong> {getCountryShortName(selectedMerchant.country)} ({selectedMerchant.country})</p>
              <p><strong>Coin Allocation:</strong> <span className="text-yellow-400 font-bold">🪙 {formatNumber(selectedMerchant.coinAllocation)}</span></p>
              <p><strong>Daily Settlement Limit:</strong> ${selectedMerchant.dailySettlementLimitUSD} USD</p>
              <p><strong>Supported Payment Methods:</strong> {(selectedMerchant.paymentMethods || []).join(', ')}</p>
              <p><strong>Withdrawal Settlement Link:</strong> <span className="text-emerald-400 font-bold">{selectedMerchant.linkedToWithdrawalSettlement ? 'LINKED' : 'NOT LINKED'}</span></p>
              <p><strong>Sales This Month:</strong> ${selectedMerchant.salesThisMonthUSD} / ${selectedMerchant.targetUSD}</p>
            </div>
            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedMerchant(null)}>Close Profile</Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Assign Custom Coin Allocation Modal */}
      {allocationModal.open && (
        <Modal isOpen={true} onClose={() => setAllocationModal({ open: false, merchant: null, newAllocation: '' })} title={`Assign Coin Allocation: ${allocationModal.merchant?.merchantName}`} size="sm">
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Custom Coin Allocation Amount *"
              type="number"
              value={allocationModal.newAllocation}
              onChange={(e) => setAllocationModal({ ...allocationModal, newAllocation: e.target.value })}
              placeholder="e.g. 25200000"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setAllocationModal({ open: false, merchant: null, newAllocation: '' })}>Cancel</Button>
              <Button variant="primary" size="sm" onClick={handleSaveAllocation}>Assign Allocation</Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Configure Country, Payment Methods & Settlement Limits Modal */}
      {configModal.open && (
        <Modal isOpen={true} onClose={() => setConfigModal({ open: false, merchant: null })} title={`Configure Settlement Limits & Country: ${configModal.merchant?.merchantName}`} size="sm">
          <div className="space-y-4 text-xs text-slate-300">
            <CountrySelect
              label="Operational Country"
              value={configForm.country}
              onChange={(code) => setConfigForm({ ...configForm, country: code })}
            />
            <Input
              label="Daily Settlement Limit ($ USD)"
              type="number"
              value={configForm.dailyLimitUSD}
              onChange={(e) => setConfigForm({ ...configForm, dailyLimitUSD: e.target.value })}
            />
            <Input
              label="Payment Methods (comma separated)"
              value={configForm.paymentMethods}
              onChange={(e) => setConfigForm({ ...configForm, paymentMethods: e.target.value })}
              placeholder="Bank Wire Transfer, USDT (TRC20), PayPal Express"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setConfigModal({ open: false, merchant: null })}>Cancel</Button>
              <Button variant="primary" size="sm" onClick={handleSaveConfig}>Save Configuration</Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Transaction & Correction History Modal */}
      {historyModal.open && (
        <Modal isOpen={true} onClose={() => setHistoryModal({ open: false, merchant: null })} title={`Merchant Corrections & Transaction History: ${historyModal.merchant?.merchantName}`} size="lg">
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 bg-slate-900 border border-slate-800 rounded-xl space-y-3">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-bold text-white text-base">{historyModal.merchant?.merchantName}</p>
                    <Badge variant="warning">Audit Logged</Badge>
                  </div>
                  <p className="text-xs text-slate-400 mt-1">Ref: {historyModal.merchant?.userRef}</p>
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

              <div className="bg-slate-950 px-3 py-2 rounded-lg border border-slate-800 text-xs font-mono text-slate-400">
                Current Coin Allocation: <strong className="text-emerald-400 font-mono ml-1">{formatNumber(historyModal.merchant?.coinAllocation)} coins</strong>
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
                    placeholder="e.g. 1000000"
                  />
                </div>

                <Input
                  label="Adjustment Reason / Audit Note *"
                  value={adjustModal.reason}
                  onChange={(e) => setAdjustModal({ ...adjustModal, reason: e.target.value })}
                  placeholder="e.g. Corrected mistaken duplicate coin allocation"
                />

                <div className="flex justify-end pt-1">
                  <Button variant="danger" size="xs" onClick={handleExecuteMerchantAdjustment}>
                    Execute Adjustment & Audit Log
                  </Button>
                </div>
              </div>
            )}

            <div className="space-y-2 max-h-60 overflow-y-auto pr-1">
              {historyModal.merchant?.history?.map((h, i) => (
                <div key={i} className="p-2.5 bg-slate-900/80 border border-slate-800 rounded-lg flex justify-between items-center">
                  <div>
                    <span className={`font-bold ${h.type?.includes('DEDUCTION') ? 'text-rose-400' : 'text-emerald-400'}`}>
                      {h.type}
                    </span>
                    <p className="text-slate-300 text-[11px] mt-0.5">{h.details}</p>
                    <p className="text-slate-500 text-[10px]">{h.date}</p>
                  </div>
                </div>
              ))}
            </div>
            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => setHistoryModal({ open: false, merchant: null })}>Close Ledger</Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
