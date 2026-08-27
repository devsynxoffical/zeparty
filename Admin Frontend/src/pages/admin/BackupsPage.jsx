// ============================================================
// ZeParty Admin Portal — Backup & Disaster Recovery (JSX)
// Interactive Restore Simulation Modal
// ============================================================

import React, { useState } from 'react';
import { HardDrive, RotateCcw, CheckCircle2 } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { useAuditLog } from '../../context/AuditLogContext';

const MOCK_BACKUPS = [
  { id: 'BAK-2026-08-20', type: 'Automated Daily Full', size: '14.2 GB', date: '2026-08-20T03:00:00Z', status: 'COMPLETED' },
  { id: 'BAK-2026-08-19', type: 'Automated Daily Full', size: '13.8 GB', date: '2026-08-19T03:00:00Z', status: 'COMPLETED' },
];

export function BackupsPage() {
  const { logAdminAction } = useAuditLog();
  const [selectedBackup, setSelectedBackup] = useState(null);
  const [isRestoring, setIsRestoring] = useState(false);
  const [restoreMsg, setRestoreMsg] = useState(null);

  const handleExecuteRestore = () => {
    if (!selectedBackup) return;
    setIsRestoring(true);
    setTimeout(async () => {
      
      await logAdminAction({
        action: 'DB_RESTORE_SIMULATION',
        module: 'SystemSettings',
        targetType: 'database_backup',
        targetId: selectedBackup.id,
        targetName: selectedBackup.id,
        reason: 'Executed manual database snapshot restore verification',
        riskLevel: 'CRITICAL',
      });

      setIsRestoring(false);
      setRestoreMsg(`Restoration simulation for "${selectedBackup.id}" completed successfully! Snapshot verified.`);
      setSelectedBackup(null);
      setTimeout(() => setRestoreMsg(null), 3500);
    }, 1200);
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <HardDrive className="h-6 w-6 text-gold-400" />
            Backup & Disaster Recovery
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Frontend UI for database snapshot inspection and retention settings.</p>
        </div>
      </div>

      {restoreMsg && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{restoreMsg}</span>
          <span className="font-mono">VERIFIED</span>
        </div>
      )}

      <DataTable
        columns={[
          { key: 'id', header: 'Backup Snapshot ID', render: (r) => <span className="text-xs font-mono font-bold text-white">{r.id}</span> },
          { key: 'type', header: 'Type', render: (r) => <Badge variant="purple">{r.type}</Badge> },
          { key: 'size', header: 'Archive Size', render: (r) => <span className="text-xs font-mono text-slate-300">{r.size}</span> },
          { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status.toLowerCase()} /> },
          { key: 'actions', header: 'Actions', render: (r) => (
            <Button variant="outline" size="xs" onClick={() => setSelectedBackup(r)}>
              Simulate Restore
            </Button>
          )},
        ]}
        data={MOCK_BACKUPS}
        isLoading={false}
      />

      {selectedBackup && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedBackup(null)}
          title={`Disaster Recovery: Restore ${selectedBackup.id}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p className="bg-amber-500/10 border border-amber-500/30 p-3 rounded-lg text-amber-400 font-medium">
              Simulation Mode: Testing restoration process for archive archive size <strong className="text-white">{selectedBackup.size}</strong>.
            </p>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedBackup(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleExecuteRestore} isLoading={isRestoring}>
                Execute Restore Test
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
