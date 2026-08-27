// ============================================================
// ZeParty Admin Portal — Reports & Analytics Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { BarChart3, TrendingUp, Users, Smartphone, Globe, Download } from 'lucide-react';
import {
  AreaChart, Area, PieChart, Pie, Cell, BarChart, Bar, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis, Legend
} from 'recharts';
import { Card, CardHeader } from '../../components/ui/Card';
import { StatCard } from '../../components/ui/StatCard';
import { useAuditLog } from '../../context/AuditLogContext';
import { CountryFlag } from '../../components/ui/CountryFlag';
import {
  getReportCards,
  getUserGrowthChart,
  getDeviceBreakdown,
  getCountryBreakdown
} from '../../services/modules/reports.service';

const COLORS = ['#10b981', '#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6', '#64748b'];

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="rounded-lg border border-slate-700 bg-slate-900 px-3 py-2 shadow-xl text-xs">
        <p className="text-slate-400 mb-1">{label}</p>
        <p className="font-semibold text-white">
          {payload[0].value.toLocaleString()}
        </p>
      </div>
    );
  }
  return null;
};

export function ReportsPage() {
  const { addLog } = useAuditLog();
  const [cards, setCards] = useState(null);
  const [growthData, setGrowthData] = useState([]);
  const [deviceData, setDeviceData] = useState([]);
  const [countryData, setCountryData] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    Promise.all([getReportCards(), getUserGrowthChart(), getDeviceBreakdown(), getCountryBreakdown()])
      .then(([c, g, d, cData]) => {
        setCards(c);
        setGrowthData(g);
        setDeviceData(d);
        setCountryData(cData);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const handleExport = () => {
    const csvRows = [];
    csvRows.push(['Section', 'Label', 'Value']);
    
    if (growthData && growthData.length > 0) {
      growthData.forEach(row => csvRows.push(['User Growth Trend', row.label, row.users]));
    }
    if (deviceData && deviceData.length > 0) {
      deviceData.forEach(row => csvRows.push(['Device Breakdown', row.name, row.value]));
    }
    if (countryData && countryData.length > 0) {
      countryData.forEach(row => csvRows.push(['Country Breakdown', row.name, row.value]));
    }

    const csvContent = "data:text/csv;charset=utf-8," 
      + csvRows.map(e => e.map(val => `"${String(val).replace(/"/g, '""')}"`).join(",")).join("\n");
    
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement("a");
    link.setAttribute("href", encodedUri);
    link.setAttribute("download", `zeparty_analytics_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    addLog('REPORTS_EXPORT', 'export', 'Reports', 'Exported analytics chart data to CSV');
  };

  if (isLoading) return <div className="p-6 text-slate-400">Loading Analytics...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Reports & Analytics">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <BarChart3 className="h-6 w-6 text-indigo-400" aria-hidden="true" />
            Reports & Analytics
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Platform growth, user retention, and activity insights.</p>
        </div>
        <div className="flex items-center gap-3">
          <select className="bg-slate-900 border border-slate-700 text-sm text-white py-2 px-3 rounded-lg outline-none">
            <option>Last 30 Days</option>
            <option>Last 90 Days</option>
            <option>This Year</option>
            <option>All Time</option>
          </select>
          <button
            onClick={handleExport}
            className="flex items-center gap-2 bg-slate-800 hover:bg-slate-700 text-white border border-slate-700 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
          >
            <Download className="h-4 w-4" /> Export Data
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="User Growth" value={cards.userGrowth} icon={TrendingUp} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
        <StatCard title="Retention Rate" value={cards.retention} icon={Users} iconColor="text-blue-400" iconBg="bg-blue-500/10" />
        <StatCard title="Monthly Active Users (MAU)" value={cards.mau} icon={BarChart3} iconColor="text-indigo-400" iconBg="bg-indigo-500/10" />
        <StatCard title="Daily Active Users (DAU)" value={cards.dau} icon={ActivityIcon} iconColor="text-purple-400" iconBg="bg-purple-500/10" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card className="lg:col-span-2">
          <CardHeader title="User Growth Trend" description="Total registered users over time" />
          <div className="p-4 h-80">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={growthData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorUsers" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#6366f1" stopOpacity={0.8}/>
                    <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" vertical={false} />
                <XAxis dataKey="label" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => `\${(v/1000000).toFixed(1)}M`} />
                <Tooltip content={<CustomTooltip />} />
                <Area type="monotone" dataKey="users" stroke="#6366f1" fillOpacity={1} fill="url(#colorUsers)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card>
          <CardHeader title="Device Breakdown" description="Active devices (iOS vs Android)" />
          <div className="p-4 h-80 flex flex-col items-center justify-center">
            <ResponsiveContainer width="100%" height="80%">
              <PieChart>
                <Pie
                  data={deviceData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {deviceData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend verticalAlign="bottom" height={36} wrapperStyle={{ fontSize: '12px', color: '#cbd5e1' }}/>
              </PieChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      <Card>
        <CardHeader title="Geographic Distribution" description="Top user demographics by country" />
        <div className="p-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={countryData} layout="vertical" margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#1e293b" horizontal={false} />
                  <XAxis type="number" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => `\${(v/1000)}k`} />
                  <YAxis dataKey="country" type="category" tick={{ fill: '#cbd5e1', fontSize: 12 }} axisLine={false} tickLine={false} width={100} />
                  <Tooltip content={<CustomTooltip />} />
                  <Bar dataKey="users" fill="#10b981" radius={[0, 4, 4, 0]} barSize={20} />
                </BarChart>
              </ResponsiveContainer>
            </div>
            <div className="flex flex-col justify-center space-y-4">
              {countryData.slice(0, 5).map((country, idx) => (
                <div key={country.country} className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className={`w-3 h-3 rounded-full`} style={{ backgroundColor: COLORS[idx % COLORS.length] }}></div>
                    <CountryFlag code={country.country} className="w-4 h-3 object-cover rounded-sm shrink-0" />
                    <span className="text-sm text-white">{country.country}</span>
                  </div>
                  <div className="flex items-center gap-4 text-sm">
                    <span className="text-slate-400">{country.users.toLocaleString()}</span>
                    <span className="text-emerald-400 font-medium w-12 text-right">{country.percentage}%</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}

// Simple fallback icon
function ActivityIcon(props) {
  return (
    <svg {...props} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="22 12 18 12 15 21 9 3 6 12 2 12"></polyline>
    </svg>
  );
}
