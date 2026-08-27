// ============================================================
// ZeParty Admin Portal — Rankings Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo } from 'react';
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

const TIMEFRAME_DATA = {
  Hourly: [
    { rank: 1, name: 'SpeedGifter_99', category: 'Top Gifter', metric: '140,000 Coins/hr', country: 'US', tier: 'VIP5', status: 'Active' },
    { rank: 2, name: 'LiveSinger_Aria', category: 'Charm', metric: '98,000 Coins/hr', country: 'KR', tier: 'VIP4', status: 'Active' },
    { rank: 3, name: 'PK_Master_x', category: 'PK', metric: '45,000 Pts', country: 'UK', tier: 'VIP3', status: 'Active' },
  ],
  Daily: [
    { rank: 1, name: 'StarQueen Luna', category: 'Wealth', metric: '840,000 Coins', country: 'US', tier: 'VIP5', status: 'Active' },
    { rank: 2, name: 'Fire Phoenix', category: 'Charm', metric: '620,000 Coins', country: 'KR', tier: 'VIP4', status: 'Active' },
    { rank: 3, name: 'NightOwl Kai', category: 'PK', metric: '410,000 Pts', country: 'UK', tier: 'VIP3', status: 'Active' },
  ],
  Weekly: [
    { rank: 1, name: 'StarQueen Luna', category: 'Top Gifter', metric: '2,840,000 Coins', country: 'US', tier: 'VIP5', status: 'Active' },
    { rank: 2, name: 'Fire Phoenix', category: 'Charm', metric: '2,180,000 Coins', country: 'KR', tier: 'VIP4', status: 'Active' },
    { rank: 3, name: 'NightOwl Kai', category: 'PK', metric: '1,560,000 Pts', country: 'UK', tier: 'VIP3', status: 'Active' },
    { rank: 4, name: 'ZenMaster Aria', category: 'Top Host', metric: '1,240,000 Coins', country: 'JP', tier: 'VIP2', status: 'Active' },
    { rank: 5, name: 'StarMedia Entertainment', category: 'Top Agency', metric: '$48,290 Payout', country: 'US', tier: 'Official Agency', status: 'Active' },
  ],
  Monthly: [
    { rank: 1, name: 'StarMedia Entertainment', category: 'Top Agency', metric: '$184,290 Payout', country: 'US', tier: 'Official Agency', status: 'Active' },
    { rank: 2, name: 'StarQueen Luna', category: 'Wealth', metric: '11,400,000 Coins', country: 'US', tier: 'VIP5', status: 'Active' },
    { rank: 3, name: 'Fire Phoenix', category: 'Charm', metric: '9,800,000 Coins', country: 'KR', tier: 'VIP4', status: 'Active' },
  ],
  'All-Time': [
    { rank: 1, name: 'StarQueen Luna', category: 'Wealth', metric: '84,000,000 Coins', country: 'US', tier: 'SVIP2', status: 'Active' },
    { rank: 2, name: 'Global Talent Agency', category: 'Top Agency', metric: '$1.4M Payout', country: 'UK', tier: 'Super Agency', status: 'Active' },
  ],
};

export function RankingsPage() {
  const { logAdminAction } = useAuditLog();
  const [timeframe, setTimeframe] = useState('Weekly');
  const [dataList, setDataList] = useState(TIMEFRAME_DATA);
  const [excludeFraud, setExcludeFraud] = useState(true);
  const [isFrozen, setIsFrozen] = useState(false);
  
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

      <DataTable columns={columns} data={currentData} isLoading={false} />

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
    </div>
  );
}
