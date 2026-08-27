// ============================================================
// ZeParty Admin Portal — Virtual Items Catalog Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState } from 'react';
import { Sparkles, Search, Plus, Eye, Tag, Lock, CheckCircle } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { useAuditLog } from '../../context/AuditLogContext';

const INITIAL_ITEMS = [
  { id: 'itm-01', name: 'Gold Crown Frame', type: 'Avatar Frame', priceCoins: 50000, duration: '30 Days', rarity: 'Legendary', active: true, scope: 'GLOBAL', overrideValue: '', inheritedValue: '50,000 coins' },
  { id: 'itm-02', name: 'Dragon Mount', type: 'Ride', priceCoins: 120000, duration: '7 Days', rarity: 'Mythic', active: true, scope: 'REGION', overrideValue: '110,000 coins', inheritedValue: '120,000 coins' },
  { id: 'itm-03', name: 'Golden Aura Bubble', type: 'Chat Bubble', priceCoins: 15000, duration: '30 Days', rarity: 'Rare', active: true, scope: 'GLOBAL', overrideValue: '', inheritedValue: '15,000 coins' },
  { id: 'itm-04', name: 'Top Gifter Badge', type: 'Badge', priceCoins: 0, duration: 'Permanent', rarity: 'Unique', active: true, scope: 'COUNTRY', overrideValue: 'Grant only', inheritedValue: '0 coins' },
];

export function VirtualItemsPage() {
  const { logAdminAction } = useAuditLog();
  const [items, setItems] = useState(INITIAL_ITEMS);
  const [search, setSearch] = useState('');
  const [selectedItem, setSelectedItem] = useState(null);
  
  // Inheritance UI state for chosen item
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('');
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleOpenInheritance = (item) => {
    setSelectedItem(item);
    setScope(item.scope || 'GLOBAL');
    setOverrideValue(item.overrideValue || '');
    setInheritedValue(item.inheritedValue || '50,000 coins');
  };

  const handleSaveInheritance = async () => {
    if (!selectedItem) return;

    setItems(items.map(i => i.id === selectedItem.id ? {
      ...i,
      scope,
      overrideValue,
      priceCoins: overrideValue && !isNaN(parseInt(overrideValue)) ? parseInt(overrideValue) : i.priceCoins
    } : i));

    await logAdminAction({
      action: 'VIRTUAL_ITEM_INHERITANCE_UPDATED',
      module: 'Virtual Store',
      targetType: 'virtual_item',
      targetId: selectedItem.id,
      targetName: selectedItem.name,
      reason: `Set scope to ${scope} with override: ${overrideValue}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Inheritance settings updated for ${selectedItem.name}.`);
    setSelectedItem(null);
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
      showFeedback('Reset country override. Inheriting from Region scope.');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
      showFeedback('Reset region override. Inheriting from Global default.');
    }
  };

  const filtered = items.filter(i => {
    const q = search.toLowerCase();
    return !q || i.name.toLowerCase().includes(q) || i.type.toLowerCase().includes(q);
  });

  const columns = [
    {
      key: 'name',
      header: 'Item Name',
      render: (r) => (
        <div>
          <p className="text-xs font-bold text-white">{r.name}</p>
          <p className="text-[10px] text-slate-400">ID: {r.id}</p>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Category',
      render: (r) => <Badge variant="purple">{r.type}</Badge>,
    },
    {
      key: 'scope',
      header: 'Pricing Scope',
      render: (r) => <Badge variant={r.scope === 'GLOBAL' ? 'primary' : 'info'}>{r.scope}</Badge>,
    },
    {
      key: 'price',
      header: 'Price / Effective Value',
      render: (r) => (
        <div>
          <p className="text-xs font-bold text-yellow-400">🪙 {formatNumber(r.priceCoins)} Coins</p>
          {r.overrideValue && <p className="text-[10px] text-emerald-400">Override: {r.overrideValue}</p>}
        </div>
      ),
    },
    {
      key: 'status',
      header: 'State',
      render: (r) => <StatusBadge status={r.active ? 'active' : 'inactive'} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <Button variant="outline" size="xs" onClick={() => handleOpenInheritance(r)}>
          Pricing & Scope Overrides
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Sparkles className="h-6 w-6 text-gold-400" />
            Virtual Items Catalog
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage avatar frames, entrance rides, bubbles, and badges with local currency pricing overrides.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      <Card className="p-4">
        <Input
          placeholder="Search by item name or category..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={filtered} isLoading={false} />

      {/* Inheritance Overrides Modal */}
      {selectedItem && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedItem(null)}
          title={`Pricing & Scope Overrides: ${selectedItem.name}`}
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
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedItem(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save Override Settings
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
