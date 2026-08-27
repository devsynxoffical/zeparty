// ============================================================
// ZeParty Admin Portal — Support Tickets Page (JSX)
// ============================================================

import React, { useState, useEffect, useMemo } from 'react';
import { LifeBuoy, Search, AlertCircle, MessageSquare, Tag, Paperclip, Send, CheckCircle } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { Input } from '../../components/ui/Input';
import { StatCard } from '../../components/ui/StatCard';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getSupportStats,
  getSupportTickets,
  updateTicket
} from '../../services/modules/support.service';
import { getLogsForTarget } from '../../services/modules/auditLogs.service';

export function SupportPage() {
  const { addLog } = useAuditLog();
  const [stats, setStats] = useState(null);
  const [tickets, setTickets] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  
  const [selectedTicket, setSelectedTicket] = useState(null);
  const [replyMessage, setReplyMessage] = useState('');
  const { logAdminAction } = useAuditLog();
  
  const [activeTab, setActiveTab] = useState('conversation');
  const [history, setHistory] = useState([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [ticketRepliesState, setTicketRepliesState] = useState({});

  useEffect(() => {
    if (selectedTicket) {
      setIsLoadingHistory(true);
      getLogsForTarget(selectedTicket.id).then(data => {
        setHistory(data);
        setIsLoadingHistory(false);
      });
    }
  }, [selectedTicket?.id]);

  useEffect(() => {
    Promise.all([getSupportStats(), getSupportTickets()])
      .then(([s, t]) => {
        setStats(s);
        setTickets(t);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const filteredTickets = useMemo(() => {
    return tickets.filter(t => {
      const matchStatus = statusFilter === 'ALL' || t.status === statusFilter;
      const matchSearch = search === '' || 
        t.user.toLowerCase().includes(search.toLowerCase()) || 
        t.subject.toLowerCase().includes(search.toLowerCase()) ||
        t.id.toLowerCase().includes(search.toLowerCase());
      return matchStatus && matchSearch;
    });
  }, [tickets, search, statusFilter]);

  const handleStatusChange = async (ticketId, newStatus) => {
    const updated = await updateTicket(ticketId, { status: newStatus });
    setTickets(tickets.map(t => t.id === ticketId ? updated : t));
    
    if (selectedTicket && selectedTicket.id === ticketId) {
      setSelectedTicket(updated);
    }
    
    await logAdminAction({
      action: 'TICKET_STATUS_UPDATE',
      module: 'Support',
      targetType: 'ticket',
      targetId: ticketId,
      targetName: `Ticket ${ticketId}`,
      reason: `Changed status to ${newStatus}`,
      afterValue: { status: newStatus }
    });
    
    if (selectedTicket && selectedTicket.id === ticketId) {
      getLogsForTarget(ticketId).then(setHistory);
    }
  };

  const handleSendReply = async () => {
    if (!replyMessage.trim() || !selectedTicket) return;
    
    const replyObj = {
      id: `rep-${Date.now()}`,
      message: replyMessage,
      timestamp: new Date().toISOString()
    };
    
    setTicketRepliesState(prev => ({
      ...prev,
      [selectedTicket.id]: [...(prev[selectedTicket.id] || []), replyObj]
    }));

    await logAdminAction({
      action: 'TICKET_REPLY',
      module: 'Support',
      targetType: 'ticket',
      targetId: selectedTicket.id,
      targetName: `Ticket ${selectedTicket.id}`,
      reason: 'Admin sent a reply',
      metadata: { message: replyMessage }
    });
    
    setReplyMessage('');
    getLogsForTarget(selectedTicket.id).then(setHistory);
  };

  const columns = [
    { key: 'ticket', header: 'Ticket Details', render: (row) => (
      <div>
        <p className="font-medium text-white text-sm">{row.subject}</p>
        <p className="text-xs text-slate-500 font-mono mt-0.5">{row.id} • {new Date(row.created).toLocaleString()}</p>
      </div>
    )},
    { key: 'user', header: 'User', render: (row) => <span className="font-medium text-white">{row.user}</span> },
    { key: 'category', header: 'Category', render: (row) => <Badge variant="default">{row.category}</Badge> },
    { key: 'priority', header: 'Priority', render: (row) => (
      <Badge variant={row.priority === 'URGENT' ? 'danger' : row.priority === 'HIGH' ? 'warning' : 'default'}>
        {row.priority}
      </Badge>
    )},
    { key: 'status', header: 'Status', render: (row) => <StatusBadge status={row.status.toLowerCase()} /> },
    { key: 'assignedTo', header: 'Assignee', render: (row) => <span className="text-xs text-slate-400">{row.assignedTo}</span> },
    { key: 'actions', header: 'Actions', render: (row) => (
      <button 
        onClick={() => { setSelectedTicket(row); setActiveTab('conversation'); }}
        className="text-xs text-indigo-400 hover:underline"
      >
        View Thread
      </button>
    )}
  ];

  const historyColumns = [
    { key: 'timestamp', header: 'Date', render: (row) => <span className="text-xs text-slate-400">{new Date(row.timestamp).toLocaleString()}</span> },
    { key: 'action', header: 'Action', render: (row) => <span className="text-xs font-bold text-indigo-400">{row.action}</span> },
    { key: 'operator', header: 'Operator', render: (row) => <span className="text-xs text-white">{row.operatorName}</span> },
    { key: 'reason', header: 'Details', render: (row) => <span className="text-xs text-slate-300 italic">{row.reason || '-'}</span> },
  ];

  if (isLoading) return <div className="p-6 text-slate-400">Loading Support...</div>;

  return (
    <div className="space-y-6 max-w-screen-2xl mx-auto" aria-label="Support Tickets">
      <div>
        <h1 className="text-2xl font-bold text-white flex items-center gap-2">
          <LifeBuoy className="h-6 w-6 text-indigo-400" aria-hidden="true" />
          Support & Feedback
        </h1>
        <p className="text-sm text-slate-400 mt-0.5">Manage user inquiries, bug reports, and payment issues.</p>
      </div>

      <div className="grid grid-cols-2 lg:grid-cols-5 gap-4">
        <StatCard title="Open Tickets" value={stats.openTickets} icon={LifeBuoy} iconColor="text-indigo-400" iconBg="bg-indigo-500/10" />
        <StatCard title="High Priority" value={stats.highPriority} icon={AlertCircle} iconColor="text-red-400" iconBg="bg-red-500/10" />
        <StatCard title="Unassigned" value={stats.unassigned} icon={Tag} iconColor="text-amber-400" iconBg="bg-amber-500/10" />
        <StatCard title="Awaiting Reply" value={stats.waitingForReply} icon={MessageSquare} iconColor="text-sky-400" iconBg="bg-sky-500/10" />
        <StatCard title="Resolved Today" value={stats.resolvedToday} icon={CheckCircle} iconColor="text-emerald-400" iconBg="bg-emerald-500/10" />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <Card className={selectedTicket ? "xl:col-span-2 hidden xl:block" : "xl:col-span-3"}>
          <CardHeader title="Ticket Queue" description="All user support requests">
            <div className="flex items-center gap-3">
              <select
                className="bg-slate-900 border border-slate-700 text-sm text-white py-2 px-3 rounded-lg outline-none focus:border-indigo-500"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="ALL">All Statuses</option>
                <option value="OPEN">Open</option>
                <option value="IN_PROGRESS">In Progress</option>
                <option value="WAITING">Waiting on User</option>
                <option value="RESOLVED">Resolved</option>
                <option value="CLOSED">Closed</option>
              </select>
              <Input
                placeholder="Search tickets..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                leftIcon={Search}
                containerClassName="w-64"
              />
            </div>
          </CardHeader>
          <DataTable columns={columns} data={filteredTickets} isLoading={false} />
        </Card>

        {selectedTicket ? (
          <Card className="flex flex-col h-[700px]">
            <div className="p-4 border-b border-slate-700/60 flex items-start justify-between">
              <div>
                <h2 className="text-lg font-bold text-white leading-tight">{selectedTicket.subject}</h2>
                <div className="flex items-center gap-2 mt-2">
                  <Badge variant="default" className="text-[10px]">{selectedTicket.category}</Badge>
                  <StatusBadge status={selectedTicket.status.toLowerCase()} />
                </div>
              </div>
              <button 
                onClick={() => setSelectedTicket(null)}
                className="text-slate-400 hover:text-white transition-colors"
              >
                &times;
              </button>
            </div>
            
            <div className="p-4 bg-slate-800/30 border-b border-slate-700/60 text-xs text-slate-400 flex justify-between">
              <div>Reporter: <span className="text-white font-medium">{selectedTicket.user}</span></div>
              <div>ID: <span className="font-mono text-white">{selectedTicket.id}</span></div>
            </div>
            
            <div className="flex border-b border-slate-700/60 px-4 pt-2">
              <button 
                onClick={() => setActiveTab('conversation')}
                className={`pb-2 px-3 text-sm font-medium transition-colors border-b-2 ${activeTab === 'conversation' ? 'text-white border-indigo-500' : 'text-slate-400 border-transparent hover:text-slate-200'}`}
              >
                Conversation
              </button>
              <button 
                onClick={() => setActiveTab('history')}
                className={`pb-2 px-3 text-sm font-medium transition-colors border-b-2 ${activeTab === 'history' ? 'text-white border-indigo-500' : 'text-slate-400 border-transparent hover:text-slate-200'}`}
              >
                Internal Notes & History
              </button>
            </div>

            {activeTab === 'conversation' && (
              <>
                <div className="flex-1 overflow-y-auto p-4 space-y-6">
                  {/* Mock initial message */}
                  <div className="flex gap-3">
                    <div className="h-8 w-8 rounded-full bg-slate-700 flex-shrink-0 flex items-center justify-center text-xs font-bold text-white">
                      {selectedTicket.user.charAt(0)}
                    </div>
                    <div className="bg-slate-800 rounded-lg rounded-tl-none p-3 max-w-[85%] border border-slate-700">
                      <p className="text-sm text-slate-300">
                        Hello, I have an issue regarding my recent transaction. Please help me resolve this as soon as possible.
                      </p>
                      <span className="text-[10px] text-slate-500 mt-2 block">{new Date(selectedTicket.created).toLocaleString()}</span>
                    </div>
                  </div>

                  {/* Reactive Admin Replies */}
                  {(ticketRepliesState[selectedTicket.id] || []).map((rep) => (
                    <div key={rep.id} className="flex gap-3 justify-end">
                      <div className="bg-indigo-950/40 rounded-lg rounded-tr-none p-3 max-w-[85%] border border-indigo-500/30">
                        <p className="text-sm text-slate-200">{rep.message}</p>
                        <span className="text-[10px] text-slate-500 mt-2 block">{new Date(rep.timestamp).toLocaleString()}</span>
                      </div>
                      <div className="h-8 w-8 rounded-full bg-indigo-600 flex-shrink-0 flex items-center justify-center text-xs font-bold text-white">
                        A
                      </div>
                    </div>
                  ))}
                </div>

            <div className="p-4 border-t border-slate-700/60 bg-slate-900/50">
              <div className="flex items-center justify-between mb-3">
                <div className="flex gap-2">
                  <button 
                    onClick={() => handleStatusChange(selectedTicket.id, 'RESOLVED')}
                    className="text-xs font-medium text-emerald-400 hover:underline"
                  >
                    Mark as Resolved
                  </button>
                  <button 
                    onClick={() => handleStatusChange(selectedTicket.id, 'IN_PROGRESS')}
                    className="text-xs font-medium text-indigo-400 hover:underline"
                  >
                    Mark In Progress
                  </button>
                </div>
                <button className="text-xs font-medium text-slate-400 hover:text-white flex items-center gap-1">
                  <Paperclip className="h-3 w-3" /> Attach
                </button>
              </div>
              <div className="flex items-end gap-2">
                <textarea
                  className="flex-1 bg-slate-800 border border-slate-700 rounded-lg px-3 py-2 text-sm text-white focus:border-indigo-500 outline-none resize-none"
                  rows={3}
                  placeholder="Type your reply to the user..."
                  value={replyMessage}
                  onChange={(e) => setReplyMessage(e.target.value)}
                />
                <button 
                  onClick={handleSendReply}
                  disabled={!replyMessage.trim()}
                  className="bg-indigo-500 hover:bg-indigo-400 text-white h-10 w-10 rounded-lg flex items-center justify-center transition-colors disabled:opacity-50 flex-shrink-0"
                >
                  <Send className="h-4 w-4" />
                </button>
              </div>
            </div>
          </>
          )}

          {activeTab === 'history' && (
            <div className="flex-1 p-4 overflow-y-auto">
              <DataTable
                columns={historyColumns}
                data={history}
                isLoading={isLoadingHistory}
                pagination={null}
                emptyTitle="No History"
                emptyDescription="No administrative actions or internal notes exist for this ticket."
              />
            </div>
          )}
          </Card>
        ) : (
          <div className="hidden xl:flex flex-col items-center justify-center h-[700px] border border-dashed border-slate-700 bg-slate-900/30 rounded-xl text-slate-500">
            <MessageSquare className="h-12 w-12 mb-4 opacity-50" />
            <p>Select a ticket to view conversation</p>
          </div>
        )}
      </div>
    </div>
  );
}
