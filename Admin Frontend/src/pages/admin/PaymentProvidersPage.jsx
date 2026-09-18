// ============================================================
// ZeParty Admin Portal — Payment Provider Settings (JSX)
// Interactive Gateway Configuration Modal
// ============================================================

import React, { useState, useEffect } from 'react';
import { CreditCard, ShieldCheck, Settings } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import {
  getPaymentProviders,
  updatePaymentProvider,
} from '../../services/modules/paymentProvider.service';

export function PaymentProvidersPage() {
  const [providers, setProviders] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [selectedProvider, setSelectedProvider] = useState(null);
  const [fee, setFee] = useState('');
  const [limits, setLimits] = useState('');
  const [status, setStatus] = useState('ACTIVE');
  const [isSandbox, setIsSandbox] = useState(true);
  const [savedMessage, setSavedMessage] = useState(null);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    loadProviders();
  }, []);

  async function loadProviders() {
    setIsLoading(true);
    try {
      const data = await getPaymentProviders({ includeInactive: true });
      setProviders(data);
    } catch (err) {
      console.error('Failed to load payment providers:', err);
    } finally {
      setIsLoading(false);
    }
  }

  const handleOpenConfig = (p) => {
    setSelectedProvider(p);
    setFee(p.fee);
    setLimits(p.limits);
    setStatus(p.status);
    setIsSandbox(p.isSandbox);
  };

  const handleSaveConfig = async () => {
    if (!selectedProvider) return;
    setIsSaving(true);
    try {
      await updatePaymentProvider(selectedProvider.id, {
        fee,
        limits,
        status,
        isSandbox,
      });
      setSavedMessage(`Gateway "${selectedProvider.name}" updated successfully.`);
      setSelectedProvider(null);
      await loadProviders();
      setTimeout(() => setSavedMessage(null), 3000);
    } catch (err) {
      console.error('Failed to save provider config:', err);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-emerald-400" />
            Payment Provider Configurations
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage online gateway integrations, processing fees, masked credentials, and transaction limits.
          </p>
        </div>
      </div>

      {savedMessage && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{savedMessage}</span>
          <span className="font-mono">200 OK</span>
        </div>
      )}

      <DataTable
        columns={[
          { key: 'name', header: 'Provider Name', render: (r) => <span className="text-xs font-bold text-white">{r.name}</span> },
          { key: 'fee', header: 'Processing Fee', render: (r) => <span className="text-xs text-slate-300">{r.fee}</span> },
          { key: 'limits', header: 'Transaction Limits', render: (r) => <span className="text-xs font-mono text-gold-400">{r.limits}</span> },
          { key: 'apiKey', header: 'Masked API Key', render: (r) => <code className="text-xs font-mono text-slate-400">{r.apiKey}</code> },
          { key: 'mode', header: 'Environment', render: (r) => (
            <Badge variant={r.isSandbox ? 'warning' : 'success'}>
              {r.isSandbox ? 'SANDBOX' : 'PRODUCTION'}
            </Badge>
          )},
          { key: 'status', header: 'Gateway Status', render: (r) => <StatusBadge status={r.status.toLowerCase()} /> },
          { key: 'actions', header: 'Actions', render: (r) => (
            <Button variant="outline" size="xs" onClick={() => handleOpenConfig(r)}>
              Configure
            </Button>
          )},
        ]}
        data={providers}
        isLoading={isLoading}
      />

      {selectedProvider && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedProvider(null)}
          title={`Configure Gateway: ${selectedProvider.name}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input label="Processing Fee Description" value={fee} onChange={(e) => setFee(e.target.value)} required />
            <Input label="Transaction Limits ($ USD)" value={limits} onChange={(e) => setLimits(e.target.value)} required />

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-xs font-medium text-slate-300 block mb-1">Gateway Status</label>
                <select
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none"
                  value={status}
                  onChange={(e) => setStatus(e.target.value)}
                >
                  <option value="ACTIVE">ACTIVE</option>
                  <option value="DISABLED">DISABLED</option>
                </select>
              </div>

              <div>
                <label className="text-xs font-medium text-slate-300 block mb-1">Environment Mode</label>
                <select
                  className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none"
                  value={isSandbox ? 'SANDBOX' : 'PRODUCTION'}
                  onChange={(e) => setIsSandbox(e.target.value === 'SANDBOX')}
                >
                  <option value="SANDBOX">SANDBOX (Test Mode)</option>
                  <option value="PRODUCTION">PRODUCTION (Live Mode)</option>
                </select>
              </div>
            </div>

            <div className="p-3 bg-slate-900 border border-slate-700 rounded-lg text-slate-400 text-xs">
              <span className="font-semibold text-slate-200">Security Invariant:</span> Credentials are encrypted via AES-256-GCM in the backend database. Decrypted raw API secrets are never transmitted to or displayed in the browser.
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedProvider(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" disabled={isSaving} onClick={handleSaveConfig}>
                {isSaving ? 'Saving...' : 'Save Provider Settings'}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
