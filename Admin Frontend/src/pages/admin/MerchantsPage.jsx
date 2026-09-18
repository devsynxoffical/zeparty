// ============================================================
// ZeParty Admin Portal — Merchant Management Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import {
  ShoppingCart,
  Search,
  ShieldCheck,
  Coins,
  CheckCircle,
  Clock,
  Edit,
  ToggleLeft,
  ToggleRight,
  Eye,
  Plus,
  Globe,
  Link,
  CreditCard,
  History,
  UserCheck,
  Sliders,
  Power,
  Trash2,
  DollarSign,
  AlertTriangle,
  Wallet,
  RefreshCw,
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Tooltip } from '../../components/ui/Tooltip';
import { formatNumber, formatDate } from '../../utils/format';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { getCountryShortName } from '../../constants/countries.data';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getMerchants,
  createMerchant,
  updateMerchant,
  adjustMerchantBalance,
  deleteMerchant,
} from '../../services/modules/merchants.service';
import { CURRENT_MERCHANT_POLICY } from '../../mocks/policies/merchantPolicy.mock';

export function MerchantsPage() {
  const { logAdminAction } = useAuditLog();
  const [merchants, setMerchants] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCountry, setSelectedCountry] = useState('All');

  const fetchMerchantsData = async () => {
    setLoading(true);
    try {
      const data = await getMerchants();
      setMerchants(data || []);
    } catch (err) {
      console.error('Failed to load merchants:', err);
      setMerchants([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMerchantsData();
  }, []);

  // Modals state
  const [selectedMerchant, setSelectedMerchant] = useState(null);
  const [editModal, setEditModal] = useState(null);
  const [addModal, setAddModal] = useState(false);
  const [configModal, setConfigModal] = useState({ open: false, merchant: null });
  const [allocationModal, setAllocationModal] = useState({ open: false, merchant: null, newAllocation: '' });
  const [historyModal, setHistoryModal] = useState({ open: false, merchant: null });
  const [balanceModal, setBalanceModal] = useState({ open: false, merchant: null, amount: '', type: 'CREDIT', reason: '' });
  const [deleteModal, setDeleteModal] = useState({ open: false, merchant: null, reason: '' });
  const [adjustModal, setAdjustModal] = useState({ open: false, type: 'DEDUCTION', amount: '', reason: '' });
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const [editForm, setEditForm] = useState({
    merchantName: '',
    contactPerson: '',
    email: '',
    userRef: '',
  });

  const [newForm, setNewForm] = useState({
    userRef: '',
    merchantName: '',
    contactPerson: '',
    email: '',
    country: 'US',
    initialAllocation: '25200000',
  });

  const [configForm, setConfigForm] = useState({
    country: 'US',
    dailyLimitUSD: '10000',
    paymentMethods: 'Bank Wire Transfer, USDT (TRC20)',
  });

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return merchants.filter((m) => {
      const matchCountry =
        !selectedCountry ||
        selectedCountry === 'All' ||
        selectedCountry === 'GLOBAL' ||
        m.country?.toLowerCase() === selectedCountry.toLowerCase();
      const matchQuery =
        !q ||
        m.merchantName?.toLowerCase().includes(q) ||
        m.contactPerson?.toLowerCase().includes(q) ||
        m.email?.toLowerCase().includes(q) ||
        (m.userRef && m.userRef.toLowerCase().includes(q));
      return matchCountry && matchQuery;
    });
  }, [search, selectedCountry, merchants]);

  // Status toggle handler
  const handleToggleStatus = async (merchant) => {
    const newStatus = merchant.status === 'active' ? 'suspended' : 'active';
    try {
      await updateMerchant(merchant.id, {
        status: newStatus.toUpperCase(),
      });

      await logAdminAction({
        action: `MERCHANT_${newStatus.toUpperCase()}`,
        module: 'Merchants',
        targetType: 'merchant',
        targetId: merchant.id,
        targetName: merchant.merchantName,
        reason: `Set merchant status to ${newStatus}`,
        riskLevel: 'HIGH',
      });

      setMerchants((prev) =>
        prev.map((m) => (m.id === merchant.id ? { ...m, status: newStatus } : m))
      );
      showFeedback(`${merchant.merchantName} is now ${newStatus}.`);
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update merchant status');
    }
  };

  // Withdrawal link toggle handler
  const handleToggleWithdrawalLink = async (merchant) => {
    const newVal = !merchant.linkedToWithdrawalSettlement;
    try {
      await updateMerchant(merchant.id, {
        linkedToWithdrawalSettlement: newVal,
      });

      await logAdminAction({
        action: 'MERCHANT_SETTLEMENT_LINK_TOGGLED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: merchant.id,
        targetName: merchant.merchantName,
        reason: `Updated withdrawal settlement linking to ${newVal}`,
        riskLevel: 'MEDIUM',
      });

      setMerchants((prev) =>
        prev.map((m) => (m.id === merchant.id ? { ...m, linkedToWithdrawalSettlement: newVal } : m))
      );
      showFeedback(
        `Withdrawal settlement linking for ${merchant.merchantName} is now ${
          newVal ? 'LINKED' : 'UNLINKED'
        }.`
      );
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to toggle settlement link');
    }
  };

  // Open Edit Modal
  const handleOpenEdit = (merchant) => {
    setEditForm({
      merchantName: merchant.merchantName,
      contactPerson: merchant.contactPerson,
      email: merchant.email,
      userRef: merchant.userRef || '',
    });
    setEditModal(merchant);
  };

  // Save Edit Profile
  const handleSaveEdit = async () => {
    if (!editModal) return;
    try {
      await updateMerchant(editModal.id, {
        companyName: editForm.merchantName,
        merchantName: editForm.merchantName,
        contactPerson: editForm.contactPerson,
        email: editForm.email,
      });

      await logAdminAction({
        action: 'MERCHANT_PROFILE_UPDATED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: editModal.id,
        targetName: editForm.merchantName,
        reason: 'Updated merchant profile information',
        riskLevel: 'MEDIUM',
      });

      setMerchants((prev) =>
        prev.map((m) =>
          m.id === editModal.id
            ? {
                ...m,
                merchantName: editForm.merchantName,
                contactPerson: editForm.contactPerson,
                email: editForm.email,
              }
            : m
        )
      );
      setEditModal(null);
      showFeedback(`Merchant profile updated for ${editForm.merchantName}.`);
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update merchant profile');
    }
  };

  // Save Configuration Limits & Country
  const handleSaveConfig = async () => {
    const { merchant } = configModal;
    if (!merchant) return;

    try {
      await updateMerchant(merchant.id, {
        country: configForm.country,
        dailySettlementLimitUSD: Number(configForm.dailyLimitUSD) || merchant.dailySettlementLimitUSD,
      });

      await logAdminAction({
        action: 'MERCHANT_CONFIG_UPDATED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: merchant.id,
        targetName: merchant.merchantName,
        reason: `Configured country ${configForm.country}, limit $${configForm.dailyLimitUSD}`,
        riskLevel: 'HIGH',
      });

      setMerchants((prev) =>
        prev.map((m) =>
          m.id === merchant.id
            ? {
                ...m,
                country: configForm.country,
                dailySettlementLimitUSD: Number(configForm.dailyLimitUSD) || m.dailySettlementLimitUSD,
                paymentMethods: configForm.paymentMethods
                  .split(',')
                  .map((p) => p.trim())
                  .filter(Boolean),
              }
            : m
        )
      );
      setConfigModal({ open: false, merchant: null });
      showFeedback(`Configuration saved for ${merchant.merchantName}.`);
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to save config');
    }
  };

  // Save Custom Coin Allocation
  const handleSaveAllocation = async () => {
    const { merchant, newAllocation } = allocationModal;
    if (!merchant) return;

    const numAlloc = Number(newAllocation);
    if (isNaN(numAlloc) || numAlloc < 0) {
      alert('Please enter a valid non-negative coin allocation.');
      return;
    }

    try {
      await updateMerchant(merchant.id, {
        monthlyQuotaCoins: numAlloc,
        coinAllocation: numAlloc,
      });

      await logAdminAction({
        action: 'MERCHANT_ALLOCATION_ASSIGNED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: merchant.id,
        targetName: merchant.merchantName,
        reason: `Assigned custom coin allocation of ${numAlloc}`,
        riskLevel: 'HIGH',
      });

      setMerchants((prev) =>
        prev.map((m) =>
          m.id === merchant.id
            ? { ...m, totalCoins: numAlloc, coinAllocation: numAlloc, sellerBalanceCoins: numAlloc }
            : m
        )
      );
      setAllocationModal({ open: false, merchant: null, newAllocation: '' });
      showFeedback(`Coin allocation updated for ${merchant.merchantName}.`);
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update allocation');
    }
  };

  // Execute Dedicated Balance Adjustment
  const handleExecuteDedicatedBalance = async () => {
    const { merchant, amount, type, reason } = balanceModal;
    if (!merchant) return;

    const amtNum = Number(amount);
    if (!amtNum || amtNum <= 0) {
      alert('Please enter a valid positive coin amount.');
      return;
    }

    try {
      await adjustMerchantBalance(merchant.id, {
        amount: amtNum,
        type,
        reason: reason.trim() || `Admin balance adjustment (${type})`,
      });

      await logAdminAction({
        action: 'MERCHANT_BALANCE_ADJUSTED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: merchant.id,
        targetName: merchant.merchantName,
        reason: `Balance adjusted (${type} ${amtNum.toLocaleString()} coins): ${reason}`,
        riskLevel: 'HIGH',
      });

      setBalanceModal({ open: false, merchant: null, amount: '', type: 'CREDIT', reason: '' });
      showFeedback(`Balance adjusted successfully for ${merchant.merchantName}.`);
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to adjust merchant balance');
    }
  };

  // Execute History/Ledger Adjustment
  const handleExecuteMerchantAdjustment = async () => {
    const merchant = historyModal.merchant;
    if (!merchant) return;

    if (!adjustModal.amount || Number(adjustModal.amount) <= 0) {
      alert('Please enter a valid positive coin amount.');
      return;
    }

    const amt = Number(adjustModal.amount);
    const isDeduct = adjustModal.type === 'DEDUCTION';
    const noteReason =
      adjustModal.reason.trim() ||
      (isDeduct ? 'Manual coin deduction correction' : 'Manual coin credit adjustment');

    try {
      await adjustMerchantBalance(merchant.id, {
        amount: amt,
        type: isDeduct ? 'DEBIT' : 'CREDIT',
        reason: noteReason,
      });

      await logAdminAction({
        action: 'MERCHANT_PAYMENT_ADJUSTED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: merchant.id,
        targetName: merchant.merchantName,
        reason: `Manual adjustment (${isDeduct ? 'Deducted' : 'Added'} ${amt} coins): ${noteReason}`,
        riskLevel: 'HIGH',
      });

      await fetchMerchantsData();
      setAdjustModal({ open: false, type: 'DEDUCTION', amount: '', reason: '' });
      setHistoryModal({ open: false, merchant: null });
      showFeedback(`Adjustment of ${amt.toLocaleString()} coins applied to ${merchant.merchantName}.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to apply adjustment');
    }
  };

  // Confirm Delete / Remove Merchant
  const handleConfirmDeleteMerchant = async () => {
    if (!deleteModal.merchant) return;
    const m = deleteModal.merchant;

    try {
      await deleteMerchant(m.id, deleteModal.reason);

      await logAdminAction({
        action: 'MERCHANT_DELETED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: m.id,
        targetName: m.merchantName,
        reason: deleteModal.reason || 'Merchant removed by Super Admin',
        riskLevel: 'CRITICAL',
      });

      setMerchants((prev) => prev.filter((item) => item.id !== m.id));
      setDeleteModal({ open: false, merchant: null, reason: '' });
      showFeedback(`Merchant "${m.merchantName}" successfully removed.`);
      await fetchMerchantsData();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to remove merchant');
    }
  };

  // Add Merchant
  const handleAddMerchant = async () => {
    if (!newForm.merchantName || !newForm.contactPerson || !newForm.email) return;

    try {
      await createMerchant({
        userRef: newForm.userRef,
        username: newForm.userRef,
        companyName: newForm.merchantName,
        merchantName: newForm.merchantName,
        contactPerson: newForm.contactPerson,
        email: newForm.email,
        country: newForm.country || 'US',
        countryCode: newForm.country || 'US',
        initialAllocation: Number(newForm.initialAllocation) || 25200000,
        monthlyQuotaCoins: Number(newForm.initialAllocation) || 25200000,
      });

      await logAdminAction({
        action: 'MERCHANT_ADDED',
        module: 'Merchants',
        targetType: 'merchant',
        targetId: newForm.merchantName,
        targetName: newForm.merchantName,
        reason: `Added merchant with account ref ${newForm.userRef || newForm.merchantName}`,
        riskLevel: 'HIGH',
      });

      await fetchMerchantsData();
      setAddModal(false);
      setNewForm({
        userRef: '',
        merchantName: '',
        contactPerson: '',
        email: '',
        country: 'US',
        initialAllocation: '25200000',
      });
      showFeedback(`New merchant "${newForm.merchantName}" added.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to create merchant');
    }
  };

  const columns = [
    {
      key: 'merchant',
      header: 'Merchant Profile & User Ref',
      render: (row) => (
        <div>
          <p className="text-sm font-bold text-white">{row.merchantName}</p>
          <p className="text-xs text-slate-400">
            Contact: {row.contactPerson} • Ref:{' '}
            <span className="font-mono text-emerald-400">{row.userRef}</span>
          </p>
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
      header: 'Coin Allocation & Balance',
      render: (row) => (
        <div>
          <span className="text-xs font-bold text-yellow-400 font-mono">
            🪙 {formatNumber(row.coinAllocation)}
          </span>
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
        const pct = Math.min(100, Math.round((row.salesThisMonthUSD / (row.targetUSD || 1000)) * 100));
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

          <Tooltip content="Edit Merchant Details">
            <button
              onClick={() => handleOpenEdit(row)}
              className="p-1.5 rounded-lg text-slate-400 hover:text-sky-400 hover:bg-slate-800 transition-colors"
            >
              <Edit className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Manage Balance (Add / Deduct Coins)">
            <button
              onClick={() =>
                setBalanceModal({
                  open: true,
                  merchant: row,
                  amount: '',
                  type: 'CREDIT',
                  reason: '',
                })
              }
              className="p-1.5 rounded-lg text-slate-400 hover:text-gold-400 hover:bg-gold-500/10 transition-colors"
            >
              <Coins className="h-3.5 w-3.5 text-gold-400" />
            </button>
          </Tooltip>

          <Tooltip content="Assign Custom Coin Allocation">
            <button
              onClick={() =>
                setAllocationModal({
                  open: true,
                  merchant: row,
                  newAllocation: String(row.coinAllocation),
                })
              }
              className="p-1.5 rounded-lg text-slate-400 hover:text-amber-400 hover:bg-slate-800 transition-colors"
            >
              <Sliders className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Configure Limits & Payment Methods">
            <button
              onClick={() => {
                setConfigForm({
                  country: row.country,
                  dailyLimitUSD: String(row.dailySettlementLimitUSD),
                  paymentMethods: (row.paymentMethods || []).join(', '),
                });
                setConfigModal({ open: true, merchant: row });
              }}
              className="p-1.5 rounded-lg text-slate-400 hover:text-sky-400 hover:bg-slate-800 transition-colors"
            >
              <CreditCard className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip
            content={
              row.linkedToWithdrawalSettlement
                ? 'Linked to Withdrawal Settlement (Click to toggle)'
                : 'Not Linked to Withdrawal Settlement (Click to toggle)'
            }
          >
            <button
              onClick={() => handleToggleWithdrawalLink(row)}
              className={`p-1.5 rounded-lg transition-colors ${
                row.linkedToWithdrawalSettlement
                  ? 'text-emerald-400 hover:bg-emerald-500/20'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
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
              className={`p-1.5 rounded-lg transition-colors ${
                row.status === 'active'
                  ? 'text-slate-400 hover:text-rose-400 hover:bg-slate-800'
                  : 'text-emerald-400 hover:bg-emerald-500/20'
              }`}
            >
              <Power className="h-3.5 w-3.5" />
            </button>
          </Tooltip>

          <Tooltip content="Remove / Delete Merchant">
            <button
              onClick={() => setDeleteModal({ open: true, merchant: row, reason: '' })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition-colors"
            >
              <Trash2 className="h-3.5 w-3.5" />
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
        <div className="flex items-center gap-2">
          <Button variant="ghost" size="sm" onClick={fetchMerchantsData} disabled={loading}>
            <RefreshCw className={`h-4 w-4 mr-1.5 ${loading ? 'animate-spin' : ''}`} /> Refresh
          </Button>
          <Button variant="primary" size="sm" onClick={() => setAddModal(true)}>
            <Plus className="h-4 w-4 mr-1.5" /> Add Merchant
          </Button>
        </div>
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
            <p className="text-base font-bold text-yellow-400">
              {formatNumber(CURRENT_MERCHANT_POLICY.totalCoins)}
            </p>
          </div>
          <div className="p-2.5 rounded-lg bg-slate-900/80 border border-slate-700/60">
            <p className="text-slate-400">Min Target</p>
            <p className="text-base font-bold text-white">
              ${CURRENT_MERCHANT_POLICY.monthlySalesTargetUSD}
            </p>
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
          <span className="text-xs text-slate-400">Filter Country:</span>
          <CountrySelect
            value={selectedCountry}
            onChange={setSelectedCountry}
            allowAll={true}
            className="w-40"
          />
        </div>
      </Card>

      <DataTable
        columns={columns}
        data={filtered}
        isLoading={loading}
        emptyMessage="No merchants found matching your query."
      />

      {/* Edit Merchant Profile Modal */}
      {editModal && (
        <Modal
          isOpen={true}
          onClose={() => setEditModal(null)}
          title={`Edit Merchant: ${editModal.merchantName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Merchant / Company Name *"
              value={editForm.merchantName}
              onChange={(e) => setEditForm({ ...editForm, merchantName: e.target.value })}
              placeholder="e.g. Global Pay Ltd"
            />
            <Input
              label="Contact Person Name *"
              value={editForm.contactPerson}
              onChange={(e) => setEditForm({ ...editForm, contactPerson: e.target.value })}
              placeholder="e.g. Marcus Vance"
            />
            <Input
              label="Email Address *"
              value={editForm.email}
              onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
              placeholder="e.g. contact@globalpay.com"
            />
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button variant="ghost" size="sm" onClick={() => setEditModal(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveEdit}>
                Save Changes
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Manage Merchant Balance Modal */}
      {balanceModal.open && (
        <Modal
          isOpen={true}
          onClose={() =>
            setBalanceModal({ open: false, merchant: null, amount: '', type: 'CREDIT', reason: '' })
          }
          title={`Manage Balance: ${balanceModal.merchant?.merchantName}`}
          size="md"
        >
          <div className="space-y-4 text-xs text-slate-300">
            {/* Current Balance Banner */}
            <div className="p-3.5 bg-slate-900 border border-slate-800 rounded-xl flex items-center justify-between">
              <div>
                <p className="text-slate-400 text-xs">Current Merchant Allocation</p>
                <p className="text-lg font-bold text-yellow-400 font-mono flex items-center gap-1.5">
                  <Coins className="h-4 w-4" />
                  {formatNumber(
                    balanceModal.merchant?.coinAllocation || balanceModal.merchant?.totalCoins || 0
                  )}{' '}
                  coins
                </p>
              </div>
              <div className="text-right">
                <p className="text-slate-400 text-xs">Wallet Seller Balance</p>
                <p className="text-base font-bold text-emerald-400 font-mono">
                  {formatNumber(
                    balanceModal.merchant?.sellerBalanceCoins ||
                      balanceModal.merchant?.coinAllocation ||
                      0
                  )}{' '}
                  coins
                </p>
              </div>
            </div>

            {/* Operation Type Selection */}
            <div>
              <label className="block text-xs text-slate-300 font-semibold mb-1.5">
                Balance Operation Type
              </label>
              <div className="grid grid-cols-3 gap-2">
                <button
                  type="button"
                  onClick={() => setBalanceModal({ ...balanceModal, type: 'CREDIT' })}
                  className={`py-2 px-3 rounded-lg text-xs font-bold border transition-all text-center ${
                    balanceModal.type === 'CREDIT'
                      ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-400 shadow-sm'
                      : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
                  }`}
                >
                  + Add Coins (Credit)
                </button>
                <button
                  type="button"
                  onClick={() => setBalanceModal({ ...balanceModal, type: 'DEBIT' })}
                  className={`py-2 px-3 rounded-lg text-xs font-bold border transition-all text-center ${
                    balanceModal.type === 'DEBIT'
                      ? 'bg-rose-500/20 border-rose-500/50 text-rose-400 shadow-sm'
                      : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
                  }`}
                >
                  - Deduct Coins (Debit)
                </button>
                <button
                  type="button"
                  onClick={() => setBalanceModal({ ...balanceModal, type: 'SET' })}
                  className={`py-2 px-3 rounded-lg text-xs font-bold border transition-all text-center ${
                    balanceModal.type === 'SET'
                      ? 'bg-sky-500/20 border-sky-500/50 text-sky-400 shadow-sm'
                      : 'bg-slate-900 border-slate-700 text-slate-400 hover:text-white'
                  }`}
                >
                  = Set Exact Balance
                </button>
              </div>
            </div>

            {/* Quick Preset Buttons */}
            <div>
              <label className="block text-[11px] text-slate-400 mb-1">Quick Presets</label>
              <div className="flex flex-wrap gap-1.5">
                {[500000, 1000000, 5000000, 10000000, 25200000].map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => setBalanceModal({ ...balanceModal, amount: String(preset) })}
                    className="px-2.5 py-1 rounded-md bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white text-[11px] font-mono border border-slate-700 transition-colors"
                  >
                    +{formatNumber(preset)}
                  </button>
                ))}
              </div>
            </div>

            {/* Amount Input */}
            <Input
              label="Coin Amount *"
              type="number"
              value={balanceModal.amount}
              onChange={(e) => setBalanceModal({ ...balanceModal, amount: e.target.value })}
              placeholder="e.g. 1000000"
            />

            {/* Live Calculation Preview */}
            {balanceModal.amount && Number(balanceModal.amount) > 0 && (
              <div className="p-2.5 bg-slate-950 border border-slate-800 rounded-lg text-xs flex justify-between items-center font-mono">
                <span className="text-slate-400">Estimated New Allocation:</span>
                <span className="font-bold text-white">
                  {balanceModal.type === 'CREDIT' && (
                    <span className="text-emerald-400">
                      {formatNumber(
                        (balanceModal.merchant?.coinAllocation || 0) + Number(balanceModal.amount)
                      )}{' '}
                      coins
                    </span>
                  )}
                  {balanceModal.type === 'DEBIT' && (
                    <span className="text-rose-400">
                      {formatNumber(
                        Math.max(
                          0,
                          (balanceModal.merchant?.coinAllocation || 0) - Number(balanceModal.amount)
                        )
                      )}{' '}
                      coins
                    </span>
                  )}
                  {balanceModal.type === 'SET' && (
                    <span className="text-sky-400">
                      {formatNumber(Number(balanceModal.amount))} coins
                    </span>
                  )}
                </span>
              </div>
            )}

            {/* Reason */}
            <Input
              label="Audit Note / Reason *"
              value={balanceModal.reason}
              onChange={(e) => setBalanceModal({ ...balanceModal, reason: e.target.value })}
              placeholder="e.g. Monthly allocation top-up or manual settlement correction"
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() =>
                  setBalanceModal({ open: false, merchant: null, amount: '', type: 'CREDIT', reason: '' })
                }
              >
                Cancel
              </Button>
              <Button
                variant={balanceModal.type === 'DEBIT' ? 'danger' : 'primary'}
                size="sm"
                onClick={handleExecuteDedicatedBalance}
              >
                Apply Balance Adjustment
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Delete / Remove Merchant Confirmation Modal */}
      {deleteModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setDeleteModal({ open: false, merchant: null, reason: '' })}
          title={`Remove Merchant: ${deleteModal.merchant?.merchantName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3.5 bg-rose-950/30 border border-rose-500/40 rounded-xl space-y-2">
              <div className="flex items-center gap-2 text-rose-400 font-bold text-sm">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>Confirm Merchant Removal</span>
              </div>
              <p className="text-xs text-slate-300">
                Are you sure you want to remove{' '}
                <strong className="text-white">{deleteModal.merchant?.merchantName}</strong>?
              </p>
              <ul className="list-disc pl-4 text-slate-400 space-y-1 text-[11px]">
                <li>Merchant privileges & API credentials will be revoked immediately.</li>
                <li>
                  The user account (
                  <span className="text-slate-200">
                    {deleteModal.merchant?.email || deleteModal.merchant?.userRef}
                  </span>
                  ) will revert to a standard user.
                </li>
                <li>All action details will be permanently written to the Super Admin audit log.</li>
              </ul>
            </div>

            <Input
              label="Reason for Removal (Optional)"
              value={deleteModal.reason}
              onChange={(e) => setDeleteModal({ ...deleteModal, reason: e.target.value })}
              placeholder="e.g. Inactivity, contract termination, or policy breach"
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setDeleteModal({ open: false, merchant: null, reason: '' })}
              >
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={handleConfirmDeleteMerchant}>
                Permanently Remove Merchant
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Add Merchant Modal */}
      {addModal && (
        <Modal isOpen={true} onClose={() => setAddModal(false)} title="Add New Merchant" size="md">
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Existing User ID or Username (Optional Ref)"
              value={newForm.userRef}
              onChange={(e) => setNewForm({ ...newForm, userRef: e.target.value })}
              placeholder="e.g. usr_123 or leave blank to auto-create user"
            />
            <Input
              label="Merchant / Company Name *"
              value={newForm.merchantName}
              onChange={(e) => setNewForm({ ...newForm, merchantName: e.target.value })}
              placeholder="e.g. Global Pay Ltd"
            />
            <Input
              label="Contact Person Name *"
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
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button variant="ghost" size="sm" onClick={() => setAddModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleAddMerchant}>
                Create Merchant
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* View Merchant Profile Modal */}
      {selectedMerchant && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedMerchant(null)}
          title={`Merchant Profile: ${selectedMerchant.merchantName}`}
          size="md"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-base font-bold text-white">{selectedMerchant.merchantName}</span>
                <StatusBadge status={selectedMerchant.status} />
              </div>
              <p>
                <strong>Account Reference:</strong>{' '}
                <span className="font-mono text-emerald-400">{selectedMerchant.userRef}</span>
              </p>
              <p>
                <strong>Contact Person:</strong> {selectedMerchant.contactPerson} (
                {selectedMerchant.email})
              </p>
              <p>
                <strong>Country:</strong> {getCountryShortName(selectedMerchant.country)} (
                {selectedMerchant.country})
              </p>
              <p>
                <strong>Coin Allocation:</strong>{' '}
                <span className="text-yellow-400 font-bold font-mono">
                  🪙 {formatNumber(selectedMerchant.coinAllocation)}
                </span>
              </p>
              <p>
                <strong>Wallet Seller Balance:</strong>{' '}
                <span className="text-emerald-400 font-bold font-mono">
                  🪙 {formatNumber(selectedMerchant.sellerBalanceCoins || selectedMerchant.coinAllocation)}
                </span>
              </p>
              <p>
                <strong>Daily Settlement Limit:</strong> ${selectedMerchant.dailySettlementLimitUSD} USD
              </p>
              <p>
                <strong>Supported Payment Methods:</strong>{' '}
                {(selectedMerchant.paymentMethods || []).join(', ')}
              </p>
              <p>
                <strong>Withdrawal Settlement Link:</strong>{' '}
                <span className="text-emerald-400 font-bold">
                  {selectedMerchant.linkedToWithdrawalSettlement ? 'LINKED' : 'NOT LINKED'}
                </span>
              </p>
              <p>
                <strong>Sales This Month:</strong> ${selectedMerchant.salesThisMonthUSD} / $
                {selectedMerchant.targetUSD}
              </p>
            </div>
            <div className="flex justify-between items-center pt-2 border-t border-slate-800">
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  const m = selectedMerchant;
                  setSelectedMerchant(null);
                  handleOpenEdit(m);
                }}
              >
                <Edit className="h-3.5 w-3.5 mr-1.5" /> Edit Profile
              </Button>
              <Button variant="ghost" size="sm" onClick={() => setSelectedMerchant(null)}>
                Close Profile
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Assign Custom Coin Allocation Modal */}
      {allocationModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setAllocationModal({ open: false, merchant: null, newAllocation: '' })}
          title={`Assign Coin Allocation: ${allocationModal.merchant?.merchantName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Custom Coin Allocation Amount *"
              type="number"
              value={allocationModal.newAllocation}
              onChange={(e) =>
                setAllocationModal({ ...allocationModal, newAllocation: e.target.value })
              }
              placeholder="e.g. 25200000"
            />
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setAllocationModal({ open: false, merchant: null, newAllocation: '' })}
              >
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveAllocation}>
                Assign Allocation
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Configure Country, Payment Methods & Settlement Limits Modal */}
      {configModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setConfigModal({ open: false, merchant: null })}
          title={`Configure Limits & Country: ${configModal.merchant?.merchantName}`}
          size="sm"
        >
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
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setConfigModal({ open: false, merchant: null })}
              >
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveConfig}>
                Save Configuration
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Transaction & Correction History Modal */}
      {historyModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setHistoryModal({ open: false, merchant: null })}
          title={`Merchant Corrections & Transaction History: ${historyModal.merchant?.merchantName}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 bg-slate-900 border border-slate-800 rounded-xl space-y-3">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-bold text-white text-base">
                      {historyModal.merchant?.merchantName}
                    </p>
                    <Badge variant="warning">Audit Logged</Badge>
                  </div>
                  <p className="text-xs text-slate-400 mt-1">
                    Ref: {historyModal.merchant?.userRef}
                  </p>
                </div>

                <Button
                  variant="danger"
                  size="sm"
                  className="shrink-0 whitespace-nowrap"
                  onClick={() =>
                    setAdjustModal({ open: true, type: 'DEDUCTION', amount: '', reason: '' })
                  }
                >
                  Adjust Payment / Deduct Coins
                </Button>
              </div>

              <div className="bg-slate-950 px-3 py-2 rounded-lg border border-slate-800 text-xs font-mono text-slate-400">
                Current Coin Allocation:{' '}
                <strong className="text-emerald-400 font-mono ml-1">
                  {formatNumber(historyModal.merchant?.coinAllocation)} coins
                </strong>
              </div>
            </div>

            {/* Adjust Payment Inline Form */}
            {adjustModal.open && (
              <div className="p-3.5 bg-slate-950 border border-rose-500/30 rounded-xl space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-white text-xs">
                    Manual Payment / Coin Adjustment
                  </span>
                  <button
                    onClick={() =>
                      setAdjustModal({ open: false, type: 'DEDUCTION', amount: '', reason: '' })
                    }
                    className="text-slate-400 hover:text-white text-xs font-bold"
                  >
                    Cancel
                  </button>
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-[11px] text-slate-400 font-semibold mb-1">
                      Adjustment Action
                    </label>
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
                <div
                  key={i}
                  className="p-2.5 bg-slate-900/80 border border-slate-800 rounded-lg flex justify-between items-center"
                >
                  <div>
                    <span
                      className={`font-bold ${
                        h.type?.includes('DEDUCTION') ? 'text-rose-400' : 'text-emerald-400'
                      }`}
                    >
                      {h.type}
                    </span>
                    <p className="text-slate-300 text-[11px] mt-0.5">{h.details}</p>
                    <p className="text-slate-500 text-[10px]">{h.date}</p>
                  </div>
                </div>
              ))}
            </div>
            <div className="flex justify-end pt-2 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setHistoryModal({ open: false, merchant: null })}
              >
                Close Ledger
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}

export default MerchantsPage;
