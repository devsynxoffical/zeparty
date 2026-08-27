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

const MOCK_VIP_TIERS = [
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
            VIP / SVIP / Level Perks Engine
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage VIP levels, spending thresholds, room entrance effects, and admin manual grants.</p>
        </div>

        <Button variant="primary" size="sm" leftIcon={Sparkles} onClick={() => setGrantModal(true)}>
          Grant VIP / SVIP Status
        </Button>
      </div>

      <Card className="p-5">
        <h2 className="text-sm font-bold text-white mb-4 flex items-center gap-2">
          <Award className="h-4 w-4 text-gold-400" /> VIP & SVIP Privilege Tiers & Thresholds
        </h2>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
          {MOCK_VIP_TIERS.map((t) => (
            <div key={t.level} className="p-4 rounded-xl bg-slate-800/60 border border-slate-700/50 flex flex-col justify-between">
              <div>
                <div className="flex justify-between items-center mb-1">
                  <Badge variant={t.level.startsWith('SVIP') ? 'purple' : 'warning'}>{t.level}</Badge>
                  <span className="text-xs font-mono font-bold text-emerald-400">${formatNumber(t.spendUSD)} USD</span>
                </div>
                <p className="text-sm font-bold text-white mt-1">{t.title}</p>
                <p className="text-xs text-slate-400 mt-1 italic">{t.perk}</p>
              </div>
            </div>
          ))}
        </div>
      </Card>

      {grantModal && (
        <Modal
          isOpen={true}
          onClose={() => setGrantModal(null)}
          title="Grant VIP / SVIP Status to User"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Target User ID or Username"
              placeholder="e.g. usr-001"
              value={targetUser}
              onChange={(e) => setTargetUser(e.target.value)}
              required
            />

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">Select Status Tier</label>
              <select
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none"
                value={selectedLevel}
                onChange={(e) => setSelectedLevel(e.target.value)}
              >
                {MOCK_VIP_TIERS.map((t) => (
                  <option key={t.level} value={t.level}>{t.level} — {t.title}</option>
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
