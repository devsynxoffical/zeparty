// ============================================================
// ZeParty Admin Portal — Geographic Inheritance Panel (JSX)
// GLOBAL -> REGION -> COUNTRY Inheritance Model
// ============================================================

import React from 'react';
import { Globe, Compass, MapPin, RotateCcw, AlertCircle } from 'lucide-react';
import { Card } from './Card';
import { Badge } from './Badge';

export function GeographicInheritancePanel({
  scope = 'GLOBAL',
  onChangeScope,
  inheritedValue = '',
  overrideValue = '',
  onChangeOverride,
  effectiveValue = '',
  onResetScope,
  label = 'Pricing & Config Scope Inheritance'
}) {
  return (
    <Card className="p-4 border-slate-800 bg-slate-900/60 text-xs text-slate-300">
      <div className="flex items-center justify-between border-b border-slate-800 pb-2.5 mb-3">
        <h3 className="font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
          <Globe className="h-4 w-4 text-gold-400" />
          {label}
        </h3>
        <Badge variant={scope === 'GLOBAL' ? 'primary' : scope === 'REGION' ? 'info' : 'purple'}>
          Active: {scope}
        </Badge>
      </div>

      <div className="grid md:grid-cols-3 gap-4">
        {/* Scope Selector */}
        <div className="space-y-1.5">
          <label className="text-slate-400 font-semibold block">Select Configuration Scope</label>
          <select
            value={scope}
            onChange={(e) => onChangeScope(e.target.value)}
            className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-white focus:outline-none focus:ring-1 focus:ring-gold-500"
          >
            <option value="GLOBAL">Global Default</option>
            <option value="REGION">Region Override</option>
            <option value="COUNTRY">Country Override</option>
          </select>
        </div>

        {/* Inherited vs Override Values */}
        <div className="space-y-1.5">
          <label className="text-slate-400 font-semibold block">Local Override Value</label>
          <div className="flex gap-2">
            <input
              type="text"
              value={overrideValue}
              onChange={(e) => onChangeOverride(e.target.value)}
              placeholder="e.g. 5.99 or custom text"
              className="flex-1 rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-xs text-white focus:outline-none focus:ring-1 focus:ring-gold-500"
            />
            {scope !== 'GLOBAL' && (
              <button
                type="button"
                onClick={() => onResetScope(scope)}
                title="Reset to parent config"
                className="p-2 rounded bg-slate-800 border border-slate-700 text-slate-400 hover:text-white hover:bg-slate-700 transition-colors"
              >
                <RotateCcw className="h-3.5 w-3.5" />
              </button>
            )}
          </div>
        </div>

        {/* Effective Configuration Preview */}
        <div className="p-3 bg-slate-950 border border-slate-900 rounded-lg space-y-1">
          <span className="text-[10px] text-slate-500 font-bold uppercase tracking-wider block">Effective Config Preview</span>
          <div className="flex justify-between items-center mt-1">
            <p className="text-[11px] text-slate-400">Inherited Parent:</p>
            <span className="font-mono font-bold text-slate-300">{inheritedValue || 'None'}</span>
          </div>
          <div className="flex justify-between items-center">
            <p className="text-[11px] text-gold-400 font-bold">Effective Value:</p>
            <span className="font-mono font-bold text-emerald-400">{effectiveValue || inheritedValue || 'None'}</span>
          </div>
        </div>
      </div>

      <div className="mt-3 flex items-start gap-1.5 text-[10px] text-slate-500">
        <AlertCircle className="h-3.5 w-3.5 text-slate-500 shrink-0 mt-0.5" />
        <p>
          Priority Rules: <strong className="text-slate-400">Country override &gt; Region override &gt; Global default</strong>. Editing overrides does not modify parent scopes.
        </p>
      </div>
    </Card>
  );
}
