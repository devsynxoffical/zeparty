// ============================================================
// ZeParty Admin Portal — App Configuration & Feature Flags (JSX)
// Client Excel Phase F Requirements
// ============================================================

import React, { useState } from 'react';
import { ToggleLeft, ShieldAlert } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { useAuditLog } from '../../context/AuditLogContext';

export function AppConfigPage() {
  const { logAdminAction } = useAuditLog();
  const [flags, setFlags] = useState({
    gamesEnabled: true,
    storeEnabled: true,
    pkEnabled: true,
    svipEnabled: true,
    referralEnabled: true,
    maintenanceMode: false,
  });

  const toggle = async (key) => {
    const newVal = !flags[key];
    setFlags((prev) => ({ ...prev, [key]: newVal }));
    
    await logAdminAction({
      action: 'FEATURE_FLAG_TOGGLED',
      module: 'SystemSettings',
      targetType: 'feature_flag',
      targetId: key,
      targetName: key,
      reason: `Toggled feature flag to ${newVal ? 'ENABLED' : 'DISABLED'}`,
      riskLevel: key === 'maintenanceMode' ? 'CRITICAL' : 'HIGH',
      afterValue: { enabled: newVal }
    });
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <ToggleLeft className="h-6 w-6 text-gold-400" />
            App Configuration & Feature Flags
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Toggle module visibility, enable maintenance mode, and force app updates.</p>
        </div>
      </div>

      <Card className="p-5 space-y-4">
        <h2 className="text-sm font-bold text-white mb-2">Module Feature Toggles</h2>
        {Object.entries(flags).map(([key, val]) => (
          <div key={key} className="flex items-center justify-between p-3 rounded-xl bg-slate-800/60 border border-slate-700/50">
            <div>
              <p className="text-xs font-bold text-white capitalize">{key.replace(/([A-Z])/g, ' $1')}</p>
              <p className="text-[11px] text-slate-400">Controls runtime client app behavior</p>
            </div>
            <Button
              variant={val ? 'primary' : 'outline'}
              size="xs"
              onClick={() => toggle(key)}
            >
              {val ? 'ENABLED' : 'DISABLED'}
            </Button>
          </div>
        ))}
      </Card>
    </div>
  );
}
