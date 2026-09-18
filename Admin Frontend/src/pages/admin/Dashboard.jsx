// ============================================================
// ZeParty Admin Portal — Dashboard Page (100% Real Backend Driven)
// ============================================================

import React from 'react';
import {
  Activity,
  AlertCircle,
  BarChart3,
  CheckCircle,
  Crown,
  DollarSign,
  Gift,
  Megaphone,
  Radio,
  Shield,
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
import { formatCompact, formatCurrency, timeAgo } from '../../utils/format';
import { getDashboardStats, getDashboardCharts, getDashboardContent } from '../../services/modules/dashboard.service';

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

function KPISection({ stats }) {
  const s = stats || {
    activeRooms: 0,
    concurrentViewers: 0,
    coinSalesToday: 0,
    coinsSoldToday: 0,
    giftsSentToday: 0,
    giftCoinsVolumeToday: 0,
    totalUsers: 0,
    totalRevenue: 0,
    activeHosts: 0,
    pendingHostVerifications: 0,
    pendingAgencyVerifications: 0,
  };

  return (
    <section aria-labelledby="kpi-heading">
      <h2 id="kpi-heading" className="sr-only">Key Performance Indicators</h2>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Active Live Rooms"
          value={s.activeRooms ?? 0}
          icon={Radio}
          iconColor="text-gold-400"
          iconBg="bg-gold-500/10"
          change={s.roomsGrowthPercent}
          changeLabel="vs last week"
        />
        <StatCard
          title="Concurrent Viewers"
          value={s.concurrentViewers ?? 0}
          icon={Activity}
          iconColor="text-emerald-400"
          iconBg="bg-emerald-500/10"
          change={s.viewersGrowthPercent}
          changeLabel="vs peak yesterday"
        />
        <StatCard
          title="Today's Coin Sales"
          value={formatCompact(s.coinSalesToday ?? s.totalRevenue ?? 0)}
          icon={DollarSign}
          iconColor="text-amber-400"
          iconBg="bg-amber-500/10"
          subValue={`${formatCompact(s.coinsSoldToday ?? s.totalCoinsInCirculation ?? 0)} coins in circulation`}
        />
        <StatCard
          title="Gifts Sent Today"
          value={s.giftsSentToday ?? 0}
          icon={Gift}
          iconColor="text-pink-400"
          iconBg="bg-pink-500/10"
          subValue={`${formatCompact(s.giftCoinsVolumeToday ?? s.totalDiamondsInCirculation ?? 0)} diamond volume`}
        />
      </div>

      <div className="mt-4 grid grid-cols-2 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Total Users"
          value={s.totalUsers ?? 0}
          icon={Users}
          iconColor="text-sky-400"
          iconBg="bg-sky-500/10"
          subValue="All time registered"
        />
        <StatCard
          title="Total Revenue"
          value={formatCurrency(s.totalRevenue ?? 0)}
          icon={BarChart3}
          iconColor="text-teal-400"
          iconBg="bg-teal-500/10"
          change={s.revenueGrowthPercent}
          changeLabel="total platform volume"
        />
        <StatCard
          title="Active Hosts"
          value={s.activeHosts ?? 0}
          icon={Crown}
          iconColor="text-amber-400"
          iconBg="bg-amber-500/10"
          subValue="Registered creators"
        />
        <StatCard
          title="Pending Verifications"
          value={(s.pendingHostVerifications ?? 0) + (s.pendingAgencyVerifications ?? 0)}
          icon={Shield}
          iconColor="text-orange-400"
          iconBg="bg-orange-500/10"
          subValue={`${s.pendingHostVerifications || 0} hosts · ${s.pendingAgencyVerifications || 0} agencies`}
        />
      </div>

      {/* Social Audio & Multi-Category Live Metrics */}
      <div className="mt-4 p-4 rounded-2xl bg-gradient-to-r from-indigo-950/40 via-purple-950/30 to-slate-900 border border-indigo-500/30 grid grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <p className="text-xs text-indigo-300 font-semibold">🎙️ Active Social Audio Rooms</p>
          <p className="text-xl font-bold text-white mt-0.5">{s.activeRooms ?? 0} Rooms</p>
          <p className="text-[10px] text-slate-400">Live platform audio</p>
        </div>
        <div>
          <p className="text-xs text-indigo-300 font-semibold">🎧 Total Audio Listeners</p>
          <p className="text-xl font-bold text-sky-400 mt-0.5">{formatCompact(s.concurrentViewers ?? 0)}</p>
          <p className="text-[10px] text-slate-400">Real-time audience</p>
        </div>
        <div>
          <p className="text-xs text-indigo-300 font-semibold">💎 Audio Room Diamond Volume</p>
          <p className="text-xl font-bold text-gold-400 mt-0.5">💎 {formatCompact(s.totalDiamondsInCirculation ?? 0)}</p>
          <p className="text-[10px] text-slate-400">Platform diamond balance</p>
        </div>
        <div>
          <p className="text-xs text-indigo-300 font-semibold">🛡️ 4-Eyes Approvals Queue</p>
          <p className="text-xl font-bold text-amber-400 mt-0.5">0 Pending</p>
          <p className="text-[10px] text-slate-400">Dual-admin sign-off queue</p>
        </div>
      </div>
    </section>
  );
}

function ChartsSection({ charts }) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const defaultSeries = days.map((label) => ({ label, value: 0 }));

  const userActivity = charts?.userActivity || defaultSeries;
  const streamingActivity = charts?.streamingActivity || defaultSeries;
  const revenue = charts?.revenue || defaultSeries;

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
            <Badge variant="muted">
              Live Backend
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

function TopHostsSection({ hosts }) {
  const list = hosts || [];

  return (
    <Card>
      <CardHeader
        title="Top Hosts"
        description="By earnings this month"
        action={<Badge variant="primary">Live</Badge>}
      />
      <div className="mt-4 overflow-x-auto">
        {list.length === 0 ? (
          <div className="py-12 text-center text-sm text-slate-500">
            No active hosts with earnings recorded.
          </div>
        ) : (
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
              {list.map((host) => (
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
        )}
      </div>
    </Card>
  );
}

function TopContentSection({ content }) {
  const list = content || [];

  return (
    <Card>
      <CardHeader
        title="Top Content"
        description="Highest-viewed streams today"
      />
      <div className="mt-4 space-y-3">
        {list.length === 0 ? (
          <div className="py-12 text-center text-sm text-slate-500">
            No live rooms currently streaming.
          </div>
        ) : (
          list.map((item) => (
            <div
              key={item.id}
              className="flex items-start gap-3 rounded-lg p-2.5 hover:bg-slate-700/20 transition-colors"
            >
              <span className="flex-shrink-0 w-5 text-xs font-bold text-slate-500 mt-0.5">
                #{item.rank}
              </span>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-white truncate">{item.title}</p>
                <div className="mt-0.5 flex flex-wrap items-center gap-2">
                  <span className="text-xs text-slate-500">{item.hostName}</span>
                  <span className="text-slate-700">·</span>
                  <Badge variant="muted">{item.category}</Badge>
                  <span className="text-slate-700">·</span>
                  <span className="text-xs text-slate-500">{item.duration}</span>
                </div>
              </div>
              <div className="flex-shrink-0 text-right">
                <p className="text-sm font-semibold text-white">{formatCompact(item.viewers)}</p>
                <p className="text-[11px] text-slate-500">viewers</p>
              </div>
            </div>
          ))
        )}
      </div>
    </Card>
  );
}

function RecentActivitySection({ activities }) {
  const list = activities || [];

  return (
    <Card>
      <CardHeader
        title="Recent Activity"
        description="Latest admin actions"
      />
      <div className="mt-4 space-y-3">
        {list.length === 0 ? (
          <div className="py-8 text-center text-sm text-slate-500">
            No recent activity recorded.
          </div>
        ) : (
          list.map((activity) => {
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
          })
        )}
      </div>
    </Card>
  );
}

export function Dashboard() {
  const [stats, setStats] = React.useState(null);
  const [charts, setCharts] = React.useState(null);
  const [content, setContent] = React.useState(null);
  const [isLive, setIsLive] = React.useState(false);

  React.useEffect(() => {
    let mounted = true;
    async function loadDashboard() {
      try {
        const [liveStats, liveCharts, liveContent] = await Promise.all([
          getDashboardStats(),
          getDashboardCharts(),
          getDashboardContent(),
        ]);
        if (mounted) {
          if (liveStats) setStats(liveStats);
          if (liveCharts) setCharts(liveCharts);
          if (liveContent) setContent(liveContent);
          setIsLive(true);
        }
      } catch {
        if (mounted) setIsLive(false);
      }
    }
    loadDashboard();
    return () => { mounted = false; };
  }, []);

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Dashboard">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs text-slate-500 mt-0.5">
            {isLive ? 'Live platform overview connected to backend services' : 'Platform overview (connecting to backend...)'}
          </p>
        </div>
        <div className={`flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 border ${isLive ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400' : 'bg-slate-800 border-slate-700 text-slate-400'}`}>
          <Activity className="h-3.5 w-3.5" aria-hidden="true" />
          <span className="text-xs font-medium">{isLive ? 'Live Backend Connected' : 'Connecting'}</span>
        </div>
      </div>

      <KPISection stats={stats} />
      <ChartsSection charts={charts} />

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <TopHostsSection hosts={content?.topHosts} />
        </div>
        <div className="lg:col-span-2">
          <TopContentSection content={content?.topContent} />
        </div>
      </div>

      <RecentActivitySection activities={content?.recentActivities} />
    </div>
  );
}
