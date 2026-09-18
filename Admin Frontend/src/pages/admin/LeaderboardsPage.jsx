// ============================================================
// ZeParty Admin Portal — Leaderboards Page (JSX)
// 100% Real Backend Driven via getLeaderboards()
// ============================================================

import React, { useState, useEffect } from 'react';
import { Trophy, Flame, Crown } from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { getLeaderboards } from '../../services/modules/leaderboards.service';
import { formatNumber } from '../../utils/format';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';

export function LeaderboardsPage() {
  const [tab, setTab] = useState('rich'); // 'rich' | 'hosts'
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    getLeaderboards('daily', tab)
      .then((res) => {
        if (mounted) {
          setData(res || []);
          setLoading(false);
        }
      })
      .catch(() => {
        if (mounted) {
          setData([]);
          setLoading(false);
        }
      });
    return () => { mounted = false; };
  }, [tab]);

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
      <Card className="overflow-x-auto">
        {loading ? (
          <div className="py-12 text-center text-sm text-slate-400">Loading leaderboard rankings...</div>
        ) : data.length === 0 ? (
          <div className="py-12 text-center text-sm text-slate-500">
            {tab === 'rich' ? 'No platform spender records found.' : 'No active host earnings found.'}
          </div>
        ) : tab === 'rich' ? (
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
              {data.map((row) => (
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
                    🪙 {formatNumber(row.totalCoinsSpent || 0)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <table className="w-full text-left text-sm text-slate-300">
            <thead className="bg-slate-900/60 text-xs uppercase text-slate-400 border-b border-slate-700/60">
              <tr>
                <th className="px-4 py-3">Rank</th>
                <th className="px-4 py-3">Host</th>
                <th className="px-4 py-3">Country</th>
                <th className="px-4 py-3">Live Hours</th>
                <th className="px-4 py-3 text-right">Total Earnings</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-700/40">
              {data.map((row) => (
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
                  <td className="px-4 py-3 whitespace-nowrap text-slate-300">{row.hoursStreamed || 0}h</td>
                  <td className="px-4 py-3 whitespace-nowrap text-right font-mono font-bold text-emerald-400 text-base">
                    💎 {formatNumber(row.totalDiamondsEarned || 0)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
