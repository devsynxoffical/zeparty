// ============================================================
// ZeParty Admin Portal — Announcements Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { Megaphone, Plus, Pin, Trash2, Pencil } from 'lucide-react';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal, ConfirmDialog } from '../../components/ui/Modal';
import { Select, Textarea } from '../../components/ui/Select';
import {
  getAnnouncements,
  createAnnouncement,
} from '../../services/modules/communications.service';
import { formatDate } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

// ── Announcement Form Modal ───────────────────────────────────
function AnnouncementModal({ isOpen, onClose, ann, onSave }) {
  const isEdit = !!ann;
  const [title, setTitle]     = useState(ann?.title    || '');
  const [content, setContent] = useState(ann?.content  || '');
  const [type, setType]       = useState(ann?.type     || 'Maintenance');
  const [audience, setAudience] = useState(ann?.audience || 'All Users');
  const [pinned, setPinned]   = useState(ann?.pinned   || false);
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError]     = useState('');

  useEffect(() => {
    if (isOpen) {
      setTitle(ann?.title || '');
      setContent(ann?.content || '');
      setType(ann?.type || 'Maintenance');
      setAudience(ann?.audience || 'All Users');
      setPinned(ann?.pinned || false);
      setError('');
    }
  }, [isOpen, ann?.id]);

  async function handleSubmit(e) {
    e.preventDefault();
    setIsSaving(true);
    setError('');
    try {
      const payload = { title, content, type, audience, pinned };
      if (isEdit) {
        // No update service yet — optimistic local patch
        onSave({ ...ann, ...payload });
      } else {
        const newAnn = await createAnnouncement({ ...payload, publishNow: true });
        // Merge extra fields so the card renders properly
        onSave({ ...newAnn, title, content, type, audience, pinned, status: 'published', publishedAt: new Date().toISOString(), createdBy: 'Admin' }, 'create');
      }
      onClose();
    } catch {
      setError('Failed to save announcement. Please try again.');
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title={isEdit ? 'Edit Announcement' : 'New Announcement'} size="md">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input label="Title" value={title} onChange={(e) => setTitle(e.target.value)} required placeholder="Announcement headline" />
        <div className="grid grid-cols-2 gap-3">
          <Select label="Type" value={type} onChange={(e) => setType(e.target.value)}>
            <option value="Maintenance">Maintenance</option>
            <option value="Feature">Feature Update</option>
            <option value="Promotion">Promotion</option>
          </Select>
          <Select label="Target Audience" value={audience} onChange={(e) => setAudience(e.target.value)}>
            <option value="All Users">All Users</option>
            <option value="Hosts Only">Hosts Only</option>
            <option value="VIP Users">VIP Users Only</option>
          </Select>
        </div>
        <Textarea label="Content" value={content} onChange={(e) => setContent(e.target.value)} required rows={4} placeholder="Full announcement text…" />
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={pinned}
            onChange={(e) => setPinned(e.target.checked)}
            className="h-4 w-4 rounded border-slate-700 bg-slate-800 accent-indigo-600"
          />
          <span className="text-xs text-slate-300">Pin to top of in-app announcements</span>
        </label>
        {error && <p className="text-xs text-red-400">{error}</p>}
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSaving}>Cancel</Button>
          <Button type="submit" variant="primary" size="sm" isLoading={isSaving}>
            {isEdit ? 'Save Announcement' : 'Publish Announcement'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ── Page ──────────────────────────────────────────────────────
export function AnnouncementsPage() {
  const { logAdminAction } = useAuditLog();
  const [announcements, setAnnouncements] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [modal, setModal] = useState({ open: false, ann: null });
  const [deleteModal, setDeleteModal] = useState({ open: false, ann: null });
  const [isDeleting, setIsDeleting] = useState(false);

  // Load on mount
  useEffect(() => {
    getAnnouncements()
      .then((data) => setAnnouncements(data))
      .finally(() => setIsLoading(false));
  }, []);

  async function handleSave(updated, mode) {
    if (mode === 'create') {
      setAnnouncements((prev) => [updated, ...prev]);
      await logAdminAction({
        action: 'ANNOUNCEMENT_CREATED',
        module: 'Communications',
        targetType: 'announcement',
        targetId: updated.id,
        targetName: updated.title,
        reason: 'New system announcement published',
        riskLevel: 'MEDIUM',
      });
    } else {
      setAnnouncements((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));
      await logAdminAction({
        action: 'ANNOUNCEMENT_EDITED',
        module: 'Communications',
        targetType: 'announcement',
        targetId: updated.id,
        targetName: updated.title,
        reason: 'Announcement details modified',
        riskLevel: 'LOW',
      });
    }
  }

  async function handleDelete() {
    if (!deleteModal.ann) return;
    setIsDeleting(true);
    try {
      setAnnouncements((prev) => prev.filter((a) => a.id !== deleteModal.ann.id));
      await logAdminAction({
        action: 'ANNOUNCEMENT_DELETED',
        module: 'Communications',
        targetType: 'announcement',
        targetId: deleteModal.ann.id,
        targetName: deleteModal.ann.title,
        reason: 'Announcement removed from system',
        riskLevel: 'MEDIUM',
      });
    } finally {
      setIsDeleting(false);
      setDeleteModal({ open: false, ann: null });
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Megaphone className="h-6 w-6 text-indigo-400" aria-hidden="true" />
            System Announcements
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Broadcast platform announcements and banner notices.</p>
        </div>
        <Button variant="primary" size="sm" leftIcon={Plus} onClick={() => setModal({ open: true, ann: null })}>
          Create Announcement
        </Button>
      </div>

      {isLoading ? (
        <div className="text-center py-12 text-slate-400 text-sm">Loading announcements…</div>
      ) : (
        <div className="flex flex-col gap-4">
          {announcements.map((ann) => (
            <Card key={ann.id} className="p-5 flex flex-col gap-3">
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-center gap-2 flex-wrap">
                  {ann.pinned && (
                    <Badge variant="warning" className="flex items-center gap-1 text-[10px]">
                      <Pin className="h-3 w-3" /> Pinned
                    </Badge>
                  )}
                  <Badge variant="primary" className="text-[10px]">{ann.type}</Badge>
                  <Badge variant={ann.status === 'published' ? 'success' : 'muted'} className="text-[10px]">
                    {ann.status}
                  </Badge>
                  <span className="text-xs text-slate-500">• Audience: {ann.audience}</span>
                </div>
                <div className="flex gap-1">
                  <button
                    onClick={() => setModal({ open: true, ann })}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-700 transition-colors"
                  >
                    <Pencil className="h-3.5 w-3.5" />
                  </button>
                  <button
                    onClick={() => setDeleteModal({ open: true, ann })}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-red-400 hover:bg-slate-700 transition-colors"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              </div>
              <div>
                <h2 className="text-base font-semibold text-white">{ann.title}</h2>
                <p className="text-xs text-slate-300 mt-1 leading-relaxed">{ann.content}</p>
              </div>
              {ann.publishedAt && (
                <p className="text-[11px] text-slate-500 border-t border-slate-700/40 pt-2">
                  Published {formatDate(ann.publishedAt)} by {ann.createdBy}
                </p>
              )}
            </Card>
          ))}
          {announcements.length === 0 && (
            <div className="text-center py-12 text-slate-400 text-sm">No announcements yet.</div>
          )}
        </div>
      )}

      <AnnouncementModal
        isOpen={modal.open}
        onClose={() => setModal({ open: false, ann: null })}
        ann={modal.ann}
        onSave={handleSave}
      />
      <ConfirmDialog
        isOpen={deleteModal.open}
        onClose={() => setDeleteModal({ open: false, ann: null })}
        onConfirm={handleDelete}
        title="Delete Announcement"
        description={`Are you sure you want to delete "${deleteModal.ann?.title}"?`}
        confirmLabel="Delete"
        confirmVariant="danger"
        isLoading={isDeleting}
      />
    </div>
  );
}
