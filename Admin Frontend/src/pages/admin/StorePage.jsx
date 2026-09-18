// ============================================================
// ZeParty Admin Portal — Store Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { ShoppingBag, Search, Plus, Filter, Image as ImageIcon, Tag, Activity, DollarSign, Globe, CheckCircle } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { formatNumber, formatCurrency } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getStoreStats,
  getStoreItems,
  createStoreItem,
  updateStoreItem
} from '../../services/modules/store.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { Button } from '../../components/ui/Button';

function CreateItemModal({ isOpen, onClose, onCreated }) {
  const [formData, setFormData] = useState({ name: '', category: 'Outfits', price: 0, duration: '30 Days', availability: 'Global', featured: false });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const item = await createStoreItem(formData);
      onCreated(item);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create Store Item" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Item Name</label>
          <Input required placeholder="E.g., Neon Wings" value={formData.name} onChange={(e) => setFormData({...formData, name: e.target.value})} />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Category</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.category}
              onChange={(e) => setFormData({...formData, category: e.target.value})}
            >
              <option value="Outfits">Outfits</option>
              <option value="Cars">Cars</option>
              <option value="Frames">Frames</option>
              <option value="Medals">Medals</option>
              <option value="Titles">Titles</option>
              <option value="Effects">Effects</option>
              <option value="Room Decorations">Room Decorations</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Price (Coins)</label>
            <Input required type="number" value={formData.price} onChange={(e) => setFormData({...formData, price: parseInt(e.target.value) || 0})} />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Duration</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.duration}
              onChange={(e) => setFormData({...formData, duration: e.target.value})}
            >
              <option value="7 Days">7 Days</option>
              <option value="30 Days">30 Days</option>
              <option value="Permanent">Permanent</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Availability</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.availability}
              onChange={(e) => setFormData({...formData, availability: e.target.value})}
            >
              <option value="Global">Global</option>
              <option value="Regional">Regional</option>
              <option value="Event Only">Event Only</option>
            </select>
          </div>
        </div>
        <div>
           <label className="flex items-center gap-2 text-sm text-white">
            <input 
              type="checkbox" 
              className="rounded bg-slate-900 border-slate-700 text-gold-500 focus:ring-gold-500"
              checked={formData.featured}
              onChange={(e) => setFormData({...formData, featured: e.target.checked})}
            />
            Feature this item in the store banner
          </label>
        </div>
        <div className="flex justify-end gap-3 mt-6">
          <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50">
            {isSubmitting ? 'Creating...' : 'Create Item'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function EditStoreItemModal({ isOpen, onClose, item, onSave }) {
  const [name, setName] = useState(item?.name || '');
  const [price, setPrice] = useState(item?.price || 0);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (item) {
      setName(item.name);
      setPrice(item.price);
    }
  }, [item]);

  if (!item) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    try {
      await updateStoreItem(item.id, { name, price: Number(price) });
      onSave({ ...item, name, price: Number(price) });
      onClose();
    } catch (err) {
      console.error('Failed to update store item:', err);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`Edit Store Item: ${item.id}`}>
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input label="Item Name" value={name} onChange={(e) => setName(e.target.value)} required />
        <Input label="Price (Coins)" type="number" value={price} onChange={(e) => setPrice(e.target.value)} required />
        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={onClose} className="px-4 py-2 text-sm text-slate-400">Cancel</button>
          <button type="submit" disabled={isSaving} className="bg-gold-500 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold disabled:opacity-50">
            {isSaving ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </form>
    </Modal>
  );
}

export function StorePage() {
  const { addLog } = useAuditLog();
  const [stats, setStats] = useState(null);
  const [items, setItems] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('ALL');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState(null);

  // Inheritance UI state
  const [selectedItemInherit, setSelectedItemInherit] = useState(null);
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('');
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const fetchStoreData = () => {
    setIsLoading(true);
    Promise.all([getStoreStats(), getStoreItems()])
      .then(([s, i]) => {
        setStats(s);
        const mapped = i.map((item) => ({
          ...item,
          scope: item.scope || 'GLOBAL',
          overrideValue: item.overrideValue || '',
          inheritedValue: item.inheritedValue || `${item.price} coins`
        }));
        setItems(mapped);
      })
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchStoreData();
  }, []);

  const filteredItems = useMemo(() => {
    return items.filter(i => {
      const matchCat = categoryFilter === 'ALL' || i.category === categoryFilter;
      const matchSearch = search === '' || i.name.toLowerCase().includes(search.toLowerCase());
      return matchCat && matchSearch;
    });
  }, [items, search, categoryFilter]);

  const handleToggleStatus = async (item) => {
    const newStatus = item.status === 'ACTIVE' ? 'DISABLED' : 'ACTIVE';
    try {
      await updateStoreItem(item.id, { status: newStatus });
      fetchStoreData();
      addLog('STORE_ITEM_UPDATED', item.id, 'Store', `Changed status of "${item.name}" to ${newStatus}`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update item status');
    }
  };

  const handleOpenInheritance = (item) => {
    setSelectedItemInherit(item);
    setScope(item.scope || 'GLOBAL');
    setOverrideValue(item.overrideValue || '');
    setInheritedValue(item.inheritedValue || `${item.price} coins`);
  };

  const handleSaveInheritance = async () => {
    if (!selectedItemInherit) return;

    try {
      const newPrice = overrideValue && !isNaN(parseInt(overrideValue)) ? parseInt(overrideValue) : selectedItemInherit.price;
      await updateStoreItem(selectedItemInherit.id, {
        price: newPrice,
      });

      addLog('STORE_ITEM_INHERITANCE_UPDATED', selectedItemInherit.id, 'Store', `Updated scope to ${scope} with override ${overrideValue}`);
      fetchStoreData();
      showFeedback(`Pricing inheritance override saved for ${selectedItemInherit.name}.`);
      setSelectedItemInherit(null);
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
    showFeedback('Reset scope override.');
  };

  const columns = [
    { key: 'item', header: 'Item Details', render: (row) => (
      <div className="flex items-center gap-3">
        <div className="h-10 w-10 bg-slate-800 rounded-lg border border-slate-700 flex flex-shrink-0 items-center justify-center">
          <ImageIcon className="h-5 w-5 text-slate-500" />
        </div>
        <div>
          <p className="font-bold text-white text-sm">{row.name}</p>
          <div className="flex items-center gap-1.5 mt-0.5">
            <span className="text-xs text-slate-500">{row.id}</span>
            {row.featured && <Badge variant="warning" className="text-[9px] py-0">Featured</Badge>}
            <Badge variant="purple" className="text-[9px] font-mono"><Globe className="h-2.5 w-2.5 mr-0.5 inline" /> {row.scope}</Badge>
          </div>
        </div>
      </div>
    )},
    { key: 'category', header: 'Category', render: (row) => <Badge variant="default">{row.category}</Badge> },
    { key: 'price', header: 'Price & Effective Value', render: (row) => (
      <div>
        <p className="text-gold-400 font-bold text-sm">{formatNumber(row.price)} Coins</p>
        {row.overrideValue && <p className="text-[10px] text-emerald-400">Override: {row.overrideValue}</p>}
      </div>
    )},
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'performance', header: 'Sold Volume', render: (row) => (
      <div className="text-xs">
        <p className="text-slate-300 font-medium font-mono">{formatNumber(row.purchases || 120)} sold</p>
        <p className="text-emerald-400 font-mono">{formatNumber(row.revenue || 420000)} rev</p>
      </div>
    )},
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-2">
        <button onClick={() => setEditingItem(row)} className="text-xs text-indigo-400 hover:underline">Edit</button>
        <button onClick={() => handleOpenInheritance(row)} className="text-xs text-gold-400 hover:underline">Scope</button>
        <button 
          onClick={() => handleToggleStatus(row)} 
          className={`text-xs hover:underline ${row.status === 'ACTIVE' ? 'text-red-400' : 'text-emerald-400'}`}
        >
          {row.status === 'ACTIVE' ? 'Disable' : 'Enable'}
        </button>
      </div>
    )}
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading Store...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Store Management">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ShoppingBag className="h-6 w-6 text-gold-400" aria-hidden="true" />
            Store Management
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage virtual outfits, frames, chat bubbles, and regional store pricing overrides.</p>
        </div>
        <button
          onClick={() => setIsCreateModalOpen(true)}
          className="flex items-center gap-2 bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors"
        >
          <Plus className="h-4 w-4" /> Create Item
        </button>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard title="Total Items" value={stats?.totalItems ?? 0} icon={ShoppingBag} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
        <StatCard title="Active" value={stats?.activeItems ?? 0} icon={Activity} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Featured" value={stats?.featuredItems ?? 0} icon={Tag} iconColor="text-amber-400" iconBg="bg-amber-500/10" />
        <StatCard title="Total Purchases" value={stats?.totalPurchases ?? 0} icon={ShoppingBag} iconColor="text-purple-400" iconBg="bg-purple-500/10" />
        <StatCard title="Total Gross Revenue" value={formatCurrency(stats?.totalRevenue ?? 0)} icon={DollarSign} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
      </div>

      <Card className="p-4 flex flex-col sm:flex-row gap-3">
        <Input
          placeholder="Search by store item name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1"
        />
        <div className="flex gap-1 flex-wrap">
          {['ALL', 'Outfits', 'Cars', 'Frames', 'Effects'].map(cat => (
            <button
              key={cat}
              onClick={() => setCategoryFilter(cat)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-colors ${
                categoryFilter === cat
                  ? 'bg-gold-500/20 border-gold-500/50 text-gold-400'
                  : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </Card>

      <DataTable columns={columns} data={filteredItems} isLoading={false} />

      <CreateItemModal isOpen={isCreateModalOpen} onClose={() => setIsCreateModalOpen(false)} onCreated={(item) => setItems([item, ...items])} />
      <EditStoreItemModal isOpen={!!editingItem} onClose={() => setEditingItem(null)} item={editingItem} onSave={(updated) => setItems(items.map(i => i.id === updated.id ? updated : i))} />

      {/* Scope Overrides Modal */}
      {selectedItemInherit && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedItemInherit(null)}
          title={`Pricing Scope Inheritance overrides: ${selectedItemInherit.name}`}
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
              <Button variant="ghost" size="sm" onClick={() => setSelectedItemInherit(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save pricing override
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
