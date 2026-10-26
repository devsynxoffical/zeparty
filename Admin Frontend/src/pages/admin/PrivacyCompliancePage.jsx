// ============================================================
// ZeParty Admin Portal — Privacy & Compliance Page (JSX)
// NEW-58: Complete Privacy Controls Governance & Eligibility
// ============================================================

import React, { useState, useEffect } from 'react';
import {
  ShieldCheck,
  FileText,
  Lock,
  Unlock,
  Users,
  RefreshCw,
  Save,
  CheckCircle2,
  AlertCircle,
  X,
  Plus,
  EyeOff,
  UserX,
  Crown,
  Sparkles,
  Search,
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import {
  getPrivacyEligibilityPolicy,
  updatePrivacyEligibilityPolicy,
  grantIndividualPrivacyAccess,
  revokeIndividualPrivacyAccess,
} from '../../services/modules/privacyPolicy.service';

const ALL_SVIP_LEVELS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];
const ALL_NOBLE_RANKS = [
  'KNIGHT',
  'BARON',
  'VISCOUNT',
  'COUNT',
  'MARQUIS',
  'DUKE',
  'PRINCE',
  'KING',
  'EMPEROR',
  'SOVEREIGN',
];

const FEATURE_METADATA = {
  ANTI_FOLLOW: {
    label: 'Anti-Follow',
    description: 'Restricts other users from following this account unless eligible or granted.',
    icon: UserX,
  },
  FAILED_TO_FIND: {
    label: 'Failed To Find',
    description: 'Excludes user profile from public search results for other users.',
    icon: Search,
  },
  INVISIBLE_VISIT: {
    label: 'Invisible Profile Visit',
    description: 'Leaves no visitor footprint or records as a Mystery Visitor on visited profiles.',
    icon: EyeOff,
  },
  HIDE_ONLINE: {
    label: 'Hide Online Status',
    description: 'Masks active presence to OFFLINE and hides current room pointer to non-owners.',
    icon: EyeOff,
  },
  HIDE_GIFT_RECORD: {
    label: 'Hide Gift Record / Anonymous Gifting',
    description: 'Broadcasts room gifting anonymously as "Mysterious Sender" without ledger alteration.',
    icon: Sparkles,
  },
  RANK_INVISIBLE: {
    label: 'Rank Invisible',
    description: 'Masks username, avatar, and VIP details on leaderboards as Mystery User while keeping points.',
    icon: ShieldCheck,
  },
  ROOM_INVISIBLE: {
    label: 'Room Invisible / Stealth Entry',
    description: 'Silences live room join banners, entrance effects, and welcome messages.',
    icon: Lock,
  },
  SVIP_HIDDEN: {
    label: 'SVIP Identity Hidden',
    description: 'Hides SVIP badge and tier level from public profile cards and room presence.',
    icon: Crown,
  },
  MYSTERY: {
    label: 'Mystery Mode',
    description: 'Global stealth profile mask for high-tier VIP accounts.',
    icon: Sparkles,
  },
  HIDE_WEALTH: {
    label: 'Hide Wealth & Charm Levels',
    description: 'Masks wealth level and charm level on public cards and member strips.',
    icon: ShieldCheck,
  },
};

export function PrivacyCompliancePage() {
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [policies, setPolicies] = useState({});
  const [selectedFeature, setSelectedFeature] = useState('ANTI_FOLLOW');
  const [grantInput, setGrantInput] = useState('');
  const [saveStatus, setSaveStatus] = useState({});
  const [errorMessage, setErrorMessage] = useState('');

  const fetchPolicies = async (isManual = false) => {
    if (isManual) setRefreshing(true);
    else setLoading(true);
    setErrorMessage('');

    try {
      const data = await getPrivacyEligibilityPolicy();
      setPolicies(data || {});
    } catch (err) {
      console.error('Failed to load privacy eligibility policy:', err);
      setErrorMessage(err.response?.data?.message || err.message || 'Failed to load policy from server');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchPolicies();
  }, []);

  const currentConfig = policies[selectedFeature] || {
    featureKey: selectedFeature,
    label: FEATURE_METADATA[selectedFeature]?.label || selectedFeature,
    eligibleSvipLevels: [],
    eligibleNobleRanks: [],
    individualUserGrants: [],
  };

  const handleToggleSvip = (lvl) => {
    const currentLevels = currentConfig.eligibleSvipLevels || [];
    const exists = currentLevels.includes(lvl);
    const updated = exists ? currentLevels.filter((x) => x !== lvl) : [...currentLevels, lvl].sort((a, b) => a - b);

    setPolicies((prev) => ({
      ...prev,
      [selectedFeature]: {
        ...currentConfig,
        eligibleSvipLevels: updated,
      },
    }));
  };

  const handleToggleNoble = (rank) => {
    const currentRanks = currentConfig.eligibleNobleRanks || [];
    const exists = currentRanks.includes(rank);
    const updated = exists ? currentRanks.filter((x) => x !== rank) : [...currentRanks, rank];

    setPolicies((prev) => ({
      ...prev,
      [selectedFeature]: {
        ...currentConfig,
        eligibleNobleRanks: updated,
      },
    }));
  };

  const handleSaveFeaturePolicy = async () => {
    setSaveStatus((prev) => ({ ...prev, [selectedFeature]: 'saving' }));
    try {
      const updated = await updatePrivacyEligibilityPolicy({
        featureKey: selectedFeature,
        eligibleSvipLevels: currentConfig.eligibleSvipLevels || [],
        eligibleNobleRanks: currentConfig.eligibleNobleRanks || [],
        individualUserGrants: currentConfig.individualUserGrants || [],
      });

      setPolicies((prev) => ({
        ...prev,
        [selectedFeature]: updated,
      }));

      setSaveStatus((prev) => ({ ...prev, [selectedFeature]: 'saved' }));
      setTimeout(() => {
        setSaveStatus((prev) => ({ ...prev, [selectedFeature]: null }));
      }, 3000);
    } catch (err) {
      console.error('Failed to save policy for', selectedFeature, err);
      setSaveStatus((prev) => ({ ...prev, [selectedFeature]: 'error' }));
      alert(err.response?.data?.message || err.message || 'Failed to update feature policy');
    }
  };

  const handleGrantUser = async (e) => {
    e.preventDefault();
    const trimmedId = grantInput.trim();
    if (!trimmedId) return;

    try {
      await grantIndividualPrivacyAccess(trimmedId, selectedFeature);
      const currentGrants = currentConfig.individualUserGrants || [];
      if (!currentGrants.includes(trimmedId)) {
        setPolicies((prev) => ({
          ...prev,
          [selectedFeature]: {
            ...currentConfig,
            individualUserGrants: [...currentGrants, trimmedId],
          },
        }));
      }
      setGrantInput('');
    } catch (err) {
      console.error('Failed to grant user access:', err);
      alert(err.response?.data?.message || err.message || 'Failed to grant user access');
    }
  };

  const handleRevokeUser = async (userId) => {
    try {
      await revokeIndividualPrivacyAccess(userId, selectedFeature);
      const currentGrants = currentConfig.individualUserGrants || [];
      setPolicies((prev) => ({
        ...prev,
        [selectedFeature]: {
          ...currentConfig,
          individualUserGrants: currentGrants.filter((id) => id !== userId),
        },
      }));
    } catch (err) {
      console.error('Failed to revoke user access:', err);
      alert(err.response?.data?.message || err.message || 'Failed to revoke user access');
    }
  };

  const CurrentIcon = FEATURE_METADATA[selectedFeature]?.icon || ShieldCheck;

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ShieldCheck className="h-6 w-6 text-emerald-400" />
            Privacy & Compliance Governance
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Configure server-authoritative privacy entitlement policies, SVIP/Noble tier eligibility, and GDPR compliance.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Button
            variant="secondary"
            size="sm"
            onClick={() => fetchPolicies(true)}
            isLoading={refreshing}
            leftIcon={RefreshCw}
          >
            Refresh Policies
          </Button>
        </div>
      </div>

      {errorMessage && (
        <div className="p-4 rounded-xl bg-red-950/40 border border-red-800 text-red-200 text-sm flex items-center gap-3">
          <AlertCircle className="h-5 w-5 flex-shrink-0 text-red-400" />
          <span>{errorMessage}</span>
        </div>
      )}

      {/* NEW-58 Privacy Feature Entitlements Governance Section */}
      <Card className="p-5 space-y-5 border-slate-700/80 bg-slate-900/90 shadow-xl">
        <div className="border-b border-slate-800 pb-4 flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-base font-bold text-white">Configurable Privacy Feature Eligibility</h2>
              <Badge variant="primary">NEW-58 Server-Authoritative</Badge>
            </div>
            <p className="text-xs text-slate-400 mt-1">
              Control which SVIP levels, Noble ranks, or individual user IDs are permitted to activate gated privacy settings.
            </p>
          </div>
          <div className="text-xs text-slate-400 flex items-center gap-1.5 bg-slate-800/80 px-3 py-1.5 rounded-lg border border-slate-700/60">
            <Lock className="h-3.5 w-3.5 text-amber-400" />
            <span>Enforced server-side with fail-closed security.</span>
          </div>
        </div>

        {loading ? (
          <div className="py-12 flex flex-col items-center justify-center gap-3 text-slate-400">
            <RefreshCw className="h-6 w-6 animate-spin text-gold-400" />
            <p className="text-sm">Loading privacy policies from PolicyConfiguration...</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            {/* Feature selector sidebar */}
            <div className="lg:col-span-4 flex flex-col gap-2">
              <span className="text-xs font-semibold text-slate-400 uppercase tracking-wider px-1">
                Privacy Features ({Object.keys(FEATURE_METADATA).length})
              </span>
              <div className="flex flex-col gap-1.5 max-h-[580px] overflow-y-auto pr-1">
                {Object.entries(FEATURE_METADATA).map(([key, meta]) => {
                  const cfg = policies[key] || {};
                  const isSelected = selectedFeature === key;
                  const Icon = meta.icon;
                  const svipCount = (cfg.eligibleSvipLevels || []).length;
                  const nobleCount = (cfg.eligibleNobleRanks || []).length;
                  const grantCount = (cfg.individualUserGrants || []).length;

                  return (
                    <button
                      key={key}
                      type="button"
                      onClick={() => setSelectedFeature(key)}
                      className={[
                        'text-left p-3 rounded-xl border transition-all duration-150 flex items-start gap-3',
                        isSelected
                          ? 'bg-slate-800 border-gold-500/60 shadow-md ring-1 ring-gold-500/30'
                          : 'bg-slate-800/40 border-slate-800 hover:bg-slate-800/70 hover:border-slate-700',
                      ].join(' ')}
                    >
                      <div
                        className={[
                          'p-2 rounded-lg mt-0.5 flex-shrink-0',
                          isSelected ? 'bg-gold-500/20 text-gold-400' : 'bg-slate-700/50 text-slate-400',
                        ].join(' ')}
                      >
                        <Icon className="h-4 w-4" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between gap-1">
                          <p className={`text-xs font-bold truncate ${isSelected ? 'text-white' : 'text-slate-200'}`}>
                            {meta.label}
                          </p>
                          {isSelected && <Badge variant="primary" className="text-[10px] py-0 px-1.5">Editing</Badge>}
                        </div>
                        <p className="text-[11px] text-slate-400 line-clamp-1 mt-0.5">{meta.description}</p>
                        <div className="flex items-center gap-2 mt-2 text-[10px] text-slate-400">
                          <span className="bg-slate-900/60 px-1.5 py-0.5 rounded border border-slate-800">
                            SVIP: {svipCount ? `${svipCount} tiers` : 'None'}
                          </span>
                          <span className="bg-slate-900/60 px-1.5 py-0.5 rounded border border-slate-800">
                            Noble: {nobleCount ? `${nobleCount} ranks` : 'None'}
                          </span>
                          {grantCount > 0 && (
                            <span className="bg-emerald-950/60 text-emerald-400 px-1.5 py-0.5 rounded border border-emerald-800/60">
                              +{grantCount} grants
                            </span>
                          )}
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Feature editor pane */}
            <div className="lg:col-span-8 flex flex-col gap-5 bg-slate-800/40 p-5 rounded-2xl border border-slate-700/60">
              {/* Feature Header */}
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-700/60 pb-4">
                <div className="flex items-center gap-3">
                  <div className="p-2.5 rounded-xl bg-gold-500/15 text-gold-400 ring-1 ring-gold-500/30">
                    <CurrentIcon className="h-6 w-6" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="text-base font-bold text-white">
                        {FEATURE_METADATA[selectedFeature]?.label || selectedFeature}
                      </h3>
                      <code className="text-[11px] bg-slate-900 text-slate-400 px-2 py-0.5 rounded font-mono border border-slate-800">
                        {selectedFeature}
                      </code>
                    </div>
                    <p className="text-xs text-slate-400 mt-0.5">
                      {FEATURE_METADATA[selectedFeature]?.description}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  {saveStatus[selectedFeature] === 'saved' && (
                    <div className="flex items-center gap-1.5 text-xs text-emerald-400 font-medium">
                      <CheckCircle2 className="h-4 w-4" />
                      <span>Saved</span>
                    </div>
                  )}
                  {saveStatus[selectedFeature] === 'error' && (
                    <div className="flex items-center gap-1.5 text-xs text-red-400 font-medium">
                      <AlertCircle className="h-4 w-4" />
                      <span>Failed</span>
                    </div>
                  )}
                  <Button
                    variant="primary"
                    size="sm"
                    leftIcon={Save}
                    isLoading={saveStatus[selectedFeature] === 'saving'}
                    onClick={handleSaveFeaturePolicy}
                  >
                    Save Policy
                  </Button>
                </div>
              </div>

              {/* SVIP Tiers selection */}
              <div className="space-y-2.5">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-slate-200 flex items-center gap-2">
                    <Crown className="h-3.5 w-3.5 text-amber-400" />
                    Eligible SVIP Levels (Click to toggle)
                  </label>
                  <span className="text-[11px] text-slate-400">
                    {(currentConfig.eligibleSvipLevels || []).length} of 13 levels selected
                  </span>
                </div>
                <div className="grid grid-cols-4 sm:grid-cols-7 gap-2">
                  {ALL_SVIP_LEVELS.map((lvl) => {
                    const active = (currentConfig.eligibleSvipLevels || []).includes(lvl);
                    return (
                      <button
                        key={lvl}
                        type="button"
                        onClick={() => handleToggleSvip(lvl)}
                        className={[
                          'h-9 rounded-lg text-xs font-bold transition-all border flex items-center justify-center gap-1',
                          active
                            ? 'bg-amber-500/20 text-amber-300 border-amber-500/50 shadow-sm ring-1 ring-amber-500/30'
                            : 'bg-slate-800/80 text-slate-400 border-slate-700/60 hover:bg-slate-700/60 hover:text-white',
                        ].join(' ')}
                      >
                        <span>SVIP {lvl}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Noble Ranks selection */}
              <div className="space-y-2.5 pt-2">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-slate-200 flex items-center gap-2">
                    <Sparkles className="h-3.5 w-3.5 text-sky-400" />
                    Eligible Noble Ranks (Click to toggle)
                  </label>
                  <span className="text-[11px] text-slate-400">
                    {(currentConfig.eligibleNobleRanks || []).length} of {ALL_NOBLE_RANKS.length} ranks selected
                  </span>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                  {ALL_NOBLE_RANKS.map((rank) => {
                    const active = (currentConfig.eligibleNobleRanks || []).includes(rank);
                    return (
                      <button
                        key={rank}
                        type="button"
                        onClick={() => handleToggleNoble(rank)}
                        className={[
                          'h-9 px-2 rounded-lg text-xs font-bold transition-all border flex items-center justify-center truncate',
                          active
                            ? 'bg-sky-500/20 text-sky-300 border-sky-500/50 shadow-sm ring-1 ring-sky-500/30'
                            : 'bg-slate-800/80 text-slate-400 border-slate-700/60 hover:bg-slate-700/60 hover:text-white',
                        ].join(' ')}
                      >
                        <span>{rank}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Individual User Grants */}
              <div className="space-y-3 pt-3 border-t border-slate-700/60">
                <div className="flex items-center justify-between">
                  <div>
                    <label className="text-xs font-bold text-slate-200 flex items-center gap-2">
                      <Users className="h-3.5 w-3.5 text-emerald-400" />
                      Individual Explicit User Grants
                    </label>
                    <p className="text-[11px] text-slate-400 mt-0.5">
                      Grant access to specific users regardless of their SVIP level or Noble rank.
                    </p>
                  </div>
                  <Badge variant="success">
                    {(currentConfig.individualUserGrants || []).length} Granted
                  </Badge>
                </div>

                <form onSubmit={handleGrantUser} className="flex gap-2">
                  <Input
                    placeholder="Enter UUID or User ID (e.g., usr_...)"
                    value={grantInput}
                    onChange={(e) => setGrantInput(e.target.value)}
                    containerClassName="flex-1"
                  />
                  <Button
                    type="submit"
                    variant="secondary"
                    size="md"
                    leftIcon={Plus}
                    disabled={!grantInput.trim()}
                  >
                    Grant Access
                  </Button>
                </form>

                {/* Grants List */}
                <div className="p-3 rounded-xl bg-slate-900/70 border border-slate-800 min-h-[70px] max-h-[160px] overflow-y-auto">
                  {(currentConfig.individualUserGrants || []).length === 0 ? (
                    <div className="h-full flex items-center justify-center text-xs text-slate-500 py-3">
                      No individual user grants active for {FEATURE_METADATA[selectedFeature]?.label}. All access determined by SVIP/Noble rules.
                    </div>
                  ) : (
                    <div className="flex flex-wrap gap-2">
                      {currentConfig.individualUserGrants.map((uid) => (
                        <span
                          key={uid}
                          className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-mono bg-slate-800 border border-slate-700 text-slate-200"
                        >
                          <span className="truncate max-w-[180px]">{uid}</span>
                          <button
                            type="button"
                            onClick={() => handleRevokeUser(uid)}
                            title="Revoke access"
                            className="text-slate-400 hover:text-red-400 transition-colors p-0.5 rounded"
                          >
                            <X className="h-3 w-3" />
                          </button>
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        )}
      </Card>

      {/* Active Compliance Terms & Versions */}
      <Card className="p-5 space-y-3">
        <h2 className="text-sm font-bold text-white">Active Compliance Terms & Versions</h2>
        <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/50 flex justify-between items-center">
          <div>
            <p className="text-xs font-bold text-white">Terms of Service</p>
            <p className="text-[11px] text-slate-400">Version 3.1.0 • Applied Jan 1, 2026</p>
          </div>
          <Badge variant="success">Active</Badge>
        </div>
        <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/50 flex justify-between items-center">
          <div>
            <p className="text-xs font-bold text-white">Privacy Policy</p>
            <p className="text-[11px] text-slate-400">Version 2.8.0 • Applied Jan 1, 2026</p>
          </div>
          <Badge variant="success">Active</Badge>
        </div>
      </Card>
    </div>
  );
}

export default PrivacyCompliancePage;
