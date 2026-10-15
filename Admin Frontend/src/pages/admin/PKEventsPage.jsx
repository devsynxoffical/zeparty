// ============================================================
// ZeParty Admin Portal — PK Match Operations & Management (JSX)
// Complete Redesign — Authoritative 2026 Client Specification
// ============================================================

import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
  Swords,
  ShieldAlert,
  Settings,
  Search,
  RefreshCw,
  Square,
  Users,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Clock,
  Ban,
  History,
  Eye,
  Edit3,
  Tv,
  Mic,
  Award,
} from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getAdminMatches,
  forceStopMatch,
  getPKSettings,
  updatePKSettings,
  getPKRestrictions,
  createPKRestriction,
  revokePKRestriction,
  reviseMatchResult,
  getMatchDetails,
} from '../../services/modules/pkEvents.service';

export function PKEventsPage() {
  const { addLog } = useAuditLog();

  // Active Tab
  const [activeTab, setActiveTab] = useState('live'); // 'live' | 'history' | 'settings' | 'restrictions'

  // Data States
  const [liveMatches, setLiveMatches] = useState([]);
  const [historyMatches, setHistoryMatches] = useState([]);
  const [historyMeta, setHistoryMeta] = useState({ total: 0, page: 1, limit: 20 });
  const [historyPage, setHistoryPage] = useState(1);
  const [settings, setSettings] = useState(null);
  const [restrictions, setRestrictions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [feedback, setFeedback] = useState(null);

  // Filters
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState('ALL');

  // Modals State
  const [forceStopModalMatch, setForceStopModalMatch] = useState(null);
  const [forceStopReason, setForceStopReason] = useState('');
  const [isSubmittingForceStop, setIsSubmittingForceStop] = useState(false);

  const [inspectModalMatchId, setInspectModalMatchId] = useState(null);
  const [inspectedMatch, setInspectedMatch] = useState(null);
  const [isLoadingInspect, setIsLoadingInspect] = useState(false);

  const [revisionModalMatch, setRevisionModalMatch] = useState(null);
  const [revisionForm, setRevisionForm] = useState({
    reason: '',
    revisedScoreA: 0,
    revisedScoreB: 0,
    revisedWinnerHostId: '',
    revisedIsDraw: false,
  });
  const [isSubmittingRevision, setIsSubmittingRevision] = useState(false);

  const [isAddRestrictionModalOpen, setIsAddRestrictionModalOpen] = useState(false);
  const [restrictionForm, setRestrictionForm] = useState({
    targetType: 'USER',
    targetId: '',
    reason: '',
    durationHours: 24,
  });
  const [isSubmittingRestriction, setIsSubmittingRestriction] = useState(false);

  const showToast = (msg, isError = false) => {
    setFeedback({ msg, isError });
    setTimeout(() => setFeedback(null), 4000);
  };

  // Fetch Live Matches
  const fetchLiveMatches = useCallback(async () => {
    try {
      const res = await getAdminMatches({ limit: 50 });
      const active = (res.matches || []).filter((m) =>
        ['ACTIVE', 'COUNTDOWN', 'PREPARING', 'PENDING'].includes(m.status)
      );
      setLiveMatches(active);
    } catch (err) {
      console.error('Failed to fetch live matches:', err);
    }
  }, []);

  // Fetch History Matches
  const fetchHistory = useCallback(async (page = 1, searchQuery = '') => {
    try {
      const res = await getAdminMatches({
        page,
        limit: 20,
        search: searchQuery || undefined,
      });
      const concluded = (res.matches || []).filter((m) =>
        ['FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED', 'EXPIRED'].includes(m.status)
      );
      setHistoryMatches(concluded);
      setHistoryMeta(res.meta || { total: concluded.length, page, limit: 20 });
    } catch (err) {
      console.error('Failed to fetch history:', err);
    }
  }, []);

  // Fetch Settings
  const fetchSettings = useCallback(async () => {
    try {
      const data = await getPKSettings();
      if (data) setSettings(data);
    } catch (err) {
      console.error('Failed to fetch settings:', err);
    }
  }, []);

  // Fetch Restrictions
  const fetchRestrictions = useCallback(async () => {
    try {
      const res = await getPKRestrictions({ limit: 50 });
      setRestrictions(res.restrictions || []);
    } catch (err) {
      console.error('Failed to fetch restrictions:', err);
    }
  }, []);

  // Initial Load
  useEffect(() => {
    setIsLoading(true);
    Promise.all([fetchLiveMatches(), fetchHistory(1), fetchSettings(), fetchRestrictions()])
      .finally(() => setIsLoading(false));
  }, [fetchLiveMatches, fetchHistory, fetchSettings, fetchRestrictions]);

  // Periodic Refresh for Live Matches (every 10 seconds)
  useEffect(() => {
    if (activeTab === 'live') {
      const timer = setInterval(() => {
        fetchLiveMatches();
      }, 10000);
      return () => clearInterval(timer);
    }
  }, [activeTab, fetchLiveMatches]);

  // Handle Force Stop Submit
  const handleConfirmForceStop = async () => {
    if (!forceStopModalMatch || !forceStopReason.trim()) {
      showToast('Please provide a reason for force stopping this match.', true);
      return;
    }

    setIsSubmittingForceStop(true);
    try {
      await forceStopMatch(forceStopModalMatch.id, forceStopReason.trim());
      addLog(
        'PK_MATCH_FORCE_STOPPED',
        forceStopModalMatch.id,
        'PK Matches',
        `Admin force-stopped match ${forceStopModalMatch.id}. Reason: ${forceStopReason}`
      );
      showToast(`Match ${forceStopModalMatch.id} force-stopped successfully.`);
      setForceStopModalMatch(null);
      setForceStopReason('');
      await fetchLiveMatches();
      await fetchHistory(1);
    } catch (err) {
      showToast(err.response?.data?.error || err.message || 'Force stop failed.', true);
    } finally {
      setIsSubmittingForceStop(false);
    }
  };

  // Handle Inspect Match
  const handleOpenInspect = async (matchId) => {
    setInspectModalMatchId(matchId);
    setIsLoadingInspect(true);
    try {
      const details = await getMatchDetails(matchId);
      setInspectedMatch(details);
    } catch (err) {
      showToast('Failed to load match snapshot.', true);
      setInspectModalMatchId(null);
    } finally {
      setIsLoadingInspect(false);
    }
  };

  // Handle Open Revision Modal
  const handleOpenRevision = (match) => {
    setRevisionModalMatch(match);
    setRevisionForm({
      reason: '',
      revisedScoreA: Number(match.scoreA || 0),
      revisedScoreB: Number(match.scoreB || 0),
      revisedWinnerHostId: match.winnerHostId || '',
      revisedIsDraw: Boolean(match.isDraw),
    });
  };

  // Submit Result Revision
  const handleSubmitRevision = async () => {
    if (!revisionForm.reason.trim()) {
      showToast('Audited revision reason is required.', true);
      return;
    }

    setIsSubmittingRevision(true);
    try {
      await reviseMatchResult(revisionModalMatch.id, revisionForm);
      addLog(
        'PK_RESULT_REVISED',
        revisionModalMatch.id,
        'PK Matches',
        `Audited result revision for ${revisionModalMatch.id}. Reason: ${revisionForm.reason}`
      );
      showToast(`Match ${revisionModalMatch.id} result revised successfully.`);
      setRevisionModalMatch(null);
      await fetchHistory(historyPage, search);
    } catch (err) {
      showToast(err.response?.data?.error || err.message || 'Result revision failed.', true);
    } finally {
      setIsSubmittingRevision(false);
    }
  };

  // Handle Save Settings
  const handleSaveSettings = async (e) => {
    e.preventDefault();
    if (!settings) return;

    try {
      const updated = await updatePKSettings(settings);
      setSettings(updated);
      addLog('PK_SETTINGS_UPDATED', 'default', 'PK Matches', 'Platform PK operational settings updated');
      showToast('PK system settings saved successfully.');
    } catch (err) {
      showToast(err.response?.data?.error || err.message || 'Failed to save settings.', true);
    }
  };

  // Handle Create Restriction
  const handleCreateRestriction = async (e) => {
    e.preventDefault();
    if (!restrictionForm.targetId.trim() || !restrictionForm.reason.trim()) {
      showToast('Target ID and Reason are required.', true);
      return;
    }

    setIsSubmittingRestriction(true);
    try {
      await createPKRestriction(restrictionForm);
      addLog(
        'PK_RESTRICTION_ADDED',
        restrictionForm.targetId,
        'PK Matches',
        `Restricted ${restrictionForm.targetType} ${restrictionForm.targetId}. Reason: ${restrictionForm.reason}`
      );
      showToast('PK restriction applied successfully.');
      setIsAddRestrictionModalOpen(false);
      setRestrictionForm({ targetType: 'USER', targetId: '', reason: '', durationHours: 24 });
      await fetchRestrictions();
    } catch (err) {
      showToast(err.response?.data?.error || err.message || 'Failed to apply restriction.', true);
    } finally {
      setIsSubmittingRestriction(false);
    }
  };

  // Handle Revoke Restriction
  const handleRevokeRestriction = async (id) => {
    try {
      await revokePKRestriction(id);
      addLog('PK_RESTRICTION_REVOKED', id, 'PK Matches', `Revoked restriction ${id}`);
      showToast('Restriction revoked.');
      await fetchRestrictions();
    } catch (err) {
      showToast('Failed to revoke restriction.', true);
    }
  };

  // Filtered Live Matches
  const filteredLiveMatches = useMemo(() => {
    return liveMatches.filter((m) => {
      const matchSearch =
        m.id.toLowerCase().includes(search.toLowerCase()) ||
        m.roomAId?.toLowerCase().includes(search.toLowerCase()) ||
        m.roomBId?.toLowerCase().includes(search.toLowerCase()) ||
        m.hostA?.username?.toLowerCase().includes(search.toLowerCase()) ||
        m.hostB?.username?.toLowerCase().includes(search.toLowerCase());

      const matchType = typeFilter === 'ALL' || m.roomType === typeFilter;
      return matchSearch && matchType;
    });
  }, [liveMatches, search, typeFilter]);

  // Statistics
  const activeCount = liveMatches.filter((m) => m.status === 'ACTIVE').length;
  const preparingCount = liveMatches.filter((m) => ['PREPARING', 'COUNTDOWN', 'PENDING'].includes(m.status)).length;
  const activeRestrictionsCount = restrictions.filter((r) => r.status === 'ACTIVE').length;

  return (
    <div className="space-y-6">
      {/* Toast Feedback */}
      {feedback && (
        <div
          className={`fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl shadow-2xl flex items-center gap-3 text-sm font-medium border ${
            feedback.isError
              ? 'bg-rose-950/90 text-rose-200 border-rose-800'
              : 'bg-emerald-950/90 text-emerald-200 border-emerald-800'
          }`}
        >
          {feedback.isError ? <AlertTriangle className="h-5 w-5 text-rose-400" /> : <CheckCircle className="h-5 w-5 text-emerald-400" />}
          <span>{feedback.msg}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Swords className="h-7 w-7 text-gold-400" />
            PK Match Management
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Realtime 1v1 Room Battles • Authoritative Scoring • Administrative Governance
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              fetchLiveMatches();
              fetchHistory(historyPage, search);
              fetchSettings();
              fetchRestrictions();
              showToast('Data refreshed.');
            }}
          >
            <RefreshCw className="h-4 w-4 mr-1 text-gold-400" /> Refresh All
          </Button>
        </div>
      </div>

      {/* Metric Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          title="Active PK Battles"
          value={activeCount}
          subtitle="Currently streaming 1v1"
          icon={Swords}
          iconColor="text-gold-400"
        />
        <StatCard
          title="In Preparation / Countdown"
          value={preparingCount}
          subtitle="Handshaking readiness"
          icon={Clock}
          iconColor="text-indigo-400"
        />
        <StatCard
          title="System Status"
          value={settings?.audioPkEnabled && settings?.videoPkEnabled ? 'Full Active' : 'Restricted'}
          subtitle={`Audio: ${settings?.audioPkEnabled ? 'ON' : 'OFF'} | Video: ${settings?.videoPkEnabled ? 'ON' : 'OFF'}`}
          icon={Tv}
          iconColor="text-emerald-400"
        />
        <StatCard
          title="Active Restrictions"
          value={activeRestrictionsCount}
          subtitle="Users & Rooms suspended"
          icon={ShieldAlert}
          iconColor="text-rose-400"
        />
      </div>

      {/* Main Tabs Navigation */}
      <div className="flex items-center gap-2 border-b border-slate-800 pb-2">
        <button
          onClick={() => setActiveTab('live')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
            activeTab === 'live'
              ? 'bg-gold-500/10 text-gold-400 border border-gold-500/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-800/40'
          }`}
        >
          <Swords className="h-4 w-4" /> Live Monitor ({liveMatches.length})
        </button>
        <button
          onClick={() => setActiveTab('history')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
            activeTab === 'history'
              ? 'bg-gold-500/10 text-gold-400 border border-gold-500/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-800/40'
          }`}
        >
          <History className="h-4 w-4" /> Match History & Revisions
        </button>
        <button
          onClick={() => setActiveTab('settings')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
            activeTab === 'settings'
              ? 'bg-gold-500/10 text-gold-400 border border-gold-500/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-800/40'
          }`}
        >
          <Settings className="h-4 w-4" /> System Settings
        </button>
        <button
          onClick={() => setActiveTab('restrictions')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
            activeTab === 'restrictions'
              ? 'bg-gold-500/10 text-gold-400 border border-gold-500/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-800/40'
          }`}
        >
          <ShieldAlert className="h-4 w-4" /> Restrictions ({restrictions.length})
        </button>
      </div>

      {/* ─────────────────────────────────────────────────────────── */}
      {/* TAB 1: LIVE MATCH MONITOR */}
      {/* ─────────────────────────────────────────────────────────── */}
      {activeTab === 'live' && (
        <Card>
          <CardHeader>
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 w-full">
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <span className="relative flex h-2.5 w-2.5">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
                  </span>
                  Live PK Matches
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">Authoritative real-time sessions currently executing on server</p>
              </div>

              <div className="flex items-center gap-3 w-full sm:w-auto">
                <select
                  value={typeFilter}
                  onChange={(e) => setTypeFilter(e.target.value)}
                  className="bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-white focus:border-gold-500 outline-none"
                >
                  <option value="ALL">All Modes</option>
                  <option value="LIVE_VIDEO">Live Video</option>
                  <option value="AUDIO_PARTY">Audio Party</option>
                </select>

                <div className="relative w-full sm:w-64">
                  <Search className="h-3.5 w-3.5 text-slate-400 absolute left-2.5 top-2.5" />
                  <Input
                    placeholder="Search Match ID, Host, Room..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    className="pl-8 text-xs py-1.5"
                  />
                </div>
              </div>
            </div>
          </CardHeader>

          <DataTable
            isLoading={isLoading}
            data={filteredLiveMatches}
            emptyMessage="No active PK battles currently running."
            columns={[
              {
                key: 'id',
                header: 'Match ID / Mode',
                render: (m) => (
                  <div>
                    <span className="font-mono text-xs text-white font-semibold">{m.id}</span>
                    <div className="flex items-center gap-1.5 mt-1">
                      <Badge variant={m.roomType === 'LIVE_VIDEO' ? 'purple' : 'default'} className="text-[10px]">
                        {m.roomType === 'LIVE_VIDEO' ? <Tv className="h-2.5 w-2.5 mr-1 inline" /> : <Mic className="h-2.5 w-2.5 mr-1 inline" />}
                        {m.roomType}
                      </Badge>
                      <span className="text-[10px] text-slate-500">{m.region || 'GLOBAL'}</span>
                    </div>
                  </div>
                ),
              },
              {
                key: 'sideA',
                header: 'Side A (Blue)',
                render: (m) => (
                  <div className="flex items-center gap-2">
                    <img
                      src={m.hostA?.avatarUrl || 'https://via.placeholder.com/32'}
                      alt="Host A"
                      className="w-7 h-7 rounded-full border border-sky-500/40 object-cover"
                    />
                    <div>
                      <p className="text-xs font-bold text-sky-300">
                        {m.hostA?.profile?.displayName || m.hostA?.username || m.hostAUserId}
                      </p>
                      <p className="text-[10px] text-slate-400 truncate max-w-[120px]">{m.roomA?.title || m.roomAId}</p>
                    </div>
                  </div>
                ),
              },
              {
                key: 'scores',
                header: 'Score (A vs B)',
                render: (m) => {
                  const scoreA = Number(m.scoreA || 0);
                  const scoreB = Number(m.scoreB || 0);
                  return (
                    <div className="flex items-center gap-2">
                      <span className={`text-xs font-mono font-bold ${scoreA >= scoreB ? 'text-sky-400' : 'text-slate-400'}`}>
                        {formatNumber(scoreA)}
                      </span>
                      <span className="text-[10px] text-slate-600 font-bold">:</span>
                      <span className={`text-xs font-mono font-bold ${scoreB >= scoreA ? 'text-rose-400' : 'text-slate-400'}`}>
                        {formatNumber(scoreB)}
                      </span>
                    </div>
                  );
                },
              },
              {
                key: 'sideB',
                header: 'Side B (Red)',
                render: (m) => (
                  <div className="flex items-center gap-2">
                    <img
                      src={m.hostB?.avatarUrl || 'https://via.placeholder.com/32'}
                      alt="Host B"
                      className="w-7 h-7 rounded-full border border-rose-500/40 object-cover"
                    />
                    <div>
                      <p className="text-xs font-bold text-rose-300">
                        {m.hostB?.profile?.displayName || m.hostB?.username || m.hostBUserId}
                      </p>
                      <p className="text-[10px] text-slate-400 truncate max-w-[120px]">{m.roomB?.title || m.roomBId}</p>
                    </div>
                  </div>
                ),
              },
              {
                key: 'status',
                header: 'Status',
                render: (m) => (
                  <div>
                    <StatusBadge status={m.status.toLowerCase()} />
                    <p className="text-[10px] text-slate-500 mt-0.5">Rev #{m.stateVersion}</p>
                  </div>
                ),
              },
              {
                key: 'duration',
                header: 'Duration',
                render: (m) => (
                  <div className="text-xs text-slate-300">
                    <span className="font-mono">{m.durationSeconds}s</span>
                    {m.startAt && (
                      <p className="text-[10px] text-slate-500">
                        Started: {new Date(m.startAt).toLocaleTimeString()}
                      </p>
                    )}
                  </div>
                ),
              },
              {
                key: 'actions',
                header: 'Admin Actions',
                render: (m) => (
                  <div className="flex items-center gap-2">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleOpenInspect(m.id)}
                      className="text-xs py-1 px-2 text-indigo-300 hover:text-white"
                    >
                      <Eye className="h-3 w-3 mr-1" /> Inspect
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        setForceStopModalMatch(m);
                        setForceStopReason('');
                      }}
                      className="text-xs py-1 px-2 border-rose-800 text-rose-400 hover:bg-rose-950/40"
                    >
                      <Square className="h-3 w-3 mr-1" /> Force Stop
                    </Button>
                  </div>
                ),
              },
            ]}
          />
        </Card>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* TAB 2: MATCH HISTORY & AUDITED REVISIONS */}
      {/* ─────────────────────────────────────────────────────────── */}
      {activeTab === 'history' && (
        <Card>
          <CardHeader>
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 w-full">
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <History className="h-5 w-5 text-gold-400" />
                  PK Match History & Audit Trail
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">Durable match outcomes, deterministic results, and audited corrections</p>
              </div>

              <div className="flex items-center gap-3 w-full sm:w-auto">
                <div className="relative w-full sm:w-72">
                  <Search className="h-3.5 w-3.5 text-slate-400 absolute left-2.5 top-2.5" />
                  <Input
                    placeholder="Search Match ID, Room ID..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') fetchHistory(1, search);
                    }}
                    className="pl-8 text-xs py-1.5"
                  />
                </div>
                <Button size="sm" onClick={() => fetchHistory(1, search)}>
                  Search
                </Button>
              </div>
            </div>
          </CardHeader>

          <DataTable
            isLoading={isLoading}
            data={historyMatches}
            emptyMessage="No historical PK matches found."
            columns={[
              {
                key: 'id',
                header: 'Match ID / Date',
                render: (m) => (
                  <div>
                    <span className="font-mono text-xs text-white font-semibold">{m.id}</span>
                    <p className="text-[10px] text-slate-500 mt-0.5">
                      {new Date(m.createdAt).toLocaleDateString()} {new Date(m.createdAt).toLocaleTimeString()}
                    </p>
                    {m.revisionNumber > 0 && (
                      <Badge variant="warning" className="text-[9px] mt-1 py-0">
                        Revised (v{m.revisionNumber})
                      </Badge>
                    )}
                  </div>
                ),
              },
              {
                key: 'roomType',
                header: 'Mode',
                render: (m) => (
                  <Badge variant={m.roomType === 'LIVE_VIDEO' ? 'purple' : 'default'} className="text-[10px]">
                    {m.roomType}
                  </Badge>
                ),
              },
              {
                key: 'contestants',
                header: 'Participants',
                render: (m) => (
                  <div className="text-xs space-y-0.5">
                    <p className="text-sky-300">
                      Blue: {m.hostA?.profile?.displayName || m.hostA?.username || m.hostAUserId}
                    </p>
                    <p className="text-rose-300">
                      Red: {m.hostB?.profile?.displayName || m.hostB?.username || m.hostBUserId}
                    </p>
                  </div>
                ),
              },
              {
                key: 'finalScore',
                header: 'Final Score',
                render: (m) => (
                  <div className="font-mono text-xs">
                    <span className="text-sky-400 font-bold">{formatNumber(Number(m.scoreA || 0))}</span>
                    <span className="text-slate-600 font-bold mx-1">:</span>
                    <span className="text-rose-400 font-bold">{formatNumber(Number(m.scoreB || 0))}</span>
                  </div>
                ),
              },
              {
                key: 'outcome',
                header: 'Outcome / Winner',
                render: (m) => {
                  if (m.status === 'FORFEIT') {
                    return <Badge variant="warning">FORFEIT</Badge>;
                  }
                  if (m.status === 'ABORTED') {
                    return <Badge variant="danger">ABORTED</Badge>;
                  }
                  if (m.isDraw) {
                    return <Badge variant="secondary">DRAW (Equal Score)</Badge>;
                  }
                  const isA = m.winnerHostId === m.hostAUserId;
                  return (
                    <Badge variant="success">
                      <Award className="h-3 w-3 mr-1 inline" />
                      Winner: {isA ? 'Blue (Side A)' : 'Red (Side B)'}
                    </Badge>
                  );
                },
              },
              {
                key: 'endReason',
                header: 'End Reason',
                render: (m) => (
                  <span className="text-xs text-slate-400 font-mono truncate max-w-[140px] block" title={m.endReason}>
                    {m.endReason || 'NORMAL_COMPLETION'}
                  </span>
                ),
              },
              {
                key: 'actions',
                header: 'Actions',
                render: (m) => (
                  <div className="flex items-center gap-1.5">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleOpenInspect(m.id)}
                      className="text-xs py-1 px-2 text-indigo-300 hover:text-white"
                    >
                      <Eye className="h-3 w-3 mr-1" /> Inspect
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleOpenRevision(m)}
                      className="text-xs py-1 px-2 border-amber-800 text-amber-400 hover:bg-amber-950/40"
                    >
                      <Edit3 className="h-3 w-3 mr-1" /> Revise
                    </Button>
                  </div>
                ),
              },
            ]}
          />
        </Card>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* TAB 3: PK SYSTEM CONFIGURATION */}
      {/* ─────────────────────────────────────────────────────────── */}
      {activeTab === 'settings' && (
        <Card>
          <CardHeader>
            <div>
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Settings className="h-5 w-5 text-gold-400" />
                Authoritative PK System Settings
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Controls room eligibility, timeouts, durations, and rate limits across the platform
              </p>
            </div>
          </CardHeader>

          {settings ? (
            <form onSubmit={handleSaveSettings} className="p-6 space-y-6 max-w-3xl">
              {/* Feature Enablement */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 p-4 rounded-xl bg-slate-900 border border-slate-800">
                <label className="flex items-center gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded bg-slate-800 border-slate-700 text-gold-500 focus:ring-gold-500"
                    checked={settings.audioPkEnabled}
                    onChange={(e) => setSettings({ ...settings, audioPkEnabled: e.target.checked })}
                  />
                  <div>
                    <span className="text-sm font-semibold text-white">Audio PK Enabled</span>
                    <p className="text-xs text-slate-400">Allow Audio Party rooms to send & accept PK matches</p>
                  </div>
                </label>

                <label className="flex items-center gap-3 cursor-pointer">
                  <input
                    type="checkbox"
                    className="h-4 w-4 rounded bg-slate-800 border-slate-700 text-gold-500 focus:ring-gold-500"
                    checked={settings.videoPkEnabled}
                    onChange={(e) => setSettings({ ...settings, videoPkEnabled: e.target.checked })}
                  />
                  <div>
                    <span className="text-sm font-semibold text-white">Video PK Enabled</span>
                    <p className="text-xs text-slate-400">Allow Live Video broadcasts to send & accept PK matches</p>
                  </div>
                </label>
              </div>

              {/* Timing & Timeouts */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Default Duration (Seconds)</label>
                  <select
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 outline-none"
                    value={settings.defaultDurationSeconds}
                    onChange={(e) => setSettings({ ...settings, defaultDurationSeconds: Number(e.target.value) })}
                  >
                    <option value={180}>180 Seconds (3 Minutes)</option>
                    <option value={300}>300 Seconds (5 Minutes - Recommended)</option>
                    <option value={600}>600 Seconds (10 Minutes)</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Invitation Expiry Timeout</label>
                  <Input
                    type="number"
                    value={settings.invitationTimeoutSeconds}
                    onChange={(e) => setSettings({ ...settings, invitationTimeoutSeconds: Number(e.target.value) })}
                    placeholder="30"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">Seconds before pending invitation automatically expires (Default: 30s)</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Media Preparation Timeout</label>
                  <Input
                    type="number"
                    value={settings.preparationTimeoutSeconds}
                    onChange={(e) => setSettings({ ...settings, preparationTimeoutSeconds: Number(e.target.value) })}
                    placeholder="15"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">Max window for hosts to confirm media & readiness (Default: 15s)</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Host Reconnect Grace Period</label>
                  <Input
                    type="number"
                    value={settings.reconnectGraceSeconds}
                    onChange={(e) => setSettings({ ...settings, reconnectGraceSeconds: Number(e.target.value) })}
                    placeholder="30"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">Grace window before opponent wins by forfeit (Default: 30s)</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Invitation Rate Limit</label>
                  <Input
                    type="number"
                    value={settings.invitationRateLimit}
                    onChange={(e) => setSettings({ ...settings, invitationRateLimit: Number(e.target.value) })}
                    placeholder="5"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">Maximum invitations allowed per host per minute (Default: 5)</p>
                </div>

                <div>
                  <label className="block text-xs font-medium text-slate-300 mb-1">Result Display Window</label>
                  <Input
                    type="number"
                    value={settings.resultDisplaySeconds}
                    onChange={(e) => setSettings({ ...settings, resultDisplaySeconds: Number(e.target.value) })}
                    placeholder="10"
                  />
                  <p className="text-[10px] text-slate-500 mt-1">Seconds to show final victory screen before un-relaying (Default: 10s)</p>
                </div>
              </div>

              {/* Policy Notice Box */}
              <div className="p-4 rounded-xl bg-amber-950/20 border border-amber-800/40 flex items-start gap-3">
                <AlertTriangle className="h-5 w-5 text-amber-400 flex-shrink-0 mt-0.5" />
                <div className="text-xs text-amber-200/90 leading-relaxed">
                  <p className="font-bold text-amber-300 mb-1">First-Release Specification Boundaries</p>
                  Scoring rule: Exactly 1 spent gift coin = 1 PK point. Multipliers, lucky gift inflation, loser financial debits,
                  automatic overtime, and tournaments are disabled. Changes to operational settings apply to new matches; active
                  matches preserve their stored configuration snapshot.
                </div>
              </div>

              <div className="flex justify-end pt-4">
                <Button type="submit" variant="primary">
                  Save Platform Settings
                </Button>
              </div>
            </form>
          ) : (
            <div className="p-6 text-sm text-slate-400">Loading settings...</div>
          )}
        </Card>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* TAB 4: USER & ROOM RESTRICTIONS */}
      {/* ─────────────────────────────────────────────────────────── */}
      {activeTab === 'restrictions' && (
        <Card>
          <CardHeader>
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 w-full">
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <ShieldAlert className="h-5 w-5 text-rose-400" />
                  PK Safety & Restrictions
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Temporarily or permanently suspend abusive hosts and rooms from PK matching
                </p>
              </div>

              <Button size="sm" onClick={() => setIsAddRestrictionModalOpen(true)}>
                <Ban className="h-4 w-4 mr-1.5" /> Add Restriction
              </Button>
            </div>
          </CardHeader>

          <DataTable
            isLoading={isLoading}
            data={restrictions}
            emptyMessage="No active PK restrictions."
            columns={[
              {
                key: 'targetType',
                header: 'Target Type',
                render: (r) => (
                  <Badge variant={r.targetType === 'USER' ? 'purple' : 'default'}>{r.targetType}</Badge>
                ),
              },
              {
                key: 'targetId',
                header: 'Target ID',
                render: (r) => <span className="font-mono text-xs text-white font-bold">{r.targetId}</span>,
              },
              {
                key: 'reason',
                header: 'Reason',
                render: (r) => <span className="text-xs text-slate-300">{r.reason}</span>,
              },
              {
                key: 'status',
                header: 'Status',
                render: (r) => (
                  <Badge variant={r.status === 'ACTIVE' ? 'danger' : 'secondary'}>{r.status}</Badge>
                ),
              },
              {
                key: 'expiresAt',
                header: 'Expires At',
                render: (r) => (
                  <span className="text-xs text-slate-400">
                    {r.expiresAt ? new Date(r.expiresAt).toLocaleString() : 'Permanent'}
                  </span>
                ),
              },
              {
                key: 'actions',
                header: 'Actions',
                render: (r) =>
                  r.status === 'ACTIVE' ? (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleRevokeRestriction(r.id)}
                      className="text-xs py-1 px-2 border-slate-700 text-slate-300 hover:text-white"
                    >
                      Revoke
                    </Button>
                  ) : (
                    <span className="text-xs text-slate-600">Revoked</span>
                  ),
              },
            ]}
          />
        </Card>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* MODAL: FORCE STOP MATCH (CONFIRMATION & AUDIT) */}
      {/* ─────────────────────────────────────────────────────────── */}
      {forceStopModalMatch && (
        <Modal
          isOpen={Boolean(forceStopModalMatch)}
          onClose={() => setForceStopModalMatch(null)}
          title="Force Stop PK Match"
          size="md"
        >
          <div className="space-y-4">
            <div className="p-3 rounded-lg bg-rose-950/30 border border-rose-800/40 text-xs text-rose-300">
              <p className="font-bold flex items-center gap-1.5 mb-1">
                <AlertTriangle className="h-4 w-4" /> Irreversible Lifecycle Action
              </p>
              Force stopping will immediately abort match <span className="font-mono font-bold">{forceStopModalMatch.id}</span> without a winner,
              shut down Agora cross-channel relay, release room reservations, and leave committed gift transactions intact.
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1">
                Reason for Force Stopping (Required for Audit Log)
              </label>
              <textarea
                className="w-full bg-slate-900 border border-slate-700 rounded-lg p-3 text-xs text-white focus:border-rose-500 outline-none"
                rows={3}
                placeholder="E.g., Host policy violation, inappropriate live broadcast content, mutual disconnection..."
                value={forceStopReason}
                onChange={(e) => setForceStopReason(e.target.value)}
              />
            </div>

            <div className="flex justify-end gap-3 pt-3">
              <Button variant="outline" onClick={() => setForceStopModalMatch(null)}>
                Cancel
              </Button>
              <Button
                variant="danger"
                disabled={isSubmittingForceStop || !forceStopReason.trim()}
                onClick={handleConfirmForceStop}
              >
                {isSubmittingForceStop ? 'Force Stopping...' : 'Confirm Force Stop'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* MODAL: INSPECT MATCH SNAPSHOT & TOP SUPPORTERS */}
      {/* ─────────────────────────────────────────────────────────── */}
      {inspectModalMatchId && (
        <Modal
          isOpen={Boolean(inspectModalMatchId)}
          onClose={() => setInspectModalMatchId(null)}
          title={`Match Inspection: ${inspectModalMatchId}`}
          size="lg"
        >
          {isLoadingInspect ? (
            <div className="p-8 text-center text-sm text-slate-400">Loading authoritative match state...</div>
          ) : inspectedMatch ? (
            <div className="space-y-5 max-h-[75vh] overflow-y-auto pr-1">
              {/* Top Banner Overview */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 p-3.5 rounded-xl bg-slate-900 border border-slate-800 text-xs">
                <div>
                  <span className="text-slate-500 block">Status</span>
                  <StatusBadge status={inspectedMatch.status.toLowerCase()} />
                </div>
                <div>
                  <span className="text-slate-500 block">Mode</span>
                  <span className="font-semibold text-white">{inspectedMatch.roomType}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">State Version</span>
                  <span className="font-mono text-white">Rev #{inspectedMatch.stateVersion}</span>
                </div>
                <div>
                  <span className="text-slate-500 block">End Reason</span>
                  <span className="text-slate-300 font-mono truncate">{inspectedMatch.endReason || 'IN_PROGRESS'}</span>
                </div>
              </div>

              {/* Side A vs Side B Cards */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {/* Side A Card */}
                <div className="p-4 rounded-xl bg-sky-950/20 border border-sky-800/40 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-sky-400 uppercase tracking-wider">Side A (Blue)</span>
                    <Badge variant="default" className="text-[10px]">
                      {inspectedMatch.sideA?.connectionStatus || 'CONNECTED'}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-3">
                    <img
                      src={inspectedMatch.sideA?.avatarUrl || 'https://via.placeholder.com/48'}
                      alt="Host A"
                      className="w-12 h-12 rounded-full border border-sky-500 object-cover"
                    />
                    <div>
                      <p className="text-sm font-bold text-white">{inspectedMatch.sideA?.displayName}</p>
                      <p className="text-xs text-slate-400">Host ID: {inspectedMatch.sideA?.hostId}</p>
                      <p className="text-xs text-slate-400">Room: {inspectedMatch.sideA?.roomId}</p>
                    </div>
                  </div>
                  <div className="pt-2 border-t border-sky-900/40 flex justify-between items-center">
                    <span className="text-xs text-slate-400">Score</span>
                    <span className="text-lg font-mono font-bold text-sky-300">
                      {formatNumber(Number(inspectedMatch.scoreA || 0))} pts
                    </span>
                  </div>

                  {/* Top 3 Supporters for Side A */}
                  <div className="pt-2">
                    <p className="text-[11px] font-bold text-slate-400 mb-2">Top 3 Supporters</p>
                    {inspectedMatch.topSupportersA?.length ? (
                      <div className="space-y-1.5">
                        {inspectedMatch.topSupportersA.map((s, idx) => (
                          <div key={idx} className="flex items-center justify-between text-xs bg-slate-900/60 p-1.5 rounded">
                            <span className="text-slate-300">
                              #{s.rank} {s.displayName || s.userId}
                            </span>
                            <span className="font-mono text-gold-400 font-semibold">{formatNumber(s.totalCoins)} coins</span>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-[11px] text-slate-600">No supporters recorded</p>
                    )}
                  </div>
                </div>

                {/* Side B Card */}
                <div className="p-4 rounded-xl bg-rose-950/20 border border-rose-800/40 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-bold text-rose-400 uppercase tracking-wider">Side B (Red)</span>
                    <Badge variant="default" className="text-[10px]">
                      {inspectedMatch.sideB?.connectionStatus || 'CONNECTED'}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-3">
                    <img
                      src={inspectedMatch.sideB?.avatarUrl || 'https://via.placeholder.com/48'}
                      alt="Host B"
                      className="w-12 h-12 rounded-full border border-rose-500 object-cover"
                    />
                    <div>
                      <p className="text-sm font-bold text-white">{inspectedMatch.sideB?.displayName}</p>
                      <p className="text-xs text-slate-400">Host ID: {inspectedMatch.sideB?.hostId}</p>
                      <p className="text-xs text-slate-400">Room: {inspectedMatch.sideB?.roomId}</p>
                    </div>
                  </div>
                  <div className="pt-2 border-t border-rose-900/40 flex justify-between items-center">
                    <span className="text-xs text-slate-400">Score</span>
                    <span className="text-lg font-mono font-bold text-rose-300">
                      {formatNumber(Number(inspectedMatch.scoreB || 0))} pts
                    </span>
                  </div>

                  {/* Top 3 Supporters for Side B */}
                  <div className="pt-2">
                    <p className="text-[11px] font-bold text-slate-400 mb-2">Top 3 Supporters</p>
                    {inspectedMatch.topSupportersB?.length ? (
                      <div className="space-y-1.5">
                        {inspectedMatch.topSupportersB.map((s, idx) => (
                          <div key={idx} className="flex items-center justify-between text-xs bg-slate-900/60 p-1.5 rounded">
                            <span className="text-slate-300">
                              #{s.rank} {s.displayName || s.userId}
                            </span>
                            <span className="font-mono text-gold-400 font-semibold">{formatNumber(s.totalCoins)} coins</span>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <p className="text-[11px] text-slate-600">No supporters recorded</p>
                    )}
                  </div>
                </div>
              </div>

              {/* Agora Cross-Room Relay Channel Details */}
              {inspectedMatch.agoraRelay && (
                <div className="p-3 rounded-lg bg-slate-900 border border-slate-800 text-xs">
                  <span className="font-bold text-slate-400 block mb-1">Agora Cross-Room Channel Relay</span>
                  <div className="grid grid-cols-2 gap-2 text-slate-300 font-mono text-[11px]">
                    <div>Channel A: {inspectedMatch.agoraRelay.channelA}</div>
                    <div>Channel B: {inspectedMatch.agoraRelay.channelB}</div>
                    <div>Host A Uid: {inspectedMatch.agoraRelay.hostAUid}</div>
                    <div>Host B Uid: {inspectedMatch.agoraRelay.hostBUid}</div>
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="p-6 text-sm text-rose-400">Failed to load match snapshot.</div>
          )}
        </Modal>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* MODAL: AUDITED RESULT REVISION */}
      {/* ─────────────────────────────────────────────────────────── */}
      {revisionModalMatch && (
        <Modal
          isOpen={Boolean(revisionModalMatch)}
          onClose={() => setRevisionModalMatch(null)}
          title={`Audited Result Revision: ${revisionModalMatch.id}`}
          size="md"
        >
          <div className="space-y-4">
            <div className="p-3 rounded-lg bg-amber-950/30 border border-amber-800/40 text-xs text-amber-300">
              <p className="font-bold flex items-center gap-1.5 mb-1">
                <AlertTriangle className="h-4 w-4" /> Audited Correction Policy
              </p>
              Original scores and winner are preserved immutably. This operation records a formal revision number,
              admin actor, and reason for proven financial transaction reconciliation.
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Revised Score A (Blue)</label>
                <Input
                  type="number"
                  value={revisionForm.revisedScoreA}
                  onChange={(e) => setRevisionForm({ ...revisionForm, revisedScoreA: Number(e.target.value) })}
                />
              </div>
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Revised Score B (Red)</label>
                <Input
                  type="number"
                  value={revisionForm.revisedScoreB}
                  onChange={(e) => setRevisionForm({ ...revisionForm, revisedScoreB: Number(e.target.value) })}
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Revised Winner</label>
                <select
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white outline-none"
                  value={revisionForm.revisedWinnerHostId}
                  onChange={(e) =>
                    setRevisionForm({
                      ...revisionForm,
                      revisedWinnerHostId: e.target.value,
                      revisedIsDraw: false,
                    })
                  }
                >
                  <option value={revisionModalMatch.hostAUserId}>Host A (Blue)</option>
                  <option value={revisionModalMatch.hostBUserId}>Host B (Red)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Declare as Draw?</label>
                <select
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white outline-none"
                  value={revisionForm.revisedIsDraw ? 'true' : 'false'}
                  onChange={(e) =>
                    setRevisionForm({
                      ...revisionForm,
                      revisedIsDraw: e.target.value === 'true',
                      revisedWinnerHostId: e.target.value === 'true' ? null : revisionForm.revisedWinnerHostId,
                    })
                  }
                >
                  <option value="false">No (Decisive Winner)</option>
                  <option value="true">Yes (Tie / Draw)</option>
                </select>
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1">
                Mandatory Revision Reason (Audit Reference)
              </label>
              <textarea
                className="w-full bg-slate-900 border border-slate-700 rounded-lg p-2.5 text-xs text-white outline-none focus:border-amber-500"
                rows={3}
                placeholder="E.g., Transaction ID #tx_9876 was reversed due to fraud; adjusted Host A score accordingly..."
                value={revisionForm.reason}
                onChange={(e) => setRevisionForm({ ...revisionForm, reason: e.target.value })}
              />
            </div>

            <div className="flex justify-end gap-3 pt-3">
              <Button variant="outline" onClick={() => setRevisionModalMatch(null)}>
                Cancel
              </Button>
              <Button
                variant="primary"
                disabled={isSubmittingRevision || !revisionForm.reason.trim()}
                onClick={handleSubmitRevision}
              >
                {isSubmittingRevision ? 'Saving Revision...' : 'Save Audited Revision'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* ─────────────────────────────────────────────────────────── */}
      {/* MODAL: ADD RESTRICTION */}
      {/* ─────────────────────────────────────────────────────────── */}
      {isAddRestrictionModalOpen && (
        <Modal
          isOpen={isAddRestrictionModalOpen}
          onClose={() => setIsAddRestrictionModalOpen(false)}
          title="Add PK Match Restriction"
          size="md"
        >
          <form onSubmit={handleCreateRestriction} className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Target Type</label>
                <select
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white outline-none"
                  value={restrictionForm.targetType}
                  onChange={(e) => setRestrictionForm({ ...restrictionForm, targetType: e.target.value })}
                >
                  <option value="USER">User / Host</option>
                  <option value="ROOM">Room</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1">Duration (Hours)</label>
                <Input
                  type="number"
                  placeholder="24 (Leave empty for permanent)"
                  value={restrictionForm.durationHours}
                  onChange={(e) => setRestrictionForm({ ...restrictionForm, durationHours: e.target.value })}
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1">Target ID (User ID or Room ID)</label>
              <Input
                required
                placeholder="E.g., usr_12345 or room_abc99"
                value={restrictionForm.targetId}
                onChange={(e) => setRestrictionForm({ ...restrictionForm, targetId: e.target.value })}
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-slate-300 mb-1">Reason for Restriction</label>
              <textarea
                required
                className="w-full bg-slate-900 border border-slate-700 rounded-lg p-2.5 text-xs text-white outline-none focus:border-rose-500"
                rows={3}
                placeholder="E.g., Match spamming, harassment, streaming inappropriate video..."
                value={restrictionForm.reason}
                onChange={(e) => setRestrictionForm({ ...restrictionForm, reason: e.target.value })}
              />
            </div>

            <div className="flex justify-end gap-3 pt-3">
              <Button type="button" variant="outline" onClick={() => setIsAddRestrictionModalOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" variant="danger" disabled={isSubmittingRestriction}>
                {isSubmittingRestriction ? 'Applying...' : 'Apply Restriction'}
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}

export default PKEventsPage;
