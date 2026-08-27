// ============================================================
// ZeParty Admin Portal — Payment Provider Settings (JSX)
// Interactive Gateway Configuration Modal
// ============================================================

import React, { useState } from 'react';
import { CreditCard, ShieldCheck, Settings } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';

const INITIAL_PROVIDERS = [
  { id: 'gw-1', name: 'Stripe Payments', fee: '2.9% + $0.30', limits: '$10 - $5,000', status: 'ACTIVE', apiKey: 'pk_live_••••••••4892' },
  { id: 'gw-2', name: 'PayPal Express', fee: '3.4% + $0.30', limits: '$10 - $3,000', status: 'ACTIVE', apiKey: 'client_live_••••••••1102' },
  { id: 'gw-3', name: 'Binance Pay (Crypto)', fee: '0.5%', limits: '$20 - $10,000', status: 'ACTIVE', apiKey: 'binance_live_••••••••8819' },
];

export function PaymentProvidersPage() {
  const [providers, setProviders] = useState(INITIAL_PROVIDERS);
  const [selectedProvider, setSelectedProvider] = useState(null);
  const [fee, setFee] = useState('');
  const [limits, setLimits] = useState('');
  const [status, setStatus] = useState('ACTIVE');
  const [savedMessage, setSavedMessage] = useState(null);

  const handleOpenConfig = (p) => {
    setSelectedProvider(p);
    setFee(p.fee);
    setLimits(p.limits);
    setStatus(p.status);
  };

  const handleSaveConfig = () => {
    if (!selectedProvider) return;
    setProviders(providers.map(p => p.id === selectedProvider.id ? { ...p, fee, limits, status } : p));
    setSavedMessage(`Gateway "${selectedProvider.name}" updated successfully.`);
    setSelectedProvider(null);
    setTimeout(() => setSavedMessage(null), 3000);
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <CreditCard className="h-6 w-6 text-emerald-400" />
            Payment Provider Configurations
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage online gateway integrations, processing fees, masked credentials, and transaction limits.</p>
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
          { key: 'status', header: 'Gateway Status', render: (r) => <StatusBadge status={r.status.toLowerCase()} /> },
          { key: 'actions', header: 'Actions', render: (r) => (
            <Button variant="outline" size="xs" onClick={() => handleOpenConfig(r)}>
              Configure
            </Button>
          )},
        ]}
        data={providers}
        isLoading={false}
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

            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1">Gateway Status</label>
              <select
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none"
                value={status}
                onChange={(e) => setStatus(e.target.value)}
              >
                <option value="ACTIVE">ACTIVE</option>
                <option value="DISABLED">DISABLED</option>
                <option value="MAINTENANCE">MAINTENANCE</option>
              </select>
            </div>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedProvider(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveConfig}>
                Save Provider Settings
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
