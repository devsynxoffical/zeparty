// ============================================================
// ZeParty Admin Panel — App Emoji & Reaction Control System (JSX)
// Developer Specification: Main App Room & Chat Emoji Tray Engine
// ============================================================

import React, { useState, useEffect } from 'react';
import {
  Smile, Plus, Search, CheckCircle, ShieldAlert, Sparkles, Filter, Settings,
  Eye, ToggleLeft, ToggleRight, Trash2, Edit, Crown, Layers, Calendar, BarChart2
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { useAuditLog } from '../../context/AuditLogContext';
import apiClient from '../../services/api';
import { resolveMediaUrl, handleImageError } from '../../utils/imageUrl';

export function EmojiManagementPage() {
  const { logAdminAction } = useAuditLog();
  const [emojis, setEmojis] = useState([]);
  const [categories, setCategories] = useState(['all', 'Default', 'Reaction', 'Game', 'VIP']);
  const [loading, setLoading] = useState(true);
  const [masterSwitch, setMasterSwitch] = useState(true);
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [feedback, setFeedback] = useState(null);

  const fetchEmojis = async () => {
    setLoading(true);
    try {
      const res = await apiClient.get('/v1/admin/emojis');
      const items = res.data?.data || [];
      setEmojis(items.map((e) => ({
        id: e.id,
        name: e.name,
        category: e.category || 'Default',
        panelIconUrl: e.panelIconUrl || e.iconUrl || e.assetUrl,
        reactionUrl: e.reactionUrl || e.animationUrl,
        assetUrl: e.panelIconUrl || e.iconUrl || e.assetUrl,
        format: e.format || 'WebP',
        isAnimated: Boolean(e.isAnimated),
        displayOrder: e.displayOrder || 1,
        availability: e.roomType ? `${e.roomType} Rooms` : 'Party & Live Rooms',
        eligibility: e.isVipOnly ? 'VIP & Nobles' : 'Everyone',
        unlockType: e.priceCoins > 0 ? `${e.priceCoins} Coins` : 'Free',
        priceCoins: Number(e.priceCoins || 0),
        status: (e.status || (e.isActive ? 'ACTIVE' : 'INACTIVE')).toUpperCase(),
        usageCount: e.usageCount || 0,
      })));
      if (res.data?.masterEnabled !== undefined) {
        setMasterSwitch(Boolean(res.data.masterEnabled));
      }
      if (Array.isArray(res.data?.categories) && res.data.categories.length > 0) {
        const uniqueCats = ['all', ...new Set(res.data.categories.map((c) => c.name || c))];
        setCategories(uniqueCats);
      }
    } catch (err) {
      console.error('Failed to load emojis:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEmojis();
  }, []);

  // Modals
  const [showAddModal, setShowAddModal] = useState(false);
  const [formData, setFormData] = useState({
    name: '',
    category: 'Default',
    panelIconUrl: '/assets/emojis/panel_icons/emoji_showlove.png',
    reactionUrl: '/assets/emojis/reactions/emoji_showlove_reaction.webp',
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

  const handleMasterSwitchToggle = async () => {
    const nextVal = !masterSwitch;
    try {
      await apiClient.post('/v1/admin/emojis/master-switch', { enabled: nextVal });
      setMasterSwitch(nextVal);
      logAdminAction({
        action: 'EMOJI_MASTER_SWITCH_TOGGLED',
        module: 'Emoji Management',
        targetType: 'SYSTEM',
        reason: `Global App Emoji System set to ${nextVal ? 'ENABLED' : 'DISABLED'}`,
        riskLevel: 'HIGH',
        status: 'SUCCESS'
      });
      showFeedback(`Global App Emoji System set to ${nextVal ? 'ENABLED' : 'DISABLED'}.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to toggle master switch');
    }
  };

  const handleCreateEmoji = async (e) => {
    e.preventDefault();
    try {
      await apiClient.post('/v1/admin/emojis', {
        name: formData.name,
        category: formData.category,
        panelIconUrl: formData.panelIconUrl,
        reactionUrl: formData.reactionUrl,
        isAnimated: formData.isAnimated,
        priceCoins: Number(formData.priceCoins || 0),
        status: 'ACTIVE',
      });
      logAdminAction({
        action: 'ADD_APP_EMOJI',
        module: 'Emoji Management',
        targetType: 'EMOJI',
        reason: `Uploaded new emoji: ${formData.name}`,
        riskLevel: 'MEDIUM',
        status: 'SUCCESS'
      });
      showFeedback(`Emoji "${formData.name}" added to room tray!`);
      setShowAddModal(false);
      fetchEmojis();
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to create emoji');
    }
  };

  const handleToggleStatus = async (emoji) => {
    try {
      await apiClient.post(`/v1/admin/emojis/${emoji.id}/toggle`);
      const nextStatus = emoji.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
      setEmojis(emojis.map((item) => (item.id === emoji.id ? { ...item, status: nextStatus } : item)));
      logAdminAction({
        action: `TOGGLE_EMOJI_${nextStatus}`,
        module: 'Emoji Management',
        targetType: 'EMOJI',
        targetId: emoji.id,
        reason: `Status changed to ${nextStatus}`,
        riskLevel: 'MEDIUM',
        status: 'SUCCESS'
      });
      showFeedback(`Emoji "${emoji.name}" set to ${nextStatus}.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to toggle emoji status');
    }
  };

  const handleDeleteEmoji = async (emoji) => {
    if (!window.confirm(`Are you sure you want to delete emoji "${emoji.name}"?`)) return;
    try {
      await apiClient.delete(`/v1/admin/emojis/${emoji.id}`);
      setEmojis(emojis.filter((item) => item.id !== emoji.id));
      showFeedback(`Emoji "${emoji.name}" deleted.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to delete emoji');
    }
  };

  const filteredEmojis = emojis.filter((e) => {
    const matchCategory = categoryFilter === 'all' || e.category.toLowerCase() === categoryFilter.toLowerCase();
    const q = search.trim().toLowerCase();
    const matchSearch = !q || e.name.toLowerCase().includes(q) || e.category.toLowerCase().includes(q);
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
        <div className="p-4 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-sm font-medium flex items-center gap-2">
          <CheckCircle className="h-5 w-5 shrink-0" />
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
          onClick={handleMasterSwitchToggle}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-colors border ${
            masterSwitch
              ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40 shadow-sm shadow-emerald-500/10'
              : 'bg-rose-500/20 text-rose-400 border-rose-500/40'
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

        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-xs text-slate-400 font-bold">Category:</span>
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setCategoryFilter(cat)}
              className={`px-2.5 py-1 rounded-lg text-xs font-bold uppercase transition-colors border ${
                categoryFilter.toLowerCase() === cat.toLowerCase()
                  ? 'bg-gold-500/20 text-gold-400 border-gold-500/50'
                  : 'bg-slate-800 text-slate-400 border-slate-700 hover:text-white'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>
      </Card>

      {/* Emoji Grid */}
      {loading ? (
        <div className="text-center py-16 text-slate-400 text-sm">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-gold-400 mb-2"></div>
          <p>Loading emoji & reaction assets…</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {filteredEmojis.map((emoji) => (
            <Card key={emoji.id} className="p-4 flex flex-col justify-between space-y-3 bg-slate-900/60 border-slate-800 hover:border-gold-400/40 transition-all">
              <div>
                <div className="flex justify-between items-start mb-2">
                  <Badge variant={emoji.category === 'SVIP' ? 'purple' : 'primary'}>{emoji.category}</Badge>
                  <Badge variant={emoji.status === 'ACTIVE' ? 'success' : 'danger'}>{emoji.status}</Badge>
                </div>

                <div className="flex items-center gap-3 my-2.5">
                  <div className="w-14 h-14 rounded-xl border border-slate-700/80 bg-slate-950 flex items-center justify-center p-1 overflow-hidden shrink-0 shadow-inner">
                    <img
                      src={resolveMediaUrl(emoji.panelIconUrl || emoji.assetUrl, 'emoji')}
                      alt={emoji.name}
                      onError={(e) => handleImageError(e, 'emoji')}
                      className="w-full h-full object-contain filter drop-shadow-md"
                    />
                  </div>
                  <div>
                    <h4 className="font-bold text-white text-sm">{emoji.name}</h4>
                    <p className="text-[11px] text-slate-400">{emoji.format} • {emoji.isAnimated ? 'Animated' : 'Static'}</p>
                    {emoji.reactionUrl && (
                      <span className="text-[10px] text-purple-400 font-mono mt-0.5 block flex items-center gap-1">
                        <Sparkles className="h-2.5 w-2.5" /> Reaction Ready
                      </span>
                    )}
                  </div>
                </div>

                <div className="space-y-1 text-[11px] text-slate-400 bg-slate-950/70 p-2.5 rounded-lg border border-slate-800/80">
                  <p><strong className="text-slate-300">Room Availability:</strong> {emoji.availability}</p>
                  <p><strong className="text-slate-300">Eligibility:</strong> {emoji.eligibility}</p>
                  <p><strong className="text-slate-300">Unlock:</strong> {emoji.unlockType}</p>
                </div>
              </div>

              <div className="pt-2 border-t border-slate-800 flex justify-between items-center text-xs">
                <span className="text-slate-400">Total Sends: <strong className="text-gold-400">{emoji.usageCount}</strong></span>
                <div className="flex items-center gap-1.5">
                  <button
                    onClick={() => handleToggleStatus(emoji)}
                    className={`p-1.5 rounded transition-colors ${
                      emoji.status === 'ACTIVE' ? 'text-amber-400 hover:bg-slate-800' : 'text-emerald-400 hover:bg-slate-800'
                    }`}
                    title={emoji.status === 'ACTIVE' ? 'Disable Emoji' : 'Enable Emoji'}
                  >
                    {emoji.status === 'ACTIVE' ? <ToggleLeft className="h-4 w-4" /> : <ToggleRight className="h-4 w-4" />}
                  </button>
                  <button
                    onClick={() => handleDeleteEmoji(emoji)}
                    className="p-1.5 rounded text-slate-500 hover:text-red-400 hover:bg-slate-800 transition-colors"
                    title="Delete Emoji"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      )}

      {!loading && filteredEmojis.length === 0 && (
        <div className="text-center py-16 text-slate-400 bg-slate-900/40 border border-slate-800 rounded-xl">
          <Smile className="h-12 w-12 text-slate-600 mx-auto mb-2 opacity-50" />
          <p className="font-medium text-slate-300">No emojis found</p>
          <p className="text-xs text-slate-500 mt-1">
            {search ? `No emojis matching "${search}" in category ${categoryFilter}` : `No emojis in category "${categoryFilter}"`}
          </p>
          {categoryFilter !== 'all' && (
            <Button
              variant="outline"
              size="sm"
              className="mt-3"
              onClick={() => setCategoryFilter('all')}
            >
              View All Emojis
            </Button>
          )}
        </div>
      )}

      {/* Add Emoji Modal */}
      {showAddModal && (
        <Modal isOpen={true} onClose={() => setShowAddModal(false)} title="Add App Room Emoji Asset">
          <form onSubmit={handleCreateEmoji} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-[11px] text-slate-400 mb-1 block">Emoji Name *</label>
              <Input
                size="sm"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                required
                placeholder="e.g. Heart Love"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Category</label>
                <select
                  value={formData.category}
                  onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-xs"
                >
                  <option value="Default">Default</option>
                  <option value="Reaction">Reaction</option>
                  <option value="Game">Game</option>
                  <option value="VIP">VIP</option>
                </select>
              </div>
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Coin Price (0 = Free)</label>
                <Input
                  size="sm"
                  type="number"
                  value={formData.priceCoins}
                  onChange={(e) => setFormData({ ...formData, priceCoins: Number(e.target.value) })}
                />
              </div>
            </div>

            <div>
              <label className="text-[11px] text-slate-400 mb-1 block">Panel Icon URL / Path</label>
              <Input
                size="sm"
                value={formData.panelIconUrl}
                onChange={(e) => setFormData({ ...formData, panelIconUrl: e.target.value })}
                placeholder="/assets/emojis/panel_icons/..."
                required
              />
            </div>

            <div>
              <label className="text-[11px] text-slate-400 mb-1 block">Reaction Animation URL / Path</label>
              <Input
                size="sm"
                value={formData.reactionUrl}
                onChange={(e) => setFormData({ ...formData, reactionUrl: e.target.value })}
                placeholder="/assets/emojis/reactions/..."
              />
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

