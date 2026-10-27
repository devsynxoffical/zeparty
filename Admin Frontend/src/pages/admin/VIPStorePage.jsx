// ============================================================
// ZeParty Admin Portal — VIP / SVIP / Levels Store Page (JSX)
// Client Excel Phase D Requirements + Real Visual Asset Integration
// ============================================================

import React, { useState } from 'react';
import { Crown, Plus, Pencil, Trash2, Search, Sparkles, Award, ShieldCheck, Star } from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import { resolveMediaUrl, handleImageError } from '../../utils/imageUrl';

const VIP_TIERS = [
  { level: 'VIP 1', spendUSD: 50, coins: 5000, title: 'VIP Starter', perk: 'Bronze Avatar Frame, 5% Bonus EXP, Exclusive Entry Badge', badge: '/assets/nobles/baron_badge.webp', frame: '/assets/nobles/baron_frame.webp' },
  { level: 'VIP 2', spendUSD: 200, coins: 20000, title: 'VIP Bronze', perk: 'Silver Avatar Frame, Special Chat Bubble, Room Pin Priority', badge: '/assets/nobles/viscount_badge.webp', frame: '/assets/nobles/viscount_frame.webp' },
  { level: 'VIP 3', spendUSD: 500, coins: 50000, title: 'VIP Silver', perk: 'Gold Frame, Cyber Supercar Entry, 10% EXP Booster', badge: '/assets/nobles/count_badge.webp', frame: '/assets/nobles/count_frame.webp' },
  { level: 'VIP 4', spendUSD: 1200, coins: 120000, title: 'VIP Gold', perk: 'Platinum Frame, Dragon Mount, Noble Badge, Priority Support', badge: '/assets/nobles/marquis_badge.webp', frame: '/assets/nobles/marquis_frame.webp' },
  { level: 'VIP 5', spendUSD: 3000, coins: 300000, title: 'VIP Platinum', perk: 'Diamond Frame, Dragon Mount, ID-8888 Badge, Custom Profile Card', badge: '/assets/nobles/duke_badge.webp', frame: '/assets/nobles/duke_frame.webp' },
  { level: 'VIP 6', spendUSD: 5000, coins: 500000, title: 'VIP Crown', perk: 'Imperial King Crown Frame & Crest, Dedicated Room Host Privilege', badge: '/assets/nobles/king_badge.webp', frame: '/assets/nobles/king_frame.webp' },
  { level: 'VIP 7', spendUSD: 8000, coins: 800000, title: 'VIP Royal Emperor', perk: 'Imperial Emperor Frame & Crest, Global Room Entrance Notification', badge: '/assets/nobles/emperor_badge.webp', frame: '/assets/nobles/emperor_frame.webp' },
  { level: 'VIP 8', spendUSD: 12000, coins: 1200000, title: 'VIP Sovereign', perk: 'Celestial Warrior Frame & Gold Crest, 20% Coin Rebate Perks', badge: '/assets/roles/ZP-216_official_badge.webp', frame: '/assets/roles/official_frame.webp' },
  { level: 'VIP 9', spendUSD: 18000, coins: 1800000, title: 'VIP Mythic', perk: 'Apex Sovereign Frame & Sovereign Tag, Dedicated VIP Manager', badge: '/assets/roles/admin_badge.webp', frame: '/assets/roles/admin_frame.webp' },
  { level: 'VIP 10', spendUSD: 25000, coins: 2500000, title: 'VIP Titan', perk: 'Mythic Titan Frame & Dragon Crest, Exclusive Profile Banner', badge: '/assets/roles/super_admin_tag.webp', frame: '/assets/roles/super_admin_frame.webp' },
  { level: 'VIP 11', spendUSD: 35000, coins: 3500000, title: 'VIP Celestial', perk: 'Eternal Celestial Frame & Star Halo, Animated Avatar Glow', badge: '/assets/roles/boss_tag.webp', frame: '/assets/roles/boss_frame.webp' },
  { level: 'VIP 12', spendUSD: 50000, coins: 5000000, title: 'VIP Overlord', perk: 'Supreme Overlord Frame & Infinity Badge, Custom Room Aura', badge: '/assets/roles/ceo_tag.webp', frame: '/assets/roles/ceo_frame.webp' },
];

const SVIP_TIERS = Array.from({ length: 16 }, (_, i) => {
  const num = i + 1;
  const spendUSD = 5000 + i * 5000;
  return {
    level: `SVIP ${num}`,
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
  const [grantModal, setGrantModal] = useState(false);
  const [targetUser, setTargetUser] = useState('');
  const [selectedLevel, setSelectedLevel] = useState('VIP 5');
  const [auditReason, setAuditReason] = useState('');

  const currentTiers = activeTab === 'VIP' ? VIP_TIERS : SVIP_TIERS;

  const handleGrantVIP = async () => {
    if (!targetUser || !auditReason) return;
    await logAdminAction({
      action: `GRANT_${selectedLevel.replace(/\s+/g, '_')}`,
      module: 'VIP',
      targetType: 'user',
      targetId: targetUser,
      reason: auditReason,
      riskLevel: 'MEDIUM',
    });
    setGrantModal(false);
    setTargetUser('');
    setAuditReason('');
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Crown className="h-6 w-6 text-gold-400" />
            VIP & SVIP Privilege Store
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage spending tier rewards, noble entrance animations, profile frames, badges, and VIP manual grants.
          </p>
        </div>
        <Button variant="primary" size="sm" onClick={() => setGrantModal(true)}>
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
          VIP Tiers (VIP 1 - VIP 12)
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
              onClick={() => {
                setSelectedLevel(t.level);
                setGrantModal(true);
              }}
            >
              Grant {t.level} to User
            </Button>
          </Card>
        ))}
      </div>

      {grantModal && (
        <Modal isOpen={true} onClose={() => setGrantModal(false)} title="Grant VIP / SVIP Level Manually">
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Target User ID / Username"
              value={targetUser}
              onChange={(e) => setTargetUser(e.target.value)}
              required
              placeholder="e.g. usr-12345 or @username"
            />
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Select Tier</label>
              <select
                value={selectedLevel}
                onChange={(e) => setSelectedLevel(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white text-xs"
              >
                <optgroup label="VIP Tiers">
                  {VIP_TIERS.map((t) => (
                    <option key={t.level} value={t.level}>{t.level} - {t.title}</option>
                  ))}
                </optgroup>
                <optgroup label="SVIP Supreme Tiers">
                  {SVIP_TIERS.map((t) => (
                    <option key={t.level} value={t.level}>{t.level} - {t.title}</option>
                  ))}
                </optgroup>
              </select>
            </div>

            <Input
              label="Mandatory Audit Reason"
              placeholder="e.g. Verified high spender / Promotional grant"
              value={auditReason}
              onChange={(e) => setAuditReason(e.target.value)}
              required
            />

            <div className="flex justify-end gap-3 pt-2 border-t border-slate-800">
              <Button variant="ghost" size="sm" onClick={() => setGrantModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleGrantVIP} disabled={!targetUser || !auditReason}>
                Grant Status & Log Audit
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}

