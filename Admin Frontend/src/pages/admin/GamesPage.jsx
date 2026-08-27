// ============================================================
// ZeParty Admin Portal — In-App Games & House Edge Economics (JSX)
// Derived House Edge + Probability Validation + Screenshot 4 Features
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import {
  Gamepad2,
  Plus,
  Pencil,
  Search,
  Percent,
  TrendingUp,
  AlertTriangle,
  CheckCircle2,
  History,
  Coins,
  DollarSign,
  Layers,
  Calendar,
  ShieldAlert,
  Trash2,
  RotateCcw,
  Lock,
  ArrowRight
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card, CardHeader } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Select } from '../../components/ui/Select';
import { GAME_STATUSES, GAME_TYPES } from '../../mocks/games.mock';
import { getGames, updateGameConfig } from '../../services/modules/games.service';
import { formatNumber, formatDate, formatCurrency } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

// ── Game Configuration Modal with Live House Edge Calculation ──
function GameConfigModal({ isOpen, onClose, game, onSave }) {
  const isEdit = !!game;
  const { logAdminAction } = useAuditLog();

  const [activeTab, setActiveTab] = useState('economics'); // 'economics' | 'general' | 'limits' | 'history'
  const [name, setName] = useState('');
  const [type, setType] = useState('Spin');
  const [status, setStatus] = useState('active');
  const [entryFee, setEntryFee] = useState(10);
  const [minPrize, setMinPrize] = useState(0);
  const [maxPrize, setMaxPrize] = useState(500);
  const [dailyPlayLimit, setDailyPlayLimit] = useState(50);
  const [userLevelLimit, setUserLevelLimit] = useState(1);
  const [isEventSpecific, setIsEventSpecific] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [description, setDescription] = useState('');
  const [outcomes, setOutcomes] = useState([]);
  const [changeReason, setChangeReason] = useState('');
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setName(game?.name || '');
      setType(game?.type || 'Spin');
      setStatus(game?.status || 'active');
      setEntryFee(game?.entryFee || 10);
      setMinPrize(game?.minPrize || 0);
      setMaxPrize(game?.maxPrize || 500);
      setDailyPlayLimit(game?.dailyPlayLimit || 50);
      setUserLevelLimit(game?.userLevelLimit || 1);
      setIsEventSpecific(game?.isEventSpecific || false);
      setStartDate(game?.startDate || '');
      setEndDate(game?.endDate || '');
      setDescription(game?.description || '');
      setChangeReason('');
      setError('');
      setActiveTab('economics');

      if (game?.outcomes && game.outcomes.length > 0) {
        setOutcomes(JSON.parse(JSON.stringify(game.outcomes)));
      } else {
        setOutcomes([
          { id: 'out-1', name: 'No Win', probability: 50, payout: 0, active: true },
          { id: 'out-2', name: 'Standard Prize (2x)', probability: 35, payout: 2, active: true },
          { id: 'out-3', name: 'Major Jackpot (5x)', probability: 15, payout: 5, active: true },
        ]);
      }
    }
  }, [isOpen, game?.id]);

  // Derived Mathematical Calculations
  const economics = useMemo(() => {
    const totalProb = outcomes.reduce((acc, out) => (out.active ? acc + Number(out.probability || 0) : acc), 0);
    const expectedReturn = outcomes.reduce((acc, out) => {
      if (!out.active) return acc;
      return acc + (Number(out.probability || 0) / 100) * Number(out.payout || 0);
    }, 0);
    const derivedHouseEdge = (1 - expectedReturn) * 100;
    const maxExposure = outcomes.reduce((max, out) => (out.active && out.payout > max ? out.payout : max), 0);

    const isProbValid = Math.abs(totalProb - 100) < 0.001;

    return {
      totalProbability: Number(totalProb.toFixed(2)),
      expectedReturn: Number(expectedReturn.toFixed(4)),
      derivedHouseEdge: Number(derivedHouseEdge.toFixed(2)),
      maxExposure,
      isProbValid,
    };
  }, [outcomes]);

  const handleOutcomeChange = (index, field, value) => {
    const updated = [...outcomes];
    updated[index] = { ...updated[index], [field]: value };
    setOutcomes(updated);
  };

  const handleAddOutcome = () => {
    setOutcomes([
      ...outcomes,
      {
        id: `out-${Date.now()}`,
        name: 'New Prize Tier',
        probability: 0,
        payout: 1.0,
        active: true,
      },
    ]);
  };

  const handleRemoveOutcome = (index) => {
    if (outcomes.length <= 1) return;
    setOutcomes(outcomes.filter((_, i) => i !== index));
  };

  async function handleSubmit(e) {
    e.preventDefault();
    if (!economics.isProbValid) {
      setError(`Configuration Invalid: Total Probability must equal exactly 100% (Current: ${economics.totalProbability}%).`);
      return;
    }

    setIsSaving(true);
    setError('');

    try {
      const payload = {
        name,
        type,
        status,
        entryFee: Number(entryFee),
        minPrize: Number(minPrize),
        maxPrize: Number(maxPrize),
        dailyPlayLimit: Number(dailyPlayLimit),
        userLevelLimit: Number(userLevelLimit),
        isEventSpecific,
        startDate,
        endDate,
        description,
        outcomes,
      };

      const updated = await updateGameConfig(
        game?.id || 'game-001',
        payload,
        'Super Admin',
        changeReason || 'Updated game odds and economics configuration'
      );

      await logAdminAction({
        action: 'GAME_ECONOMICS_RECONFIGURED',
        module: 'Games',
        targetType: 'game',
        targetId: game?.id || 'game-001',
        targetName: name,
        reason: changeReason || 'Reconfigured prize probabilities and house edge',
        riskLevel: 'HIGH',
      });

      onSave(updated);
      onClose();
    } catch (err) {
      setError('Failed to save game configuration. Please try again.');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={`Game Economics & Configuration: ${game?.name || 'New Game'}`}
      size="xl"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        {/* Navigation Tabs */}
        <div className="flex gap-2 border-b border-slate-700/60 pb-2">
          {[
            { id: 'economics', label: 'Economics & House Edge' },
            { id: 'general', label: 'General Settings' },
            { id: 'limits', label: 'Limits & Event Rules' },
            { id: 'history', label: 'Version History' },
          ].map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => setActiveTab(t.id)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                activeTab === t.id
                  ? 'bg-gold-500/20 text-gold-400 border border-gold-500/40'
                  : 'text-slate-400 hover:text-white bg-slate-800/40'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Tab 1: Economics & House Edge Engine */}
        {activeTab === 'economics' && (
          <div className="space-y-4">
            {/* Realtime Economics Metric Strip */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <div
                className={`p-3 rounded-xl border ${
                  economics.isProbValid
                    ? 'bg-emerald-950/30 border-emerald-500/40'
                    : 'bg-red-950/40 border-red-500/60 animate-pulse'
                }`}
              >
                <div className="flex justify-between items-center">
                  <p className="text-[11px] text-slate-400 font-semibold">Total Probability</p>
                  {economics.isProbValid ? (
                    <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                  ) : (
                    <AlertTriangle className="h-4 w-4 text-red-400" />
                  )}
                </div>
                <p
                  className={`text-xl font-mono font-bold mt-1 ${
                    economics.isProbValid ? 'text-emerald-400' : 'text-red-400'
                  }`}
                >
                  {economics.totalProbability}%
                </p>
                <p className="text-[10px] text-slate-400 mt-0.5">
                  {economics.isProbValid ? 'Validated (100%)' : 'Must equal 100.0%'}
                </p>
              </div>

              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-700/60">
                <p className="text-[11px] text-slate-400 font-semibold">Expected Return (RTP)</p>
                <p className="text-xl font-mono font-bold text-sky-400 mt-1">
                  {(economics.expectedReturn * 100).toFixed(2)}%
                </p>
                <p className="text-[10px] text-slate-400 mt-0.5">Σ(Prob × Payout) = {economics.expectedReturn}</p>
              </div>

              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-700/60">
                <p className="text-[11px] text-slate-400 font-semibold">Derived House Edge</p>
                <p
                  className={`text-xl font-mono font-bold mt-1 ${
                    economics.derivedHouseEdge >= 0 ? 'text-gold-400' : 'text-red-400'
                  }`}
                >
                  {economics.derivedHouseEdge}%
                </p>
                <p className="text-[10px] text-slate-400 mt-0.5">
                  {economics.derivedHouseEdge >= 0 ? 'Positive Platform Edge' : 'Player Advantage'}
                </p>
              </div>

              <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-700/60">
                <p className="text-[11px] text-slate-400 font-semibold">Max Payout Exposure</p>
                <p className="text-xl font-mono font-bold text-yellow-400 mt-1">
                  {economics.maxExposure}x
                </p>
                <p className="text-[10px] text-slate-400 mt-0.5">Max single round multiplier</p>
              </div>
            </div>

            {/* Warning Banner if invalid */}
            {!economics.isProbValid && (
              <div className="p-3 rounded-xl bg-red-500/20 border border-red-500/50 text-red-400 text-xs flex items-center gap-2 font-medium">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>
                  Configuration Error: Total probability across all outcomes is {economics.totalProbability}%. Please adjust outcomes so the sum equals 100.0%.
                </span>
              </div>
            )}

            {economics.isProbValid && economics.derivedHouseEdge < 0 && (
              <div className="p-3 rounded-xl bg-amber-500/20 border border-amber-500/50 text-amber-400 text-xs flex items-center gap-2 font-medium">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                <span>
                  Warning: Configured House Edge is negative ({economics.derivedHouseEdge}%). This gives players a statistical advantage over the platform!
                </span>
              </div>
            )}

            {/* Prize Outcomes Table */}
            <div className="rounded-xl border border-slate-700/60 bg-slate-900/60 overflow-hidden">
              <div className="p-3 border-b border-slate-700/60 flex justify-between items-center">
                <span className="text-xs font-bold text-white uppercase tracking-wider">
                  Prize Outcome Distribution Matrix
                </span>
                <Button type="button" variant="outline" size="xs" onClick={handleAddOutcome} leftIcon={Plus}>
                  Add Outcome
                </Button>
              </div>

              <div className="overflow-x-auto max-h-56 overflow-y-auto">
                <table className="w-full text-left text-xs text-slate-300">
                  <thead className="bg-slate-800/80 text-[11px] text-slate-400 border-b border-slate-700">
                    <tr>
                      <th className="py-2 px-3">Outcome Name</th>
                      <th className="py-2 px-3">Probability (%)</th>
                      <th className="py-2 px-3">Payout (x)</th>
                      <th className="py-2 px-3">Contribution</th>
                      <th className="py-2 px-3 text-center">Active</th>
                      <th className="py-2 px-3 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800">
                    {outcomes.map((out, idx) => {
                      const contribution = (Number(out.probability || 0) / 100) * Number(out.payout || 0);
                      return (
                        <tr key={out.id || idx} className="hover:bg-slate-800/40">
                          <td className="py-2 px-3">
                            <input
                              value={out.name}
                              onChange={(e) => handleOutcomeChange(idx, 'name', e.target.value)}
                              className="w-full rounded bg-slate-800 border border-slate-700 px-2 py-1 text-xs text-white"
                              placeholder="e.g. Minor Win"
                              required
                            />
                          </td>
                          <td className="py-2 px-3 w-28">
                            <input
                              type="number"
                              step="0.01"
                              min="0"
                              max="100"
                              value={out.probability}
                              onChange={(e) =>
                                handleOutcomeChange(idx, 'probability', parseFloat(e.target.value) || 0)
                              }
                              className="w-full rounded bg-slate-800 border border-slate-700 px-2 py-1 text-xs text-white font-mono"
                              required
                            />
                          </td>
                          <td className="py-2 px-3 w-28">
                            <input
                              type="number"
                              step="0.1"
                              min="0"
                              value={out.payout}
                              onChange={(e) =>
                                handleOutcomeChange(idx, 'payout', parseFloat(e.target.value) || 0)
                              }
                              className="w-full rounded bg-slate-800 border border-slate-700 px-2 py-1 text-xs text-white font-mono"
                              required
                            />
                          </td>
                          <td className="py-2 px-3 font-mono text-emerald-400 font-semibold">
                            {contribution.toFixed(4)}
                          </td>
                          <td className="py-2 px-3 text-center">
                            <input
                              type="checkbox"
                              checked={out.active}
                              onChange={(e) => handleOutcomeChange(idx, 'active', e.target.checked)}
                              className="rounded border-slate-700 text-gold-500 focus:ring-0"
                            />
                          </td>
                          <td className="py-2 px-3 text-right">
                            <button
                              type="button"
                              onClick={() => handleRemoveOutcome(idx)}
                              className="text-slate-500 hover:text-red-400 p-1"
                            >
                              <Trash2 className="h-3.5 w-3.5" />
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">
                Reason for Economics / House Edge Change (Mandatory for Audit Trail)
              </label>
              <Input
                value={changeReason}
                onChange={(e) => setChangeReason(e.target.value)}
                placeholder="e.g. Rebalancing low tier RTP from 88% to 90% per executive decree"
                required
              />
            </div>
          </div>
        )}

        {/* Tab 2: General Settings */}
        {activeTab === 'general' && (
          <div className="space-y-4">
            <Input
              label="Game Title"
              value={name}
              onChange={(e) => setName(e.target.value)}
              required
              placeholder="e.g. Lucky Wheel"
            />
            <div className="grid grid-cols-2 gap-3">
              <Select label="Game Type" value={type} onChange={(e) => setType(e.target.value)}>
                {GAME_TYPES.filter((t) => t !== 'All').map((t) => (
                  <option key={t} value={t}>{t}</option>
                ))}
              </Select>
              <Select label="Status" value={status} onChange={(e) => setStatus(e.target.value)}>
                <option value="active">Active</option>
                <option value="paused">Paused</option>
                <option value="inactive">Inactive</option>
              </Select>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <Input
                label="Entry Fee (Coins)"
                type="number"
                value={entryFee}
                onChange={(e) => setEntryFee(e.target.value)}
                required
                min="1"
              />
              <Input
                label="Min Prize (Coins)"
                type="number"
                value={minPrize}
                onChange={(e) => setMinPrize(e.target.value)}
                required
                min="0"
              />
              <Input
                label="Max Prize (Coins)"
                type="number"
                value={maxPrize}
                onChange={(e) => setMaxPrize(e.target.value)}
                required
                min="1"
              />
            </div>
            <Input
              label="Game Description & Rules"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Brief overview of game mechanics and payouts"
            />
          </div>
        )}

        {/* Tab 3: Limits & Event Rules */}
        {activeTab === 'limits' && (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <Input
                label="Daily Play Limit Per User"
                type="number"
                value={dailyPlayLimit}
                onChange={(e) => setDailyPlayLimit(e.target.value)}
                min="1"
              />
              <Input
                label="Required Minimum VIP / User Level"
                type="number"
                value={userLevelLimit}
                onChange={(e) => setUserLevelLimit(e.target.value)}
                min="0"
              />
            </div>

            <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-700/60 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-white">Event-Specific Game</p>
                  <p className="text-xs text-slate-400">Limit game accessibility to a specific promotion period.</p>
                </div>
                <input
                  type="checkbox"
                  checked={isEventSpecific}
                  onChange={(e) => setIsEventSpecific(e.target.checked)}
                  className="rounded border-slate-700 text-gold-500 focus:ring-0 h-4 w-4"
                />
              </div>

              {isEventSpecific && (
                <div className="grid grid-cols-2 gap-3 pt-2 border-t border-slate-800">
                  <Input
                    label="Start Date"
                    type="date"
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                  />
                  <Input
                    label="End Date"
                    type="date"
                    value={endDate}
                    onChange={(e) => setEndDate(e.target.value)}
                  />
                </div>
              )}
            </div>
          </div>
        )}

        {/* Tab 4: Version History */}
        {activeTab === 'history' && (
          <div className="space-y-3">
            <p className="text-xs font-semibold text-white">Economics & Policy Version Audit Log</p>
            <div className="space-y-2 max-h-60 overflow-y-auto pr-1">
              {game?.history && game.history.length > 0 ? (
                game.history.map((h, i) => (
                  <div key={i} className="p-3 rounded-xl bg-slate-900 border border-slate-700/60 text-xs space-y-1">
                    <div className="flex justify-between items-center">
                      <span className="font-bold text-gold-400">{h.version}</span>
                      <span className="text-slate-400 font-mono text-[11px]">{formatDate(h.effectiveDate)}</span>
                    </div>
                    <p className="text-white">Operator: <strong className="text-slate-300">{h.operator}</strong></p>
                    <p className="text-slate-400 italic">"{h.reason}"</p>
                    <div className="flex gap-4 text-[11px] pt-1 text-slate-300 font-mono">
                      <span>RTP: {(h.expectedReturn * 100).toFixed(2)}%</span>
                      <span>House Edge: {h.houseEdge}%</span>
                      <span>Outcomes: {h.outcomesCount}</span>
                    </div>
                  </div>
                ))
              ) : (
                <p className="text-xs text-slate-500 py-4 text-center">No previous configuration versions recorded.</p>
              )}
            </div>
          </div>
        )}

        {error && <p className="text-xs text-red-400 font-medium">{error}</p>}

        {/* Footer */}
        <div className="flex justify-between items-center pt-3 border-t border-slate-700">
          <p className="text-[11px] text-slate-500">
            Note: Frontend calculates real-time preview. Authoritative economics are enforced server-side.
          </p>
          <div className="flex gap-2">
            <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" size="sm" isLoading={isSaving} disabled={!economics.isProbValid}>
              {isEdit ? 'Save Economics & Config' : 'Create Game'}
            </Button>
          </div>
        </div>
      </form>
    </Modal>
  );
}

// ── Main Games Management Page ─────────────────────────────────
export function GamesPage() {
  const [games, setGames] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [typeFilter, setTypeFilter] = useState('All');
  const [gameModal, setGameModal] = useState({ open: false, game: null });
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    getGames()
      .then((data) => setGames(data))
      .finally(() => setIsLoading(false));
  }, []);

  function handleSave(updated) {
    setGames((prev) => prev.map((g) => (g.id === updated.id ? updated : g)));
    setFeedback(`Configuration updated for ${updated.name}. Derived House Edge: ${updated.houseEdge}%.`);
    setTimeout(() => setFeedback(null), 4000);
  }

  const filtered = useMemo(() => {
    return games.filter((g) => {
      const matchStatus = statusFilter === 'all' || g.status === statusFilter;
      const matchType = typeFilter === 'All' || g.type === typeFilter;
      const q = search.toLowerCase();
      const matchSearch = !q || g.name.toLowerCase().includes(q) || g.type.toLowerCase().includes(q);
      return matchStatus && matchType && matchSearch;
    });
  }, [games, search, statusFilter, typeFilter]);

  const totalRevenue = useMemo(() => {
    return games.reduce((acc, g) => acc + (g.totalRounds * g.entryFee - g.totalPaidOut), 0);
  }, [games]);

  const columns = [
    {
      key: 'game',
      header: 'Game',
      render: (row) => (
        <div>
          <p className="text-sm font-bold text-white">{row.name}</p>
          <Badge variant="primary" className="text-[10px] mt-0.5">{row.type}</Badge>
        </div>
      ),
    },
    {
      key: 'entryFee',
      header: 'Entry Fee',
      render: (row) => <span className="text-xs font-mono text-yellow-400 font-bold">🪙 {row.entryFee}</span>,
    },
    {
      key: 'maxPrize',
      header: 'Max Prize (Cap)',
      render: (row) => <span className="text-xs font-mono text-emerald-400 font-bold">🪙 {formatNumber(row.maxPrize)}</span>,
    },
    {
      key: 'houseEdge',
      header: 'Derived House Edge',
      render: (row) => (
        <div>
          <span className="text-xs font-mono font-bold text-gold-400">{row.houseEdge}%</span>
          <p className="text-[10px] text-slate-400 mt-0.5">RTP: {(100 - row.houseEdge).toFixed(1)}%</p>
        </div>
      ),
    },
    {
      key: 'totalRounds',
      header: 'Rounds Played',
      render: (row) => <span className="text-xs font-mono text-slate-300">{formatNumber(row.totalRounds)}</span>,
    },
    {
      key: 'netRevenue',
      header: 'Net Game Profit',
      render: (row) => {
        const profit = row.totalRounds * row.entryFee - row.totalPaidOut;
        return <span className="text-xs font-mono font-bold text-emerald-400">🪙 +{formatNumber(profit)}</span>;
      },
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
        <Button
          variant="outline"
          size="xs"
          onClick={() => setGameModal({ open: true, game: row })}
          leftIcon={Pencil}
        >
          Configure
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6 max-w-screen-2xl mx-auto" aria-label="Games Management">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Gamepad2 className="h-7 w-7 text-indigo-400" />
            In-App Games & House Edge Economics
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Configure minigame prize outcomes, probability distributions, live derived house edge, and play limits.
          </p>
        </div>
        <Button variant="primary" size="sm" leftIcon={Plus} onClick={() => setGameModal({ open: true, game: null })}>
          Add New Game
        </Button>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle2 className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Active Minigames</p>
          <p className="text-2xl font-bold text-white mt-1">
            {games.filter((g) => g.status === 'active').length}
          </p>
        </Card>
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Total Rounds Played</p>
          <p className="text-2xl font-bold text-sky-400 mt-1">
            {formatNumber(games.reduce((acc, g) => acc + g.totalRounds, 0))}
          </p>
        </Card>
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Total Prizes Paid Out</p>
          <p className="text-2xl font-bold text-yellow-400 mt-1">
            🪙 {formatNumber(games.reduce((acc, g) => acc + g.totalPaidOut, 0))}
          </p>
        </Card>
        <Card className="p-4 bg-slate-900/60 border-slate-800">
          <p className="text-xs text-slate-400">Net Platform Game Revenue</p>
          <p className="text-2xl font-bold text-emerald-400 mt-1">
            🪙 +{formatNumber(totalRevenue)}
          </p>
        </Card>
      </div>

      {/* Filter Bar */}
      <Card className="p-4 flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
        <Input
          placeholder="Search games by title or mechanics…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md"
        />

        <div className="flex items-center gap-2 overflow-x-auto">
          <span className="text-xs text-slate-400 whitespace-nowrap">Status:</span>
          {GAME_STATUSES.map((s) => (
            <button
              key={s}
              onClick={() => setStatusFilter(s)}
              className={`px-2.5 py-1 rounded-lg text-xs font-medium capitalize border transition-colors ${
                statusFilter === s
                  ? 'bg-gold-500/20 border-gold-500/50 text-gold-400 font-bold'
                  : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </Card>

      {/* Games Table */}
      <DataTable
        columns={columns}
        data={filtered}
        isLoading={isLoading}
        emptyTitle="No games found"
        emptyDescription="No in-app games match your search criteria."
      />

      {/* Configuration Modal */}
      {gameModal.open && (
        <GameConfigModal
          isOpen={true}
          onClose={() => setGameModal({ open: false, game: null })}
          game={gameModal.game}
          onSave={handleSave}
        />
      )}
    </div>
  );
}
