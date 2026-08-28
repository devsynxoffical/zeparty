// ============================================================
// ZeParty Admin Portal — Live Room Detail Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Users, Mic, MicOff, StopCircle, ShieldAlert, AlertTriangle, Image, Trash2, Upload } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { ConfirmDialog, Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { useAuditLog } from '../../context/AuditLogContext';
import { getLiveRooms, endStream } from '../../services/modules/liveRooms.service';
import { getLogsForTarget } from '../../services/modules/auditLogs.service';

export function LiveRoomDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { addLog } = useAuditLog();
  const [room, setRoom] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [closeModal, setCloseModal] = useState(false);
  const [isClosing, setIsClosing] = useState(false);
  const [deleteDpModal, setDeleteDpModal] = useState(false);
  const [editDpModal, setEditDpModal] = useState(false);
  const [newDpUrl, setNewDpUrl] = useState('');
  const [participants, setParticipants] = useState([]);
  const [roomMuted, setRoomMuted] = useState(false);
  const [warningActive, setWarningActive] = useState(false);
  const [history, setHistory] = useState([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);

  useEffect(() => {
    getLiveRooms()
      .then((data) => {
        const found = data.find((r) => r.id === id);
        setRoom(found || null);
        if (found) {
          setParticipants([
            { id: 'usr-1', name: found.hostName, role: 'host', micOn: true },
            { id: 'usr-2', name: 'Alice_99', role: 'viewer', micOn: false },
            { id: 'usr-3', name: 'BobTheGifter', role: 'viewer', micOn: true },
          ]);
          getLogsForTarget(found.id).then(data => {
            setHistory(data);
            setIsLoadingHistory(false);
          });
        } else {
          setIsLoadingHistory(false);
        }
      })
      .finally(() => setIsLoading(false));
  }, [id]);

  const refreshHistory = () => {
    getLogsForTarget(id).then(setHistory);
  };

  const handleMuteParticipant = async (row) => {
    const isMuting = row.micOn;
    await addLog(isMuting ? 'PARTICIPANT_MUTED' : 'PARTICIPANT_UNMUTED', row.id, 'Live Rooms', `${isMuting ? 'Muted' : 'Unmuted'} ${row.name}`);
    setParticipants(participants.map(p => p.id === row.id ? { ...p, micOn: !p.micOn } : p));
    refreshHistory();
  };

  const handleToggleRoomMute = async () => {
    await addLog('ROOM_MUTED_TOGGLE', room?.id, 'Live Rooms', `Room ${room?.title} globally ${roomMuted ? 'unmuted' : 'muted'}`);
    setRoomMuted(!roomMuted);
    refreshHistory();
  };

  const handleIssueWarning = async () => {
    await addLog('ROOM_WARNING_ISSUED', room?.id, 'Live Rooms', `Warning issued to room ${room?.title}`);
    setWarningActive(true);
    setTimeout(() => setWarningActive(false), 5000);
    refreshHistory();
  };

  const handleKickParticipant = async (row) => {
    await addLog('PARTICIPANT_KICKED', row.id, 'Live Rooms', `Kicked ${row.name}`);
    setParticipants(participants.filter(p => p.id !== row.id));
    refreshHistory();
  };

  if (isLoading) {
    return <div className="p-6 text-slate-400">Loading room details...</div>;
  }

  if (!room) {
    return (
      <div className="p-6">
        <button onClick={() => navigate('/admin/live-rooms')} className="flex items-center gap-2 text-slate-400 hover:text-white mb-6 transition-colors">
          <ArrowLeft className="h-4 w-4" /> Back to Live Rooms
        </button>
        <div className="bg-slate-800/50 rounded-xl border border-slate-700/50 p-6 flex flex-col items-center justify-center min-h-[400px]">
          <AlertTriangle className="h-10 w-10 text-slate-500 mb-3" />
          <h2 className="text-lg font-bold text-white mb-1">Room Not Found</h2>
          <p className="text-sm text-slate-400">The room you are looking for does not exist or has been deleted.</p>
        </div>
      </div>
    );
  }

  const handleDeleteRoomDp = async () => {
    await addLog('ROOM_DP_DELETED', room.id, 'Live Rooms', `Deleted Room DP image for room "${room.title}". Room record preserved.`);
    setRoom({ ...room, coverImage: null, dpDeleted: true });
    setDeleteDpModal(false);
    refreshHistory();
  };

  const handleUpdateRoomDp = async () => {
    if (!newDpUrl) return;
    await addLog('ROOM_DP_UPDATED', room.id, 'Live Rooms', `Updated Room DP image for room "${room.title}".`);
    setRoom({ ...room, coverImage: newDpUrl, dpDeleted: false });
    setEditDpModal(false);
    setNewDpUrl('');
    refreshHistory();
  };

  const handleForceClose = async () => {
    setIsClosing(true);
    try {
      await endStream(room.id, 'Force closed by admin');
      await addLog('ROOM_FORCE_CLOSED', room.id, 'Live Rooms', `Force closed room "${room.title}"`);
      setRoom({ ...room, status: 'ended', viewers: 0 });
      refreshHistory();
    } finally {
      setIsClosing(false);
      setCloseModal(false);
    }
  };

  const participantsColumns = [
    { key: 'user', header: 'User', render: (row) => <span className="text-white font-medium">{row.name}</span> },
    { key: 'role', header: 'Role', render: (row) => <Badge variant={row.role === 'host' ? 'primary' : 'muted'}>{row.role}</Badge> },
    { key: 'mic', header: 'Mic Status', render: (row) => (
      row.micOn ? <div className="flex items-center gap-1.5 text-emerald-400"><Mic className="h-4 w-4"/> On</div> 
                : <div className="flex items-center gap-1.5 text-slate-500"><MicOff className="h-4 w-4"/> Off</div>
    ) },
    { key: 'actions', header: 'Actions', render: (row) => (
      <div className="flex gap-2">
        <button onClick={() => handleMuteParticipant(row)} className={`text-xs hover:underline ${row.micOn ? 'text-amber-400' : 'text-slate-400'}`}>
          {row.micOn ? 'Mute' : 'Unmute'}
        </button>
        <button onClick={() => handleKickParticipant(row)} className="text-xs text-red-400 hover:underline">Kick</button>
      </div>
    ) }
  ];

  const historyColumns = [
    { key: 'timestamp', header: 'Date', render: (row) => <span className="text-xs text-slate-400">{new Date(row.timestamp).toLocaleString()}</span> },
    { key: 'action', header: 'Action', render: (row) => <span className={`text-xs font-bold text-amber-400`}>{row.action}</span> },
    { key: 'operator', header: 'Operator', render: (row) => <span className="text-xs text-white">{row.operatorName}</span> },
    { key: 'reason', header: 'Details', render: (row) => <span className="text-xs text-slate-300 italic">{row.reason || '-'}</span> },
  ];


  return (
    <div className="flex flex-col gap-6 max-w-screen-xl mx-auto" aria-label="Live Room Details">
      <div className="flex items-center justify-between">
        <div className="flex flex-col items-start gap-2">
          <button onClick={() => navigate('/admin/live-rooms')} className="flex items-center gap-1 text-sm text-slate-400 hover:text-white transition-colors">
            <ArrowLeft className="h-4 w-4" /> Back to Rooms
          </button>
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-bold text-white">{room.title}</h1>
            <StatusBadge status={room.status} />
          </div>
          <p className="text-sm text-slate-400">Hosted by {room.hostName} ({room.hostUsername})</p>
        </div>
        
        {room.status === 'active' && (
          <button
            onClick={() => setCloseModal(true)}
            className="flex items-center gap-2 bg-red-500/10 hover:bg-red-500/20 text-red-400 px-4 py-2 rounded-lg font-medium transition-colors border border-red-500/20"
          >
            <StopCircle className="h-4 w-4" /> Force Close
          </button>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 space-y-6">
          <Card>
            <CardHeader title="Monitoring (Mock Video Stream)" description="Live view of the room" />
            <div className="bg-slate-950 aspect-video rounded-b-xl flex items-center justify-center border-t border-slate-700/60 relative overflow-hidden">
              <div className="absolute top-4 left-4 flex gap-2">
                <Badge variant="danger" className="animate-pulse">LIVE</Badge>
                <Badge variant="muted" className="bg-black/50 text-white backdrop-blur-md flex gap-1.5 items-center">
                  <Users className="h-3.5 w-3.5"/> {room.viewers}
                </Badge>
              </div>
              {warningActive && (
                <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 bg-amber-500/90 text-white px-6 py-3 rounded-xl font-bold flex items-center gap-3 shadow-lg shadow-amber-500/20 z-10 animate-bounce">
                  <AlertTriangle className="h-6 w-6" /> WARNING ISSUED BY ADMIN
                </div>
              )}
              {roomMuted && (
                <div className="absolute bottom-4 left-4 bg-red-500/90 text-white px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-2 shadow-lg z-10">
                  <MicOff className="h-4 w-4" /> ROOM MUTED
                </div>
              )}
              <p className="text-slate-600 font-medium">Video Stream Placeholder</p>
            </div>
          </Card>

          <Card>
            <CardHeader title="Participants" description="Users currently in the room" />
            <DataTable
              columns={participantsColumns}
              data={participants}
              isLoading={false}
              pagination={null}
            />
          </Card>
          
          <Card>
            <CardHeader title="Moderation History" description="Recent administrative actions taken on this room" />
            <DataTable
              columns={historyColumns}
              data={history}
              isLoading={isLoadingHistory}
              pagination={null}
              emptyTitle="No Moderation History"
              emptyDescription="No administrative actions have been taken on this room yet."
            />
          </Card>
        </div>

        <div className="space-y-6">
          {/* Room Display Picture (DP) Control Card */}
          <Card>
            <CardHeader title="Room Display Picture (DP)" description="Manage room cover image and avatar" />
            <div className="p-4 space-y-3">
              <div className="flex flex-col items-center justify-center p-3 rounded-xl bg-slate-950 border border-slate-700/60 relative">
                {room.coverImage && !room.dpDeleted ? (
                  <div className="relative w-full h-32 rounded-lg overflow-hidden border border-slate-700">
                    <img src={room.coverImage} alt="Room DP" className="w-full h-full object-cover" />
                    <Badge variant="success" className="absolute top-2 right-2">Active DP</Badge>
                  </div>
                ) : (
                  <div className="w-full h-32 rounded-lg border-2 border-dashed border-slate-700 flex flex-col items-center justify-center text-slate-500 bg-slate-900/60">
                    <Image className="h-8 w-8 mb-1 text-slate-600" />
                    <span className="text-xs font-semibold text-slate-400">Default Placeholder DP</span>
                    <span className="text-[10px] text-amber-400 mt-0.5 font-mono">Room active without custom DP</span>
                  </div>
                )}
              </div>

              <div className="flex gap-2 pt-1">
                <Button
                  variant="outline"
                  size="xs"
                  className="flex-1"
                  onClick={() => setEditDpModal(true)}
                >
                  <Upload className="h-3.5 w-3.5 mr-1 text-gold-400" /> Change DP
                </Button>
                {room.coverImage && !room.dpDeleted && (
                  <Button
                    variant="danger"
                    size="xs"
                    className="flex-1"
                    onClick={() => setDeleteDpModal(true)}
                  >
                    <Trash2 className="h-3.5 w-3.5 mr-1" /> Delete DP
                  </Button>
                )}
              </div>
            </div>
          </Card>

          <Card>
            <CardHeader title="Room Details" />
            <div className="p-4 space-y-4">
              <div>
                <p className="text-xs text-slate-500 mb-1">Category</p>
                <Badge variant="default">{room.category}</Badge>
              </div>
              <div>
                <p className="text-xs text-slate-500 mb-1">Region</p>
                <p className="text-sm text-white">{room.region}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 mb-1">Duration</p>
                <p className="text-sm text-white">{room.duration}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 mb-1">Total Gifts Received</p>
                <p className="text-sm font-medium text-purple-400">{room.giftsReceived} coins</p>
              </div>
            </div>
          </Card>

          <Card>
            <CardHeader title="Moderation Tools" />
            <div className="p-4 grid grid-cols-2 gap-3">
              <button onClick={handleIssueWarning} className="flex flex-col items-center justify-center gap-2 p-3 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition-colors border border-slate-700">
                <ShieldAlert className="h-5 w-5" />
                <span className="text-xs font-medium">Issue Warning</span>
              </button>
              <button onClick={handleToggleRoomMute} className={`flex flex-col items-center justify-center gap-2 p-3 rounded-lg border transition-colors ${roomMuted ? 'bg-red-500/20 text-red-400 border-red-500/30' : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'}`}>
                {roomMuted ? <Mic className="h-5 w-5" /> : <MicOff className="h-5 w-5" />}
                <span className="text-xs font-medium">{roomMuted ? 'Unmute Room' : 'Mute Room'}</span>
              </button>
            </div>
          </Card>
        </div>
      </div>

      <ConfirmDialog
        isOpen={closeModal}
        onClose={() => setCloseModal(false)}
        onConfirm={handleForceClose}
        title="Force Close Room"
        description={`Are you sure you want to force close "${room.title}"? This will end the live stream immediately.`}
        confirmLabel="Force Close"
        confirmVariant="danger"
        isLoading={isClosing}
      />

      {/* Delete Room DP Confirmation Modal */}
      <ConfirmDialog
        isOpen={deleteDpModal}
        onClose={() => setDeleteDpModal(false)}
        onConfirm={handleDeleteRoomDp}
        title="Delete Room Display Picture (DP)"
        description={`Are you sure you want to delete the Display Picture for room "${room.title}"? The cover image will be removed and reset to the default placeholder. The room record, host, and live stream remain active.`}
        confirmLabel="Delete Room DP"
        confirmVariant="danger"
      />

      {/* Edit Room DP Modal */}
      {editDpModal && (
        <Modal
          isOpen={true}
          onClose={() => setEditDpModal(false)}
          title="Update Room Display Picture"
        >
          <div className="space-y-4">
            <p className="text-xs text-slate-300">
              Enter a new image URL for Room <strong className="text-white">"{room.title}"</strong>:
            </p>
            <Input
              label="Image URL"
              placeholder="https://images.unsplash.com/..."
              value={newDpUrl}
              onChange={(e) => setNewDpUrl(e.target.value)}
              required
            />
            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setEditDpModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleUpdateRoomDp} disabled={!newDpUrl}>
                Save Room DP
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
