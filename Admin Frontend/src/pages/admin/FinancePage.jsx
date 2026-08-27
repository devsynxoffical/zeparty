// ============================================================
// ZeParty Admin Portal — Finance & Earnings Page (JSX)
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { DollarSign, Download, TrendingUp, PieChart, Activity, Building, ArrowDownToLine, Filter } from 'lucide-react';
import {
  BarChart, Bar, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis
} from 'recharts';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { formatCurrency, formatCompact } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getFinanceDashboard,
  getRevenueChart,
  getSettlements,
  updateSettlementStatus
} from '../../services/modules/finance.service';

const ChartTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 shadow-xl text-xs">
        <p className="text-slate-400 mb-1">{label}</p>
        <p className="font-semibold text-emerald-400">
          {formatCurrency(payload[0].value)}
        </p>
      </div>
    );
  }
  return null;
};

export function FinancePage() {
  const { addLog } = useAuditLog();
  const [stats, setStats] = useState(null);
  const [chartData, setChartData] = useState([]);
  const [settlements, setSettlements] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [selectedSettlement, setSelectedSettlement] = useState(null);
  const [rejectTarget, setRejectTarget] = useState(null);
  const [feedback, setFeedback] = useState(null);
  const [chartPeriod, setChartPeriod] = useState('Week');

  useEffect(() => {
    Promise.all([getFinanceDashboard(), getRevenueChart(), getSettlements()])
      .then(([s, c, setts]) => {
        setStats(s);
        setChartData(c);
        setSettlements(setts);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const filteredSettlements = useMemo(() => {
    return settlements.filter(s => statusFilter === 'ALL' || s.status === statusFilter);
  }, [settlements, statusFilter]);

  const handleExport = () => {
    const csvRows = [];
    csvRows.push(['ID', 'Period', 'Host/Agency Entity', 'Gross Earnings (USD)', 'Commission/Fee (USD)', 'Net Payout (USD)', 'Status']);
    
    filteredSettlements.forEach(row => {
      csvRows.push([
        row.id,
        row.period,
        row.entity,
        row.gross,
        row.commission,
        row.net,
        row.status
      ]);
    });

    const csvContent = "data:text/csv;charset=utf-8," 
      + csvRows.map(e => e.map(val => `"${String(val).replace(/"/g, '""')}"`).join(",")).join("\n");
    
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `zeparty_finance_settlements_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    addLog('FINANCE_EXPORT', 'export', 'Finance', 'Exported settlement reports to CSV');
    setFeedback('CSV settlements report downloaded successfully.');
    setTimeout(() => setFeedback(null), 3000);
  };

  const handleApproveSettlement = async (id, entity) => {
    const updated = await updateSettlementStatus(id, 'APPROVED');
    setSettlements(settlements.map(s => s.id === id ? updated : s));
    addLog('SETTLEMENT_APPROVED', id, 'Finance', `Approved settlement ${id} for ${entity}`);
    setFeedback(`Settlement ${id} approved for ${entity}.`);
    setTimeout(() => setFeedback(null), 3000);
  };

  const handleRejectSettlement = async (id, entity) => {
    const updated = await updateSettlementStatus(id, 'REJECTED');
    setSettlements(settlements.map(s => s.id === id ? updated : s));
    addLog('SETTLEMENT_REJECTED', id, 'Finance', `Rejected settlement ${id} for ${entity}`);
    setRejectTarget(null);
    setFeedback(`Settlement ${id} rejected.`);
    setTimeout(() => setFeedback(null), 3000);
  };

  const columns = [
    { key: 'settleId', header: 'ID', render: (row) => <span className="text-slate-300 font-mono text-xs">{row.id}</span> },
    { key: 'period', header: 'Period', render: (row) => <span className="text-slate-300 text-sm">{row.period}</span> },
    { key: 'entity', header: 'Host / Agency', render: (row) => <span className="font-medium text-white">{row.entity}</span> },
    { key: 'gross', header: 'Gross Earnings', render: (row) => <span className="text-slate-400">{formatCurrency(row.gross)}</span> },
    { key: 'commission', header: 'Commission (Fee)', render: (row) => <span className="text-red-400">-{formatCurrency(row.commission)}</span> },
    { key: 'net', header: 'Net Payout', render: (row) => <span className="text-emerald-400 font-bold">{formatCurrency(row.net)}</span> },
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-2">
        {row.status === 'PENDING' && (
          <>
            <button
              onClick={() => handleApproveSettlement(row.id, row.entity)}
              className="text-xs text-emerald-400 hover:underline font-bold"
            >
              Approve
            </button>
            <button
              onClick={() => setRejectTarget(row)}
              className="text-xs text-red-400 hover:underline font-bold"
            >
              Reject
            </button>
          </>
        )}
        <button
          onClick={() => setSelectedSettlement(row)}
          className="text-xs text-indigo-400 hover:underline"
        >
          Details
        </button>
      </div>
    )}
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading Finance Data...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Finance & Earnings">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <DollarSign className="h-6 w-6 text-emerald-400" aria-hidden="true" />
            Finance & Earnings
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Track revenue, process settlements, and view financial reports.</p>
        </div>
        <button
          onClick={handleExport}
          className="flex items-center gap-2 bg-slate-800 hover:bg-slate-700 text-white border border-slate-700 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
        >
          <ArrowDownToLine className="h-4 w-4" /> Export CSV
        </button>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{feedback}</span>
          <span className="font-mono">PROCESSED</span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Gross Recharge Revenue" value={formatCurrency(stats.grossRechargeRevenue)} icon={TrendingUp} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
        <StatCard title="Net Platform Revenue" value={formatCurrency(stats.netPlatformRevenue)} icon={PieChart} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Host Earnings" value={formatCurrency(stats.hostEarnings)} icon={Activity} iconColor="text-gold-400" iconBg="bg-gold-500/10" />
        <StatCard title="Pending Settlements" value={formatCurrency(stats.pendingSettlement)} icon={Building} iconColor="text-amber-400" iconBg="bg-amber-500/10" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-2">
          <CardHeader title="Revenue Trend" description="Gross revenue over the selected period">
            <div className="flex bg-slate-900 rounded-lg p-1">
              {['Day', 'Week', 'Month'].map(t => (
                <button
                  key={t}
                  onClick={() => setChartPeriod(t)}
                  className={`px-3 py-1 text-xs font-medium rounded-md transition-colors ${t === chartPeriod ? 'bg-slate-700 text-white' : 'text-slate-400 hover:text-white'}`}
                >
                  {t}
                </button>
              ))}
            </div>
          </CardHeader>
          <div className="p-4 h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData} margin={{ top: 0, right: 0, left: -20, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                <XAxis dataKey="label" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={formatCompact} />
                <Tooltip content={<ChartTooltip />} />
                <Bar dataKey="revenue" fill="#10b981" radius={[4, 4, 0, 0]} maxBarSize={40} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card>
          <CardHeader title="Finance Reconciliation" description="Current period summary" />
          <div className="p-4 space-y-4">
            <div className="flex justify-between items-center text-sm">
              <span className="text-slate-400">Gross Recharge</span>
              <span className="text-white font-medium">{formatCurrency(stats.grossRechargeRevenue)}</span>
            </div>
            <div className="flex justify-between items-center text-sm border-t border-slate-700/50 pt-3">
              <span className="text-slate-400">- Host Earnings</span>
              <span className="text-red-400 font-medium">-{formatCurrency(stats.hostEarnings)}</span>
            </div>
            <div className="flex justify-between items-center text-sm">
              <span className="text-slate-400">- Agency Commission</span>
              <span className="text-red-400 font-medium">-{formatCurrency(stats.agencyCommission)}</span>
            </div>
            <div className="flex justify-between items-center text-sm border-t border-slate-700 pt-3">
              <span className="text-white font-bold">= Platform Profit</span>
              <span className="text-emerald-400 font-bold">{formatCurrency(stats.platformProfit)}</span>
            </div>
          </div>
        </Card>
      </div>

      <Card>
        <CardHeader title="Settlement Reports" description="Process payouts to hosts and agencies">
          <div className="flex items-center gap-2 border border-slate-700 bg-slate-900 rounded-lg px-2">
            <Filter className="h-4 w-4 text-slate-500" />
            <select
              className="bg-transparent text-sm text-white py-2 outline-none"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="ALL">All Statuses</option>
              <option value="PENDING">Pending</option>
              <option value="APPROVED">Approved</option>
              <option value="PAID">Paid</option>
              <option value="REJECTED">Rejected</option>
            </select>
          </div>
        </CardHeader>
        <DataTable columns={columns} data={filteredSettlements} isLoading={false} />
      </Card>

      {/* Settlement Details Modal */}
      {selectedSettlement && (
        <Modal isOpen={true} onClose={() => setSelectedSettlement(null)} title={`Settlement Details: ${selectedSettlement.id}`}>
          <div className="space-y-3 text-xs text-slate-300">
            <p><strong>Host / Agency:</strong> <span className="text-white font-bold">{selectedSettlement.entity}</span></p>
            <p><strong>Period:</strong> {selectedSettlement.period}</p>
            <p><strong>Gross Earnings:</strong> <span className="text-emerald-400">{formatCurrency(selectedSettlement.gross)}</span></p>
            <p><strong>Commission Deducted:</strong> <span className="text-red-400">-{formatCurrency(selectedSettlement.commission)}</span></p>
            <p><strong>Net Payout:</strong> <span className="text-emerald-400 font-bold">{formatCurrency(selectedSettlement.net)}</span></p>
            <p><strong>Status:</strong> <span className="uppercase font-bold text-gold-400">{selectedSettlement.status}</span></p>
            <div className="flex justify-end pt-2">
              <button onClick={() => setSelectedSettlement(null)} className="bg-gold-500 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold">Close</button>
            </div>
          </div>
        </Modal>
      )}

      {/* Reject Confirmation Modal */}
      {rejectTarget && (
        <Modal isOpen={true} onClose={() => setRejectTarget(null)} title={`Reject Settlement: ${rejectTarget.id}`}>
          <div className="space-y-4 text-xs text-slate-300">
            <p>Are you sure you want to reject settlement <strong className="text-white">{rejectTarget.id}</strong> for <strong className="text-white">{rejectTarget.entity}</strong>?</p>
            <div className="flex justify-end gap-3 pt-2">
              <button onClick={() => setRejectTarget(null)} className="px-4 py-2 text-sm text-slate-400">Cancel</button>
              <button onClick={() => handleRejectSettlement(rejectTarget.id, rejectTarget.entity)} className="bg-red-500 text-white px-4 py-2 rounded-lg text-sm font-bold">
                Confirm Rejection
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
