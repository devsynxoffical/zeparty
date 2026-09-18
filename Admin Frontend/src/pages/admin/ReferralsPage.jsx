// ============================================================
// ZeParty Admin Portal — Referral System Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { Share2, Search, Gift, ShieldAlert, CheckCircle, ShieldX, Globe, Settings } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';
import apiClient from '../../services/api';

export function ReferralsPage() {
  const { logAdminAction } = useAuditLog();
  const [referrals, setReferrals] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedRef, setSelectedRef] = useState(null);

  useEffect(() => {
    let isMounted = true;
    setIsLoading(true);
    apiClient
      .get('/v1/admin/users', { params: { limit: 50 } })
      .then((res) => {
        if (!isMounted) return;
        // Referrals are tracked if user has referredById
        const users = res.data?.data || [];
        const formatted = users
          .filter((u) => u.referredById || u.referralCode)
          .map((u) => ({
            id: `REF-${u.id.slice(0, 6)}`,
            referralCode: u.referralCode || `ZE-${u.username.toUpperCase()}`,
            inviter: u.referredBy?.username || u.referredById || 'System Host',
            invitee: u.username,
            rewardEarnedCoins: Number(u.referralCoins || 0),
            status: u.status === 'ACTIVE' ? 'COMPLETED' : 'SUSPICIOUS',
            fraudRisk: u.status === 'ACTIVE' ? 'CLEARED' : 'FLAGGED',
            date: u.createdAt ? new Date(u.createdAt).toISOString().slice(0, 10) : '',
            country: u.country || 'US',
          }));
        setReferrals(formatted);
      })
      .catch(() => {
        if (isMounted) setReferrals([]);
      })
      .finally(() => {
        if (isMounted) setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, []);
  
  // Inheritance config state
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('Inviter: 200 coins · Invitee: 100 coins');
  const [configModal, setConfigModal] = useState(false);
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleAction = async (row, actionType) => {
    const newStatus = actionType === 'clear' ? 'COMPLETED' : 'BLOCKED';
    const newRisk = actionType === 'clear' ? 'CLEARED' : 'FRAUD_CONFIRMED';
    
    setReferrals(prev => prev.map(r =>
      r.id === row.id ? { ...r, status: newStatus, fraudRisk: newRisk } : r
    ));

    await logAdminAction({
      action: `REFERRAL_${actionType.toUpperCase()}`,
      module: 'Referrals',
      targetType: 'referral_code',
      targetId: row.id,
      targetName: row.referralCode,
      reason: `Anti-abuse manual override set as ${actionType}`,
      riskLevel: 'HIGH',
    });

    showFeedback(`Referral code ${row.referralCode} status set to ${newStatus}.`);
  };

  const handleSaveInheritance = async () => {
    await logAdminAction({
      action: 'REFERRALS_INHERITANCE_UPDATED',
      module: 'Referrals',
      targetType: 'referral_config',
      targetId: 'milestones',
      reason: `Set scope to ${scope} with override: ${overrideValue}`,
      riskLevel: 'MEDIUM',
    });
    showFeedback('Referral rewards calculation settings updated.');
    setConfigModal(false);
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
    }
    showFeedback('Referral rewards scope override reset to parent.');
  };

  const filtered = useMemo(() => {
    const q = search.toLowerCase();
    return referrals.filter((r) => {
      return !q || r.referralCode.toLowerCase().includes(q) || r.inviter.toLowerCase().includes(q) || r.invitee.toLowerCase().includes(q);
    });
  }, [search, referrals]);

  const columns = [
    {
      key: 'code',
      header: 'Referral Code',
      render: (r) => <span className="text-xs font-mono font-bold text-gold-400">{r.referralCode}</span>,
    },
    {
      key: 'country',
      header: 'Country',
      render: (r) => (
        <Badge variant="default" className="text-[10px] font-semibold flex items-center gap-1.5 px-2 py-0.5">
          <CountryFlag code={r.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(r.country)}</span>
        </Badge>
      ),
    },
    {
      key: 'inviter',
      header: 'Inviter Account',
      render: (r) => <span className="text-xs font-semibold text-white">{r.inviter}</span>,
    },
    {
      key: 'invitee',
      header: 'Invitee Account',
      render: (r) => <span className="text-xs text-slate-300">{r.invitee}</span>,
    },
    {
      key: 'reward',
      header: 'Coins Rewarded',
      render: (r) => <span className="text-xs font-mono font-bold text-yellow-400">🪙 +{r.rewardEarnedCoins}</span>,
    },
    {
      key: 'fraud',
      header: 'Anti-Abuse Check',
      render: (r) => {
        let variant = 'success';
        if (r.fraudRisk === 'FLAGGED') variant = 'warning';
        if (r.fraudRisk === 'FRAUD_CONFIRMED') variant = 'danger';
        return <Badge variant={variant}>{r.fraudRisk}</Badge>;
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => {
        let variant = 'neutral';
        if (r.status === 'COMPLETED') variant = 'success';
        if (r.status === 'SUSPICIOUS') variant = 'warning';
        if (r.status === 'BLOCKED') variant = 'danger';
        return <Badge variant={variant}>{r.status}</Badge>;
      },
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (r) => (
        <div className="flex gap-1.5">
          {r.status === 'SUSPICIOUS' && (
            <>
              <Button variant="primary" size="xs" onClick={() => handleAction(r, 'clear')}>
                Approve & Clear
              </Button>
              <Button variant="danger" size="xs" onClick={() => handleAction(r, 'block')}>
                Block & Revoke
              </Button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Share2 className="h-6 w-6 text-gold-400" />
            Referral System & Growth Matrix
          </h1>
          <p className="text-sm text-slate-400 mt-0.5 font-sans">Track referral conversions, configure milestone rewards, and run anti-abuse audits.</p>
        </div>

        <Button variant="outline" size="sm" onClick={() => setConfigModal(true)} leftIcon={Settings}>
          Configure referral Rewards
        </Button>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      <Card className="p-4">
        <Input
          placeholder="Search by referral code, inviter handle, or invitee username..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={filtered} isLoading={isLoading} emptyTitle="No referral records found" emptyDescription="No user referral conversions recorded yet." />

      {/* Rewards Configuration Modal */}
      {configModal && (
        <Modal
          isOpen={true}
          onClose={() => setConfigModal(false)}
          title="Referral Milestone Rewards Settings"
          size="lg"
        >
          <div className="space-y-4">
            <GeographicInheritancePanel
              scope={scope}
              onChangeScope={setScope}
              inheritedValue={inheritedValue}
              overrideValue={overrideValue}
              onChangeOverride={setOverrideValue}
              effectiveValue={overrideValue || inheritedValue}
              onResetScope={handleResetScope}
              label="milestone reward rules scope inheritance"
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setConfigModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save config settings
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
