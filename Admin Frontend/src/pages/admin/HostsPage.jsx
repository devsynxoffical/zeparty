// ============================================================
// ZeParty Admin Portal — Hosts Management Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Crown, Search, Eye, AlertTriangle, ToggleLeft, ToggleRight, CheckCircle, Video, Mic, ShieldAlert,
  Building, Calendar, DollarSign, Award, Clock, Users, ArrowRight, Settings, Plus, RefreshCw
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import {
  getHosts,
  getHostApplications,
  approveHostApplication,
  rejectHostApplication,
  updateHostStatus,
} from '../../services/modules/hosts.service';
import { formatDate, formatNumber, formatCurrency } from '../../utils/format';
import { usePermission } from '../../hooks/usePermission';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';

function PolicyOverviewCard() {
  const [policyType, setPolicyType] = useState('LIVE');
  const [payoutMode, setPayoutMode] = useState('15-Day Payouts');
  const [minTargetCoins, setMinTargetCoins] = useState(120000);
  const [agencyShare, setAgencyShare] = useState(20);
  const [backupShare, setBackupShare] = useState(10);
  const [isEditingPolicy, setIsEditingPolicy] = useState(false);

  return (
    <Card className="p-5 border-purple-500/30 bg-purple-950/20 mb-6">
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <Badge variant="primary" className="uppercase text-[10px] tracking-wider font-bold">
              Active Host Policy
            </Badge>
            <span className="text-xs text-slate-400 font-mono">v2.4-Production</span>
          </div>
          <h3 className="text-base font-bold text-white">Host Tier & Bi-Monthly Payout Economics</h3>
          <p className="text-xs text-slate-400 mt-0.5">
            Default 15-day payout settlement cycle · Minimum host target: <strong className="text-gold-400">{formatNumber(minTargetCoins)} coins</strong>
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => setIsEditingPolicy(true)}>
            <Settings className="w-3.5 h-3.5 mr-1.5" />
            Configure Policy
          </Button>
        </div>
      </div>

      {isEditingPolicy && (
        <Modal
          isOpen={true}
          onClose={() => setIsEditingPolicy(false)}
          title="Configure Host Payout & Target Policy"
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Payout Mode</label>
              <select
                value={payoutMode}
                onChange={(e) => setPayoutMode(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white focus:outline-none focus:border-purple-500"
              >
                <option value="15-Day Payouts">15-Day Payouts (Bi-Monthly)</option>
                <option value="Daily Payouts">Daily Payouts</option>
                <option value="Weekly Payouts">Weekly Payouts</option>
                <option value="Monthly Payouts">Monthly Payouts</option>
              </select>
            </div>
            <Input
              label="Minimum Host Target (Coins)"
              type="number"
              value={minTargetCoins}
              onChange={(e) => setMinTargetCoins(Number(e.target.value))}
            />
            <div className="grid grid-cols-2 gap-3">
              <Input
                label="Agency Share (%)"
                type="number"
                value={agencyShare}
                onChange={(e) => setAgencyShare(Number(e.target.value))}
              />
              <Input
                label="Backup Share (%)"
                type="number"
                value={backupShare}
                onChange={(e) => setBackupShare(Number(e.target.value))}
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setIsEditingPolicy(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={() => setIsEditingPolicy(false)}>
                Save Policy Settings
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </Card>
  );
}

export function HostsPage() {
  const { logAdminAction } = useAuditLog();
  const [searchParams, setSearchParams] = useSearchParams();
  const typeParam = searchParams.get('type') || 'all';
  const tabParam = searchParams.get('tab') || 'management';

  const [activeTab, setActiveTab] = useState(tabParam); // 'management' | 'applications'
  const [activeHosts, setActiveHosts] = useState([]);
  const [applications, setApplications] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [bdCenterFilter, setBdCenterFilter] = useState('all');
  const [selectedHost, setSelectedHost] = useState(null);
  const [selectedApp, setSelectedApp] = useState(null);
  
  // BD Center Modal State
  const [isBDCenterModalOpen, setIsBDCenterModalOpen] = useState(false);
  
  // Modals
  const [warnHost, setWarnHost] = useState(null);
  const [warnReason, setWarnReason] = useState('');
  const [editTargetHost, setEditTargetHost] = useState(null);
  const [newTargetCoins, setNewTargetCoins] = useState('');
  const [newPayoutTier, setNewPayoutTier] = useState('');
  const [agencyModal, setAgencyModal] = useState({ open: false, host: null, newAgencyName: '', bdCenterId: '', action: 'bind' });
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    if (tabParam && tabParam !== activeTab) {
      setActiveTab(tabParam);
    }
  }, [tabParam]);

  const [fetchError, setFetchError] = useState(null);

  const fetchHostsData = () => {
    setIsLoading(true);
    setFetchError(null);
    Promise.allSettled([
      getHosts(),
      getHostApplications(),
    ]).then(([hostsRes, appsRes]) => {
      if (hostsRes.status === 'fulfilled') {
        const rawHosts = hostsRes.value || [];
        setActiveHosts(rawHosts.map(h => ({
          id: h.id,
          hostId: h.id,
          userId: h.userId,
          name: h.user?.profile?.displayName || h.user?.username || `Host ${h.id.slice(0, 6)}`,
          hostName: h.user?.profile?.displayName || h.user?.username || `Host ${h.id.slice(0, 6)}`,
          username: h.user?.username || `@${h.id.slice(0, 6)}`,
          country: h.user?.profile?.country || 'US',
          status: (h.hostStatus || h.status || 'ACTIVE').toLowerCase(),
          category: h.hostType || h.category || 'LIVE_HOST',
          hostType: h.hostType || 'LIVE_HOST',
          agency: h.agency?.name || 'Independent',
          agencyId: h.agencyId || null,
          bdCenterId: h.agency?.bdCenterId || null,
          currentDiamonds: Number(h.totalDiamondsEarnedMonth || 0),
          targetCoins: Number(h.monthlyTargetCoins || 120000),
          liveHours: Number(h.liveHoursMonth || 0),
          validDays: Number(h.validDaysMonth || 0),
          payoutTier: h.tier || 'Tier 1',
          joinedAt: h.createdAt,
          warnings: [],
        })));
      } else {
        console.error('Failed to load active hosts:', hostsRes.reason);
      }
      if (appsRes.status === 'fulfilled') {
        setApplications(appsRes.value || []);
      } else {
        console.error('Failed to load host applications:', appsRes.reason);
        const errMsg = appsRes.reason?.response?.data?.message || appsRes.reason?.message || 'Failed to load host applications';
        setFetchError(errMsg);
      }
      setIsLoading(false);
    });
  };

  useEffect(() => {
    fetchHostsData();
  }, []);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const activeHostCategory = typeParam === 'audio' ? 'AUDIO_HOST' : 'LIVE_HOST';

  // Toggle active/suspended status
  const handleToggleHostStatus = async (host) => {
    const newStatus = host.status === 'active' ? 'suspended' : 'active';
    try {
      await updateHostStatus(host.id, newStatus.toUpperCase());
      await logAdminAction({
        action: `HOST_${newStatus.toUpperCase()}`,
        module: 'Hosts',
        targetType: 'host',
        targetId: host.id,
        targetName: host.hostName || host.name,
        reason: `Administrator set status to ${newStatus}`,
        riskLevel: 'MEDIUM',
      });

      fetchHostsData();
      showFeedback(`${host.hostName || host.name} status updated to ${newStatus}.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update host status');
    }
  };

  // Issue warning
  const handleWarnHost = async () => {
    if (!warnHost) return;

    await logAdminAction({
      action: 'HOST_WARNING_ISSUED',
      module: 'Hosts',
      targetType: 'host',
      targetId: warnHost.id,
      targetName: warnHost.hostName,
      reason: warnReason || 'Compliance warning issued by administration',
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Warning issued to ${warnHost.hostName}.`);
    setWarnHost(null);
    setWarnReason('');
  };

  // Update target/payout tiers
  const handleUpdateTarget = async () => {
    if (!editTargetHost) return;

    setActiveHosts((prev) => prev.map((h) => {
      if (h.id === editTargetHost.id) {
        return {
          ...h,
          targetCoins: Number(newTargetCoins) || h.targetCoins,
          weeklyRewardUSD: Number(newPayoutTier) || h.weeklyRewardUSD
        };
      }
      return h;
    }));

    await logAdminAction({
      action: 'HOST_TARGET_UPDATED',
      module: 'Hosts',
      targetType: 'host',
      targetId: editTargetHost.id,
      targetName: editTargetHost.hostName,
      reason: `Target updated to ${newTargetCoins} coins, Payout Tier to $${newPayoutTier}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Successfully updated target and payout tier for ${editTargetHost.hostName}.`);
    setEditTargetHost(null);
    setNewTargetCoins('');
    setNewPayoutTier('');
  };

  // Bind/Transfer Agency
  const handleAgencyAction = async () => {
    const { host, newAgencyName, action } = agencyModal;
    if (!host) return;

    setActiveHosts((prev) => prev.map((h) => {
      if (h.id === host.id) {
        const boundDate = new Date().toISOString().split('T')[0];
        const historical = [...(h.historicalAgencies || [])];
        
        // Terminate current contract if exists
        if (historical.length > 0) {
          historical[historical.length - 1] = {
            ...historical[historical.length - 1],
            unboundAt: boundDate,
            reason: `Transfer to ${newAgencyName}`
          };
        }

        // Add new binding record
        historical.push({
          agencyId: `agency-${Math.floor(Math.random() * 1000)}`,
          agencyName: newAgencyName,
          boundAt: boundDate,
          unboundAt: null,
          reason: action === 'bind' ? 'Initial contract binding' : 'Authorized agency transfer'
        });

        return {
          ...h,
          agencyName: newAgencyName,
          historicalAgencies: historical
        };
      }
      return h;
    }));

    await logAdminAction({
      action: action === 'bind' ? 'HOST_AGENCY_BOUND' : 'HOST_AGENCY_TRANSFERRED',
      module: 'Hosts',
      targetType: 'host',
      targetId: host.id,
      targetName: host.hostName,
      reason: `Bound/Transferred to agency ${newAgencyName}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Host agency successfully updated for ${host.hostName}.`);
    setAgencyModal({ open: false, host: null, newAgencyName: '', action: 'bind' });
  };

  // Approve/reject host application
  const handleApproveApplication = async (appId) => {
    try {
      await approveHostApplication(appId);
      fetchHostsData();
      showFeedback(`Host application ${appId} approved.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to approve application');
    }
  };

  const handleRejectApplication = async (appId) => {
    try {
      await rejectHostApplication(appId, 'Application did not satisfy standards.');
      fetchHostsData();
      showFeedback(`Host application ${appId} rejected.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to reject application');
    }
  };

  // Filtered lists
  const filteredHosts = useMemo(() => {
    const q = search.toLowerCase();
    return activeHosts.filter((h) => {
      let matchType = true;
      if (typeParam === 'live') {
        matchType = h.hostType === 'LIVE_HOST' || h.hostType === 'BOTH' || !h.hostType;
      } else if (typeParam === 'audio') {
        matchType = h.hostType === 'AUDIO_HOST' || h.hostType === 'BOTH' || !h.hostType;
      }
      const matchSearch =
        !q ||
        h.id.toLowerCase().includes(q) ||
        (h.hostName && h.hostName.toLowerCase().includes(q)) ||
        (h.username && h.username.toLowerCase().includes(q)) ||
        (h.agencyName && h.agencyName.toLowerCase().includes(q));
      return matchType && matchSearch;
    });
  }, [activeHosts, typeParam, search]);

  const filteredApps = useMemo(() => {
    const q = search.toLowerCase();
    return applications.filter((a) => {
      let matchType = true;
      if (typeParam === 'live') {
        matchType = a.hostType === 'LIVE_HOST' || a.hostType === 'BOTH' || !a.hostType;
      } else if (typeParam === 'audio') {
        matchType = a.hostType === 'AUDIO_HOST' || a.hostType === 'BOTH' || !a.hostType;
      }
      const isPending = a.status === 'pending' || a.status === 'applied';
      const matchStatus =
        statusFilter === 'all' ||
        a.status === statusFilter ||
        (statusFilter === 'pending' && isPending);
      const matchSearch =
        !q ||
        a.id.toLowerCase().includes(q) ||
        (a.userId && String(a.userId).toLowerCase().includes(q)) ||
        (a.applicantName && a.applicantName.toLowerCase().includes(q)) ||
        (a.applicantUsername && a.applicantUsername.toLowerCase().includes(q));
      return matchType && matchStatus && matchSearch;
    });
  }, [applications, typeParam, statusFilter, search]);

  const pendingAppsCount = useMemo(() => {
    return applications.filter((a) => a.status === 'pending' || a.status === 'applied').length;
  }, [applications]);

  const hostColumns = [
    {
      key: 'host',
      header: 'Host Creator',
      render: (row) => (
        <div>
          <div className="flex items-center gap-1.5">
            <p className="text-sm font-bold text-white">{row.hostName}</p>
            {row.hostType === 'AUDIO_HOST' ? (
              <span className="px-1.5 py-0.5 rounded bg-indigo-500/20 text-indigo-300 text-[10px] font-mono border border-indigo-500/40 flex items-center gap-0.5">
                <Mic className="h-2.5 w-2.5" /> AUDIO
              </span>
            ) : (
              <span className="px-1.5 py-0.5 rounded bg-purple-500/20 text-purple-300 text-[10px] font-mono border border-purple-500/40 flex items-center gap-0.5">
                <Video className="h-2.5 w-2.5" /> LIVE
              </span>
            )}
          </div>
          <p className="text-xs text-slate-400">@{row.username} • ID: {row.id}</p>
        </div>
      ),
    },
    {
      key: 'agency',
      header: 'Agency Assignment',
      render: (row) => (
        <div>
          <span className="text-xs text-slate-300 font-semibold">{row.agencyName}</span>
          {row.historicalAgencies?.length > 1 && (
            <p className="text-[10px] text-slate-500 font-mono">({row.historicalAgencies.length} Transfers)</p>
          )}
        </div>
      ),
    },
    {
      key: 'metrics',
      header: 'Audience & Hosting Hours',
      render: (row) => (
        <div>
          <p className="text-xs font-semibold text-sky-400">
            {row.hostType === 'AUDIO_HOST' ? `🎧 ${formatNumber(row.listeners)} Listeners` : `👁️ ${formatNumber(row.listeners)} Viewers`}
          </p>
          <p className="text-[11px] text-slate-400">
            ⏱️ {row.liveHoursThisWeek} hrs this week {row.hostType === 'AUDIO_HOST' ? '(Target: 2h/day)' : '(Target: 1h/day)'}
          </p>
        </div>
      ),
    },
    {
      key: 'target',
      header: 'Target & Progress',
      render: (row) => {
        const pct = Math.min(100, Math.round((row.currentProgressCoins / row.targetCoins) * 100));
        return (
          <div className="w-36">
            <div className="flex justify-between text-xs mb-1">
              <span className="text-gold-400 font-bold">{formatNumber(row.currentProgressCoins)}</span>
              <span className="text-slate-400">/ {formatNumber(row.targetCoins)}</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
              <div className="bg-gold-500 h-1.5 rounded-full" style={{ width: `${pct}%` }} />
            </div>
          </div>
        );
      },
    },
    {
      key: 'payout',
      header: 'Payout Tier',
      render: (row) => (
        <div>
          <span className="text-xs font-bold text-emerald-400">${row.weeklyRewardUSD} / 15 Days</span>
          <p className="text-[10px] text-slate-400">Daily Equivalent: ${(row.weeklyRewardUSD / 15).toFixed(2)}</p>
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
        <div className="flex items-center gap-1">
          <button
            title="Inspect Profile"
            onClick={() => setSelectedHost(row)}
            className="p-1.5 rounded text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
          >
            <Eye className="h-3.5 w-3.5" />
          </button>
          <button
            title="Edit Target / Salary"
            onClick={() => { setEditTargetHost(row); setNewTargetCoins(row.targetCoins); setNewPayoutTier(row.weeklyRewardUSD); }}
            className="p-1.5 rounded text-slate-400 hover:text-gold-400 hover:bg-slate-800 transition-colors"
          >
            <Settings className="h-3.5 w-3.5" />
          </button>
          <button
            title="Transfer Agency"
            onClick={() => setAgencyModal({ open: true, host: row, newAgencyName: row.agencyName, action: 'transfer' })}
            className="p-1.5 rounded text-slate-400 hover:text-indigo-400 hover:bg-slate-800 transition-colors"
          >
            <RefreshCw className="h-3.5 w-3.5" />
          </button>
          <button
            title="Issue warning violation"
            onClick={() => setWarnHost(row)}
            className="p-1.5 rounded text-slate-400 hover:text-amber-400 hover:bg-slate-800 transition-colors"
          >
            <AlertTriangle className="h-3.5 w-3.5" />
          </button>
          <button
            title={row.status === 'active' ? 'Suspend Host' : 'Activate Host'}
            onClick={() => handleToggleHostStatus(row)}
            className={`p-1.5 rounded transition-colors hover:bg-slate-800 ${
              row.status === 'active' ? 'text-rose-400 hover:text-rose-300' : 'text-emerald-400 hover:text-emerald-300'
            }`}
          >
            {row.status === 'active' ? <ToggleLeft className="h-3.5 w-3.5" /> : <ToggleRight className="h-3.5 w-3.5" />}
          </button>
        </div>
      ),
    },
  ];

  const appColumns = [
    {
      key: 'applicant',
      header: 'Applicant',
      render: (row) => (
        <div>
          <p className="text-sm font-semibold text-white">{row.applicantName || 'Applicant'}</p>
          <p className="text-xs text-slate-400">@{row.applicantUsername} • User ID: {row.userId || row.id?.slice(0, 8)}</p>
        </div>
      ),
    },
    {
      key: 'mode',
      header: 'Requested Mode',
      render: (row) => {
        if (row.hostType === 'BOTH') {
          return (
            <span className="px-2 py-0.5 rounded-full bg-gradient-to-r from-purple-500/20 to-indigo-500/20 text-purple-300 text-[11px] font-semibold border border-purple-500/40 inline-flex items-center gap-1">
              <Crown className="w-3 h-3 text-gold-400" /> Live Video & Audio (Hybrid)
            </span>
          );
        }
        if (row.hostType === 'AUDIO_HOST') {
          return (
            <span className="px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 text-[11px] font-semibold border border-indigo-500/40 inline-flex items-center gap-1">
              <Mic className="w-3 h-3" /> Social Audio Host
            </span>
          );
        }
        return (
          <span className="px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-300 text-[11px] font-semibold border border-purple-500/40 inline-flex items-center gap-1">
            <Video className="w-3 h-3" /> Live Video Host
          </span>
        );
      },
    },
    {
      key: 'country',
      header: 'Location',
      render: (row) => {
        const countryCode = row.userProfile?.country || row.country || 'US';
        return (
          <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">
            <CountryFlag code={countryCode} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
            <span>{getCountryShortName(countryCode)}</span>
          </div>
        );
      },
    },
    {
      key: 'submittedAt',
      header: 'Submitted',
      render: (row) => <span className="text-xs text-slate-400">{formatDate(row.submittedAt)}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => {
        const isPending = row.status === 'pending' || row.status === 'applied';
        return isPending ? (
          <div className="flex items-center gap-1.5">
            <Button variant="primary" size="xs" onClick={() => handleApproveApplication(row.id)}>
              <CheckCircle className="w-3.5 h-3.5 mr-1" /> Approve
            </Button>
            <Button variant="danger" size="xs" onClick={() => handleRejectApplication(row.id)}>
              Reject
            </Button>
            <button
              title="Inspect Application Details"
              onClick={() => setSelectedApp(row)}
              className="p-1.5 rounded text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
            >
              <Eye className="w-4 h-4" />
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <span className="text-xs text-slate-500 capitalize">{row.status}</span>
            <button
              title="Inspect Application Details"
              onClick={() => setSelectedApp(row)}
              className="p-1 rounded text-slate-400 hover:text-white hover:bg-slate-800"
            >
              <Eye className="w-3.5 h-3.5" />
            </button>
          </div>
        );
      },
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      {/* Tab Select Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Crown className="h-7 w-7 text-gold-400" />
            Host & Creator Registry
          </h1>
          <p className="text-sm text-slate-400 mt-0.5 font-sans">
            Manage hosts, approve creator verification requests, audit agency bindings, and set targets.
          </p>
        </div>

        {/* Live vs Audio toggle & Refresh */}
        <div className="flex items-center gap-2">
          <div className="flex bg-slate-900 rounded-xl p-1 border border-slate-800">
            <button
              onClick={() => setSearchParams((prev) => { const n = new URLSearchParams(prev); n.set('type', 'all'); return n; })}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-colors ${
                typeParam === 'all' ? 'bg-gold-500 text-slate-950 shadow' : 'text-slate-400 hover:text-white'
              }`}
            >
              All Creators
            </button>
            <button
              onClick={() => setSearchParams((prev) => { const n = new URLSearchParams(prev); n.set('type', 'live'); return n; })}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-colors ${
                typeParam === 'live' ? 'bg-purple-600 text-white shadow shadow-purple-600/20' : 'text-slate-400 hover:text-white'
              }`}
            >
              Live Video Hosts
            </button>
            <button
              onClick={() => setSearchParams((prev) => { const n = new URLSearchParams(prev); n.set('type', 'audio'); return n; })}
              className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-colors ${
                typeParam === 'audio' ? 'bg-indigo-600 text-white shadow shadow-indigo-600/20' : 'text-slate-400 hover:text-white'
              }`}
            >
              Social Audio Hosts
            </button>
          </div>
          <Button variant="outline" size="sm" onClick={fetchHostsData} disabled={isLoading} title="Reload hosts and applications from database">
            <RefreshCw className={`w-3.5 h-3.5 mr-1 ${isLoading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
      </div>

      {fetchError && (
        <div className="p-3 rounded bg-red-500/20 border border-red-500/40 text-red-400 text-xs font-bold flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="h-4 w-4 shrink-0 text-red-400" />
            <span>Connection / Authorization warning: {fetchError}</span>
          </div>
          <Button variant="secondary" size="xs" onClick={fetchHostsData}>Retry</Button>
        </div>
      )}

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Policy Card */}
      <PolicyOverviewCard />

      {/* Tab Sections */}
      <div className="flex gap-6 border-b border-slate-800">
        <button
          onClick={() => {
            setActiveTab('management');
            setSearch('');
            setSearchParams((prev) => {
              const n = new URLSearchParams(prev);
              n.set('tab', 'management');
              return n;
            });
          }}
          className={`pb-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === 'management' ? 'text-gold-400 border-gold-500' : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          Active Members ({filteredHosts.length})
        </button>
        <button
          onClick={() => {
            setActiveTab('applications');
            setSearch('');
            setSearchParams((prev) => {
              const n = new URLSearchParams(prev);
              n.set('tab', 'applications');
              return n;
            });
          }}
          className={`pb-3 text-sm font-semibold transition-colors border-b-2 flex items-center gap-2 ${
            activeTab === 'applications' ? 'text-gold-400 border-gold-500' : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          <span>Applications ({filteredApps.length})</span>
          {pendingAppsCount > 0 && (
            <span className="px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-400 text-[11px] font-bold border border-amber-500/40 animate-pulse">
              {pendingAppsCount} Pending Approval
            </span>
          )}
        </button>
      </div>

      {/* Filter Bar */}
      <Card className="p-4 flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
        <Input
          placeholder="Search by Host ID, name, username, or agency..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md"
        />

        <div className="flex items-center gap-2">
          {activeTab === 'applications' && (
            <div className="flex items-center gap-2">
              <span className="text-xs text-slate-500 font-bold">Status:</span>
              {['all', 'pending', 'approved', 'rejected'].map((st) => (
                <button
                  key={st}
                  onClick={() => setStatusFilter(st)}
                  className={`px-2 py-1 rounded text-xs font-medium uppercase border ${
                    statusFilter === st ? 'bg-indigo-500/20 border-indigo-500/50 text-indigo-400' : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
                  }`}
                >
                  {st}
                </button>
              ))}
            </div>
          )}
        </div>
      </Card>

      {/* Data tables */}
      {activeTab === 'management' && (
        <DataTable
          columns={hostColumns}
          data={filteredHosts}
          isLoading={false}
          emptyTitle="No Active Hosts Found"
          emptyDescription={`No ${typeParam === 'audio' ? 'Audio' : 'Live'} hosts match the filter.`}
        />
      )}

      {activeTab === 'applications' && (
        <DataTable
          columns={appColumns}
          data={filteredApps}
          isLoading={isLoading}
          emptyTitle="No Host Applications"
          emptyDescription="There are no applications matching the filters."
        />
      )}

      {/* Detail Modal */}
      {selectedHost && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedHost(null)}
          title={`Creator Profile: ${selectedHost.hostName}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 flex justify-between items-center">
              <div>
                <p className="text-base font-bold text-white">{selectedHost.hostName}</p>
                <p className="text-slate-400">@{selectedHost.username} • User ID: {selectedHost.userId}</p>
              </div>
              <div className="flex gap-2">
                <Badge variant={selectedHost.hostType === 'AUDIO_HOST' ? 'purple' : 'primary'}>
                  {selectedHost.hostType === 'AUDIO_HOST' ? 'Social Audio Host' : 'Live Video Host'}
                </Badge>
                <StatusBadge status={selectedHost.status} />
              </div>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div className="p-3 rounded-lg bg-slate-800/40 border border-slate-700/50">
                <p className="text-slate-400">Target Progress</p>
                <p className="text-sm font-bold text-gold-400 mt-0.5">🪙 {formatNumber(selectedHost.currentProgressCoins)}</p>
              </div>
              <div className="p-3 rounded-lg bg-slate-800/40 border border-slate-700/50">
                <p className="text-slate-400">Host Target</p>
                <p className="text-sm font-bold text-white mt-0.5">🪙 {formatNumber(selectedHost.targetCoins)}</p>
              </div>
              <div className="p-3 rounded-lg bg-slate-800/40 border border-slate-700/50">
                <p className="text-slate-400">{selectedHost.hostType === 'AUDIO_HOST' ? 'Audio Hosting Hours' : 'Live Hosting Hours'}</p>
                <p className="text-sm font-bold text-sky-400 mt-0.5">{selectedHost.liveHoursThisWeek} hrs</p>
              </div>
              <div className="p-3 rounded-lg bg-slate-800/40 border border-slate-700/50">
                <p className="text-slate-400">Salary Payout</p>
                <p className="text-sm font-bold text-emerald-400 mt-0.5">${selectedHost.weeklyRewardUSD} USD</p>
              </div>
            </div>

            {/* Historical Agency Bindings */}
            <div className="p-3.5 rounded-xl bg-slate-800/50 border border-slate-800 space-y-2">
              <span className="font-bold text-white flex items-center gap-1.5">
                <Building className="h-4 w-4 text-gold-400" />
                Historical Agency Contracts & Movement Timeline
              </span>
              <div className="space-y-1.5">
                {selectedHost.historicalAgencies?.length > 0 ? (
                  selectedHost.historicalAgencies.map((bind, i) => (
                    <div key={i} className="p-2 rounded bg-slate-900 border border-slate-800 flex justify-between items-center text-[11px]">
                      <div>
                        <span className="font-semibold text-white">{bind.agencyName}</span>
                        <p className="text-slate-400 text-[10px]">{bind.reason}</p>
                      </div>
                      <div className="text-right font-mono text-slate-400 text-[10px]">
                        <span>{bind.boundAt}</span> → <span>{bind.unboundAt || 'Present'}</span>
                      </div>
                    </div>
                  ))
                ) : (
                  <p className="text-slate-500 italic">No historical agency bindings (Independent host).</p>
                )}
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedHost(null)}>
                Close Profile
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Edit Target Modal */}
      {editTargetHost && (
        <Modal
          isOpen={true}
          onClose={() => setEditTargetHost(null)}
          title={`Edit Target & Payout: ${editTargetHost.hostName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="New Monthly Target (Coins)"
              type="number"
              value={newTargetCoins}
              onChange={(e) => setNewTargetCoins(e.target.value)}
              placeholder="e.g. 500000"
            />
            <Input
              label="New 15-Day Payout Tier ($ USD)"
              type="number"
              value={newPayoutTier}
              onChange={(e) => setNewPayoutTier(e.target.value)}
              placeholder="e.g. 40"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setEditTargetHost(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleUpdateTarget}>
                Save Target Changes
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Agency Bind/Transfer Modal */}
      {agencyModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setAgencyModal({ open: false, host: null, newAgencyName: '', action: 'bind' })}
          title={`${agencyModal.action === 'bind' ? 'Bind Agency' : 'Transfer Agency Contract'}: ${agencyModal.host?.hostName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Assign or transfer <strong className="text-white">{agencyModal.host?.hostName}</strong> to another management agency. This movement will preserve historical records.
            </p>
            <Input
              label="Target Agency Name"
              value={agencyModal.newAgencyName}
              onChange={(e) => setAgencyModal({ ...agencyModal, newAgencyName: e.target.value })}
              placeholder="e.g. Acoustic Waves Agency"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setAgencyModal({ open: false, host: null, newAgencyName: '', action: 'bind' })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleAgencyAction}>
                Confirm Agency Assignment
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Issue Warning Modal */}
      {warnHost && (
        <Modal
          isOpen={true}
          onClose={() => setWarnHost(null)}
          title={`Issue Warning: ${warnHost.hostName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Describe the violation of community standards for <strong className="text-white">{warnHost.hostName}</strong>. This warning logs into the audit ledger.
            </p>
            <Input
              label="Reason for Violation Warning"
              value={warnReason}
              onChange={(e) => setWarnReason(e.target.value)}
              placeholder="e.g. Failure to maintain required hourly streaming target"
              required
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setWarnHost(null)}>
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={handleWarnHost}>
                Issue Violation warning
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Host Application Review & Inspection Modal */}
      {selectedApp && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedApp(null)}
          title={`Review Host Application: ${selectedApp.applicantName}`}
          size="md"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800 flex justify-between items-center">
              <div>
                <p className="text-sm font-bold text-white">{selectedApp.applicantName}</p>
                <p className="text-slate-400">@{selectedApp.applicantUsername} · User ID: {selectedApp.userId}</p>
                <p className="text-[11px] text-slate-500 mt-0.5">Submitted: {formatDate(selectedApp.submittedAt)}</p>
              </div>
              <div>
                <StatusBadge status={selectedApp.status} />
              </div>
            </div>

            <div className="p-3 rounded-lg bg-purple-950/20 border border-purple-500/30">
              <span className="text-[11px] text-slate-400 font-semibold uppercase">Requested Host Capability</span>
              <p className="text-sm font-bold text-gold-400 mt-1 flex items-center gap-1.5">
                <Crown className="w-4 h-4 text-gold-400" />
                {selectedApp.hostType === 'BOTH'
                  ? 'Live Video & Audio Party Host (Recommended - Full Access)'
                  : selectedApp.hostType === 'AUDIO_HOST'
                  ? 'Social Audio & Party Lounge Host'
                  : 'Live Video Host (1080p Streamer)'}
              </p>
            </div>

            {selectedApp.idCardFrontUrl && (
              <div>
                <p className="text-slate-400 mb-1.5 font-semibold">Government / National ID (Front)</p>
                <div className="rounded-lg overflow-hidden border border-slate-800 bg-slate-900 p-2">
                  <img
                    src={selectedApp.idCardFrontUrl}
                    alt="ID Front"
                    className="max-h-48 w-auto mx-auto object-contain rounded"
                    onError={(e) => { e.target.style.display = 'none'; }}
                  />
                  <a
                    href={selectedApp.idCardFrontUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[11px] text-indigo-400 hover:underline block text-center mt-1"
                  >
                    Open Full Image in New Tab ↗
                  </a>
                </div>
              </div>
            )}

            {selectedApp.idCardBackUrl && (
              <div>
                <p className="text-slate-400 mb-1.5 font-semibold">Government / National ID (Back)</p>
                <div className="rounded-lg overflow-hidden border border-slate-800 bg-slate-900 p-2">
                  <img
                    src={selectedApp.idCardBackUrl}
                    alt="ID Back"
                    className="max-h-48 w-auto mx-auto object-contain rounded"
                    onError={(e) => { e.target.style.display = 'none'; }}
                  />
                  <a
                    href={selectedApp.idCardBackUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[11px] text-indigo-400 hover:underline block text-center mt-1"
                  >
                    Open Full Image in New Tab ↗
                  </a>
                </div>
              </div>
            )}

            {selectedApp.videoSampleUrl && (
              <div className="p-2.5 rounded-lg bg-slate-800/40 border border-slate-700/60 flex items-center justify-between">
                <div>
                  <p className="font-semibold text-white">Video Introduction Sample</p>
                  <p className="text-[11px] text-slate-400 truncate max-w-xs">{selectedApp.videoSampleUrl}</p>
                </div>
                <a
                  href={selectedApp.videoSampleUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="px-2.5 py-1 text-xs rounded bg-indigo-600 text-white font-bold hover:bg-indigo-500"
                >
                  View Sample ↗
                </a>
              </div>
            )}

            <div className="flex justify-end gap-2 pt-3 border-t border-slate-800">
              <Button variant="ghost" size="sm" onClick={() => setSelectedApp(null)}>
                Close
              </Button>
              {(selectedApp.status === 'pending' || selectedApp.status === 'applied') && (
                <>
                  <Button
                    variant="danger"
                    size="sm"
                    onClick={async () => {
                      await handleRejectApplication(selectedApp.id);
                      setSelectedApp(null);
                    }}
                  >
                    Reject Application
                  </Button>
                  <Button
                    variant="primary"
                    size="sm"
                    onClick={async () => {
                      await handleApproveApplication(selectedApp.id);
                      setSelectedApp(null);
                    }}
                  >
                    <CheckCircle className="w-3.5 h-3.5 mr-1" /> Approve Creator
                  </Button>
                </>
              )}
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
