// ============================================================
// ZeParty Admin Portal — Chat & Messaging Moderation (JSX)
// Client Excel Phase E Requirements
// ============================================================

import React, { useState } from 'react';
import { MessageSquare, Search, Plus, Trash2, ShieldAlert } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';

const MOCK_BLOCKED_WORDS = [
  { id: 'w-1', keyword: 'spam_link', category: 'Phishing', severity: 'HIGH', addedBy: 'Super Admin' },
  { id: 'w-2', keyword: 'fake_coins', category: 'Fraud', severity: 'HIGH', addedBy: 'Moderator' },
];

export function ChatModerationPage() {
  const [search, setSearch] = useState('');

  const columns = [
    {
      key: 'keyword',
      header: 'Blocked Keyword',
      render: (r) => <code className="text-xs font-bold text-red-400">{r.keyword}</code>,
    },
    {
      key: 'category',
      header: 'Category',
      render: (r) => <Badge variant="purple">{r.category}</Badge>,
    },
    {
      key: 'severity',
      header: 'Severity',
      render: (r) => (
        <Badge variant={r.severity === 'HIGH' ? 'danger' : 'warning'}>
          {r.severity}
        </Badge>
      ),
    },
    {
      key: 'addedBy',
      header: 'Added By',
      render: (r) => <span className="text-xs text-slate-300">{r.addedBy}</span>,
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <MessageSquare className="h-6 w-6 text-gold-400" />
            Chat & Messaging Moderation
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Private message reports, room chat filters, and blocked keyword rules.</p>
        </div>

        <Button variant="primary" size="sm" leftIcon={Plus}>
          Add Blocked Keyword
        </Button>
      </div>

      <Card className="p-4">
        <Input
          placeholder="Search keyword..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={MOCK_BLOCKED_WORDS} isLoading={false} />
    </div>
  );
}
