import React, { useState, useMemo, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Users, Search, Filter, Eye, Ban, DollarSign, UserCheck, Plus, Edit2, Trash2, CheckCircle2, AlertTriangle, ChevronDown, History, ArrowUpRight, ArrowDownRight,
  CheckSquare, Square, Download, ShieldCheck, ShieldAlert
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Card } from '../../components/ui/Card';
import { Modal } from '../../components/ui/Modal';
import { Select } from '../../components/ui/Select';
import { Toast } from '../../components/ui/Toast';
import { ImageViewerModal } from '../../components/ui/ImageViewerModal';
import { CountryFlag } from '../../components/ui/CountryFlag';
import {
  COUNTRY_PHONE_CONFIG,
  POPULAR_COUNTRY_CODES,
  getPhoneConfig,
  formatLocalPhoneNumber,
  toE164,
} from '../../constants/phoneCountryCodes';
const USER_STATUSES = ['all', 'active', 'suspended', 'banned'];
import { formatDistanceToNow } from '../../utils/formatters';
import { usePermission } from '../../hooks/usePermission';
import { getMasterLedger } from '../../services/modules/finance.service';
import {
  getUsers,
  createUser,
  updateUser,
  deleteUser,
  suspendUser,
  banUser,
  unbanUser,
  adjustUserBalance,
} from '../../services/modules/users.service';

// ---- Create User Modal ----
function CreateUserModal({ isOpen, onClose, onConfirm }) {
  const [formData, setFormData] = useState({
    username: '',
    displayName: '',
    avatarUrl: '',
    phone: '',
    email: '',
    countryCode: 'PK',
    status: 'ACTIVE',
    coins: '',
    diamonds: '',
  });
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  const phoneConfig = getPhoneConfig(formData.countryCode);

  useEffect(() => {
    if (isOpen) {
      setFormData({
        username: '',
        displayName: '',
        phone: '',
        email: '',
        countryCode: 'PK',
        status: 'ACTIVE',
        coins: '',
        diamonds: '',
      });
      setError('');
    }
  }, [isOpen]);

  function handleCountryChange(newCode) {
    setFormData((prev) => {
      const newPhone = formatLocalPhoneNumber(prev.phone, newCode);
      return {
        ...prev,
        countryCode: newCode,
        phone: newPhone,
      };
    });
  }

  function handlePhoneChange(e) {
    const rawVal = e.target.value;
    const formatted = formatLocalPhoneNumber(rawVal, formData.countryCode);
    setFormData((prev) => ({ ...prev, phone: formatted }));
    setError('');
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!formData.username || formData.username.trim().length < 3) {
      setError('Username must be at least 3 characters.');
      return;
    }

    if (formData.email && formData.email.trim() !== '') {
      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(formData.email.trim())) {
        setError('Please enter a valid email address (e.g. user@example.com)');
        return;
      }
    }

    setIsSaving(true);
    setError('');
    try {
      const formattedPhone = formData.phone.trim()
        ? toE164(formData.phone.trim(), formData.countryCode)
        : undefined;

      await onConfirm({
        username: formData.username.trim(),
        displayName: formData.displayName.trim() || formData.username.trim(),
        avatarUrl: formData.avatarUrl.trim() || undefined,
        phone: formattedPhone,
        email: formData.email.trim() || undefined,
        countryCode: formData.countryCode.trim().toUpperCase() || 'PK',
        status: formData.status,
        coins: Number(formData.coins) || 0,
        diamonds: Number(formData.diamonds) || 0,
      });
      onClose();
    } catch (err) {
      setError(err.message || 'Failed to create user.');
    } finally {
      setIsSaving(false);
    }
  }

  const allCountryList = useMemo(() => {
    return Object.values(COUNTRY_PHONE_CONFIG).sort((a, b) => a.name.localeCompare(b.name));
  }, []);

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Create New User"
      description="Add a new user account with PostgreSQL persistence"
      size="md"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <Input
            label="Username *"
            value={formData.username}
            onChange={(e) => { setFormData({ ...formData, username: e.target.value }); setError(''); }}
            placeholder="e.g. johndoe"
            required
          />
          <Input
            label="Display Name"
            value={formData.displayName}
            onChange={(e) => setFormData({ ...formData, displayName: e.target.value })}
            placeholder="e.g. John Doe"
          />

          {/* Country Selection Dropdown */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-slate-300 flex items-center justify-between">
              <span>Country *</span>
              <span className="text-[11px] text-indigo-400 font-mono">Dial: {phoneConfig.dialCode}</span>
            </label>
            <div className="relative">
              <select
                value={formData.countryCode}
                onChange={(e) => handleCountryChange(e.target.value)}
                className="w-full h-9 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs pl-9 pr-8 appearance-none focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 cursor-pointer"
              >
                {allCountryList.map((c) => (
                  <option key={c.code} value={c.code} className="bg-slate-900 text-white">
                    {c.name} ({c.dialCode})
                  </option>
                ))}
              </select>
              <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none flex items-center">
                <CountryFlag code={formData.countryCode} className="w-4 h-3 rounded-sm object-cover" />
              </div>
              <ChevronDown className="h-3.5 w-3.5 text-slate-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            </div>
          </div>

          {/* Phone Input with Dial Code Badge & Spacing */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-slate-300 flex items-center justify-between">
              <span>Phone Number</span>
              <span className="text-[11px] text-slate-400">Max {phoneConfig.digits} digits</span>
            </label>
            <div className="relative flex items-center">
              <div className="h-9 px-2.5 bg-slate-800 border border-r-0 border-slate-700 rounded-l-lg flex items-center gap-1.5 text-xs font-mono font-medium text-indigo-400 select-none">
                <CountryFlag code={formData.countryCode} className="w-3.5 h-2.5 rounded-sm object-cover" />
                <span>{phoneConfig.dialCode}</span>
              </div>
              <input
                type="text"
                value={formData.phone}
                onChange={handlePhoneChange}
                placeholder={phoneConfig.placeholder || 'e.g. 301 5431674'}
                className="w-full h-9 rounded-r-lg bg-slate-900 border border-slate-700 text-white text-xs px-3 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 font-mono placeholder:text-slate-600"
              />
            </div>
          </div>

          <Input
            label="Email"
            type="email"
            value={formData.email}
            onChange={(e) => { setFormData({ ...formData, email: e.target.value }); setError(''); }}
            placeholder="e.g. user@example.com"
          />

          <Input
            label="Avatar Image URL"
            value={formData.avatarUrl}
            onChange={(e) => setFormData({ ...formData, avatarUrl: e.target.value })}
            placeholder="https://example.com/avatar.jpg"
          />

          <Select
            label="Status"
            value={formData.status}
            onChange={(e) => setFormData({ ...formData, status: e.target.value })}
          >
            <option value="ACTIVE">Active</option>
            <option value="SUSPENDED">Suspended</option>
            <option value="BANNED">Banned</option>
          </Select>

          {/* Initial Coins with clean zero clearing */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-slate-300">Initial Coins</label>
            <input
              type="text"
              inputMode="numeric"
              value={formData.coins}
              onChange={(e) => {
                const val = e.target.value.replace(/\D/g, '');
                setFormData({ ...formData, coins: val });
              }}
              placeholder="0"
              className="w-full h-9 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs px-3 focus:outline-none focus:border-yellow-500 focus:ring-1 focus:ring-yellow-500 font-mono placeholder:text-slate-600"
            />
          </div>

          {/* Initial Diamonds with clean zero clearing */}
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-slate-300">Initial Diamonds</label>
            <input
              type="text"
              inputMode="numeric"
              value={formData.diamonds}
              onChange={(e) => {
                const val = e.target.value.replace(/\D/g, '');
                setFormData({ ...formData, diamonds: val });
              }}
              placeholder="0"
              className="w-full h-9 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs px-3 focus:outline-none focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 font-mono placeholder:text-slate-600"
            />
          </div>
        </div>

        {error && (
          <div className="p-2.5 rounded-lg bg-red-500/10 border border-red-500/20 text-xs text-red-400 flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" size="sm" isLoading={isSaving}>
            Create User
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ---- Edit User Modal ----
function EditUserModal({ isOpen, onClose, user, onConfirm }) {
  const [displayName, setDisplayName] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [countryCode, setCountryCode] = useState('PK');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  const phoneConfig = getPhoneConfig(countryCode);

  useEffect(() => {
    if (isOpen && user) {
      setDisplayName(user.displayName || '');
      setAvatarUrl(user.avatarUrl || '');
      const rawCountry = (user.country || 'PK').toUpperCase();
      setCountryCode(rawCountry);
      // Clean up phone if it includes country dial code
      let rawPhone = user.phone || '';
      const cfg = getPhoneConfig(rawCountry);
      if (rawPhone.startsWith(cfg.dialCode)) {
        rawPhone = rawPhone.slice(cfg.dialCode.length);
      }
      setPhone(formatLocalPhoneNumber(rawPhone, rawCountry));
      setEmail(user.email || '');
      setError('');
    }
  }, [isOpen, user?.id]);

  function handleCountryChange(newCode) {
    setCountryCode(newCode);
    setPhone((prev) => formatLocalPhoneNumber(prev, newCode));
  }

  function handlePhoneChange(e) {
    const rawVal = e.target.value;
    const formatted = formatLocalPhoneNumber(rawVal, countryCode);
    setPhone(formatted);
    setError('');
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setIsSaving(true);
    setError('');
    try {
      const formattedPhone = phone.trim()
        ? toE164(phone.trim(), countryCode)
        : undefined;

      await onConfirm(user.id, {
        displayName: displayName.trim() || user.username,
        avatarUrl: avatarUrl.trim() || undefined,
        phone: formattedPhone,
        email: email.trim() || undefined,
        countryCode: countryCode.trim().toUpperCase() || 'PK',
      });
      onClose();
    } catch (err) {
      setError(err.message || 'Failed to update user.');
    } finally {
      setIsSaving(false);
    }
  }

  if (!user) return null;

  const allCountryList = Object.values(COUNTRY_PHONE_CONFIG).sort((a, b) => a.name.localeCompare(b.name));

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Edit User Details"
      description={`Update profile information for @${user.username}`}
      size="sm"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          label="Display Name"
          value={displayName}
          onChange={(e) => setDisplayName(e.target.value)}
          required
        />

        {/* Country Selection */}
        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-medium text-slate-300 flex items-center justify-between">
            <span>Country</span>
            <span className="text-[11px] text-indigo-400 font-mono">Dial: {phoneConfig.dialCode}</span>
          </label>
          <div className="relative">
            <select
              value={countryCode}
              onChange={(e) => handleCountryChange(e.target.value)}
              className="w-full h-9 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs pl-9 pr-8 appearance-none focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 cursor-pointer"
            >
              {allCountryList.map((c) => (
                <option key={c.code} value={c.code} className="bg-slate-900 text-white">
                  {c.name} ({c.dialCode})
                </option>
              ))}
            </select>
            <div className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none flex items-center">
              <CountryFlag code={countryCode} className="w-4 h-3 rounded-sm object-cover" />
            </div>
            <ChevronDown className="h-3.5 w-3.5 text-slate-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
        </div>

        {/* Phone Input with Dial Badge */}
        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-medium text-slate-300 flex items-center justify-between">
            <span>Phone Number</span>
            <span className="text-[11px] text-slate-400">Max {phoneConfig.digits} digits</span>
          </label>
          <div className="relative flex items-center">
            <div className="h-9 px-2.5 bg-slate-800 border border-r-0 border-slate-700 rounded-l-lg flex items-center gap-1.5 text-xs font-mono font-medium text-indigo-400 select-none">
              <CountryFlag code={countryCode} className="w-3.5 h-2.5 rounded-sm object-cover" />
              <span>{phoneConfig.dialCode}</span>
            </div>
            <input
              type="text"
              value={phone}
              onChange={handlePhoneChange}
              placeholder={phoneConfig.placeholder || 'e.g. 301 5431674'}
              className="w-full h-9 rounded-r-lg bg-slate-900 border border-slate-700 text-white text-xs px-3 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 font-mono placeholder:text-slate-600"
            />
          </div>
        </div>

        <Input
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <div className="space-y-1.5">
          <Input
            label="Avatar Image URL"
            value={avatarUrl}
            onChange={(e) => setAvatarUrl(e.target.value)}
            placeholder="https://example.com/avatar.jpg"
          />
          {avatarUrl && (
            <div className="flex items-center gap-2 pt-1">
              <img
                src={avatarUrl}
                alt="Preview"
                className="h-8 w-8 rounded-full object-cover border border-slate-700 ring-1 ring-indigo-500"
                onError={(e) => {
                  e.target.style.display = 'none';
                }}
              />
              <span className="text-[11px] text-slate-400">Avatar Preview</span>
            </div>
          )}
        </div>

        {error && (
          <div className="p-2.5 rounded-lg bg-red-500/10 border border-red-500/20 text-xs text-red-400 flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <div className="flex justify-end gap-2 pt-1 border-t border-slate-800">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" size="sm" isLoading={isSaving}>
            Save Changes
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ---- Delete User Modal (Clean In-App Confirmation replacing window.confirm) ----
function DeleteUserModal({ isOpen, onClose, user, onConfirm }) {
  const [reason, setReason] = useState('');
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setReason('');
      setError('');
    }
  }, [isOpen, user?.id]);

  if (!user) return null;

  async function handleConfirm() {
    setIsDeleting(true);
    setError('');
    try {
      await onConfirm(user.id, reason.trim() || 'Deleted by administrator');
      onClose();
    } catch (err) {
      setError(err.message || 'Failed to delete user.');
    } finally {
      setIsDeleting(false);
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Delete User Account"
      description={`Are you sure you want to permanently delete @${user.username}?`}
      size="sm"
    >
      <div className="flex flex-col gap-4">
        <div className="p-3.5 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs flex items-start gap-2.5">
          <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5 text-red-400" />
          <div>
            <p className="font-semibold text-red-300">Irreversible Permanent Action</p>
            <p className="mt-0.5 text-red-400/90 leading-relaxed">
              This will permanently delete the account, wallet, and identity for{' '}
              <strong className="text-white">@{user.username}</strong> ({user.displayName}) from PostgreSQL.
            </p>
          </div>
        </div>

        <Input
          label="Deletion Reason (Optional)"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="e.g. Terms violation, GDPR request..."
        />

        {error && <p className="text-xs text-red-400">{error}</p>}

        <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isDeleting}>
            Cancel
          </Button>
          <Button
            type="button"
            variant="danger"
            size="sm"
            isLoading={isDeleting}
            onClick={handleConfirm}
          >
            Delete User Permanently
          </Button>
        </div>
      </div>
    </Modal>
  );
}

// ---- Balance Adjustment Modal ----
function BalanceModal({ isOpen, onClose, user, onConfirm }) {
  const [currencyType, setCurrencyType] = useState('coins');
  const [action, setAction] = useState('add');
  const [amount, setAmount] = useState('');
  const [reason, setReason] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');
  const [ledgerEntries, setLedgerEntries] = useState([]);
  const [isLoadingLedger, setIsLoadingLedger] = useState(false);

  useEffect(() => {
    if (isOpen && user?.id) {
      setAmount('');
      setReason('');
      setError('');
      setIsLoadingLedger(true);
      getMasterLedger({ userId: user.id, limit: 5 })
        .then((res) => {
          const items = res?.data || res?.items || (Array.isArray(res) ? res : []);
          setLedgerEntries(items);
        })
        .catch(() => {
          setLedgerEntries([]);
        })
        .finally(() => {
          setIsLoadingLedger(false);
        });
    }
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
      size="md"
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
            <span className="text-white font-medium">{(user.diamonds || 0).toLocaleString()}</span>
          </div>
        </div>

        <div className="flex flex-col gap-1.5">
          <label className="text-xs font-medium text-slate-300">Amount</label>
          <input
            type="text"
            inputMode="numeric"
            value={amount}
            onChange={(e) => {
              const val = e.target.value.replace(/\D/g, '');
              setAmount(val);
              setError('');
            }}
            placeholder="Enter amount (e.g. 5000)"
            required
            className="w-full h-9 rounded-lg bg-slate-900 border border-slate-700 text-white text-xs px-3 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 font-mono placeholder:text-slate-600"
          />
        </div>

        <Input
          label="Reason"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="Brief reason for this adjustment"
          required
        />
        {error && <p className="text-xs text-red-400 -mt-2">{error}</p>}

        {/* Recent Transaction Ledger */}
        <div className="flex flex-col gap-1.5 pt-2 border-t border-slate-800">
          <div className="flex items-center justify-between text-xs text-slate-400">
            <span className="font-semibold text-slate-300 flex items-center gap-1.5">
              <History className="h-3.5 w-3.5 text-indigo-400" />
              Recent Transaction Ledger
            </span>
            <span className="text-[11px] text-slate-500">Last 5 entries</span>
          </div>

          <div className="max-h-36 overflow-y-auto space-y-1.5 rounded-lg bg-slate-950/60 border border-slate-800 p-2 text-xs">
            {isLoadingLedger ? (
              <p className="text-center text-slate-500 py-3">Loading ledger history...</p>
            ) : ledgerEntries.length === 0 ? (
              <p className="text-center text-slate-500 py-3">No recorded ledger transactions yet.</p>
            ) : (
              ledgerEntries.map((tx) => {
                const coinDelta = Number(tx.coinDelta || 0);
                const diamondDelta = Number(tx.diamondDelta || 0);
                const isPositive = coinDelta > 0 || diamondDelta > 0;
                return (
                  <div key={tx.id || tx.referenceId || Math.random()} className="flex items-center justify-between py-1 px-2 rounded bg-slate-900/60 border border-slate-800/60">
                    <div className="flex items-center gap-2 min-w-0">
                      {isPositive ? (
                        <ArrowUpRight className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                      ) : (
                        <ArrowDownRight className="h-3.5 w-3.5 text-red-400 shrink-0" />
                      )}
                      <div className="min-w-0">
                        <p className="text-white font-medium truncate text-[11px]">
                          {(tx.transactionType || 'ADJUSTMENT').replace(/_/g, ' ')}
                        </p>
                        <p className="text-[10px] text-slate-500 font-mono">
                          {tx.createdAt ? new Date(tx.createdAt).toLocaleDateString() : 'Recent'}
                        </p>
                      </div>
                    </div>
                    <div className="text-right shrink-0">
                      {coinDelta !== 0 && (
                        <p className={`font-mono font-bold text-[11px] ${coinDelta > 0 ? 'text-yellow-400' : 'text-red-400'}`}>
                          {coinDelta > 0 ? `+${coinDelta.toLocaleString()}` : coinDelta.toLocaleString()} Coins
                        </p>
                      )}
                      {diamondDelta !== 0 && (
                        <p className={`font-mono font-bold text-[11px] ${diamondDelta > 0 ? 'text-cyan-400' : 'text-red-400'}`}>
                          {diamondDelta > 0 ? `+${diamondDelta.toLocaleString()}` : diamondDelta.toLocaleString()} Diamonds
                        </p>
                      )}
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        <div className="flex justify-end gap-2 pt-1 border-t border-slate-800">
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
        <div className="flex justify-end gap-2 pt-1 border-t border-slate-800">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
            Cancel
          </Button>
          <Button type="submit" variant="primary" size="sm" isLoading={isSaving}>
            Update Status
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ============================================================
// Main UsersPage Component
// ============================================================
export function UsersPage() {
  const navigate = useNavigate();
  const { canPerformAction } = usePermission();

  const [users, setUsers] = useState([]);
  const [pagination, setPagination] = useState({ page: 1, totalPages: 1, total: 0, limit: 20 });
  const [pageSize, setPageSize] = useState(20);
  const [currentPage, setCurrentPage] = useState(1);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState('');
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [feedback, setFeedback] = useState(null);

  // Modals state
  const [createModalOpen, setCreateModalOpen] = useState(false);
  const [editModal, setEditModal] = useState({ open: false, user: null });
  const [balanceModal, setBalanceModal] = useState({ open: false, user: null });
  const [statusModal, setStatusModal] = useState({ open: false, user: null });
  const [deleteModal, setDeleteModal] = useState({ open: false, user: null });

  // Selection & Photo Preview & Batch state
  const [selectedUserIds, setSelectedUserIds] = useState([]);
  const [previewPhoto, setPreviewPhoto] = useState(null);
  const [isBatchProcessing, setIsBatchProcessing] = useState(false);
  const [batchDeleteModalOpen, setBatchDeleteModalOpen] = useState(false);
  const [batchDeleteReason, setBatchDeleteReason] = useState('');

  function showFeedback(type, message, title = '') {
    setFeedback({
      type,
      message,
      title: title || (type === 'success' ? 'Action Completed' : 'Operation Failed'),
      duration: 4500,
    });
  }

  // Load Users from Backend
  const loadUsers = async () => {
    setIsLoading(true);
    setLoadError('');
    try {
      const res = await getUsers({
        page: currentPage,
        limit: pageSize,
        ...(search.trim() ? { search: search.trim() } : {}),
        ...(statusFilter !== 'all' ? { status: statusFilter.toUpperCase() } : {}),
      });

      const userList = res?.users || res?.data || (Array.isArray(res) ? res : []);
      setUsers(userList);
      setSelectedUserIds([]); // reset selection on page change or reload
      if (res?.pagination) {
        setPagination({
          page: Number(res.pagination.page) || currentPage,
          totalPages: Number(res.pagination.totalPages) || 1,
          total: Number(res.pagination.total) || userList.length,
          limit: Number(res.pagination.limit) || pageSize,
        });
      } else {
        setPagination({
          page: currentPage,
          totalPages: 1,
          total: userList.length,
          limit: pageSize,
        });
      }
    } catch (err) {
      console.error('Failed to load users:', err);
      setLoadError(err.message || 'Failed to load users from database.');
    } finally {
      setIsLoading(false);
    }
  };

  // Reload on page, pageSize, search or status change
  useEffect(() => {
    loadUsers();
  }, [currentPage, pageSize, search, statusFilter]);

  // Selection handlers
  const toggleSelectUser = (id) => {
    setSelectedUserIds((prev) =>
      prev.includes(id) ? prev.filter((item) => item !== id) : [...prev, id]
    );
  };

  const toggleSelectAll = () => {
    if (users.length > 0 && selectedUserIds.length === users.length) {
      setSelectedUserIds([]);
    } else {
      setSelectedUserIds(users.map((u) => u.id));
    }
  };

  // Batch Status Change Handler
  const handleBatchStatus = async (newStatus) => {
    if (selectedUserIds.length === 0) return;
    setIsBatchProcessing(true);
    let successCount = 0;
    try {
      for (const userId of selectedUserIds) {
        try {
          if (newStatus === 'banned') await banUser(userId, 'Batch admin ban');
          else if (newStatus === 'suspended') await suspendUser(userId, 'Batch admin suspension');
          else await unbanUser(userId, 'Batch admin reactivation');
          successCount++;
        } catch (e) {
          console.error(`Failed to update user ${userId}:`, e);
        }
      }
      showFeedback('success', `Successfully updated status to ${newStatus.toUpperCase()} for ${successCount} users.`, 'Batch Update Complete');
      setSelectedUserIds([]);
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Batch update encountered an error.', 'Batch Operation Error');
    } finally {
      setIsBatchProcessing(false);
    }
  };

  // Batch Export Handler (CSV)
  const handleBatchExport = () => {
    const selectedUsers = users.filter((u) => selectedUserIds.includes(u.id));
    if (selectedUsers.length === 0) return;
    const headers = ['ID', 'Username', 'DisplayName', 'Email', 'Phone', 'Country', 'Status', 'Coins', 'Diamonds'];
    const rows = selectedUsers.map((u) => [
      u.id,
      u.username,
      `"${(u.displayName || '').replace(/"/g, '""')}"`,
      u.email || '',
      u.phone || '',
      u.country || '',
      u.status || '',
      u.coins || 0,
      u.diamonds || 0,
    ]);
    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `zeparty_users_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    showFeedback('success', `Exported ${selectedUsers.length} user records to CSV file.`, 'Export Completed');
  };

  // Batch Delete Handler
  const handleBatchDelete = async () => {
    if (selectedUserIds.length === 0) return;
    setIsBatchProcessing(true);
    let successCount = 0;
    let failCount = 0;
    try {
      for (const userId of selectedUserIds) {
        try {
          await deleteUser(userId, batchDeleteReason || 'Batch admin deletion');
          successCount++;
        } catch (e) {
          console.error(`Failed to delete user ${userId}:`, e);
          failCount++;
        }
      }
      if (successCount > 0) {
        showFeedback('success', `Permanently deleted ${successCount} user accounts and cleaned up their database records.`, 'Batch Deletion Complete');
      }
      if (failCount > 0) {
        showFeedback('error', `Failed to delete ${failCount} users.`, 'Partial Deletion Failure');
      }
      setSelectedUserIds([]);
      setBatchDeleteModalOpen(false);
      setBatchDeleteReason('');
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Batch delete failed.', 'Batch Error');
    } finally {
      setIsBatchProcessing(false);
    }
  };

  // Create User Handler
  async function handleCreateUser(payload) {
    try {
      await createUser(payload);
      showFeedback('success', `User @${payload.username} has been created and saved to the database.`, 'User Created Successfully');
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Failed to create user', 'User Creation Failed');
      throw err;
    }
  }

  // Edit User Handler
  async function handleEditUser(id, payload) {
    try {
      await updateUser(id, payload);
      showFeedback('success', 'User information updated and committed to the database.', 'User Updated Successfully');
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Failed to update user', 'User Update Failed');
      throw err;
    }
  }

  // Delete User Handler
  async function handleDeleteUser(id, reason) {
    try {
      await deleteUser(id, reason);
      showFeedback('success', 'User account and associated records permanently deleted.', 'User Deleted Successfully');
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Failed to delete user', 'Deletion Failed');
      throw err;
    }
  }

  // Balance adjust handler
  async function handleBalanceAdjust(id, amount, currencyType, action, reason) {
    try {
      await adjustUserBalance(id, amount, currencyType, action, reason);
      showFeedback(
        'success',
        `Successfully ${action === 'add' ? 'added' : 'deducted'} ${amount.toLocaleString()} ${currencyType}.`,
        'Balance Adjusted'
      );
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Failed to adjust user balance', 'Balance Adjustment Failed');
      throw err;
    }
  }

  // Status change handler
  async function handleStatusChange(id, newStatus, reason) {
    try {
      if (newStatus === 'banned') await banUser(id, reason);
      else if (newStatus === 'suspended') await suspendUser(id, reason);
      else await unbanUser(id, reason);
      showFeedback('success', `User account status updated to ${newStatus.toUpperCase()}.`, 'Status Changed');
      await loadUsers();
    } catch (err) {
      showFeedback('error', err.message || 'Failed to update status', 'Status Change Failed');
      throw err;
    }
  }

  const isAllSelected = users.length > 0 && selectedUserIds.length === users.length;

  const columns = [
    {
      key: 'select',
      header: (
        <button
          type="button"
          onClick={toggleSelectAll}
          className="p-1 rounded text-slate-400 hover:text-white transition-colors"
          title={isAllSelected ? 'Deselect All' : 'Select All'}
        >
          {isAllSelected ? (
            <CheckSquare className="h-4 w-4 text-indigo-400" />
          ) : (
            <Square className="h-4 w-4 text-slate-500" />
          )}
        </button>
      ),
      render: (row) => {
        const isSelected = selectedUserIds.includes(row.id);
        return (
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation();
              toggleSelectUser(row.id);
            }}
            className="p-1 rounded text-slate-400 hover:text-white transition-colors"
          >
            {isSelected ? (
              <CheckSquare className="h-4 w-4 text-indigo-400" />
            ) : (
              <Square className="h-4 w-4 text-slate-600" />
            )}
          </button>
        );
      },
    },
    {
      key: 'user',
      header: 'User',
      render: (row) => (
        <div className="flex items-center gap-3">
          <div
            className="cursor-pointer relative group/avatar shrink-0"
            onClick={() =>
              row.avatarUrl &&
              setPreviewPhoto({
                url: row.avatarUrl,
                title: `@${row.username}'s Profile Picture`,
                subtitle: row.displayName,
              })
            }
            title={row.avatarUrl ? 'Click to view full photo' : ''}
          >
            {row.avatarUrl ? (
              <img
                src={row.avatarUrl}
                alt={row.displayName}
                className="h-9 w-9 rounded-full object-cover shadow-sm ring-1 ring-slate-700 group-hover/avatar:ring-indigo-400 transition-all"
                onError={(e) => {
                  e.target.style.display = 'none';
                }}
              />
            ) : (
              <div className="h-9 w-9 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white text-xs font-bold shrink-0 shadow-sm">
                {(row.displayName || row.username || 'U').charAt(0).toUpperCase()}
              </div>
            )}
            {row.avatarUrl && (
              <div className="absolute inset-0 bg-black/40 rounded-full opacity-0 group-hover/avatar:opacity-100 flex items-center justify-center transition-opacity">
                <Eye className="h-3 w-3 text-white" />
              </div>
            )}
          </div>
          <div className="min-w-0">
            <p
              onClick={() => navigate(`/admin/users/${row.id}`)}
              className="font-semibold text-white text-sm leading-tight truncate hover:text-indigo-300 cursor-pointer"
            >
              {row.displayName}
            </p>
            <div className="flex items-center gap-1.5 text-xs text-slate-400 mt-0.5 flex-wrap">
              <span className="font-mono text-indigo-300">@{row.username}</span>
              <span>•</span>
              <CountryFlag code={row.country} className="w-3.5 h-2.5 rounded-sm inline-block" />
              <span>{row.country || 'Global'}</span>
            </div>
          </div>
        </div>
      ),
    },
    {
      key: 'phone',
      header: 'Phone / Email',
      render: (row) => (
        <div className="text-xs space-y-0.5">
          <p className="text-white font-mono">{row.phone || '—'}</p>
          <p className="text-slate-400">{row.email || '—'}</p>
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
        <span className="text-sm font-mono font-semibold text-yellow-400">{row.coins.toLocaleString()}</span>
      ),
    },
    {
      key: 'diamonds',
      header: 'Diamonds',
      render: (row) => (
        <span className="text-sm font-mono font-semibold text-cyan-400">{(row.diamonds || 0).toLocaleString()}</span>
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
            <Eye className="h-4 w-4" aria-hidden="true" />
          </button>
          <button
            title="Edit User"
            onClick={() => setEditModal({ open: true, user: row })}
            className="p-1.5 rounded-lg text-slate-400 hover:text-indigo-400 hover:bg-slate-700 transition-colors"
          >
            <Edit2 className="h-4 w-4" aria-hidden="true" />
          </button>
          {canPerformAction('adjust_user_coins') && (
            <button
              title="Adjust Balance"
              onClick={() => setBalanceModal({ open: true, user: row })}
              className="p-1.5 rounded-lg text-slate-400 hover:text-yellow-400 hover:bg-slate-700 transition-colors"
            >
              <DollarSign className="h-4 w-4" aria-hidden="true" />
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
                <Ban className="h-4 w-4" aria-hidden="true" />
              ) : (
                <UserCheck className="h-4 w-4" aria-hidden="true" />
              )}
            </button>
          )}
          <button
            title="Delete User"
            onClick={() => setDeleteModal({ open: true, user: row })}
            className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700 transition-colors"
          >
            <Trash2 className="h-4 w-4" aria-hidden="true" />
          </button>
        </div>
      ),
    },
  ];

  const totalUsersCount = pagination.total || users.length;
  const activeCount = users.filter((u) => u.status === 'active').length;
  const suspendedCount = users.filter((u) => u.status === 'suspended').length;
  const bannedCount = users.filter((u) => u.status === 'banned').length;

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
            Manage platform users, balances, and account statuses with PostgreSQL persistence.
          </p>
        </div>
        <Button
          variant="primary"
          size="sm"
          className="flex items-center gap-2"
          onClick={() => setCreateModalOpen(true)}
        >
          <Plus className="h-4 w-4" />
          Create User
        </Button>
      </div>

      {/* Floating In-App Toast Notification */}
      <Toast toast={feedback} onClose={() => setFeedback(null)} />

      {/* Filters Bar */}
      <Card className="p-4 flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
        <Input
          placeholder="Search by username, name, phone, or email…"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setCurrentPage(1);
          }}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md w-full min-w-0"
        />
        <div className="flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-slate-400 flex-shrink-0" aria-hidden="true" />
            <div className="flex gap-1 flex-wrap">
              {USER_STATUSES.map((s) => (
                <button
                  key={s}
                  onClick={() => {
                    setStatusFilter(s);
                    setCurrentPage(1);
                  }}
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

          <div className="flex items-center gap-1.5 text-xs text-slate-400 ml-auto sm:ml-0">
            <span>Show:</span>
            {[20, 50, 100].map((sz) => (
              <button
                key={sz}
                onClick={() => {
                  setPageSize(sz);
                  setCurrentPage(1);
                }}
                className={[
                  'px-2 py-1 rounded text-xs font-mono border transition-colors',
                  pageSize === sz
                    ? 'bg-indigo-600 text-white border-indigo-500 font-bold'
                    : 'bg-slate-800 text-slate-400 border-slate-700 hover:text-white',
                ].join(' ')}
              >
                {sz}
              </button>
            ))}
          </div>
        </div>
      </Card>

      {/* Stats row */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        {[
          { label: 'Total Users', value: totalUsersCount,                               color: 'text-white' },
          { label: 'Active',      value: activeCount > 0 ? (totalUsersCount > 0 && activeCount === users.length ? totalUsersCount : activeCount) : 0, color: 'text-emerald-400' },
          { label: 'Suspended',   value: suspendedCount,                                color: 'text-amber-400' },
          { label: 'Banned',      value: bannedCount,                                   color: 'text-red-400' },
        ].map((s) => (
          <Card key={s.label} className="p-4 text-center">
            <p className={`text-2xl font-bold ${s.color}`}>{s.value}</p>
            <p className="text-xs text-slate-400 mt-0.5">{s.label}</p>
          </Card>
        ))}
      </div>

      {loadError && (
        <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 flex items-center justify-between">
          <div className="text-sm">
            <span className="font-semibold">Error loading users: </span>
            {loadError}
          </div>
          <Button variant="outline" size="sm" onClick={loadUsers}>
            Retry
          </Button>
        </div>
      )}

      {/* Table with real pagination */}
      <DataTable
        columns={columns}
        data={users}
        isLoading={isLoading}
        emptyTitle="No users found"
        emptyDescription="Try adjusting your search or status filter."
        pagination={{
          page: pagination.page,
          totalPages: pagination.totalPages,
          total: pagination.total,
        }}
        onPageChange={(newPage) => setCurrentPage(newPage)}
      />

      {/* Floating Multi-User Selection / Batch Actions Toolbar */}
      {selectedUserIds.length > 0 && (
        <div className="sticky bottom-6 z-30 p-4 rounded-xl bg-slate-900/95 border border-indigo-500/40 shadow-2xl backdrop-blur-md flex flex-wrap items-center justify-between gap-4 animate-in fade-in slide-in-from-bottom-4 duration-200">
          <div className="flex items-center gap-3">
            <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-600 text-xs font-bold text-white">
              {selectedUserIds.length}
            </span>
            <div>
              <p className="text-xs font-semibold text-white">
                {selectedUserIds.length} {selectedUserIds.length === 1 ? 'user' : 'users'} selected
              </p>
              <p className="text-[11px] text-slate-400">Perform bulk administrative operations</p>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            <Button
              variant="outline"
              size="xs"
              onClick={() => handleBatchStatus('active')}
              isLoading={isBatchProcessing}
              className="text-emerald-400 hover:text-emerald-300 border-emerald-500/30"
            >
              <UserCheck className="h-3.5 w-3.5 mr-1" /> Activate
            </Button>
            <Button
              variant="outline"
              size="xs"
              onClick={() => handleBatchStatus('suspended')}
              isLoading={isBatchProcessing}
              className="text-amber-400 hover:text-amber-300 border-amber-500/30"
            >
              <AlertTriangle className="h-3.5 w-3.5 mr-1" /> Suspend
            </Button>
            <Button
              variant="danger"
              size="xs"
              onClick={() => handleBatchStatus('banned')}
              isLoading={isBatchProcessing}
            >
              <Ban className="h-3.5 w-3.5 mr-1" /> Ban
            </Button>
            <Button
              variant="outline"
              size="xs"
              onClick={handleBatchExport}
              className="text-indigo-400 border-indigo-500/30"
            >
              <Download className="h-3.5 w-3.5 mr-1" /> Export CSV
            </Button>
            <Button
              variant="danger"
              size="xs"
              onClick={() => setBatchDeleteModalOpen(true)}
              isLoading={isBatchProcessing}
              className="bg-red-600 hover:bg-red-700 text-white"
            >
              <Trash2 className="h-3.5 w-3.5 mr-1" /> Delete ({selectedUserIds.length})
            </Button>
            <button
              onClick={() => setSelectedUserIds([])}
              className="px-2.5 py-1 text-xs text-slate-400 hover:text-white transition-colors"
            >
              Clear Selection
            </button>
          </div>
        </div>
      )}

      {/* Profile Picture High-Res Viewer Modal */}
      {previewPhoto && (
        <ImageViewerModal
          isOpen={true}
          onClose={() => setPreviewPhoto(null)}
          imageUrl={previewPhoto.url}
          title={previewPhoto.title}
          subtitle={previewPhoto.subtitle}
        />
      )}

      {/* Modals */}
      <CreateUserModal
        isOpen={createModalOpen}
        onClose={() => setCreateModalOpen(false)}
        onConfirm={handleCreateUser}
      />
      <EditUserModal
        isOpen={editModal.open}
        onClose={() => setEditModal({ open: false, user: null })}
        user={editModal.user}
        onConfirm={handleEditUser}
      />
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
      <DeleteUserModal
        isOpen={deleteModal.open}
        onClose={() => setDeleteModal({ open: false, user: null })}
        user={deleteModal.user}
        onConfirm={handleDeleteUser}
      />

      {/* Batch Delete Confirmation Modal */}
      <Modal
        isOpen={batchDeleteModalOpen}
        onClose={() => {
          if (!isBatchProcessing) {
            setBatchDeleteModalOpen(false);
            setBatchDeleteReason('');
          }
        }}
        title={`Batch Delete ${selectedUserIds.length} Users`}
        size="md"
      >
        <div className="space-y-4">
          <div className="p-3.5 rounded-lg bg-red-500/10 border border-red-500/30 flex items-start gap-3">
            <AlertTriangle className="h-5 w-5 text-red-400 shrink-0 mt-0.5" />
            <div>
              <p className="text-xs font-semibold text-red-400">Irreversible Permanent Batch Deletion</p>
              <p className="text-[11px] text-slate-300 mt-1">
                This action will permanently remove <span className="font-bold text-white">{selectedUserIds.length} selected user accounts</span>, their wallets, devices, sessions, posts, comments, likes, and relational records from PostgreSQL.
              </p>
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 mb-1.5">
              Deletion Reason (Audit Log)
            </label>
            <Input
              value={batchDeleteReason}
              onChange={(e) => setBatchDeleteReason(e.target.value)}
              placeholder="e.g. Terms violation, spam cleanup, bulk GDPR purge..."
              disabled={isBatchProcessing}
            />
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-slate-700/60">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setBatchDeleteModalOpen(false);
                setBatchDeleteReason('');
              }}
              disabled={isBatchProcessing}
            >
              Cancel
            </Button>
            <Button
              variant="danger"
              size="sm"
              onClick={handleBatchDelete}
              isLoading={isBatchProcessing}
            >
              <Trash2 className="h-4 w-4 mr-1" /> Delete All {selectedUserIds.length} Users Permanently
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}

export default UsersPage;
