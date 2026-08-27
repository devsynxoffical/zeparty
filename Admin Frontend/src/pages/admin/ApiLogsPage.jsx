// ============================================================
// ZeParty Admin Portal — API & Webhook Logs Page (JSX)
// Interactive Event Retry Simulation
// ============================================================

import React, { useState } from 'react';
import { Terminal, RefreshCw, CheckCircle2 } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';

const INITIAL_API_LOGS = [
  { id: 'LOG-901', endpoint: 'POST /v1/recharge/stripe-webhook', status: 200, duration: '45ms', timestamp: '2026-08-20T10:15:30Z' },
  { id: 'LOG-902', endpoint: 'POST /v1/withdraw/payout-trigger', status: 200, duration: '120ms', timestamp: '2026-08-20T11:00:00Z' },
  { id: 'LOG-903', endpoint: 'POST /v1/refund/coin-reclaim', status: 400, duration: '88ms', timestamp: '2026-08-20T11:20:00Z' },
];

export function ApiLogsPage() {
  const [logs, setLogs] = useState(INITIAL_API_LOGS);
  const [retryModalLog, setRetryModalLog] = useState(null);
  const [retrySuccessMsg, setRetrySuccessMsg] = useState(null);
  const [isRetrying, setIsRetrying] = useState(false);

  const handleExecuteRetry = () => {
    if (!retryModalLog) return;
    setIsRetrying(true);
    setTimeout(() => {
      setLogs(logs.map(l => l.id === retryModalLog.id ? { ...l, status: 200, duration: '52ms' } : l));
      setRetrySuccessMsg(`Event ${retryModalLog.id} successfully retried! Response 200 OK.`);
      setIsRetrying(false);
      setRetryModalLog(null);
      setTimeout(() => setRetrySuccessMsg(null), 3000);
    }, 1000);
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Terminal className="h-6 w-6 text-purple-400" />
            API & Webhook Inspection Logs
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Frontend simulation for REST API request traces and webhook delivery statuses.</p>
        </div>
      </div>

      {retrySuccessMsg && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{retrySuccessMsg}</span>
          <span className="font-mono">HTTP 200</span>
        </div>
      )}

      <DataTable
        columns={[
          { key: 'id', header: 'Request ID', render: (r) => <span className="text-xs font-mono font-bold text-white">{r.id}</span> },
          { key: 'endpoint', header: 'Endpoint', render: (r) => <code className="text-xs font-mono text-gold-400">{r.endpoint}</code> },
          { key: 'status', header: 'HTTP Code', render: (r) => <Badge variant={r.status === 200 ? 'success' : 'danger'}>{r.status}</Badge> },
          { key: 'duration', header: 'Duration', render: (r) => <span className="text-xs font-mono text-slate-400">{r.duration}</span> },
          { key: 'actions', header: 'Actions', render: (r) => (
            <Button variant="outline" size="xs" onClick={() => setRetryModalLog(r)}>
              Retry Event
            </Button>
          )},
        ]}
        data={logs}
        isLoading={false}
      />

      {retryModalLog && (
        <Modal
          isOpen={true}
          onClose={() => setRetryModalLog(null)}
          title={`Retry Event Webhook: ${retryModalLog.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>Re-send the webhook payload for request <code className="text-gold-400">{retryModalLog.endpoint}</code> to target endpoint.</p>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setRetryModalLog(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleExecuteRetry} isLoading={isRetrying}>
                Re-send Webhook Now
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
