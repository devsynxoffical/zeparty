// ============================================================
// ZeParty Admin Portal — Dashboard Page (JSX)
// ============================================================

import React from 'react';
import {
  Activity,
  AlertCircle,
  BarChart3,
  CheckCircle,
  Clock,
  Crown,
  DollarSign,
  Gift,
  Megaphone,
  Radio,
  Shield,
  TrendingUp,
  Users,
  X,
} from 'lucide-react';
import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

import { StatCard } from '../../components/ui/StatCard';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Avatar } from '../../components/common/Avatar';
import {
  MOCK_CHART_DATA,
  MOCK_DASHBOARD_STATS,
  MOCK_RECENT_ACTIVITY,
  MOCK_TOP_CONTENT,
  MOCK_TOP_HOSTS,
} from '../../mocks/dashboard.mock';
import { formatCompact, formatCurrency, timeAgo } from '../../utils/format';

const ChartTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 shadow-xl text-xs">
        <p className="text-slate-400 mb-1">{label}</p>
        {payload.map((p, i) => (
          <p key={i} className="font-semibold text-white">
            {formatCompact(p.value)}
          </p>
        ))}
      </div>
    );
  }
  return null;
};

function getActivityConfig(type) {
  const configs = {
    withdrawal_approved: { icon: CheckCircle, color: 'text-emerald-400', bg: 'bg-emerald-500/10' },
    host_verified: { icon: Shield, color: 'text-gold-400', bg: 'bg-gold-500/10' },
    agency_verified: { icon: Crown, color: 'text-violet-400', bg: 'bg-violet-500/10' },
    user_banned: { icon: X, color: 'text-red-400', bg: 'bg-red-500/10' },
    announcement: { icon: Megaphone, color: 'text-amber-400', bg: 'bg-amber-500/10' },
    room_closed: { icon: Radio, color: 'text-slate-400', bg: 'bg-slate-700' },
    gift_added: { icon: Gift, color: 'text-pink-400', bg: 'bg-pink-500/10' },
  };
  return configs[type] || { icon: AlertCircle, color: 'text-slate-400', bg: 'bg-slate-700' };
}

function KPISection() {
  const s = MOCK_DASHBOARD_STATS;

  return (
    <section aria-labelledby="kpi-heading">
      <h2 id="kpi-heading" className="sr-only">Key Performance Indicators</h2>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Active Live Rooms"
          value={s.activeRooms}
          icon={Radio}
          iconColor="text-gold-400"
          iconBg="bg-gold-500/10"
          change={s.roomsGrowthPercent}
          changeLabel="vs last week"
        />
        <StatCard
          title="Concurrent Viewers"
          value={s.concurrentViewers}
          icon={Activity}
          iconColor="text-emerald-400"
          iconBg="bg-emerald-500/10"
          change={s.viewersGrowthPercent}
          changeLabel="vs peak yesterday"
        />
        <StatCard
          title="Today's Coin Sales"
          value={formatCompact(s.coinSalesToday)}
          icon={DollarSign}
          iconColor="text-amber-400"
          iconBg="bg-amber-500/10"
          subValue={`${formatCompact(s.coinsSoldToday)} coins sold`}
        />
        <StatCard
          title="Gifts Sent Today"
          value={s.giftsSentToday}
          icon={Gift}
          iconColor="text-pink-400"
          iconBg="bg-pink-500/10"
          subValue={`${formatCompact(s.giftCoinsVolumeToday)} coin volume`}
        />
      </div>

      <div className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Total Users"
          value={s.totalUsers}
          icon={Users}
          iconColor="text-sky-400"
          iconBg="bg-sky-500/10"
          subValue="All time"
        />
        <StatCard
          title="Monthly Revenue"
          value={formatCurrency(s.revenueThisMonth)}
          icon={BarChart3}
          iconColor="text-teal-400"
          iconBg="bg-teal-500/10"
          change={s.revenueGrowthPercent}
          changeLabel="vs last month"
        />
        <StatCard
          title="Pending Withdrawals"
          value={s.pendingWithdrawals}
          icon={Clock}
          iconColor="text-amber-400"
          iconBg="bg-amber-500/10"
          subValue="Awaiting review"
        />
        <StatCard
          title="Pending Verifications"
          value={s.pendingHostVerifications + s.pendingAgencyVerifications}
          icon={Shield}
          iconColor="text-orange-400"
          iconBg="bg-orange-500/10"
          subValue={`${s.pendingHostVerifications} hosts · ${s.pendingAgencyVerifications} agencies`}
        />
      </div>

      {/* Social Audio & Multi-Category Live Metrics */}
      <div className="mt-4 p-4 rounded-2xl bg-gradient-to-r from-indigo-950/40 via-purple-950/30 to-slate-900 border border-indigo-500/30 grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <p className="text-xs text-indigo-300 font-semibold">🎙️ Active Social Audio Rooms</p>
          <p className="text-xl font-bold text-white mt-0.5">42 Rooms</p>
          <p className="text-[10px] text-slate-400">18 Audio Syndicates</p>
        </div>
        <div>
          <p className="text-xs text-indigo-300 font-semibold">🎧 Total Audio Listeners</p>
          <p className="text-xl font-bold text-sky-400 mt-0.5">38,450</p>
          <p className="text-[10px] text-emerald-400 font-semibold">+14.2% peak vs yesterday</p>
        </div>
        <div>
          <p className="text-xs text-indigo-300 font-semibold">💎 Audio Room Diamond Volume</p>
          <p className="text-xl font-bold text-gold-400 mt-0.5">💎 4,820,000</p>
          <p className="text-[10px] text-slate-400">Est. Payout $482.00 USD</p>
        </div>
        <div>
          <p className="text-xs text-indigo-300 font-semibold">🛡️ 4-Eyes Approvals Queue</p>
          <p className="text-xl font-bold text-amber-400 mt-0.5">3 Pending</p>
          <p className="text-[10px] text-slate-400">Dual-admin sign-off required</p>
        </div>
      </div>
    </section>
  );
}

function ChartsSection() {
  const { userActivity, revenue, streamingActivity } = MOCK_CHART_DATA;

  return (
    <section aria-labelledby="charts-heading" className="mt-6">
      <h2 id="charts-heading" className="sr-only">Analytics Charts</h2>
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader
            title="User Activity"
            description="Daily active users — last 7 days"
            action={<Badge variant="muted">This Week</Badge>}
          />
          <div className="mt-5 h-48">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={userActivity} margin={{ top: 4, right: 4, bottom: 0, left: -16 }}>
                <defs>
                  <linearGradient id="userGrad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#D4AF37" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#D4AF37" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                <XAxis
                  dataKey="label"
                  tick={{ fill: '#64748b', fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fill: '#64748b', fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={formatCompact}
                />
                <Tooltip content={<ChartTooltip />} />
                <Area
                  type="monotone"
                  dataKey="value"
                  stroke="#D4AF37"
                  strokeWidth={2}
                  fill="url(#userGrad)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card>
          <CardHeader
            title="Streaming Activity"
            description="Active rooms — last 7 days"
          />
          <div className="mt-5 h-48">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={streamingActivity} margin={{ top: 4, right: 4, bottom: 0, left: -20 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                <XAxis
                  dataKey="label"
                  tick={{ fill: '#64748b', fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fill: '#64748b', fontSize: 11 }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={formatCompact}
                />
                <Tooltip content={<ChartTooltip />} />
                <Line
                  type="monotone"
                  dataKey="value"
                  stroke="#f43f5e"
                  strokeWidth={2}
                  dot={{ fill: '#f43f5e', r: 3 }}
                  activeDot={{ r: 5 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <Card className="mt-4">
        <CardHeader
          title="Revenue"
          description="Daily revenue (USD) — last 7 days"
          action={
            <Badge variant="success">
              +{MOCK_DASHBOARD_STATS.revenueGrowthPercent}% this month
            </Badge>
          }
        />
        <div className="mt-5 h-44">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={revenue} margin={{ top: 4, right: 4, bottom: 0, left: -16 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
              <XAxis
                dataKey="label"
                tick={{ fill: '#64748b', fontSize: 11 }}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                tick={{ fill: '#64748b', fontSize: 11 }}
                axisLine={false}
                tickLine={false}
                tickFormatter={(v) => `$${formatCompact(v)}`}
              />
              <Tooltip content={<ChartTooltip />} />
              <Bar dataKey="value" fill="#10b981" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </Card>
    </section>
  );
}

function TopHostsSection() {
  return (
    <Card>
      <CardHeader
        title="Top Hosts"
        description="By earnings this month"
        action={<Badge variant="primary">Monthly</Badge>}
      />
      <div className="mt-4 overflow-x-auto">
        <table className="w-full" aria-label="Top hosts by earnings">
          <thead>
            <tr className="border-b border-slate-700/60">
              <th className="pb-2.5 pr-4 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                #
              </th>
              <th className="pb-2.5 pr-4 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                Host
              </th>
              <th className="pb-2.5 pr-4 text-right text-xs font-medium text-slate-500 uppercase tracking-wider hidden sm:table-cell">
                Viewers
              </th>
              <th className="pb-2.5 pr-4 text-right text-xs font-medium text-slate-500 uppercase tracking-wider hidden md:table-cell">
                Hours
              </th>
              <th className="pb-2.5 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">
                Earnings
              </th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-700/40">
            {MOCK_TOP_HOSTS.map((host) => (
              <tr key={host.id} className="group hover:bg-slate-700/20 transition-colors">
                <td className="py-3 pr-4 text-sm font-semibold text-slate-400">
                  #{host.rank}
                </td>
                <td className="py-3 pr-4">
                  <div className="flex items-center gap-2.5">
                    <Avatar name={host.displayName} size="sm" />
                    <div className="min-w-0">
                      <div className="flex items-center gap-1.5">
                        <span className="text-sm font-medium text-white truncate">
                          {host.displayName}
                        </span>
                        {host.isVerified && (
                          <Shield
                            className="h-3.5 w-3.5 text-indigo-400 flex-shrink-0"
                            aria-label="Verified host"
                          />
                        )}
                      </div>
                      <span className="text-xs text-slate-500">{host.username}</span>
                    </div>
                  </div>
                </td>
                <td className="py-3 pr-4 text-right text-sm text-slate-400 hidden sm:table-cell">
                  {formatCompact(host.totalViewers)}
                </td>
                <td className="py-3 pr-4 text-right text-sm text-slate-400 hidden md:table-cell">
                  {host.hoursStreamed}h
                </td>
                <td className="py-3 text-right text-sm font-semibold text-emerald-400">
                  {formatCurrency(host.totalEarnings)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Card>
  );
}

function TopContentSection() {
  return (
    <Card>
      <CardHeader
        title="Top Content"
        description="Highest-viewed streams today"
      />
      <div className="mt-4 space-y-3">
        {MOCK_TOP_CONTENT.map((content) => (
          <div
            key={content.id}
            className="flex items-start gap-3 rounded-lg p-2.5 hover:bg-slate-700/20 transition-colors"
          >
            <span className="flex-shrink-0 w-5 text-xs font-bold text-slate-500 mt-0.5">
              #{content.rank}
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">{content.title}</p>
              <div className="mt-0.5 flex flex-wrap items-center gap-2">
                <span className="text-xs text-slate-500">{content.hostName}</span>
                <span className="text-slate-700">·</span>
                <Badge variant="muted">{content.category}</Badge>
                <span className="text-slate-700">·</span>
                <span className="text-xs text-slate-500">{content.duration}</span>
              </div>
            </div>
            <div className="flex-shrink-0 text-right">
              <p className="text-sm font-semibold text-white">{formatCompact(content.viewers)}</p>
              <p className="text-[11px] text-slate-500">viewers</p>
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}

function RecentActivitySection() {
  return (
    <Card>
      <CardHeader
        title="Recent Activity"
        description="Latest admin actions"
      />
      <div className="mt-4 space-y-3">
        {MOCK_RECENT_ACTIVITY.map((activity) => {
          const { icon: Icon, color, bg } = getActivityConfig(activity.type);
          return (
            <div key={activity.id} className="flex items-start gap-3">
              <div
                className={['flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-full', bg].join(' ')}
                aria-hidden="true"
              >
                <Icon className={['h-4 w-4', color].join(' ')} />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm text-slate-300">{activity.description}</p>
                <div className="mt-0.5 flex items-center gap-2">
                  <span className="text-xs text-slate-500">{activity.adminName}</span>
                  <span className="text-slate-700">·</span>
                  <span className="text-xs text-slate-500">{timeAgo(activity.timestamp)}</span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}

export function Dashboard() {
  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Dashboard">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs text-slate-500 mt-0.5">
            Platform overview · Mock data — connect backend for live statistics
          </p>
        </div>
        <div className="flex items-center gap-1.5 rounded-lg bg-amber-500/10 border border-amber-500/20 px-2.5 py-1.5">
          <Activity className="h-3.5 w-3.5 text-amber-400" aria-hidden="true" />
          <span className="text-xs font-medium text-amber-400">Mock Data</span>
        </div>
      </div>

      <KPISection />
      <ChartsSection />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <TopHostsSection />
        </div>
        <div className="lg:col-span-2">
          <TopContentSection />
        </div>
      </div>

      <RecentActivitySection />
    </div>
  );
}
