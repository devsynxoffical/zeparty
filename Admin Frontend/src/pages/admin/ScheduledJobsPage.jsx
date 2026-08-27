// ============================================================
// ZeParty Admin Portal — Scheduled Jobs & Cron Manager (JSX)
// Interactive Cron Job Trigger Controls
// ============================================================

import React, { useState } from 'react';
import { Clock, Play, RotateCcw, CheckCircle2 } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { useAuditLog } from '../../context/AuditLogContext';

const INITIAL_JOBS = [
  { id: 'job-1', name: 'Weekly Host Payout Settlement', schedule: 'Every Sunday 00:00 UTC', lastRun: '2026-08-17T00:00:00Z', nextRun: '2026-08-24T00:00:00Z', status: 'IDLE' },
  { id: 'job-2', name: 'Daily Reward Calculation', schedule: 'Every Day 00:00 UTC', lastRun: '2026-08-20T00:00:00Z', nextRun: '2026-08-21T00:00:00Z', status: 'COMPLETED' },
  { id: 'job-3', name: 'Audit Log Archival', schedule: 'Every 1st of Month', lastRun: '2026-08-01T00:00:00Z', nextRun: '2026-09-01T00:00:00Z', status: 'IDLE' },
];

export function ScheduledJobsPage() {
  const { logAdminAction } = useAuditLog();
  const [jobs, setJobs] = useState(INITIAL_JOBS);
  const [selectedJob, setSelectedJob] = useState(null);
  const [isRunning, setIsRunning] = useState(false);
  const [jobMsg, setJobMsg] = useState(null);

  const handleRunJob = () => {
    if (!selectedJob) return;
    setIsRunning(true);
    setTimeout(async () => {
      setJobs(jobs.map(j => j.id === selectedJob.id ? { ...j, status: 'COMPLETED', lastRun: new Date().toISOString() } : j));
      
      await logAdminAction({
        action: 'SCHEDULED_JOB_TRIGGERED',
        module: 'SystemSettings',
        targetType: 'scheduled_job',
        targetId: selectedJob.id,
        targetName: selectedJob.name,
        reason: 'Manual admin trigger of automation cron job',
        riskLevel: 'HIGH',
      });

      setIsRunning(false);
      setJobMsg(`Job "${selectedJob.name}" executed successfully!`);
      setSelectedJob(null);
      setTimeout(() => setJobMsg(null), 3000);
    }, 1000);
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Clock className="h-6 w-6 text-gold-400" />
            Scheduled Jobs & Automation Engine
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Frontend control for cron schedules, settlement jobs, and automated reward payouts.</p>
        </div>
      </div>

      {jobMsg && (
        <div className="p-3.5 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center justify-between">
          <span>{jobMsg}</span>
          <span className="font-mono">JOB SUCCESS</span>
        </div>
      )}

      <DataTable
        columns={[
          { key: 'name', header: 'Job Name', render: (r) => <span className="text-xs font-bold text-white">{r.name}</span> },
          { key: 'schedule', header: 'Cron Schedule', render: (r) => <Badge variant="purple">{r.schedule}</Badge> },
          { key: 'lastRun', header: 'Last Run', render: (r) => <span className="text-xs font-mono text-slate-400">{r.lastRun}</span> },
          { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.status.toLowerCase()} /> },
          { key: 'actions', header: 'Actions', render: (r) => (
            <Button variant="outline" size="xs" onClick={() => setSelectedJob(r)}>
              Trigger Job Now
            </Button>
          )},
        ]}
        data={jobs}
        isLoading={false}
      />

      {selectedJob && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedJob(null)}
          title={`Manual Job Execution: ${selectedJob.name}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>Are you sure you want to trigger the automated task <strong className="text-white">{selectedJob.name}</strong> immediately?</p>

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSelectedJob(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleRunJob} isLoading={isRunning}>
                Trigger Immediate Execution
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
