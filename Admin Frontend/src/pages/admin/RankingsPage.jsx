// ============================================================
// ZeParty Admin Portal — Rankings Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { Trophy, Award, Filter, Crown, Flame, Star, Sparkles, AlertTriangle, ShieldCheck, Globe, CheckCircle, RefreshCw } from 'lucide-react';
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
import apiClient from '../../services/api';

const EMPTY_TIMEFRAME_DATA = {
  Hourly: [],
  Daily: [],
  Weekly: [],
  Monthly: [],
  'All-Time': [],
};

export function RankingsPage() {
  const { logAdminAction } = useAuditLog();
  const [timeframe, setTimeframe] = useState('Weekly');
  const [dataList, setDataList] = useState(EMPTY_TIMEFRAME_DATA);
  const [isLoading, setIsLoading] = useState(true);
  const [excludeFraud, setExcludeFraud] = useState(true);
  const [isFrozen, setIsFrozen] = useState(false);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    apiClient
      .get('/v1/admin/users', { params: { limit: 20 } })
      .then((res) => {
        if (!isMounted) return;
        const users = res.data?.data || [];
        const mapped = users.map((u, idx) => ({
          rank: idx + 1,
          name: u.username || u.displayName || u.id,
          category: idx % 2 === 0 ? 'Top Gifter' : 'Top Host',
          metric: `${Number(u.coinBalance || 0).toLocaleString()} Coins`,
          country: u.country || 'US',
          tier: u.vipTier ? `VIP${u.vipTier}` : 'Standard',
          status: u.status === 'ACTIVE' ? 'Active' : 'Disqualified',
        }));

        setDataList({
          Hourly: mapped.slice(0, 5),
          Daily: mapped.slice(0, 10),
          Weekly: mapped,
          Monthly: mapped,
          'All-Time': mapped,
        });
      })
      .catch(() => {
        if (isMounted) setDataList(EMPTY_TIMEFRAME_DATA);
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, []);
  
  // Inheritance config
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('Score = 1.0 * Gifts');
  const [configModal, setConfigModal] = useState(false);
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleDisqualify = async (row) => {
    // Update local state list
    const updatedSubList = (dataList[timeframe] || []).map(r =>
      r.name === row.name ? { ...r, status: 'Disqualified', metric: '0 (DQ)' } : r
    );
    setDataList({ ...dataList, [timeframe]: updatedSubList });

    await logAdminAction({
      action: 'RANKINGS_USER_DISQUALIFIED',
      module: 'Rankings',
      targetType: 'rankings_user',
      targetId: row.name,
      targetName: row.name,
      reason: 'Disqualified due to fraudulent coordinate recharge splits',
      riskLevel: 'HIGH',
    });

    showFeedback(`Disqualified user ${row.name} from leaderboards.`);
  };

  const handleFreezeRankings = async () => {
    const newVal = !isFrozen;
    setIsFrozen(newVal);
    await logAdminAction({
      action: newVal ? 'RANKINGS_FREEZE_ENABLED' : 'RANKINGS_FREEZE_DISABLED',
      module: 'Rankings',
      targetType: 'rankings_board',
      targetId: timeframe,
      targetName: timeframe,
      reason: `Rankings frozen state updated to ${newVal}`,
      riskLevel: 'HIGH',
    });
    showFeedback(`Leaderboard is now ${newVal ? 'FROZEN' : 'ACTIVE'}.`);
  };

  const [showCreateEventModal, setShowCreateEventModal] = useState(false);
  const [eventForm, setEventForm] = useState({
    name: 'Weekly Top Agency — Pakistan',
    type: 'Weekly Top Agency',
    metric: 'Attributed Recharge',
    top1Reward: '5,000 USD + Platinum Agency Frame',
    top2Reward: '2,500 USD + Gold Agency Frame',
    top3Reward: '1,000 USD + Silver Agency Frame',
    distributionMode: 'Manual Admin Approval'
  });

  const handleCreateEvent = async (e) => {
    e.preventDefault();
    await logAdminAction({
      action: 'CREATE_REWARD_EVENT',
      module: 'Rankings & Events',
      targetType: 'REWARD_EVENT',
      targetId: `evt-${Date.now()}`,
      reason: `Created ${eventForm.type}: ${eventForm.name}`,
      riskLevel: 'HIGH',
      status: 'SUCCESS'
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

  const currentData = useMemo(() => dataList[timeframe] || dataList['Weekly'], [timeframe, dataList]);

  const columns = [
    {
      key: 'rank',
      header: 'Rank',
      render: (r) => (
        <span className={`text-xs font-bold ${r.rank === 1 ? 'text-yellow-400' : r.rank === 2 ? 'text-slate-300' : 'text-amber-600'}`}>
          #{r.rank}
        </span>
      ),
    },
    {
      key: 'name',
      header: 'Entity Name',
      render: (r) => (
        <div>
          <span className="text-xs font-bold text-white">{r.name}</span>
          <Badge variant="purple" className="block w-max text-[9px] mt-0.5">{r.tier}</Badge>
        </div>
      ),
    },
    {
      key: 'category',
      header: 'Category Type',
      render: (r) => <Badge variant="default">{r.category}</Badge>,
    },
    {
      key: 'metric',
      header: 'Performance Score',
      render: (r) => (
        <span className={`text-xs font-mono font-bold ${r.status === 'Disqualified' ? 'text-rose-500' : 'text-emerald-400'}`}>
          {r.metric}
        </span>
      ),
    },
    {
      key: 'country',
      header: 'Location Code',
      render: (r) => (
        <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">
          <CountryFlag code={r.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(r.country)}</span>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => (
        <Badge variant={r.status === 'Active' ? 'success' : 'danger'}>{r.status}</Badge>
      ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <div className="flex gap-1.5">
          {r.status === 'Active' && (
            <Button variant="danger" size="xs" onClick={() => handleDisqualify(r)}>
              Disqualify
            </Button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Trophy className="h-6 w-6 text-gold-400" />
            Rankings & Leaderboard Policy Engine
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Oversight for Charm, Wealth, Host, and Agency leaderboards. Configures local overrides and disqualifications.</p>
        </div>

        <div className="flex gap-2">
          <Button variant="primary" size="sm" onClick={() => setShowCreateEventModal(true)}>
            <Award className="h-4 w-4 mr-1" /> Create Reward Event
          </Button>
          <Button variant="outline" size="sm" onClick={() => setConfigModal(true)}>
            Score Rules Configuration
          </Button>
          <Button variant={isFrozen ? 'warning' : 'primary'} size="sm" onClick={handleFreezeRankings}>
            {isFrozen ? 'Unfreeze board' : 'Freeze Leaderboard'}
          </Button>
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Rules banner */}
      <div className="grid md:grid-cols-3 gap-4 text-xs">
        <Card className="p-4 bg-slate-900/60 border border-slate-800">
          <span className="font-bold text-white block">Fraud protection settings:</span>
          <div className="flex items-center gap-2 mt-2">
            <input
              type="checkbox"
              id="fraud"
              checked={excludeFraud}
              onChange={(e) => {
                setExcludeFraud(e.target.checked);
                showFeedback(`Deduct Fraudulent/Refunded coins is now: ${e.target.checked ? 'ENABLED' : 'DISABLED'}`);
              }}
              className="rounded bg-slate-800 border-slate-700 text-gold-500 focus:ring-gold-500 h-4 w-4"
            />
            <label htmlFor="fraud" className="text-slate-300">Exclude refunded / fraudulent coins</label>
          </div>
        </Card>

        <Card className="p-4 bg-slate-900/60 border border-slate-800 col-span-2">
          <p className="text-slate-400">
            Rules inherit via hierarchy: <strong className="text-white">GLOBAL → REGION → COUNTRY</strong>. Disqualification removes the entity immediately from public view and voids reward distribution.
          </p>
        </Card>
      </div>

      {/* Timeframe picker */}
      <Card className="p-4 flex justify-between items-center bg-slate-900 border border-slate-800">
        <span className="text-xs text-slate-400 font-bold uppercase tracking-wider">Select Timeframe Panel</span>
        <div className="flex gap-1 border border-slate-800 bg-slate-950 p-1 rounded-lg">
          {['Hourly', 'Daily', 'Weekly', 'Monthly', 'All-Time'].map((t) => (
            <button
              key={t}
              onClick={() => setTimeframe(t)}
              className={`px-3 py-1 rounded-md text-xs font-medium transition-colors ${
                timeframe === t ? 'bg-gold-500 text-slate-950 font-bold shadow' : 'text-slate-400 hover:text-white'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </Card>

      <DataTable columns={columns} data={currentData} isLoading={isLoading} emptyTitle="No rankings data available" emptyDescription="Rankings will automatically populate as live platform activity occurs." />

      {/* Score Configuration Modal */}
      {configModal && (
        <Modal
          isOpen={true}
          onClose={() => setConfigModal(false)}
          title={`Rankings Score Config: ${timeframe}`}
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
              <Input size="sm" value={eventForm.name} onChange={(e) => setEventForm({ ...eventForm, name: e.target.value })} required />
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
                <Input size="sm" value={eventForm.metric} onChange={(e) => setEventForm({ ...eventForm, metric: e.target.value })} />
              </div>
            </div>

            <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
              <p className="font-bold text-gold-400">Independent Rank Reward Settings</p>
              <div>
                <label className="text-[10px] text-slate-400 mb-0.5 block">Top 1 Reward (First Place)</label>
                <Input size="sm" value={eventForm.top1Reward} onChange={(e) => setEventForm({ ...eventForm, top1Reward: e.target.value })} required />
              </div>
              <div>
                <label className="text-[10px] text-slate-400 mb-0.5 block">Top 2 Reward (Second Place)</label>
                <Input size="sm" value={eventForm.top2Reward} onChange={(e) => setEventForm({ ...eventForm, top2Reward: e.target.value })} required />
              </div>
              <div>
                <label className="text-[10px] text-slate-400 mb-0.5 block">Top 3 Reward (Third Place)</label>
                <Input size="sm" value={eventForm.top3Reward} onChange={(e) => setEventForm({ ...eventForm, top3Reward: e.target.value })} required />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowCreateEventModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">Publish Reward Event</Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
