// ============================================================
// ZeParty Admin Portal — Asset Management Hub (JSX)
// Universal Reusable Asset Framework + Interactive Live Previews
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import {
  Sparkles,
  Search,
  Plus,
  Trash2,
  Calendar,
  Layers,
  Image as ImageIcon,
  HelpCircle,
  Clock,
  User,
  Radio,
  Video,
  Volume2,
  ArrowRightLeft,
  Coins,
  History,
  CheckCircle,
  AlertTriangle,
  Play,
  RotateCcw,
  Copy
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Select } from '../../components/ui/Select';
import { usePermission } from '../../hooks/usePermission';
import { useAuditLog } from '../../context/AuditLogContext';
import { formatNumber, formatDate } from '../../utils/format';
import {
  getAssets,
  addAsset,
  updateAsset,
  deleteAsset,
  replaceAssetFile
} from '../../services/modules/assets.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { Globe } from 'lucide-react';

const CATEGORIES = [
  { id: 'ALL', label: 'All Assets' },
  { id: 'GIFTS', label: 'Gifts' },
  { id: 'VIP_SVIP_FRAMES', label: 'VIP/SVIP Frames' },
  { id: 'TAGS', label: 'Tags' },
  { id: 'BADGES', label: 'Badges' },
  { id: 'PROFILE_FRAMES', label: 'Profile Frames' },
  { id: 'CHAT_BUBBLES', label: 'Chat Bubbles' },
  { id: 'BAGS', label: 'Bags' },
  { id: 'ENTRY_EFFECTS', label: 'Entry Effects' },
  { id: 'ANIMATIONS', label: 'Animations' },
  { id: 'SOUND_EFFECTS', label: 'Sound Effects' },
  { id: 'VIDEO_ASSETS', label: 'Video Assets' }
];

const ROLES_LIST = [
  'All',
  'Super Admin',
  'Manager',
  'CS',
  'Agency',
  'Merchant',
  'Coin Seller',
  'Host',
  'Official',
  'VIP',
  'SVIP 1-12',
  'Noble',
  'Mystery'
];

export function AssetsPage() {
  const { canPerformAction } = usePermission();
  const { logAdminAction } = useAuditLog();

  const [assets, setAssets] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeCategory, setActiveCategory] = useState('ALL');
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [feedback, setFeedback] = useState(null);
  
  // Modals state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [isEditModalOpen, setIsEditModalOpen] = useState(false);
  const [isReplaceModalOpen, setIsReplaceModalOpen] = useState(false);
  const [selectedAsset, setSelectedAsset] = useState(null);
  
  // History tab sub-state in details
  const [detailModalOpen, setDetailModalOpen] = useState(false);
  
  // Inheritance UI State
  const [selectedAssetInherit, setSelectedAssetInherit] = useState(null);
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('');
  
  // Form states
  const [formName, setFormName] = useState('');
  const [formId, setFormId] = useState('');
  const [formCategory, setFormCategory] = useState('GIFTS');
  const [formSubCategory, setFormSubCategory] = useState('Static');
  const [formPrice, setFormPrice] = useState(0);
  const [formStatus, setFormStatus] = useState('active');
  const [formRoomAvailability, setFormRoomAvailability] = useState('Both');
  const [formDuration, setFormDuration] = useState(0);
  const [formVolume, setFormVolume] = useState(80);
  const [formComboSupport, setFormComboSupport] = useState(false);
  const [formComboCount, setFormComboCount] = useState(1);
  const [formFullScreen, setFormFullScreen] = useState(false);
  const [formPriority, setFormPriority] = useState(1);
  const [formStartDate, setFormStartDate] = useState('');
  const [formEndDate, setFormEndDate] = useState('');
  const [formAssignment, setFormAssignment] = useState('All');
  const [formThumbnail, setFormThumbnail] = useState('https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=120&auto=format&fit=crop&q=60');
  
  // Upload Simulator State
  const [uploadFile, setUploadFile] = useState(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState('');
  const [replaceReason, setReplaceReason] = useState('');

  useEffect(() => {
    loadAssetsList();
  }, []);

  async function loadAssetsList() {
    setIsLoading(true);
    try {
      const data = await getAssets();
      setAssets(data);
    } catch (err) {
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  }

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleOpenAddModal = () => {
    setFormName('');
    setFormId(`ast-${Date.now().toString().slice(-6)}`);
    setFormCategory('GIFTS');
    setFormSubCategory('Static');
    setFormPrice(0);
    setFormStatus('active');
    setFormRoomAvailability('Both');
    setFormDuration(0);
    setFormVolume(80);
    setFormComboSupport(false);
    setFormComboCount(1);
    setFormFullScreen(false);
    setFormPriority(1);
    setFormStartDate('');
    setFormEndDate('');
    setFormAssignment('All');
    setFormThumbnail('https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=120&auto=format&fit=crop&q=60');
    setUploadError('');
    setIsAddModalOpen(true);
  };

  const handleOpenEditModal = (asset) => {
    setSelectedAsset(asset);
    setFormName(asset.name);
    setFormId(asset.id);
    setFormCategory(asset.category);
    setFormSubCategory(asset.subCategory);
    setFormPrice(asset.price);
    setFormStatus(asset.status);
    setFormRoomAvailability(asset.roomAvailability || 'Both');
    setFormDuration(asset.duration || 0);
    setFormVolume(asset.volume || 80);
    setFormComboSupport(asset.comboSupport || false);
    setFormComboCount(asset.comboCount || 1);
    setFormFullScreen(asset.fullScreen || false);
    setFormPriority(asset.priority || 1);
    setFormStartDate(asset.startDate || '');
    setFormEndDate(asset.endDate || '');
    setFormAssignment(asset.assignment || 'All');
    setFormThumbnail(asset.thumbnail);
    setUploadError('');
    setIsEditModalOpen(true);
  };

  // Simulates standard file upload validation
  const simulateFileUpload = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    // Validate size and format
    const validExtensions = ['png', 'webp', 'mp4', 'mp3', 'wav', 'gif'];
    const ext = file.name.split('.').pop().toLowerCase();
    if (!validExtensions.includes(ext)) {
      setUploadError(`Invalid Format: ${ext.toUpperCase()} is not supported. Use WebP/PNG/MP4/MP3.`);
      return;
    }

    if (file.size > 8 * 1024 * 1024) {
      setUploadError('Invalid Size: File must be smaller than 8MB.');
      return;
    }

    setUploadError('');
    setUploadFile(file);
    setIsUploading(true);
    setUploadProgress(0);

    const interval = setInterval(() => {
      setUploadProgress((prev) => {
        if (prev >= 100) {
          clearInterval(interval);
          setIsUploading(false);
          // Set mock asset thumbnail depending on type
          if (ext === 'mp4') {
            setFormThumbnail('https://images.unsplash.com/photo-1534447677768-be436bb09401?w=120&auto=format&fit=crop&q=60');
          } else {
            setFormThumbnail('https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=120&auto=format&fit=crop&q=60');
          }
          return 100;
        }
        return prev + 25;
      });
    }, 150);
  };

  const handleSaveNewAsset = async (e) => {
    e.preventDefault();
    if (isUploading) return;

    const payload = {
      id: formId,
      name: formName,
      category: formCategory,
      subCategory: formSubCategory,
      price: Number(formPrice),
      status: formStatus,
      roomAvailability: formRoomAvailability,
      thumbnail: formThumbnail,
      duration: Number(formDuration),
      volume: Number(formVolume),
      comboSupport: formComboSupport,
      comboCount: Number(formComboCount),
      fullScreen: formFullScreen,
      priority: Number(formPriority),
      startDate: formStartDate,
      endDate: formEndDate,
      assignment: formAssignment
    };

    const newAsset = await addAsset(payload, 'Super Admin');
    setAssets((prev) => [newAsset, ...prev]);

    await logAdminAction({
      action: 'ASSET_CREATED',
      module: 'Assets',
      targetType: 'asset',
      targetId: newAsset.id,
      targetName: newAsset.name,
      reason: `Created new virtual ${newAsset.category.toLowerCase()} asset`,
      riskLevel: 'MEDIUM',
      afterValue: { status: newAsset.status, price: newAsset.price }
    });

    setIsAddModalOpen(false);
    showFeedback(`Asset "${newAsset.name}" successfully created.`);
  };

  const handleSaveEditAsset = async (e) => {
    e.preventDefault();
    const payload = {
      name: formName,
      category: formCategory,
      subCategory: formSubCategory,
      price: Number(formPrice),
      status: formStatus,
      roomAvailability: formRoomAvailability,
      thumbnail: formThumbnail,
      duration: Number(formDuration),
      volume: Number(formVolume),
      comboSupport: formComboSupport,
      comboCount: Number(formComboCount),
      fullScreen: formFullScreen,
      priority: Number(formPriority),
      startDate: formStartDate,
      endDate: formEndDate,
      assignment: formAssignment
    };

    const updated = await updateAsset(selectedAsset.id, payload, 'Super Admin', 'Updated asset properties via UI editor form');
    setAssets((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));

    await logAdminAction({
      action: 'ASSET_UPDATED',
      module: 'Assets',
      targetType: 'asset',
      targetId: selectedAsset.id,
      targetName: selectedAsset.name,
      reason: 'Modified virtual asset config and parameters',
      riskLevel: 'LOW',
      beforeValue: { status: selectedAsset.status, price: selectedAsset.price },
      afterValue: { status: updated.status, price: updated.price }
    });

    setIsEditModalOpen(false);
    showFeedback(`Asset "${updated.name}" updated successfully.`);
  };

  const handleReplaceFile = async (e) => {
    e.preventDefault();
    if (!uploadFile) return;

    const fileInfo = { fileName: uploadFile.name };
    const updated = await replaceAssetFile(selectedAsset.id, fileInfo, 'Super Admin');
    setAssets((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));

    await logAdminAction({
      action: 'ASSET_FILE_REPLACED',
      module: 'Assets',
      targetType: 'asset',
      targetId: selectedAsset.id,
      targetName: selectedAsset.name,
      reason: replaceReason || `Replaced asset media file with ${uploadFile.name}`,
      riskLevel: 'MEDIUM',
    });

    setIsReplaceModalOpen(false);
    setUploadFile(null);
    setReplaceReason('');
    showFeedback(`Media asset replaced successfully for ${selectedAsset.name}.`);
  };

  const handleDelete = async (asset) => {
    if (!window.confirm(`Are you sure you want to archive asset ${asset.name}? This cannot be undone and will stop app rendering for new transactions.`)) {
      return;
    }

    await deleteAsset(asset.id);
    setAssets((prev) => prev.filter((a) => a.id !== asset.id));

    await logAdminAction({
      action: 'ASSET_ARCHIVED',
      module: 'Assets',
      targetType: 'asset',
      targetId: asset.id,
      targetName: asset.name,
      reason: 'Administrative archive action (soft delete)',
      riskLevel: 'HIGH',
      beforeValue: { status: asset.status },
      afterValue: { status: 'archived' }
    });

    showFeedback(`Asset "${asset.name}" has been archived.`);
  };

  const toggleAssetStatus = async (asset) => {
    const newStatus = asset.status === 'active' ? 'disabled' : 'active';
    const updated = await updateAsset(asset.id, { status: newStatus }, 'Super Admin', `Toggled status to ${newStatus}`);
    setAssets((prev) => prev.map((a) => (a.id === asset.id ? updated : a)));

    await logAdminAction({
      action: `ASSET_${newStatus.toUpperCase()}`,
      module: 'Assets',
      targetType: 'asset',
      targetId: asset.id,
      targetName: asset.name,
      reason: `Operator toggled status to ${newStatus}`,
      riskLevel: 'MEDIUM',
      beforeValue: { status: asset.status },
      afterValue: { status: newStatus }
    });

    showFeedback(`Asset "${asset.name}" is now ${newStatus}.`);
  };

  const handleDuplicate = async (asset) => {
    const duplicatePayload = {
      ...asset,
      id: `ast-${Date.now().toString().slice(-6)}`,
      name: `${asset.name} (Copy)`,
      status: 'draft',
      updatedAt: new Date().toISOString()
    };

    const newAsset = await addAsset(duplicatePayload, 'Super Admin');
    setAssets((prev) => [newAsset, ...prev]);

    await logAdminAction({
      action: 'ASSET_DUPLICATED',
      module: 'Assets',
      targetType: 'asset',
      targetId: newAsset.id,
      targetName: newAsset.name,
      reason: `Duplicated from ${asset.id}`,
      riskLevel: 'LOW',
    });

    showFeedback(`Asset "${asset.name}" duplicated as draft.`);
  };

  const handleOpenInheritance = (asset) => {
    setSelectedAssetInherit(asset);
    setScope(asset.scope || 'GLOBAL');
    setOverrideValue(asset.overrideValue || '');
    setInheritedValue(asset.inheritedValue || `${asset.price} coins`);
  };

  const handleSaveInheritance = async () => {
    if (!selectedAssetInherit) return;

    setAssets(assets.map(a => {
      if (a.id === selectedAssetInherit.id) {
        return {
          ...a,
          scope,
          overrideValue,
          price: overrideValue && !isNaN(parseInt(overrideValue)) ? parseInt(overrideValue) : a.price
        };
      }
      return a;
    }));

    await logAdminAction({
      action: 'ASSET_INHERITANCE_UPDATED',
      module: 'Assets',
      targetType: 'asset',
      targetId: selectedAssetInherit.id,
      targetName: selectedAssetInherit.name,
      reason: `Updated scope to ${scope} with override ${overrideValue}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Asset pricing override settings updated for ${selectedAssetInherit.name}.`);
    setSelectedAssetInherit(null);
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
    }
    showFeedback('Scope override reset to parent.');
  };

  const filteredAssets = useMemo(() => {
    return assets.filter((item) => {
      const matchCat = activeCategory === 'ALL' || item.category === activeCategory;
      const matchStatus = statusFilter === 'ALL' || item.status === statusFilter.toLowerCase();
      const q = search.toLowerCase();
      const matchSearch =
        !q ||
        item.id.toLowerCase().includes(q) ||
        item.name.toLowerCase().includes(q) ||
        item.category.toLowerCase().includes(q);

      return matchCat && matchStatus && matchSearch;
    });
  }, [assets, activeCategory, statusFilter, search]);

  const columns = [
    {
      key: 'asset',
      header: 'Asset Identity',
      render: (row) => (
        <div className="flex items-center gap-3">
          <div className="relative h-11 w-11 rounded-lg bg-slate-900 border border-slate-700/60 overflow-hidden flex-shrink-0 flex items-center justify-center">
            {row.thumbnail ? (
              <img src={row.thumbnail} alt={row.name} className="h-full w-full object-cover" />
            ) : (
              <ImageIcon className="h-5 w-5 text-slate-500" />
            )}
          </div>
          <div>
            <p className="text-sm font-bold text-white leading-tight">{row.name}</p>
            <div className="flex items-center gap-1.5 mt-0.5">
              <span className="font-mono text-[10px] text-slate-400 font-bold">{row.id}</span>
              <span className="px-1.5 py-0.5 rounded bg-slate-800 text-slate-300 text-[9px] font-medium border border-slate-700">
                {row.category}
              </span>
              <Badge variant="purple" className="text-[9px] font-mono"><Globe className="h-2.5 w-2.5 mr-0.5 inline" /> {row.scope || 'GLOBAL'}</Badge>
            </div>
          </div>
        </div>
      )
    },
    {
      key: 'type',
      header: 'Type & Availability',
      render: (row) => (
        <div>
          <span className="text-xs text-slate-300 font-semibold">{row.subCategory || 'Static'}</span>
          <div className="flex gap-1.5 mt-0.5">
            {row.roomAvailability === 'Both' || row.roomAvailability === 'Live' ? (
              <Badge variant="purple" className="text-[9px] px-1 py-0 flex items-center gap-0.5">
                <Video className="h-2.5 w-2.5" /> Live
              </Badge>
            ) : null}
            {row.roomAvailability === 'Both' || row.roomAvailability === 'Audio' ? (
              <Badge variant="purple" className="text-[9px] px-1 py-0 flex items-center gap-0.5 bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                <Radio className="h-2.5 w-2.5" /> Audio
              </Badge>
            ) : null}
          </div>
        </div>
      )
    },
    {
      key: 'price',
      header: 'Pricing (Coins)',
      render: (row) => (
        <div className="flex flex-col font-mono text-xs">
          <div className="flex items-center gap-1 font-bold text-gold-400">
            <Coins className="h-3.5 w-3.5" />
            <span>{row.price > 0 ? formatNumber(row.price) : 'Free / Role Reward'}</span>
          </div>
          {row.overrideValue && <span className="text-[10px] text-emerald-400">Override: {row.overrideValue}</span>}
        </div>
      )
    },
    {
      key: 'assignment',
      header: 'Role Assignment',
      render: (row) => (
        <span className="text-xs text-slate-300 font-medium">
          {row.assignment || 'All Users'}
        </span>
      )
    },
    {
      key: 'status',
      header: 'Publishing State',
      render: (row) => {
        let variant = 'default';
        if (row.status === 'active') variant = 'success';
        if (row.status === 'disabled') variant = 'danger';
        if (row.status === 'scheduled') variant = 'warning';
        return <StatusBadge status={row.status} customVariant={variant} />;
      }
    },
    {
      key: 'dates',
      header: 'Schedule Range',
      render: (row) => (
        <div className="text-[11px] text-slate-400 font-mono">
          {row.startDate ? (
            <p>From: {row.startDate}</p>
          ) : (
            <p className="text-slate-500 italic">Always Active</p>
          )}
          {row.endDate && <p>Until: {row.endDate}</p>}
        </div>
      )
    },
    {
      key: 'actions',
      header: 'Control Actions',
      render: (row) => (
        <div className="flex items-center gap-2">
          <button
            onClick={() => { setSelectedAsset(row); setDetailModalOpen(true); }}
            className="px-2 py-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold"
          >
            Inspect
          </button>
          <button
            onClick={() => handleOpenEditModal(row)}
            className="px-2 py-1 rounded bg-gold-500/10 hover:bg-gold-500/20 text-gold-400 text-xs font-semibold border border-gold-500/20"
          >
            Edit
          </button>
          <button
            onClick={() => handleOpenInheritance(row)}
            className="px-2 py-1 rounded bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 text-xs font-semibold border border-purple-500/20"
          >
            Scope
          </button>
          <button
            onClick={() => { setSelectedAsset(row); setIsReplaceModalOpen(true); }}
            className="px-2 py-1 rounded bg-sky-500/10 hover:bg-sky-500/20 text-sky-400 text-xs font-semibold border border-sky-500/20"
          >
            Replace
          </button>
          <button
            onClick={() => toggleAssetStatus(row)}
            className={`px-2 py-1 rounded text-xs font-semibold border ${
              row.status === 'active'
                ? 'bg-red-500/10 hover:bg-red-500/20 text-red-400 border-red-500/20'
                : 'bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-400 border-emerald-500/20'
            }`}
          >
            {row.status === 'active' ? 'Disable' : 'Enable'}
          </button>
          <button
            onClick={() => handleDuplicate(row)}
            className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-white"
            title="Duplicate"
          >
            <Copy className="h-3.5 w-3.5" />
          </button>
          <button
            onClick={() => handleDelete(row)}
            className="p-1 rounded hover:bg-slate-800 text-slate-500 hover:text-red-400"
            title="Archive"
          >
            <Trash2 className="h-3.5 w-3.5" />
          </button>
        </div>
      )
    }
  ];

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Asset Management Hub">
      
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-800 pb-5">
        <div>
          <div className="flex items-center gap-2">
            <Sparkles className="h-6 w-6 text-gold-400" />
            <h1 className="text-xl font-bold tracking-tight text-white">ZeParty Asset Library</h1>
          </div>
          <p className="text-xs text-slate-400 mt-1">
            Publish, schedule, preview and assign gifts, profile frames, sound effects and premium chat bubbles.
          </p>
        </div>
        <Button onClick={handleOpenAddModal} variant="primary" size="sm" leftIcon={Plus}>
          Add Virtual Asset
        </Button>
      </div>

      {feedback && (
        <div className="p-3 bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs rounded-xl flex items-center gap-2 font-medium">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Category Tabs Scrollbar */}
      <div className="flex gap-2 border-b border-slate-800 pb-3 overflow-x-auto scrollbar-thin">
        {CATEGORIES.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setActiveCategory(cat.id)}
            className={`px-3 py-2 rounded-lg text-xs font-semibold whitespace-nowrap transition-all border ${
              activeCategory === cat.id
                ? 'bg-gold-500/20 text-gold-400 border-gold-500/40 shadow-sm shadow-gold-500/10'
                : 'text-slate-400 hover:text-white bg-slate-900 border-slate-800 hover:border-slate-700'
            }`}
          >
            {cat.label}
          </button>
        ))}
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col md:flex-row gap-3 items-center justify-between">
        <div className="relative w-full md:w-80">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-500" />
          <Input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by Asset ID, Name..."
            className="pl-9"
          />
        </div>
        
        <div className="flex gap-2 items-center w-full md:w-auto">
          <span className="text-xs text-slate-400 whitespace-nowrap font-medium">Publish Status:</span>
          <Select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="w-36">
            <option value="ALL">All States</option>
            <option value="ACTIVE">Active</option>
            <option value="DISABLED">Disabled</option>
            <option value="DRAFT">Draft</option>
            <option value="SCHEDULED">Scheduled</option>
          </Select>
        </div>
      </div>

      {/* Data Table */}
      <Card className="border-slate-800/80 bg-slate-900/40 overflow-hidden">
        <DataTable
          columns={columns}
          data={filteredAssets}
          isLoading={isLoading}
          emptyMessage="No assets match the current category, search or status filters."
        />
      </Card>

      {/* UNIVERSAL ADD ASSET MODAL */}
      <Modal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        title="Add New Virtual Asset"
        size="lg"
      >
        <form onSubmit={handleSaveNewAsset} className="space-y-4 text-xs">
          
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Asset Name"
              value={formName}
              onChange={(e) => setFormName(e.target.value)}
              required
              placeholder="e.g. Sapphire Dragon"
            />
            <Input
              label="Unique Asset ID"
              value={formId}
              onChange={(e) => setFormId(e.target.value)}
              required
              placeholder="e.g. ast-gif-dragon"
            />
          </div>

          <div className="grid grid-cols-3 gap-3">
            <Select label="Category" value={formCategory} onChange={(e) => setFormCategory(e.target.value)}>
              <option value="GIFTS">Gifts</option>
              <option value="VIP_SVIP_FRAMES">VIP/SVIP Frames</option>
              <option value="TAGS">Tags</option>
              <option value="BADGES">Badges</option>
              <option value="PROFILE_FRAMES">Profile Frames</option>
              <option value="CHAT_BUBBLES">Chat Bubbles</option>
              <option value="BAGS">Bags</option>
              <option value="ENTRY_EFFECTS">Entry Effects</option>
              <option value="ANIMATIONS">Animations</option>
              <option value="SOUND_EFFECTS">Sound Effects</option>
              <option value="VIDEO_ASSETS">Video Assets</option>
            </Select>

            <Select label="Sub-Category / Format" value={formSubCategory} onChange={(e) => setFormSubCategory(e.target.value)}>
              <option value="Static">Static PNG/WebP</option>
              <option value="Animated">Animated WebP/GIF</option>
              <option value="Video">Video MP4 Effect</option>
              <option value="Combo">Combo Accumulator</option>
              <option value="SVIP 1-12">SVIP 1–12 Frame</option>
              <option value="Noble">Noble Customizer</option>
              <option value="Mystery">Mystery Mystery</option>
              <option value="Role Tag">Role Tag Badge</option>
              <option value="Sound Effect">Audio MP3/WAV</option>
            </Select>

            <Input
              label="Coin Price (Coins)"
              type="number"
              value={formPrice}
              onChange={(e) => setFormPrice(e.target.value)}
              required
              min="0"
            />
          </div>

          {/* Interactive Upload Validation Form Area */}
          <div className="p-3 bg-slate-950 rounded-xl border border-slate-800 space-y-2">
            <label className="block text-[11px] font-semibold text-slate-300">Upload Media Attachment</label>
            <div className="flex items-center gap-3">
              <input
                type="file"
                onChange={simulateFileUpload}
                className="block w-full text-xs text-slate-400 file:mr-3 file:py-1.5 file:px-3 file:rounded file:border-0 file:text-[11px] file:font-semibold file:bg-slate-800 file:text-white hover:file:bg-slate-700 cursor-pointer"
              />
            </div>
            {isUploading && (
              <div className="space-y-1">
                <div className="flex justify-between text-[10px] text-slate-400">
                  <span>Uploading simulated file...</span>
                  <span>{uploadProgress}%</span>
                </div>
                <div className="h-1.5 w-full bg-slate-900 rounded-full overflow-hidden">
                  <div className="h-full bg-gold-500" style={{ width: `${uploadProgress}%` }}></div>
                </div>
              </div>
            )}
            {uploadError && (
              <p className="text-[10px] text-red-400 flex items-center gap-1 font-semibold">
                <AlertTriangle className="h-3 w-3 shrink-0" /> {uploadError}
              </p>
            )}
            {!uploadError && !isUploading && uploadFile && (
              <p className="text-[10px] text-emerald-400 flex items-center gap-1 font-semibold">
                <CheckCircle className="h-3 w-3 shrink-0" /> Validated attachment: {uploadFile.name}
              </p>
            )}
          </div>

          <div className="grid grid-cols-3 gap-3">
            <Select label="Publish State" value={formStatus} onChange={(e) => setFormStatus(e.target.value)}>
              <option value="active">Active (Appears immediately)</option>
              <option value="draft">Draft (Not visible to app)</option>
              <option value="scheduled">Scheduled (Activates by date range)</option>
              <option value="disabled">Disabled (No new transactions)</option>
            </Select>

            <Select label="Room Availability" value={formRoomAvailability} onChange={(e) => setFormRoomAvailability(e.target.value)}>
              <option value="Both">Both (Live & Audio Rooms)</option>
              <option value="Live">Live Rooms Only</option>
              <option value="Audio">Social Audio Rooms Only</option>
            </Select>

            <Select label="Role/Level Eligibility" value={formAssignment} onChange={(e) => setFormAssignment(e.target.value)}>
              {ROLES_LIST.map((r) => (
                <option key={r} value={r}>{r}</option>
              ))}
            </Select>
          </div>

          <div className="grid grid-cols-4 gap-3">
            <Input
              label="Duration (Seconds)"
              type="number"
              value={formDuration}
              onChange={(e) => setFormDuration(e.target.value)}
              min="0"
            />
            <Input
              label="Audio Volume (%)"
              type="number"
              value={formVolume}
              onChange={(e) => setFormVolume(e.target.value)}
              min="0"
              max="100"
            />
            <Input
              label="Priority Order"
              type="number"
              value={formPriority}
              onChange={(e) => setFormPriority(e.target.value)}
              min="1"
            />
            <div className="flex flex-col justify-end pb-1">
              <label className="flex items-center gap-1.5 text-slate-300 font-semibold cursor-pointer">
                <input
                  type="checkbox"
                  checked={formComboSupport}
                  onChange={(e) => setFormComboSupport(e.target.checked)}
                  className="rounded border-slate-700 text-gold-500 focus:ring-0"
                />
                Combo Pack
              </label>
            </div>
          </div>

          {/* Conditional Dates if Scheduled */}
          {formStatus === 'scheduled' && (
            <div className="grid grid-cols-2 gap-3 p-3 bg-slate-900 border border-slate-800 rounded-xl">
              <Input
                label="Activation Start Date"
                type="date"
                value={formStartDate}
                onChange={(e) => setFormStartDate(e.target.value)}
                required
              />
              <Input
                label="Activation Expiry Date"
                type="date"
                value={formEndDate}
                onChange={(e) => setFormEndDate(e.target.value)}
                required
              />
            </div>
          )}

          <div className="flex justify-end gap-2 pt-3 border-t border-slate-800">
            <Button type="button" variant="ghost" size="sm" onClick={() => setIsAddModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" size="sm" disabled={isUploading}>
              Publish Asset
            </Button>
          </div>

        </form>
      </Modal>

      {/* EDIT ASSET MODAL */}
      <Modal
        isOpen={isEditModalOpen}
        onClose={() => setIsEditModalOpen(false)}
        title={`Edit Asset Parameters: ${selectedAsset?.name}`}
        size="lg"
      >
        <form onSubmit={handleSaveEditAsset} className="space-y-4 text-xs">
          
          <div className="grid grid-cols-2 gap-3">
            <Input
              label="Asset Name"
              value={formName}
              onChange={(e) => setFormName(e.target.value)}
              required
            />
            <Input
              label="Unique Asset ID (Immutable)"
              value={formId}
              disabled
            />
          </div>

          <div className="grid grid-cols-3 gap-3">
            <Select label="Category" value={formCategory} onChange={(e) => setFormCategory(e.target.value)}>
              <option value="GIFTS">Gifts</option>
              <option value="VIP_SVIP_FRAMES">VIP/SVIP Frames</option>
              <option value="TAGS">Tags</option>
              <option value="BADGES">Badges</option>
              <option value="PROFILE_FRAMES">Profile Frames</option>
              <option value="CHAT_BUBBLES">Chat Bubbles</option>
              <option value="BAGS">Bags</option>
              <option value="ENTRY_EFFECTS">Entry Effects</option>
              <option value="ANIMATIONS">Animations</option>
              <option value="SOUND_EFFECTS">Sound Effects</option>
              <option value="VIDEO_ASSETS">Video Assets</option>
            </Select>

            <Select label="Sub-Category" value={formSubCategory} onChange={(e) => setFormSubCategory(e.target.value)}>
              <option value="Static">Static PNG/WebP</option>
              <option value="Animated">Animated WebP/GIF</option>
              <option value="Video">Video MP4 Effect</option>
              <option value="Combo">Combo Accumulator</option>
              <option value="SVIP 1-12">SVIP 1–12 Frame</option>
              <option value="Noble">Noble Customizer</option>
              <option value="Mystery">Mystery Mystery</option>
              <option value="Role Tag">Role Tag Badge</option>
              <option value="Sound Effect">Audio MP3/WAV</option>
            </Select>

            <Input
              label="Coin Price"
              type="number"
              value={formPrice}
              onChange={(e) => setFormPrice(e.target.value)}
              required
              min="0"
            />
          </div>

          <div className="grid grid-cols-3 gap-3">
            <Select label="Publish State" value={formStatus} onChange={(e) => setFormStatus(e.target.value)}>
              <option value="active">Active</option>
              <option value="draft">Draft</option>
              <option value="scheduled">Scheduled</option>
              <option value="disabled">Disabled</option>
            </Select>

            <Select label="Room Availability" value={formRoomAvailability} onChange={(e) => setFormRoomAvailability(e.target.value)}>
              <option value="Both">Both (Live & Audio)</option>
              <option value="Live">Live Rooms Only</option>
              <option value="Audio">Audio Rooms Only</option>
            </Select>

            <Select label="Eligibility" value={formAssignment} onChange={(e) => setFormAssignment(e.target.value)}>
              {ROLES_LIST.map((r) => (
                <option key={r} value={r}>{r}</option>
              ))}
            </Select>
          </div>

          <div className="grid grid-cols-4 gap-3">
            <Input label="Duration" type="number" value={formDuration} onChange={(e) => setFormDuration(e.target.value)} />
            <Input label="Volume" type="number" value={formVolume} onChange={(e) => setFormVolume(e.target.value)} />
            <Input label="Priority" type="number" value={formPriority} onChange={(e) => setFormPriority(e.target.value)} />
            <div className="flex flex-col justify-end pb-1">
              <label className="flex items-center gap-1.5 text-slate-300 font-semibold cursor-pointer">
                <input
                  type="checkbox"
                  checked={formComboSupport}
                  onChange={(e) => setFormComboSupport(e.target.checked)}
                  className="rounded border-slate-700 text-gold-500 focus:ring-0"
                />
                Combo Pack
              </label>
            </div>
          </div>

          {formStatus === 'scheduled' && (
            <div className="grid grid-cols-2 gap-3 p-3 bg-slate-900 border border-slate-800 rounded-xl">
              <Input
                label="Activation Start Date"
                type="date"
                value={formStartDate}
                onChange={(e) => setFormStartDate(e.target.value)}
                required
              />
              <Input
                label="Activation Expiry Date"
                type="date"
                value={formEndDate}
                onChange={(e) => setFormEndDate(e.target.value)}
                required
              />
            </div>
          )}

          <div className="flex justify-end gap-2 pt-3 border-t border-slate-800">
            <Button type="button" variant="ghost" size="sm" onClick={() => setIsEditModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" size="sm">
              Save Parameters
            </Button>
          </div>

        </form>
      </Modal>

      {/* REPLACE MEDIA FILE MODAL */}
      <Modal
        isOpen={isReplaceModalOpen}
        onClose={() => setIsReplaceModalOpen(false)}
        title={`Replace Asset Media File: ${selectedAsset?.name}`}
        size="md"
      >
        <form onSubmit={handleReplaceFile} className="space-y-4 text-xs">
          <div className="p-3.5 bg-slate-950 border border-slate-800 rounded-xl">
            <p className="text-[11px] text-slate-300">
              You are replacing the authorized graphics, video MP4, or sound sample for <strong className="text-white">{selectedAsset?.name}</strong>. Previous logs and transactions will remain linked to this Asset ID, but new users will see this new upload.
            </p>
          </div>

          <div className="space-y-2">
            <label className="block text-[11px] font-semibold text-slate-300">Select New Media File</label>
            <input
              type="file"
              onChange={simulateFileUpload}
              className="block w-full text-xs text-slate-400 file:mr-3 file:py-1.5 file:px-3 file:rounded file:border-0 file:text-[11px] file:font-semibold file:bg-slate-800 file:text-white hover:file:bg-slate-700 cursor-pointer"
              required
            />
            {isUploading && (
              <div className="space-y-1 mt-2">
                <div className="flex justify-between text-[10px] text-slate-400">
                  <span>Uploading file...</span>
                  <span>{uploadProgress}%</span>
                </div>
                <div className="h-1.5 w-full bg-slate-900 rounded-full overflow-hidden">
                  <div className="h-full bg-gold-500" style={{ width: `${uploadProgress}%` }}></div>
                </div>
              </div>
            )}
            {uploadError && (
              <p className="text-[10px] text-red-400 flex items-center gap-1 font-semibold mt-1">
                <AlertTriangle className="h-3 w-3" /> {uploadError}
              </p>
            )}
            {!uploadError && !isUploading && uploadFile && (
              <p className="text-[10px] text-emerald-400 flex items-center gap-1 font-semibold mt-1">
                <CheckCircle className="h-3 w-3" /> File validated successfully: {uploadFile.name}
              </p>
            )}
          </div>

          <Input
            label="Reason for Replacement (Mandatory for Audit Trail)"
            value={replaceReason}
            onChange={(e) => setReplaceReason(e.target.value)}
            placeholder="e.g. Updating model animations for holiday event"
            required
          />

          <div className="flex justify-end gap-2 pt-3 border-t border-slate-800">
            <Button type="button" variant="ghost" size="sm" onClick={() => setIsReplaceModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" size="sm" disabled={isUploading || !uploadFile}>
              Confirm Replacement
            </Button>
          </div>
        </form>
      </Modal>

      {/* INSPECT DETAILS & HISTORY & LIVE AVATAR PREVIEW MODAL */}
      <Modal
        isOpen={detailModalOpen}
        onClose={() => setDetailModalOpen(false)}
        title={`Asset Inspector Details: ${selectedAsset?.name}`}
        size="lg"
      >
        <div className="space-y-5 text-xs text-slate-300">
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            
            {/* Asset Profile Info Card */}
            <div className="p-4 bg-slate-950 border border-slate-800 rounded-xl space-y-2">
              <h3 className="font-bold text-white text-[11px] uppercase tracking-wider">Asset Properties</h3>
              <div className="space-y-1.5 text-xs">
                <p>Asset Reference: <strong className="text-white font-mono">{selectedAsset?.id}</strong></p>
                <p>Category: <strong className="text-white">{selectedAsset?.category}</strong></p>
                <p>Sub-Category: <strong className="text-white">{selectedAsset?.subCategory}</strong></p>
                <p>Price: <strong className="text-gold-400 font-mono">{selectedAsset?.price} Coins</strong></p>
                <p>Priority Order: <strong className="text-white">{selectedAsset?.priority}</strong></p>
                <p>Availability: <strong className="text-purple-400">{selectedAsset?.roomAvailability} Rooms</strong></p>
                <p>Level Requirement: <strong className="text-white">{selectedAsset?.assignment}</strong></p>
                <p>Status: <strong className="text-white uppercase">{selectedAsset?.status}</strong></p>
                <p>Last Modified: <strong className="text-slate-400">{formatDate(selectedAsset?.updatedAt)}</strong></p>
              </div>
            </div>

            {/* LIVE PREVIEW COMPONENT FOR FRAMES */}
            <div className="p-4 bg-slate-950 border border-slate-800 rounded-xl flex flex-col items-center justify-center">
              <h3 className="font-bold text-white text-[11px] uppercase tracking-wider mb-3 self-start">Interactive Preview</h3>
              
              {/* Sample Avatar Border Preview for Frames */}
              {selectedAsset?.category === 'VIP_SVIP_FRAMES' || selectedAsset?.category === 'PROFILE_FRAMES' ? (
                <div className="relative h-28 w-28 flex items-center justify-center">
                  {/* Outer Border/Frame Preview simulator */}
                  <div className="absolute inset-0 rounded-full border-4 border-dashed border-gold-500 animate-spin-slow"></div>
                  {/* Sample User Avatar Image */}
                  <img
                    src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80"
                    alt="Sample Avatar"
                    className="h-20 w-20 rounded-full object-cover border-2 border-slate-900 z-10"
                  />
                  {/* Badge overlap preview */}
                  <span className="absolute bottom-1 right-2 bg-slate-900 px-1 py-0.5 rounded border border-slate-700 text-[8px] text-gold-400 font-bold z-20">
                    SVIP 5
                  </span>
                </div>
              ) : selectedAsset?.category === 'GIFTS' || selectedAsset?.category === 'ANIMATIONS' ? (
                <div className="relative h-28 w-full border border-slate-800 rounded-lg bg-slate-900 flex flex-col items-center justify-center text-center p-3">
                  <div className="h-12 w-12 rounded-lg bg-slate-950 border border-slate-800 flex items-center justify-center overflow-hidden">
                    <img src={selectedAsset?.thumbnail} alt="Gift" className="h-full w-full object-cover" />
                  </div>
                  <p className="text-[10px] text-slate-400 mt-1 font-semibold">Animation Duration: {selectedAsset?.duration}s</p>
                  <button
                    onClick={() => alert('Simulating full screen web player gift particle effect...')}
                    type="button"
                    className="mt-1.5 px-2 py-0.5 rounded bg-gold-500 text-slate-950 font-bold text-[9px] uppercase tracking-wider flex items-center gap-1 hover:bg-gold-400"
                  >
                    <Play className="h-2.5 w-2.5" /> Preview Gift
                  </button>
                </div>
              ) : selectedAsset?.category === 'SOUND_EFFECTS' ? (
                <div className="h-28 w-full flex flex-col items-center justify-center gap-2">
                  <Volume2 className="h-10 w-10 text-gold-400 animate-bounce" />
                  <button
                    onClick={() => alert(`Simulating playback of audio file at volume level ${selectedAsset?.volume}%`)}
                    type="button"
                    className="px-3 py-1 bg-slate-800 text-white rounded font-bold hover:bg-slate-700 text-[10px] flex items-center gap-1"
                  >
                    <Play className="h-3 w-3" /> Play Sound Sample
                  </button>
                </div>
              ) : (
                <div className="h-28 w-28 rounded-lg bg-slate-900 border border-slate-800 overflow-hidden flex items-center justify-center">
                  <img src={selectedAsset?.thumbnail} alt="Preset thumbnail" className="h-full w-full object-cover" />
                </div>
              )}
              <p className="text-[10px] text-slate-400 mt-2 font-mono">Render ID: {selectedAsset?.id}-PREV</p>
            </div>

          </div>

          {/* HISTORICAL CHANGES / AUDIT LOG TABLE FOR THIS ASSET */}
          <div className="space-y-2">
            <div className="flex items-center gap-1.5">
              <History className="h-4 w-4 text-gold-400" />
              <h3 className="font-bold text-white text-[11px] uppercase tracking-wider">Asset Configuration Version Audit Trail</h3>
            </div>
            <div className="max-h-48 overflow-y-auto border border-slate-800 rounded-xl divide-y divide-slate-800 bg-slate-950/80">
              {selectedAsset?.history && selectedAsset.history.length > 0 ? (
                selectedAsset.history.map((log, i) => (
                  <div key={i} className="p-3 text-xs flex justify-between gap-4">
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-gold-400 font-mono text-[10px]">{log.action.toUpperCase()}</span>
                        <span className="text-slate-500 font-mono text-[10px]">{formatDate(log.timestamp)}</span>
                      </div>
                      <p className="text-white italic">"{log.details}"</p>
                      {log.before && (
                        <p className="text-[10px] text-slate-400">
                          Change state: <span className="text-red-400 line-through">{log.before}</span> → <span className="text-emerald-400 font-semibold">{log.after}</span>
                        </p>
                      )}
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className="font-semibold text-slate-300">{log.operator}</p>
                      <p className="text-[10px] text-slate-500">Security Operator</p>
                    </div>
                  </div>
                ))
              ) : (
                <p className="p-4 text-xs text-slate-500 text-center">No history changes logs compiled for this asset ID.</p>
              )}
            </div>
          </div>

          <div className="flex justify-end pt-3 border-t border-slate-800">
            <Button variant="ghost" size="sm" onClick={() => setDetailModalOpen(false)}>
              Close Inspector
            </Button>
          </div>

        </div>
      </Modal>

    {/* Scope Overrides Modal */}
      {selectedAssetInherit && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedAssetInherit(null)}
          title={`Asset Pricing Scope overrides: ${selectedAssetInherit.name}`}
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
              <Button variant="ghost" size="sm" onClick={() => setSelectedAssetInherit(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save override
              </Button>
            </div>
          </div>
        </Modal>
      )}

    </div>
  );
}
