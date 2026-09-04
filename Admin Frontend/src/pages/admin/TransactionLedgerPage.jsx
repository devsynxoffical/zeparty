// ============================================================
// ZeParty Admin Portal — Transaction Ledger & Coin Discount Report Page (JSX)
// 2026 Developer Specification Alignment + Auto-Calculated Reports
// ============================================================

import React, { useState, useMemo } from 'react';
import {
  Layers,
  Search,
  ArrowRightLeft,
  ShieldCheck,
  FileText,
  Eye,
  Filter,
  RefreshCw,
  AlertTriangle,
  ArrowRight,
  Link,
  Calendar,
  Download,
  DollarSign,
  Coins,
  CheckCircle,
  Percent,
  TrendingUp,
  UserCheck,
  Building2,
  Store,
  ChevronDown,
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { MOCK_LEDGER_CHAIN } from '../../mocks/transactionLedger.mock';
import { formatNumber, formatDate, formatCurrency } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

// Additional Coin Sellers & Merchants Coin Allocation Mock Transactions
const INITIAL_COIN_SALES = [
  {
    txnId: 'TXN-CS-801',
    timestamp: '2026-08-28T14:20:00.000Z',
    type: 'COINS',
    entityType: 'SELLER',
    entityName: 'CoinMaster Pro',
    username: '@coinmaster_pro',
    userRef: 'usr-8812',
    packageTier: '$1,000 Reseller Tier',
    coinsDelivered: 7700000,
    grossAmountUSD: 1000.0,
    discountPercent: 10, // 10% Discount
    netAmountUSD: 900.0,
    discountSavingsUSD: 100.0,
    grossAmountPKR: 280000,
    netAmountPKR: 252000,
    discountSavingsPKR: 28000,
    paymentMethod: 'Bank Wire Transfer (HBL)',
    status: 'SUCCESS',
    chainId: 'CHAIN-COIN-001',
    operator: 'Super Admin',
  },
  {
    txnId: 'TXN-CS-802',
    timestamp: '2026-08-25T11:10:00.000Z',
    type: 'COINS',
    entityType: 'SELLER',
    entityName: 'Apex Global Distribution',
    username: '@apex_dist',
    userRef: 'usr-9012',
    packageTier: '$500 Reseller Tier',
    coinsDelivered: 3675000,
    grossAmountUSD: 500.0,
    discountPercent: 5, // 5% Discount
    netAmountUSD: 475.0,
    discountSavingsUSD: 25.0,
    grossAmountPKR: 140000,
    netAmountPKR: 133000,
    discountSavingsPKR: 7000,
    paymentMethod: 'USDT (TRC20)',
    status: 'SUCCESS',
    chainId: 'CHAIN-COIN-002',
    operator: 'Finance Admin',
  },
  {
    txnId: 'TXN-MC-901',
    timestamp: '2026-08-20T09:45:00.000Z',
    type: 'COINS',
    entityType: 'MERCHANT',
    entityName: 'SilkRoad Pay Enterprise',
    username: '@silkroad_pay',
    userRef: 'usr-7741',
    packageTier: '$3,000 Merchant Enterprise',
    coinsDelivered: 25200000,
    grossAmountUSD: 3000.0,
    discountPercent: 16, // 16% Discount
    netAmountUSD: 2520.0,
    discountSavingsUSD: 480.0,
    grossAmountPKR: 840000,
    netAmountPKR: 705600,
    discountSavingsPKR: 134400,
    paymentMethod: 'Bank Wire Transfer (Mezan Bank)',
    status: 'SUCCESS',
    chainId: 'CHAIN-COIN-003',
    operator: 'Root Owner',
  },
  {
    txnId: 'TXN-CS-803',
    timestamp: '2026-08-15T16:30:00.000Z',
    type: 'COINS',
    entityType: 'SELLER',
    entityName: 'Desert Eagle Pay AE',
    username: '@desert_eagle',
    userRef: 'usr-3319',
    packageTier: '$300 Reseller Tier',
    coinsDelivered: 2205000,
    grossAmountUSD: 300.0,
    discountPercent: 5,
    netAmountUSD: 285.0,
    discountSavingsUSD: 15.0,
    grossAmountPKR: 84000,
    netAmountPKR: 79800,
    discountSavingsPKR: 4200,
    paymentMethod: 'Local E-Wallet',
    status: 'SUCCESS',
    chainId: 'CHAIN-COIN-004',
    operator: 'Finance Admin',
  },
  {
    txnId: 'TXN-MC-902',
    timestamp: '2026-08-10T12:00:00.000Z',
    type: 'COINS',
    entityType: 'MERCHANT',
    entityName: 'NovaPay Solutions Global',
    username: '@novapay_io',
    userRef: 'usr-5521',
    packageTier: '$3,000 Merchant Enterprise',
    coinsDelivered: 25200000,
    grossAmountUSD: 3000.0,
    discountPercent: 15,
    netAmountUSD: 2550.0,
    discountSavingsUSD: 450.0,
    grossAmountPKR: 840000,
    netAmountPKR: 714000,
    discountSavingsPKR: 126000,
    paymentMethod: 'USDT (TRC20)',
    status: 'SUCCESS',
    chainId: 'CHAIN-COIN-005',
    operator: 'Super Admin',
  },
];

export function TransactionLedgerPage() {
  const { logAdminAction } = useAuditLog();

  // Primary Tab: 'ledger' | 'reports'
  const [activeView, setActiveView] = useState('ledger');

  // Ledger state
  const [ledger, setLedger] = useState(
    MOCK_LEDGER_CHAIN.map((tx) => ({
      ...tx,
      sellerId: tx.sellerId || null,
      merchantId: tx.merchantId || null,
      withdrawalId: tx.withdrawalId || null,
      rate: tx.rate || '10,000/$1',
      operator: tx.operator || 'System Automated',
      linkedRecords: tx.relatedTxnIds || [],
    }))
  );

  const [coinSales, setCoinSales] = useState(INITIAL_COIN_SALES);

  // Filters
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('ALL');
  const [coinsToggle, setCoinsToggle] = useState('SELLER'); // 'SELLER' | 'MERCHANT'

  // Report Period & Target Filters
  const [timePreset, setTimePreset] = useState('ALL_TIME'); // 'TODAY' | 'WEEK' | 'MONTH' | 'YEAR' | 'ALL_TIME' | 'CUSTOM'
  const [customStartDate, setCustomStartDate] = useState('');
  const [customEndDate, setCustomEndDate] = useState('');
  const [reportTargetFilter, setReportTargetFilter] = useState('ALL'); // 'ALL' | 'SELLER' | 'MERCHANT'
  const [currencyUnit, setCurrencyUnit] = useState('USD'); // 'USD' | 'PKR'

  // Modals
  const [inspectTx, setInspectTx] = useState(null);
  const [reversalModal, setReversalModal] = useState({ open: false, txn: null, reason: '', reversalAmountUSD: '' });
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  // Filtered Ledger Chain
  const filteredLedger = useMemo(() => {
    const q = search.toLowerCase();

    if (typeFilter === 'COINS') {
      return coinSales
        .filter((item) => item.entityType === coinsToggle)
        .filter((item) => {
          return (
            !q ||
            item.txnId.toLowerCase().includes(q) ||
            item.entityName.toLowerCase().includes(q) ||
            item.username.toLowerCase().includes(q) ||
            item.chainId.toLowerCase().includes(q)
          );
        })
        .map((item) => ({
          txnId: item.txnId,
          timestamp: item.timestamp,
          type: `COIN_${item.entityType}`,
          user: item.entityName,
          source: item.paymentMethod,
          destination: `${item.entityName} (${item.packageTier})`,
          amountUSD: item.netAmountUSD,
          coinsAdded: item.coinsDelivered,
          status: item.status,
          chainId: item.chainId,
          operator: item.operator,
          linkedRecords: [item.chainId],
          isCoinSale: true,
          saleData: item,
        }));
    }

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
  }, [search, typeFilter, coinsToggle, ledger, coinSales]);

  // Execute Reversal Action
  const handleCreateReversal = async () => {
    const { txn, reason, reversalAmountUSD } = reversalModal;
    if (!txn || !reason) return;

    const amt = Number(reversalAmountUSD) || Math.abs(txn.amountUSD || 0);
    const reversalTxId = `TXN-REV-${Math.floor(100000 + Math.random() * 900000)}`;

    const adjustmentRecord = {
      txnId: reversalTxId,
      timestamp: new Date().toISOString(),
      type: 'REVERSAL_ADJUSTMENT',
      user: txn.user || 'System',
      userId: txn.userId || null,
      source: txn.destination || 'System Vault',
      destination: txn.source || 'Adjustment Pool',
      amountUSD: -amt,
      coinsAdded: txn.coinsSpent ? txn.coinsSpent : 0,
      coinsSpent: txn.coinsAdded ? txn.coinsAdded : 0,
      status: 'SUCCESS',
      chainId: txn.chainId || 'CHAIN-REV',
      relatedTxnIds: [txn.txnId],
      linkedRecords: [txn.txnId],
      rate: txn.rate || '1:1',
      operator: 'Finance Admin',
      note: `Reversal Correction: ${reason}`,
    };

    // Mark original transaction status as REVERSED
    setLedger((prev) =>
      prev.map((t) => (t.txnId === txn.txnId ? { ...t, status: 'REVERSED', note: `Reversed via ${reversalTxId}` } : t))
    );

    // Append reversal adjustment record
    setLedger((prev) => [adjustmentRecord, ...prev]);

    await logAdminAction({
      action: 'LEDGER_TXN_REVERSED',
      module: 'Ledger',
      targetType: 'transaction',
      targetId: txn.txnId,
      targetName: txn.txnId,
      reason: `Reversal executed: ${reason} (Amount: -$${amt})`,
      riskLevel: 'HIGH',
      afterValue: { reversalTxId },
    });

    showFeedback(`Reversal transaction ${reversalTxId} successfully posted to ledger!`);
    setReversalModal({ open: false, txn: null, reason: '', reversalAmountUSD: '' });
  };

  // Filtered Auto-Calculated Coin Discount Report Records
  const filteredReportRecords = useMemo(() => {
    const now = new Date();

    return coinSales.filter((item) => {
      // 1. Target Filter (All / Seller / Merchant)
      if (reportTargetFilter !== 'ALL' && item.entityType !== reportTargetFilter) {
        return false;
      }

      // 2. Search Query
      if (search) {
        const q = search.toLowerCase();
        const match =
          item.txnId.toLowerCase().includes(q) ||
          item.entityName.toLowerCase().includes(q) ||
          item.username.toLowerCase().includes(q) ||
          item.userRef.toLowerCase().includes(q);
        if (!match) return false;
      }

      // 3. Time Preset Filter
      const txDate = new Date(item.timestamp);
      if (timePreset === 'TODAY') {
        const isToday =
          txDate.getDate() === now.getDate() &&
          txDate.getMonth() === now.getMonth() &&
          txDate.getFullYear() === now.getFullYear();
        if (!isToday) return false;
      } else if (timePreset === 'WEEK') {
        const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        if (txDate < oneWeekAgo) return false;
      } else if (timePreset === 'MONTH') {
        const isThisMonth = txDate.getMonth() === now.getMonth() && txDate.getFullYear() === now.getFullYear();
        if (!isThisMonth) return false;
      } else if (timePreset === 'YEAR') {
        const isThisYear = txDate.getFullYear() === now.getFullYear();
        if (!isThisYear) return false;
      } else if (timePreset === 'CUSTOM') {
        if (customStartDate) {
          const start = new Date(customStartDate);
          if (txDate < start) return false;
        }
        if (customEndDate) {
          const end = new Date(customEndDate);
          end.setHours(23, 59, 59, 999);
          if (txDate > end) return false;
        }
      }

      return true;
    });
  }, [coinSales, reportTargetFilter, timePreset, customStartDate, customEndDate, search]);

  // Grand Totals Calculations
  const reportTotals = useMemo(() => {
    return filteredReportRecords.reduce(
      (acc, curr) => {
        acc.count += 1;
        acc.totalCoins += curr.coinsDelivered || 0;
        acc.totalGrossUSD += curr.grossAmountUSD || 0;
        acc.totalNetUSD += curr.netAmountUSD || 0;
        acc.totalDiscountUSD += curr.discountSavingsUSD || 0;
        acc.totalGrossPKR += curr.grossAmountPKR || 0;
        acc.totalNetPKR += curr.netAmountPKR || 0;
        acc.totalDiscountPKR += curr.discountSavingsPKR || 0;
        return acc;
      },
      {
        count: 0,
        totalCoins: 0,
        totalGrossUSD: 0,
        totalNetUSD: 0,
        totalDiscountUSD: 0,
        totalGrossPKR: 0,
        totalNetPKR: 0,
        totalDiscountPKR: 0,
      }
    );
  }, [filteredReportRecords]);

  // Ledger Table Columns
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
        if (row.type === 'REVERSAL_ADJUSTMENT' || row.status === 'REVERSED') variant = 'danger';
        if (row.type === 'RECHARGE' || row.type.includes('COIN')) variant = 'success';
        if (row.type === 'HOST_EARNING') variant = 'info';
        return <Badge variant={variant}>{row.type}</Badge>;
      },
    },
    {
      key: 'flow',
      header: 'Source → Destination',
      render: (row) => (
        <div className="flex items-center gap-1 text-[11px] text-slate-300">
          <span className="truncate max-w-[120px]">{row.source}</span>
          <ArrowRight className="h-3 w-3 text-gold-400 shrink-0" />
          <span className="truncate max-w-[140px] font-semibold text-white">{row.destination}</span>
        </div>
      ),
    },
    {
      key: 'value',
      header: 'Ledger Balances & Values',
      render: (row) => (
        <div className="font-mono text-xs">
          {row.amountUSD !== undefined && (
            <p className={`font-bold ${row.amountUSD >= 0 ? 'text-emerald-400' : 'text-rose-400'}`}>
              {row.amountUSD >= 0 ? '+' : ''}${Math.abs(row.amountUSD).toFixed(2)} USD
            </p>
          )}
          {row.coinsAdded > 0 && <p className="text-yellow-400 font-bold">🪙 +{formatNumber(row.coinsAdded)}</p>}
          {row.coinsSpent > 0 && <p className="text-red-400 font-bold">🪙 -{formatNumber(row.coinsSpent)}</p>}
          {row.saleData && (
            <span className="inline-block mt-0.5 px-1.5 py-0.5 rounded text-[10px] bg-gold-500/20 text-gold-300 font-sans">
              Discount: {row.saleData.discountPercent}% OFF
            </span>
          )}
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
      render: (row) => <span className="text-xs text-slate-300 font-medium">{row.operator}</span>,
    },
    {
      key: 'actions',
      header: 'Audits',
      render: (row) => (
        <div className="flex items-center gap-1.5">
          <Button variant="outline" size="xs" onClick={() => setInspectTx(row)}>
            Trace
          </Button>
          {row.type !== 'REVERSAL_ADJUSTMENT' && row.status !== 'REVERSED' && (
            <Button
              variant="danger"
              size="xs"
              onClick={() =>
                setReversalModal({
                  open: true,
                  txn: row,
                  reason: '',
                  reversalAmountUSD: Math.abs(row.amountUSD || 0),
                })
              }
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
      {/* Header View Switcher */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800 pb-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Layers className="h-6 w-6 text-gold-400" />
            Transaction Ledger & Coin Reports
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            End-to-end ledger auditing, reversal corrections, and auto-calculated coin discount reports over custom time windows.
          </p>
        </div>

        {/* Primary View Tabs */}
        <div className="flex items-center gap-2 bg-slate-900 p-1 rounded-xl border border-slate-800 shrink-0">
          <button
            onClick={() => setActiveView('ledger')}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${
              activeView === 'ledger'
                ? 'bg-gold-500 text-slate-950 shadow-lg'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            Ledger Stream Chain
          </button>
          <button
            onClick={() => setActiveView('reports')}
            className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              activeView === 'reports'
                ? 'bg-gold-500 text-slate-950 shadow-lg'
                : 'text-slate-400 hover:text-white hover:bg-slate-800/50'
            }`}
          >
            <Percent className="h-3.5 w-3.5" />
            Coin Discount & Revenue Report
          </button>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* ============================================================ */}
      {/* VIEW 1: IMMUTABLE TRANSACTION LEDGER STREAM                 */}
      {/* ============================================================ */}
      {activeView === 'ledger' && (
        <>
          {/* Ecosystem Flow Chain Map */}
          <Card className="p-4 bg-slate-900 border border-slate-800">
            <p className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
              Ecosystem Transaction Flow Chain Map
            </p>
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

          {/* Search & Select Filter Bar */}
          <Card className="p-4 flex flex-col sm:flex-row gap-3 items-center">
            <Input
              placeholder="Search by Txn ID, Chain ID, User ID, Reseller or Merchant..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              leftIcon={Search}
              containerClassName="flex-1 w-full"
            />

            {/* Type Filter Select — Styled with dark background on options (Fixing Screenshot 2) */}
            <div className="flex items-center gap-2 border border-slate-700 bg-slate-900 rounded-lg px-2 py-1 shrink-0 w-full sm:w-auto">
              <Filter className="h-4 w-4 text-slate-400 shrink-0" />
              <select
                className="bg-slate-900 text-slate-100 text-xs font-semibold py-1.5 pr-6 outline-none cursor-pointer rounded"
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
              >
                <option value="ALL" className="bg-slate-900 text-slate-100 font-sans py-1">
                  All Transaction Types
                </option>
                <option value="COINS" className="bg-slate-900 text-gold-400 font-bold py-1">
                  🪙 Coins (Resellers & Merchants)
                </option>
                <option value="RECHARGE" className="bg-slate-900 text-slate-100 font-sans py-1">
                  User Recharge
                </option>
                <option value="GIFT_SEND" className="bg-slate-900 text-slate-100 font-sans py-1">
                  Gift Send
                </option>
                <option value="AGENCY_COMMISSION" className="bg-slate-900 text-slate-100 font-sans py-1">
                  Agency Commission
                </option>
                <option value="HOST_EARNING" className="bg-slate-900 text-slate-100 font-sans py-1">
                  Host Earning
                </option>
                <option value="WITHDRAWAL_REQUEST" className="bg-slate-900 text-slate-100 font-sans py-1">
                  Withdrawal Request
                </option>
                <option value="REVERSAL_ADJUSTMENT" className="bg-slate-900 text-slate-100 font-sans py-1">
                  Reversal Adjustment
                </option>
              </select>
            </div>

            {/* Sellers vs Merchants Toggle Switch (Rendered when COINS filter active) */}
            {typeFilter === 'COINS' && (
              <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-lg border border-slate-800 shrink-0">
                <button
                  onClick={() => setCoinsToggle('SELLER')}
                  className={`px-2.5 py-1 rounded text-xs font-bold flex items-center gap-1 transition-all ${
                    coinsToggle === 'SELLER'
                      ? 'bg-gold-500 text-slate-950 shadow'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  <Store className="h-3.5 w-3.5" />
                  Coin Sellers
                </button>
                <button
                  onClick={() => setCoinsToggle('MERCHANT')}
                  className={`px-2.5 py-1 rounded text-xs font-bold flex items-center gap-1 transition-all ${
                    coinsToggle === 'MERCHANT'
                      ? 'bg-gold-500 text-slate-950 shadow'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  <Building2 className="h-3.5 w-3.5" />
                  Merchants
                </button>
              </div>
            )}
          </Card>

          <DataTable columns={columns} data={filteredLedger} isLoading={false} />
        </>
      )}

      {/* ============================================================ */}
      {/* VIEW 2: AUTO-CALCULATED COIN DISCOUNT & REVENUE REPORT SYSTEM */}
      {/* ============================================================ */}
      {activeView === 'reports' && (
        <div className="space-y-6">
          {/* Controls & Filter Bar */}
          <Card className="p-4 space-y-4 bg-slate-900 border border-slate-800">
            <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
              <div>
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  <Calendar className="h-4 w-4 text-gold-400" />
                  Select Report Time Period & Target Entity
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Auto-calculates gross standard value, discounted net prices, and total coins delivered.
                </p>
              </div>

              {/* Currency & Export controls */}
              <div className="flex items-center gap-2">
                <div className="flex items-center bg-slate-950 p-1 rounded-lg border border-slate-800">
                  <button
                    onClick={() => setCurrencyUnit('USD')}
                    className={`px-2.5 py-1 rounded text-xs font-bold ${
                      currencyUnit === 'USD' ? 'bg-slate-800 text-gold-400' : 'text-slate-400'
                    }`}
                  >
                    USD ($)
                  </button>
                  <button
                    onClick={() => setCurrencyUnit('PKR')}
                    className={`px-2.5 py-1 rounded text-xs font-bold ${
                      currencyUnit === 'PKR' ? 'bg-slate-800 text-gold-400' : 'text-slate-400'
                    }`}
                  >
                    PKR (Rs)
                  </button>
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  leftIcon={Download}
                  onClick={() => window.print()}
                >
                  Print / Export Report
                </Button>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-4 gap-3 pt-2 border-t border-slate-800">
              {/* Preset Time Range */}
              <div>
                <label className="block text-[11px] text-slate-400 font-semibold mb-1">Time Period</label>
                <select
                  className="w-full bg-slate-950 border border-slate-700 text-slate-100 rounded-lg px-3 py-2 text-xs font-medium cursor-pointer"
                  value={timePreset}
                  onChange={(e) => setTimePreset(e.target.value)}
                >
                  <option value="ALL_TIME" className="bg-slate-900 text-slate-100">All Time Records</option>
                  <option value="TODAY" className="bg-slate-900 text-slate-100">Today (24h)</option>
                  <option value="WEEK" className="bg-slate-900 text-slate-100">This Week (Last 7 Days)</option>
                  <option value="MONTH" className="bg-slate-900 text-slate-100">This Month</option>
                  <option value="YEAR" className="bg-slate-900 text-slate-100">This Year</option>
                  <option value="CUSTOM" className="bg-slate-900 text-slate-100">Custom Date Range...</option>
                </select>
              </div>

              {/* Target Entity */}
              <div>
                <label className="block text-[11px] text-slate-400 font-semibold mb-1">Target Entity</label>
                <select
                  className="w-full bg-slate-950 border border-slate-700 text-slate-100 rounded-lg px-3 py-2 text-xs font-medium cursor-pointer"
                  value={reportTargetFilter}
                  onChange={(e) => setReportTargetFilter(e.target.value)}
                >
                  <option value="ALL" className="bg-slate-900 text-slate-100">All Entities (Sellers & Merchants)</option>
                  <option value="SELLER" className="bg-slate-900 text-slate-100">Coin Sellers Only</option>
                  <option value="MERCHANT" className="bg-slate-900 text-slate-100">Merchants Only</option>
                </select>
              </div>

              {/* Custom Date Pickers (Shown if CUSTOM selected) */}
              {timePreset === 'CUSTOM' && (
                <>
                  <Input
                    label="From Start Date"
                    type="date"
                    value={customStartDate}
                    onChange={(e) => setCustomStartDate(e.target.value)}
                  />
                  <Input
                    label="To End Date"
                    type="date"
                    value={customEndDate}
                    onChange={(e) => setCustomEndDate(e.target.value)}
                  />
                </>
              )}
            </div>
          </Card>

          {/* Auto-Calculated Summary Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card className="p-4 bg-slate-900/90 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Total Coins Delivered</span>
                <Coins className="h-5 w-5 text-gold-400" />
              </div>
              <p className="text-xl font-bold font-mono text-gold-400 mt-2">
                🪙 {formatNumber(reportTotals.totalCoins)}
              </p>
              <p className="text-[11px] text-slate-500 mt-1">Across {reportTotals.count} coin allocations</p>
            </Card>

            <Card className="p-4 bg-slate-900/90 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Gross Standard Value</span>
                <DollarSign className="h-5 w-5 text-slate-400" />
              </div>
              <p className="text-xl font-bold font-mono text-white mt-2">
                {currencyUnit === 'USD'
                  ? `$${reportTotals.totalGrossUSD.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
                  : `Rs ${reportTotals.totalGrossPKR.toLocaleString()}`}
              </p>
              <p className="text-[11px] text-slate-500 mt-1">Base price before discount</p>
            </Card>

            <Card className="p-4 bg-slate-900/90 border border-slate-800">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Total Discount Savings</span>
                <Percent className="h-5 w-5 text-purple-400" />
              </div>
              <p className="text-xl font-bold font-mono text-purple-400 mt-2">
                {currencyUnit === 'USD'
                  ? `$${reportTotals.totalDiscountUSD.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
                  : `Rs ${reportTotals.totalDiscountPKR.toLocaleString()}`}
              </p>
              <p className="text-[11px] text-slate-500 mt-1">Discount granted to sellers/merchants</p>
            </Card>

            <Card className="p-4 bg-slate-900/90 border border-emerald-500/30">
              <div className="flex items-center justify-between">
                <span className="text-xs font-bold text-emerald-400 uppercase tracking-wider">Net Amount Collected</span>
                <TrendingUp className="h-5 w-5 text-emerald-400" />
              </div>
              <p className="text-xl font-bold font-mono text-emerald-400 mt-2">
                {currencyUnit === 'USD'
                  ? `$${reportTotals.totalNetUSD.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
                  : `Rs ${reportTotals.totalNetPKR.toLocaleString()}`}
              </p>
              <p className="text-[11px] text-slate-400 mt-1">Actual revenue received after discount</p>
            </Card>
          </div>

          {/* Detailed Transaction Report Table */}
          <Card className="p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-base font-bold text-white">
                Detailed Transaction Breakdown ({filteredReportRecords.length} Records)
              </h3>
              <Badge variant="success">Auto-Calculated Report</Badge>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-slate-800 bg-slate-900/60 text-slate-400 font-bold uppercase tracking-wider">
                    <th className="p-3">Entity Name</th>
                    <th className="p-3">Category</th>
                    <th className="p-3">Date</th>
                    <th className="p-3 text-right">Coins Delivered</th>
                    <th className="p-3 text-right">Standard Gross</th>
                    <th className="p-3 text-center">Discount %</th>
                    <th className="p-3 text-right">Discounted Net Paid</th>
                    <th className="p-3 text-right">Discount Savings</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 text-slate-300">
                  {filteredReportRecords.length > 0 ? (
                    filteredReportRecords.map((row) => (
                      <tr key={row.txnId} className="hover:bg-slate-900/50 transition-colors">
                        <td className="p-3">
                          <p className="font-bold text-white">{row.entityName}</p>
                          <p className="text-[11px] text-slate-400">{row.username} ({row.userRef})</p>
                        </td>
                        <td className="p-3">
                          <Badge variant={row.entityType === 'SELLER' ? 'gold' : 'purple'}>
                            {row.entityType === 'SELLER' ? 'Coin Seller' : 'Merchant'}
                          </Badge>
                        </td>
                        <td className="p-3 text-slate-400">{formatDate(row.timestamp)}</td>
                        <td className="p-3 text-right font-mono font-bold text-yellow-400">
                          🪙 {formatNumber(row.coinsDelivered)}
                        </td>
                        <td className="p-3 text-right font-mono text-slate-400">
                          {currencyUnit === 'USD' ? `$${row.grossAmountUSD.toFixed(2)}` : `Rs ${row.grossAmountPKR.toLocaleString()}`}
                        </td>
                        <td className="p-3 text-center">
                          <span className="px-2 py-0.5 rounded bg-purple-500/20 text-purple-300 font-bold border border-purple-500/30">
                            {row.discountPercent}% OFF
                          </span>
                        </td>
                        <td className="p-3 text-right font-mono font-bold text-emerald-400">
                          {currencyUnit === 'USD' ? `$${row.netAmountUSD.toFixed(2)}` : `Rs ${row.netAmountPKR.toLocaleString()}`}
                        </td>
                        <td className="p-3 text-right font-mono text-slate-300">
                          {currencyUnit === 'USD' ? `$${row.discountSavingsUSD.toFixed(2)}` : `Rs ${row.discountSavingsPKR.toLocaleString()}`}
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={8} className="p-6 text-center text-slate-500 italic">
                        No transactions found for the selected date range and filter criteria.
                      </td>
                    </tr>
                  )}
                </tbody>

                {/* Grand Totals Section at Bottom */}
                {filteredReportRecords.length > 0 && (
                  <tfoot>
                    <tr className="border-t-2 border-slate-700 bg-slate-900 font-bold text-white text-xs">
                      <td colSpan={3} className="p-3.5 text-gold-400 uppercase tracking-wider">
                        GRAND TOTALS SUMMARY
                      </td>
                      <td className="p-3.5 text-right font-mono text-gold-400 text-sm">
                        🪙 {formatNumber(reportTotals.totalCoins)}
                      </td>
                      <td className="p-3.5 text-right font-mono text-slate-300">
                        {currencyUnit === 'USD'
                          ? `$${reportTotals.totalGrossUSD.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
                          : `Rs ${reportTotals.totalGrossPKR.toLocaleString()}`}
                      </td>
                      <td className="p-3.5 text-center text-purple-400">
                        Avg {Math.round((reportTotals.totalDiscountUSD / (reportTotals.totalGrossUSD || 1)) * 100)}%
                      </td>
                      <td className="p-3.5 text-right font-mono text-emerald-400 text-sm">
                        {currencyUnit === 'USD'
                          ? `$${reportTotals.totalNetUSD.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
                          : `Rs ${reportTotals.totalNetPKR.toLocaleString()}`}
                      </td>
                      <td className="p-3.5 text-right font-mono text-purple-300">
                        {currencyUnit === 'USD'
                          ? `$${reportTotals.totalDiscountUSD.toLocaleString(undefined, { minimumFractionDigits: 2 })}`
                          : `Rs ${reportTotals.totalDiscountPKR.toLocaleString()}`}
                      </td>
                    </tr>
                  </tfoot>
                )}
              </table>
            </div>
          </Card>
        </div>
      )}

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
              <p>
                <strong>Chain ID:</strong> <code className="font-mono text-gold-400 font-bold">{inspectTx.chainId}</code>
              </p>
              <p>
                <strong>Transaction ID:</strong> <code className="font-mono text-slate-200">{inspectTx.txnId}</code>
              </p>
              <p>
                <strong>Executing Operator:</strong> {inspectTx.operator}
              </p>
              {inspectTx.note && (
                <p className="text-amber-400">
                  <strong>Note:</strong> {inspectTx.note}
                </p>
              )}
            </div>

            <div className="p-3 bg-slate-800/40 border border-slate-700/50 rounded-xl space-y-2">
              <p className="font-bold text-white flex items-center gap-1.5">
                <Link className="h-3.5 w-3.5 text-gold-400" /> Linked Related Txn IDs
              </p>
              <div className="flex flex-wrap gap-2">
                {inspectTx.linkedRecords?.map((linkId) => (
                  <Badge key={linkId} variant="purple" className="font-mono">
                    {linkId}
                  </Badge>
                ))}
              </div>
            </div>

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
                <strong>Attention:</strong> You are creating an adjusting reversal entry for transaction{' '}
                <code className="font-mono text-white font-bold">{reversalModal.txn?.txnId}</code>. This action posts a compensating ledger entry and marks the original transaction as REVERSED.
              </p>
            </div>

            <Input
              label="Reversal Adjust Amount (USD)"
              type="number"
              value={reversalModal.reversalAmountUSD}
              onChange={(e) => setReversalModal({ ...reversalModal, reversalAmountUSD: e.target.value })}
            />

            <Input
              label="Correction Justification Reason *"
              value={reversalModal.reason}
              onChange={(e) => setReversalModal({ ...reversalModal, reason: e.target.value })}
              placeholder="e.g. Corrected mistaken duplicate coin allocation"
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setReversalModal({ open: false, txn: null, reason: '', reversalAmountUSD: '' })}
              >
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={handleCreateReversal}>
                Post Reversal Entry & Audit Log
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
