// ============================================================
// ZeParty Admin Portal — Host Target Reconciliation & Reliability Panel
// NEW 10: Persistent Attribution, Dry-Run Reconciliation & Linked Reversals
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import {
  ShieldCheck, AlertTriangle, CheckCircle, RefreshCw, Play, Eye,
  RotateCcw, FileText, CheckCheck, Calendar, DollarSign, Layers,
  Search, Award, Info, ArrowRight, ShieldAlert
} from 'lucide-react';
import { Card } from '../ui/Card';
import { Button } from '../ui/Button';
import { Input } from '../ui/Input';
import { Badge, StatusBadge } from '../ui/Badge';
import { Modal } from '../ui/Modal';
import {
  previewTargetReconciliation,
  applyTargetReconciliation,
  reverseGiftTarget,
  getTargetReconciliationRuns,
} from '../../services/modules/hosts.service';
import { formatDate, formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import { usePermission } from '../../hooks/usePermission';

export function TargetReconciliationPanel({ showFeedback, activeHosts = [] }) {
  const { logAdminAction } = useAuditLog();
  const { hasPermission, isSuperAdmin, isOwner } = usePermission();

  const canApplyReconciliation = isOwner || isSuperAdmin || hasPermission('approve_reject_hosts');

  // Form State
  const [targetScope, setTargetScope] = useState('ALL');
  const [hostIdentifier, setHostIdentifier] = useState('');
  const [agencyId, setAgencyId] = useState('');
  const [targetPeriod, setTargetPeriod] = useState('');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  // Execution State
  const [isRunningPreview, setIsRunningPreview] = useState(false);
  const [isRunningApply, setIsRunningApply] = useState(false);
  const [previewResult, setPreviewResult] = useState(null);
  const [applyResult, setApplyResult] = useState(null);
  const [runError, setRunError] = useState(null);

  // Apply Confirmation Modal
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [confirmReason, setConfirmReason] = useState('');

  // Reversals State
  const [revTxId, setRevTxId] = useState('');
  const [revRef, setRevRef] = useState('');
  const [revReason, setRevReason] = useState('');
  const [isReversing, setIsReversing] = useState(false);
  const [revResult, setRevResult] = useState(null);
  const [revError, setRevError] = useState(null);

  // Historical Runs
  const [runs, setRuns] = useState([]);
  const [isLoadingRuns, setIsLoadingRuns] = useState(false);
  const [inspectRun, setInspectRun] = useState(null);

  // Active run result to display (either latest apply or preview)
  const activeDisplayResult = applyResult || previewResult;

  const fetchRuns = async () => {
    setIsLoadingRuns(true);
    try {
      const res = await getTargetReconciliationRuns({ limit: 15 });
      setRuns(res?.data || []);
    } catch (err) {
      console.warn('Could not load historical reconciliation runs:', err.message);
    } finally {
      setIsLoadingRuns(false);
    }
  };

  useEffect(() => {
    fetchRuns();
  }, []);

  // 1. Dry Run Preview
  const handleRunPreview = async () => {
    setIsRunningPreview(true);
    setRunError(null);
    setApplyResult(null);
    try {
      const payload = {
        targetScope,
        hostIdentifier: hostIdentifier.trim() || undefined,
        agencyId: agencyId.trim() || undefined,
        targetPeriod: targetPeriod.trim() || undefined,
        startDate: startDate ? new Date(startDate).toISOString() : undefined,
        endDate: endDate ? new Date(endDate).toISOString() : undefined,
      };

      const res = await previewTargetReconciliation(payload);
      setPreviewResult(res.data);
      showFeedback(`Dry-run preview completed. Inspected ${res.data?.summary?.totalInspected || 0} gifts.`);
      fetchRuns();
    } catch (err) {
      const msg = err.response?.data?.message || err.message || 'Dry-run preview failed';
      setRunError(msg);
      showFeedback(`Error: ${msg}`);
    } finally {
      setIsRunningPreview(false);
    }
  };

  // 2. Open Confirm Apply Modal
  const handleOpenConfirmApply = () => {
    if (!previewResult) {
      showFeedback('Please run a Dry-Run Preview first to inspect proposed target attributions.');
      return;
    }
    setConfirmReason('');
    setShowConfirmModal(true);
  };

  // 3. Apply Reconciled Target Write
  const handleConfirmApply = async () => {
    if (!confirmReason.trim()) {
      showFeedback('Please provide an operational audit reason before applying corrections.');
      return;
    }

    setIsRunningApply(true);
    setRunError(null);
    try {
      const payload = {
        targetScope,
        hostIdentifier: hostIdentifier.trim() || undefined,
        agencyId: agencyId.trim() || undefined,
        targetPeriod: targetPeriod.trim() || undefined,
        startDate: startDate ? new Date(startDate).toISOString() : undefined,
        endDate: endDate ? new Date(endDate).toISOString() : undefined,
        reason: confirmReason.trim(),
      };

      const res = await applyTargetReconciliation(payload);
      setApplyResult(res.data);
      setPreviewResult(null);
      setShowConfirmModal(false);

      await logAdminAction({
        action: 'TARGET_RECONCILIATION_APPLIED',
        module: 'Hosts',
        targetType: 'reconciliation',
        targetId: res.data?.runId || 'run',
        targetName: `Scope: ${targetScope}`,
        reason: confirmReason.trim(),
        riskLevel: 'HIGH',
      });

      showFeedback(`Reconciliation applied successfully! Created ${res.data?.summary?.missingAttributionsCreated || 0} missing target attributions.`);
      fetchRuns();
    } catch (err) {
      const msg = err.response?.data?.message || err.message || 'Failed to apply reconciliation';
      setRunError(msg);
      showFeedback(`Error: ${msg}`);
    } finally {
      setIsRunningApply(false);
    }
  };

  // 4. Linked Target Reversal
  const handleExecuteReversal = async (e) => {
    e.preventDefault();
    if (!revTxId.trim()) {
      setRevError('Gift Transaction ID is required.');
      return;
    }
    if (!revRef.trim()) {
      setRevError('Unique Reference ID is required for audit traceability.');
      return;
    }

    setIsReversing(true);
    setRevError(null);
    setRevResult(null);
    try {
      const res = await reverseGiftTarget({
        giftTransactionId: revTxId.trim(),
        referenceId: revRef.trim(),
        reason: revReason.trim() || 'Administrative target reversal',
      });

      setRevResult(res.data);
      showFeedback(`Target reversal executed: Deducted ${formatNumber(res.data?.targetCoinsDeducted || 0)} coins.`);

      await logAdminAction({
        action: 'HOST_TARGET_REVERSED',
        module: 'Hosts',
        targetType: 'giftTransaction',
        targetId: revTxId.trim(),
        targetName: `Ref: ${revRef.trim()}`,
        reason: revReason.trim(),
        riskLevel: 'HIGH',
      });

      // Clear input fields
      setRevTxId('');
      setRevRef('');
      setRevReason('');
    } catch (err) {
      const msg = err.response?.data?.message || err.message || 'Target reversal failed';
      setRevError(msg);
      showFeedback(`Reversal failed: ${msg}`);
    } finally {
      setIsReversing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Overview & Rules Banner */}
      <Card className="p-5 border-amber-500/30 bg-amber-950/20">
        <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-2 mb-1">
              <Badge variant="warning" className="uppercase text-[10px] tracking-wider font-bold">
                NEW 10 Verified Engine
              </Badge>
              <span className="text-xs text-slate-400 font-mono">Authoritative Ledger Reconciliation</span>
            </div>
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-emerald-400" />
              Target Reliability & Missing-Progress Recovery
            </h2>
            <p className="text-xs text-slate-300 mt-1">
              Guarantees idempotent target counting via database-enforced unique gift transaction keys.
              Calculates normal gifts at <strong>100%</strong> of gross coin value and Lucky Gifts at <strong>10%</strong>.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={fetchRuns}
              disabled={isLoadingRuns}
              title="Refresh recent reconciliation audit runs"
            >
              <RefreshCw className={`w-3.5 h-3.5 mr-1 ${isLoadingRuns ? 'animate-spin' : ''}`} />
              Refresh Runs
            </Button>
          </div>
        </div>
      </Card>

      {/* Grid: Recovery Controls & Linked Reversals */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Reconcile Engine */}
        <Card className="p-5 lg:col-span-2 border-slate-800 space-y-4">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <div className="flex items-center gap-2">
              <Play className="w-4 h-4 text-gold-400" />
              <h3 className="text-sm font-bold text-white">Reconciliation & Missing Progress Recovery</h3>
            </div>
            <span className="text-xs text-slate-400">Preview (Dry Run) & Write Mode</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Target Scope</label>
              <select
                value={targetScope}
                onChange={(e) => setTargetScope(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-gold-500"
              >
                <option value="ALL">All Hosts (Live & Audio)</option>
                <option value="LIVE_HOST">Live Video Hosts (10-Day Cycles)</option>
                <option value="AUDIO_HOST">Social Audio Hosts (15-Day Cycles)</option>
              </select>
            </div>

            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Host (Public ID / UUID / @)</label>
              <Input
                placeholder="e.g. 9202535 or username"
                value={hostIdentifier}
                onChange={(e) => setHostIdentifier(e.target.value)}
                className="text-xs"
              />
            </div>

            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Agency ID (Optional)</label>
              <Input
                placeholder="UUID or Agency code"
                value={agencyId}
                onChange={(e) => setAgencyId(e.target.value)}
                className="text-xs"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Target Period Identifier</label>
              <Input
                placeholder="e.g. LIVE_HOST_2026-10_C2"
                value={targetPeriod}
                onChange={(e) => setTargetPeriod(e.target.value)}
                className="text-xs"
              />
            </div>

            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Start Date (Optional)</label>
              <Input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
                className="text-xs"
              />
            </div>

            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">End Date (Optional)</label>
              <Input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="text-xs"
              />
            </div>
          </div>

          {runError && (
            <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/30 text-red-400 text-xs flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 shrink-0 text-red-400" />
              <span>{runError}</span>
            </div>
          )}

          <div className="flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-slate-800">
            <p className="text-[11px] text-slate-400">
              ⚡ <strong>Safety Guarantee:</strong> Dry-run previews inspect verified ledger entries without modifying database records.
            </p>
            <div className="flex items-center gap-2">
              <Button
                variant="outline"
                size="sm"
                onClick={handleRunPreview}
                disabled={isRunningPreview || isRunningApply}
              >
                <Eye className="w-3.5 h-3.5 mr-1" />
                {isRunningPreview ? 'Inspecting Ledger...' : 'Run Dry-Run Preview'}
              </Button>

              <Button
                variant="primary"
                size="sm"
                onClick={handleOpenConfirmApply}
                disabled={isRunningPreview || isRunningApply || !previewResult || !canApplyReconciliation}
                title={!canApplyReconciliation ? 'Requires Host Administrator permission' : 'Apply write recovery'}
              >
                <CheckCheck className="w-3.5 h-3.5 mr-1" />
                Apply Write Recovery
              </Button>
            </div>
          </div>
        </Card>

        {/* Right Col: Linked Target Reversals */}
        <Card className="p-5 border-slate-800 space-y-4">
          <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
            <RotateCcw className="w-4 h-4 text-rose-400" />
            <h3 className="text-sm font-bold text-white">Linked Target Reversal</h3>
          </div>
          <p className="text-[11px] text-slate-400">
            Reverse target credit for a refunded or cancelled gift. Corrects both host and agency target totals idempotently.
          </p>

          <form onSubmit={handleExecuteReversal} className="space-y-3">
            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Gift Transaction ID *</label>
              <Input
                placeholder="UUID of gift transaction"
                value={revTxId}
                onChange={(e) => setRevTxId(e.target.value)}
                required
                className="text-xs"
              />
            </div>

            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Reference ID (Refund / Dispute) *</label>
              <Input
                placeholder="e.g. REF-2026-00492"
                value={revRef}
                onChange={(e) => setRevRef(e.target.value)}
                required
                className="text-xs"
              />
            </div>

            <div>
              <label className="block text-slate-400 text-xs mb-1 font-semibold">Reason</label>
              <Input
                placeholder="Reason for target deduction"
                value={revReason}
                onChange={(e) => setRevReason(e.target.value)}
                className="text-xs"
              />
            </div>

            {revError && (
              <div className="p-2.5 rounded bg-red-500/10 border border-red-500/30 text-red-400 text-xs">
                {revError}
              </div>
            )}

            {revResult && (
              <div className="p-2.5 rounded bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs space-y-1 font-mono">
                <p>✓ Reversal Status: {revResult.status}</p>
                <p>• Deducted: -{formatNumber(revResult.targetCoinsDeducted)} Target Coins</p>
                <p>• Target Period: {revResult.targetPeriod}</p>
              </div>
            )}

            <Button
              type="submit"
              variant="danger"
              size="sm"
              className="w-full"
              disabled={isReversing || !revTxId.trim() || !revRef.trim() || !canApplyReconciliation}
            >
              <RotateCcw className="w-3.5 h-3.5 mr-1" />
              {isReversing ? 'Processing Reversal...' : 'Execute Linked Reversal'}
            </Button>
          </form>
        </Card>
      </div>

      {/* Discrepancy & Verification Results Section */}
      {activeDisplayResult && (
        <Card className="p-5 border-slate-800 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-800 pb-3">
            <div className="flex items-center gap-2">
              <Award className="w-5 h-5 text-gold-400" />
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <span>Reconciliation Results</span>
                  <Badge variant={activeDisplayResult.mode === 'APPLIED' ? 'success' : 'warning'}>
                    {activeDisplayResult.mode}
                  </Badge>
                </h3>
                <p className="text-xs text-slate-400 font-mono">Run Identifier: {activeDisplayResult.runId}</p>
              </div>
            </div>
            <div className="text-right">
              <span className="text-xs text-slate-400">Target Period:</span>{' '}
              <strong className="text-xs text-white font-mono">{activeDisplayResult.targetPeriod}</strong>
            </div>
          </div>

          {/* Metrics Cards */}
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
              <p className="text-[11px] text-slate-400">Inspected Gifts</p>
              <p className="text-base font-bold text-white mt-1">
                {formatNumber(activeDisplayResult.summary?.totalInspected || 0)}
              </p>
            </div>

            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
              <p className="text-[11px] text-slate-400">Verified Completed</p>
              <p className="text-base font-bold text-emerald-400 mt-1">
                {formatNumber(activeDisplayResult.summary?.verifiedCompleted || 0)}
              </p>
            </div>

            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
              <p className="text-[11px] text-slate-400">Already Counted</p>
              <p className="text-base font-bold text-sky-400 mt-1">
                {formatNumber(activeDisplayResult.summary?.previouslyCounted || 0)}
              </p>
            </div>

            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
              <p className="text-[11px] text-slate-400">
                {activeDisplayResult.mode === 'APPLIED' ? 'Attributions Created' : 'Missing Attributions'}
              </p>
              <p className="text-base font-bold text-gold-400 mt-1">
                {formatNumber(
                  activeDisplayResult.mode === 'APPLIED'
                    ? activeDisplayResult.summary?.missingAttributionsCreated
                    : activeDisplayResult.summary?.missingAttributionsToCreate
                )}
              </p>
            </div>

            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
              <p className="text-[11px] text-slate-400">Skipped / Ineligible</p>
              <p className="text-base font-bold text-slate-400 mt-1">
                {formatNumber(activeDisplayResult.summary?.skippedIneligible || 0)}
              </p>
            </div>

            <div className="p-3 rounded-lg bg-slate-900 border border-slate-800">
              <p className="text-[11px] text-slate-400">Recovered Target Coins</p>
              <p className="text-base font-bold text-purple-400 mt-1">
                🪙 {formatNumber(activeDisplayResult.summary?.recoveredTargetCoins || 0)}
              </p>
            </div>
          </div>

          {/* Details Table */}
          <div className="space-y-2">
            <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">
              Transaction Inspection Log ({activeDisplayResult.details?.length || 0} Transactions)
            </h4>

            {activeDisplayResult.details && activeDisplayResult.details.length > 0 ? (
              <div className="overflow-x-auto rounded-lg border border-slate-800 max-h-96">
                <table className="w-full text-left text-xs">
                  <thead className="bg-slate-900/90 text-slate-400 font-semibold border-b border-slate-800 sticky top-0">
                    <tr>
                      <th className="p-2.5">Tx ID</th>
                      <th className="p-2.5">Sender</th>
                      <th className="p-2.5">Recipient Host</th>
                      <th className="p-2.5">Gift Details</th>
                      <th className="p-2.5">Gross Coins</th>
                      <th className="p-2.5">Target Coins</th>
                      <th className="p-2.5">Attribution Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60 font-mono">
                    {activeDisplayResult.details.map((tx) => (
                      <tr key={tx.transactionId} className="hover:bg-slate-900/50">
                        <td className="p-2.5 text-slate-400" title={tx.transactionId}>
                          {tx.transactionId.slice(0, 8)}...
                        </td>
                        <td className="p-2.5 text-slate-300">{tx.senderUsername || tx.senderId?.slice(0, 8)}</td>
                        <td className="p-2.5 text-gold-400">
                          {tx.recipientUsername || tx.recipientId?.slice(0, 8)}
                        </td>
                        <td className="p-2.5 text-slate-300">
                          <span className="font-sans font-medium">{tx.giftName}</span>{' '}
                          <span className={`text-[10px] px-1.5 py-0.5 rounded ${tx.isLucky ? 'bg-amber-500/20 text-amber-300' : 'bg-purple-500/20 text-purple-300'}`}>
                            {tx.isLucky ? 'Lucky (10%)' : 'Normal (100%)'}
                          </span>
                        </td>
                        <td className="p-2.5 text-white">{formatNumber(tx.grossCoins)}</td>
                        <td className="p-2.5 text-emerald-400 font-bold">+{formatNumber(tx.targetCoins)}</td>
                        <td className="p-2.5">
                          {tx.action === 'ALREADY_COUNTED' && (
                            <span className="text-sky-400 bg-sky-500/10 px-2 py-0.5 rounded text-[11px]">
                              Already Counted
                            </span>
                          )}
                          {tx.action === 'ATTRIBUTION_CREATED' && (
                            <span className="text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded text-[11px] font-bold">
                              ✓ Reconciled & Created
                            </span>
                          )}
                          {tx.action === 'MISSING_ATTRIBUTION_FOUND' && (
                            <span className="text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded text-[11px] font-bold">
                              ⚠ Missing (Will Recover)
                            </span>
                          )}
                          {tx.action === 'NON_HOST_RECIPIENT' && (
                            <span className="text-slate-500 bg-slate-800 px-2 py-0.5 rounded text-[11px]">
                              Ineligible (Non-Host)
                            </span>
                          )}
                          {tx.action === 'REVERSED_OR_CANCELLED' && (
                            <span className="text-rose-400 bg-rose-500/10 px-2 py-0.5 rounded text-[11px]">
                              Reversed
                            </span>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <p className="text-xs text-slate-500 italic p-3 bg-slate-900/50 rounded-lg">
                No matching gift transactions found in the specified cycle and scope.
              </p>
            )}
          </div>
        </Card>
      )}

      {/* Audit History: Historical Reconciliation Runs Table */}
      <Card className="p-5 border-slate-800 space-y-4">
        <div className="flex items-center justify-between border-b border-slate-800 pb-3">
          <div className="flex items-center gap-2">
            <FileText className="w-4 h-4 text-sky-400" />
            <h3 className="text-sm font-bold text-white">Reconciliation Audit Trail</h3>
          </div>
          <span className="text-xs text-slate-400">Persisted Operational History</span>
        </div>

        {runs && runs.length > 0 ? (
          <div className="overflow-x-auto rounded-lg border border-slate-800">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-900 text-slate-400 font-semibold border-b border-slate-800">
                <tr>
                  <th className="p-2.5">Run Identifier</th>
                  <th className="p-2.5">Execution Mode</th>
                  <th className="p-2.5">Scope</th>
                  <th className="p-2.5">Inspected</th>
                  <th className="p-2.5">Attributions Handled</th>
                  <th className="p-2.5">Admin ID</th>
                  <th className="p-2.5">Timestamp</th>
                  <th className="p-2.5">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 font-mono">
                {runs.map((r) => (
                  <tr key={r.id} className="hover:bg-slate-900/50">
                    <td className="p-2.5 text-white font-bold">{r.runIdentifier}</td>
                    <td className="p-2.5">
                      <span className={`px-2 py-0.5 rounded text-[10px] font-bold ${r.executionMode === 'APPLIED' ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40' : 'bg-amber-500/20 text-amber-400 border border-amber-500/40'}`}>
                        {r.executionMode}
                      </span>
                    </td>
                    <td className="p-2.5 text-slate-300 font-sans">{r.targetScope}</td>
                    <td className="p-2.5 text-white">{formatNumber(r.summaryReportJson?.totalInspected || 0)}</td>
                    <td className="p-2.5 text-gold-400">
                      {formatNumber(
                        r.executionMode === 'APPLIED'
                          ? r.summaryReportJson?.missingAttributionsCreated || 0
                          : r.summaryReportJson?.missingAttributionsToCreate || 0
                      )}
                    </td>
                    <td className="p-2.5 text-slate-400 font-sans">{r.adminId || 'System'}</td>
                    <td className="p-2.5 text-slate-400 font-sans">{formatDate(r.createdAt)}</td>
                    <td className="p-2.5">
                      <Button
                        variant="ghost"
                        size="xs"
                        onClick={() => setInspectRun(r)}
                      >
                        <Eye className="w-3.5 h-3.5 mr-1" /> Inspect
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-xs text-slate-500 italic p-4 text-center">
            No historical reconciliation runs logged yet. Execute a dry-run preview above to generate an auditable record.
          </p>
        )}
      </Card>

      {/* Confirmation Modal for Write Recovery */}
      {showConfirmModal && (
        <Modal
          isOpen={true}
          onClose={() => setShowConfirmModal(false)}
          title="Confirm Apply: Historical Target Reconciliation"
          size="md"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-3.5 rounded-xl bg-amber-950/30 border border-amber-500/40 space-y-2">
              <div className="flex items-center gap-2 text-amber-400 font-bold">
                <ShieldAlert className="w-4 h-4" />
                <span>Authoritative Target Adjustment Confirmation</span>
              </div>
              <p className="text-slate-300 leading-relaxed">
                You are about to apply write recovery for missing target attributions based on verified database gift ledger transactions.
              </p>
              <div className="bg-slate-900/80 p-2.5 rounded-lg space-y-1 font-mono text-[11px] border border-slate-800">
                <p>• Scope: <strong className="text-white">{targetScope}</strong></p>
                <p>• Period: <strong className="text-gold-400">{previewResult?.targetPeriod || 'Active'}</strong></p>
                <p>• Missing Attributions to Create: <strong className="text-emerald-400">+{previewResult?.summary?.missingAttributionsToCreate || 0}</strong></p>
                <p>• Recovered Target Coins: <strong className="text-purple-400">+{formatNumber(previewResult?.summary?.recoveredTargetCoins || 0)} 🪙</strong></p>
              </div>
              <p className="text-emerald-400 text-[11px] font-semibold">
                ✓ Idempotency Guarantee: Database unique constraints prevent duplicate attribution. Retrying will not double-count transactions.
              </p>
            </div>

            <div>
              <label className="block text-slate-400 mb-1 font-semibold">
                Administrative Reason / Ticket Reference *
              </label>
              <Input
                value={confirmReason}
                onChange={(e) => setConfirmReason(e.target.value)}
                placeholder="e.g. Audit reconciliation for missing gift targets per client confirmation"
                required
              />
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                disabled={isRunningApply}
                onClick={() => setShowConfirmModal(false)}
              >
                Cancel
              </Button>
              <Button
                variant="primary"
                size="sm"
                disabled={isRunningApply || !confirmReason.trim()}
                onClick={handleConfirmApply}
              >
                {isRunningApply ? 'Applying Recovery...' : 'Confirm & Apply Recovery'}
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Inspect Historical Run Modal */}
      {inspectRun && (
        <Modal
          isOpen={true}
          onClose={() => setInspectRun(null)}
          title={`Audit Run Details: ${inspectRun.runIdentifier}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300 font-mono">
            <div className="bg-slate-900 p-3 rounded-lg border border-slate-800 grid grid-cols-2 gap-2 text-xs">
              <div>Run ID: <strong className="text-white">{inspectRun.runIdentifier}</strong></div>
              <div>Mode: <strong className="text-gold-400">{inspectRun.executionMode}</strong></div>
              <div>Scope: <strong className="text-white">{inspectRun.targetScope}</strong></div>
              <div>Admin: <strong className="text-white">{inspectRun.adminId || 'System'}</strong></div>
              <div>Created: <strong className="text-slate-400">{formatDate(inspectRun.createdAt)}</strong></div>
            </div>

            <div className="space-y-1">
              <p className="font-bold text-slate-400 uppercase text-[11px]">Summary Report JSON:</p>
              <pre className="p-3 bg-slate-950 rounded-lg border border-slate-800 text-[11px] text-emerald-300 overflow-x-auto max-h-60">
                {JSON.stringify(inspectRun.summaryReportJson, null, 2)}
              </pre>
            </div>

            <div className="flex justify-end pt-2">
              <Button variant="ghost" size="sm" onClick={() => setInspectRun(null)}>
                Close
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
