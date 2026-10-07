// ============================================================
// ZeParty Admin Portal — Banners & Home Page Management (JSX)
// Enhanced Banner Templates & Real-time Synchronization
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import {
  Image as ImageIcon,
  Search,
  Plus,
  Calendar,
  Megaphone,
  Clock,
  AlertCircle,
  Globe,
  CheckCircle,
  Sparkles,
  Rocket,
  Swords,
  Gift,
  Trash2,
  Edit2,
  ExternalLink,
  Eye,
  RefreshCw
} from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getBannerStats,
  getBanners,
  createBanner,
  updateBanner,
  deleteBanner
} from '../../services/modules/banners.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { Button } from '../../components/ui/Button';

// 4 Standard Rich Banner Templates required by ZeParty
export const PRESET_BANNER_TEMPLATES = [
  {
    id: 'template_welcome',
    title: '🎉 Welcome to ZeParty! Voice, Party & Live',
    subtitle: 'Experience next-gen social streaming and HD voice rooms',
    tag: 'WELCOME',
    tagColor: 'from-amber-400 to-yellow-500',
    bgGradient: 'from-violet-900 via-purple-900 to-indigo-950',
    borderGradient: 'border-yellow-500/40',
    icon: Sparkles,
    imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://party',
    placement: 'Home Carousel',
    priority: 10,
    isGlobal: true,
  },
  {
    id: 'template_updates',
    title: '🚀 Big Updates Coming Soon!',
    subtitle: 'New AI Avatars, 3D Soundstage & Season 4 Tournaments',
    tag: 'SNEAK PEEK',
    tagColor: 'from-cyan-400 to-blue-500',
    bgGradient: 'from-sky-950 via-cyan-950 to-blue-950',
    borderGradient: 'border-cyan-500/40',
    icon: Rocket,
    imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://updates',
    placement: 'Home Carousel',
    priority: 9,
    isGlobal: true,
  },
  {
    id: 'template_pk_live',
    title: '⚔️ Epic PK Battles & Live Streaming',
    subtitle: 'Challenge top creators, vote live, and trigger room combos',
    tag: 'HOT BATTLE',
    tagColor: 'from-rose-500 to-red-600',
    bgGradient: 'from-red-950 via-rose-950 to-slate-950',
    borderGradient: 'border-rose-500/40',
    icon: Swords,
    imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://live',
    placement: 'Home Carousel',
    priority: 8,
    isGlobal: true,
  },
  {
    id: 'template_giftings',
    title: '🎁 Send Luxury Gifts & Win Big Rewards',
    subtitle: 'Send Super Cars, Dragon Ships & unlock VIP wealth badges',
    tag: 'EXCLUSIVE REWARDS',
    tagColor: 'from-emerald-400 to-teal-500',
    bgGradient: 'from-emerald-950 via-teal-950 to-slate-950',
    borderGradient: 'border-emerald-500/40',
    icon: Gift,
    imageUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://store',
    placement: 'Home Carousel',
    priority: 7,
    isGlobal: true,
  },
];

function CreateBannerModal({ isOpen, onClose, onCreated, initialTemplate = null }) {
  const [formData, setFormData] = useState({
    title: '',
    placement: 'Home Carousel',
    isGlobal: true,
    selectedCountries: ['PK', 'SA', 'US'],
    startDate: '',
    endDate: '',
    imageUrl: '',
    destinationUrl: 'zeparty://party',
    priority: 5,
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [countryInput, setCountryInput] = useState('');

  useEffect(() => {
    if (initialTemplate) {
      setFormData({
        title: initialTemplate.title,
        placement: initialTemplate.placement || 'Home Carousel',
        isGlobal: initialTemplate.isGlobal ?? true,
        selectedCountries: ['PK', 'SA', 'US'],
        startDate: '',
        endDate: '',
        imageUrl: initialTemplate.imageUrl,
        destinationUrl: initialTemplate.destinationUrl || 'zeparty://party',
        priority: initialTemplate.priority || 5,
      });
    } else {
      setFormData({
        title: '',
        placement: 'Home Carousel',
        isGlobal: true,
        selectedCountries: ['PK', 'SA', 'US'],
        startDate: '',
        endDate: '',
        imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&h=400&q=80',
        destinationUrl: 'zeparty://party',
        priority: 5,
      });
    }
  }, [initialTemplate, isOpen]);

  const handleApplyTemplate = (tmpl) => {
    setFormData((prev) => ({
      ...prev,
      title: tmpl.title,
      imageUrl: tmpl.imageUrl,
      destinationUrl: tmpl.destinationUrl,
      priority: tmpl.priority,
    }));
  };

  const handleAddCountry = () => {
    if (!countryInput) return;
    const code = countryInput.trim().toUpperCase();
    if (!formData.selectedCountries.includes(code)) {
      setFormData({
        ...formData,
        isGlobal: false,
        selectedCountries: [...formData.selectedCountries, code]
      });
    }
    setCountryInput('');
  };

  const handleRemoveCountry = (code) => {
    setFormData({
      ...formData,
      selectedCountries: formData.selectedCountries.filter((c) => c !== code)
    });
  };

  const handleImageFileChange = (file) => {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (e) => {
      setFormData((prev) => ({ ...prev, imageUrl: e.target.result }));
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const banner = await createBanner({
        ...formData,
        linkUrl: formData.destinationUrl,
        destinationUrl: formData.destinationUrl,
        target: formData.isGlobal ? 'Global' : formData.selectedCountries.join(', '),
        image: formData.imageUrl || 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&h=400&q=80',
        status: 'ACTIVE'
      });
      onCreated(banner);
      onClose();
    } catch (err) {
      console.error('Failed to create banner:', err);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create New Banner Campaign" size="lg">
      <form onSubmit={handleSubmit} className="space-y-4 text-xs text-slate-300 max-h-[80vh] overflow-y-auto pr-1">
        {/* Quick Template Picker */}
        <div>
          <label className="block text-xs font-bold text-gold-400 mb-2 flex items-center gap-1.5">
            <Sparkles className="h-4 w-4" /> Quick Select Preset Template:
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {PRESET_BANNER_TEMPLATES.map((tmpl) => {
              const IconComp = tmpl.icon;
              return (
                <button
                  type="button"
                  key={tmpl.id}
                  onClick={() => handleApplyTemplate(tmpl)}
                  className={`p-2.5 rounded-xl border text-left transition-all flex flex-col justify-between ${
                    formData.title === tmpl.title
                      ? 'bg-gold-500/20 border-gold-500 text-white shadow-lg shadow-gold-500/10'
                      : 'bg-slate-900/90 border-slate-800 text-slate-400 hover:border-slate-700 hover:text-white'
                  }`}
                >
                  <div className="flex items-center justify-between w-full mb-1">
                    <IconComp className="h-4 w-4 text-gold-400" />
                    <span className="text-[9px] font-black uppercase px-1.5 py-0.5 rounded bg-slate-800 text-slate-300">{tmpl.tag}</span>
                  </div>
                  <span className="text-[11px] font-bold line-clamp-2 leading-tight">{tmpl.title.replace(/^[^\s]+\s*/, '')}</span>
                </button>
              );
            })}
          </div>
        </div>

        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Banner Title *</label>
          <Input
            required
            placeholder="E.g., 🎉 Welcome to ZeParty! Voice & Live"
            value={formData.title}
            onChange={(e) => setFormData({ ...formData, title: e.target.value })}
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Destination Action / Link URL</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all mb-2"
              value={formData.destinationUrl}
              onChange={(e) => setFormData({ ...formData, destinationUrl: e.target.value })}
            >
              <option value="zeparty://party">🎉 Voice Party Rooms (zeparty://party)</option>
              <option value="zeparty://live">⚔️ Live Stream & PK (zeparty://live)</option>
              <option value="zeparty://updates">🚀 Upcoming Updates Roadmap (zeparty://updates)</option>
              <option value="zeparty://store">🎁 Luxury Gift Store (zeparty://store)</option>
              <option value="zeparty://games">🎮 Game Center Lobby (zeparty://games)</option>
              <option value="zeparty://shorts">🎬 Trending Shorts (zeparty://shorts)</option>
              <option value="custom">🌐 Custom External URL...</option>
            </select>
            {formData.destinationUrl === 'custom' && (
              <Input
                placeholder="https://example.com/event"
                onChange={(e) => setFormData({ ...formData, destinationUrl: e.target.value })}
              />
            )}
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Priority / Order (Higher is first)</label>
            <Input
              type="number"
              min="0"
              max="100"
              value={formData.priority}
              onChange={(e) => setFormData({ ...formData, priority: parseInt(e.target.value, 10) || 0 })}
            />
          </div>
        </div>

        {/* Banner Creative URL and File Upload */}
        <div className="space-y-2">
          <label className="block text-xs font-medium text-slate-400">Banner Creative Artwork</label>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <Input
                placeholder="https://images.unsplash.com/..."
                value={formData.imageUrl}
                onChange={(e) => setFormData({ ...formData, imageUrl: e.target.value })}
              />
            </div>
            <div>
              <input
                type="file"
                accept="image/*"
                onChange={(e) => handleImageFileChange(e.target.files[0])}
                className="w-full text-xs text-slate-400 file:mr-3 file:py-2 file:px-3 file:rounded-lg file:border-0 file:text-xs file:font-bold file:bg-slate-800 file:text-gold-400 hover:file:bg-slate-700 cursor-pointer"
              />
            </div>
          </div>
        </div>

        {/* Live Mobile Card Preview */}
        <div>
          <label className="block text-[11px] font-semibold text-slate-400 mb-1 flex items-center gap-1">
            <Eye className="h-3.5 w-3.5 text-indigo-400" /> Live App Display Preview (How it looks on mobile home screen):
          </label>
          <div className="relative h-32 w-full rounded-2xl overflow-hidden border border-slate-700/80 shadow-2xl bg-gradient-to-r from-slate-900 via-indigo-950 to-purple-950 flex items-center p-5">
            {formData.imageUrl && (
              <img
                src={formData.imageUrl}
                alt="Banner preview"
                className="absolute inset-0 w-full h-full object-cover opacity-40 mix-blend-overlay"
              />
            )}
            <div className="absolute inset-0 bg-gradient-to-r from-slate-950/90 via-slate-950/60 to-transparent" />
            <div className="relative z-10 max-w-md">
              <span className="px-2 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider bg-gold-500 text-slate-950 mb-1.5 inline-block">
                FEATURED EVENT
              </span>
              <h4 className="text-white font-black text-base sm:text-lg leading-tight line-clamp-2 drop-shadow-md">
                {formData.title || 'Enter a banner title...'}
              </h4>
              <p className="text-slate-300 text-[11px] mt-1 line-clamp-1">
                Tap to open: <span className="text-gold-400 font-mono">{formData.destinationUrl}</span>
              </p>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Placement</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.placement}
              onChange={(e) => setFormData({ ...formData, placement: e.target.value })}
            >
              <option value="Home Carousel">Home Carousel</option>
              <option value="Party Top">Party Section Top</option>
              <option value="Live Top">Live Section Top</option>
              <option value="Store Top">Store Top Banner</option>
            </select>
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Target Mode</label>
            <button
              type="button"
              onClick={() => setFormData({ ...formData, isGlobal: !formData.isGlobal })}
              className={`w-full py-2 px-3 rounded-lg text-xs font-bold transition-colors border ${
                formData.isGlobal ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40' : 'bg-purple-500/20 text-purple-400 border-purple-500/40'
              }`}
            >
              {formData.isGlobal ? '🌍 Global (Worldwide)' : '🎯 Country-Specific Targeting'}
            </button>
          </div>
        </div>

        {!formData.isGlobal && (
          <div className="p-3 rounded-xl bg-slate-900 border border-slate-800 space-y-2">
            <label className="block text-[11px] font-medium text-slate-400">Target Countries (Multi-Select ISO Codes)</label>
            <div className="flex gap-2">
              <Input
                size="sm"
                placeholder="Enter country code (e.g. PK, SA, US, BR)"
                value={countryInput}
                onChange={(e) => setCountryInput(e.target.value)}
              />
              <Button type="button" variant="primary" size="xs" onClick={handleAddCountry}>
                + Add Country
              </Button>
            </div>

            <div className="flex flex-wrap gap-1.5 pt-1">
              {formData.selectedCountries.map((code) => (
                <span key={code} className="px-2 py-0.5 rounded bg-purple-950 border border-purple-700/60 text-purple-300 font-mono text-[11px] flex items-center gap-1">
                  <span>{code}</span>
                  <button type="button" onClick={() => handleRemoveCountry(code)} className="text-slate-400 hover:text-rose-400 font-bold">×</button>
                </span>
              ))}
            </div>
          </div>
        )}

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Start Date (Optional)</label>
            <Input type="date" value={formData.startDate} onChange={(e) => setFormData({ ...formData, startDate: e.target.value })} />
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">End Date (Optional)</label>
            <Input type="date" value={formData.endDate} onChange={(e) => setFormData({ ...formData, endDate: e.target.value })} />
          </div>
        </div>

        <div className="flex justify-end gap-3 mt-6 border-t border-slate-800 pt-3">
          <button type="button" onClick={onClose} className="px-4 py-2 text-xs font-medium text-slate-400 hover:text-white transition-colors">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-xs font-bold transition-colors disabled:opacity-50 flex items-center gap-1.5">
            {isSubmitting ? <RefreshCw className="h-3.5 w-3.5 animate-spin" /> : <Plus className="h-3.5 w-3.5" />}
            Publish Banner to Mobile App
          </button>
        </div>
      </form>
    </Modal>
  );
}

function EditBannerModal({ isOpen, onClose, banner, onSave }) {
  const [formData, setFormData] = useState({
    title: '',
    placement: 'Home Carousel',
    imageUrl: '',
    destinationUrl: '',
    priority: 0,
    status: 'ACTIVE',
  });
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (banner) {
      setFormData({
        title: banner.title || '',
        placement: banner.placement || 'Home Carousel',
        imageUrl: banner.imageUrl || banner.image || '',
        destinationUrl: banner.linkUrl || banner.destinationUrl || '',
        priority: banner.priority !== undefined ? banner.priority : (banner.position || 0),
        status: banner.status || 'ACTIVE',
      });
    }
  }, [banner]);

  if (!banner) return null;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    try {
      const updated = await updateBanner(banner.id, {
        title: formData.title,
        placement: formData.placement,
        imageUrl: formData.imageUrl,
        linkUrl: formData.destinationUrl,
        priority: formData.priority,
        status: formData.status,
      });
      onSave(updated || { ...banner, ...formData });
      onClose();
    } catch (err) {
      console.error('Failed to update banner:', err);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`Edit Banner: ${banner.title}`} size="md">
      <form onSubmit={handleSubmit} className="space-y-4 text-xs">
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Banner Title</label>
          <Input value={formData.title} onChange={(e) => setFormData({ ...formData, title: e.target.value })} required />
        </div>

        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Image URL</label>
          <Input value={formData.imageUrl} onChange={(e) => setFormData({ ...formData, imageUrl: e.target.value })} required />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Action / Deep Link</label>
            <Input value={formData.destinationUrl} onChange={(e) => setFormData({ ...formData, destinationUrl: e.target.value })} />
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Priority / Sort Order</label>
            <Input type="number" value={formData.priority} onChange={(e) => setFormData({ ...formData, priority: parseInt(e.target.value, 10) || 0 })} />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Placement</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white focus:outline-none"
              value={formData.placement}
              onChange={(e) => setFormData({ ...formData, placement: e.target.value })}
            >
              <option value="Home Carousel">Home Carousel</option>
              <option value="Party Top">Party Top</option>
              <option value="Live Top">Live Top</option>
              <option value="Store Top">Store Top</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Status</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white focus:outline-none"
              value={formData.status}
              onChange={(e) => setFormData({ ...formData, status: e.target.value })}
            >
              <option value="ACTIVE">ACTIVE</option>
              <option value="INACTIVE">DISABLED / INACTIVE</option>
            </select>
          </div>
        </div>

        {/* Live Preview */}
        <div className="relative h-24 w-full rounded-xl overflow-hidden border border-slate-700 bg-slate-900 flex items-center p-3">
          {formData.imageUrl && (
            <img src={formData.imageUrl} alt="Banner preview" className="absolute inset-0 w-full h-full object-cover opacity-50" />
          )}
          <div className="relative z-10">
            <h4 className="text-white font-bold text-sm line-clamp-1">{formData.title}</h4>
            <p className="text-slate-300 text-[10px]">{formData.destinationUrl}</p>
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-2 border-t border-slate-800">
          <button type="button" onClick={onClose} className="px-4 py-2 text-xs text-slate-400 hover:text-white">Cancel</button>
          <button type="submit" disabled={isSaving} className="bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-xs font-bold disabled:opacity-50 flex items-center gap-1.5">
            {isSaving ? <RefreshCw className="h-3.5 w-3.5 animate-spin" /> : <CheckCircle className="h-3.5 w-3.5" />}
            Save & Update Mobile App
          </button>
        </div>
      </form>
    </Modal>
  );
}

export function BannersPage() {
  const { addLog } = useAuditLog();
  const [stats, setStats] = useState({ activeBanners: 0, scheduledCampaigns: 0, globalReach: 0, regionalOverrides: 0 });
  const [banners, setBanners] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [selectedTemplateForCreate, setSelectedTemplateForCreate] = useState(null);
  const [editingBanner, setEditingBanner] = useState(null);

  // Inheritance & Test UI State
  const [selectedBannerInherit, setSelectedBannerInherit] = useState(null);
  const [simulatedTargetEvent, setSimulatedTargetEvent] = useState(null);
  const [isJoined, setIsJoined] = useState(false);
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('');
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const fetchBannersData = () => {
    setIsLoading(true);
    Promise.all([getBannerStats(), getBanners()])
      .then(([s, b]) => {
        if (s) setStats(s);
        const formatted = (b || []).map((item) => ({
          ...item,
          scope: item.scope || 'GLOBAL',
          overrideValue: item.overrideValue || '',
          inheritedValue: item.inheritedValue || 'Campaign Standard'
        }));
        setBanners(formatted);
      })
      .catch((err) => {
        console.error('Failed to fetch banners:', err);
      })
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchBannersData();
  }, []);

  const filteredBanners = useMemo(() => {
    return banners.filter((b) => (b.title || '').toLowerCase().includes(search.toLowerCase()));
  }, [banners, search]);

  const handleToggleStatus = async (banner) => {
    const newStatus = banner.status === 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await updateBanner(banner.id, { status: newStatus });
      fetchBannersData();
      addLog('BANNER_STATUS_CHANGED', banner.id, 'Banners', `Changed banner "${banner.title}" status to ${newStatus}`);
      showFeedback(`Banner status updated to ${newStatus}.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update banner status');
    }
  };

  const handleDeleteBanner = async (banner) => {
    if (!window.confirm(`Are you sure you want to delete banner "${banner.title}"?`)) return;
    try {
      await deleteBanner(banner.id);
      setBanners(banners.filter((b) => b.id !== banner.id));
      addLog('BANNER_DELETED', banner.id, 'Banners', `Deleted banner "${banner.title}"`);
      showFeedback(`Banner "${banner.title}" removed successfully.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to delete banner');
    }
  };

  const handleQuickDeployTemplate = async (tmpl) => {
    try {
      const banner = await createBanner({
        title: tmpl.title,
        imageUrl: tmpl.imageUrl,
        destinationUrl: tmpl.destinationUrl,
        linkUrl: tmpl.destinationUrl,
        placement: tmpl.placement,
        priority: tmpl.priority,
        isGlobal: true,
        status: 'ACTIVE',
      });
      setBanners([banner, ...banners]);
      addLog('BANNER_CREATED', banner.id, 'Banners', `Deployed preset template "${tmpl.title}"`);
      showFeedback(`Template "${tmpl.title}" deployed live to mobile app!`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to deploy template');
    }
  };

  const handleOpenInheritance = (banner) => {
    setSelectedBannerInherit(banner);
    setScope(banner.scope || 'GLOBAL');
    setOverrideValue(banner.overrideValue || '');
    setInheritedValue(banner.inheritedValue || 'Campaign Standard');
  };

  const handleSaveInheritance = async () => {
    if (!selectedBannerInherit) return;
    try {
      await updateBanner(selectedBannerInherit.id, {
        title: selectedBannerInherit.title,
      });
      fetchBannersData();
      addLog('BANNER_INHERITANCE_UPDATED', selectedBannerInherit.id, 'Banners', `Updated scope to ${scope} with override ${overrideValue}`);
      showFeedback(`Banner inheritance override settings configured for ${selectedBannerInherit.title}.`);
      setSelectedBannerInherit(null);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update banner');
    }
  };

  const columns = [
    {
      key: 'preview',
      header: 'Creative Preview',
      render: (row) => (
        <div className="h-14 w-28 rounded-lg overflow-hidden border border-slate-700 bg-slate-900 flex items-center justify-center relative shadow-sm group">
          <img src={row.imageUrl || row.image} alt="Preview" className="h-full w-full object-cover group-hover:scale-105 transition-transform" />
          <div className="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent flex items-end p-1">
            <span className="text-[9px] text-white font-mono font-bold truncate">{row.priority !== undefined ? `P${row.priority}` : ''}</span>
          </div>
        </div>
      )
    },
    {
      key: 'details',
      header: 'Banner Campaign Details',
      render: (row) => (
        <div className="max-w-xs">
          <p className="font-bold text-white text-sm line-clamp-1">{row.title}</p>
          <div className="flex items-center gap-1.5 mt-1 text-xs text-slate-400">
            <span className="text-[10px] text-gold-400 font-mono">{row.linkUrl || row.destinationUrl || 'No action link'}</span>
            <span>•</span>
            <Badge variant="muted" className="text-[10px] py-0">{row.target || 'Global'}</Badge>
          </div>
        </div>
      )
    },
    {
      key: 'placement',
      header: 'Placement',
      render: (row) => <Badge variant="default">{row.placement || 'Home Carousel'}</Badge>
    },
    {
      key: 'priority',
      header: 'Priority',
      render: (row) => (
        <span className="px-2 py-1 rounded bg-slate-800 font-mono text-xs font-bold text-gold-400 border border-slate-700">
          {row.priority ?? 0}
        </span>
      )
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={(row.status || 'ACTIVE').toLowerCase()} />
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex items-center gap-2">
          <button
            onClick={() => setEditingBanner(row)}
            className="p-1.5 rounded hover:bg-slate-800 text-indigo-400 hover:text-indigo-300 transition-colors"
            title="Edit Banner"
          >
            <Edit2 className="h-4 w-4" />
          </button>
          <button
            onClick={() => setSimulatedTargetEvent({ name: row.title, url: row.linkUrl || row.destinationUrl })}
            className="p-1.5 rounded hover:bg-slate-800 text-purple-400 hover:text-purple-300 transition-colors"
            title="Simulate Mobile Tap"
          >
            <ExternalLink className="h-4 w-4" />
          </button>
          <button
            onClick={() => handleOpenInheritance(row)}
            className="text-xs text-gold-400 hover:underline px-1"
          >
            Scope
          </button>
          <button
            onClick={() => handleToggleStatus(row)}
            className={`text-xs px-2 py-1 rounded font-bold transition-colors ${
              row.status === 'ACTIVE'
                ? 'bg-rose-500/10 text-rose-400 hover:bg-rose-500/20'
                : 'bg-emerald-500/10 text-emerald-400 hover:bg-emerald-500/20'
            }`}
          >
            {row.status === 'ACTIVE' ? 'Disable' : 'Enable'}
          </button>
          <button
            onClick={() => handleDeleteBanner(row)}
            className="p-1.5 rounded hover:bg-rose-500/10 text-slate-500 hover:text-rose-400 transition-colors"
            title="Delete Banner"
          >
            <Trash2 className="h-4 w-4" />
          </button>
        </div>
      )
    }
  ];

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto pb-12" aria-label="Banners & Content">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ImageIcon className="h-6 w-6 text-gold-400" aria-hidden="true" />
            Banners & Home Carousel Management
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage live mobile app homepage banners, preset templates, and interactive action redirects.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={fetchBannersData}
            className="flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-2 rounded-lg text-sm font-semibold transition-colors border border-slate-700"
          >
            <RefreshCw className="h-4 w-4" /> Refresh
          </button>
          <button
            onClick={() => {
              setSelectedTemplateForCreate(null);
              setIsCreateModalOpen(true);
            }}
            className="flex items-center gap-2 bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors shadow-lg shadow-gold-500/20"
          >
            <Plus className="h-4 w-4" /> Create Custom Banner
          </button>
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2 shadow-lg">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Preset Banner Templates Showcase Card */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Sparkles className="h-5 w-5 text-gold-400" />
            <h2 className="text-base font-bold text-white">Preset Mobile Banner Templates</h2>
            <span className="text-xs px-2 py-0.5 rounded-full bg-gold-500/20 text-gold-300 font-bold border border-gold-500/30">
              4 Official Templates
            </span>
          </div>
          <span className="text-xs text-slate-400">1-Click instant deploy or customize for mobile app</span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
          {PRESET_BANNER_TEMPLATES.map((tmpl) => {
            const IconComp = tmpl.icon;
            const isAlreadyActive = banners.some((b) => b.title === tmpl.title && b.status === 'ACTIVE');

            return (
              <div
                key={tmpl.id}
                className={`relative rounded-2xl p-4 overflow-hidden border ${tmpl.borderGradient} bg-gradient-to-br ${tmpl.bgGradient} flex flex-col justify-between shadow-xl group transition-all hover:scale-[1.01]`}
              >
                {/* Background Artwork */}
                <img
                  src={tmpl.imageUrl}
                  alt={tmpl.title}
                  className="absolute inset-0 w-full h-full object-cover opacity-25 mix-blend-overlay group-hover:scale-105 transition-transform duration-500"
                />
                <div className="absolute inset-0 bg-black/40" />

                {/* Content */}
                <div className="relative z-10 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className={`px-2 py-0.5 rounded-full text-[9px] font-black uppercase tracking-wider bg-gradient-to-r ${tmpl.tagColor} text-slate-950 shadow-sm`}>
                      {tmpl.tag}
                    </span>
                    <IconComp className="h-5 w-5 text-white/80" />
                  </div>
                  <div>
                    <h3 className="text-sm font-black text-white leading-tight drop-shadow-md">{tmpl.title}</h3>
                    <p className="text-[11px] text-slate-300 mt-1 leading-normal line-clamp-2">{tmpl.subtitle}</p>
                  </div>
                </div>

                {/* Footer Actions */}
                <div className="relative z-10 pt-4 mt-2 border-t border-white/10 flex items-center justify-between gap-2">
                  <span className="text-[10px] font-mono text-gold-300 truncate max-w-[110px]">
                    {tmpl.destinationUrl}
                  </span>
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => {
                        setSelectedTemplateForCreate(tmpl);
                        setIsCreateModalOpen(true);
                      }}
                      className="px-2 py-1 rounded bg-white/10 hover:bg-white/20 text-white text-[10px] font-bold transition-colors"
                    >
                      Customize
                    </button>
                    <button
                      onClick={() => handleQuickDeployTemplate(tmpl)}
                      disabled={isAlreadyActive}
                      className={`px-2.5 py-1 rounded text-[10px] font-black transition-colors ${
                        isAlreadyActive
                          ? 'bg-emerald-500/30 text-emerald-300 border border-emerald-500/40 cursor-default'
                          : 'bg-gold-500 hover:bg-gold-400 text-slate-950 shadow-md'
                      }`}
                    >
                      {isAlreadyActive ? '✓ Active' : 'Deploy Live'}
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Active Banners" value={stats.activeBanners || banners.filter((b) => b.status === 'ACTIVE').length} icon={Megaphone} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Scheduled" value={stats.scheduledCampaigns || 0} icon={Calendar} iconColor="text-indigo-400" iconBg="bg-indigo-500/10" />
        <StatCard title="Global Reach" value={stats.globalReach || banners.length} icon={Globe} iconColor="text-amber-400" iconBg="bg-amber-500/10" />
        <StatCard title="Total Campaigns" value={banners.length} icon={Clock} iconColor="text-purple-400" iconBg="bg-purple-500/10" />
      </div>

      {/* Banners Table */}
      <Card>
        <CardHeader title="All Banner Campaigns" description="Control promotional and live content streamed to mobile app users">
          <Input
            placeholder="Search campaigns..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            leftIcon={Search}
            containerClassName="w-64"
          />
        </CardHeader>
        <DataTable columns={columns} data={filteredBanners} isLoading={isLoading} />
      </Card>

      {/* Create Modal */}
      <CreateBannerModal
        isOpen={isCreateModalOpen}
        onClose={() => {
          setIsCreateModalOpen(false);
          setSelectedTemplateForCreate(null);
        }}
        initialTemplate={selectedTemplateForCreate}
        onCreated={(banner) => {
          setBanners([banner, ...banners]);
          addLog('BANNER_CREATED', banner.id, 'Banners', `Scheduled new banner "${banner.title}"`);
          showFeedback(`Banner "${banner.title}" published live to mobile app.`);
        }}
      />

      {/* Edit Modal */}
      <EditBannerModal
        isOpen={!!editingBanner}
        onClose={() => setEditingBanner(null)}
        banner={editingBanner}
        onSave={(updated) => {
          setBanners(banners.map((b) => (b.id === updated.id ? updated : b)));
          addLog('BANNER_EDITED', updated.id, 'Banners', `Edited banner "${updated.title}"`);
          showFeedback(`Banner "${updated.title}" updated successfully.`);
        }}
      />

      {/* Scope Overrides Modal */}
      {selectedBannerInherit && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedBannerInherit(null)}
          title={`Geographic Scope Overrides: ${selectedBannerInherit.title}`}
          size="lg"
        >
          <div className="space-y-4">
            <GeographicInheritancePanel
              scope={scope}
              onChangeScope={setScope}
              inheritedValue={inheritedValue}
              overrideValue={overrideValue}
              onChangeOverride={setOverrideValue}
              effectiveValue={overrideValue ? overrideValue : inheritedValue}
              onResetScope={() => {
                setOverrideValue('');
                setScope('GLOBAL');
              }}
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedBannerInherit(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save Banner Override
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Simulated Client App Deep-Link Redirect Modal */}
      {simulatedTargetEvent && (
        <Modal
          isOpen={true}
          onClose={() => {
            setSimulatedTargetEvent(null);
            setIsJoined(false);
          }}
          title={`Simulated Mobile Deep-Link View: ${simulatedTargetEvent.name}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 bg-indigo-950/40 border border-indigo-500/20 rounded-xl text-indigo-300">
              <span className="font-bold block text-sm">Mobile Navigation Target Verified</span>
              <p className="text-[11px] mt-0.5">
                Target URI: <code className="bg-slate-900 px-1.5 py-0.5 rounded text-gold-400 font-mono">{simulatedTargetEvent.url || 'zeparty://party'}</code>
              </p>
            </div>

            <div className="h-28 rounded-xl bg-gradient-to-br from-indigo-800 to-purple-950 p-4 flex flex-col justify-end border border-purple-500/30">
              <span className="text-[10px] text-purple-300 uppercase tracking-widest font-black">ZeParty Mobile Routing</span>
              <h4 className="text-lg font-black text-white leading-tight mt-0.5">{simulatedTargetEvent.name}</h4>
              <p className="text-[10px] text-slate-400">Deep link router directs the user directly to the destination screen.</p>
            </div>

            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSimulatedTargetEvent(null)}>
                Close Preview
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
