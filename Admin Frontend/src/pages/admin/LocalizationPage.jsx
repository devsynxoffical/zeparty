// ============================================================
// ZeParty Admin Portal — Localization & Region Settings (JSX)
// Client Excel Phase F Requirements
// ============================================================

import React, { useState } from 'react';
import { Globe, Search, Plus } from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Button } from '../../components/ui/Button';

const MOCK_LOCALES = [
  { id: 'loc-1', code: 'en-US', name: 'English (United States)', currency: 'USD ($)', active: true },
  { id: 'loc-2', code: 'ja-JP', name: 'Japanese (Japan)', currency: 'JPY (¥)', active: true },
  { id: 'loc-3', code: 'ar-SA', name: 'Arabic (Saudi Arabia)', currency: 'SAR (SR)', active: true },
];

export function LocalizationPage() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Globe className="h-6 w-6 text-gold-400" />
            Localization & Regional Settings
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage supported languages, currency symbols, and regional formats.</p>
        </div>
      </div>

      <DataTable
        columns={[
          { key: 'code', header: 'Locale Code', render: (r) => <span className="text-xs font-mono font-bold text-white">{r.code}</span> },
          { key: 'name', header: 'Language', render: (r) => <span className="text-xs text-slate-300">{r.name}</span> },
          { key: 'currency', header: 'Currency Symbol', render: (r) => <Badge variant="gold">{r.currency}</Badge> },
          { key: 'status', header: 'Status', render: (r) => <StatusBadge status={r.active ? 'active' : 'inactive'} /> },
        ]}
        data={MOCK_LOCALES}
        isLoading={false}
      />
    </div>
  );
}
