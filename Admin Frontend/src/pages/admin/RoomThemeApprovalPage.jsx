// ============================================================
// ZeParty Admin Portal — Room Theme Approval Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState } from 'react';
import { Sparkles, CheckCircle, XCircle, RefreshCw, Eye, Archive, Ban, FileText, AlertCircle, Save } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Badge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import { useAuditLog } from '../../context/AuditLogContext';

const INITIAL_THEMES = [
  {
    id: 'thm-001',
    themeName: 'Cyberpunk Neon Party',
    assetId: 'ast-902',
    creator: 'PixelVibe Studio',
    category: 'Entertainment',
    scope: 'GLOBAL',
    priceUSD: 4.99,
    status: 'pending',
    submittedAt: '2026-08-23T10:30:00Z',
    imageUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=300&auto=format&fit=crop',
    filesCount: 12,
    version: '1.0.0',
    auditTrail: [
      { action: 'Submitted', operator: 'PixelVibe Studio', timestamp: '2026-08-23T10:30:00Z', note: 'Initial release bundle' }
    ]
  },
  {
    id: 'thm-002',
    themeName: 'Classical Luxury VIP Room',
    assetId: 'ast-883',
    creator: 'Royal Designs',
    category: 'Talk Show',
    scope: 'REGION (Asia)',
    priceUSD: 0.00, // Free
    status: 'under_review',
    submittedAt: '2026-08-22T14:15:00Z',
    imageUrl: 'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?q=80&w=300&auto=format&fit=crop',
    filesCount: 8,
    version: '2.1.0',
    auditTrail: [
      { action: 'Submitted', operator: 'Royal Designs', timestamp: '2026-08-22T09:00:00Z', note: 'Uploaded asset file' },
      { action: 'Assigned Reviewer', operator: 'Operations Manager', timestamp: '2026-08-22T14:15:00Z', note: 'Auto-assigned for initial QA checks' }
    ]
  },
  {
    id: 'thm-003',
    themeName: 'Spooky Halloween Haunted Stage',
    assetId: 'ast-741',
    creator: 'SpookyCreations',
    category: 'PK Battle',
    scope: 'COUNTRY (US)',
    priceUSD: 2.99,
    status: 'approved',
    submittedAt: '2026-08-20T08:00:00Z',
    imageUrl: 'https://images.unsplash.com/photo-1508349937151-22b68b72d5b1?q=80&w=300&auto=format&fit=crop',
    filesCount: 15,
    version: '1.0.1',
    auditTrail: [
      { action: 'Approved', operator: 'Content Admin Sarah', timestamp: '2026-08-21T11:00:00Z', note: 'Staging preview matches mobile viewport' }
    ]
  }
];

export function RoomThemeApprovalPage() {
  const { logAdminAction } = useAuditLog();
  const [themes, setThemes] = useState(INITIAL_THEMES);
  const [selectedTheme, setSelectedTheme] = useState(null);
  const [actionModal, setActionModal] = useState({ open: false, theme: null, actionType: null });
  const [inputNote, setInputNote] = useState('');
  const [feedback, setFeedback] = useState(null);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleAction = async () => {
    if (!actionModal.theme) return;
    const { id, themeName } = actionModal.theme;
    const { actionType } = actionModal;

    let newStatus = 'approved';
    let auditAction = 'APPROVED';

    if (actionType === 'reject') {
      if (!inputNote.trim()) {
        alert('Rejection reason is required.');
        return;
      }
      newStatus = 'rejected';
      auditAction = 'REJECTED';
    } else if (actionType === 'changes') {
      if (!inputNote.trim()) {
        alert('Correction note is required.');
        return;
      }
      newStatus = 'changes_required';
      auditAction = 'CHANGES_REQUIRED';
    } else if (actionType === 'disable') {
      newStatus = 'disabled';
      auditAction = 'DISABLED';
    } else if (actionType === 'archive') {
      newStatus = 'archived';
      auditAction = 'ARCHIVED';
    }

    setThemes(prev => prev.map(t => {
      if (t.id === id) {
        const updatedAudit = [
          ...t.auditTrail,
          { action: auditAction, operator: 'Content Admin', timestamp: new Date().toISOString(), note: inputNote || `${actionType} action executed` }
        ];
        return { ...t, status: newStatus, auditTrail: updatedAudit };
      }
      return t;
    }));

    await logAdminAction({
      action: `ROOM_THEME_${auditAction}`,
      module: 'Content',
      targetType: 'room_theme',
      targetId: id,
      targetName: themeName,
      reason: inputNote || `Admin set status to ${newStatus}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Room theme "${themeName}" updated to ${newStatus}.`);
    setActionModal({ open: false, theme: null, actionType: null });
    setInputNote('');
  };

  const columns = [
    {
      key: 'theme',
      header: 'Theme Details',
      render: (row) => (
        <div className="flex items-center gap-3">
          <img
            src={row.imageUrl}
            alt={row.themeName}
            className="h-12 w-16 object-cover rounded-lg border border-slate-700 bg-slate-800"
          />
          <div>
            <p className="text-sm font-bold text-white">{row.themeName}</p>
            <p className="text-xs text-slate-400">ID: {row.id} • Asset ID: {row.assetId}</p>
          </div>
        </div>
      ),
    },
    {
      key: 'creator',
      header: 'Creator & Version',
      render: (row) => (
        <div>
          <p className="text-xs font-semibold text-slate-200">{row.creator}</p>
          <p className="text-[10px] text-slate-400 font-mono">v{row.version}</p>
        </div>
      ),
    },
    {
      key: 'scope_category',
      header: 'Scope / Category',
      render: (row) => (
        <div>
          <Badge variant="purple" className="mr-1">{row.category}</Badge>
          <span className="text-xs font-semibold text-slate-300 font-mono">{row.scope}</span>
        </div>
      ),
    },
    {
      key: 'price',
      header: 'Pricing',
      render: (row) => (
        <span className="text-xs font-bold text-emerald-400">
          {row.priceUSD > 0 ? `$${row.priceUSD.toFixed(2)}` : 'FREE'}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => {
        let variant = 'neutral';
        if (row.status === 'approved') variant = 'success';
        if (row.status === 'pending') variant = 'warning';
        if (row.status === 'under_review') variant = 'info';
        if (row.status === 'rejected') variant = 'danger';
        if (row.status === 'changes_required') variant = 'danger';
        return <Badge variant={variant}>{row.status.replace('_', ' ').toUpperCase()}</Badge>;
      },
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex items-center gap-1">
          <button
            title="Preview Details & History"
            onClick={() => setSelectedTheme(row)}
            className="p-1 rounded bg-slate-800 text-sky-400 hover:bg-slate-700 transition-colors"
          >
            <Eye className="h-4 w-4" />
          </button>

          {row.status === 'pending' || row.status === 'under_review' ? (
            <>
              <button
                title="Approve Theme"
                onClick={() => setActionModal({ open: true, theme: row, actionType: 'approve' })}
                className="p-1 rounded bg-slate-800 text-emerald-400 hover:bg-slate-700 transition-colors"
              >
                <CheckCircle className="h-4 w-4" />
              </button>
              <button
                title="Reject Theme"
                onClick={() => setActionModal({ open: true, theme: row, actionType: 'reject' })}
                className="p-1 rounded bg-slate-800 text-rose-400 hover:bg-slate-700 transition-colors"
              >
                <XCircle className="h-4 w-4" />
              </button>
              <button
                title="Request Changes"
                onClick={() => setActionModal({ open: true, theme: row, actionType: 'changes' })}
                className="p-1 rounded bg-slate-800 text-amber-400 hover:bg-slate-700 transition-colors"
              >
                <RefreshCw className="h-4 w-4" />
              </button>
            </>
          ) : (
            <>
              {row.status === 'approved' && (
                <button
                  title="Disable"
                  onClick={() => setActionModal({ open: true, theme: row, actionType: 'disable' })}
                  className="p-1 rounded bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-red-400 transition-colors"
                >
                  <Ban className="h-4 w-4" />
                </button>
              )}
              {row.status !== 'archived' && (
                <button
                  title="Archive"
                  onClick={() => setActionModal({ open: true, theme: row, actionType: 'archive' })}
                  className="p-1 rounded bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-amber-300 transition-colors"
                >
                  <Archive className="h-4 w-4" />
                </button>
              )}
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
            <Sparkles className="h-6 w-6 text-gold-400" />
            Room Theme Approval & Moderation
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Approve, reject, and request changes for custom-designed visual themes, room backdrops, and interactive stage assets.</p>
        </div>
      </div>

      {feedback && (
        <div className="p-4 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-sm font-medium flex items-center gap-2 animate-pulse">
          <CheckCircle className="h-5 w-5 text-emerald-400" />
          <span>{feedback}</span>
        </div>
      )}

      <Card className="p-5">
        <DataTable columns={columns} data={themes} isLoading={false} />
      </Card>

      {/* Details Modal */}
      {selectedTheme && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedTheme(null)}
          title={`Theme Info: ${selectedTheme.themeName}`}
        >
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <img
                  src={selectedTheme.imageUrl}
                  alt={selectedTheme.themeName}
                  className="w-full h-32 object-cover rounded-lg border border-slate-700 bg-slate-800"
                />
              </div>
              <div className="space-y-1.5 text-xs text-slate-300">
                <p><strong>Theme ID:</strong> {selectedTheme.id}</p>
                <p><strong>Asset ID:</strong> {selectedTheme.assetId}</p>
                <p><strong>Creator:</strong> {selectedTheme.creator}</p>
                <p><strong>Category:</strong> {selectedTheme.category}</p>
                <p><strong>Scope:</strong> {selectedTheme.scope}</p>
                <p><strong>Price:</strong> ${selectedTheme.priceUSD}</p>
                <p><strong>Status:</strong> <span className="uppercase text-gold-400 font-bold">{selectedTheme.status}</span></p>
                <p><strong>Files Included:</strong> {selectedTheme.filesCount} layers</p>
              </div>
            </div>

            <div className="border-t border-slate-700 pt-3">
              <h3 className="text-xs font-bold text-white mb-2 flex items-center gap-1.5">
                <FileText className="h-3.5 w-3.5 text-gold-400" /> Audit Log & Version History
              </h3>
              <div className="space-y-2 max-h-36 overflow-y-auto">
                {selectedTheme.auditTrail.map((log, idx) => (
                  <div key={idx} className="p-2 rounded bg-slate-900 border border-slate-800 text-[11px]">
                    <div className="flex justify-between font-mono text-[10px] text-slate-400">
                      <span>{log.action} by {log.operator}</span>
                      <span>{new Date(log.timestamp).toLocaleString()}</span>
                    </div>
                    <p className="text-slate-200 mt-0.5">{log.note}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="flex justify-end pt-2 border-t border-slate-700">
              <Button variant="outline" size="sm" onClick={() => setSelectedTheme(null)}>
                Close Window
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Action Dialog (Approve, Reject, Changes Required) */}
      {actionModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setActionModal({ open: false, theme: null, actionType: null })}
          title={`Confirm Action: ${actionModal.actionType.toUpperCase()}`}
        >
          <div className="space-y-4">
            <p className="text-sm text-slate-300">
              Are you sure you want to set the status of <strong>{actionModal.theme.themeName}</strong> to <strong className="text-white capitalize">{actionModal.actionType}d</strong>?
            </p>

            {(actionModal.actionType === 'reject' || actionModal.actionType === 'changes') && (
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-slate-400">
                  {actionModal.actionType === 'reject' ? 'Rejection Reason (Required)' : 'Correction & Feedback Notes (Required)'}
                </label>
                <Input
                  placeholder="Provide detailed comments..."
                  value={inputNote}
                  onChange={(e) => setInputNote(e.target.value)}
                  required
                />
              </div>
            )}

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="outline" size="sm" onClick={() => setActionModal({ open: false, theme: null, actionType: null })}>
                Cancel
              </Button>
              <Button
                variant={actionModal.actionType === 'approve' ? 'primary' : 'danger'}
                size="sm"
                onClick={handleAction}
              >
                Execute {actionModal.actionType.toUpperCase()}
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
