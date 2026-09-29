// ============================================================
// ZeParty Admin Portal — Master Economy & Policy Settings Engine
// Bulletproof, 100% Fully Editable, Server-Authoritative Database Sync
// ============================================================

import React, { useState, useEffect } from 'react';
import {
  Sliders, Save, History, CheckCircle2, ShieldAlert, DollarSign,
  Plus, RefreshCw, BarChart3, ShieldCheck, ArrowRightLeft,
  AlertCircle, RotateCcw, Sparkles, Eye, Check, Lock, Building,
  Mic, Video, Trash2, Edit2, Info, Settings2, Percent, Layers
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getEconomyConfigs,
  updateEconomyConfig,
  disableEconomyConfig,
  restoreEconomyConfig,
  getEffectivePolicy,
  getEconomyConfigByKey,
} from '../../services/modules/economy.service';

// Authoritative Baseline Defaults (used if database has fresh/empty tables)
const DEFAULT_ECONOMY_POLICY = {
  version: 'v3.0.0',
  platformShare: 45,
  hostShare: 35,
  agencyShare: 12,
  roomReward: 8,
  status: 'ACTIVE'
};

const DEFAULT_COUNTRY_OVERRIDES = [
  { id: 'ov-1', country: '🇵🇰 Pakistan (PK)', platform: 40, host: 40, agency: 12, room: 8, status: 'ACTIVE' },
  { id: 'ov-2', country: '🇸🇦 Saudi Arabia (SA)', platform: 42, host: 38, agency: 12, room: 8, status: 'ACTIVE' },
  { id: 'ov-3', country: '🇺🇸 United States (US)', platform: 45, host: 35, agency: 12, room: 8, status: 'DEFAULT' },
  { id: 'ov-4', country: '🇧🇷 Brazil (BR)', platform: 40, host: 40, agency: 12, room: 8, status: 'ACTIVE' }
];

const DEFAULT_EXCHANGE_RATES = [
  {
    id: 'ex-101',
    rateType: 'USD_TO_COIN',
    name: 'USD to Coin Standard Rate',
    currency: 'USD',
    country: 'GLOBAL',
    currentRate: 10000,
    proposedRate: 10500,
    unit: 'Coins / $1 USD',
    status: 'ACTIVE',
    version: 'v3.2.0',
    effectiveDate: '2026-08-01',
    history: [
      { version: 'v3.2.0', rate: 10000, effectiveDate: '2026-08-01', changedBy: 'Super Admin', notes: 'Baseline standard coin conversion.' }
    ]
  },
  {
    id: 'ex-102',
    rateType: 'DIAMOND_TO_USD',
    name: 'Diamond to USD Payout Rate',
    currency: 'USD',
    country: 'GLOBAL',
    currentRate: 10000,
    proposedRate: 10000,
    unit: 'Diamonds / $1 USD',
    status: 'ACTIVE',
    version: 'v3.0.0',
    effectiveDate: '2026-01-01',
    history: [
      { version: 'v3.0.0', rate: 10000, effectiveDate: '2026-01-01', changedBy: 'Finance Admin', notes: 'Established host payout conversion baseline.' }
    ]
  },
  {
    id: 'ex-103',
    rateType: 'PK_LOCAL_CURRENCY',
    name: 'PKR Local Fiat to Coin Rate',
    currency: 'PKR',
    country: 'PK',
    currentRate: 35,
    proposedRate: 38,
    unit: 'Coins / 1 PKR',
    status: 'SCHEDULED',
    version: 'v3.3.0-draft',
    effectiveDate: '2026-09-01',
    history: [
      { version: 'v3.2.0', rate: 35, effectiveDate: '2026-06-01', changedBy: 'Regional Admin PK', notes: 'Adjusted for FX inflation.' }
    ]
  },
  {
    id: 'ex-104',
    rateType: 'BRL_LOCAL_CURRENCY',
    name: 'BRL Local Fiat to Coin Rate',
    currency: 'BRL',
    country: 'BR',
    currentRate: 1800,
    proposedRate: 1800,
    unit: 'Coins / 1 BRL',
    status: 'ACTIVE',
    version: 'v3.1.0',
    effectiveDate: '2026-04-10',
    history: [
      { version: 'v3.1.0', rate: 1800, effectiveDate: '2026-04-10', changedBy: 'Finance Admin', notes: 'LATAM expansion localized rate.' }
    ]
  }
];

const DEFAULT_TRANSFER_RATES = [
  {
    id: 'tr-201',
    transferType: 'COIN_RESELLER_FEE',
    name: 'Reseller Coin Transfer Commission',
    description: 'Percentage fee applied to bulk coin transfers between platform and resellers',
    currentRatePercent: 2.5,
    proposedRatePercent: 3.0,
    status: 'ACTIVE',
    version: 'v2.1.0'
  },
  {
    id: 'tr-202',
    transferType: 'MERCHANT_ALLOCATION_FEE',
    name: 'Merchant Coin Allocation Fee',
    description: 'Processing percentage fee for custom merchant coin allocations',
    currentRatePercent: 1.8,
    proposedRatePercent: 2.0,
    status: 'ACTIVE',
    version: 'v1.4.0'
  },
  {
    id: 'tr-203',
    transferType: 'HOST_TO_HOST_TRANSFER_FEE',
    name: 'Host-to-Host Coin Transfer Fee',
    description: 'Commission fee for direct user/host coin transfers in room chats',
    currentRatePercent: 5.0,
    proposedRatePercent: 5.0,
    status: 'ACTIVE',
    version: 'v3.0.0'
  }
];

const DEFAULT_LIVE_HOST_TIERS = [
  { level: 1, targetDiamonds: 25000, durationDays: 10, basicSalaryUSD: 2.00, dailyHoursRequired: 1.0 },
  { level: 2, targetDiamonds: 50000, durationDays: 10, basicSalaryUSD: 4.00, dailyHoursRequired: 1.0 },
  { level: 3, targetDiamonds: 100000, durationDays: 10, basicSalaryUSD: 8.00, dailyHoursRequired: 1.0 },
  { level: 4, targetDiamonds: 250000, durationDays: 10, basicSalaryUSD: 20.00, dailyHoursRequired: 1.0 },
  { level: 5, targetDiamonds: 500000, durationDays: 8, basicSalaryUSD: 40.00, dailyHoursRequired: 1.0 },
  { level: 6, targetDiamonds: 1000000, durationDays: 8, basicSalaryUSD: 80.00, dailyHoursRequired: 1.0 },
  { level: 7, targetDiamonds: 2500000, durationDays: 8, basicSalaryUSD: 200.00, dailyHoursRequired: 1.0 },
  { level: 8, targetDiamonds: 5000000, durationDays: 5, basicSalaryUSD: 400.00, dailyHoursRequired: 1.0 },
  { level: 9, targetDiamonds: 10000000, durationDays: 5, basicSalaryUSD: 800.00, dailyHoursRequired: 1.0 },
  { level: 10, targetDiamonds: 20000000, durationDays: 5, basicSalaryUSD: 1600.00, dailyHoursRequired: 1.0 }
];

const DEFAULT_AUDIO_HOST_TIERS = [
  { level: 1, tierName: '30K Audio Starter', targetCoins: 30000, dailyRewardUSD: 0.80, agencyProfitUSD: 0.15, minDailyHours: 2.0, durationDays: 10 },
  { level: 2, tierName: '60K Audio Bronze', targetCoins: 60000, dailyRewardUSD: 1.60, agencyProfitUSD: 0.30, minDailyHours: 2.0, durationDays: 10 },
  { level: 3, tierName: '100K Audio Silver', targetCoins: 100000, dailyRewardUSD: 2.80, agencyProfitUSD: 0.50, minDailyHours: 2.0, durationDays: 10 },
  { level: 4, tierName: '350K Audio Gold', targetCoins: 350000, dailyRewardUSD: 9.50, agencyProfitUSD: 1.70, minDailyHours: 2.0, durationDays: 10 },
  { level: 5, tierName: '1M Audio Platinum', targetCoins: 1000000, dailyRewardUSD: 28.00, agencyProfitUSD: 5.00, minDailyHours: 2.0, durationDays: 8 },
  { level: 6, tierName: '3M Audio VIP Master', targetCoins: 3000000, dailyRewardUSD: 90.00, agencyProfitUSD: 16.00, minDailyHours: 2.0, durationDays: 8 },
  { level: 7, tierName: '10M Audio Crown Royalty', targetCoins: 10000000, dailyRewardUSD: 320.00, agencyProfitUSD: 55.00, minDailyHours: 2.0, durationDays: 5 }
];

const DEFAULT_RESELLER_PACKAGES = [
  { id: 'res-1', tierName: 'Silver Reseller Tier', priceUSD: 50, totalCoins: 525000, bonusCoins: 25000, profitPercent: 8 },
  { id: 'res-2', tierName: 'Gold Reseller Tier', priceUSD: 200, totalCoins: 2160000, bonusCoins: 160000, profitPercent: 10 },
  { id: 'res-3', tierName: 'Platinum Reseller Tier', priceUSD: 1000, totalCoins: 11200000, bonusCoins: 1200000, profitPercent: 12 },
  { id: 'res-4', tierName: 'VIP Master Reseller Tier', priceUSD: 5000, totalCoins: 58000000, bonusCoins: 8000000, profitPercent: 15 }
];

export function EconomySettingsPage() {
  const { logAdminAction } = useAuditLog();
  const [activeTab, setActiveTab] = useState('general');
  const [feedback, setFeedback] = useState(null);
  const [isSaving, setIsSaving] = useState(false);

  // Core Editable States
  const [economyPolicy, setEconomyPolicy] = useState(DEFAULT_ECONOMY_POLICY);
  const [countryOverrides, setCountryOverrides] = useState(DEFAULT_COUNTRY_OVERRIDES);
  const [exchangeRates, setExchangeRates] = useState(DEFAULT_EXCHANGE_RATES);
  const [transferRates, setTransferRates] = useState(DEFAULT_TRANSFER_RATES);
  const [liveHostTiers, setLiveHostTiers] = useState(DEFAULT_LIVE_HOST_TIERS);
  const [audioHostTiers, setAudioHostTiers] = useState(DEFAULT_AUDIO_HOST_TIERS);
  const [resellerPackages, setResellerPackages] = useState(DEFAULT_RESELLER_PACKAGES);

  // Auto-OFF 15-day switch state
  const [isExchangeDisabled, setIsExchangeDisabled] = useState(false);
  const [isTransferDisabled, setIsTransferDisabled] = useState(false);

  // Simulator
  const [simAmount, setSimAmount] = useState('100');
  const [simMode, setSimMode] = useState('live');

  // Modals state
  const [previewModal, setPreviewModal] = useState(null);
  const [showDraftModal, setShowDraftModal] = useState(false);
  const [draftForm, setDraftForm] = useState({
    name: 'Promotional USD Coin Rate',
    currency: 'USD',
    country: 'GLOBAL',
    proposedRate: 11000,
    unit: 'Coins / $1 USD'
  });

  const [showOverrideModal, setShowOverrideModal] = useState(false);
  const [overrideForm, setOverrideForm] = useState({
    id: '',
    country: '🇹🇷 Turkey (TR)',
    platform: 41,
    host: 39,
    agency: 12,
    room: 8
  });
  const [isEditingOverride, setIsEditingOverride] = useState(false);

  // Exchange rate edit modal
  const [showEditRateModal, setShowEditRateModal] = useState(false);
  const [editingRate, setEditingRate] = useState(null);

  // Transfer fee edit modal
  const [showEditTransferModal, setShowEditTransferModal] = useState(false);
  const [editingTransfer, setEditingTransfer] = useState(null);

  // Live Host Tier Modal
  const [showLiveHostModal, setShowLiveHostModal] = useState(false);
  const [liveHostForm, setLiveHostForm] = useState({
    level: 1,
    targetDiamonds: 25000,
    durationDays: 10,
    basicSalaryUSD: 2.00,
    dailyHoursRequired: 1.0
  });
  const [isEditingLiveHost, setIsEditingLiveHost] = useState(false);

  // Audio Host Tier Modal
  const [showAudioHostModal, setShowAudioHostModal] = useState(false);
  const [audioHostForm, setAudioHostForm] = useState({
    level: 1,
    tierName: '50K Audio Tier',
    targetCoins: 50000,
    dailyRewardUSD: 1.20,
    agencyProfitUSD: 0.25,
    minDailyHours: 2.0,
    durationDays: 10
  });
  const [isEditingAudioHost, setIsEditingAudioHost] = useState(false);

  // Reseller Package Modal
  const [showResellerModal, setShowResellerModal] = useState(false);
  const [resellerForm, setResellerForm] = useState({
    id: '',
    tierName: 'Diamond Reseller Tier',
    priceUSD: 500,
    totalCoins: 5500000,
    bonusCoins: 500000,
    profitPercent: 11
  });
  const [isEditingReseller, setIsEditingReseller] = useState(false);

  // Initial Load from PostgreSQL Database
  useEffect(() => {
    async function loadData() {
      try {
        const configs = await getEconomyConfigs();
        if (Array.isArray(configs)) {
          for (const item of configs) {
            if (item.key === 'ECONOMY_POLICY_GLOBAL' && item.valueJson) {
              if (item.valueJson.revenueSplit) setEconomyPolicy((prev) => ({ ...prev, ...item.valueJson.revenueSplit }));
              if (item.valueJson.countryOverrides) setCountryOverrides(item.valueJson.countryOverrides);
            }
            if (item.key === 'EXCHANGE_RATES' && item.valueJson) {
              const rates = Array.isArray(item.valueJson) ? item.valueJson : (item.valueJson.rates || []);
              if (rates.length > 0) setExchangeRates(rates);
              if (item.status === 'DISABLED') setIsExchangeDisabled(true);
            }
            if (item.key === 'TRANSFER_RATES' && item.valueJson) {
              const trs = Array.isArray(item.valueJson) ? item.valueJson : (item.valueJson.transferRates || []);
              if (trs.length > 0) setTransferRates(trs);
              if (item.status === 'DISABLED') setIsTransferDisabled(true);
            }
            if (item.key === 'LIVE_HOST_TIERS' && item.valueJson) {
              const tiers = Array.isArray(item.valueJson) ? item.valueJson : (item.valueJson.tiers || []);
              if (tiers.length > 0) setLiveHostTiers(tiers);
            }
            if (item.key === 'AUDIO_HOST_TIERS' && item.valueJson) {
              const tiers = Array.isArray(item.valueJson) ? item.valueJson : (item.valueJson.tiers || []);
              if (tiers.length > 0) setAudioHostTiers(tiers);
            }
            if (item.key === 'RESELLER_PACKAGES' && item.valueJson) {
              const pkgs = Array.isArray(item.valueJson) ? item.valueJson : (item.valueJson.packages || []);
              if (pkgs.length > 0) setResellerPackages(pkgs);
            }
          }
        }
      } catch (err) {
        console.warn('Could not load dynamic configurations, checking effective policies:', err.message);
      }

      // Also query master policies for live/audio host fallback
      try {
        const livePol = await getEffectivePolicy('LIVE_HOST');
        if (livePol?.config?.tiers?.length) {
          setLiveHostTiers(livePol.config.tiers);
        }
        const audioPol = await getEffectivePolicy('AUDIO_HOST');
        if (audioPol?.config?.tiers?.length) {
          setAudioHostTiers(audioPol.config.tiers);
        }
      } catch (err) {
        // Fallback gracefully to default state
      }
    }

    loadData();
  }, []);

  const showToast = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 4000);
  };

  // -------------------------------------------------------------
  // General Tab Handlers
  // -------------------------------------------------------------
  const totalRevenueSplit = (Number(economyPolicy.platformShare) || 0) +
    (Number(economyPolicy.hostShare) || 0) +
    (Number(economyPolicy.agencyShare) || 0) +
    (Number(economyPolicy.roomReward) || 0);

  const handleSaveRevenuePolicy = async () => {
    if (totalRevenueSplit !== 100) {
      alert(`Warning: Revenue split shares must total exactly 100%. Current total is ${totalRevenueSplit}%. Please adjust before publishing.`);
      return;
    }
    setIsSaving(true);
    try {
      await updateEconomyConfig('ECONOMY_POLICY_GLOBAL', {
        revenueSplit: economyPolicy,
        countryOverrides,
        updatedAt: new Date().toISOString()
      }, 'Updated global platform revenue split policy & regional overrides');

      await logAdminAction({
        action: 'UPDATE_ECONOMY_POLICY',
        module: 'Economy',
        targetType: 'POLICY',
        targetId: 'ECONOMY_POLICY_GLOBAL',
        reason: 'Updated platform revenue shares and country overrides',
        riskLevel: 'HIGH',
        status: 'SUCCESS'
      });
      showToast('Global Revenue Allocation Policy & Overrides successfully saved to PostgreSQL database!');
    } catch (err) {
      showToast(`Error saving policy: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const applyPresetSplit = (p, h, a, r) => {
    setEconomyPolicy({
      ...economyPolicy,
      platformShare: p,
      hostShare: h,
      agencyShare: a,
      roomReward: r
    });
    showToast(`Applied preset split: Platform ${p}% / Host ${h}% / Agency ${a}% / Room ${r}%`);
  };

  const handleOpenAddOverride = () => {
    setIsEditingOverride(false);
    setOverrideForm({
      id: `ov-${Date.now().toString().slice(-4)}`,
      country: '',
      platform: 40,
      host: 40,
      agency: 12,
      room: 8
    });
    setShowOverrideModal(true);
  };

  const handleOpenEditOverride = (item) => {
    setIsEditingOverride(true);
    setOverrideForm({ ...item });
    setShowOverrideModal(true);
  };

  const handleDeleteOverride = (countryName) => {
    if (window.confirm(`Delete regional override for "${countryName}"?`)) {
      const updated = countryOverrides.filter((c) => c.country !== countryName);
      setCountryOverrides(updated);
      showToast(`Removed override for "${countryName}". Click "Publish Revenue Policy" to persist.`);
    }
  };

  const handleSaveOverrideSubmit = (e) => {
    e.preventDefault();
    if (isEditingOverride) {
      setCountryOverrides(countryOverrides.map((c) => (c.country === overrideForm.country ? { ...overrideForm, status: 'ACTIVE' } : c)));
      showToast(`Updated override for "${overrideForm.country}"!`);
    } else {
      setCountryOverrides([{ ...overrideForm, id: `ov-${Date.now().toString().slice(-4)}`, status: 'ACTIVE' }, ...countryOverrides]);
      showToast(`Added override for "${overrideForm.country}"!`);
    }
    setShowOverrideModal(false);
  };

  // -------------------------------------------------------------
  // Exchange Rates Handlers
  // -------------------------------------------------------------
  const handleSaveExchangeRates = async () => {
    setIsSaving(true);
    try {
      await updateEconomyConfig('EXCHANGE_RATES', {
        rates: exchangeRates,
        updatedAt: new Date().toISOString()
      }, 'Updated currency exchange rates matrix');

      await logAdminAction({
        action: 'UPDATE_EXCHANGE_RATES',
        module: 'Economy',
        targetType: 'CONFIG',
        targetId: 'EXCHANGE_RATES',
        reason: 'Updated currency exchange rates',
        riskLevel: 'HIGH',
        status: 'SUCCESS'
      });
      showToast('Exchange rates saved and published to PostgreSQL database!');
    } catch (err) {
      showToast(`Error saving exchange rates: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleToggleExchangeStatus = async () => {
    const next = !isExchangeDisabled;
    setIsExchangeDisabled(next);
    try {
      if (next) {
        await disableEconomyConfig('EXCHANGE_RATES', 'Admin switched off exchange system (15-day countdown active)');
        showToast('Exchange rates turned OFF worldwide. 15-day auto-return countdown started.');
      } else {
        await restoreEconomyConfig('EXCHANGE_RATES');
        showToast('Exchange rates manually restored to ACTIVE worldwide.');
      }
    } catch (err) {
      console.warn('API error toggling exchange:', err.message);
    }
  };

  const handleCreateDraft = (e) => {
    e.preventDefault();
    const newRate = {
      id: `ex-${Date.now().toString().slice(-4)}`,
      rateType: 'CUSTOM_RATE',
      name: draftForm.name,
      currency: draftForm.currency.toUpperCase(),
      country: draftForm.country.toUpperCase(),
      currentRate: Number(draftForm.proposedRate),
      proposedRate: Number(draftForm.proposedRate),
      unit: draftForm.unit || `Coins / $1 ${draftForm.currency}`,
      status: 'ACTIVE',
      version: `v3.${Date.now().toString().slice(-3)}`,
      effectiveDate: new Date().toISOString().split('T')[0],
      history: []
    };
    setExchangeRates([newRate, ...exchangeRates]);
    setShowDraftModal(false);
    showToast(`New currency rate "${draftForm.name}" created! Remember to click "Publish Exchange Rates".`);
  };

  const handleOpenEditRate = (rate) => {
    setEditingRate({ ...rate });
    setShowEditRateModal(true);
  };

  const handleSaveRateEdit = (e) => {
    e.preventDefault();
    setExchangeRates(exchangeRates.map((r) => (r.id === editingRate.id ? {
      ...editingRate,
      currentRate: Number(editingRate.currentRate),
      proposedRate: Number(editingRate.proposedRate)
    } : r)));
    setShowEditRateModal(false);
    showToast(`Exchange rate for "${editingRate.name}" updated!`);
  };

  const handleDeleteRate = (id, name) => {
    if (window.confirm(`Delete exchange rate configuration "${name}"?`)) {
      setExchangeRates(exchangeRates.filter((r) => r.id !== id));
      showToast(`Removed exchange rate "${name}".`);
    }
  };

  // -------------------------------------------------------------
  // Transfer Rates Handlers
  // -------------------------------------------------------------
  const handleSaveTransferRates = async () => {
    setIsSaving(true);
    try {
      await updateEconomyConfig('TRANSFER_RATES', {
        transferRates,
        updatedAt: new Date().toISOString()
      }, 'Updated platform transfer commission rules');

      await logAdminAction({
        action: 'UPDATE_TRANSFER_RATES',
        module: 'Economy',
        targetType: 'CONFIG',
        targetId: 'TRANSFER_RATES',
        reason: 'Updated transfer commission percentages',
        riskLevel: 'MEDIUM',
        status: 'SUCCESS'
      });
      showToast('Transfer commission rules saved to PostgreSQL database!');
    } catch (err) {
      showToast(`Error saving transfer rates: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleToggleTransferStatus = async () => {
    const next = !isTransferDisabled;
    setIsTransferDisabled(next);
    try {
      if (next) {
        await disableEconomyConfig('TRANSFER_RATES', 'Admin switched off transfer fee system (15-day auto return)');
        showToast('Transfer fee rules turned OFF. 15-day worldwide auto-ON timer active.');
      } else {
        await restoreEconomyConfig('TRANSFER_RATES');
        showToast('Transfer fee system manually restored to ACTIVE.');
      }
    } catch (err) {
      console.warn('API error toggling transfer:', err.message);
    }
  };

  const handleOpenEditTransfer = (t) => {
    setEditingTransfer({ ...t });
    setShowEditTransferModal(true);
  };

  const handleSaveTransferEdit = (e) => {
    e.preventDefault();
    setTransferRates(transferRates.map((t) => (t.id === editingTransfer.id ? {
      ...editingTransfer,
      currentRatePercent: Number(editingTransfer.currentRatePercent),
      proposedRatePercent: Number(editingTransfer.proposedRatePercent)
    } : t)));
    setShowEditTransferModal(false);
    showToast(`Transfer commission "${editingTransfer.name}" updated!`);
  };

  const handleDeleteTransfer = (id, name) => {
    if (window.confirm(`Delete transfer rule "${name}"?`)) {
      setTransferRates(transferRates.filter((t) => t.id !== id));
      showToast(`Removed transfer rule "${name}".`);
    }
  };

  // -------------------------------------------------------------
  // Live Host Tiers Handlers
  // -------------------------------------------------------------
  const handleSaveLiveHostTiers = async () => {
    setIsSaving(true);
    try {
      await updateEconomyConfig('LIVE_HOST_TIERS', {
        version: 'v3.0.0',
        minDailyHours: 1.0,
        minDaysPerMonth: 10,
        tiers: liveHostTiers,
        updatedAt: new Date().toISOString()
      }, 'Updated Live Stream Host Tier Matrix');

      await logAdminAction({
        action: 'UPDATE_LIVE_HOST_POLICY',
        module: 'Economy',
        targetType: 'POLICY',
        targetId: 'LIVE_HOST',
        reason: 'Updated Live Creator diamond targets & basic salaries',
        riskLevel: 'HIGH',
        status: 'SUCCESS'
      });
      showToast('Live Host Tiers successfully published to PostgreSQL database & HostLevelConfig!');
    } catch (err) {
      showToast(`Error saving live host tiers: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleOpenAddLiveHost = () => {
    setIsEditingLiveHost(false);
    const nextLevel = liveHostTiers.length > 0 ? Math.max(...liveHostTiers.map((t) => t.level)) + 1 : 1;
    setLiveHostForm({
      level: nextLevel,
      targetDiamonds: 50000 * nextLevel,
      durationDays: 10,
      basicSalaryUSD: 5.0 * nextLevel,
      dailyHoursRequired: 1.0
    });
    setShowLiveHostModal(true);
  };

  const handleOpenEditLiveHost = (tier) => {
    setIsEditingLiveHost(true);
    setLiveHostForm({ ...tier });
    setShowLiveHostModal(true);
  };

  const handleSaveLiveHostSubmit = (e) => {
    e.preventDefault();
    const formatted = {
      level: Number(liveHostForm.level),
      targetDiamonds: Number(liveHostForm.targetDiamonds),
      durationDays: Number(liveHostForm.durationDays),
      basicSalaryUSD: Number(liveHostForm.basicSalaryUSD),
      dailyHoursRequired: Number(liveHostForm.dailyHoursRequired || 1.0)
    };

    if (isEditingLiveHost) {
      setLiveHostTiers(liveHostTiers.map((t) => (t.level === formatted.level ? formatted : t)));
      showToast(`Updated Level ${formatted.level} tier.`);
    } else {
      const exists = liveHostTiers.some((t) => t.level === formatted.level);
      if (exists) {
        alert(`Level ${formatted.level} already exists in the matrix. Please edit the existing tier or change the level number.`);
        return;
      }
      setLiveHostTiers([...liveHostTiers, formatted].sort((a, b) => a.level - b.level));
      showToast(`Added Level ${formatted.level} to live host matrix.`);
    }
    setShowLiveHostModal(false);
  };

  const handleDeleteLiveHostTier = (level) => {
    if (window.confirm(`Delete Level ${level} from Live Host Tier Matrix?`)) {
      setLiveHostTiers(liveHostTiers.filter((t) => t.level !== level));
      showToast(`Removed Level ${level}. Click "Publish Host Tiers" to save.`);
    }
  };

  // -------------------------------------------------------------
  // Audio Host Tiers Handlers (NEW!)
  // -------------------------------------------------------------
  const handleSaveAudioHostTiers = async () => {
    setIsSaving(true);
    try {
      await updateEconomyConfig('AUDIO_HOST_TIERS', {
        version: 'v3.0.0',
        minDailyHours: 2.0,
        tiers: audioHostTiers,
        updatedAt: new Date().toISOString()
      }, 'Updated Social Audio Party Host Rewards & Commission Policy');

      await logAdminAction({
        action: 'UPDATE_AUDIO_HOST_POLICY',
        module: 'Economy',
        targetType: 'POLICY',
        targetId: 'AUDIO_HOST',
        reason: 'Updated Audio Room Host daily rewards & agency profit splits',
        riskLevel: 'HIGH',
        status: 'SUCCESS'
      });
      showToast('Audio Host Tiers successfully published to PostgreSQL database & HostLevelConfig!');
    } catch (err) {
      showToast(`Error saving audio host tiers: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleOpenAddAudioHost = () => {
    setIsEditingAudioHost(false);
    const nextLevel = audioHostTiers.length > 0 ? Math.max(...audioHostTiers.map((t) => t.level || 1)) + 1 : 1;
    setAudioHostForm({
      level: nextLevel,
      tierName: `${nextLevel * 50}K Audio Tier`,
      targetCoins: nextLevel * 50000,
      dailyRewardUSD: nextLevel * 1.50,
      agencyProfitUSD: nextLevel * 0.30,
      minDailyHours: 2.0,
      durationDays: 10
    });
    setShowAudioHostModal(true);
  };

  const handleOpenEditAudioHost = (tier) => {
    setIsEditingAudioHost(true);
    setAudioHostForm({ ...tier });
    setShowAudioHostModal(true);
  };

  const handleSaveAudioHostSubmit = (e) => {
    e.preventDefault();
    const formatted = {
      level: Number(audioHostForm.level || 1),
      tierName: audioHostForm.tierName,
      targetCoins: Number(audioHostForm.targetCoins),
      dailyRewardUSD: Number(audioHostForm.dailyRewardUSD),
      agencyProfitUSD: Number(audioHostForm.agencyProfitUSD),
      minDailyHours: Number(audioHostForm.minDailyHours || 2.0),
      durationDays: Number(audioHostForm.durationDays || 10)
    };

    if (isEditingAudioHost) {
      setAudioHostTiers(audioHostTiers.map((t) => (t.level === formatted.level || t.tierName === formatted.tierName ? formatted : t)));
      showToast(`Updated audio host tier "${formatted.tierName}".`);
    } else {
      setAudioHostTiers([...audioHostTiers, formatted].sort((a, b) => a.level - b.level));
      showToast(`Added audio host tier "${formatted.tierName}".`);
    }
    setShowAudioHostModal(false);
  };

  const handleDeleteAudioHostTier = (tierName) => {
    if (window.confirm(`Delete audio tier "${tierName}"?`)) {
      setAudioHostTiers(audioHostTiers.filter((t) => t.tierName !== tierName));
      showToast(`Removed audio tier "${tierName}". Click "Publish Audio Tiers" to save.`);
    }
  };

  // -------------------------------------------------------------
  // Reseller Packages Handlers
  // -------------------------------------------------------------
  const handleSaveResellerPackages = async () => {
    setIsSaving(true);
    try {
      await updateEconomyConfig('RESELLER_PACKAGES', {
        packages: resellerPackages,
        updatedAt: new Date().toISOString()
      }, 'Updated authorized coin reseller pricing catalog & profit margins');

      await logAdminAction({
        action: 'UPDATE_RESELLER_POLICY',
        module: 'Economy',
        targetType: 'POLICY',
        targetId: 'RESELLER',
        reason: 'Updated Reseller pricing catalog & margins',
        riskLevel: 'MEDIUM',
        status: 'SUCCESS'
      });
      showToast('Reseller pricing tiers successfully saved to PostgreSQL database!');
    } catch (err) {
      showToast(`Error saving reseller packages: ${err.message}`);
    } finally {
      setIsSaving(false);
    }
  };

  const handleOpenAddReseller = () => {
    setIsEditingReseller(false);
    setResellerForm({
      id: `res-${Date.now().toString().slice(-4)}`,
      tierName: '',
      priceUSD: 100,
      totalCoins: 1100000,
      bonusCoins: 100000,
      profitPercent: 10
    });
    setShowResellerModal(true);
  };

  const handleOpenEditReseller = (pkg) => {
    setIsEditingReseller(true);
    setResellerForm({ ...pkg });
    setShowResellerModal(true);
  };

  const handleSaveResellerSubmit = (e) => {
    e.preventDefault();
    const formatted = {
      id: resellerForm.id || `res-${Date.now().toString().slice(-4)}`,
      tierName: resellerForm.tierName,
      priceUSD: Number(resellerForm.priceUSD),
      totalCoins: Number(resellerForm.totalCoins),
      bonusCoins: Number(resellerForm.bonusCoins || 0),
      profitPercent: Number(resellerForm.profitPercent)
    };

    if (isEditingReseller) {
      setResellerPackages(resellerPackages.map((p) => (p.id === formatted.id || p.tierName === formatted.tierName ? formatted : p)));
      showToast(`Updated reseller tier "${formatted.tierName}".`);
    } else {
      setResellerPackages([...resellerPackages, formatted]);
      showToast(`Added reseller tier "${formatted.tierName}".`);
    }
    setShowResellerModal(false);
  };

  const handleDeleteResellerPackage = (id, name) => {
    if (window.confirm(`Delete reseller package "${name}"?`)) {
      setResellerPackages(resellerPackages.filter((p) => p.id !== id && p.tierName !== name));
      showToast(`Removed reseller package "${name}".`);
    }
  };

  // -------------------------------------------------------------
  // Financial Simulation Math
  // -------------------------------------------------------------
  const val = Number(simAmount || 0);
  const pShare = Number(economyPolicy.platformShare) || 45;
  const hShare = Number(economyPolicy.hostShare) || 35;
  const aShare = Number(economyPolicy.agencyShare) || 12;
  const rShare = Number(economyPolicy.roomReward) || 8;

  const simResults = {
    platformCut: val * (pShare / 100),
    hostShare: val * (hShare / 100),
    agencyShare: val * (aShare / 100),
    roomReward: val * (rShare / 100),
    gatewayFee: val * 0.029 + (val > 0 ? 0.30 : 0)
  };

  return (
    <div className="flex flex-col gap-6 text-slate-100">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Sliders className="h-7 w-7 text-gold-400" />
            Economy & Policy Settings Engine
          </h1>
          <p className="text-xs text-slate-400 mt-0.5">
            Master control suite for platform revenue splits, currency exchange rates, transfer fees, live & audio host tiers, and reseller margins.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="success">DB Status: ONLINE</Badge>
          <Badge variant="purple">v3.0.0 Multi-Tier Engine</Badge>
        </div>
      </div>

      {feedback && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-300 text-xs font-semibold flex items-center gap-2 animate-pulse">
          <CheckCircle2 className="h-4 w-4 text-emerald-400" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Navigation Tabs */}
      <div className="flex flex-wrap gap-2 border-b border-slate-800 pb-3">
        {[
          { id: 'general', label: '📊 Platform Revenue Split', icon: Sliders },
          { id: 'exchange_rates', label: '💱 Exchange Rates Control', icon: ArrowRightLeft },
          { id: 'transfer_rates', label: '💸 Transfer Rates & Fees', icon: DollarSign },
          { id: 'live_host', label: '📹 Live Stream Host Tiers', icon: Video },
          { id: 'audio_host', label: '🎙️ Audio Party Host Tiers', icon: Mic },
          { id: 'reseller', label: '🛍️ Resellers Catalog', icon: Layers },
          { id: 'simulator', label: '🧮 Financial Simulator', icon: BarChart3 }
        ].map((tab) => {
          const Icon = tab.icon;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 px-3.5 py-2 text-xs font-bold rounded-lg border transition-all ${
                activeTab === tab.id
                  ? 'bg-gold-500/20 border-gold-500/50 text-gold-400 shadow-lg'
                  : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white hover:bg-slate-800'
              }`}
            >
              <Icon className="h-3.5 w-3.5" />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* TAB 1: GENERAL PLATFORM ECONOMY POLICY */}
      {activeTab === 'general' && (
        <div className="space-y-6">
          <Card className="p-5 space-y-5">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-slate-800 pb-4">
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <Sliders className="h-5 w-5 text-gold-400" /> Global Platform Revenue Allocation Rules
                </h3>
                <p className="text-xs text-slate-400">
                  Configure default percentage shares applied to stream gifts, audio party volume, and platform activity.
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Button variant="primary" size="sm" onClick={handleSaveRevenuePolicy} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-1" /> {isSaving ? 'Saving...' : 'Publish Revenue Policy'}
                </Button>
              </div>
            </div>

            {/* Split Visual Progress Bar */}
            <div className="space-y-2 bg-slate-950/60 p-4 rounded-xl border border-slate-800/80">
              <div className="flex justify-between text-xs font-semibold">
                <span className="text-slate-300">Revenue Split Allocation Breakdown:</span>
                <span className={totalRevenueSplit === 100 ? 'text-emerald-400 font-mono' : 'text-rose-400 font-mono font-bold'}>
                  Total: {totalRevenueSplit}% {totalRevenueSplit === 100 ? '✅ Balanced' : '⚠️ Must Equal 100%'}
                </span>
              </div>
              <div className="h-3 w-full bg-slate-800 rounded-full overflow-hidden flex">
                <div style={{ width: `${Math.min(100, Number(economyPolicy.platformShare) || 0)}%` }} className="bg-gold-500 h-full transition-all" title={`Platform Cut: ${economyPolicy.platformShare}%`} />
                <div style={{ width: `${Math.min(100, Number(economyPolicy.hostShare) || 0)}%` }} className="bg-purple-500 h-full transition-all" title={`Host Split: ${economyPolicy.hostShare}%`} />
                <div style={{ width: `${Math.min(100, Number(economyPolicy.agencyShare) || 0)}%` }} className="bg-emerald-500 h-full transition-all" title={`Agency Bonus: ${economyPolicy.agencyShare}%`} />
                <div style={{ width: `${Math.min(100, Number(economyPolicy.roomReward) || 0)}%` }} className="bg-sky-500 h-full transition-all" title={`Room Incentive: ${economyPolicy.roomReward}%`} />
              </div>
              <div className="flex flex-wrap gap-4 text-[11px] pt-1">
                <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-gold-500" /> Platform ({economyPolicy.platformShare}%)</span>
                <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-purple-500" /> Host Creators ({economyPolicy.hostShare}%)</span>
                <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-emerald-500" /> Agency Partners ({economyPolicy.agencyShare}%)</span>
                <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-sky-500" /> Party Rooms ({economyPolicy.roomReward}%)</span>
              </div>
            </div>

            {/* Quick Presets */}
            <div className="flex flex-wrap items-center gap-2 text-xs">
              <span className="text-slate-400 font-medium mr-1">Quick Presets:</span>
              <button
                onClick={() => applyPresetSplit(45, 35, 12, 8)}
                className="px-2.5 py-1 rounded-md bg-slate-900 border border-slate-700 hover:border-gold-500 text-slate-300 hover:text-white transition-all text-xs"
              >
                Standard (45 / 35 / 12 / 8)
              </button>
              <button
                onClick={() => applyPresetSplit(35, 45, 12, 8)}
                className="px-2.5 py-1 rounded-md bg-slate-900 border border-slate-700 hover:border-purple-500 text-slate-300 hover:text-white transition-all text-xs"
              >
                Creator Boost (35 / 45 / 12 / 8)
              </button>
              <button
                onClick={() => applyPresetSplit(40, 30, 20, 10)}
                className="px-2.5 py-1 rounded-md bg-slate-900 border border-slate-700 hover:border-emerald-500 text-slate-300 hover:text-white transition-all text-xs"
              >
                Agency Growth (40 / 30 / 20 / 10)
              </button>
            </div>

            {/* Editable Revenue Allocation Inputs */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              {/* Platform Retention */}
              <div className="p-4 rounded-xl bg-slate-900/90 border border-slate-800 space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-gold-400 uppercase tracking-wider">Platform Cut</span>
                  <Badge variant="success">Active</Badge>
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] text-slate-400">Platform Retention Share (%)</label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="number"
                      step="0.5"
                      min="0"
                      max="100"
                      value={economyPolicy.platformShare}
                      onChange={(e) => setEconomyPolicy({ ...economyPolicy, platformShare: Number(e.target.value) })}
                      className="font-mono text-gold-400 font-bold"
                    />
                    <span className="text-xs font-bold text-slate-400">%</span>
                  </div>
                </div>
                <p className="text-[11px] text-slate-500">Net platform revenue retained from virtual gift transactions.</p>
              </div>

              {/* Host Split */}
              <div className="p-4 rounded-xl bg-slate-900/90 border border-slate-800 space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-purple-400 uppercase tracking-wider">Host Creators</span>
                  <Badge variant="purple">Streamers</Badge>
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] text-slate-400">Host Payout Allocation (%)</label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="number"
                      step="0.5"
                      min="0"
                      max="100"
                      value={economyPolicy.hostShare}
                      onChange={(e) => setEconomyPolicy({ ...economyPolicy, hostShare: Number(e.target.value) })}
                      className="font-mono text-purple-400 font-bold"
                    />
                    <span className="text-xs font-bold text-slate-400">%</span>
                  </div>
                </div>
                <p className="text-[11px] text-slate-500">Portion allocated to streamer diamond cashout balance.</p>
              </div>

              {/* Agency Bonus */}
              <div className="p-4 rounded-xl bg-slate-900/90 border border-slate-800 space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-emerald-400 uppercase tracking-wider">Agency Syndicate</span>
                  <Badge variant="success">Partners</Badge>
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] text-slate-400">Agency Commission Bonus (%)</label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="number"
                      step="0.5"
                      min="0"
                      max="100"
                      value={economyPolicy.agencyShare}
                      onChange={(e) => setEconomyPolicy({ ...economyPolicy, agencyShare: Number(e.target.value) })}
                      className="font-mono text-emerald-400 font-bold"
                    />
                    <span className="text-xs font-bold text-slate-400">%</span>
                  </div>
                </div>
                <p className="text-[11px] text-slate-500">Commission credited to managing agency syndicate.</p>
              </div>

              {/* Room Owner Reward */}
              <div className="p-4 rounded-xl bg-slate-900/90 border border-slate-800 space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-bold text-sky-400 uppercase tracking-wider">Room Owners</span>
                  <Badge variant="info">Party Rooms</Badge>
                </div>
                <div className="space-y-1">
                  <label className="text-[11px] text-slate-400">Party Room Reward (%)</label>
                  <div className="flex items-center gap-2">
                    <Input
                      type="number"
                      step="0.5"
                      min="0"
                      max="100"
                      value={economyPolicy.roomReward}
                      onChange={(e) => setEconomyPolicy({ ...economyPolicy, roomReward: Number(e.target.value) })}
                      className="font-mono text-sky-400 font-bold"
                    />
                    <span className="text-xs font-bold text-slate-400">%</span>
                  </div>
                </div>
                <p className="text-[11px] text-slate-500">Reward credited to the host or room owner where gift was sent.</p>
              </div>
            </div>
          </Card>

          {/* Regional Country Overrides Table */}
          <Card className="p-5 space-y-4">
            <div className="flex justify-between items-center border-b border-slate-800 pb-3">
              <div>
                <h4 className="text-sm font-bold text-white flex items-center gap-2">
                  <ShieldCheck className="h-4 w-4 text-gold-400" /> Regional Country Overrides
                </h4>
                <p className="text-xs text-slate-400">Localized split adjustments override global defaults for compliance, market expansion, or local tax requirements.</p>
              </div>
              <Button variant="outline" size="sm" onClick={handleOpenAddOverride}>
                <Plus className="h-4 w-4 mr-1 text-gold-400" /> Add Country Override
              </Button>
            </div>

            <div className="overflow-x-auto border border-slate-800 rounded-xl">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-slate-400 border-b border-slate-800">
                  <tr>
                    <th className="p-3">Country / Region</th>
                    <th className="p-3">Platform Cut</th>
                    <th className="p-3">Host Split</th>
                    <th className="p-3">Agency Bonus</th>
                    <th className="p-3">Room Incentive</th>
                    <th className="p-3">Status</th>
                    <th className="p-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800 text-slate-300">
                  {countryOverrides.map((r, i) => (
                    <tr key={r.id || i} className="hover:bg-slate-900/50">
                      <td className="p-3 font-bold text-white">{r.country}</td>
                      <td className="p-3 font-mono text-gold-400">{r.platform}%</td>
                      <td className="p-3 font-mono text-purple-400">{r.host}%</td>
                      <td className="p-3 font-mono text-emerald-400">{r.agency}%</td>
                      <td className="p-3 font-mono text-sky-400">{r.room}%</td>
                      <td className="p-3">
                        <Badge variant={r.status === 'DEFAULT' ? 'purple' : 'success'}>{r.status}</Badge>
                      </td>
                      <td className="p-3 text-right space-x-1">
                        <Button variant="outline" size="xs" onClick={() => handleOpenEditOverride(r)}>
                          <Edit2 className="h-3 w-3 mr-1" /> Edit
                        </Button>
                        <Button variant="outline" size="xs" onClick={() => handleDeleteOverride(r.country)} className="text-rose-400 hover:text-rose-300">
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {/* TAB 2: EXCHANGE RATES CONTROL */}
      {activeTab === 'exchange_rates' && (
        <div className="space-y-4">
          <Card className="p-5 space-y-4">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-slate-800 pb-3">
              <div>
                <h2 className="text-sm font-bold text-white flex items-center gap-2">
                  <ArrowRightLeft className="h-4 w-4 text-gold-400" /> Admin-Controlled Currency Exchange Rates
                </h2>
                <p className="text-xs text-slate-400 mt-0.5">Enforced server-side for real-time wallet conversions. Turning OFF starts a 15-day worldwide auto-return countdown.</p>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={handleToggleExchangeStatus}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-colors ${
                    isExchangeDisabled
                      ? 'bg-rose-500/20 text-rose-400 border-rose-500/40'
                      : 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40'
                  }`}
                >
                  {isExchangeDisabled ? '🛑 Exchange OFF (15-Day Auto Return)' : '✅ Exchange System ACTIVE'}
                </button>
                <Button variant="outline" size="sm" onClick={() => setShowDraftModal(true)}>
                  <Plus className="h-4 w-4 mr-1 text-gold-400" /> Create Rate Draft
                </Button>
                <Button variant="primary" size="sm" onClick={handleSaveExchangeRates} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-1" /> {isSaving ? 'Saving...' : 'Publish Exchange Rates'}
                </Button>
              </div>
            </div>

            <div className="overflow-x-auto border border-slate-800 rounded-xl">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-slate-400 border-b border-slate-800">
                  <tr>
                    <th className="p-3">Rate Configuration</th>
                    <th className="p-3">Currency</th>
                    <th className="p-3">Active Rate</th>
                    <th className="p-3">Proposed Rate</th>
                    <th className="p-3">Status</th>
                    <th className="p-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800 text-slate-300">
                  {exchangeRates.map((r) => (
                    <tr key={r.id} className="hover:bg-slate-900/40">
                      <td className="p-3">
                        <p className="font-bold text-white">{r.name}</p>
                        <p className="text-[10px] text-slate-400 font-mono">{r.unit}</p>
                      </td>
                      <td className="p-3 font-mono text-purple-300">{r.currency} ({r.country})</td>
                      <td className="p-3 font-mono text-gold-400 font-bold">{formatNumber(r.currentRate)}</td>
                      <td className="p-3 font-mono text-emerald-400 font-bold">{formatNumber(r.proposedRate)}</td>
                      <td className="p-3">
                        <Badge variant={r.status === 'ACTIVE' ? 'success' : 'warning'}>{r.status}</Badge>
                      </td>
                      <td className="p-3 text-right space-x-1">
                        <Button variant="outline" size="xs" onClick={() => handleOpenEditRate(r)}>
                          <Edit2 className="h-3 w-3 mr-1" /> Edit
                        </Button>
                        <Button variant="outline" size="xs" onClick={() => setPreviewModal(r)}>
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="outline" size="xs" onClick={() => handleDeleteRate(r.id, r.name)} className="text-rose-400 hover:text-rose-300">
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {/* TAB 3: TRANSFER RATES & FEES */}
      {activeTab === 'transfer_rates' && (
        <div className="space-y-4">
          <Card className="p-5 space-y-4">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-slate-800 pb-3">
              <div>
                <h2 className="text-sm font-bold text-white flex items-center gap-2">
                  <DollarSign className="h-4 w-4 text-emerald-400" /> Platform Transfer Commission Rates & Fees
                </h2>
                <p className="text-xs text-slate-400 mt-0.5">Commission percentages applied to reseller transfers, merchant coin allocations, and host payouts.</p>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={handleToggleTransferStatus}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-colors ${
                    isTransferDisabled
                      ? 'bg-rose-500/20 text-rose-400 border-rose-500/40'
                      : 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40'
                  }`}
                >
                  {isTransferDisabled ? '🛑 Transfer System OFF (15-Day Auto Return)' : '✅ Transfer System ACTIVE'}
                </button>
                <Button variant="primary" size="sm" onClick={handleSaveTransferRates} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-1" /> {isSaving ? 'Saving...' : 'Publish Transfer Rates'}
                </Button>
              </div>
            </div>

            <div className="overflow-x-auto border border-slate-800 rounded-xl">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-slate-400 border-b border-slate-800">
                  <tr>
                    <th className="p-3">Transfer Type</th>
                    <th className="p-3">Description</th>
                    <th className="p-3">Current Fee %</th>
                    <th className="p-3">Proposed Fee %</th>
                    <th className="p-3">Status</th>
                    <th className="p-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800 text-slate-300">
                  {transferRates.map((t) => (
                    <tr key={t.id} className="hover:bg-slate-900/40">
                      <td className="p-3 font-bold text-white">{t.name}</td>
                      <td className="p-3 text-slate-400">{t.description}</td>
                      <td className="p-3 font-mono text-emerald-400 font-bold">{t.currentRatePercent}%</td>
                      <td className="p-3 font-mono text-gold-400 font-bold">{t.proposedRatePercent || t.currentRatePercent}%</td>
                      <td className="p-3">
                        <Badge variant="success">{t.status}</Badge>
                      </td>
                      <td className="p-3 text-right space-x-1">
                        <Button variant="outline" size="xs" onClick={() => handleOpenEditTransfer(t)}>
                          <Edit2 className="h-3 w-3 mr-1" /> Edit
                        </Button>
                        <Button variant="outline" size="xs" onClick={() => setPreviewModal({ name: t.name, currentRate: t.currentRatePercent, proposedRate: t.proposedRatePercent || t.currentRatePercent })}>
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                        <Button variant="outline" size="xs" onClick={() => handleDeleteTransfer(t.id, t.name)} className="text-rose-400 hover:text-rose-300">
                          <Trash2 className="h-3 w-3" />
                        </Button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {/* TAB 4: LIVE HOST TIERS */}
      {activeTab === 'live_host' && (
        <Card className="p-5 space-y-4">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-slate-800 pb-3">
            <div>
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <Video className="h-4 w-4 text-purple-400" /> Live Stream Creator Host Tier Matrix
              </h2>
              <p className="text-xs text-slate-400 mt-0.5">Configured diamond targets and 15-day base salaries for video streamers.</p>
            </div>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={handleOpenAddLiveHost}>
                <Plus className="h-4 w-4 mr-1 text-gold-400" /> Add Live Tier
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveLiveHostTiers} disabled={isSaving}>
                <Save className="h-4 w-4 mr-1" /> {isSaving ? 'Saving...' : 'Publish Host Tiers'}
              </Button>
            </div>
          </div>

          <div className="overflow-x-auto border border-slate-800 rounded-xl">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-900 text-slate-400 border-b border-slate-800">
                <tr>
                  <th className="p-3">Level</th>
                  <th className="p-3">Diamond Target (15d)</th>
                  <th className="p-3">Stream Days Required</th>
                  <th className="p-3">Min Daily Hours</th>
                  <th className="p-3">Base Salary ($ USD)</th>
                  <th className="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 text-slate-300">
                {liveHostTiers.map((t) => (
                  <tr key={t.level} className="hover:bg-slate-900/40">
                    <td className="p-3 font-bold font-mono text-purple-400">Level {t.level}</td>
                    <td className="p-3 font-mono text-gold-400 font-bold">{formatNumber(t.targetDiamonds)} 💎</td>
                    <td className="p-3">{t.durationDays} Days</td>
                    <td className="p-3 font-mono text-slate-400">{t.dailyHoursRequired || 1.0} hr/day</td>
                    <td className="p-3 font-mono text-emerald-400 font-bold">${t.basicSalaryUSD.toFixed(2)} USD</td>
                    <td className="p-3 text-right space-x-1">
                      <Button variant="outline" size="xs" onClick={() => handleOpenEditLiveHost(t)}>
                        <Edit2 className="h-3 w-3 mr-1" /> Edit
                      </Button>
                      <Button variant="outline" size="xs" onClick={() => handleDeleteLiveHostTier(t.level)} className="text-rose-400 hover:text-rose-300">
                        <Trash2 className="h-3 w-3" />
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* TAB 5: AUDIO HOST TIERS (NEW DEDICATED OPTION) */}
      {activeTab === 'audio_host' && (
        <div className="space-y-4">
          <Card className="p-5 space-y-4">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-slate-800 pb-3">
              <div>
                <h2 className="text-sm font-bold text-white flex items-center gap-2">
                  <Mic className="h-4 w-4 text-emerald-400" /> Social Audio Party Host Rewards & Commission Policy
                </h2>
                <p className="text-xs text-slate-400 mt-0.5">
                  Multi-tier commission and daily cash reward matrix for social audio room creators, mic speakers, and audio agencies.
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Button variant="outline" size="sm" onClick={handleOpenAddAudioHost}>
                  <Plus className="h-4 w-4 mr-1 text-gold-400" /> Add Audio Tier
                </Button>
                <Button variant="primary" size="sm" onClick={handleSaveAudioHostTiers} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-1" /> {isSaving ? 'Saving...' : 'Publish Audio Tiers'}
                </Button>
              </div>
            </div>

            {/* Quick Metrics */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800">
                <p className="text-xs text-slate-400">Total Configured Audio Tiers</p>
                <p className="text-xl font-bold text-white font-mono mt-0.5">{audioHostTiers.length} Active Tiers</p>
              </div>
              <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800">
                <p className="text-xs text-slate-400">Max Daily Host Payout</p>
                <p className="text-xl font-bold text-emerald-400 font-mono mt-0.5">
                  ${Math.max(...audioHostTiers.map((t) => t.dailyRewardUSD || 0), 0).toFixed(2)} USD / day
                </p>
              </div>
              <div className="p-3.5 rounded-xl bg-slate-900 border border-slate-800">
                <p className="text-xs text-slate-400">Standard Min Audio Requirement</p>
                <p className="text-xl font-bold text-gold-400 font-mono mt-0.5">2.0 Hours / Day</p>
              </div>
            </div>

            {/* Audio Host Table */}
            <div className="overflow-x-auto border border-slate-800 rounded-xl">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-slate-400 border-b border-slate-800">
                  <tr>
                    <th className="p-3">Level / Tier Name</th>
                    <th className="p-3">Target Coins / Diamonds</th>
                    <th className="p-3">Daily Host Reward ($ USD)</th>
                    <th className="p-3">Agency Profit ($ USD)</th>
                    <th className="p-3">Total Daily Payout</th>
                    <th className="p-3">Required Hours</th>
                    <th className="p-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800 text-slate-300">
                  {audioHostTiers.map((t, idx) => {
                    const totalDaily = (Number(t.dailyRewardUSD) || 0) + (Number(t.agencyProfitUSD) || 0);
                    return (
                      <tr key={t.tierName || idx} className="hover:bg-slate-900/40">
                        <td className="p-3 font-bold text-white flex items-center gap-2">
                          <span className="w-6 h-6 rounded-full bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 flex items-center justify-center font-mono text-[10px]">
                            {t.level || idx + 1}
                          </span>
                          <span>{t.tierName}</span>
                        </td>
                        <td className="p-3 font-mono text-gold-400 font-bold">{formatNumber(t.targetCoins || t.targetDiamonds)} 🪙</td>
                        <td className="p-3 font-mono text-emerald-400 font-bold">${Number(t.dailyRewardUSD).toFixed(2)} USD</td>
                        <td className="p-3 font-mono text-purple-400 font-bold">${Number(t.agencyProfitUSD).toFixed(2)} USD</td>
                        <td className="p-3 font-mono text-white font-bold">${totalDaily.toFixed(2)} USD</td>
                        <td className="p-3 font-mono text-slate-400">{t.minDailyHours || 2.0} hrs/day ({t.durationDays || 10}d)</td>
                        <td className="p-3 text-right space-x-1">
                          <Button variant="outline" size="xs" onClick={() => handleOpenEditAudioHost(t)}>
                            <Edit2 className="h-3 w-3 mr-1" /> Edit
                          </Button>
                          <Button variant="outline" size="xs" onClick={() => handleDeleteAudioHostTier(t.tierName)} className="text-rose-400 hover:text-rose-300">
                            <Trash2 className="h-3 w-3" />
                          </Button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {/* TAB 6: RESELLER PACKAGES */}
      {activeTab === 'reseller' && (
        <Card className="p-5 space-y-4">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-slate-800 pb-3">
            <div>
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <Layers className="h-4 w-4 text-gold-400" /> Authorized Coin Reseller Pricing Tiers & Margins
              </h2>
              <p className="text-xs text-slate-400 mt-0.5">Bulk coin purchase packages, merchant wholesale prices, and distributor profit margins.</p>
            </div>
            <div className="flex items-center gap-2">
              <Button variant="outline" size="sm" onClick={handleOpenAddReseller}>
                <Plus className="h-4 w-4 mr-1 text-gold-400" /> Add Package
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveResellerPackages} disabled={isSaving}>
                <Save className="h-4 w-4 mr-1" /> {isSaving ? 'Saving...' : 'Save Reseller Tiers'}
              </Button>
            </div>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            {resellerPackages.map((pkg, idx) => (
              <div key={pkg.id || idx} className="p-4 rounded-xl bg-slate-900 border border-slate-800 space-y-3 relative group">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="font-bold text-white text-sm">{pkg.tierName}</p>
                    <p className="text-[11px] text-slate-400 font-mono">Wholesale Package #{idx + 1}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant="purple">{pkg.profitPercent}% Margin</Badge>
                    <button
                      onClick={() => handleOpenEditReseller(pkg)}
                      className="p-1 rounded bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white"
                      title="Edit package"
                    >
                      <Edit2 className="h-3.5 w-3.5" />
                    </button>
                    <button
                      onClick={() => handleDeleteResellerPackage(pkg.id, pkg.tierName)}
                      className="p-1 rounded bg-slate-800 hover:bg-rose-900/50 text-slate-400 hover:text-rose-400"
                      title="Delete package"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </button>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2 pt-1 border-t border-slate-800/60 text-xs font-mono">
                  <div>
                    <span className="text-slate-500 text-[10px] block">Price (USD)</span>
                    <span className="text-white font-bold text-sm">${pkg.priceUSD} USD</span>
                  </div>
                  <div>
                    <span className="text-slate-500 text-[10px] block">Total Coins</span>
                    <span className="text-gold-400 font-bold text-sm">{formatNumber(pkg.totalCoins)}</span>
                  </div>
                </div>

                {pkg.bonusCoins > 0 && (
                  <div className="text-[11px] text-emerald-400 font-mono flex items-center gap-1 bg-emerald-950/30 p-2 rounded-lg border border-emerald-900/40">
                    <Sparkles className="h-3.5 w-3.5" />
                    <span>Includes +{formatNumber(pkg.bonusCoins)} bonus coins</span>
                  </div>
                )}
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* TAB 7: FINANCIAL SIMULATOR */}
      {activeTab === 'simulator' && (
        <Card className="p-5 space-y-4">
          <div className="flex justify-between items-center border-b border-slate-800 pb-3">
            <div>
              <h2 className="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-2">
                <BarChart3 className="h-4 w-4 text-gold-400" /> Real-Time Financial Simulation Calculator
              </h2>
              <p className="text-xs text-slate-400 mt-0.5">Simulate how revenue splits perform based on current live settings.</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setSimMode('live')}
                className={`px-3 py-1 text-xs font-bold rounded-lg border ${simMode === 'live' ? 'bg-gold-500/20 text-gold-400 border-gold-500/40' : 'bg-slate-900 text-slate-400 border-slate-800'}`}
              >
                📹 Live Stream
              </button>
              <button
                onClick={() => setSimMode('audio')}
                className={`px-3 py-1 text-xs font-bold rounded-lg border ${simMode === 'audio' ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/40' : 'bg-slate-900 text-slate-400 border-slate-800'}`}
              >
                🎙️ Audio Party Room
              </button>
            </div>
          </div>

          <div className="max-w-xs space-y-1">
            <label className="text-xs text-slate-400 font-medium">Test Gift Transaction Volume ($ USD)</label>
            <div className="flex items-center gap-2">
              <Input
                type="number"
                value={simAmount}
                onChange={(e) => setSimAmount(e.target.value)}
                placeholder="E.g., 100"
                className="font-mono text-gold-400 font-bold"
              />
              <span className="text-xs font-bold text-slate-400">USD</span>
            </div>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 pt-2">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
              <p className="text-xs text-slate-400">Platform Retention ({pShare}%)</p>
              <p className="text-xl font-bold text-gold-400 font-mono mt-1">${simResults.platformCut.toFixed(2)} USD</p>
              <p className="text-[10px] text-slate-500 mt-1">Net gross margin</p>
            </div>
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
              <p className="text-xs text-slate-400">Host Stream Payout ({hShare}%)</p>
              <p className="text-xl font-bold text-purple-400 font-mono mt-1">${simResults.hostShare.toFixed(2)} USD</p>
              <p className="text-[10px] text-slate-500 mt-1">{formatNumber(simResults.hostShare * 10000)} Diamonds</p>
            </div>
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
              <p className="text-xs text-slate-400">Agency Syndicate ({aShare}%)</p>
              <p className="text-xl font-bold text-emerald-400 font-mono mt-1">${simResults.agencyShare.toFixed(2)} USD</p>
              <p className="text-[10px] text-slate-500 mt-1">Agency recruitment share</p>
            </div>
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800">
              <p className="text-xs text-slate-400">Room Owner Reward ({rShare}%)</p>
              <p className="text-xl font-bold text-sky-400 font-mono mt-1">${simResults.roomReward.toFixed(2)} USD</p>
              <p className="text-[10px] text-slate-500 mt-1">Party room host incentive</p>
            </div>
          </div>

          <div className="p-3.5 rounded-xl bg-slate-950/60 border border-slate-800 text-xs text-slate-400 flex items-center justify-between">
            <span>Estimated Payment Gateway Processing Fee (2.9% + $0.30):</span>
            <span className="text-rose-400 font-mono font-bold">${simResults.gatewayFee.toFixed(2)} USD</span>
          </div>
        </Card>
      )}

      {/* ------------------------------------------------------------- */}
      {/* MODALS */}
      {/* ------------------------------------------------------------- */}

      {/* Impact Preview Modal */}
      {previewModal && (
        <Modal isOpen={true} onClose={() => setPreviewModal(null)} title={`Impact Preview: ${previewModal.name}`}>
          <div className="space-y-3 text-xs text-slate-300">
            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800 space-y-1 font-mono">
              <p><strong className="text-slate-400">Current Rate / Fee:</strong> {formatNumber(previewModal.currentRate || previewModal.currentRatePercent)}</p>
              <p><strong className="text-slate-400">Proposed Rate / Fee:</strong> <span className="text-emerald-400">{formatNumber(previewModal.proposedRate || previewModal.proposedRatePercent)}</span></p>
            </div>
            <p className="text-slate-400">Publishing this change will immediately update conversion math across all active client apps and background settlement workers.</p>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button variant="outline" size="sm" onClick={() => setPreviewModal(null)}>Cancel</Button>
              <Button variant="primary" size="sm" onClick={() => {
                showToast(`Rate change for "${previewModal.name}" validated.`);
                setPreviewModal(null);
              }}>
                Confirm
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Create Rate Draft Modal */}
      {showDraftModal && (
        <Modal isOpen={true} onClose={() => setShowDraftModal(false)} title="Create New Exchange Rate Draft">
          <form onSubmit={handleCreateDraft} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-slate-400 mb-1 block">Rate Name *</label>
              <Input value={draftForm.name} onChange={(e) => setDraftForm({ ...draftForm, name: e.target.value })} required />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Currency Code *</label>
                <Input value={draftForm.currency} onChange={(e) => setDraftForm({ ...draftForm, currency: e.target.value.toUpperCase() })} required placeholder="e.g. EUR, PKR" />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Country Code *</label>
                <Input value={draftForm.country} onChange={(e) => setDraftForm({ ...draftForm, country: e.target.value.toUpperCase() })} required placeholder="e.g. EU, PK" />
              </div>
            </div>
            <div>
              <label className="text-slate-400 mb-1 block">Proposed Rate (Coins per $1 / 1 Unit) *</label>
              <Input type="number" value={draftForm.proposedRate} onChange={(e) => setDraftForm({ ...draftForm, proposedRate: e.target.value })} required />
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowDraftModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">Create Draft</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Edit Exchange Rate Modal */}
      {showEditRateModal && editingRate && (
        <Modal isOpen={true} onClose={() => setShowEditRateModal(false)} title={`Edit Exchange Rate: ${editingRate.name}`}>
          <form onSubmit={handleSaveRateEdit} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-slate-400 mb-1 block">Rate Name *</label>
              <Input value={editingRate.name} onChange={(e) => setEditingRate({ ...editingRate, name: e.target.value })} required />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Active Rate</label>
                <Input type="number" value={editingRate.currentRate} onChange={(e) => setEditingRate({ ...editingRate, currentRate: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Proposed Rate</label>
                <Input type="number" value={editingRate.proposedRate} onChange={(e) => setEditingRate({ ...editingRate, proposedRate: e.target.value })} required />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowEditRateModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">Save Rate</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Edit Transfer Fee Modal */}
      {showEditTransferModal && editingTransfer && (
        <Modal isOpen={true} onClose={() => setShowEditTransferModal(false)} title={`Edit Transfer Rule: ${editingTransfer.name}`}>
          <form onSubmit={handleSaveTransferEdit} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-slate-400 mb-1 block">Rule Name *</label>
              <Input value={editingTransfer.name} onChange={(e) => setEditingTransfer({ ...editingTransfer, name: e.target.value })} required />
            </div>
            <div>
              <label className="text-slate-400 mb-1 block">Description</label>
              <Input value={editingTransfer.description} onChange={(e) => setEditingTransfer({ ...editingTransfer, description: e.target.value })} />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Current Fee (%)</label>
                <Input type="number" step="0.1" value={editingTransfer.currentRatePercent} onChange={(e) => setEditingTransfer({ ...editingTransfer, currentRatePercent: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Proposed Fee (%)</label>
                <Input type="number" step="0.1" value={editingTransfer.proposedRatePercent || editingTransfer.currentRatePercent} onChange={(e) => setEditingTransfer({ ...editingTransfer, proposedRatePercent: e.target.value })} />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowEditTransferModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">Save Transfer Rule</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Create / Edit Country Override Modal */}
      {showOverrideModal && (
        <Modal isOpen={true} onClose={() => setShowOverrideModal(false)} title={isEditingOverride ? 'Edit Regional Override' : 'Add Regional Economy Override'}>
          <form onSubmit={handleSaveOverrideSubmit} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-slate-400 mb-1 block">Country Name & Flag *</label>
              <Input value={overrideForm.country} onChange={(e) => setOverrideForm({ ...overrideForm, country: e.target.value })} required placeholder="e.g. 🇩🇪 Germany (DE)" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Platform Cut %</label>
                <Input type="number" step="0.5" value={overrideForm.platform} onChange={(e) => setOverrideForm({ ...overrideForm, platform: Number(e.target.value) })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Host Split %</label>
                <Input type="number" step="0.5" value={overrideForm.host} onChange={(e) => setOverrideForm({ ...overrideForm, host: Number(e.target.value) })} required />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Agency Bonus %</label>
                <Input type="number" step="0.5" value={overrideForm.agency} onChange={(e) => setOverrideForm({ ...overrideForm, agency: Number(e.target.value) })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Room Incentive %</label>
                <Input type="number" step="0.5" value={overrideForm.room} onChange={(e) => setOverrideForm({ ...overrideForm, room: Number(e.target.value) })} required />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowOverrideModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">{isEditingOverride ? 'Save Changes' : 'Add Override'}</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Create / Edit Live Host Tier Modal */}
      {showLiveHostModal && (
        <Modal isOpen={true} onClose={() => setShowLiveHostModal(false)} title={isEditingLiveHost ? `Edit Live Host Tier (Level ${liveHostForm.level})` : 'Add Live Stream Host Tier'}>
          <form onSubmit={handleSaveLiveHostSubmit} className="space-y-3 text-xs text-slate-300">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Level Number *</label>
                <Input type="number" value={liveHostForm.level} onChange={(e) => setLiveHostForm({ ...liveHostForm, level: e.target.value })} required disabled={isEditingLiveHost} />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Target Diamonds (15d) *</label>
                <Input type="number" value={liveHostForm.targetDiamonds} onChange={(e) => setLiveHostForm({ ...liveHostForm, targetDiamonds: e.target.value })} required />
              </div>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Base Salary ($ USD) *</label>
                <Input type="number" step="0.5" value={liveHostForm.basicSalaryUSD} onChange={(e) => setLiveHostForm({ ...liveHostForm, basicSalaryUSD: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Stream Days Req. *</label>
                <Input type="number" value={liveHostForm.durationDays} onChange={(e) => setLiveHostForm({ ...liveHostForm, durationDays: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Daily Hours Req.</label>
                <Input type="number" step="0.5" value={liveHostForm.dailyHoursRequired || 1.0} onChange={(e) => setLiveHostForm({ ...liveHostForm, dailyHoursRequired: e.target.value })} required />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowLiveHostModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">{isEditingLiveHost ? 'Save Tier' : 'Add Tier'}</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Create / Edit Audio Host Tier Modal (NEW!) */}
      {showAudioHostModal && (
        <Modal isOpen={true} onClose={() => setShowAudioHostModal(false)} title={isEditingAudioHost ? `Edit Audio Host Tier: ${audioHostForm.tierName}` : 'Add Social Audio Host Tier'}>
          <form onSubmit={handleSaveAudioHostSubmit} className="space-y-3 text-xs text-slate-300">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Level #</label>
                <Input type="number" value={audioHostForm.level || 1} onChange={(e) => setAudioHostForm({ ...audioHostForm, level: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Tier Display Name *</label>
                <Input value={audioHostForm.tierName} onChange={(e) => setAudioHostForm({ ...audioHostForm, tierName: e.target.value })} required placeholder="e.g. 50K Audio Tier" />
              </div>
            </div>
            <div>
              <label className="text-slate-400 mb-1 block">Target Coins / Diamonds *</label>
              <Input type="number" value={audioHostForm.targetCoins} onChange={(e) => setAudioHostForm({ ...audioHostForm, targetCoins: e.target.value })} required />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Daily Host Reward ($ USD) *</label>
                <Input type="number" step="0.05" value={audioHostForm.dailyRewardUSD} onChange={(e) => setAudioHostForm({ ...audioHostForm, dailyRewardUSD: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Agency Profit Share ($ USD) *</label>
                <Input type="number" step="0.05" value={audioHostForm.agencyProfitUSD} onChange={(e) => setAudioHostForm({ ...audioHostForm, agencyProfitUSD: e.target.value })} required />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Min Daily Audio Hours</label>
                <Input type="number" step="0.5" value={audioHostForm.minDailyHours || 2.0} onChange={(e) => setAudioHostForm({ ...audioHostForm, minDailyHours: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Required Days</label>
                <Input type="number" value={audioHostForm.durationDays || 10} onChange={(e) => setAudioHostForm({ ...audioHostForm, durationDays: e.target.value })} required />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowAudioHostModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">{isEditingAudioHost ? 'Save Audio Tier' : 'Add Audio Tier'}</Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Create / Edit Reseller Package Modal */}
      {showResellerModal && (
        <Modal isOpen={true} onClose={() => setShowResellerModal(false)} title={isEditingReseller ? `Edit Reseller Package: ${resellerForm.tierName}` : 'Add Reseller Package'}>
          <form onSubmit={handleSaveResellerSubmit} className="space-y-3 text-xs text-slate-300">
            <div>
              <label className="text-slate-400 mb-1 block">Package Name *</label>
              <Input value={resellerForm.tierName} onChange={(e) => setResellerForm({ ...resellerForm, tierName: e.target.value })} required placeholder="e.g. VIP Master Reseller Tier" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Price ($ USD) *</label>
                <Input type="number" value={resellerForm.priceUSD} onChange={(e) => setResellerForm({ ...resellerForm, priceUSD: e.target.value })} required />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Total Coins *</label>
                <Input type="number" value={resellerForm.totalCoins} onChange={(e) => setResellerForm({ ...resellerForm, totalCoins: e.target.value })} required />
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-slate-400 mb-1 block">Bonus Coins</label>
                <Input type="number" value={resellerForm.bonusCoins || 0} onChange={(e) => setResellerForm({ ...resellerForm, bonusCoins: e.target.value })} />
              </div>
              <div>
                <label className="text-slate-400 mb-1 block">Profit Margin (%)</label>
                <Input type="number" value={resellerForm.profitPercent} onChange={(e) => setResellerForm({ ...resellerForm, profitPercent: e.target.value })} required />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button type="button" variant="outline" size="sm" onClick={() => setShowResellerModal(false)}>Cancel</Button>
              <Button type="submit" variant="primary" size="sm">{isEditingReseller ? 'Save Package' : 'Add Package'}</Button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
