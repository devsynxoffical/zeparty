// ============================================================
// ZeParty Admin Portal — PK & Events Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { Trophy, Plus, Search, Calendar, Swords, Award, Star, Users, Mic, MicOff, ShieldAlert, Globe, CheckCircle, Settings } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { Modal } from '../../components/ui/Modal';
import { formatNumber } from '../../utils/format';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getPKEvents,
  getPKStats,
  getPKLeaderboard,
  createPKEvent,
  updatePKEvent
} from '../../services/modules/pkEvents.service';
import { GeographicInheritancePanel } from '../../components/ui/GeographicInheritancePanel';
import { Button } from '../../components/ui/Button';

function CreateEventModal({ isOpen, onClose, onCreated }) {
  const [formData, setFormData] = useState({
    name: '',
    type: 'GLOBAL',
    startDate: '',
    endDate: '',
    prizePool: 0,
    promoteAsBanner: true,
    infoText: 'Weekly live stream PK rumble event for top content creators.',
    requirementsText: 'Host must stream at least 5 hours during event duration.',
    eligibilityText: 'Official creators matching VIP tier 2+ level.',
    termsText: 'Anti-fraud policy applies. Immediate disqualification for infractions.'
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    try {
      const event = await createPKEvent(formData);
      onCreated(event);
      onClose();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create PK Event" size="md">
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Event Name</label>
          <Input required placeholder="E.g., Summer Rumble" value={formData.name} onChange={(e) => setFormData({...formData, name: e.target.value})} />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Type</label>
            <select
              className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-gold-500 focus:ring-1 focus:ring-gold-500 outline-none transition-all"
              value={formData.type}
              onChange={(e) => setFormData({...formData, type: e.target.value})}
            >
              <option value="GLOBAL">Global</option>
              <option value="WEEKEND">Weekend</option>
              <option value="VOICE">Voice</option>
              <option value="NEW_HOST">New Host</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Prize Pool (Coins)</label>
            <Input required type="number" value={formData.prizePool} onChange={(e) => setFormData({...formData, prizePool: parseInt(e.target.value) || 0})} />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Start Date</label>
            <Input required type="datetime-local" value={formData.startDate} onChange={(e) => setFormData({...formData, startDate: e.target.value})} />
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">End Date</label>
            <Input required type="datetime-local" value={formData.endDate} onChange={(e) => setFormData({...formData, endDate: e.target.value})} />
          </div>
        </div>
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Event Description & Info</label>
          <textarea
            className="w-full bg-slate-900 border border-slate-700 rounded-lg p-2 text-xs text-white outline-none focus:border-gold-500"
            rows="2"
            value={formData.infoText}
            onChange={(e) => setFormData({...formData, infoText: e.target.value})}
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Requirements details</label>
            <textarea
              className="w-full bg-slate-900 border border-slate-700 rounded-lg p-2 text-xs text-white outline-none focus:border-gold-500"
              rows="2"
              value={formData.requirementsText}
              onChange={(e) => setFormData({...formData, requirementsText: e.target.value})}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-slate-400 mb-1">Eligibility Criteria</label>
            <textarea
              className="w-full bg-slate-900 border border-slate-700 rounded-lg p-2 text-xs text-white outline-none focus:border-gold-500"
              rows="2"
              value={formData.eligibilityText}
              onChange={(e) => setFormData({...formData, eligibilityText: e.target.value})}
            />
          </div>
        </div>
        <div>
          <label className="block text-xs font-medium text-slate-400 mb-1">Terms & Conditions</label>
          <textarea
            className="w-full bg-slate-900 border border-slate-700 rounded-lg p-2 text-xs text-white outline-none focus:border-gold-500"
            rows="2"
            value={formData.termsText}
            onChange={(e) => setFormData({...formData, termsText: e.target.value})}
          />
        </div>
        <div>
           <label className="flex items-center gap-2 text-xs text-white cursor-pointer">
            <input 
              type="checkbox" 
              className="rounded bg-slate-900 border-slate-700 text-gold-500 focus:ring-gold-500 h-4 w-4"
              checked={formData.promoteAsBanner}
              onChange={(e) => setFormData({...formData, promoteAsBanner: e.target.checked})}
            />
            Promote this event as Homepage Banner Carousel (Users get notified)
          </label>
        </div>
        <div className="flex justify-end gap-3 mt-6">
          <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-slate-400 hover:text-white transition-colors">Cancel</button>
          <button type="submit" disabled={isSubmitting} className="bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors disabled:opacity-50">
            Create Event
          </button>
        </div>
      </form>
    </Modal>
  );
}

export function PKEventsPage() {
  const { addLog } = useAuditLog();
  const [events, setEvents] = useState([]);
  const [stats, setStats] = useState(null);
  const [leaderboard, setLeaderboard] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingEvent, setEditingEvent] = useState(null);

  // Inheritance UI State
  const [selectedEventInherit, setSelectedEventInherit] = useState(null);
  const [viewingRankingsEvent, setViewingRankingsEvent] = useState(null);
  const [activeModalTab, setActiveModalTab] = useState('rankings'); // 'rankings' | 'portal'
  const [isUserParticipating, setIsUserParticipating] = useState(false);
  const [scope, setScope] = useState('GLOBAL');
  const [overrideValue, setOverrideValue] = useState('');
  const [inheritedValue, setInheritedValue] = useState('');
  const [feedback, setFeedback] = useState(null);

  const [activeBattles, setActiveBattles] = useState([
    { id: 'PKB-101', host1: 'Host_Alpha', host2: 'Host_Beta', score1: 4500, score2: 3200, duration: '05:23', host1Muted: false, host2Muted: false },
    { id: 'PKB-102', host1: 'Singer_Star', host2: 'Gamer_Pro', score1: 12000, score2: 11500, duration: '12:45', host1Muted: true, host2Muted: false },
    { id: 'PKB-103', host1: 'User_X', host2: 'User_Y', score1: 500, score2: 250, duration: '01:10', host1Muted: false, host2Muted: false },
  ]);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const handleMuteHost = (battleId, hostIndex) => {
    const battle = activeBattles.find(b => b.id === battleId);
    const hostName = hostIndex === 1 ? battle.host1 : battle.host2;
    const isMuted = hostIndex === 1 ? battle.host1Muted : battle.host2Muted;
    
    addLog('PK_HOST_MUTED', battleId, 'PK & Events', `${isMuted ? 'Unmuted' : 'Muted'} ${hostName} in battle ${battleId}`);
    
    setActiveBattles(activeBattles.map(b => {
      if (b.id === battleId) {
        if (hostIndex === 1) return { ...b, host1Muted: !b.host1Muted };
        if (hostIndex === 2) return { ...b, host2Muted: !b.host2Muted };
      }
      return b;
    }));
  };

  const handleKickHost = (battleId, hostIndex) => {
    const battle = activeBattles.find(b => b.id === battleId);
    const hostName = hostIndex === 1 ? battle.host1 : battle.host2;
    addLog('PK_HOST_KICKED', battleId, 'PK & Events', `Kicked ${hostName} from battle ${battleId}`);
    setActiveBattles(activeBattles.filter(b => b.id !== battleId));
  };

  useEffect(() => {
    Promise.all([getPKEvents(), getPKStats(), getPKLeaderboard()])
      .then(([evtData, statData, leadData]) => {
        const formatted = evtData.map(e => ({
          ...e,
          scope: e.scope || 'GLOBAL',
          overrideValue: e.overrideValue || '',
          inheritedValue: e.inheritedValue || `${e.prizePool} coins`
        }));
        setEvents(formatted);
        setStats(statData);
        setLeaderboard(leadData);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const filteredEvents = useMemo(() => {
    return events.filter(e => e.name.toLowerCase().includes(search.toLowerCase()));
  }, [events, search]);

  const handleToggleEventStatus = async (id, name, currentStatus) => {
    const newStatus = currentStatus === 'DISABLED' ? 'SCHEDULED' : 'DISABLED';
    await updatePKEvent(id, { status: newStatus });
    setEvents(events.map(e => e.id === id ? { ...e, status: newStatus } : e));
    addLog(newStatus === 'DISABLED' ? 'EVENT_DISABLED' : 'EVENT_ENABLED', id, 'PK & Events', `${newStatus === 'DISABLED' ? 'Disabled' : 'Enabled'} PK event "${name}"`);
  };

  const handleOpenInheritance = (event) => {
    setSelectedEventInherit(event);
    setScope(event.scope || 'GLOBAL');
    setOverrideValue(event.overrideValue || '');
    setInheritedValue(event.inheritedValue || `${event.prizePool} coins`);
  };

  const handleSaveInheritance = async () => {
    if (!selectedEventInherit) return;

    setEvents(events.map(e => {
      if (e.id === selectedEventInherit.id) {
        return {
          ...e,
          scope,
          overrideValue,
          prizePool: overrideValue && !isNaN(parseInt(overrideValue)) ? parseInt(overrideValue) : e.prizePool
        };
      }
      return e;
    }));

    addLog('EVENT_INHERITANCE_UPDATED', selectedEventInherit.id, 'PK & Events', `Updated scope to ${scope} with override ${overrideValue}`);
    showFeedback(`Event inheritance configured for ${selectedEventInherit.name}.`);
    setSelectedEventInherit(null);
  };

  const handleResetScope = (resetScope) => {
    setOverrideValue('');
    if (resetScope === 'COUNTRY') {
      setScope('REGION');
    } else if (resetScope === 'REGION') {
      setScope('GLOBAL');
    }
    showFeedback('Reset scope settings.');
  };

  const columns = [
    { key: 'name', header: 'Event Name', render: (row) => (
      <div>
        <p className="font-bold text-white text-sm cursor-pointer hover:text-gold-400 transition-colors" onClick={() => setViewingRankingsEvent(row)}>
          {row.name}
        </p>
        <div className="flex flex-wrap items-center gap-1.5 mt-1">
          <span className="text-xs text-slate-500">{row.id}</span>
          <Badge variant="purple" className="text-[9px] font-mono"><Globe className="h-2.5 w-2.5 mr-0.5 inline" /> {row.scope}</Badge>
          {(row.promoteAsBanner || row.id === 'PK-1001' || row.id === 'PK-1004') && (
            <Badge variant="warning" className="text-[9px] py-0">Banner promoted</Badge>
          )}
        </div>
      </div>
    )},
    { key: 'type', header: 'Type', render: (row) => <Badge variant="default">{row.type}</Badge> },
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'schedule', header: 'Schedule', render: (row) => (
      <div className="text-xs text-slate-400">
        <p>Start: {new Date(row.startDate).toLocaleDateString()}</p>
        <p>End: {new Date(row.endDate).toLocaleDateString()}</p>
      </div>
    )},
    { key: 'prize', header: 'Prize Pool / Override', render: (row) => (
      <div>
        <p className="text-gold-400 font-medium">{formatNumber(row.prizePool)} coins</p>
        {row.overrideValue && <p className="text-[10px] text-emerald-400">Override: {row.overrideValue}</p>}
      </div>
    )},
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-1.5">
        <button onClick={() => setViewingRankingsEvent(row)} className="text-xs text-gold-400 hover:underline font-bold">Rankings</button>
        <button onClick={() => setEditingEvent(row)} className="text-xs text-indigo-400 hover:underline">Edit</button>
        <button onClick={() => handleOpenInheritance(row)} className="text-xs text-slate-400 hover:underline">Scope</button>
        <button 
          onClick={() => handleToggleEventStatus(row.id, row.name, row.status)} 
          className={`text-xs hover:underline ${row.status === 'DISABLED' ? 'text-emerald-400' : 'text-red-400'}`}
        >
          {row.status === 'DISABLED' ? 'Enable' : 'Disable'}
        </button>
      </div>
    )}
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading PK Page...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="PK Events Management">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Swords className="h-6 w-6 text-gold-400 animate-pulse" aria-hidden="true" />
            PK & Live Events
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">Manage live streaming PK battles, weekend campaigns, and regional reward calculations.</p>
        </div>
        <button
          onClick={() => setIsCreateModalOpen(true)}
          className="flex items-center gap-2 bg-gold-500 hover:bg-gold-400 text-slate-900 px-4 py-2 rounded-lg text-sm font-bold transition-colors"
        >
          <Plus className="h-4 w-4" /> Create Event
        </button>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Stats row */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard title="Total Events" value={stats.totalEvents} icon={Trophy} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
        <StatCard title="Active PK Battles" value={activeBattles.length} icon={Swords} iconColor="text-red-400" iconBg="bg-red-500/10" />
        <StatCard title="Gross Coins Volume" value={formatNumber(stats.totalEngagementCoins)} icon={Star} iconColor="text-purple-400" iconBg="bg-purple-500/10" />
        <StatCard title="Active Participants" value={stats.activeHosts} icon={Users} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
      </div>

      {/* Active battles moderation */}
      <Card className="p-5">
        <CardHeader title="Live PK Battles Oversight Room" description="Active PK connections. Operations Admins can mute microphone or terminate connection immediately." />
        <div className="space-y-3 mt-4">
          {activeBattles.map(b => (
            <div key={b.id} className="p-3 bg-slate-900 border border-slate-800 rounded-xl flex justify-between items-center text-xs">
              <div>
                <p className="font-bold text-white flex items-center gap-1">
                  <span>{b.host1}</span> <span className="text-slate-500">vs</span> <span>{b.host2}</span>
                </p>
                <p className="text-[10px] text-slate-400">Score: <strong className="text-gold-400 font-mono">{b.score1}</strong> to <strong className="text-gold-400 font-mono">{b.score2}</strong> · Time: {b.duration}</p>
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="xs" onClick={() => handleMuteHost(b.id, 1)}>
                  {b.host1Muted ? 'Unmute H1' : 'Mute H1'}
                </Button>
                <Button variant="danger" size="xs" onClick={() => handleKickHost(b.id, 1)}>
                  Kick H1
                </Button>
              </div>
            </div>
          ))}
        </div>
      </Card>

      <Card className="p-4">
        <Input
          placeholder="Search by event name…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
        />
      </Card>

      <DataTable columns={columns} data={filteredEvents} isLoading={false} />

      <CreateEventModal isOpen={isCreateModalOpen} onClose={() => setIsCreateModalOpen(false)} onCreated={(e) => setEvents([e, ...events])} />

      {/* Scope Overrides Modal */}
      {selectedEventInherit && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedEventInherit(null)}
          title={`PK Event Scope overrides: ${selectedEventInherit.name}`}
          size="lg"
        >
          <div className="space-y-4">
            <GeographicInheritancePanel
              scope={scope}
              onChangeScope={setScope}
              inheritedValue={inheritedValue}
              overrideValue={overrideValue}
              onChangeOverride={setOverrideValue}
              effectiveValue={overrideValue ? `${overrideValue} coins` : inheritedValue}
              onResetScope={handleResetScope}
            />

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedEventInherit(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveInheritance}>
                Save override
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Rankings / Top Performers Modal */}
      {viewingRankingsEvent && (
        <Modal
          isOpen={true}
          onClose={() => { setViewingRankingsEvent(null); setActiveModalTab('rankings'); setIsUserParticipating(false); }}
          title={`Event Hub: ${viewingRankingsEvent.name}`}
          size="lg"
        >
          <div className="space-y-4">
            {/* Modal Tabs */}
            <div className="flex gap-2 border-b border-slate-800 pb-2">
              <button
                onClick={() => setActiveModalTab('rankings')}
                className={`px-3 py-1.5 rounded text-xs font-semibold border ${
                  activeModalTab === 'rankings'
                    ? 'bg-gold-500/20 border-gold-500/50 text-gold-400'
                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
                }`}
              >
                Leaderboard & Standings
              </button>
              <button
                onClick={() => setActiveModalTab('portal')}
                className={`px-3 py-1.5 rounded text-xs font-semibold border ${
                  activeModalTab === 'portal'
                    ? 'bg-purple-500/20 border-purple-500/50 text-purple-400'
                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-white'
                }`}
              >
                Simulated User Info & Sign-Up
              </button>
            </div>

            {activeModalTab === 'rankings' ? (
              <div className="space-y-4">
                {(viewingRankingsEvent.promoteAsBanner || viewingRankingsEvent.id === 'PK-1001' || viewingRankingsEvent.id === 'PK-1004') && (
                  <div className="p-3 bg-gradient-to-r from-purple-900 to-indigo-900 border border-indigo-500/40 rounded-xl flex items-center justify-between text-xs text-white">
                    <div>
                      <p className="font-bold uppercase tracking-wider flex items-center gap-1">
                        <Trophy className="h-4 w-4 text-gold-400" />
                        ★ Live App Banner Promotion Active ★
                      </p>
                      <p className="text-[10px] text-indigo-200 mt-0.5">This event is highlighted on the client application homepage banner carousel.</p>
                    </div>
                    <Badge variant="warning">Broadcasting</Badge>
                  </div>
                )}

                <div className="p-3 bg-slate-900 border border-slate-800 rounded-xl grid grid-cols-3 gap-2 text-xs">
                  <div>
                    <p className="text-slate-400">Prize Pool:</p>
                    <p className="font-bold text-yellow-400">🪙 {formatNumber(viewingRankingsEvent.prizePool)} coins</p>
                  </div>
                  <div>
                    <p className="text-slate-400">Participants:</p>
                    <p className="font-bold text-white">{viewingRankingsEvent.participants || 45} Hosts</p>
                  </div>
                  <div>
                    <p className="text-slate-400">Current Leader:</p>
                    <p className="font-bold text-emerald-400">{viewingRankingsEvent.topWinner || 'KingLion'}</p>
                  </div>
                </div>

                <div className="border border-slate-800 rounded-lg overflow-hidden">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead className="bg-slate-900 text-slate-400 font-semibold border-b border-slate-800">
                      <tr>
                        <th className="p-2.5">Rank</th>
                        <th className="p-2.5">Host Name</th>
                        <th className="p-2.5">Engagement Score</th>
                        <th className="p-2.5">Wins / Rounds</th>
                        <th className="p-2.5">Est. Rewards</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800 bg-slate-950 text-slate-300">
                      {leaderboard.map((item, idx) => (
                        <tr key={idx} className="hover:bg-slate-900/30">
                          <td className="p-2.5 font-bold font-mono">
                            {item.rank === 1 ? '👑 #1' : `#${item.rank}`}
                          </td>
                          <td className="p-2.5 font-bold text-white">{item.host}</td>
                          <td className="p-2.5 font-mono text-emerald-400">{formatNumber(item.score)} pts</td>
                          <td className="p-2.5 font-mono">{item.wins}W / {item.rounds}R</td>
                          <td className="p-2.5 text-yellow-400 font-bold font-mono">🪙 {formatNumber(item.rewards)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            ) : (
              <div className="space-y-4 text-xs text-slate-300">
                {/* Banner Header mockup */}
                <div className="h-32 rounded-xl bg-gradient-to-br from-yellow-600 to-amber-900 p-4 flex flex-col justify-end border border-yellow-500/20 relative overflow-hidden">
                  <div className="absolute top-2 right-2 flex gap-1">
                    <Badge variant="warning">EVENT LIVE</Badge>
                  </div>
                  <h4 className="text-lg font-black text-white leading-tight">{viewingRankingsEvent.name}</h4>
                  <p className="text-[10px] text-yellow-200">Category: {viewingRankingsEvent.type} · Prize: 🪙 {formatNumber(viewingRankingsEvent.prizePool)} coins</p>
                </div>

                <div className="space-y-3 bg-slate-900 p-4 border border-slate-800 rounded-xl">
                  <div>
                    <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[11px] text-yellow-400">1. Event Information Overview</h5>
                    <p className="text-slate-300 leading-relaxed">{viewingRankingsEvent.infoText || "Weekly challenge event promoting dynamic creator engagement across social rooms."}</p>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4 border-t border-slate-800 pt-3">
                    <div>
                      <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[10px] text-indigo-400">2. Performance Requirements</h5>
                      <p className="text-slate-400 leading-normal">{viewingRankingsEvent.requirementsText || "Hosts must stream at least 5 hours during the weekend period and match active PK rounds."}</p>
                    </div>
                    <div>
                      <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[10px] text-indigo-400">3. Eligibility Criteria</h5>
                      <p className="text-slate-400 leading-normal">{viewingRankingsEvent.eligibilityText || "Open to Direct Registries and Agency Hosts in all countries. Requires VIP tier status."}</p>
                    </div>
                  </div>

                  <div className="border-t border-slate-800 pt-3">
                    <h5 className="font-bold text-white mb-1 uppercase tracking-wider text-[11px] text-red-400">4. Official Terms & Conditions</h5>
                    <p className="text-slate-400 leading-normal">{viewingRankingsEvent.termsText || "Platform reserves the right to audit and disqualify accounts participating in fraudulent coordinator trade recharges."}</p>
                  </div>
                </div>

                {/* Simulated Participation Checkbox */}
                <div className="p-3 bg-slate-950 border border-slate-900 rounded-xl flex items-center justify-between">
                  <div>
                    <p className="font-bold text-slate-200">Simulate Host Sign-Up Option</p>
                    <p className="text-[10px] text-slate-500">Admins can test host registration options.</p>
                  </div>
                  <Button
                    variant={isUserParticipating ? 'success' : 'primary'}
                    size="sm"
                    onClick={() => {
                      setIsUserParticipating(!isUserParticipating);
                      showFeedback(isUserParticipating ? "Host successfully unregistered from event." : "Host successfully joined event! Participation verified.");
                    }}
                  >
                    {isUserParticipating ? 'Signed Up (Leave Event)' : 'Participate / Join Event'}
                  </Button>
                </div>
              </div>
            )}

            <div className="flex justify-end pt-3 border-t border-slate-800">
              <Button variant="ghost" size="sm" onClick={() => { setViewingRankingsEvent(null); setActiveModalTab('rankings'); setIsUserParticipating(false); }}>
                Close Event Hub
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
