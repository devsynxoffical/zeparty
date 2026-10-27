// ============================================================
// ZeParty Admin Portal — Gift Catalog Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { Gift as GiftIcon, Plus, Pencil, Trash2, Search, Globe, CheckCircle, Image as ImageIcon } from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal, ConfirmDialog } from '../../components/ui/Modal';
import { Select } from '../../components/ui/Select';
import { resolveMediaUrl, handleImageError } from '../../utils/imageUrl';
import {
  getGifts,
  createGift,
  updateGift,
  deleteGift,
} from '../../services/modules/gifts.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { useAuditLog } from '../../context/AuditLogContext';

const GIFT_CATEGORIES = ['All', 'Popular', 'Luxury', 'VIP', 'Audio'];

// ── Gift Form Modal ───────────────────────────────────────────
function GiftFormModal({ isOpen, onClose, gift, onSave }) {
  const isEdit = !!gift;
  const [name, setName] = useState(gift?.name || '');
  const [iconUrl, setIconUrl] = useState(gift?.iconUrl || gift?.icon || '');
  const [price, setPrice] = useState(gift?.coinValue || gift?.coinPrice || gift?.diamondPrice || '');
  const [category, setCategory] = useState(gift?.giftCategory || gift?.category || 'Popular');
  const [active, setActive] = useState(gift?.isActive ?? gift?.active ?? true);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (isOpen) {
      setName(gift?.name || '');
      setIconUrl(gift?.iconUrl || gift?.icon || '');
      setPrice(gift?.coinValue || gift?.coinPrice || gift?.diamondPrice || '');
      setCategory(gift?.giftCategory || gift?.category || 'Popular');
      setActive(gift?.isActive ?? gift?.active ?? true);
      setError('');
    }
  }, [isOpen, gift]);

  async function handleSubmit(e) {
    e.preventDefault();
    setIsSaving(true);
    setError('');
    try {
      const payload = {
        name,
        iconUrl: iconUrl.trim() || '/assets/images/party_gift_box.jpg',
        coinValue: Number(price) || 10,
        category: category.toUpperCase(),
        giftCategory: category.toUpperCase(),
        active,
        isActive: active,
      };
      if (isEdit) {
        await updateGift(gift.id, payload);
        onSave({ ...gift, ...payload });
      } else {
        const newGift = await createGift(payload);
        onSave(newGift, 'create');
      }
      onClose();
    } catch {
      setError('Failed to save gift. Please verify the fields and try again.');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={isEdit ? 'Edit Gift' : 'Create Gift'} size="md">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          label="Gift Name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          required
          placeholder="e.g. Golden Crown"
        />

        <div className="flex gap-4 items-center">
          <div className="flex-1">
            <Input
              label="Icon / Image URL or Path"
              value={iconUrl}
              onChange={(e) => setIconUrl(e.target.value)}
              placeholder="e.g. /assets/gifts/classic/rocket.png"
            />
          </div>
          <div className="w-16 h-16 rounded-xl bg-slate-800 border border-slate-700 flex items-center justify-center overflow-hidden shrink-0 mt-5">
            {iconUrl ? (
              <img
                src={resolveMediaUrl(iconUrl, 'gift')}
                alt="Preview"
                onError={(e) => handleImageError(e, 'gift')}
                className="w-12 h-12 object-contain"
              />
            ) : (
              <ImageIcon className="w-6 h-6 text-slate-500" />
            )}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Input
            label="Coin Price (Coins)"
            type="number"
            min="1"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            required
            placeholder="e.g. 50"
          />
          <Select
            label="Category"
            value={category}
            onChange={(e) => setCategory(e.target.value)}
          >
            {GIFT_CATEGORIES.filter((c) => c !== 'All').map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </Select>
        </div>

        <label className="flex items-center gap-2 cursor-pointer mt-1">
          <input
            type="checkbox"
            checked={active}
            onChange={(e) => setActive(e.target.checked)}
            className="h-4 w-4 rounded border-slate-700 bg-slate-800 accent-purple-600"
          />
          <span className="text-xs text-slate-300">Active (Visible in Virtual Store & In-App Gifting)</span>
        </label>

        {error && <p className="text-xs text-red-400">{error}</p>}

        <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>
            Cancel
          </Button>
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

  const fetchGiftsData = () => {
    setIsLoading(true);
    getGifts()
      .then((data) => {
        const formatted = (Array.isArray(data) ? data : []).map((g) => ({
          ...g,
          scope: g.scope || 'GLOBAL',
          overrideValue: g.overrideValue || '',
          inheritedValue: g.inheritedValue || `${g.coinValue || g.coinPrice || g.diamondPrice || 0} coins`
        }));
        setGifts(formatted);
      })
      .catch((err) => {
        console.error('Failed to load gifts:', err);
        setGifts([]);
      })
      .finally(() => setIsLoading(false));
  };

  // Load on mount
  useEffect(() => {
    fetchGiftsData();
  }, []);

  function handleSave(updated, mode) {
    fetchGiftsData();
  }

  async function handleDelete() {
    if (!deleteModal.gift) return;
    setIsDeleting(true);
    try {
      await deleteGift(deleteModal.gift.id);
      await logAdminAction({
        action: 'GIFT_DELETED',
        module: 'Virtual Store',
        targetType: 'gift',
        targetId: deleteModal.gift.id,
        targetName: deleteModal.gift.name,
        reason: 'Gift deleted by administrator',
        riskLevel: 'HIGH',
      });
      fetchGiftsData();
      showFeedback(`Gift "${deleteModal.gift.name}" deleted.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to delete gift');
    } finally {
      setIsDeleting(false);
      setDeleteModal({ open: false, gift: null });
    }
  }

  const handleOpenInheritance = (gift) => {
    setInheritanceModal({ open: true, gift });
    setScope(gift.scope || 'GLOBAL');
    setOverrideValue(gift.overrideValue || '');
    setInheritedValue(gift.inheritedValue || `${gift.coinValue || gift.coinPrice || gift.diamondPrice || 0} coins`);
  };

  const handleSaveInheritance = async () => {
    const { gift } = inheritanceModal;
    if (!gift) return;

    try {
      const newPrice = overrideValue && !isNaN(parseInt(overrideValue)) ? parseInt(overrideValue) : (gift.coinValue || gift.coinPrice || gift.diamondPrice);
      await updateGift(gift.id, {
        coinValue: newPrice,
      });

      await logAdminAction({
        action: 'GIFT_PRICING_INHERITANCE_UPDATED',
        module: 'Virtual Store',
        targetType: 'gift',
        targetId: gift.id,
        targetName: gift.name,
        reason: `Set scope to ${scope} with override: ${overrideValue}`,
        riskLevel: 'MEDIUM',
      });

      fetchGiftsData();
      showFeedback(`Inheritance pricing updated for ${gift.name}.`);
      setInheritanceModal({ open: false, gift: null });
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to save inheritance');
    }
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
      const gCat = (g.giftCategory || g.category || '').toUpperCase();
      const fCat = categoryFilter.toUpperCase();
      const matchCat = fCat === 'ALL' || gCat === fCat;
      const q = search.trim().toLowerCase();
      const matchSearch = !q || (g.name || '').toLowerCase().includes(q);
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

      {/* Category Filter & Search */}
      <Card className="p-4 flex flex-col sm:flex-row gap-3 items-start sm:items-center">
        <Input
          placeholder="Search gifts…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1"
        />
        <div className="flex gap-1.5 flex-wrap">
          {GIFT_CATEGORIES.map((c) => (
            <button
              key={c}
              onClick={() => setCategoryFilter(c)}
              className={[
                'px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all duration-200',
                categoryFilter.toUpperCase() === c.toUpperCase()
                  ? 'bg-purple-600/30 border-purple-500 text-purple-300 shadow-sm shadow-purple-500/20'
                  : 'bg-slate-800/80 border-slate-700/80 text-slate-400 hover:text-white hover:border-slate-600',
              ].join(' ')}
            >
              {c}
            </button>
          ))}
        </div>
      </Card>

      {/* Gift Grid */}
      {isLoading ? (
        <div className="text-center py-16 text-slate-400 text-sm">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-purple-500 mb-2"></div>
          <p>Loading gift catalog…</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
          {filtered.map((gift) => (
            <Card
              key={gift.id}
              className={[
                'p-4 flex flex-col items-center gap-2.5 text-center transition-all duration-200 hover:border-purple-500/40 group relative',
                !(gift.isActive ?? gift.active ?? true) ? 'opacity-50' : '',
              ].join(' ')}
            >
              <div className="relative w-16 h-16 rounded-xl bg-slate-800/80 border border-slate-700/60 flex items-center justify-center p-1.5 overflow-hidden group-hover:border-purple-500/50 transition-colors shadow-inner">
                <img
                  src={resolveMediaUrl(gift.iconUrl || gift.icon, 'gift')}
                  alt={gift.name}
                  onError={(e) => handleImageError(e, 'gift')}
                  className="w-full h-full object-contain filter drop-shadow-md transition-transform duration-300 group-hover:scale-110"
                  loading="lazy"
                />
              </div>

              <div className="w-full text-center">
                <p className="text-sm font-semibold text-white truncate" title={gift.name}>
                  {gift.name}
                </p>
                <p className="text-xs text-amber-400 font-semibold flex items-center justify-center gap-1 mt-0.5">
                  <span>🪙</span> {Number(gift.coinValue || gift.coinPrice || gift.diamondPrice || 0).toLocaleString()} Coins
                </p>
                <div className="flex justify-center items-center gap-1.5 mt-1 flex-wrap">
                  <Badge variant="purple" className="text-[9px] font-mono tracking-wider">
                    {gift.giftCategory || gift.category || 'POPULAR'}
                  </Badge>
                  {gift.scope && (
                    <Badge variant="default" className="text-[9px] font-mono text-slate-400 border-slate-700">
                      <Globe className="h-2.5 w-2.5 mr-0.5 inline text-slate-400" /> {gift.scope}
                    </Badge>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-1">
                <Badge variant={(gift.isActive ?? gift.active ?? true) ? 'success' : 'muted'} className="text-[10px]">
                  {(gift.isActive ?? gift.active ?? true) ? 'Active' : 'Inactive'}
                </Badge>
              </div>

              <div className="flex gap-1.5 mt-1 border-t border-slate-800/60 pt-2 w-full justify-center">
                <button
                  onClick={() => setFormModal({ open: true, gift })}
                  className="p-1.5 rounded text-slate-400 hover:text-white hover:bg-slate-800 transition-colors"
                  title="Edit"
                >
                  <Pencil className="h-3.5 w-3.5" aria-hidden="true" />
                </button>
                <button
                  onClick={() => handleOpenInheritance(gift)}
                  className="p-1.5 rounded text-slate-400 hover:text-amber-400 hover:bg-slate-800 transition-colors"
                  title="Pricing Overrides"
                >
                  <Globe className="h-3.5 w-3.5" aria-hidden="true" />
                </button>
                <button
                  onClick={() => setDeleteModal({ open: true, gift })}
                  className="p-1.5 rounded text-slate-400 hover:text-red-400 hover:bg-slate-800 transition-colors"
                  title="Delete"
                >
                  <Trash2 className="h-3.5 w-3.5" aria-hidden="true" />
                </button>
              </div>
            </Card>
          ))}
        </div>
      )}

      {!isLoading && filtered.length === 0 && (
        <div className="text-center py-16 text-slate-400 bg-slate-900/40 border border-slate-800 rounded-xl">
          <GiftIcon className="h-12 w-12 text-slate-600 mx-auto mb-2 opacity-50" />
          <p className="font-medium text-slate-300">No gifts found</p>
          <p className="text-xs text-slate-500 mt-1">
            {search ? `No gifts matching "${search}" in ${categoryFilter}` : `No gifts in category "${categoryFilter}"`}
          </p>
          {categoryFilter !== 'All' && (
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => setCategoryFilter('All')}
            >
              View All Gifts
            </Button>
          )}
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
              effectiveValue={overrideValue ? `${overrideValue} coins` : inheritedValue}
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

