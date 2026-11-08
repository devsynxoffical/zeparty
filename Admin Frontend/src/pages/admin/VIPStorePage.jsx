// ============================================================
// ZeParty Admin Portal — VIP / SVIP / Levels Store Page (JSX)
// Issue 26: Limit VIP Noble to 7 Tiers, Repair Manual Grants & User Verification
// ============================================================

import React, { useState } from 'react';
import { Crown, Sparkles, Award, ShieldCheck, CheckCircle2, AlertCircle, Loader2, UserCheck, RefreshCw } from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import { resolveMediaUrl, handleImageError } from '../../utils/imageUrl';
import { lookupUserForGrant, grantNobleToUser, grantSVIPToUser } from '../../services/modules/users.service';

// Issue 26: Strictly 7 Canonical VIP Noble Tiers
const VIP_TIERS = [
  { level: 'VIP 1', canonicalTier: 'BARON', tierNum: 1, spendUSD: 50, coins: 5000, title: 'Baron', perk: 'Bronze Avatar Frame, 5% Bonus EXP, Exclusive Entry Badge', badge: '/assets/nobles/baron_badge.webp', frame: '/assets/nobles/baron_frame.webp' },
  { level: 'VIP 2', canonicalTier: 'VISCOUNT', tierNum: 2, spendUSD: 200, coins: 20000, title: 'Viscount', perk: 'Silver Avatar Frame, Special Chat Bubble, Room Pin Priority', badge: '/assets/nobles/viscount_badge.webp', frame: '/assets/nobles/viscount_frame.webp' },
  { level: 'VIP 3', canonicalTier: 'COUNT', tierNum: 3, spendUSD: 500, coins: 50000, title: 'Count', perk: 'Gold Frame, Cyber Supercar Entry, 10% EXP Booster', badge: '/assets/nobles/count_badge.webp', frame: '/assets/nobles/count_frame.webp' },
  { level: 'VIP 4', canonicalTier: 'MARQUIS', tierNum: 4, spendUSD: 1200, coins: 120000, title: 'Marquis', perk: 'Platinum Frame, Dragon Mount, Noble Badge, Priority Support', badge: '/assets/nobles/marquis_badge.webp', frame: '/assets/nobles/marquis_frame.webp' },
  { level: 'VIP 5', canonicalTier: 'DUKE', tierNum: 5, spendUSD: 3000, coins: 300000, title: 'Duke', perk: 'Diamond Frame, Dragon Mount, ID-8888 Badge, Custom Profile Card', badge: '/assets/nobles/duke_badge.webp', frame: '/assets/nobles/duke_frame.webp' },
  { level: 'VIP 6', canonicalTier: 'KING', tierNum: 6, spendUSD: 5000, coins: 500000, title: 'King', perk: 'Imperial King Crown Frame & Crest, Dedicated Room Host Privilege', badge: '/assets/nobles/king_badge.webp', frame: '/assets/nobles/king_frame.webp' },
  { level: 'VIP 7', canonicalTier: 'EMPEROR', tierNum: 7, spendUSD: 8000, coins: 800000, title: 'Emperor', perk: 'Imperial Emperor Frame & Crest, Global Room Entrance Notification', badge: '/assets/nobles/emperor_badge.webp', frame: '/assets/nobles/emperor_frame.webp' },
];

// Issue 26: SVIP Independent System (16 Tiers)
const SVIP_TIERS = Array.from({ length: 16 }, (_, i) => {
  const num = i + 1;
  const spendUSD = 5000 + i * 5000;
  return {
    level: `SVIP ${num}`,
    tierNum: num,
    spendUSD,
    coins: spendUSD * 100,
    title: `SVIP Tier ${num} Supreme`,
    perk: `Full animated SVIP ${num} Aura, Dynamic Entry Effect, Glowing Chat Bubble & Dedicated Support Lead`,
    badge: `/assets/svip/svip${num}_badge.webp`,
    frame: `/assets/svip/svip${num}_frame.webp`,
    profileCard: `/assets/svip/svip${num}_profilecard.webp`,
  };
});

export function VIPStorePage() {
  const { logAdminAction } = useAuditLog();
  const [activeTab, setActiveTab] = useState('VIP');
  
  // Modal & Grant state
  const [grantModal, setGrantModal] = useState(false);
  const [grantMode, setGrantMode] = useState('NOBLE'); // 'NOBLE' | 'SVIP'
  const [userQuery, setUserQuery] = useState('');
  const [verifiedUser, setVerifiedUser] = useState(null);
  const [isVerifying, setIsVerifying] = useState(false);
  const [verifyError, setVerifyError] = useState(null);
  
  const [selectedNobleTier, setSelectedNobleTier] = useState('BARON');
  const [selectedSvipLevel, setSelectedSvipLevel] = useState(1);
  const [durationDays, setDurationDays] = useState(30);
  const [auditReason, setAuditReason] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [actionFeedback, setActionFeedback] = useState(null);

  const currentTiers = activeTab === 'VIP' ? VIP_TIERS : SVIP_TIERS;

  // Open modal with preselected tier
  const handleOpenGrantModal = (tier) => {
    setActionFeedback(null);
    setVerifyError(null);
    if (tier?.canonicalTier) {
      setGrantMode('NOBLE');
      setSelectedNobleTier(tier.canonicalTier);
    } else if (tier?.tierNum) {
      setGrantMode('SVIP');
      setSelectedSvipLevel(tier.tierNum);
    }
    setGrantModal(true);
  };

  // User verification
  const handleVerifyUser = async () => {
    if (!userQuery.trim()) return;
    setIsVerifying(true);
    setVerifyError(null);
    setActionFeedback(null);
    try {
      const user = await lookupUserForGrant(userQuery.trim());
      setVerifiedUser(user);
    } catch (err) {
      setVerifiedUser(null);
      setVerifyError(err?.response?.data?.message || err?.message || 'User not found or deleted');
    } finally {
      setIsVerifying(false);
    }
  };

  // Execute Grant
  const handleExecuteGrant = async () => {
    if (!verifiedUser || !auditReason.trim()) return;
    setIsSubmitting(true);
    setActionFeedback(null);

    try {
      if (grantMode === 'NOBLE') {
        const res = await grantNobleToUser(verifiedUser.id, {
          nobleTitle: selectedNobleTier,
          durationDays: Number(durationDays) || 30,
          reason: auditReason.trim(),
        });

        await logAdminAction({
          action: `GRANT_NOBLE_${selectedNobleTier}`,
          module: 'VIP',
          targetType: 'user',
          targetId: verifiedUser.id,
          reason: auditReason.trim(),
          riskLevel: 'MEDIUM',
        });

        setActionFeedback({
          type: 'success',
          message: res?.message || `Noble title "${selectedNobleTier}" successfully granted to @${verifiedUser.username}!`,
        });

        // Update local user card
        setVerifiedUser((prev) => ({
          ...prev,
          nobleRank: res?.nobleRank || selectedNobleTier,
        }));
      } else {
        const res = await grantSVIPToUser(verifiedUser.id, {
          svipLevel: Number(selectedSvipLevel),
          durationDays: Number(durationDays) || 30,
          reason: auditReason.trim(),
        });

        await logAdminAction({
          action: `GRANT_SVIP_${selectedSvipLevel}`,
          module: 'VIP',
          targetType: 'user',
          targetId: verifiedUser.id,
          reason: auditReason.trim(),
          riskLevel: 'MEDIUM',
        });

        setActionFeedback({
          type: 'success',
          message: res?.message || `SVIP Level ${selectedSvipLevel} successfully granted to @${verifiedUser.username}!`,
        });

        // Update local user card
        setVerifiedUser((prev) => ({
          ...prev,
          svipLevel: Number(selectedSvipLevel),
        }));
      }

      setAuditReason('');
    } catch (err) {
      setActionFeedback({
        type: 'error',
        message: err?.response?.data?.message || err?.message || 'Failed to grant privilege. Check input parameters.',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Crown className="h-6 w-6 text-amber-400" />
            VIP & SVIP Privilege Store
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage 7 canonical VIP Noble tiers, 16 SVIP Supreme tiers, visual badges, frames, and manual admin grants.
          </p>
        </div>
        <Button variant="primary" size="sm" onClick={() => handleOpenGrantModal()}>
          <Award className="h-4 w-4 mr-1" /> Grant VIP / SVIP Manually
        </Button>
      </div>

      {/* Tab Switcher */}
      <div className="flex gap-2 border-b border-slate-800 pb-2">
        <button
          onClick={() => setActiveTab('VIP')}
          className={[
            'px-4 py-2 rounded-lg text-xs font-bold transition-all border flex items-center gap-2',
            activeTab === 'VIP'
              ? 'bg-amber-500/20 text-amber-400 border-amber-500/40 shadow-sm shadow-amber-500/10'
              : 'text-slate-400 hover:text-white bg-slate-900 border-slate-800 hover:border-slate-700',
          ].join(' ')}
        >
          <Crown className="h-3.5 w-3.5 text-amber-400" />
          VIP Noble Tiers (VIP 1 - VIP 7: Baron to Emperor)
        </button>
        <button
          onClick={() => setActiveTab('SVIP')}
          className={[
            'px-4 py-2 rounded-lg text-xs font-bold transition-all border flex items-center gap-2',
            activeTab === 'SVIP'
              ? 'bg-purple-500/20 text-purple-400 border-purple-500/40 shadow-sm shadow-purple-500/10'
              : 'text-slate-400 hover:text-white bg-slate-900 border-slate-800 hover:border-slate-700',
          ].join(' ')}
        >
          <Sparkles className="h-3.5 w-3.5 text-purple-400" />
          SVIP Supreme Tiers (SVIP 1 - SVIP 16)
        </button>
      </div>

      {/* Tiers Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        {currentTiers.map((t) => (
          <Card
            key={t.level}
            className="p-4 space-y-3 border-slate-800 bg-slate-900/60 hover:border-amber-500/30 transition-all flex flex-col justify-between"
          >
            <div>
              <div className="flex justify-between items-start gap-2">
                <div>
                  <Badge variant={t.level.startsWith('SVIP') ? 'purple' : 'gold'} className="font-bold">
                    {t.level}
                  </Badge>
                  <h3 className="font-bold text-white text-sm mt-1">{t.title}</h3>
                </div>
                <div className="text-right">
                  <span className="text-xs font-mono font-bold text-amber-400 block">${formatNumber(t.spendUSD)}</span>
                  <span className="text-[10px] text-slate-500 font-mono">🪙 {formatNumber(t.coins)} coins</span>
                </div>
              </div>

              {/* Visual Asset Previews */}
              <div className="flex items-center gap-3 my-3 p-2.5 rounded-xl bg-slate-950/70 border border-slate-800/80">
                <div className="flex-1 flex flex-col items-center">
                  <span className="text-[10px] font-semibold text-slate-400 mb-1">Badge</span>
                  <div className="w-12 h-12 rounded-lg bg-slate-900 border border-slate-800 flex items-center justify-center p-1 overflow-hidden shadow-inner">
                    <img
                      src={resolveMediaUrl(t.badge, 'badge')}
                      alt={`${t.level} Badge`}
                      onError={(e) => handleImageError(e, 'badge')}
                      className="w-full h-full object-contain filter drop-shadow-md"
                    />
                  </div>
                </div>

                <div className="flex-1 flex flex-col items-center">
                  <span className="text-[10px] font-semibold text-slate-400 mb-1">Frame</span>
                  <div className="w-12 h-12 rounded-lg bg-slate-900 border border-slate-800 flex items-center justify-center p-1 overflow-hidden shadow-inner">
                    <img
                      src={resolveMediaUrl(t.frame, 'frame')}
                      alt={`${t.level} Frame`}
                      onError={(e) => handleImageError(e, 'frame')}
                      className="w-full h-full object-contain filter drop-shadow-md"
                    />
                  </div>
                </div>
              </div>

              <div className="p-2.5 rounded-lg bg-slate-950/50 border border-slate-800 text-xs text-slate-300">
                <span className="text-slate-400 font-semibold block mb-0.5 text-[10px] uppercase tracking-wider">Privileges & Perks:</span>
                <p className="text-slate-300 text-xs leading-relaxed">{t.perk}</p>
              </div>
            </div>

            <Button
              variant="outline"
              size="sm"
              className="w-full text-xs mt-2"
              onClick={() => handleOpenGrantModal(t)}
            >
              Grant {t.level} to User
            </Button>
          </Card>
        ))}
      </div>

      {/* Manual Grant Modal */}
      {grantModal && (
        <Modal
          isOpen={true}
          onClose={() => {
            setGrantModal(false);
            setVerifiedUser(null);
            setUserQuery('');
            setActionFeedback(null);
          }}
          title="Grant VIP Noble / SVIP Status Manually"
        >
          <div className="space-y-4 text-xs text-slate-300">
            {/* Feedback Alert */}
            {actionFeedback && (
              <div
                className={`p-3 rounded-lg border text-xs flex items-center gap-2 ${
                  actionFeedback.type === 'success'
                    ? 'bg-emerald-950/40 border-emerald-500/50 text-emerald-300'
                    : 'bg-rose-950/40 border-rose-500/50 text-rose-300'
                }`}
              >
                {actionFeedback.type === 'success' ? (
                  <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-400" />
                ) : (
                  <AlertCircle className="h-4 w-4 shrink-0 text-rose-400" />
                )}
                <span>{actionFeedback.message}</span>
              </div>
            )}

            {/* Target User Verification Section */}
            <div className="space-y-2">
              <label className="block text-slate-400 font-semibold">
                Target User Identifier <span className="text-rose-400">*</span>
              </label>
              <div className="flex gap-2">
                <Input
                  value={userQuery}
                  onChange={(e) => {
                    setUserQuery(e.target.value);
                    setVerifiedUser(null); // Invalidate verified user when query changes
                    setVerifyError(null);
                    setActionFeedback(null);
                  }}
                  placeholder="Enter User ID (e.g. 9202535), @username, or UUID"
                  className="flex-1"
                />
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleVerifyUser}
                  disabled={!userQuery.trim() || isVerifying}
                  className="shrink-0"
                >
                  {isVerifying ? (
                    <Loader2 className="h-4 w-4 animate-spin mr-1" />
                  ) : (
                    <UserCheck className="h-4 w-4 mr-1 text-emerald-400" />
                  )}
                  {isVerifying ? 'Verifying...' : 'Verify User'}
                </Button>
              </div>
              <p className="text-[11px] text-slate-500">
                You must verify the account before granting any privileges. Modifying the search text resets verification.
              </p>

              {verifyError && (
                <div className="p-2.5 rounded bg-rose-950/30 border border-rose-900/50 text-rose-400 text-xs flex items-center gap-1.5">
                  <AlertCircle className="h-3.5 w-3.5 shrink-0" />
                  <span>{verifyError}</span>
                </div>
              )}
            </div>

            {/* Verified Account Card */}
            {verifiedUser && (
              <div className="p-3 rounded-xl bg-slate-950/80 border border-emerald-500/40 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-slate-800 border border-slate-700 overflow-hidden flex items-center justify-center">
                      {verifiedUser.avatarUrl ? (
                        <img
                          src={resolveMediaUrl(verifiedUser.avatarUrl, 'avatar')}
                          alt="Avatar"
                          onError={(e) => handleImageError(e, 'avatar')}
                          className="w-full h-full object-cover"
                        />
                      ) : (
                        <ShieldCheck className="h-5 w-5 text-emerald-400" />
                      )}
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-white text-sm">
                          {verifiedUser.displayName || verifiedUser.nickname || verifiedUser.username}
                        </span>
                        <Badge variant="success" className="text-[10px]">Verified</Badge>
                      </div>
                      <span className="text-slate-400 font-mono text-[11px]">
                        @{verifiedUser.username} · ID: {verifiedUser.id}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-2 pt-2 border-t border-slate-800/80 text-[11px]">
                  <div className="bg-slate-900/60 p-2 rounded border border-slate-800">
                    <span className="text-slate-500 block">Current Noble Rank</span>
                    <span className="font-semibold text-amber-400">
                      {verifiedUser.nobleRank && verifiedUser.nobleRank !== 'None'
                        ? verifiedUser.nobleRank
                        : 'No Active Noble'}
                    </span>
                  </div>
                  <div className="bg-slate-900/60 p-2 rounded border border-slate-800">
                    <span className="text-slate-500 block">Current SVIP Level</span>
                    <span className="font-semibold text-purple-400">
                      {verifiedUser.svipLevel ? `SVIP ${verifiedUser.svipLevel}` : 'Standard (No SVIP)'}
                    </span>
                  </div>
                </div>
              </div>
            )}

            {/* Grant Mode Switcher */}
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Entitlement Category</label>
              <div className="grid grid-cols-2 gap-2">
                <button
                  type="button"
                  onClick={() => setGrantMode('NOBLE')}
                  className={`p-2.5 rounded-lg border text-xs font-bold flex items-center justify-center gap-2 transition-all ${
                    grantMode === 'NOBLE'
                      ? 'bg-amber-500/20 border-amber-500/50 text-amber-400'
                      : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  <Crown className="h-4 w-4" /> VIP Noble Title (7 Tiers)
                </button>
                <button
                  type="button"
                  onClick={() => setGrantMode('SVIP')}
                  className={`p-2.5 rounded-lg border text-xs font-bold flex items-center justify-center gap-2 transition-all ${
                    grantMode === 'SVIP'
                      ? 'bg-purple-500/20 border-purple-500/50 text-purple-400'
                      : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
                  }`}
                >
                  <Sparkles className="h-4 w-4" /> SVIP Status (16 Tiers)
                </button>
              </div>
            </div>

            {/* Noble Tier Selector (7 Canonical Tiers) */}
            {grantMode === 'NOBLE' ? (
              <div>
                <label className="block text-slate-400 mb-1 font-semibold">
                  Select Approved VIP Noble Tier (Limit: 7 Tiers)
                </label>
                <select
                  value={selectedNobleTier}
                  onChange={(e) => setSelectedNobleTier(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-xs font-medium focus:ring-1 focus:ring-amber-400"
                >
                  {VIP_TIERS.map((t) => (
                    <option key={t.canonicalTier} value={t.canonicalTier}>
                      Tier {t.tierNum}: {t.title} ({t.level}) — ${formatNumber(t.spendUSD)} threshold
                    </option>
                  ))}
                </select>
                <p className="text-[11px] text-amber-500/80 mt-1">
                  Single active noble title rule: granting a new noble title deactivates any existing noble rank for this account.
                </p>
              </div>
            ) : (
              <div>
                <label className="block text-slate-400 mb-1 font-semibold">
                  Select SVIP Level (1 - 16)
                </label>
                <select
                  value={selectedSvipLevel}
                  onChange={(e) => setSelectedSvipLevel(Number(e.target.value))}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-xs font-medium focus:ring-1 focus:ring-purple-400"
                >
                  <option value={0}>0 — Revoke SVIP Status</option>
                  {SVIP_TIERS.map((t) => (
                    <option key={t.tierNum} value={t.tierNum}>
                      {t.level}: {t.title} (${formatNumber(t.spendUSD)})
                    </option>
                  ))}
                </select>
                <p className="text-[11px] text-purple-400/80 mt-1">
                  SVIP is independent of VIP Noble rank. Setting SVIP will preserve the user's active noble title.
                </p>
              </div>
            )}

            {/* Duration Days */}
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Entitlement Validity</label>
              <select
                value={durationDays}
                onChange={(e) => setDurationDays(Number(e.target.value))}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-xs font-medium"
              >
                <option value={30}>30 Days (Standard Activation)</option>
                <option value={90}>90 Days (Quarterly Privilege)</option>
                <option value={365}>365 Days (1 Full Year)</option>
                <option value={0}>Permanent Assignment</option>
              </select>
            </div>

            {/* Mandatory Audit Reason */}
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">
                Mandatory Audit Reason <span className="text-rose-400">*</span>
              </label>
              <textarea
                value={auditReason}
                onChange={(e) => setAuditReason(e.target.value)}
                placeholder="e.g. VIP onboarding gift approved by Head of Operations / verified external transfer"
                rows={2}
                required
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-xs focus:ring-1 focus:ring-amber-400 outline-none"
              />
            </div>

            {/* Action Buttons */}
            <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setGrantModal(false);
                  setVerifiedUser(null);
                  setUserQuery('');
                  setActionFeedback(null);
                }}
              >
                Cancel
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={handleExecuteGrant}
                disabled={!verifiedUser || !auditReason.trim() || isSubmitting}
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin mr-1" />
                    Applying Grant...
                  </>
                ) : (
                  <>
                    <Award className="h-4 w-4 mr-1" />
                    Confirm & Apply Grant
                  </>
                )}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
export default VIPStorePage;
