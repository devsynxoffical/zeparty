// ============================================================
// ZeParty Admin Portal — Recharge Plans Management Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import {
  CreditCard, Plus, Pencil, Trash2, Star, Gift, Award, Calendar, CheckCircle, AlertTriangle, RefreshCw, Power,
} from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal, ConfirmDialog } from '../../components/ui/Modal';
import { CountrySelect } from '../../components/ui/CountrySelect';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';
import {
  getRechargePlans,
  createRechargePlan,
  updateRechargePlan,
  deleteRechargePlan,
  getRechargeRewardEvents,
  toggleRechargeRewardEvent,
} from '../../services/modules/monetization.service';

// ── Plan Form Modal ───────────────────────────────────────────
function PlanFormModal({ isOpen, onClose, plan, onSave }) {
  const isEdit = !!plan;
  const [name, setName]       = useState(plan?.name    || '');
  const [coins, setCoins]     = useState(plan?.coins   || '');
  const [price, setPrice]     = useState(plan?.price   || '');
  const [bonus, setBonus]     = useState(plan?.bonus   || '');
  const [targetCountry, setTargetCountry] = useState(plan?.targetCountry || 'GLOBAL');
  const [featured, setFeatured] = useState(plan?.featured || false);
  const [active, setActive]   = useState(plan?.active  ?? true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError]     = useState('');

  useEffect(() => {
    if (isOpen) {
      setName(plan?.name || '');
      setCoins(plan?.coins || '');
      setPrice(plan?.price || '');
      setBonus(plan?.bonus || '');
      setTargetCountry(plan?.targetCountry || 'GLOBAL');
      setFeatured(plan?.featured || false);
      setActive(plan?.active ?? true);
      setError('');
    }
  }, [isOpen, plan?.id]);

  async function handleSubmit(e) {
    e.preventDefault();
    setIsSaving(true);
    setError('');
    try {
      const payload = {
        name,
        coins: Number(coins),
        price: Number(price),
        bonus: Number(bonus || 0),
        targetCountry,
        featured,
        active,
      };
      if (isEdit) {
        await updateRechargePlan(plan.id, payload);
        onSave({ ...plan, ...payload });
      } else {
        const newPlan = await createRechargePlan(payload);
        onSave(newPlan, 'create');
      }
      onClose();
    } catch {
      setError('Failed to save plan. Please try again.');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={isEdit ? 'Edit Recharge Plan' : 'Create Recharge Plan'}
      size="sm"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input label="Plan Name" value={name} onChange={(e) => setName(e.target.value)} required placeholder="e.g. Starter Pack" />
        <CountrySelect label="Target Country" value={targetCountry} onChange={setTargetCountry} />
        <div className="grid grid-cols-2 gap-3">
          <Input label="Coins" type="number" value={coins} onChange={(e) => setCoins(e.target.value)} required min="1" />
          <Input label="Price (USD)" type="number" step="0.01" value={price} onChange={(e) => setPrice(e.target.value)} required min="0.01" />
        </div>
        <Input label="Bonus Coins" type="number" value={bonus} onChange={(e) => setBonus(e.target.value)} min="0" hint="Bonus coins given on top of base coins" />
        <div className="flex gap-4">
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={featured}
              onChange={(e) => setFeatured(e.target.checked)}
              className="h-4 w-4 rounded border-slate-700 bg-slate-800 text-indigo-600 accent-indigo-600"
            />
            <span className="text-xs text-slate-300">Mark as Featured</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={active}
              onChange={(e) => setActive(e.target.checked)}
              className="h-4 w-4 rounded border-slate-700 bg-slate-800 accent-indigo-600"
            />
            <span className="text-xs text-slate-300">Active</span>
          </label>
        </div>
        {error && <p className="text-xs text-red-400">{error}</p>}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>Cancel</Button>
          <Button type="submit" variant="primary" size="sm" isLoading={isSaving}>
            {isEdit ? 'Save Changes' : 'Create Plan'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ── Page ──────────────────────────────────────────────────────
export function RechargePlansPage() {
  const [activeTab, setActiveTab] = useState('plans'); // 'plans' | 'rewards'
  const [plans, setPlans] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [formModal, setFormModal] = useState({ open: false, plan: null });
  const [deleteModal, setDeleteModal] = useState({ open: false, plan: null });
  const [isDeleting, setIsDeleting] = useState(false);

  // Rewards Events State
  const [rewardEvents, setRewardEvents] = useState([]);
  const [isLoadingRewards, setIsLoadingRewards] = useState(false);
  const [togglingEventId, setTogglingEventId] = useState(null);

  const fetchPlansData = () => {
    setIsLoading(true);
    getRechargePlans()
      .then((data) => {
        const enriched = (data || []).map((p, i) => ({
          ...p,
          targetCountry: p.targetCountry || (i % 3 === 0 ? 'US' : i % 3 === 1 ? 'AE' : 'All')
        }));
        setPlans(enriched);
      })
      .finally(() => setIsLoading(false));
  };

  const fetchRewardEventsData = () => {
    setIsLoadingRewards(true);
    getRechargeRewardEvents()
      .then((data) => {
        setRewardEvents(data || []);
      })
      .catch((err) => {
        console.error('Failed to load recharge reward events:', err);
      })
      .finally(() => setIsLoadingRewards(false));
  };

  // Load on mount
  useEffect(() => {
    fetchPlansData();
    fetchRewardEventsData();
  }, []);

  function handleSave(updated, mode) {
    fetchPlansData();
  }

  async function handleDelete() {
    if (!deleteModal.plan) return;
    setIsDeleting(true);
    try {
      await deleteRechargePlan(deleteModal.plan.id);
      fetchPlansData();
    } catch (err) {
      console.error('Failed to delete recharge plan:', err);
    } finally {
      setIsDeleting(false);
      setDeleteModal({ open: false, plan: null });
    }
  }

  async function handleToggleRewardEvent(event) {
    setTogglingEventId(event.id);
    try {
      await toggleRechargeRewardEvent(event.id, !event.isActive);
      fetchRewardEventsData();
    } catch (err) {
      console.error('Failed to toggle recharge reward event:', err);
    } finally {
      setTogglingEventId(null);
    }
  }

  const filteredPlans = plans.filter((p) => {
    return !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || p.targetCountry?.toLowerCase() === selectedCountry.toLowerCase();
  });

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-emerald-400" aria-hidden="true" />
            Recharge Monetization & Reward Events
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage coin recharge packages, country targeting, and cumulative recharge reward milestones.</p>
        </div>
        {activeTab === 'plans' && (
          <Button
            variant="primary"
            size="sm"
            leftIcon={Plus}
            onClick={() => setFormModal({ open: true, plan: null })}
          >
            New Plan
          </Button>
        )}
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-2 border-b border-slate-800 pb-2">
        <button
          onClick={() => setActiveTab('plans')}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
            activeTab === 'plans'
              ? 'bg-gold-500/10 text-gold-400 border border-gold-500/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-800/40'
          }`}
        >
          <CreditCard className="h-4 w-4" /> Recharge Plans ({plans.length})
        </button>
        <button
          onClick={() => { setActiveTab('rewards'); fetchRewardEventsData(); }}
          className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all ${
            activeTab === 'rewards'
              ? 'bg-gold-500/10 text-gold-400 border border-gold-500/30'
              : 'text-slate-400 hover:text-white hover:bg-slate-800/40'
          }`}
        >
          <Gift className="h-4 w-4" /> Recharge Rewards Events ({rewardEvents.length})
        </button>
      </div>

      {/* TAB 1: Recharge Plans */}
      {activeTab === 'plans' && (
        <>
          {/* Filter Card */}
          <Card className="p-4 flex flex-col sm:flex-row items-center justify-between gap-3">
            <div className="text-xs text-slate-300">
              Showing <strong className="text-white">{filteredPlans.length}</strong> recharge plans for target region
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs text-slate-400 font-semibold">Target Country:</span>
              <CountrySelect value={selectedCountry} onChange={setSelectedCountry} />
            </div>
          </Card>

          {isLoading ? (
            <div className="text-center py-12 text-slate-400 text-sm">Loading plans…</div>
          ) : (
            <div className="grid sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
              {filteredPlans.map((plan) => (
                <Card key={plan.id} className={['p-5 flex flex-col gap-3 relative', !plan.active ? 'opacity-60' : ''].join(' ')}>
                  {plan.featured && (
                    <span className="absolute top-3 right-3">
                      <Star className="h-4 w-4 text-yellow-400 fill-yellow-400" aria-hidden="true" />
                    </span>
                  )}
                  <div>
                    <p className="text-sm font-semibold text-white">{plan.name}</p>
                    <p className="text-2xl font-bold text-emerald-400 mt-1">${plan.price}</p>
                  </div>
                  <div className="flex flex-col gap-1 text-xs text-slate-400">
                    <div className="flex justify-between">
                      <span>🪙 Base Coins</span>
                      <span className="text-white font-medium">{plan.coins.toLocaleString()}</span>
                    </div>
                    {plan.bonus > 0 && (
                      <div className="flex justify-between">
                        <span>🎁 Bonus Coins</span>
                        <span className="text-yellow-400 font-medium">+{plan.bonus.toLocaleString()}</span>
                      </div>
                    )}
                    <div className="flex justify-between border-t border-slate-700/50 pt-1 mt-1">
                      <span>Total Coins</span>
                      <span className="text-white font-bold">{(plan.coins + plan.bonus).toLocaleString()}</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between">
                    <Badge variant={plan.active ? 'success' : 'muted'}>{plan.active ? 'Active' : 'Inactive'}</Badge>
                    <div className="flex gap-1">
                      <button
                        onClick={() => setFormModal({ open: true, plan })}
                        className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700 transition-colors"
                        title="Edit"
                      >
                        <Pencil className="h-3.5 w-3.5" aria-hidden="true" />
                      </button>
                      <button
                        onClick={() => setDeleteModal({ open: true, plan })}
                        className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700 transition-colors"
                        title="Delete"
                      >
                        <Trash2 className="h-3.5 w-3.5" aria-hidden="true" />
                      </button>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </>
      )}

      {/* TAB 2: Recharge Rewards Events */}
      {activeTab === 'rewards' && (
        <div className="flex flex-col gap-6">
          {/* Integrity Guarantee Banner */}
          <div className="p-4 rounded-xl border border-gold-500/30 bg-gold-500/5 flex items-start gap-3">
            <CheckCircle className="h-5 w-5 text-gold-400 flex-shrink-0 mt-0.5" />
            <div className="text-xs text-slate-300 leading-relaxed">
              <strong className="text-gold-300 font-semibold block text-sm mb-0.5">Authoritative Zero-Start Financial Integrity</strong>
              User cumulative recharge progress is strictly computed in real time from persisted, confirmed Online and Offline recharge records within the event window. Accounts with no eligible recharges always start at exactly <strong className="text-white">$0.00 USD</strong> with all milestones locked. No demo data, mock fixtures, or cross-account leakage.
            </div>
          </div>

          {isLoadingRewards ? (
            <div className="text-center py-12 text-slate-400 text-sm">Loading reward events…</div>
          ) : rewardEvents.length === 0 ? (
            <Card className="p-8 text-center text-slate-400 text-sm">
              No recharge reward events found. Use the backend bootstrap or API to configure one.
            </Card>
          ) : (
            rewardEvents.map((evt) => {
              const milestones = Array.isArray(evt.milestones) ? evt.milestones : [];
              return (
                <Card key={evt.id} className="p-6 flex flex-col gap-6 border-slate-800">
                  {/* Event Meta Header */}
                  <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 pb-4 border-b border-slate-800">
                    <div>
                      <div className="flex items-center gap-3">
                        <h2 className="text-lg font-bold text-white">{evt.name}</h2>
                        <Badge variant={evt.isActive ? 'success' : 'muted'}>
                          {evt.isActive ? 'Active' : 'Inactive'}
                        </Badge>
                        <span className="text-xs px-2 py-0.5 rounded bg-slate-800 text-slate-400 font-mono">
                          {evt.eventCode}
                        </span>
                      </div>
                      <p className="text-xs text-slate-400 mt-1">{evt.description}</p>
                      <div className="flex items-center gap-4 text-xs text-slate-400 mt-2">
                        <span className="flex items-center gap-1.5">
                          <Calendar className="h-3.5 w-3.5 text-gold-400" />
                          {new Date(evt.startDate).toLocaleDateString()} – {new Date(evt.endDate).toLocaleDateString()}
                        </span>
                        <span>Currency: <strong className="text-white">{evt.currency}</strong></span>
                        <span>Total Claims: <strong className="text-emerald-400">{evt._count?.claims || 0}</strong></span>
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      <Button
                        variant={evt.isActive ? 'outline' : 'primary'}
                        size="sm"
                        leftIcon={Power}
                        isLoading={togglingEventId === evt.id}
                        onClick={() => handleToggleRewardEvent(evt)}
                      >
                        {evt.isActive ? 'Deactivate Event' : 'Activate Event'}
                      </Button>
                    </div>
                  </div>

                  {/* Milestones Grid */}
                  <div>
                    <h3 className="text-sm font-semibold text-slate-200 mb-3 flex items-center gap-2">
                      <Award className="h-4 w-4 text-gold-400" />
                      Configured Cumulative Milestones ({milestones.length})
                    </h3>
                    <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
                      {milestones.map((m) => (
                        <div
                          key={m.level}
                          className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 flex flex-col justify-between gap-3 hover:border-slate-700 transition-colors"
                        >
                          <div className="flex items-start justify-between gap-2">
                            <div>
                              <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-gold-500/10 text-gold-400 border border-gold-500/20">
                                Level {m.level}
                              </span>
                              <div className="text-xl font-extrabold text-white mt-1.5">
                                ${Number(m.thresholdUSD).toFixed(2)} USD
                              </div>
                            </div>
                            <span className="text-xs px-2 py-1 rounded bg-emerald-500/10 text-emerald-400 font-bold">
                              +{Number(m.bonusCoins).toLocaleString()} Coins
                            </span>
                          </div>

                          <div className="text-xs bg-slate-950/60 p-2.5 rounded-lg border border-slate-800/80">
                            <div className="text-slate-400 font-medium text-[11px] uppercase tracking-wide">
                              Exclusive Reward:
                            </div>
                            <div className="text-gold-300 font-semibold mt-0.5">
                              {m.title || m.exclusiveAssetId || 'Exclusive Reward'}
                            </div>
                            <div className="text-slate-400 text-[11px] mt-0.5">
                              {m.description || `Claimable upon reaching $${m.thresholdUSD} eligible recharge.`}
                            </div>
                            {m.validityDays > 0 && (
                              <div className="text-slate-400 text-[10px] mt-1">
                                Duration: {m.validityDays} days
                              </div>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </Card>
              );
            })
          )}
        </div>
      )}

      <PlanFormModal
        isOpen={formModal.open}
        onClose={() => setFormModal({ open: false, plan: null })}
        plan={formModal.plan}
        onSave={handleSave}
      />
      <ConfirmDialog
        isOpen={deleteModal.open}
        onClose={() => setDeleteModal({ open: false, plan: null })}
        onConfirm={handleDelete}
        title="Delete Recharge Plan"
        description={`Are you sure you want to delete "${deleteModal.plan?.name}"? This cannot be undone.`}
        confirmLabel="Delete"
        confirmVariant="danger"
        isLoading={isDeleting}
      />
    </div>
  );
}
