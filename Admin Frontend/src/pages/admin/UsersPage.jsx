// ============================================================
// ZeParty Admin Portal — User Management Page (JSX)
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Users, Search, Filter, Eye, Ban, DollarSign, UserCheck,
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Card } from '../../components/ui/Card';
import { Modal } from '../../components/ui/Modal';
import { Select } from '../../components/ui/Select';
import { USER_STATUSES } from '../../mocks/users.mock';
import { formatDate, formatNumber } from '../../utils/format';
import { formatDistanceToNow } from '../../utils/formatters';
import { usePermission } from '../../hooks/usePermission';
import {
  getUsers,
  suspendUser,
  banUser,
  unbanUser,
  adjustUserBalance,
} from '../../services/modules/users.service';

// ---- Balance Adjustment Modal ----
function BalanceModal({ isOpen, onClose, user, onConfirm }) {
  const [currencyType, setCurrencyType] = useState('coins');
  const [action, setAction] = useState('add');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) { setAmount(''); setReason(''); setError(''); }
  }, [isOpen, user?.id]);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!amount || Number(amount) <= 0) { setError('Please enter a valid amount.'); return; }
    setIsSaving(true);
    setError('');
    try {
      await onConfirm(user.id, Number(amount), currencyType, action, reason.trim());
      onClose();
    } catch {
      setError('Failed to adjust balance. Please try again.');
    } finally {
      setIsSaving(false);
    }
  }

  if (!user) return null;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Adjust Balance"
      description={`Modify virtual currency for ${user.displayName}`}
      size="sm"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-slate-300 block mb-1.5">Currency</label>
            <div className="flex gap-2">
              {['coins', 'diamonds'].map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => setCurrencyType(c)}
                  className={[
                    'flex-1 py-1.5 rounded-lg text-xs font-medium capitalize border transition-colors',
                    currencyType === c
                      ? 'border-indigo-500 bg-indigo-500/20 text-indigo-400'
                      : 'border-slate-700 bg-slate-800 text-slate-400 hover:text-white',
                  ].join(' ')}
                >
                  {c}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="text-xs font-medium text-slate-300 block mb-1.5">Action</label>
            <div className="flex gap-2">
              {['add', 'deduct'].map((a) => (
                <button
                  key={a}
                  type="button"
                  onClick={() => setAction(a)}
                  className={[
                    'flex-1 py-1.5 rounded-lg text-xs font-medium capitalize border transition-colors',
                    action === a
                      ? a === 'add'
                        ? 'border-emerald-500 bg-emerald-500/20 text-emerald-400'
                        : 'border-red-500 bg-red-500/20 text-red-400'
                      : 'border-slate-700 bg-slate-800 text-slate-400 hover:text-white',
                  ].join(' ')}
                >
                  {a}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="p-3 rounded-lg bg-slate-800/80 text-xs text-slate-400 space-y-1">
          <div className="flex justify-between">
            <span>Current Coins</span>
            <span className="text-white font-medium">{user.coins.toLocaleString()}</span>
          </div>
          <div className="flex justify-between">
            <span>Current Diamonds</span>
            <span className="text-white font-medium">{user.diamonds.toLocaleString()}</span>
          </div>
        </div>

        <Input
          label="Amount"
          type="number"
          min="1"
          value={amount}
          onChange={(e) => { setAmount(e.target.value); setError(''); }}
          placeholder="Enter amount"
          required
        />
        <Input
          label="Reason"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Brief reason for this adjustment"
          required
        />
        {error && <p className="text-xs text-red-400 -mt-2">{error}</p>}

        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant={action === 'add' ? 'primary' : 'danger'}
            size="sm"
            isLoading={isSaving}
          >
            {action === 'add' ? 'Add Balance' : 'Deduct Balance'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ---- Status Change Modal ----
function StatusModal({ isOpen, onClose, user, onConfirm }) {
  const [newStatus, setNewStatus] = useState('');
  const [reason, setReason] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) { setNewStatus(''); setReason(''); setError(''); }
  }, [isOpen, user?.id]);

  const NEXT_STATUSES = USER_STATUSES.filter((s) => s !== 'all' && s !== user?.status);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!newStatus) { setError('Please select a new status.'); return; }
    setIsSaving(true);
    setError('');
    try {
      await onConfirm(user.id, newStatus, reason.trim());
      onClose();
    } catch {
      setError('Failed to update status. Please try again.');
    } finally {
      setIsSaving(false);
    }
  }

  if (!user) return null;

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Change User Status"
      description={`Update account status for ${user.displayName}`}
      size="sm"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Select
          label="New Status"
          value={newStatus}
          onChange={(e) => { setNewStatus(e.target.value); setError(''); }}
          required
        >
          <option value="">Select new status…</option>
          {NEXT_STATUSES.map((s) => (
            <option key={s} value={s} className="capitalize">
              {s.charAt(0).toUpperCase() + s.slice(1)}
            </option>
          ))}
        </Select>
        <Input
          label="Reason"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Reason for status change"
          required
        />
        {error && <p className="text-xs text-red-400 -mt-2">{error}</p>}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant={newStatus === 'banned' ? 'danger' : 'primary'}
            size="sm"
            isLoading={isSaving}
          >
            Update Status
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ---- Main Users Page ----
export function UsersPage() {
  const navigate = useNavigate();
  const { canPerformAction } = usePermission();
  const [users, setUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [balanceModal, setBalanceModal] = useState({ open: false, user: null });
  const [statusModal, setStatusModal] = useState({ open: false, user: null });

  // Load on mount
  useEffect(() => {
    getUsers()
      .then((data) => setUsers(data))
      .finally(() => setIsLoading(false));
  }, []);

  // Patch a single user
  function patchUser(id, patch) {
    setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, ...patch } : u)));
  }

  // Balance adjust handler
  async function handleBalanceAdjust(id, amount, currencyType, action) {
    await adjustUserBalance(id, amount, action, currencyType);
    // Update local coin/diamond count
    setUsers((prev) =>
      prev.map((u) => {
        if (u.id !== id) return u;
        const delta = action === 'add' ? amount : -amount;
        if (currencyType === 'coins') return { ...u, coins: Math.max(0, u.coins + delta) };
        return { ...u, diamonds: Math.max(0, (u.diamonds || 0) + delta) };
      })
    );
  }

  // Status change handler
  async function handleStatusChange(id, newStatus, reason) {
    if (newStatus === 'banned') await banUser(id, reason);
    else if (newStatus === 'suspended') await suspendUser(id, reason);
    else await unbanUser(id);
    patchUser(id, { status: newStatus });
  }

  const filtered = useMemo(() => {
    return users.filter((u) => {
      const matchStatus = statusFilter === 'all' || u.status === statusFilter;
      const q = search.toLowerCase();
      const matchSearch =
        !q ||
        u.username.toLowerCase().includes(q) ||
        u.displayName.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q);
      return matchStatus && matchSearch;
    });
  }, [users, search, statusFilter]);

  const columns = [
    {
      key: 'user',
      header: 'User',
      render: (row) => (
        <div className="flex items-center gap-3">
          <div className="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
            {row.displayName.charAt(0)}
          </div>
          <div>
            <p className="font-medium text-white text-sm leading-tight">{row.displayName}</p>
            <p className="text-xs text-slate-500">@{row.username}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status} />,
    },
    {
      key: 'vip',
      header: 'VIP',
      render: (row) =>
        row.vip ? (
          <Badge variant="warning">{row.vipLevel}</Badge>
        ) : (
          <span className="text-xs text-slate-500">—</span>
        ),
    },
    {
      key: 'coins',
      header: 'Coins',
      render: (row) => (
        <span className="text-sm font-mono text-yellow-400">{row.coins.toLocaleString()}</span>
      ),
    },
    {
      key: 'diamonds',
      header: 'Diamonds',
      render: (row) => (
        <span className="text-sm font-mono text-cyan-400">{(row.diamonds || 0).toLocaleString()}</span>
      ),
    },
    {
      key: 'lastActive',
      header: 'Last Active',
      render: (row) => (
        <span className="text-xs text-slate-400">
          {formatDistanceToNow(row.lastActive)}
        </span>
      ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex items-center gap-1">
          <button
            title="View Details"
            onClick={() => navigate(`/admin/users/${row.id}`)}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700 transition-colors"
          >
            <Eye className="h-3.5 w-3.5" aria-hidden="true" />
          </button>
          {canPerformAction('adjust_user_coins') && (
            <button
              title="Adjust Balance"
              onClick={() => setBalanceModal({ open: true, user: row })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-yellow-400 hover:bg-slate-700 transition-colors"
            >
              <DollarSign className="h-3.5 w-3.5" aria-hidden="true" />
            </button>
          )}
          {(canPerformAction('suspend_users') || canPerformAction('ban_users')) && (
            <button
              title="Change Status"
              onClick={() => setStatusModal({ open: true, user: row })}
              className={[
                'p-1.5 rounded-lg transition-colors',
                row.status === 'active'
                  ? 'text-slate-400 hover:text-red-400 hover:bg-slate-700'
                  : 'text-slate-400 hover:text-emerald-400 hover:bg-slate-700',
              ].join(' ')}
            >
              {row.status === 'active' ? (
                <Ban className="h-3.5 w-3.5" aria-hidden="true" />
              ) : (
                <UserCheck className="h-3.5 w-3.5" aria-hidden="true" />
              )}
            </button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Users className="h-6 w-6 text-indigo-400" aria-hidden="true" />
            User Management
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage platform users, balances, and account statuses.
          </p>
        </div>
      </div>

      {/* Filters Bar */}
      <Card className="p-4 flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <Input
          placeholder="Search by username, name, or email…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md w-full min-w-0"
        />
        <div className="flex items-center gap-2">
          <Filter className="h-4 w-4 text-slate-400 flex-shrink-0" aria-hidden="true" />
          <div className="flex gap-1 flex-wrap">
            {USER_STATUSES.map((s) => (
              <button
                key={s}
                onClick={() => setStatusFilter(s)}
                className={[
                  'px-3 py-1.5 rounded-lg text-xs font-medium capitalize border transition-colors',
                  statusFilter === s
                    ? 'bg-indigo-500/20 border-indigo-500/50 text-indigo-400'
                    : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white hover:border-slate-600',
                ].join(' ')}
              >
                {s === 'all' ? 'All' : s}
              </button>
            ))}
          </div>
        </div>
      </Card>

      {/* Stats row — derived from live state */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Total Users', value: users.length,                                            color: 'text-white' },
          { label: 'Active',      value: users.filter((u) => u.status === 'active').length,    color: 'text-emerald-400' },
          { label: 'Suspended',   value: users.filter((u) => u.status === 'suspended').length, color: 'text-amber-400' },
          { label: 'Banned',      value: users.filter((u) => u.status === 'banned').length,    color: 'text-red-400' },
        ].map((s) => (
          <Card key={s.label} className="p-4 text-center">
            <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
            <p className="text-xs text-slate-400 mt-0.5">{s.label}</p>
          </Card>
        ))}
      </div>

      {/* Table */}
      <DataTable
        columns={columns}
        data={filtered}
        isLoading={isLoading}
        emptyTitle="No users found"
        emptyDescription="Try adjusting your search or status filter."
        pagination={{ page: 1, totalPages: 1, total: filtered.length }}
      />

      {/* Modals */}
      <BalanceModal
        isOpen={balanceModal.open}
        onClose={() => setBalanceModal({ open: false, user: null })}
        user={balanceModal.user}
        onConfirm={handleBalanceAdjust}
      />
      <StatusModal
        isOpen={statusModal.open}
        onClose={() => setStatusModal({ open: false, user: null })}
        user={statusModal.user}
        onConfirm={handleStatusChange}
      />
    </div>
  );
}
