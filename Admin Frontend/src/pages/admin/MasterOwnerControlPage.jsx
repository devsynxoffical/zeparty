import React, { useState } from 'react';
import {
  ShieldAlert,
  Crown,
  Eye,
  EyeOff,
  Lock,
  Activity,
  Terminal,
  UserCheck,
  Zap,
  AlertTriangle,
  RefreshCw,
  Search,
  CheckCircle2,
  Sliders,
  Database,
  DollarSign,
  Radio,
  Coins,
  ShieldCheck,
  TrendingUp
} from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { usePermission } from '../../hooks/usePermission';

export function MasterOwnerControlPage() {
  const { user } = useAuth();
  const { isOwner } = usePermission();

  const [stealthMode, setStealthMode] = useState(true);
  const [globalLockdown, setGlobalLockdown] = useState(false);
  const [activeTab, setActiveTab] = useState('oversight');
  const [searchTarget, setSearchTarget] = useState('');
  const [inspectionResult, setInspectionResult] = useState(null);

  // Mock Super Admin Activity Audit Stream
  const [auditStream] = useState([
    {
      id: 'aud-001',
      admin: 'superadmin',
      role: 'Super Admin',
      action: 'Updated User Balance',
      target: '@user_9923',
      timestamp: '2 mins ago',
      status: 'APPROVED_AUTO',
    },
    {
      id: 'aud-002',
      admin: 'financeadmin',
      role: 'Finance Admin',
      action: 'Approved Withdrawal $450',
      target: 'Transaction #TX-8831',
      timestamp: '14 mins ago',
      status: 'AUDITED',
    },
    {
      id: 'aud-003',
      admin: 'hostadmin',
      role: 'Host Admin',
      action: 'Promoted Host Level',
      target: 'Agency: StarMedia',
      timestamp: '42 mins ago',
      status: 'AUDITED',
    },
    {
      id: 'aud-004',
      admin: 'superadmin',
      role: 'Super Admin',
      action: 'Modified App Feature Flags',
      target: 'Live Audio Bitrate',
      timestamp: '1 hour ago',
      status: 'AUDITED',
    },
  ]);

  if (!isOwner) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] text-center p-6">
        <ShieldAlert className="h-16 w-16 text-rose-500 mb-4 animate-bounce" />
        <h1 className="text-2xl font-bold text-white mb-2">403 — Master Access Restricted</h1>
        <p className="text-slate-400 max-w-md text-sm">
          This portal is reserved strictly for Root System Owners. Your attempt has been logged.
        </p>
      </div>
    );
  }

  const handleInspectUser = (e) => {
    e.preventDefault();
    if (!searchTarget.trim()) return;

    setInspectionResult({
      id: 'usr_master_idx_99',
      username: searchTarget.replace('@', ''),
      realName: 'Verified Account',
      role: 'Standard Host / User',
      walletBalance: '1,420,000 Coins',
      totalSpent: '8,950.00 USD',
      lastLoginIp: '192.168.1.104',
      linkedDevices: 2,
      riskScore: 'LOW (0.02)',
      invisibilityStatus: 'Visible to normal admins',
    });
  };

  return (
    <div className="space-y-6 pb-12">
      {/* Top Banner Header */}
      <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-slate-900 via-amber-950/40 to-slate-900 border border-gold-500/30 p-6 shadow-2xl">
        <div className="absolute right-0 top-0 translate-x-4 -translate-y-4 opacity-10 pointer-events-none">
          <Crown className="h-64 w-64 text-gold-400" />
        </div>

        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 mb-2">
              <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-gold-500/20 text-gold-300 border border-gold-500/40">
                <Crown className="h-3.5 w-3.5" /> ROOT OWNER MASTER PORTAL
              </span>
              <span className="flex items-center gap-1 text-[11px] font-mono text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                STEALTH INVISIBILITY ACTIVE
              </span>
            </div>
            <h1 className="text-2xl md:text-3xl font-extrabold text-white tracking-tight">
              Master System Oversight & Control
            </h1>
            <p className="text-xs md:text-sm text-slate-300 mt-1 max-w-2xl">
              Welcome, <strong className="text-gold-300">{user?.name || 'Root Master'}</strong>. You have complete, silent administrative override across all modules, super admins, users, and financial ledgers.
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={() => setStealthMode(!stealthMode)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold border transition-all ${
                stealthMode
                  ? 'bg-slate-900 text-emerald-300 border-emerald-500/40 shadow-lg shadow-emerald-500/10'
                  : 'bg-amber-500/20 text-amber-300 border-amber-500/40'
              }`}
            >
              {stealthMode ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              {stealthMode ? 'Stealth Mode Enabled' : 'Stealth Mode Off'}
            </button>

            <button
              onClick={() => setGlobalLockdown(!globalLockdown)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold border transition-all ${
                globalLockdown
                  ? 'bg-rose-600 text-white border-rose-500 shadow-lg shadow-rose-600/30 animate-pulse'
                  : 'bg-slate-800 text-slate-300 border-slate-700 hover:border-rose-500/50 hover:text-rose-300'
              }`}
            >
              <Lock className="h-4 w-4" />
              {globalLockdown ? 'EMERGENCY LOCKDOWN ACTIVE' : 'Emergency Override'}
            </button>
          </div>
        </div>
      </div>

      {/* Actionable Executive Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-slate-900/90 border border-slate-800 rounded-xl p-4 flex items-center justify-between shadow-md">
          <div>
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wider">24h Net Revenue</p>
            <p className="text-lg font-extrabold text-gold-400 mt-1 flex items-center gap-1">
              $148,250.00
            </p>
            <p className="text-[11px] text-emerald-400 mt-0.5 flex items-center gap-0.5">
              <TrendingUp className="h-3 w-3" /> +14.2% vs yesterday
            </p>
          </div>
          <div className="h-10 w-10 rounded-xl bg-gold-500/10 border border-gold-500/20 flex items-center justify-center text-gold-400">
            <DollarSign className="h-5 w-5" />
          </div>
        </div>

        <div className="bg-slate-900/90 border border-slate-800 rounded-xl p-4 flex items-center justify-between shadow-md">
          <div>
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wider">Live Rooms & CCU</p>
            <p className="text-lg font-extrabold text-white mt-1">1,240 Rooms</p>
            <p className="text-[11px] text-blue-400 mt-0.5">42.8K active • Peak 58.2K online</p>
          </div>
          <div className="h-10 w-10 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400">
            <Radio className="h-5 w-5" />
          </div>
        </div>

        <div className="bg-slate-900/90 border border-slate-800 rounded-xl p-4 flex items-center justify-between shadow-md">
          <div>
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wider">Circulating Economy</p>
            <p className="text-lg font-extrabold text-emerald-400 mt-1">1.85 Billion Coins</p>
            <p className="text-[11px] text-slate-400 mt-0.5">Reseller Vault: 240M | Burn: 84%</p>
          </div>
          <div className="h-10 w-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
            <Coins className="h-5 w-5" />
          </div>
        </div>

        <div className="bg-slate-900/90 border border-slate-800 rounded-xl p-4 flex items-center justify-between shadow-md">
          <div>
            <p className="text-xs font-medium text-slate-400 uppercase tracking-wider">Security & Risk Shield</p>
            <p className="text-lg font-extrabold text-white mt-1">0 Critical Threats</p>
            <p className="text-[11px] text-emerald-400 mt-0.5">2 Flagged • 100% Protected</p>
          </div>
          <div className="h-10 w-10 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-400">
            <ShieldCheck className="h-5 w-5" />
          </div>
        </div>
      </div>

      {/* Tabs Header */}
      <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
        <button
          onClick={() => setActiveTab('oversight')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-colors ${
            activeTab === 'oversight'
              ? 'bg-gold-500 text-slate-950 font-bold'
              : 'text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <Activity className="h-4 w-4" /> Super Admin Audit Stream
        </button>

        <button
          onClick={() => setActiveTab('inspector')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-colors ${
            activeTab === 'inspector'
              ? 'bg-gold-500 text-slate-950 font-bold'
              : 'text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <Search className="h-4 w-4" /> Silent User & Room Inspector
        </button>

        <button
          onClick={() => setActiveTab('system')}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-colors ${
            activeTab === 'system'
              ? 'bg-gold-500 text-slate-950 font-bold'
              : 'text-slate-400 hover:text-white hover:bg-slate-800'
          }`}
        >
          <Sliders className="h-4 w-4" /> Emergency System Overrides
        </button>
      </div>

      {/* Tab Content 1: Super Admin Audit Stream */}
      {activeTab === 'oversight' && (
        <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-6 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Terminal className="h-4 w-4 text-gold-400" />
                Live Super Admin Action Feed
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Every action taken by Super Admins and lower tier managers is silently tracked here in real-time.
              </p>
            </div>
            <button className="flex items-center gap-1.5 text-xs text-slate-400 hover:text-white bg-slate-800 px-3 py-1.5 rounded-lg border border-slate-700">
              <RefreshCw className="h-3.5 w-3.5" /> Refresh Audit Stream
            </button>
          </div>

          <div className="overflow-x-auto border border-slate-800 rounded-xl">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-slate-950 text-slate-400 font-semibold border-b border-slate-800 uppercase tracking-wider text-[10px]">
                <tr>
                  <th className="p-3">Admin Account</th>
                  <th className="p-3">Role</th>
                  <th className="p-3">Action Executed</th>
                  <th className="p-3">Target / Resource</th>
                  <th className="p-3">Time</th>
                  <th className="p-3 text-right">Master Audit</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 font-mono">
                {auditStream.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-800/40">
                    <td className="p-3 font-semibold text-white flex items-center gap-2">
                      <span className="h-2 w-2 rounded-full bg-blue-400"></span>
                      @{item.admin}
                    </td>
                    <td className="p-3 text-slate-400">{item.role}</td>
                    <td className="p-3 text-gold-300 font-sans font-medium">{item.action}</td>
                    <td className="p-3 text-slate-300">{item.target}</td>
                    <td className="p-3 text-slate-500 text-[11px]">{item.timestamp}</td>
                    <td className="p-3 text-right">
                      <span className="inline-flex items-center gap-1 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-2 py-0.5 rounded text-[10px] font-sans font-semibold">
                        <CheckCircle2 className="h-3 w-3" /> VERIFIED
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tab Content 2: Silent User Inspector */}
      {activeTab === 'inspector' && (
        <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-6 space-y-6">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <Search className="h-4 w-4 text-gold-400" />
              Silent Inspection Portal
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Inspect any user profile, room, or transaction without leaving audit logs or sending notifications.
            </p>
          </div>

          <form onSubmit={handleInspectUser} className="flex gap-3 max-w-xl">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-3 h-4 w-4 text-slate-500" />
              <input
                type="text"
                placeholder="Enter User ID, @username, or phone number..."
                value={searchTarget}
                onChange={(e) => setSearchTarget(e.target.value)}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-10 pr-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-gold-500"
              />
            </div>
            <button
              type="submit"
              className="bg-gold-500 hover:bg-gold-400 text-slate-950 font-bold px-5 py-2.5 rounded-xl text-xs transition-colors"
            >
              Inspect Silently
            </button>
          </form>

          {inspectionResult && (
            <div className="bg-slate-950 border border-gold-500/30 rounded-xl p-5 space-y-4">
              <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                <div className="flex items-center gap-3">
                  <div className="h-10 w-10 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-gold-400 font-bold text-sm">
                    {inspectionResult.username[0]?.toUpperCase()}
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-white">@{inspectionResult.username}</h4>
                    <p className="text-xs text-slate-400">{inspectionResult.realName} • ID: {inspectionResult.id}</p>
                  </div>
                </div>
                <span className="text-xs text-emerald-400 bg-emerald-500/10 px-2.5 py-1 rounded-lg border border-emerald-500/20 font-mono">
                  Silent Mode Active
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
                <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-500 text-[11px] block">Wallet Balance</span>
                  <span className="font-bold text-gold-300 text-sm">{inspectionResult.walletBalance}</span>
                </div>
                <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-500 text-[11px] block">Total Spent (USD)</span>
                  <span className="font-bold text-white text-sm">{inspectionResult.totalSpent}</span>
                </div>
                <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
                  <span className="text-slate-500 text-[11px] block">Risk Score</span>
                  <span className="font-bold text-emerald-400 text-sm">{inspectionResult.riskScore}</span>
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Tab Content 3: Emergency Overrides */}
      {activeTab === 'system' && (
        <div className="bg-slate-900/90 border border-slate-800 rounded-2xl p-6 space-y-6">
          <div>
            <h3 className="text-base font-bold text-white flex items-center gap-2">
              <Sliders className="h-4 w-4 text-rose-400" />
              Master Root Emergency Overrides
            </h3>
            <p className="text-xs text-slate-400 mt-0.5">
              Execute immediate root-level controls that supersede all Super Admin rules and app policies.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 space-y-3">
              <div className="flex items-center gap-2 text-amber-400 font-bold text-sm">
                <AlertTriangle className="h-4 w-4" /> Global Financial Freeze
              </div>
              <p className="text-xs text-slate-400">
                Immediately halt all coin recharges, reseller transfers, and withdrawals across the entire platform.
              </p>
              <button className="w-full bg-slate-900 hover:bg-amber-500/20 text-amber-300 border border-amber-500/30 py-2 rounded-lg text-xs font-semibold transition-colors">
                Toggle Financial Freeze
              </button>
            </div>

            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 space-y-3">
              <div className="flex items-center gap-2 text-rose-400 font-bold text-sm">
                <ShieldAlert className="h-4 w-4" /> Super Admin Lockout
              </div>
              <p className="text-xs text-slate-400">
                Temporarily revoke permissions for all active Super Admin sessions in case of compromised accounts.
              </p>
              <button className="w-full bg-slate-900 hover:bg-rose-500/20 text-rose-300 border border-rose-500/30 py-2 rounded-lg text-xs font-semibold transition-colors">
                Execute Super Admin Revoke
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default MasterOwnerControlPage;
