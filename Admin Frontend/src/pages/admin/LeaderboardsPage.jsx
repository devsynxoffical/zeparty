// ============================================================
// ZeParty Admin Portal — Leaderboards Page (JSX)
// ============================================================

import React, { useState } from 'react';
import { Trophy, Flame, Crown, Star } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { MOCK_LEADERBOARD_RICH, MOCK_LEADERBOARD_HOSTS } from '../../mocks/leaderboards.mock';
import { formatNumber } from '../../utils/format';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';

export function LeaderboardsPage() {
  const [tab, setTab] = useState('rich'); // 'rich' | 'hosts'

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Trophy className="h-6 w-6 text-yellow-400" aria-hidden="true" />
            Leaderboards & Rankings
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Platform top spenders and top earning live hosts.</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 border-b border-slate-700/60 pb-3">
        <button
          onClick={() => setTab('rich')}
          className={[
            'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-colors',
            tab === 'rich'
              ? 'bg-yellow-500/20 text-yellow-400 border border-yellow-500/40'
              : 'text-slate-400 hover:text-white hover:bg-slate-800',
          ].join(' ')}
        >
          <Crown className="h-4 w-4" /> Top Spenders (Rich List)
        </button>
        <button
          onClick={() => setTab('hosts')}
          className={[
            'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-colors',
            tab === 'hosts'
              ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/40'
              : 'text-slate-400 hover:text-white hover:bg-slate-800',
          ].join(' ')}
        >
          <Flame className="h-4 w-4" /> Top Earning Hosts
        </button>
      </div>

      {/* Leaderboard Table */}
      {tab === 'rich' ? (
        <Card className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-300">
            <thead className="bg-slate-900/60 text-xs uppercase text-slate-400 border-b border-slate-700/60">
              <tr>
                <th className="px-4 py-3">Rank</th>
                <th className="px-4 py-3">User</th>
                <th className="px-4 py-3">Country</th>
                <th className="px-4 py-3">VIP Level</th>
                <th className="px-4 py-3 text-right">Coins Spent</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-700/40">
              {MOCK_LEADERBOARD_RICH.map((row) => (
                <tr key={row.rank} className="hover:bg-slate-700/20 transition-colors">
                  <td className="px-4 py-3 whitespace-nowrap">
                    <span className={`inline-flex items-center justify-center h-7 w-7 rounded-full text-xs font-bold ${
                      row.rank === 1 ? 'bg-yellow-500 text-slate-950' :
                      row.rank === 2 ? 'bg-slate-300 text-slate-950' :
                      row.rank === 3 ? 'bg-amber-700 text-white' : 'bg-slate-800 text-slate-400'
                    }`}>
                      #{row.rank}
                    </span>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    <p className="font-semibold text-white">{row.displayName}</p>
                    <p className="text-xs text-slate-500">{row.username}</p>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-xs font-semibold text-slate-300">
                    <div className="flex items-center gap-1.5">
                      <CountryFlag code={row.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
                      <span>{getCountryShortName(row.country)}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    {row.vipLevel ? <Badge variant="warning">{row.vipLevel}</Badge> : <span className="text-xs text-slate-500">—</span>}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-right font-mono font-bold text-yellow-400 text-base">
                    🪙 {formatNumber(row.totalCoinsSpent)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      ) : (
        <Card className="overflow-x-auto">
          <table className="w-full text-left text-sm text-slate-300">
            <thead className="bg-slate-900/60 text-xs uppercase text-slate-400 border-b border-slate-700/60">
              <tr>
                <th className="px-4 py-3">Rank</th>
                <th className="px-4 py-3">Host</th>
                <th className="px-4 py-3">Country</th>
                <th className="px-4 py-3">Gifts Received</th>
                <th className="px-4 py-3">Live Hours</th>
                <th className="px-4 py-3 text-right">Total Earnings</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-700/40">
              {MOCK_LEADERBOARD_HOSTS.map((row) => (
                <tr key={row.rank} className="hover:bg-slate-700/20 transition-colors">
                  <td className="px-4 py-3 whitespace-nowrap">
                    <span className={`inline-flex items-center justify-center h-7 w-7 rounded-full text-xs font-bold ${
                      row.rank === 1 ? 'bg-yellow-500 text-slate-950' :
                      row.rank === 2 ? 'bg-slate-300 text-slate-950' :
                      row.rank === 3 ? 'bg-amber-700 text-white' : 'bg-slate-800 text-slate-400'
                    }`}>
                      #{row.rank}
                    </span>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    <p className="font-semibold text-white">{row.displayName}</p>
                    <p className="text-xs text-slate-500">{row.username}</p>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-xs font-semibold text-slate-300">
                    <div className="flex items-center gap-1.5">
                      <CountryFlag code={row.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
                      <span>{getCountryShortName(row.country)}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-purple-400 font-medium">🎁 {formatNumber(row.giftsReceived)}</td>
                  <td className="px-4 py-3 whitespace-nowrap text-slate-300">{row.liveHours}h</td>
                  <td className="px-4 py-3 whitespace-nowrap text-right font-mono font-bold text-emerald-400 text-base">
                    💎 {formatNumber(row.totalEarnings)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}
    </div>
  );
}
