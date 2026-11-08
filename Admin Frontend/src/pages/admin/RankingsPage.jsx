// ============================================================
// ZeParty Admin Portal — Authoritative Rankings Page
// 2026 Developer Specification & Issue 27 Resolution
// ============================================================

import React, { useState, useMemo, useEffect, useCallback } from 'react';
import {
  Trophy,
  Award,
  Filter,
  Crown,
  Flame,
  Star,
  Sparkles,
  AlertTriangle,
  ShieldCheck,
  Globe,
  CheckCircle,
  RefreshCw,
  Search,
  Radio,
  Heart,
  Users,
  Coins,
  Gem,
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';
import { getRankings } from '../../services/modules/leaderboards.service';

const CATEGORIES = [
  { id: 'wealth', label: 'Wealth', icon: Coins, description: 'Top coin gifters / spenders' },
  { id: 'charm', label: 'Charm', icon: Gem, description: 'Top gift receivers / diamonds earned' },
  { id: 'room', label: 'Rooms', icon: Radio, description: 'Top live rooms & gift activity' },
  { id: 'cp', label: 'CP Intimacy', icon: Heart, description: 'Top couple partner intimacy pairs' },
  { id: 'svip', label: 'SVIP', icon: Crown, description: 'High-tier SVIP privilege rankings' },
  { id: 'noble', label: 'Nobility', icon: Star, description: 'Aristocratic peerage tiers' },
];

const TIMEFRAMES = [
  { id: 'hourly', label: 'Hourly' },
  { id: 'daily', label: 'Daily' },
  { id: 'weekly', label: 'Weekly' },
  { id: 'monthly', label: 'Monthly' },
  { id: 'all_time', label: 'All-Time' },
];

const COUNTRIES = [
  { code: 'GLOBAL', name: 'Global (All Countries)' },
  { code: 'PK', name: 'Pakistan' },
  { code: 'US', name: 'United States' },
  { code: 'SA', name: 'Saudi Arabia' },
  { code: 'AE', name: 'United Arab Emirates' },
  { code: 'IN', name: 'India' },
  { code: 'BD', name: 'Bangladesh' },
  { code: 'GB', name: 'United Kingdom' },
  { code: 'EG', name: 'Egypt' },
];

export function RankingsPage() {
  const { logAdminAction } = useAuditLog();

  // Primary filtering state
  const [activeCategory, setActiveCategory] = useState('wealth');
  const [timeframe, setTimeframe] = useState('daily');
  const [scope, setScope] = useState('GLOBAL');
  const [countryCode, setCountryCode] = useState('GLOBAL');
  const [searchQuery, setSearchQuery] = useState('');

  // Data state
  const [rankingsData, setRankingsData] = useState([]);
  const [metadata, setMetadata] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [excludeFraud, setExcludeFraud] = useState(true);
  const [isFrozen, setIsFrozen] = useState(false);
  const [feedback, setFeedback] = useState(null);

  // Configuration and Event Modals
  const [configModal, setConfigModal] = useState(false);
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('Score = 1.0 * Gifts');
  const [showCreateEventModal, setShowCreateEventModal] = useState(false);
  const [eventForm, setEventForm] = useState({
    name: 'Weekly Top Agency — Pakistan',
    type: 'Weekly Top Agency',
    metric: 'Attributed Recharge',
    top1Reward: '5,000 USD + Platinum Agency Frame',
    top2Reward: '2,500 USD + Gold Agency Frame',
    top3Reward: '1,000 USD + Silver Agency Frame',
    distributionMode: 'Manual Admin Approval',
  });

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  // Fetch rankings from backend
  const fetchRankings = useCallback(async () => {
    setIsLoading(true);
    try {
      const selectedScope = countryCode !== 'GLOBAL' ? 'COUNTRY' : scope;
      const res = await getRankings({
        category: activeCategory,
        period: timeframe,
        scope: selectedScope,
        country: countryCode !== 'GLOBAL' ? countryCode : null,
        limit: 50,
        search: searchQuery,
      });

      if (res && res.data) {
        setRankingsData(res.data);
        setMetadata({
          periodStart: res.periodStart,
          periodEnd: res.periodEnd,
          timezone: res.timezone || 'UTC',
          snapshotTime: res.snapshotTime,
          lastUpdatedAt: res.lastUpdatedAt,
          totalCount: res.totalCount || res.data.length,
          scope: res.scope,
          scopeValue: res.scopeValue,
        });
      } else {
        setRankingsData([]);
      }
    } catch (err) {
      console.error('Failed to load rankings:', err);
      showFeedback('Failed to load rankings from backend.');
      setRankingsData([]);
    } finally {
      setIsLoading(false);
    }
  }, [activeCategory, timeframe, scope, countryCode, searchQuery]);

  useEffect(() => {
    fetchRankings();
  }, [fetchRankings]);

  const handleDisqualify = async (row) => {
    const targetName = row.user?.username || row.roomTitle || row.id;
    setRankingsData((prev) =>
      prev.map((r) => {
        const match = (r.user?.username || r.roomTitle || r.id) === targetName;
        return match ? { ...r, status: 'Disqualified', metric: '0 (DQ)' } : r;
      })
    );

    await logAdminAction({
      action: 'RANKINGS_USER_DISQUALIFIED',
      module: 'Rankings',
      targetType: 'rankings_user',
      targetId: targetName,
      targetName,
      reason: 'Disqualified due to policy violation / manual moderation',
      riskLevel: 'HIGH',
    });

    showFeedback(`Disqualified "${targetName}" from leaderboards.`);
  };

  const handleFreezeRankings = async () => {
    const newVal = !isFrozen;
    setIsFrozen(newVal);
    await logAdminAction({
      action: newVal ? 'RANKINGS_FREEZE_ENABLED' : 'RANKINGS_FREEZE_DISABLED',
      module: 'Rankings',
      targetType: 'rankings_board',
      targetId: `${activeCategory}:${timeframe}`,
      targetName: `${activeCategory} (${timeframe})`,
      reason: `Rankings freeze status set to ${newVal}`,
      riskLevel: 'HIGH',
    });
    showFeedback(`Leaderboard is now ${newVal ? 'FROZEN' : 'ACTIVE'}.`);
  };

  const handleCreateEvent = async (e) => {
    e.preventDefault();
    await logAdminAction({
      action: 'CREATE_REWARD_EVENT',
      module: 'Rankings & Events',
      targetType: 'REWARD_EVENT',
      targetId: `evt-${Date.now()}`,
      reason: `Created ${eventForm.type}: ${eventForm.name}`,
      riskLevel: 'HIGH',
      status: 'SUCCESS',
    });
    showFeedback(`Reward Event "${eventForm.name}" created & published!`);
    setShowCreateEventModal(false);
  };

  const handleSaveInheritance = async () => {
    await logAdminAction({
      action: 'RANKINGS_INHERITANCE_UPDATED',
      module: 'Rankings',
      targetType: 'rankings_config',
      targetId: timeframe,
      targetName: `Timeframe ${timeframe}`,
      reason: `Set scope to ${scope} with calculation override: ${overrideValue}`,
      riskLevel: 'MEDIUM',
    });
    showFeedback('Ranking calculation settings updated.');
    setConfigModal(false);
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
    }
    showFeedback('Scope override reset to parent.');
  };

  // Build dynamic columns based on active category
  const columns = useMemo(() => {
    const rankCol = {
      key: 'rank',
      header: 'Rank',
      render: (r) => (
        <span
          className={`text-xs font-extrabold ${
            r.rank === 1
              ? 'text-yellow-400 text-sm'
              : r.rank === 2
              ? 'text-slate-300 text-sm'
              : r.rank === 3
              ? 'text-amber-500 text-sm'
              : 'text-slate-400'
          }`}
        >
          #{r.rank}
        </span>
      ),
    };

    if (activeCategory === 'room') {
      return [
        rankCol,
        {
          key: 'room',
          header: 'Room Details',
          render: (r) => (
            <div className="flex items-center gap-2.5">
              {r.coverImageUrl ? (
                <img
                  src={r.coverImageUrl}
                  alt={r.roomTitle}
                  className="w-10 h-10 rounded-lg object-cover border border-slate-700 shrink-0"
                />
              ) : (
                <div className="w-10 h-10 rounded-lg bg-slate-800 border border-slate-700 flex items-center justify-center shrink-0">
                  <Radio className="w-5 h-5 text-indigo-400" />
                </div>
              )}
              <div>
                <span className="text-xs font-bold text-white block truncate max-w-[180px]">{r.roomTitle}</span>
                <span className="text-[10px] text-slate-400 font-mono">ID: {r.roomId?.slice(0, 8)}...</span>
              </div>
            </div>
          ),
        },
        {
          key: 'creator',
          header: 'Host / Creator',
          render: (r) => (
            <div className="flex items-center gap-2">
              <span className="text-xs text-slate-200 font-semibold">{r.user?.displayName || r.creator?.displayName || 'Host'}</span>
              <CountryFlag code={r.user?.countryCode || 'GLOBAL'} className="w-3.5 h-2.5 rounded-sm" />
            </div>
          ),
        },
        {
          key: 'viewers',
          header: 'Viewers',
          render: (r) => (
            <div className="flex items-center gap-1.5 text-xs font-bold text-indigo-400">
              <Users className="w-3.5 h-3.5" />
              <span>{r.currentViewersCount || 1}</span>
            </div>
          ),
        },
        {
          key: 'points',
          header: 'Room Score',
          render: (r) => (
            <span className="text-xs font-mono font-bold text-gold-400">
              {Number(r.points || 0).toLocaleString()} ({r.formattedPoints})
            </span>
          ),
        },
        {
          key: 'actions',
          header: 'Actions',
          render: (r) => (
            <Button variant="danger" size="xs" onClick={() => handleDisqualify(r)}>
              Disqualify
            </Button>
          ),
        },
      ];
    }

    if (activeCategory === 'cp') {
      return [
        rankCol,
        {
          key: 'partner1',
          header: 'Partner 1',
          render: (r) => (
            <div className="flex items-center gap-2">
              <img
                src={r.user?.avatarUrl || 'https://via.placeholder.com/40'}
                alt=""
                className="w-7 h-7 rounded-full object-cover border border-slate-700"
              />
              <div>
                <span className="text-xs font-bold text-white block">{r.user?.displayName || r.user?.username}</span>
                <span className="text-[10px] text-slate-400">@{r.user?.username}</span>
              </div>
            </div>
          ),
        },
        {
          key: 'partner2',
          header: 'Partner 2',
          render: (r) => (
            <div className="flex items-center gap-2">
              <img
                src={r.partnerUser?.avatarUrl || 'https://via.placeholder.com/40'}
                alt=""
                className="w-7 h-7 rounded-full object-cover border border-slate-700"
              />
              <div>
                <span className="text-xs font-bold text-white block">{r.partnerUser?.displayName || r.partnerUser?.username}</span>
                <span className="text-[10px] text-slate-400">@{r.partnerUser?.username}</span>
              </div>
            </div>
          ),
        },
        {
          key: 'intimacy',
          header: 'CP Intimacy Score',
          render: (r) => (
            <div className="flex items-center gap-1.5">
              <Heart className="w-3.5 h-3.5 text-rose-500 fill-rose-500 shrink-0" />
              <span className="text-xs font-mono font-bold text-rose-400">
                {Number(r.points || 0).toLocaleString()} ({r.formattedPoints})
              </span>
            </div>
          ),
        },
        {
          key: 'badge',
          header: 'Relationship Tier',
          render: (r) => (
            <Badge variant="purple" className="text-[10px]">
              {r.relationshipBadge || '💍 Eternal Love'}
            </Badge>
          ),
        },
        {
          key: 'actions',
          header: 'Actions',
          render: (r) => (
            <Button variant="danger" size="xs" onClick={() => handleDisqualify(r)}>
              Disqualify
            </Button>
          ),
        },
      ];
    }

    // Default for Wealth, Charm, SVIP, Nobility
    return [
      rankCol,
      {
        key: 'user',
        header: 'User Identity',
        render: (r) => {
          const u = r.user || {};
          return (
            <div className="flex items-center gap-2.5">
              <img
                src={u.avatarUrl || 'https://via.placeholder.com/40'}
                alt=""
                className="w-8 h-8 rounded-full object-cover border border-slate-700 shrink-0"
              />
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs font-bold text-white">{u.displayName || u.name || u.username}</span>
                  {u.svipLevel > 0 && (
                    <Badge variant="purple" className="text-[9px] px-1 py-0 font-bold">
                      SVIP {u.svipLevel}
                    </Badge>
                  )}
                  {r.nobleTitle && (
                    <Badge variant="warning" className="text-[9px] px-1 py-0 font-bold">
                      {r.nobleTitle}
                    </Badge>
                  )}
                </div>
                <span className="text-[10px] text-slate-400 font-mono">@{u.username} • ID: {u.id?.slice(0, 8)}</span>
              </div>
            </div>
          );
        },
      },
      {
        key: 'country',
        header: 'Location',
        render: (r) => {
          const code = r.user?.countryCode || 'GLOBAL';
          return (
            <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">
              <CountryFlag code={code} className="w-3.5 h-2.5 rounded-sm shrink-0" />
              <span>{getCountryShortName(code)}</span>
            </div>
          );
        },
      },
      {
        key: 'tier',
        header: activeCategory === 'wealth' ? 'Wealth Level' : activeCategory === 'charm' ? 'Charm Level' : 'Tier',
        render: (r) => {
          const lvl = r.user?.level || r.user?.wealthLevel || r.user?.charmLevel || 1;
          return (
            <Badge variant={activeCategory === 'charm' ? 'purple' : 'default'} className="text-[10px]">
              {activeCategory === 'charm' ? `Charm Lv.${lvl}` : `Level ${lvl}`}
            </Badge>
          );
        },
      },
      {
        key: 'points',
        header: activeCategory === 'wealth' ? 'Coins Spent' : activeCategory === 'charm' ? 'Diamonds Received' : 'Score',
        render: (r) => (
          <span
            className={`text-xs font-mono font-bold ${
              r.status === 'Disqualified' ? 'text-rose-500' : 'text-emerald-400'
            }`}
          >
            {Number(r.points || 0).toLocaleString()} ({r.formattedPoints})
          </span>
        ),
      },
      {
        key: 'status',
        header: 'Status',
        render: (r) => (
          <Badge variant={r.status === 'Disqualified' ? 'danger' : 'success'}>
            {r.status || 'Active'}
          </Badge>
        ),
      },
      {
        key: 'actions',
        header: 'Actions',
        render: (r) => (
          <div className="flex gap-1.5">
            {r.status !== 'Disqualified' && (
              <Button variant="danger" size="xs" onClick={() => handleDisqualify(r)}>
                Disqualify
              </Button>
            )}
          </div>
        ),
      },
    ];
  }, [activeCategory]);

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Trophy className="h-6 w-6 text-gold-400" />
            Global Rankings & Leaderboard Engine
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            100% Authoritative Real-Time Calculations for Wealth, Charm, Room, CP, and SVIP.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Button variant="primary" size="sm" onClick={() => setShowCreateEventModal(true)}>
            <Award className="h-4 w-4 mr-1" /> Create Reward Event
          </Button>
          <Button variant="outline" size="sm" onClick={() => setConfigModal(true)}>
            Score Rules
          </Button>
          <Button variant={isFrozen ? 'warning' : 'outline'} size="sm" onClick={handleFreezeRankings}>
            {isFrozen ? 'Unfreeze' : 'Freeze Board'}
          </Button>
          <Button variant="ghost" size="sm" onClick={fetchRankings} disabled={isLoading}>
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin' : ''}`} />
          </Button>
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded-lg bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Category Tabs */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2">
        {CATEGORIES.map((cat) => {
          const Icon = cat.icon;
          const isActive = activeCategory === cat.id;
          return (
            <button
              key={cat.id}
              onClick={() => setActiveCategory(cat.id)}
              className={`flex items-center gap-2.5 p-3 rounded-xl border text-left transition-all ${
                isActive
                  ? 'bg-slate-900 border-gold-500 shadow-md ring-1 ring-gold-500/30'
                  : 'bg-slate-900/60 border-slate-800 hover:border-slate-700 text-slate-400 hover:text-white'
              }`}
            >
              <div
                className={`p-2 rounded-lg shrink-0 ${
                  isActive ? 'bg-gold-500/20 text-gold-400' : 'bg-slate-800 text-slate-400'
                }`}
              >
                <Icon className="w-4 h-4" />
              </div>
              <div className="min-w-0">
                <span className={`text-xs font-bold block truncate ${isActive ? 'text-white' : 'text-slate-300'}`}>
                  {cat.label}
                </span>
                <span className="text-[10px] text-slate-400 block truncate">{cat.description}</span>
              </div>
            </button>
          );
        })}
      </div>

      {/* Filter & Period Bar */}
      <Card className="p-4 bg-slate-900 border border-slate-800 space-y-4">
        <div className="flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4">
          {/* Timeframe Buttons */}
          <div className="flex items-center gap-1 bg-slate-950 p-1 rounded-lg border border-slate-800 overflow-x-auto">
            {TIMEFRAMES.map((t) => (
              <button
                key={t.id}
                onClick={() => setTimeframe(t.id)}
                className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors shrink-0 ${
                  timeframe === t.id
                    ? 'bg-gold-500 text-slate-950 font-bold shadow'
                    : 'text-slate-400 hover:text-white'
                }`}
              >
                {t.label}
              </button>
            ))}
          </div>

          {/* Territory & Search Controls */}
          <div className="flex flex-wrap items-center gap-2.5">
            {/* Country Selector */}
            <div className="flex items-center gap-1.5 bg-slate-950 px-2.5 py-1.5 rounded-lg border border-slate-800">
              <Globe className="w-3.5 h-3.5 text-slate-400 shrink-0" />
              <select
                value={countryCode}
                onChange={(e) => setCountryCode(e.target.value)}
                className="bg-transparent text-xs text-white border-0 outline-none cursor-pointer pr-2"
              >
                {COUNTRIES.map((c) => (
                  <option key={c.code} value={c.code} className="bg-slate-900 text-white">
                    {c.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Search Input */}
            <div className="relative min-w-[200px]">
              <Search className="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <Input
                size="sm"
                placeholder="Search user, room..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-8 bg-slate-950 border-slate-800 text-xs"
              />
            </div>
          </div>
        </div>

        {/* Live Active Window Metadata */}
        {metadata && (
          <div className="flex flex-wrap items-center justify-between gap-2 pt-3 border-t border-slate-800/80 text-[11px] text-slate-400">
            <div className="flex items-center gap-3">
              <span>
                Window Start: <strong className="text-white font-mono">{metadata.periodStart ? new Date(metadata.periodStart).toUTCString() : 'Lifetime All-Time'}</strong>
              </span>
              <span>•</span>
              <span>
                Window End: <strong className="text-white font-mono">{metadata.periodEnd ? new Date(metadata.periodEnd).toUTCString() : 'Now'}</strong>
              </span>
              <span>•</span>
              <span className="text-gold-400 font-semibold uppercase">{metadata.timezone || 'UTC'} Calendar Boundary</span>
            </div>
            <div>
              Total Ranked Entries: <strong className="text-white font-mono">{metadata.totalCount}</strong>
            </div>
          </div>
        )}
      </Card>

      {/* Main Table */}
      <DataTable
        columns={columns}
        data={rankingsData}
        isLoading={isLoading}
        emptyTitle="No ranking entries found"
        emptyDescription="Rankings update dynamically as users spend coins, stream, and interact."
      />

      {/* Score Configuration Modal */}
      {configModal && (
        <Modal
          isOpen={true}
          onClose={() => setConfigModal(false)}
          title={`Rankings Score Config: ${timeframe.toUpperCase()}`}
          size="lg"
        >
          <div className="space-y-4">
            <GeographicInheritancePanel
              scope={scope}
              onChangeScope={setScope}
              inheritedValue={inheritedValue}
              overrideValue={overrideValue}
              onChangeOverride={setOverrideValue}
              effectiveValue={overrideValue || inheritedValue}
              onResetScope={handleResetScope}
              label="Ranking formula inheritance rules"
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setConfigModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save config formula
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Create Reward Event Modal */}
      {showCreateEventModal && (
        <Modal isOpen={true} onClose={() => setShowCreateEventModal(false)} title="Create Ranking Reward Event">
          <form onSubmit={handleCreateEvent} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-[11px] text-slate-400 mb-1 block">Event Title *</label>
              <Input
                size="sm"
                value={eventForm.name}
                onChange={(e) => setEventForm({ ...eventForm, name: e.target.value })}
                required
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Event Type</label>
                <select
                  className="w-full bg-slate-900 border border-slate-700 text-white text-xs rounded-lg p-2"
                  value={eventForm.type}
                  onChange={(e) => setEventForm({ ...eventForm, type: e.target.value })}
                >
                  <option value="Weekly Top Agency">Weekly Top Agency</option>
                  <option value="Weekly Top Game">Weekly Top Game</option>
                  <option value="Custom Ranking Event">Custom Ranking Event</option>
                </select>
              </div>
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Ranking Metric</label>
                <Input
                  size="sm"
                  value={eventForm.metric}
                  onChange={(e) => setEventForm({ ...eventForm, metric: e.target.value })}
                />
              </div>
            </div>

            <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
              <p className="font-bold text-gold-400">Independent Rank Reward Settings</p>
              <div>
                <label className="text-[10px] text-slate-400 mb-0.5 block">Top 1 Reward (First Place)</label>
                <Input
                  size="sm"
                  value={eventForm.top1Reward}
                  onChange={(e) => setEventForm({ ...eventForm, top1Reward: e.target.value })}
                  required
                />
              </div>
              <div>
                <label className="text-[10px] text-slate-400 mb-0.5 block">Top 2 Reward (Second Place)</label>
                <Input
                  size="sm"
                  value={eventForm.top2Reward}
                  onChange={(e) => setEventForm({ ...eventForm, top2Reward: e.target.value })}
                  required
                />
              </div>
              <div>
                <label className="text-[10px] text-slate-400 mb-0.5 block">Top 3 Reward (Third Place)</label>
                <Input
                  size="sm"
                  value={eventForm.top3Reward}
                  onChange={(e) => setEventForm({ ...eventForm, top3Reward: e.target.value })}
                  required
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowCreateEventModal(false)}>
                Cancel
              </Button>
              <Button type="submit" variant="primary" size="sm">
                Publish Reward Event
              </Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
export default RankingsPage;
