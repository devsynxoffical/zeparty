// ============================================================
// ZeParty Admin Portal — Banners & Home Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { Image as ImageIcon, Search, Plus, Calendar, Megaphone, Clock, AlertCircle, Globe, CheckCircle } from 'lucide-react';
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
  updateBanner
} from '../../services/modules/banners.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { Button } from '../../components/ui/Button';

function CreateBannerModal({ isOpen, onClose, onCreated }) {
  const [formData, setFormData] = useState({ title: '', placement: 'Home Carousel', target: 'Global', startDate: '', endDate: '' });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const banner = await createBanner({
        ...formData,
        image: 'https://placehold.co/800x400/D4AF37/000000?text=New+Banner',
        status: 'SCHEDULED'
      });
      onCreated(banner);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create New Banner" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Banner Title</label>
          <Input required placeholder="E.g., Eid Celebration Campaign" value={formData.title} onChange={(e) => setFormData({...formData, title: e.target.value})} />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Placement</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.placement}
              onChange={(e) => setFormData({...formData, placement: e.target.value})}
            >
              <option value="Home Carousel">Home Carousel</option>
              <option value="Discover Page">Discover Page</option>
              <option value="Events Page">Events Page</option>
              <option value="Store Page">Store Page</option>
              <option value="Wallet Page">Wallet Page</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Target Audience</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.target}
              onChange={(e) => setFormData({...formData, target: e.target.value})}
            >
              <option value="Global">Global</option>
              <option value="MENA">MENA Region</option>
              <option value="Asia">Asia</option>
              <option value="Europe">Europe</option>
            </select>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Start Date</label>
            <Input required type="date" value={formData.startDate} onChange={(e) => setFormData({...formData, startDate: e.target.value})} />
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">End Date</label>
            <Input required type="date" value={formData.endDate} onChange={(e) => setFormData({...formData, endDate: e.target.value})} />
          </div>
        </div>
        <div className="flex justify-end gap-3 mt-6">
          <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50">
            Schedule Banner
          </button>
        </div>
      </form>
    </Modal>
  );
}

function EditBannerModal({ isOpen, onClose, banner, onSave }) {
  const [title, setTitle] = useState(banner?.title || '');
  const [placement, setPlacement] = useState(banner?.placement || 'Home Carousel');

  useEffect(() => {
    if (banner) {
      setTitle(banner.title);
      setPlacement(banner.placement);
    }
  }, [banner]);

  if (!banner) return null;

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave({ ...banner, title, placement });
    onClose();
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={`Edit Banner: ${banner.id}`}>
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input label="Banner Title" value={title} onChange={(e) => setTitle(e.target.value)} required />
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Placement</label>
          <select
            className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:outline-none"
            value={placement}
            onChange={(e) => setPlacement(e.target.value)}
          >
            <option value="Home Carousel">Home Carousel</option>
            <option value="Discover Page">Discover Page</option>
            <option value="Events Page">Events Page</option>
          </select>
        </div>
        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={onClose} className="px-4 py-2 text-sm text-slate-400">Cancel</button>
          <button type="submit" className="bg-gold-500 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold">Save Changes</button>
        </div>
      </form>
    </Modal>
  );
}

export function BannersPage() {
  const { addLog } = useAuditLog();
  const [stats, setStats] = useState(null);
  const [banners, setBanners] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingBanner, setEditingBanner] = useState(null);

  // Inheritance UI State
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

  useEffect(() => {
    Promise.all([getBannerStats(), getBanners()])
      .then(([s, b]) => {
        setStats(s);
        const formatted = b.map(item => ({
          ...item,
          scope: item.scope || 'GLOBAL',
          overrideValue: item.overrideValue || '',
          inheritedValue: item.inheritedValue || 'Campaign Standard'
        }));
        setBanners(formatted);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const filteredBanners = useMemo(() => {
    return banners.filter(b => b.title.toLowerCase().includes(search.toLowerCase()));
  }, [banners, search]);

  const handleToggleStatus = async (banner) => {
    const newStatus = banner.status === 'ACTIVE' ? 'DISABLED' : (banner.status === 'DISABLED' || banner.status === 'DRAFT') ? 'ACTIVE' : banner.status;
    const updated = await updateBanner(banner.id, { status: newStatus });
    setBanners(banners.map(b => b.id === banner.id ? { ...b, status: newStatus } : b));
    addLog('BANNER_STATUS_CHANGED', banner.id, 'Banners', `Changed banner "${banner.title}" status to ${newStatus}`);
  };

  const handleOpenInheritance = (banner) => {
    setSelectedBannerInherit(banner);
    setScope(banner.scope || 'GLOBAL');
    setOverrideValue(banner.overrideValue || '');
    setInheritedValue(banner.inheritedValue || 'Campaign Standard');
  };

  const handleSaveInheritance = async () => {
    if (!selectedBannerInherit) return;

    setBanners(banners.map(b => {
      if (b.id === selectedBannerInherit.id) {
        return {
          ...b,
          scope,
          overrideValue
        };
      }
      return b;
    }));

    addLog('BANNER_INHERITANCE_UPDATED', selectedBannerInherit.id, 'Banners', `Updated scope to ${scope} with override ${overrideValue}`);
    showFeedback(`Banner inheritance override settings configured for ${selectedBannerInherit.title}.`);
    setSelectedBannerInherit(null);
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
    }
    showFeedback('Reset scope configuration.');
  };

  const columns = [
    { key: 'preview', header: 'Preview', render: (row) => (
      <div className="h-12 w-24 rounded overflow-hidden border border-slate-700 bg-slate-900 flex items-center justify-center">
        <img src={row.image} alt="Preview" className="h-full w-full object-cover" />
      </div>
    )},
    { key: 'details', header: 'Banner Details', render: (row) => (
      <div>
        <p className="font-bold text-white text-sm">{row.title}</p>
        <div className="flex items-center gap-1.5 mt-0.5 text-xs text-slate-400">
          <span>{row.id}</span>
          <span>•</span>
          <span className="flex items-center gap-1"><Badge variant="muted" className="text-[10px] py-0">{row.target}</Badge></span>
          <Badge variant="purple" className="text-[9px] font-mono"><Globe className="h-2.5 w-2.5 mr-0.5 inline" /> {row.scope}</Badge>
        </div>
      </div>
    )},
    { key: 'placement', header: 'Placement', render: (row) => <Badge variant="default">{row.placement}</Badge> },
    { key: 'dates', header: 'Schedule', render: (row) => (
      <div className="text-xs text-slate-300">
        <p>{row.startDate} to</p>
        <p>{row.endDate}</p>
      </div>
    )},
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-2">
        <button onClick={() => setEditingBanner(row)} className="text-xs text-indigo-400 hover:underline">Edit</button>
        <button onClick={() => setSimulatedTargetEvent({ name: row.title })} className="text-xs text-purple-400 hover:underline font-bold">Test Target Link</button>
        <button onClick={() => handleOpenInheritance(row)} className="text-xs text-gold-400 hover:underline">Scope</button>
        {row.status !== 'EXPIRED' && (
          <button
            onClick={() => handleToggleStatus(row)}
            className={`text-xs hover:underline ${row.status === 'ACTIVE' || row.status === 'SCHEDULED' ? 'text-red-400' : 'text-emerald-400'}`}
          >
            {row.status === 'ACTIVE' || row.status === 'SCHEDULED' ? 'Disable' : 'Activate'}
          </button>
        )}
      </div>
    )}
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading Banners...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Banners & Content">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ImageIcon className="h-6 w-6 text-gold-400" aria-hidden="true" />
            Banners & App Content
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage promotional banners, announcements, and featured app content with country overrides.</p>
        </div>
        <button
          onClick={() => setIsCreateModalOpen(true)}
          className="flex items-center gap-2 bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors"
        >
          <Plus className="h-4 w-4" /> Create Banner
        </button>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Active Banners" value={stats.activeBanners} icon={Megaphone} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Scheduled" value={stats.scheduledBanners} icon={Calendar} iconColor="text-indigo-400" iconBg="bg-indigo-500/10" />
        <StatCard title="Drafts" value={stats.drafts} icon={ImageIcon} iconColor="text-amber-400" iconBg="bg-amber-500/10" />
        <StatCard title="Expired" value={stats.expired} icon={Clock} iconColor="text-slate-400" iconBg="bg-slate-700" />
      </div>

      <Card>
        <CardHeader title="Banner Management" description="Control promotional content across the ZeParty platform">
          <Input
            placeholder="Search banners..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            leftIcon={Search}
            containerClassName="w-64"
          />
        </CardHeader>
        <DataTable columns={columns} data={filteredBanners} isLoading={false} />
      </Card>

      <CreateBannerModal
        isOpen={isCreateModalOpen}
        onClose={() => setIsCreateModalOpen(false)}
        onCreated={(banner) => {
          setBanners([banner, ...banners]);
          addLog('BANNER_CREATED', banner.id, 'Banners', `Scheduled new banner "${banner.title}"`);
        }}
      />

      <EditBannerModal
        isOpen={!!editingBanner}
        onClose={() => setEditingBanner(null)}
        banner={editingBanner}
        onSave={(updated) => {
          setBanners(banners.map(b => b.id === updated.id ? updated : b));
          addLog('BANNER_EDITED', updated.id, 'Banners', `Edited banner "${updated.title}"`);
        }}
      />

      {/* Scope Overrides Modal */}
      {selectedBannerInherit && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedBannerInherit(null)}
          title={`Banner Geographic Scope overrides: ${selectedBannerInherit.title}`}
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
              onResetScope={handleResetScope}
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedBannerInherit(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save banner override
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Simulated Client App Click-Through Redirect Modal */}
      {simulatedTargetEvent && (
        <Modal
          isOpen={true}
          onClose={() => { setSimulatedTargetEvent(null); setIsJoined(false); }}
          title={`Simulated Client Event View: ${simulatedTargetEvent.name}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3 bg-indigo-950/40 border border-indigo-500/20 rounded-xl text-indigo-300">
              <span className="font-bold block">App Redirect Verification Success</span>
              <p className="text-[10px]">Admins can test how the mobile app processes this clickable banner redirect target.</p>
            </div>

            {/* Banner details target card */}
            <div className="h-32 rounded-xl bg-gradient-to-br from-indigo-800 to-purple-950 p-4 flex flex-col justify-end border border-purple-500/30">
              <span className="text-[10px] text-purple-300 uppercase tracking-widest font-black">ZeParty App Event Banner Click</span>
              <h4 className="text-lg font-black text-white leading-tight mt-0.5">{simulatedTargetEvent.name}</h4>
              <p className="text-[10px] text-slate-400">Interactive live streaming event configuration details & rules.</p>
            </div>

            <div className="space-y-3 bg-slate-900 p-4 border border-slate-800 rounded-xl">
              <div>
                <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[11px] text-yellow-400">1. Event Info & Details</h5>
                <p className="text-slate-300 leading-relaxed">This event is active on the homepage carousel. Engage with users, receive virtual items, and accumulate points to climb the real-time leaderboard.</p>
              </div>

              <div className="grid grid-cols-2 gap-4 border-t border-slate-700 pt-3">
                <div>
                  <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[10px] text-purple-400">2. Requirements Details</h5>
                  <p className="text-slate-400">Must stream in PK battles or entertainment categories. Requires minimum level L3 host status to register.</p>
                </div>
                <div>
                  <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[10px] text-purple-400">3. Eligibility Criteria</h5>
                  <p className="text-slate-400">Direct register and official agency hosts matching country code scopes are eligible for rewards.</p>
                </div>
              </div>

              <div className="border-t border-slate-700 pt-3">
                <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[11px] text-rose-400">4. Terms and Conditions</h5>
                <p className="text-slate-400">All rewards are finalized after 15 days SLA holding audits. Accounts engaging in system abuse or coordinates trading are subject to disqualification.</p>
              </div>
            </div>

            {/* Participation Simulator */}
            <div className="p-3 bg-slate-950 border border-slate-900 rounded-xl flex items-center justify-between">
              <div>
                <p className="font-bold text-slate-200">Simulate Host Sign-Up Option</p>
                <p className="text-[10px] text-slate-500">Admins can test host registration options.</p>
              </div>
              <Button
                variant={isJoined ? 'success' : 'primary'}
                size="sm"
                onClick={() => {
                  setIsJoined(!isJoined);
                  showFeedback(isJoined ? "Unsubscribed from event." : "Successfully signed up! Active participation simulated.");
                }}
              >
                {isJoined ? 'Signed Up (Leave Event)' : 'Participate / Join Event'}
              </Button>
            </div>

            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => { setSimulatedTargetEvent(null); setIsJoined(false); }}>
                Close Previews
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
