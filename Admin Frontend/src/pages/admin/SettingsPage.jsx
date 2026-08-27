// ============================================================
// ZeParty Admin Portal — Admin Portal Settings Page (JSX)
// ============================================================

import React, { useState } from 'react';
import { Settings, Save, Shield, Lock, Bell } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';

export function SettingsPage() {
  const [general, setGeneral] = useState({
    siteName: 'ZeParty Admin Portal',
    supportEmail: 'admin-support@zeparty.io',
    sessionTimeoutMins: '60',
    maxLoginAttempts: '5',
  });

  const [security, setSecurity] = useState({
    enforce2FA: true,
    ipWhitelist: '',
    requirePasswordChangeDays: '90',
  });

  const [isSaving, setIsSaving] = useState(false);
  const [savedMsg, setSavedMsg] = useState(false);

  function handleSubmit(e) {
    e.preventDefault();
    setIsSaving(true);
    setTimeout(() => {
      setIsSaving(false);
      setSavedMsg(true);
      setTimeout(() => setSavedMsg(false), 3000);
    }, 1000);
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Settings className="h-6 w-6 text-slate-400" aria-hidden="true" />
            Admin Portal Settings
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Global configuration, security policies, and admin session rules.</p>
        </div>
      </div>

      {savedMsg && (
        <div className="p-4 rounded-xl bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-sm font-medium flex items-center justify-between">
          <span>Portal settings updated successfully!</span>
          <span className="text-xs text-emerald-500 font-mono">Status: 200 OK</span>
        </div>
      )}

      <form onSubmit={handleSubmit} className="grid md:grid-cols-2 gap-6">
        {/* General Settings */}
        <Card className="p-5 flex flex-col gap-4">
          <h2 className="text-base font-semibold text-white flex items-center gap-2">
            <Settings className="h-4 w-4 text-indigo-400" />
            General Platform Settings
          </h2>
          <Input
            label="Portal Name"
            value={general.siteName}
            onChange={(e) => setGeneral({ ...general, siteName: e.target.value })}
            required
          />
          <Input
            label="Support Email"
            type="email"
            value={general.supportEmail}
            onChange={(e) => setGeneral({ ...general, supportEmail: e.target.value })}
            required
          />
          <Input
            label="Session Timeout (Minutes)"
            type="number"
            value={general.sessionTimeoutMins}
            onChange={(e) => setGeneral({ ...general, sessionTimeoutMins: e.target.value })}
            required
          />
          <Input
            label="Max Failed Login Attempts"
            type="number"
            value={general.maxLoginAttempts}
            onChange={(e) => setGeneral({ ...general, maxLoginAttempts: e.target.value })}
            required
          />
        </Card>

        {/* Security & Access Control */}
        <Card className="p-5 flex flex-col gap-4">
          <h2 className="text-base font-semibold text-white flex items-center gap-2">
            <Shield className="h-4 w-4 text-emerald-400" />
            Security & Access Control
          </h2>
          <label className="flex items-center gap-3 cursor-pointer p-3 rounded-lg bg-slate-800/60 border border-slate-700/60">
            <input
              type="checkbox"
              checked={security.enforce2FA}
              onChange={(e) => setSecurity({ ...security, enforce2FA: e.target.checked })}
              className="h-4 w-4 rounded border-slate-700 bg-slate-800 accent-indigo-600"
            />
            <div>
              <p className="text-xs font-medium text-white">Enforce 2FA for all Admin Accounts</p>
              <p className="text-[11px] text-slate-400">Requires authenticator app token on login</p>
            </div>
          </label>
          <Input
            label="IP Whitelist (comma separated)"
            value={security.ipWhitelist}
            onChange={(e) => setSecurity({ ...security, ipWhitelist: e.target.value })}
            placeholder="e.g. 192.168.1.1, 10.0.0.1 (leave blank for all)"
            hint="Restrict admin login access to specific IP ranges"
          />
          <Input
            label="Password Expiry (Days)"
            type="number"
            value={security.requirePasswordChangeDays}
            onChange={(e) => setSecurity({ ...security, requirePasswordChangeDays: e.target.value })}
            hint="Force admin password reset after N days"
          />
        </Card>

        <div className="md:col-span-2 flex justify-end">
          <Button type="submit" variant="primary" leftIcon={Save} isLoading={isSaving}>
            Save All Settings
          </Button>
        </div>
      </form>
    </div>
  );
}
