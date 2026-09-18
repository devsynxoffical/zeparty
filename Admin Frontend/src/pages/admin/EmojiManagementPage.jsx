// ============================================================
// ZeParty Admin Panel — App Emoji & Reaction Control System (JSX)
// Developer Specification: Main App Room & Chat Emoji Tray Engine
// ============================================================

import React, { useState } from 'react';
import {
  Smile, Plus, Search, CheckCircle, ShieldAlert, Sparkles, Filter, Settings,
  Eye, ToggleLeft, ToggleRight, Trash2, Edit, Crown, Layers, Calendar, BarChart2
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { useAuditLog } from '../../context/AuditLogContext';
import apiClient from '../../services/api';

export function EmojiManagementPage() {
  const { logAdminAction } = useAuditLog();
  const [emojis, setEmojis] = useState([]);
  const [loading, setLoading] = useState(true);
  const [masterSwitch, setMasterSwitch] = useState(true);
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [feedback, setFeedback] = useState(null);

  React.useEffect(() => {
    let mounted = true;
    setLoading(true);
    apiClient.get('/v1/admin/assets')
      .then((res) => {
        if (mounted) {
          const items = res.data?.data || [];
          setEmojis(items.filter(a => a.type === 'EMOJI' || a.category === 'EMOJI').map(e => ({
            id: e.id,
            name: e.name,
            category: e.category || 'Default',
            assetUrl: e.assetUrl || e.iconUrl || '',
            format: 'WebP',
            isAnimated: Boolean(e.isAnimated),
            displayOrder: e.displayOrder || 1,
            availability: 'Party & Live Rooms',
            eligibility: 'Everyone',
            status: e.status?.toLowerCase() || 'active',
          })));
          setLoading(false);
        }
      })
      .catch(() => {
        if (mounted) {
          setEmojis([]);
          setLoading(false);
        }
      });
    return () => { mounted = false; };
  }, []);

  // Modals
  const [showAddModal, setShowAddModal] = useState(false);
  const [editEmoji, setEditEmoji] = useState(null);

  const [formData, setFormData] = useState({
    name: '',
    category: 'Default',
    assetUrl: '',
    format: 'WebP',
    isAnimated: true,
    displayOrder: 1,
    availability: 'Party & Live Rooms',
    eligibility: 'Everyone',
    unlockType: 'Free',
    priceCoins: 0,
    scope: 'Global'
  });

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleCreateEmoji = (e) => {
    e.preventDefault();
    const newEmoji = {
      id: `emoji-${Date.now()}`,
      ...formData,
      status: 'ACTIVE',
      usageCount: 0
    };
    setEmojis([newEmoji, ...emojis]);
    logAdminAction({
      action: 'ADD_APP_EMOJI',
      module: 'Emoji Management',
      targetType: 'EMOJI',
      targetId: newEmoji.id,
      reason: `Uploaded new emoji: ${newEmoji.name}`,
      riskLevel: 'MEDIUM',
      status: 'SUCCESS'
    });
    showFeedback(`Emoji "${newEmoji.name}" added to room tray!`);
    setShowAddModal(false);
  };

  const handleToggleStatus = (emoji) => {
    const newStatus = emoji.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    setEmojis(emojis.map((e) => (e.id === emoji.id ? { ...e, status: newStatus } : e)));
    logAdminAction({
      action: `TOGGLE_EMOJI_${newStatus}`,
      module: 'Emoji Management',
      targetType: 'EMOJI',
      targetId: emoji.id,
      reason: `Status changed to ${newStatus}`,
      riskLevel: 'MEDIUM',
      status: 'SUCCESS'
    });
    showFeedback(`Emoji "${emoji.name}" set to ${newStatus}.`);
  };

  const filteredEmojis = emojis.filter((e) => {
    const matchCategory = categoryFilter === 'all' || e.category.toLowerCase() === categoryFilter.toLowerCase();
    const matchSearch = !search || e.name.toLowerCase().includes(search.toLowerCase());
    return matchCategory && matchSearch;
  });

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Smile className="h-7 w-7 text-gold-400" />
            App Room Emoji & Reaction Tray System
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Database-Driven Emoji Tray Control: Master ON/OFF, Asset Upload, Categories, SVIP/Noble Rules & Pricing.
          </p>
        </div>
        <Button variant="primary" size="sm" onClick={() => setShowAddModal(true)}>
          <Plus className="h-4 w-4 mr-1" /> Add New Emoji Asset
        </Button>
      </div>

      {feedback && (
        <div className="p-4 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-sm font-medium flex items-center gap-2 animate-pulse">
          <CheckCircle className="h-5 w-5" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Global Master Switch */}
      <Card className="p-4 flex justify-between items-center bg-slate-900/80 border-slate-800">
        <div>
          <p className="font-bold text-white text-sm flex items-center gap-2">
            <Sparkles className="h-4 w-4 text-gold-400" /> App-Wide Room Emoji Tray Master Switch
          </p>
          <p className="text-xs text-slate-400 mt-0.5">
            Turning OFF completely disables the emoji/reaction tray in all Live & Party voice rooms worldwide.
          </p>
        </div>
        <button
          onClick={() => {
            setMasterSwitch(!masterSwitch);
            showFeedback(`Global App Emoji System set to ${!masterSwitch ? 'ENABLED' : 'DISABLED'}.`);
          }}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-colors ${
            masterSwitch ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40' : 'bg-rose-500/20 text-rose-400 border border-rose-500/40'
          }`}
        >
          Master System: {masterSwitch ? 'GLOBAL ON' : 'GLOBAL OFF'}
        </button>
      </Card>

      {/* Filter Bar */}
      <Card className="p-4 flex flex-col sm:flex-row items-center justify-between gap-4">
        <Input
          size="sm"
          placeholder="Search emojis by name or category..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          containerClassName="flex-1 max-w-md"
        />

        <div className="flex items-center gap-2">
          <span className="text-xs text-slate-400 font-bold">Category:</span>
          {['all', 'Default', 'Love', 'Funny', 'SVIP', 'Noble'].map((cat) => (
            <button
              key={cat}
              onClick={() => setCategoryFilter(cat)}
              className={`px-2.5 py-1 rounded-lg text-xs font-bold uppercase transition-colors border ${
                categoryFilter === cat ? 'bg-gold-500/20 text-gold-400 border-gold-500/50' : 'bg-slate-800 text-slate-400 border-slate-700 hover:text-white'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </Card>

      {/* Emoji Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
        {filteredEmojis.map((emoji) => (
          <Card key={emoji.id} className="p-4 flex flex-col justify-between space-y-3">
            <div>
              <div className="flex justify-between items-start mb-2">
                <Badge variant={emoji.category === 'SVIP' ? 'purple' : 'primary'}>{emoji.category}</Badge>
                <Badge variant={emoji.status === 'ACTIVE' ? 'success' : 'danger'}>{emoji.status}</Badge>
              </div>

              <div className="flex items-center gap-3 my-2">
                <img src={emoji.assetUrl} alt={emoji.name} className="w-12 h-12 object-cover rounded-lg border border-slate-700 bg-slate-900" />
                <div>
                  <h4 className="font-bold text-white text-sm">{emoji.name}</h4>
                  <p className="text-[11px] text-slate-400">{emoji.format} • {emoji.isAnimated ? 'Animated' : 'Static'}</p>
                </div>
              </div>

              <div className="space-y-1 text-[11px] text-slate-400 bg-slate-900/60 p-2.5 rounded-lg border border-slate-800">
                <p><strong className="text-slate-300">Room Availability:</strong> {emoji.availability}</p>
                <p><strong className="text-slate-300">Eligibility:</strong> {emoji.eligibility}</p>
                <p><strong className="text-slate-300">Unlock:</strong> {emoji.unlockType}</p>
              </div>
            </div>

            <div className="pt-2 border-t border-slate-800 flex justify-between items-center text-xs">
              <span className="text-slate-400">Total Sends: <strong className="text-gold-400">{emoji.usageCount}</strong></span>
              <button
                onClick={() => handleToggleStatus(emoji)}
                className={`p-1.5 rounded transition-colors ${
                  emoji.status === 'ACTIVE' ? 'text-amber-400 hover:bg-slate-800' : 'text-emerald-400 hover:bg-slate-800'
                }`}
              >
                {emoji.status === 'ACTIVE' ? <ToggleLeft className="h-4 w-4" /> : <ToggleRight className="h-4 w-4" />}
              </button>
            </div>
          </Card>
        ))}
      </div>

      {/* Add Emoji Modal */}
      {showAddModal && (
        <Modal isOpen={true} onClose={() => setShowAddModal(false)} title="Add App Room Emoji Asset">
          <form onSubmit={handleCreateEmoji} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-[11px] text-slate-400 mb-1 block">Emoji Name *</label>
              <Input size="sm" value={formData.name} onChange={(e) => setFormData({ ...formData, name: e.target.value })} required />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Category</label>
                <Input size="sm" value={formData.category} onChange={(e) => setFormData({ ...formData, category: e.target.value })} />
              </div>
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Asset URL (WebP/PNG)</label>
                <Input size="sm" value={formData.assetUrl} onChange={(e) => setFormData({ ...formData, assetUrl: e.target.value })} placeholder="https://..." required />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Eligibility Group</label>
                <Input size="sm" value={formData.eligibility} onChange={(e) => setFormData({ ...formData, eligibility: e.target.value })} placeholder="Everyone, SVIP Only..." />
              </div>
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Coin Price (0 = Free)</label>
                <Input size="sm" type="number" value={formData.priceCoins} onChange={(e) => setFormData({ ...formData, priceCoins: Number(e.target.value) })} />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowAddModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">Save Emoji Asset</Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
