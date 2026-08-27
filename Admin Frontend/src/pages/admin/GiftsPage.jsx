// ============================================================
// ZeParty Admin Portal — Gift Catalog Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { Gift as GiftIcon, Plus, Pencil, Trash2, Search, Globe, CheckCircle } from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal, ConfirmDialog } from '../../components/ui/Modal';
import { Select } from '../../components/ui/Select';
import { GIFT_CATEGORIES } from '../../mocks/gifts.mock';
import {
  getGifts,
  createGift,
  updateGift,
} from '../../services/modules/gifts.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { useAuditLog } from '../../context/AuditLogContext';

// ── Gift Form Modal ───────────────────────────────────────────
function GiftFormModal({ isOpen, onClose, gift, onSave }) {
  const isEdit = !!gift;
  const [name, setName] = useState(gift?.name || '');
  const [emoji, setEmoji] = useState(gift?.emoji || '');
  const [price, setPrice] = useState(gift?.diamondPrice || '');
  const [category, setCategory] = useState(gift?.category || 'Basic');
  const [active, setActive] = useState(gift?.active ?? true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setName(gift?.name || '');
      setEmoji(gift?.emoji || '');
      setPrice(gift?.diamondPrice || '');
      setCategory(gift?.category || 'Basic');
      setActive(gift?.active ?? true);
      setError('');
    }
  }, [isOpen, gift?.id]);

  async function handleSubmit(e) {
    e.preventDefault();
    setIsSaving(true);
    setError('');
    try {
      const payload = { name, emoji, diamondPrice: Number(price), category, active };
      if (isEdit) {
        await updateGift(gift.id, payload);
        onSave({ ...gift, ...payload });
      } else {
        const newGift = await createGift(payload);
        onSave(newGift, 'create');
      }
      onClose();
    } catch {
      setError('Failed to save gift. Please try again.');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={isEdit ? 'Edit Gift' : 'Create Gift'} size="sm">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input label="Gift Name" value={name} onChange={(e) => setName(e.target.value)} required placeholder="e.g. Golden Crown" />
        <div className="grid grid-cols-2 gap-3">
          <Input label="Emoji / Icon" value={emoji} onChange={(e) => setEmoji(e.target.value)} placeholder="e.g. 👑" required />
          <Input label="Diamond Price" type="number" min="1" value={price} onChange={(e) => setPrice(e.target.value)} required />
        </div>
        <Select label="Category" value={category} onChange={(e) => setCategory(e.target.value)}>
          {GIFT_CATEGORIES.filter((c) => c !== 'All').map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </Select>
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={active}
            onChange={(e) => setActive(e.target.checked)}
            className="h-4 w-4 rounded border-slate-700 bg-slate-800 accent-indigo-600"
          />
          <span className="text-xs text-slate-300">Active (visible in-app)</span>
        </label>
        {error && <p className="text-xs text-red-400">{error}</p>}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>Cancel</Button>
          <Button type="submit" variant="primary" size="sm" isLoading={isSaving}>
            {isEdit ? 'Save Changes' : 'Create Gift'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ── Page ──────────────────────────────────────────────────────
export function GiftsPage() {
  const { logAdminAction } = useAuditLog();
  const [gifts, setGifts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [formModal, setFormModal] = useState({ open: false, gift: null });
  const [deleteModal, setDeleteModal] = useState({ open: false, gift: null });
  const [isDeleting, setIsDeleting] = useState(false);

  // Inheritance State
  const [inheritanceModal, setInheritanceModal] = useState({ open: false, gift: null });
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('');
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  // Load on mount
  useEffect(() => {
    getGifts()
      .then((data) => {
        const formatted = data.map((g) => ({
          ...g,
          scope: g.scope || 'GLOBAL',
          overrideValue: g.overrideValue || '',
          inheritedValue: g.inheritedValue || `${g.diamondPrice} diamonds`
        }));
        setGifts(formatted);
      })
      .finally(() => setIsLoading(false));
  }, []);

  // Save callback from modal
  function handleSave(updated, mode) {
    if (mode === 'create') {
      setGifts((prev) => [updated, ...prev]);
    } else {
      setGifts((prev) => prev.map((g) => (g.id === updated.id ? updated : g)));
    }
  }

  async function handleDelete() {
    if (!deleteModal.gift) return;
    setIsDeleting(true);
    try {
      setGifts((prev) => prev.filter((g) => g.id !== deleteModal.gift.id));
    } finally {
      setIsDeleting(false);
      setDeleteModal({ open: false, gift: null });
    }
  }

  const handleOpenInheritance = (gift) => {
    setInheritanceModal({ open: true, gift });
    setScope(gift.scope || 'GLOBAL');
    setOverrideValue(gift.overrideValue || '');
    setInheritedValue(gift.inheritedValue || `${gift.diamondPrice} diamonds`);
  };

  const handleSaveInheritance = async () => {
    const { gift } = inheritanceModal;
    if (!gift) return;

    setGifts((prev) => prev.map((g) => {
      if (g.id === gift.id) {
        return {
          ...g,
          scope,
          overrideValue,
          diamondPrice: overrideValue && !isNaN(parseInt(overrideValue)) ? parseInt(overrideValue) : g.diamondPrice
        };
      }
      return g;
    }));

    await logAdminAction({
      action: 'GIFT_PRICING_INHERITANCE_UPDATED',
      module: 'Virtual Store',
      targetType: 'gift',
      targetId: gift.id,
      targetName: gift.name,
      reason: `Set scope to ${scope} with override: ${overrideValue}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Inheritance pricing updated for ${gift.name}.`);
    setInheritanceModal({ open: false, gift: null });
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
    }
    showFeedback('Reset scope override to parent settings.');
  };

  const filtered = useMemo(() => {
    return gifts.filter((g) => {
      const matchCat = categoryFilter === 'All' || g.category === categoryFilter;
      const q = search.toLowerCase();
      const matchSearch = !q || g.name.toLowerCase().includes(q);
      return matchCat && matchSearch;
    });
  }, [gifts, search, categoryFilter]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <GiftIcon className="h-6 w-6 text-purple-400" aria-hidden="true" />
            Gift Catalog & Country Pricing
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage virtual gifts that users can send, complete with Global, Region, and Country pricing overrides.</p>
        </div>
        <Button variant="primary" size="sm" leftIcon={Plus} onClick={() => setFormModal({ open: true, gift: null })}>
          New Gift
        </Button>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Category Filter */}
      <Card className="p-4 flex flex-col sm:flex-row gap-3 items-start sm:items-center">
        <Input
          placeholder="Search gifts…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1"
        />
        <div className="flex gap-1 flex-wrap">
          {GIFT_CATEGORIES.map((c) => (
            <button
              key={c}
              onClick={() => setCategoryFilter(c)}
              className={[
                'px-2.5 py-1 rounded-lg text-xs font-medium border transition-colors',
                categoryFilter === c
                  ? 'bg-purple-500/20 border-purple-500/50 text-purple-400'
                  : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white',
              ].join(' ')}
            >
              {c}
            </button>
          ))}
        </div>
      </Card>

      {/* Gift Grid */}
      {isLoading ? (
        <div className="text-center py-12 text-slate-400 text-sm">Loading gifts…</div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
          {filtered.map((gift) => (
            <Card key={gift.id} className={['p-4 flex flex-col items-center gap-2 text-center', !gift.active ? 'opacity-50' : ''].join(' ')}>
              <span className="text-4xl">{gift.emoji}</span>
              <div>
                <p className="text-sm font-medium text-white">{gift.name}</p>
                <p className="text-xs text-cyan-400 font-medium">💎 {gift.diamondPrice}</p>
                <div className="flex justify-center items-center gap-1.5 mt-0.5">
                  <Badge variant="purple" className="text-[9px] font-mono"><Globe className="h-2 w-2 mr-0.5 inline" /> {gift.scope}</Badge>
                </div>
              </div>
              <div className="flex items-center gap-1 mt-1">
                <Badge variant={gift.active ? 'success' : 'muted'} className="text-[10px]">
                  {gift.active ? 'Active' : 'Inactive'}
                </Badge>
              </div>
              <div className="flex gap-1.5 mt-2">
                <button
                  onClick={() => setFormModal({ open: true, gift })}
                  className="p-1 rounded text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
                  title="Edit"
                >
                  <Pencil className="h-3 w-3" aria-hidden="true" />
                </button>
                <button
                  onClick={() => handleOpenInheritance(gift)}
                  className="p-1 rounded text-slate-400 hover:text-gold-400 hover:bg-slate-800 transition-colors"
                  title="Pricing Overrides"
                >
                  <Globe className="h-3 w-3" aria-hidden="true" />
                </button>
                <button
                  onClick={() => setDeleteModal({ open: true, gift })}
                  className="p-1 rounded text-slate-400 hover:text-red-400 hover:bg-slate-800 transition-colors"
                  title="Delete"
                >
                  <Trash2 className="h-3 w-3" aria-hidden="true" />
                </button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {!isLoading && filtered.length === 0 && (
        <div className="text-center py-12 text-slate-400">
          <p>No gifts found for this category.</p>
        </div>
      )}

      <GiftFormModal
        isOpen={formModal.open}
        onClose={() => setFormModal({ open: false, gift: null })}
        gift={formModal.gift}
        onSave={handleSave}
      />
      
      <ConfirmDialog
        isOpen={deleteModal.open}
        onClose={() => setDeleteModal({ open: false, gift: null })}
        onConfirm={handleDelete}
        title="Delete Gift"
        description={`Are you sure you want to delete "${deleteModal.gift?.name}"?`}
        confirmLabel="Delete"
        confirmVariant="danger"
        isLoading={isDeleting}
      />

      {/* Pricing Override Modal */}
      {inheritanceModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setInheritanceModal({ open: false, gift: null })}
          title={`Pricing Overrides: ${inheritanceModal.gift?.name}`}
          size="lg"
        >
          <div className="space-y-4">
            <GeographicInheritancePanel
              scope={scope}
              onChangeScope={setScope}
              inheritedValue={inheritedValue}
              overrideValue={overrideValue}
              onChangeOverride={setOverrideValue}
              effectiveValue={overrideValue ? `${overrideValue} diamonds` : inheritedValue}
              onResetScope={handleResetScope}
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setInheritanceModal({ open: false, gift: null })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save Override Config
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
