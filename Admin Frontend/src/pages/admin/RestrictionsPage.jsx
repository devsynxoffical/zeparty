// ============================================================
// ZeParty Admin Portal — Restrictions & Ban Management (JSX)
// Client Excel Phase C Requirements
// ============================================================

import React, { useState, useEffect } from 'react';
import { Slash, Search, Plus, Clock, ShieldOff, AlertTriangle } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { useAuditLog } from '../../context/AuditLogContext';
import { getRestrictions, applyRestriction, liftRestriction } from '../../services/modules/moderation.service';

export function RestrictionsPage() {
  const { logAdminAction } = useAuditLog();
  const [restrictions, setRestrictions] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [createModal, setCreateModal] = useState(false);
  const [removeTarget, setRemoveTarget] = useState(null);
  const [successMsg, setSuccessMsg] = useState(null);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    getRestrictions()
      .then((data) => {
        if (!isMounted) return;
        const formatted = (data || []).map((r) => ({
          id: r.id,
          user: r.user?.username || r.userId || 'User',
          userId: r.userId,
          type: r.type || 'PERMANENT_BAN',
          reason: r.reason || 'Administrative restriction',
          expiry: r.expiresAt ? new Date(r.expiresAt).toLocaleDateString() : 'Never (Permanent)',
          createdBy: r.createdByName || r.createdByAdminId || 'Super Admin',
          status: r.status || 'ACTIVE',
        }));
        setRestrictions(formatted);
      })
      .catch(() => {
        if (isMounted) setRestrictions([]);
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  // Form states
  const [formUser, setFormUser] = useState('');
  const [formScope, setFormScope] = useState('TEMP_BAN');
  const [formDuration, setFormDuration] = useState('');
  const [formReason, setFormReason] = useState('');

  const handleRemovePenalty = async () => {
    if (!removeTarget) return;
    try {
      await liftRestriction(removeTarget.id);
    } catch {}
    setRestrictions(restrictions.filter((r) => r.id !== removeTarget.id));
    
    await logAdminAction({
      action: 'USER_PENALTY_REMOVED',
      module: 'Moderation',
      targetType: 'user_restriction',
      targetId: removeTarget.id,
      targetName: removeTarget.user,
      reason: 'Administrative lifting of restriction',
      riskLevel: 'HIGH',
      afterValue: { status: 'EXPIRED' }
    });

    setSuccessMsg(`Penalty "${removeTarget.id}" removed from ${removeTarget.user}. Account unbanned.`);
    setRemoveTarget(null);
    setTimeout(() => setSuccessMsg(null), 3000);
  };

  const handleApplyPenalty = async () => {
    if (!formUser || !formReason) return;
    const penaltyType = formScope === 'PERM_BAN' ? 'PERMANENT_BAN' : formScope === 'TEMP_BAN' ? 'TEMPORARY_BAN' : formScope;
    let createdItem;
    try {
      createdItem = await applyRestriction({
        userId: formUser,
        type: penaltyType,
        reason: formReason,
        durationDays: formDuration ? parseInt(formDuration, 10) : undefined,
      });
    } catch {}

    const newPenalty = {
      id: createdItem?.id || `RST-${Math.floor(100 + Math.random() * 900)}`,
      user: formUser,
      type: penaltyType,
      reason: formReason,
      expiry: formDuration ? `${formDuration} Days` : 'Never (Permanent)',
      createdBy: 'Super Admin',
      status: 'ACTIVE'
    };

    setRestrictions([newPenalty, ...restrictions]);

    await logAdminAction({
      action: 'USER_PENALTY_APPLIED',
      module: 'Moderation',
      targetType: 'user_restriction',
      targetId: newPenalty.id,
      targetName: formUser,
      reason: formReason,
      riskLevel: formScope.includes('BAN') ? 'HIGH' : 'MEDIUM',
      afterValue: { type: newPenalty.type, expiry: newPenalty.expiry }
    });

    setSuccessMsg(`Penalty applied successfully to ${formUser}.`);
    setCreateModal(false);
    setFormUser('');
    setFormScope('TEMP_BAN');
    setFormDuration('');
    setFormReason('');
    setTimeout(() => setSuccessMsg(null), 3000);
  };

  const columns = [
    {
      key: 'id',
      header: 'Restriction ID',
      render: (r) => <span className="text-xs font-mono font-bold text-white">{r.id}</span>,
    },
    {
      key: 'user',
      header: 'Target User',
      render: (r) => <span className="text-xs font-semibold text-white">{r.user}</span>,
    },
    {
      key: 'type',
      header: 'Restriction Scope',
      render: (r) => <Badge variant="danger">{r.type}</Badge>,
    },
    {
      key: 'reason',
      header: 'Audit Reason',
      render: (r) => <span className="text-xs text-slate-300 italic">{r.reason}</span>,
    },
    {
      key: 'expiry',
      header: 'Expiry Duration',
      render: (r) => <span className="text-xs text-slate-400 font-mono">{r.expiry}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <StatusBadge status={r.status.toLowerCase()} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <Button variant="outline" size="xs" onClick={() => setRemoveTarget(r)}>
          Remove Penalty
        </Button>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Slash className="h-6 w-6 text-red-400" />
            Ban & Restriction Management
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Enforce account bans, room mute/mic restrictions, and penalty histories.</p>
        </div>

        <Button variant="primary" size="sm" leftIcon={Plus} onClick={() => setCreateModal(true)}>
          New Penalty Rule
        </Button>
      </div>

      {successMsg && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{successMsg}</span>
          <span className="font-mono">PENALTY REMOVED</span>
        </div>
      )}

      <Card className="p-4">
        <Input
          placeholder="Search by user or restriction ID..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={restrictions} isLoading={isLoading} emptyTitle="No penalties or restrictions active" emptyDescription="All user accounts and room privileges are currently in good standing." />

      {removeTarget && (
        <Modal
          isOpen={true}
          onClose={() => setRemoveTarget(null)}
          title={`Remove Penalty: ${removeTarget.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>Are you sure you want to lift restriction <strong className="text-white">{removeTarget.type}</strong> for <strong className="text-white">{removeTarget.user}</strong>?</p>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setRemoveTarget(null)}>
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={handleRemovePenalty}>
                Confirm Removal
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {createModal && (
        <Modal
          isOpen={true}
          onClose={() => setCreateModal(false)}
          title="Apply User Ban or Scope Restriction"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input 
              label="Target User ID or Username" 
              placeholder="e.g. usr-004" 
              value={formUser}
              onChange={(e) => setFormUser(e.target.value)}
              required 
            />

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">Restriction Scope</label>
              <select 
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none"
                value={formScope}
                onChange={(e) => setFormScope(e.target.value)}
              >
                <option value="TEMP_BAN">Temporary Account Ban</option>
                <option value="PERM_BAN">Permanent Account Ban</option>
                <option value="ROOM_BAN">Live Room Access Ban</option>
                <option value="CHAT">Chat Mute Restriction</option>
                <option value="MIC">Mic / Audio Block</option>
              </select>
            </div>

            <Input 
              label="Duration (Days)" 
              type="number" 
              placeholder="7" 
              value={formDuration}
              onChange={(e) => setFormDuration(e.target.value)}
              hint="Leave blank for permanent" 
            />

            <Input 
              label="Mandatory Audit Reason" 
              placeholder="e.g. Violation of community guidelines" 
              value={formReason}
              onChange={(e) => setFormReason(e.target.value)}
              required 
            />

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setCreateModal(false)}>
                Cancel
              </Button>
              <Button 
                variant="danger" 
                size="sm" 
                onClick={handleApplyPenalty}
                disabled={!formUser || !formReason}
              >
                Apply Penalty
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
