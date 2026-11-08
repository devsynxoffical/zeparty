// ============================================================
// ZeParty Admin Portal — Notification Broadcasts Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { Bell, Send, Search, RotateCcw, AlertCircle, CheckCircle } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Select, Textarea } from '../../components/ui/Select';
import { getNotifications, broadcastNotification, retryNotificationBroadcast } from '../../services/modules/communications.service';
import { formatDate, formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';

function BroadcastModal({ isOpen, onClose, onSent }) {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [type, setType] = useState('Push');
  const [audience, setAudience] = useState('All Users');
  const [destination, setDestination] = useState('zeparty://home');
  const [isSending, setIsSending] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!title.trim() || !body.trim()) {
      setError('Both title and message body are required.');
      return;
    }

    setIsSending(true);
    setError(null);
    try {
      const created = await broadcastNotification({
        title: title.trim(),
        body: body.trim(),
        message: body.trim(),
        type,
        audience,
        targetSegment: audience,
        destination: destination.trim() || 'zeparty://home',
      });
      onSent(created);
      setTitle('');
      setBody('');
      setDestination('zeparty://home');
      setError(null);
      onClose();
    } catch (err) {
      console.error('Failed to broadcast notification:', err);
      setError(err.response?.data?.message || err.message || 'Failed to dispatch notification broadcast');
    } finally {
      setIsSending(false);
    }
  }

  const isFormValid = Boolean(title.trim() && body.trim());

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Send Push Notification Broadcast" size="md">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4 text-xs text-slate-300">
        {error && (
          <div className="p-3 rounded-lg bg-rose-950/40 border border-rose-500/50 text-rose-300 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-400 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <Input
          label="Notification Title *"
          value={title}
          onChange={(e) => {
            setTitle(e.target.value);
            if (error) setError(null);
          }}
          required
          placeholder="e.g. Special Weekend Event Live Now!"
        />

        <div className="grid grid-cols-2 gap-3">
          <Select label="Notification Type" value={type} onChange={(e) => setType(e.target.value)}>
            <option value="Push">Standard Push</option>
            <option value="Promotional">Promotional</option>
            <option value="Transactional">Transactional</option>
            <option value="System">System Alert</option>
          </Select>
          <Select label="Target Audience *" value={audience} onChange={(e) => setAudience(e.target.value)}>
            <option value="All Users">All Registered Users</option>
            <option value="Active Users">Active Users (7 Days)</option>
            <option value="VIP Users">VIP Members Only</option>
            <option value="Hosts Only">Verified Hosts Only</option>
          </Select>
        </div>

        <Input
          label="Tap Destination Route (Deep Link)"
          value={destination}
          onChange={(e) => setDestination(e.target.value)}
          placeholder="zeparty://home, zeparty://vip, or zeparty://wallet"
        />

        <div>
          <label className="text-[11px] text-slate-400 mb-1 block">Message Body *</label>
          <Textarea
            value={body}
            onChange={(e) => {
              setBody(e.target.value);
              if (error) setError(null);
            }}
            required
            rows={3}
            placeholder="Notification text payload delivered to user notification tray…"
          />
        </div>

        {!isFormValid && (
          <p className="text-[11px] text-amber-400/80 italic">
            * Please enter both a Title and Message Body to enable the broadcast button.
          </p>
        )}

        <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
          <Button type="button" variant="ghost" size="sm" onClick={onClose} disabled={isSending}>
            Cancel
          </Button>
          <Button
            type="submit"
            variant="primary"
            size="sm"
            leftIcon={Send}
            isLoading={isSending}
            disabled={isSending || !isFormValid}
          >
            {isSending ? 'Dispatching Push...' : 'Broadcast Now'}
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
  const [retryingId, setRetryingId] = useState(null);
  const [actionMessage, setActionMessage] = useState(null);

  const loadBroadcasts = () => {
    setLoading(true);
    getNotifications()
      .then((data) => {
        setNotifications(data || []);
        setLoading(false);
      })
      .catch((err) => {
        console.error('Failed to load notifications:', err);
        setNotifications([]);
        setLoading(false);
      });
  };

  useEffect(() => {
    loadBroadcasts();
  }, []);

  async function handleRetry(broadcastId) {
    setRetryingId(broadcastId);
    setActionMessage(null);
    try {
      await retryNotificationBroadcast(broadcastId);
      setActionMessage({ type: 'success', text: 'Broadcast re-dispatched successfully!' });
      loadBroadcasts();
    } catch (err) {
      console.error('Failed to retry broadcast:', err);
      setActionMessage({ type: 'error', text: err.response?.data?.message || 'Failed to retry broadcast' });
    } finally {
      setRetryingId(null);
    }
  }

  const filtered = notifications.filter((n) => {
    const q = search.toLowerCase();
    return !q || n.title?.toLowerCase().includes(q) || n.body?.toLowerCase().includes(q);
  });

  const columns = [
    {
      key: 'title',
      header: 'Notification & Message',
      render: (row) => (
        <div className="max-w-md">
          <p className="text-sm font-semibold text-white">{row.title}</p>
          <p className="text-xs text-slate-400 truncate">{row.body}</p>
          {row.metadataJson?.destination && (
            <p className="text-[10px] text-sky-400 font-mono mt-0.5">Route: {row.metadataJson.destination}</p>
          )}
        </div>
      ),
    },
    {
      key: 'type',
      header: 'Type',
      render: (row) => <Badge variant="primary" className="text-[10px]">{row.type || 'Push'}</Badge>,
    },
    {
      key: 'audience',
      header: 'Target Audience',
      render: (row) => <span className="text-xs text-slate-300 font-medium">{row.audience}</span>,
    },
    {
      key: 'recipients',
      header: 'Eligible Recipients',
      render: (row) => (
        <span className="text-xs font-mono text-indigo-400 font-bold">
          {formatNumber(row.recipientCount ?? row.recipients ?? 0)}
        </span>
      ),
    },
    {
      key: 'deliveryStats',
      header: 'Provider Stats',
      render: (row) => {
        const stats = row.metadataJson?.dispatchStats;
        if (!stats) return <span className="text-xs text-slate-500">—</span>;
        return (
          <div className="text-[11px] font-mono">
            <span className="text-emerald-400 font-semibold">{stats.providerAcceptedCount || 0} accepted</span>
            {stats.failedCount > 0 && (
              <span className="text-rose-400 ml-1.5 font-semibold">({stats.failedCount} failed)</span>
            )}
          </div>
        );
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => {
        const st = (row.status || '').toUpperCase();
        let badgeVariant = 'default';
        if (st === 'PROVIDER_ACCEPTED' || st === 'SENT') badgeVariant = 'success';
        else if (st === 'PARTIALLY_DELIVERED') badgeVariant = 'warning';
        else if (st === 'FAILED') badgeVariant = 'danger';
        else if (st === 'DISPATCHING') badgeVariant = 'primary';
        else if (st === 'SIMULATED') badgeVariant = 'purple';
        return <Badge variant={badgeVariant} className="text-[10px] font-bold">{st}</Badge>;
      },
    },
    {
      key: 'sentAt',
      header: 'Sent At',
      render: (row) => <span className="text-xs text-slate-400">{row.sentAt || row.createdAt ? formatDate(row.sentAt || row.createdAt) : 'Draft'}</span>,
    },
    {
      key: 'actions',
      header: 'Action',
      render: (row) => (
        <Button
          size="xs"
          variant="outline"
          leftIcon={RotateCcw}
          isLoading={retryingId === row.id}
          disabled={retryingId === row.id}
          onClick={() => handleRetry(row.id)}
          title="Retry push delivery"
        >
          Retry
        </Button>
      ),
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

      {actionMessage && (
        <div className={`p-3 rounded-lg flex items-center gap-2 text-xs ${actionMessage.type === 'success' ? 'bg-emerald-950/40 border border-emerald-500/50 text-emerald-300' : 'bg-rose-950/40 border border-rose-500/50 text-rose-300'}`}>
          {actionMessage.type === 'success' ? <CheckCircle className="w-4 h-4 text-emerald-400" /> : <AlertCircle className="w-4 h-4 text-rose-400" />}
          <span>{actionMessage.text}</span>
        </div>
      )}

      <Card className="p-4">
        <Input
          placeholder="Search notifications by title or message…"
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
          loadBroadcasts();
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
