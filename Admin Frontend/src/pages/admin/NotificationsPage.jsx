// ============================================================
// ZeParty Admin Portal — Notification Broadcasts Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { Bell, Send, Search } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Select, Textarea } from '../../components/ui/Select';
import { getNotifications, broadcastNotification } from '../../services/modules/communications.service';
import { formatDate, formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

function BroadcastModal({ isOpen, onClose, onSent }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState('Push');
  const [audience, setAudience] = useState('All Users');
  const [isSending, setIsSending] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setIsSending(true);
    try {
      const created = await broadcastNotification({
        title,
        body,
        type,
        targetSegment: audience,
      });
      onSent(created);
      setTitle('');
      setBody('');
      onClose();
    } catch (err) {
      console.error('Failed to broadcast notification:', err);
    } finally {
      setIsSending(false);
    }
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Send Push Notification Broadcast" size="md">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input label="Notification Title" value={title} onChange={(e) => setTitle(e.target.value)} required placeholder="Short push notification title" />
        <div className="grid grid-cols-2 gap-3">
          <Select label="Type" value={type} onChange={(e) => setType(e.target.value)}>
            <option value="Push">Standard Push</option>
            <option value="Promotional">Promotional</option>
            <option value="Transactional">Transactional</option>
          </Select>
          <Select label="Target Audience" value={audience} onChange={(e) => setAudience(e.target.value)}>
            <option value="All Users">All Registered Users</option>
            <option value="Active Users">Active Users (7 Days)</option>
            <option value="VIP Users">VIP Members Only</option>
            <option value="Hosts Only">Verified Hosts Only</option>
          </Select>
        </div>
        <Textarea label="Message Body" value={body} onChange={(e) => setBody(e.target.value)} required rows={3} placeholder="Notification text payload…" />
        <div className="flex justify-end gap-2 pt-1">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSending}>Cancel</Button>
          <Button type="submit" variant="primary" size="sm" leftIcon={Send} isLoading={isSending}>
            Broadcast Now
          </Button>
        </div>
      </form>
    </Modal>
  );
}

export function NotificationsPage() {
  const { logAdminAction } = useAuditLog();
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [search, setSearch] = useState('');

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    getNotifications()
      .then((data) => {
        if (mounted) {
          setNotifications(data || []);
          setLoading(false);
        }
      })
      .catch((err) => {
        console.error('Failed to load notifications:', err);
        if (mounted) {
          setNotifications([]);
          setLoading(false);
        }
      });
    return () => { mounted = false; };
  }, []);

  const filtered = notifications.filter((n) => {
    const q = search.toLowerCase();
    return !q || n.title?.toLowerCase().includes(q) || n.body?.toLowerCase().includes(q);
  });

  const columns = [
    {
      key: 'title',
      header: 'Notification',
      render: (row) => (
        <div className="max-w-md">
          <p className="text-sm font-semibold text-white">{row.title}</p>
          <p className="text-xs text-slate-400 truncate">{row.body}</p>
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      render: (row) => <Badge variant="primary" className="text-[10px]">{row.type}</Badge>,
    },
    {
      key: 'audience',
      header: 'Audience',
      render: (row) => <span className="text-xs text-slate-300">{row.audience}</span>,
    },
    {
      key: 'recipients',
      header: 'Recipients',
      render: (row) => <span className="text-xs font-mono text-indigo-400">{formatNumber(row.recipients)}</span>,
    },
    {
      key: 'openRate',
      header: 'Open Rate',
      render: (row) => row.openRate > 0 ? (
        <span className="text-xs font-mono text-emerald-400">{row.openRate}%</span>
      ) : (
        <span className="text-xs text-slate-500">—</span>
      ),
    },
    {
      key: 'sentAt',
      header: 'Sent At',
      render: (row) => <span className="text-xs text-slate-400">{row.sentAt ? formatDate(row.sentAt) : 'Draft'}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status} />,
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Bell className="h-6 w-6 text-sky-400" aria-hidden="true" />
            Notification Broadcasts
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Send targeted push notifications to mobile users.</p>
        </div>
        <Button variant="primary" size="sm" leftIcon={Send} onClick={() => setModalOpen(true)}>
          New Broadcast
        </Button>
      </div>

      <Card className="p-4">
        <Input
          placeholder="Search notifications…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable
        columns={columns}
        data={filtered}
        emptyTitle="No broadcasts found"
        emptyDescription="No notification broadcasts match your search."
        pagination={{ page: 1, totalPages: 1, total: filtered.length }}
      />

      <BroadcastModal 
        isOpen={modalOpen} 
        onClose={() => setModalOpen(false)} 
        onSent={async (newNotif) => {
          setNotifications([newNotif, ...notifications]);
          await logAdminAction({
            action: 'NOTIFICATION_BROADCAST_SENT',
            module: 'Communications',
            targetType: 'notification_broadcast',
            targetId: newNotif.id,
            targetName: newNotif.title,
            reason: 'Manual push notification broadcast triggered',
            riskLevel: 'HIGH',
            afterValue: { type: newNotif.type, audience: newNotif.audience }
          });
        }}
      />
    </div>
  );
}
