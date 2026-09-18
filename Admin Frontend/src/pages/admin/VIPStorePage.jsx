// ============================================================
// ZeParty Admin Portal — VIP / SVIP / Levels Store Page (JSX)
// Client Excel Phase D Requirements
// ============================================================

import React, { useState } from 'react';
import { Crown, Plus, Pencil, Trash2, Search, Sparkles, Award, ShieldCheck } from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

const VIP_TIERS = [
  { level: 'VIP1', spendUSD: 50, title: 'VIP Starter', perk: 'Bronze Avatar Frame, 5% Bonus EXP' },
  { level: 'VIP2', spendUSD: 200, title: 'VIP Bronze', perk: 'Silver Avatar Frame, Special Chat Bubble' },
  { level: 'VIP3', spendUSD: 500, title: 'VIP Silver', perk: 'Gold Frame, Cyber Supercar Entry' },
  { level: 'VIP4', spendUSD: 1200, title: 'VIP Gold', perk: 'Platinum Frame, Dragon Mount, Noble Badge' },
  { level: 'VIP5', spendUSD: 3000, title: 'VIP Platinum', perk: 'Diamond Frame, Dragon Mount, ID-8888 Badge' },
  { level: 'SVIP1', spendUSD: 5000, title: 'SVIP Supreme', perk: 'Supreme Aura, Custom Room Entrance' },
  { level: 'SVIP2', spendUSD: 10000, title: 'SVIP Royalty', perk: 'Royalty Crown, Dedicated Support Lead' },
];

export function VIPStorePage() {
  const { logAdminAction } = useAuditLog();
  const [grantModal, setGrantModal] = useState(false);
  const [targetUser, setTargetUser] = useState('');
  const [selectedLevel, setSelectedLevel] = useState('VIP5');
  const [auditReason, setAuditReason] = useState('');

  const handleGrantVIP = async () => {
    if (!targetUser || !auditReason) return;
    await logAdminAction({
      action: `GRANT_${selectedLevel}`,
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
          <p className="text-sm text-slate-400 mt-0.5">Manage spending tier rewards, noble entrance animations, and VIP manual grants.</p>
        </div>
        <Button variant="primary" size="sm" onClick={() => setGrantModal(true)}>
          <Award className="h-4 w-4 mr-1" /> Grant VIP Manually
        </Button>
      </div>

      {/* VIP Tiers Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
        {VIP_TIERS.map((t) => (
          <Card key={t.level} className="p-4 space-y-3">
            <div className="flex justify-between items-start">
              <div>
                <Badge variant={t.level.startsWith('SVIP') ? 'purple' : 'gold'}>{t.level}</Badge>
                <h3 className="font-bold text-white text-sm mt-1">{t.title}</h3>
              </div>
              <span className="text-xs font-mono font-bold text-gold-400">${formatNumber(t.spendUSD)} Required</span>
            </div>
            <div className="p-2.5 rounded bg-slate-900 border border-slate-800 text-xs text-slate-300">
              <span className="text-slate-400 font-semibold block mb-0.5">Privileges & Props:</span>
              {t.perk}
            </div>
          </Card>
        ))}
      </div>

      {grantModal && (
        <Modal isOpen={true} onClose={() => setGrantModal(false)} title="Grant VIP / SVIP Level Manually">
          <div className="space-y-4 text-xs text-slate-300">
            <Input label="Target User ID / Username" value={targetUser} onChange={(e) => setTargetUser(e.target.value)} required placeholder="usr-..." />
            <div>
              <label className="block text-slate-400 mb-1 font-semibold">Select Tier</label>
              <select value={selectedLevel} onChange={(e) => setSelectedLevel(e.target.value)} className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-white">
                {VIP_TIERS.map((t) => (
                  <option key={t.level} value={t.level}>{t.level} - {t.title}</option>
                ))}
              </select>
            </div>

            <Input
              label="Mandatory Audit Reason"
              placeholder="e.g. Verified high spender / Promotional grant"
              value={auditReason}
              onChange={(e) => setAuditReason(e.target.value)}
              required
            />

            <div className="flex justify-end gap-3 pt-2">
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
