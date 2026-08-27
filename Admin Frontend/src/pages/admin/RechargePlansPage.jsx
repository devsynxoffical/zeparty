// ============================================================
// ZeParty Admin Portal — Recharge Plans Management Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import {
  CreditCard, Plus, Pencil, Trash2, Star,
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
  const [plans, setPlans] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedCountry, setSelectedCountry] = useState('All');
  const [formModal, setFormModal] = useState({ open: false, plan: null });
  const [deleteModal, setDeleteModal] = useState({ open: false, plan: null });
  const [isDeleting, setIsDeleting] = useState(false);

  // Load on mount
  useEffect(() => {
    getRechargePlans()
      .then((data) => {
        const enriched = (data || []).map((p, i) => ({
          ...p,
          targetCountry: p.targetCountry || (i % 3 === 0 ? 'US' : i % 3 === 1 ? 'AE' : 'All')
        }));
        setPlans(enriched);
      })
      .finally(() => setIsLoading(false));
  }, []);

  function handleSave(updated, mode) {
    if (mode === 'create') {
      setPlans((prev) => [updated, ...prev]);
    } else {
      setPlans((prev) => prev.map((p) => (p.id === updated.id ? updated : p)));
    }
  }

  async function handleDelete() {
    if (!deleteModal.plan) return;
    setIsDeleting(true);
    try {
      setPlans((prev) => prev.filter((p) => p.id !== deleteModal.plan.id));
    } finally {
      setIsDeleting(false);
      setDeleteModal({ open: false, plan: null });
    }
  }

  const filteredPlans = plans.filter((p) => {
    return !selectedCountry || selectedCountry === 'All' || selectedCountry === 'GLOBAL' || p.targetCountry?.toLowerCase() === selectedCountry.toLowerCase();
  });

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-emerald-400" aria-hidden="true" />
            Recharge Plans & Country Targeting
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage coin recharge packages available globally or targeted to specific countries.</p>
        </div>
        <Button
          variant="primary"
          size="sm"
          leftIcon={Plus}
          onClick={() => setFormModal({ open: true, plan: null })}
        >
          New Plan
        </Button>
      </div>

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
