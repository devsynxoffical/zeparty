// ============================================================
// ZeParty Admin Portal — Economy & Policy Settings Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState } from 'react';
import {
  Sliders, Save, History, Calendar, CheckCircle2, ShieldAlert, DollarSign,
  Plus, Trash, RefreshCw, BarChart3, ShieldCheck, Edit3
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import {
  CURRENT_ECONOMY_POLICY,
  CURRENT_LIVE_HOST_POLICY,
  CURRENT_AUDIO_HOST_POLICY,
  CURRENT_RESELLER_POLICY,
  CURRENT_MERCHANT_POLICY,
  CURRENT_MANAGER_POLICY,
  POLICY_HISTORIES
} from '../../mocks/policyConfig.mock';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountrySelect } from '../../components/ui/CountrySelect';

export function EconomySettingsPage() {
  const { logAdminAction } = useAuditLog();
  const [activeTab, setActiveTab] = useState('manager'); // 'manager' | 'live_host' | 'agency_host' | 'reseller' | 'merchant' | 'simulator'
  const [selectedCountry, setSelectedCountry] = useState('All');
  
  // Policies State
  const [managerPolicy, setManagerPolicy] = useState(CURRENT_MANAGER_POLICY);
  const [liveHostPolicy, setLiveHostPolicy] = useState(CURRENT_LIVE_HOST_POLICY);
  const [resellerPolicy, setResellerPolicy] = useState(CURRENT_RESELLER_POLICY);
  const [merchantPolicy, setMerchantPolicy] = useState(CURRENT_MERCHANT_POLICY);
  const [economyPolicy, setEconomyPolicy] = useState(CURRENT_ECONOMY_POLICY);

  // Simulator State
  const [simAmount, setSimAmount] = useState('100');
  const [customAmount, setCustomAmount] = useState('');

  // Versioning state
  const [applyFromDate, setApplyFromDate] = useState('2026-09-01');
  const [isSaving, setIsSaving] = useState(false);
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 4000);
  };

  const handleSavePolicy = async (policyArea) => {
    setIsSaving(true);
    await logAdminAction({
      action: 'UPDATE_ECONOMY_POLICY',
      module: 'Economy',
      targetType: 'policy',
      targetId: policyArea,
      reason: `${policyArea} policy updated. Applied from ${applyFromDate}`,
      riskLevel: 'HIGH',
    });
    setTimeout(() => {
      setIsSaving(false);
      showFeedback(`Policy updates for "${policyArea.toUpperCase()}" scheduled successfully! applied from ${applyFromDate}.`);
    }, 800);
  };

  // Financial simulation math
  const simValue = Number(customAmount || simAmount || 0);
  const simResults = useMemo(() => {
    const platformShare = simValue * (economyPolicy.platformShare / 100);
    const agencyShare = simValue * (economyPolicy.agencyShare / 100);
    const hostBackup = simValue * (economyPolicy.hostBackup / 100);
    const roomReward = simValue * (economyPolicy.roomReward / 100);
    const hostShare = simValue - platformShare - agencyShare - roomReward - hostBackup;
    
    // Reseller profit (average 10%)
    const resellerMargin = simValue * 0.10;
    // Merchant profit (20%)
    const merchantMargin = simValue * 0.20;
    const fees = simValue * 0.03; // Gateway fees

    return {
      platformShare,
      hostShare,
      agencyShare,
      roomReward,
      hostBackup,
      resellerMargin,
      merchantMargin,
      fees,
      netOutcome: simValue - fees
    };
  }, [simValue, economyPolicy]);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Sliders className="h-6 w-6 text-gold-400" />
            Ecosystem policy Configuration
          </h1>
          <p className="text-sm text-slate-400 mt-0.5 font-sans">
            Primary configuration hub for platform margins, coin packages, host targets, and live splits simulations.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs text-slate-400 font-semibold">Target Country:</span>
            <CountrySelect value={selectedCountry} onChange={setSelectedCountry} />
          </div>
          <Badge variant="success">Status: CONFIGURABLE</Badge>
          <Badge variant="purple">Engine Version: v3.0.0</Badge>
        </div>
      </div>

      {feedback && (
        <div className="p-4 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-sm font-medium flex items-center gap-2 animate-pulse">
          <CheckCircle2 className="h-5 w-5" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Tab select bar */}
      <div className="flex flex-wrap gap-2 border-b border-slate-800 pb-3">
        {[
          { id: 'manager', label: 'Manager Policy' },
          { id: 'live_host', label: 'Live Host Tiers' },
          { id: 'reseller', label: 'Coin Resellers' },
          { id: 'merchant', label: 'Merchants Catalog' },
          { id: 'simulator', label: 'Financial Simulator' }
        ].map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-4 py-2 text-xs font-bold rounded-lg border transition-colors ${
              activeTab === tab.id
                ? 'bg-gold-500/20 border-gold-500/50 text-gold-400'
                : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* 1. Manager Policy Editor */}
      {activeTab === 'manager' && (
        <Card className="p-5 space-y-4">
          <div className="flex justify-between items-center border-b border-slate-800 pb-3">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider">Manager Eligibility Settings</h2>
            <Badge variant="info">Active Version: {managerPolicy.version}</Badge>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <Input
              label="Location Restrictions"
              value={managerPolicy.locationEligibility}
              onChange={(e) => setManagerPolicy({ ...managerPolicy, locationEligibility: e.target.value })}
            />
            <Input
              label="Team Requirement Details"
              value={managerPolicy.teamRequirement}
              onChange={(e) => setManagerPolicy({ ...managerPolicy, teamRequirement: e.target.value })}
            />
            <Input
              label="Maximum Monthly Work/Target ($ USD)"
              type="number"
              value={managerPolicy.maxMonthlyWorkTargetUSD}
              onChange={(e) => setManagerPolicy({ ...managerPolicy, maxMonthlyWorkTargetUSD: Number(e.target.value) })}
            />
            <Input
              label="Coins Seller Prerequisite Limit ($ USD)"
              type="number"
              value={managerPolicy.coinsSellerPrerequisiteUSD}
              onChange={(e) => setManagerPolicy({ ...managerPolicy, coinsSellerPrerequisiteUSD: Number(e.target.value) })}
            />
          </div>

          <div className="pt-3 border-t border-slate-800 flex justify-end">
            <Button variant="primary" onClick={() => handleSavePolicy('manager')} isLoading={isSaving}>
              Save Manager Policy Settings
            </Button>
          </div>
        </Card>
      )}

      {/* 2. Live Host Tiers Matrix (25 configurable levels) */}
      {activeTab === 'live_host' && (
        <Card className="p-5 space-y-4">
          <div className="flex justify-between items-center border-b border-slate-800 pb-3">
            <div>
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">25-Level Host incentive Matrix</h2>
              <p className="text-[10px] text-slate-400 mt-1">Minimum target required: {formatNumber(liveHostPolicy.minTargetCoins)} coins · 1h daily streams for 10 days</p>
            </div>
            <Badge variant="purple">v3.0.0 Matrix</Badge>
          </div>

          {/* Table display */}
          <div className="overflow-x-auto max-h-[400px] border border-slate-800 rounded-lg">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-slate-900 text-slate-400 font-semibold border-b border-slate-800">
                <tr>
                  <th className="p-2.5">Level</th>
                  <th className="p-2.5">Diamond Target (15d)</th>
                  <th className="p-2.5">Duration Days</th>
                  <th className="p-2.5">Basic Salary ($)</th>
                  <th className="p-2.5">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800">
                {liveHostPolicy.tiers.map((t, idx) => (
                  <tr key={idx} className="hover:bg-slate-900/40">
                    <td className="p-2.5 font-bold font-mono">L{t.level}</td>
                    <td className="p-2.5 font-mono text-gold-400 font-bold">{formatNumber(t.targetDiamonds)}</td>
                    <td className="p-2.5 font-mono">{t.durationDays} Days</td>
                    <td className="p-2.5 font-mono text-emerald-400 font-bold">${t.basicSalaryUSD}</td>
                    <td className="p-2.5">
                      <Button variant="ghost" size="xs" onClick={() => {
                        const newTarget = prompt(`Change target for L${t.level}:`, t.targetDiamonds);
                        if (newTarget) {
                          const updated = [...liveHostPolicy.tiers];
                          updated[idx] = { ...t, targetDiamonds: Number(newTarget) };
                          setLiveHostPolicy({ ...liveHostPolicy, tiers: updated });
                        }
                      }}>
                        Edit
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="pt-3 border-t border-slate-800 flex justify-end gap-2">
            <Button variant="outline" onClick={() => {
              const nextLevel = liveHostPolicy.tiers.length + 1;
              const newTiers = [...liveHostPolicy.tiers, { level: nextLevel, targetDiamonds: 60000000, durationDays: 5, basicSalaryUSD: 4800.00 }];
              setLiveHostPolicy({ ...liveHostPolicy, tiers: newTiers });
            }}>
              Add Level Tier
            </Button>
            <Button variant="primary" onClick={() => handleSavePolicy('live_host')} isLoading={isSaving}>
              Publish Tiers Update
            </Button>
          </div>
        </Card>
      )}

      {/* 3. Coin Resellers Policy */}
      {activeTab === 'reseller' && (
        <Card className="p-5 space-y-4">
          <div className="flex justify-between items-center border-b border-slate-800 pb-3">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider">Authorized Resellers Pricing Tiers</h2>
            <Badge variant="success">Verification Required</Badge>
          </div>

          <div className="space-y-3">
            {resellerPolicy.packages.map((pkg, idx) => (
              <div key={idx} className="p-3.5 rounded-xl bg-slate-900 border border-slate-800 flex flex-wrap justify-between items-center gap-3 text-xs">
                <div>
                  <p className="font-bold text-white">{pkg.tierName}</p>
                  <p className="text-slate-400 font-mono">Price: ${pkg.priceUSD} | Coins: {formatNumber(pkg.totalCoins)}</p>
                </div>
                <div className="flex items-center gap-3">
                  <Input
                    label="Adjust Profit %"
                    type="number"
                    value={pkg.profitPercent}
                    onChange={(e) => {
                      const updated = [...resellerPolicy.packages];
                      updated[idx] = { ...pkg, profitPercent: Number(e.target.value) };
                      setResellerPolicy({ ...resellerPolicy, packages: updated });
                    }}
                    containerClassName="w-24"
                  />
                </div>
              </div>
            ))}
          </div>

          <div className="pt-3 border-t border-slate-800 flex justify-end">
            <Button variant="primary" onClick={() => handleSavePolicy('reseller')} isLoading={isSaving}>
              Save Resellers Configuration
            </Button>
          </div>
        </Card>
      )}

      {/* 4. Merchant Policy Editor */}
      {activeTab === 'merchant' && (
        <Card className="p-5 space-y-4">
          <div className="flex justify-between items-center border-b border-slate-800 pb-3">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider">Merchant Portal Licensing Specifications</h2>
            <Badge variant="warning">Portal Entry: $3,000</Badge>
          </div>

          <div className="grid md:grid-cols-2 gap-4">
            <Input
              label="Standard Portal Entrance Cost ($ USD)"
              type="number"
              value={merchantPolicy.priceUSD}
              onChange={(e) => setMerchantPolicy({ ...merchantPolicy, priceUSD: Number(e.target.value) })}
            />
            <Input
              label="Merchant Profit Margin Split (%)"
              type="number"
              value={merchantPolicy.profitPercent}
              onChange={(e) => setMerchantPolicy({ ...merchantPolicy, profitPercent: Number(e.target.value) })}
            />
            <Input
              label="Coins Allotment"
              type="number"
              value={merchantPolicy.totalCoins}
              onChange={(e) => setMerchantPolicy({ ...merchantPolicy, totalCoins: Number(e.target.value) })}
            />
            <Input
              label="New Portal Minimum Amount limit ($)"
              type="number"
              value={merchantPolicy.minPortalOpenAmountUSD}
              onChange={(e) => setMerchantPolicy({ ...merchantPolicy, minPortalOpenAmountUSD: Number(e.target.value) })}
            />
          </div>

          <div className="pt-3 border-t border-slate-800 flex justify-end">
            <Button variant="primary" onClick={() => handleSavePolicy('merchant')} isLoading={isSaving}>
              Save Merchants Configuration
            </Button>
          </div>
        </Card>
      )}

      {/* 5. Financial Simulator */}
      {activeTab === 'simulator' && (
        <div className="grid md:grid-cols-3 gap-6">
          {/* Controls */}
          <Card className="p-5 space-y-4 md:col-span-1">
            <h3 className="text-sm font-bold text-white uppercase tracking-wider">Simulation Inputs</h3>
            <div className="space-y-3">
              <label className="text-xs font-bold text-slate-400 block">Preset Gross Transaction Amount</label>
              <div className="grid grid-cols-4 gap-1.5">
                {['1', '10', '100', '1000'].map((amt) => (
                  <button
                    key={amt}
                    onClick={() => { setSimAmount(amt); setCustomAmount(''); }}
                    className={`py-1.5 rounded font-mono font-bold text-xs border ${
                      simAmount === amt && !customAmount ? 'bg-gold-500/20 border-gold-500 text-gold-400' : 'bg-slate-900 border-slate-800 text-slate-400'
                    }`}
                  >
                    ${amt}
                  </button>
                ))}
              </div>

              <Input
                label="Or Custom Simulation Amount ($)"
                type="number"
                value={customAmount}
                onChange={(e) => setCustomAmount(e.target.value)}
                placeholder="e.g. 5000"
              />
            </div>

            <div className="p-3 bg-slate-900 border border-slate-800 rounded-lg space-y-2 text-xs">
              <p className="font-bold text-white">Active Split Rules:</p>
              <p>Platform Share: {economyPolicy.platformShare}%</p>
              <p>Agency Commission: {economyPolicy.agencyShare}%</p>
              <p>Host Backup: {economyPolicy.hostBackup}%</p>
              <p>Room Reward: {economyPolicy.roomReward}%</p>
            </div>
          </Card>

          {/* Results visualization */}
          <Card className="p-5 md:col-span-2 space-y-4">
            <h3 className="text-sm font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
              <BarChart3 className="h-4 w-4 text-emerald-400" /> Simulated Split Outcomes & Margins
            </h3>

            <div className="bg-slate-950 p-4 rounded-xl border border-slate-900 grid grid-cols-2 gap-4">
              <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
                <p className="text-xs text-slate-400">Total Simulation Value</p>
                <p className="text-2xl font-black text-white font-mono">${simValue.toFixed(2)}</p>
              </div>
              <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
                <p className="text-xs text-slate-400">Estimated Gateway Fees (3%)</p>
                <p className="text-2xl font-black text-rose-400 font-mono">${simResults.fees.toFixed(2)}</p>
              </div>
            </div>

            <div className="space-y-2 text-xs">
              <p className="font-semibold text-slate-300">Revenue Splits Breakdown:</p>
              {[
                { label: `Platform Share (${economyPolicy.platformShare}%)`, value: simResults.platformShare, color: 'bg-blue-600', text: 'text-blue-400' },
                { label: 'Host basic Salary Share', value: simResults.hostShare, color: 'bg-emerald-600', text: 'text-emerald-400' },
                { label: `Agency Commission Split (${economyPolicy.agencyShare}%)`, value: simResults.agencyShare, color: 'bg-purple-600', text: 'text-purple-400' },
                { label: `Weekly Room Reward (${economyPolicy.roomReward}%)`, value: simResults.roomReward, color: 'bg-indigo-600', text: 'text-indigo-400' },
                { label: `Host backup Guarantee (${economyPolicy.hostBackup}%)`, value: simResults.hostBackup, color: 'bg-amber-600', text: 'text-amber-400' },
                { label: 'Coin Seller margin (Average 10%)', value: simResults.resellerMargin, color: 'bg-yellow-600', text: 'text-yellow-400' },
                { label: 'Merchant License margin (20%)', value: simResults.merchantMargin, color: 'bg-orange-600', text: 'text-orange-400' }
              ].map((row, idx) => {
                const pct = simValue > 0 ? Math.round((row.value / simValue) * 100) : 0;
                return (
                  <div key={idx} className="space-y-1">
                    <div className="flex justify-between font-mono">
                      <span>{row.label}</span>
                      <strong className={row.text}>${row.value.toFixed(2)} ({pct}%)</strong>
                    </div>
                    <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                      <div className={`h-1.5 rounded-full ${row.color}`} style={{ width: `${pct}%` }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </Card>
        </div>
      )}

      {/* Versioning Scheduling Footer */}
      <Card className="p-4 border-gold-500/20 bg-gold-950/5">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="text-xs text-slate-400">
            <p className="font-bold text-white flex items-center gap-1.5"><Calendar className="h-3.5 w-3.5 text-gold-400" /> Version Lifecycle Scheduling</p>
            <p className="mt-0.5">Ensure you specify the effective date. Rolling changes requires super administrator review.</p>
          </div>
          <div className="flex items-center gap-2">
            <Input
              type="date"
              value={applyFromDate}
              onChange={(e) => setApplyFromDate(e.target.value)}
              containerClassName="w-40"
            />
          </div>
        </div>
      </Card>

      {/* History Log */}
      <Card className="p-5">
        <h3 className="text-sm font-bold text-white uppercase tracking-wider mb-3 flex items-center gap-1.5">
          <History className="h-4 w-4 text-gold-400" /> Audit Log & Version History
        </h3>
        <div className="space-y-2">
          {POLICY_HISTORIES.map((h, i) => (
            <div key={i} className="p-3 bg-slate-900 border border-slate-800 rounded-xl flex justify-between items-center text-xs text-slate-300">
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="font-bold text-white">{h.policyType} Policy</span>
                  <Badge variant="purple">{h.version}</Badge>
                  <StatusBadge status={h.status.toLowerCase()} />
                </div>
                <p className="text-slate-400 mt-1 italic">{h.summary}</p>
              </div>
              <div className="text-right text-[11px] text-slate-500">
                <p>Apply From: {h.applyFrom}</p>
                <p>Approved By: {h.approvedBy}</p>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
