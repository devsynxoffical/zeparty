// ============================================================
// ZeParty Admin Portal — Live Room Detail Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft, Users, Mic, MicOff, StopCircle, ShieldAlert, AlertTriangle, Image, Trash2, Upload, RefreshCw } from 'lucide-react';
import { Card, CardHeader } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { DataTable } from '../../components/tables/DataTable';
import { ConfirmDialog, Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { useAuditLog } from '../../context/AuditLogContext';
import {
  getLiveRoomById,
  endStream,
  issueRoomWarning,
  toggleRoomMute,
  muteParticipant,
  kickParticipant,
  updateRoomCoverDp,
  deleteRoomCoverDp,
} from '../../services/modules/liveRooms.service';
import { getLogsForTarget } from '../../services/modules/auditLogs.service';
import { AgoraVideoPlayer } from '../../components/common/AgoraVideoPlayer';

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
  const [elapsedDuration, setElapsedDuration] = useState('00:00');

  useEffect(() => {
    if (!id) return;
    setIsLoading(true);
    getLiveRoomById(id)
      .then((found) => {
        setRoom(found || null);
        if (found) {
          setRoomMuted(Boolean(found.isMuted));
          const realParticipants = [];
          if (found.hostId || found.hostName) {
            realParticipants.push({
              id: found.hostId || 'host',
              name: found.hostName || 'Host',
              role: 'host',
              micOn: !found.isMuted,
              seatIndex: 0,
            });
          }
          if (Array.isArray(found.seats)) {
            found.seats.forEach((s) => {
              if (s.occupiedUser && s.occupiedUser.id !== found.hostId) {
                realParticipants.push({
                  id: s.occupiedUser.id,
                  name: s.occupiedUser.profile?.displayName || s.occupiedUser.username || `Speaker ${s.seatIndex + 1}`,
                  role: 'speaker',
                  micOn: !s.isMuted,
                  seatIndex: s.seatIndex,
                });
              }
            });
          }
          if (Array.isArray(found.members)) {
            found.members.forEach((m) => {
              const u = m.user || m;
              if (u && u.id && !realParticipants.some((p) => p.id === u.id)) {
                realParticipants.push({
                  id: u.id,
                  name: u.profile?.displayName || u.username || 'Viewer',
                  role: 'viewer',
                  micOn: false,
                });
              }
            });
          }
          setParticipants(realParticipants);
          getLogsForTarget(found.id).then((data) => {
            setHistory(data || []);
            setIsLoadingHistory(false);
          });
        } else {
          setIsLoadingHistory(false);
        }
      })
      .catch((err) => {
        console.error('Failed to load live room:', err);
        setRoom(null);
        setParticipants([]);
        setIsLoadingHistory(false);
      })
      .finally(() => setIsLoading(false));
  }, [id]);

  useEffect(() => {
    if (!room?.startedAt) return;
    const start = new Date(room.startedAt).getTime();
    const updateElapsed = () => {
      const diffSec = Math.max(0, Math.floor((Date.now() - start) / 1000));
      const mins = Math.floor(diffSec / 60);
      const secs = diffSec % 60;
      const hrs = Math.floor(mins / 60);
      if (hrs > 0) {
        setElapsedDuration(`${hrs}h ${mins % 60}m ${secs}s`);
      } else {
        setElapsedDuration(`${mins}m ${secs}s`);
      }
    };
    updateElapsed();
    const timer = setInterval(updateElapsed, 1000);
    return () => clearInterval(timer);
  }, [room?.startedAt]);

  const refreshHistory = () => {
    if (!id) return;
    getLogsForTarget(id).then(setHistory);
  };

  const [warningModalOpen, setWarningModalOpen] = useState(false);
  const [warningReason, setWarningReason] = useState('Community Guidelines Violation: Please follow platform streaming policies.');
  const [activeWarningText, setActiveWarningText] = useState('');

  const handleIssueWarning = async () => {
    const reasonText = warningReason.trim() || 'Warning issued by platform moderation.';
    try {
      await issueRoomWarning(room?.id, reasonText);
      await addLog('ROOM_WARNING_ISSUED', room?.id, 'Live Rooms', `Warning issued to room "${room?.title}": ${reasonText}`);
    } catch (err) {
      console.error('Failed to issue room warning:', err);
    }
    setActiveWarningText(reasonText);
    setWarningActive(true);
    setWarningModalOpen(false);
    setTimeout(() => {
      setWarningActive(false);
      setActiveWarningText('');
    }, 6500);
    refreshHistory();
  };

  const handleToggleRoomMute = async () => {
    const nextState = !roomMuted;
    try {
      await toggleRoomMute(room?.id, nextState);
      await addLog(nextState ? 'ROOM_MUTED' : 'ROOM_UNMUTED', room?.id, 'Live Rooms', `Room "${room?.title}" globally ${nextState ? 'muted' : 'unmuted'}`);
      setRoomMuted(nextState);
      setParticipants(participants.map((p) => ({ ...p, micOn: !nextState })));
    } catch (err) {
      console.error('Failed to toggle room mute:', err);
    }
    refreshHistory();
  };

  const handleMuteParticipant = async (row) => {
    const nextMic = !row.micOn;
    try {
      await muteParticipant(room?.id, { targetUserId: row.id, seatIndex: row.seatIndex, isMuted: !nextMic });
      await addLog(!nextMic ? 'PARTICIPANT_MUTED' : 'PARTICIPANT_UNMUTED', row.id, 'Live Rooms', `${!nextMic ? 'Muted' : 'Unmuted'} participant ${row.name}`);
      setParticipants(participants.map((p) => (p.id === row.id ? { ...p, micOn: nextMic } : p)));
    } catch (err) {
      console.error('Failed to mute participant:', err);
    }
    refreshHistory();
  };

  const handleKickParticipant = async (row) => {
    try {
      await kickParticipant(room?.id, row.id, 'Participant removed by admin moderation');
      await addLog('PARTICIPANT_KICKED', row.id, 'Live Rooms', `Kicked participant ${row.name} from live room`);
      setParticipants(participants.filter((p) => p.id !== row.id));
      if (row.role === 'host') {
        setRoom((r) => (r ? { ...r, status: 'ended', viewers: 0 } : r));
      }
    } catch (err) {
      console.error('Failed to kick participant:', err);
    }
    refreshHistory();
  };

  const handleDeleteRoomDp = async () => {
    try {
      await deleteRoomCoverDp(room?.id);
      await addLog('ROOM_DP_DELETED', room?.id, 'Live Rooms', `Deleted Room DP image for room "${room?.title}". Room record preserved.`);
      setRoom({ ...room, coverImage: null, dpDeleted: true });
    } catch (err) {
      console.error('Failed to delete room DP:', err);
    }
    setDeleteDpModal(false);
    refreshHistory();
  };

  const handleUpdateRoomDp = async () => {
    if (!newDpUrl) return;
    try {
      await updateRoomCoverDp(room?.id, newDpUrl);
      await addLog('ROOM_DP_UPDATED', room?.id, 'Live Rooms', `Updated Room DP image for room "${room?.title}".`);
      setRoom({ ...room, coverImage: newDpUrl, dpDeleted: false });
    } catch (err) {
      console.error('Failed to update room DP:', err);
    }
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
    } catch (err) {
      console.error('Failed to force close room:', err);
    } finally {
      setIsClosing(false);
      setCloseModal(false);
    }
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

  const participantsColumns = [
    { key: 'user', header: 'User', render: (row) => <span className="text-white font-medium">{row.name}</span> },
    { key: 'role', header: 'Role', render: (row) => <Badge variant={row.role === 'host' ? 'primary' : 'muted'}>{row.role}</Badge> },
    {
      key: 'mic',
      header: 'Mic Status',
      render: (row) =>
        row.micOn && !roomMuted ? (
          <div className="flex items-center gap-1.5 text-emerald-400">
            <Mic className="h-4 w-4" /> On
          </div>
        ) : (
          <div className="flex items-center gap-1.5 text-slate-500">
            <MicOff className="h-4 w-4" /> Off
          </div>
        ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex gap-2">
          <button onClick={() => handleMuteParticipant(row)} className={`text-xs hover:underline ${row.micOn ? 'text-amber-400' : 'text-slate-400'}`}>
            {row.micOn ? 'Mute' : 'Unmute'}
          </button>
          <button onClick={() => handleKickParticipant(row)} className="text-xs text-red-400 hover:underline">
            Kick
          </button>
        </div>
      ),
    },
  ];

  const historyColumns = [
    { key: 'timestamp', header: 'Date', render: (row) => <span className="text-xs text-slate-400">{new Date(row.timestamp).toLocaleString()}</span> },
    { key: 'action', header: 'Action', render: (row) => <span className="text-xs font-bold text-amber-400">{row.action}</span> },
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
          <p className="text-sm text-slate-400">
            Hosted by {room.hostName} ({room.hostUsername})
          </p>
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
            <CardHeader title="Live Stream Live Monitor & Moderation" description="Real-time broadcast preview with live video stream, audio status, and active overlay tools" />
            <div className="bg-slate-950 aspect-video rounded-b-xl flex items-center justify-center border-t border-slate-700/60 relative overflow-hidden group">
              {/* Agora Web RTC Live Video Monitor Player */}
              <AgoraVideoPlayer
                roomId={room.id}
                hostName={room.hostName}
                hostAvatar={room.hostAvatar}
                coverImage={room.coverImage && !room.dpDeleted ? room.coverImage : null}
                isLive={room.status === 'active'}
                roomType={room.roomType}
              />

              {/* Top Stream Badges Overlay */}
              <div className="absolute top-4 left-4 flex items-center gap-2 z-20 pointer-events-none">
                <Badge variant="danger" className="animate-pulse flex items-center gap-1.5 shadow-lg shadow-red-500/20">
                  <span className="w-2 h-2 rounded-full bg-white animate-ping" />
                  {room.status === 'active' ? 'LIVE' : room.status.toUpperCase()}
                </Badge>
                <Badge variant="muted" className="bg-black/60 text-white backdrop-blur-md flex gap-1.5 items-center border border-white/10">
                  <Users className="h-3.5 w-3.5 text-indigo-400" /> {room.viewers} Viewers
                </Badge>
                <Badge variant="muted" className="bg-black/60 text-amber-300 backdrop-blur-md border border-amber-400/20 capitalize">
                  {room.roomType === 'party' ? '🎙️ Audio Party' : '📹 Live Stream'}
                </Badge>
              </div>

              {/* Active Admin Warning Overlay */}
              {warningActive && (
                <div className="absolute inset-x-6 top-1/2 transform -translate-y-1/2 bg-amber-600/95 text-white p-4 rounded-xl font-bold flex flex-col items-center justify-center text-center gap-2 shadow-2xl shadow-amber-500/40 z-30 animate-bounce border-2 border-amber-300">
                  <div className="flex items-center gap-2 text-lg">
                    <AlertTriangle className="h-7 w-7 text-white animate-pulse" />
                    <span>MODERATION WARNING BROADCASTED</span>
                  </div>
                  <p className="text-xs text-amber-100 font-medium max-w-md">
                    {activeWarningText || 'This room has received an official administrative warning.'}
                  </p>
                </div>
              )}

              {/* Active Mute Overlay */}
              {roomMuted && (
                <div className="absolute bottom-4 left-4 bg-red-600/95 text-white px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-2 shadow-lg z-20 border border-red-400">
                  <MicOff className="h-4 w-4" /> ROOM AUDIO MUTED BY ADMIN
                </div>
              )}
            </div>
          </Card>

          <Card>
            <CardHeader title="Participants" description="Users currently in the room" />
            <DataTable columns={participantsColumns} data={participants} isLoading={false} pagination={null} />
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
                    <Badge variant="success" className="absolute top-2 right-2">
                      Active DP
                    </Badge>
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
                <Button variant="outline" size="xs" className="flex-1" onClick={() => setEditDpModal(true)}>
                  <Upload className="h-3.5 w-3.5 mr-1 text-gold-400" /> Change DP
                </Button>
                {room.coverImage && !room.dpDeleted && (
                  <Button variant="danger" size="xs" className="flex-1" onClick={() => setDeleteDpModal(true)}>
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
                <Badge variant="default">{room.category || 'General'}</Badge>
              </div>
              <div>
                <p className="text-xs text-slate-500 mb-1">Region</p>
                <p className="text-sm font-medium text-white">{room.region || room.country || 'Global (PK)'}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 mb-1">Stream Duration</p>
                <p className="text-sm font-semibold text-emerald-400 font-mono">{elapsedDuration || room.duration || '00:00'}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 mb-1">Total Gifts Received</p>
                <p className="text-sm font-bold text-purple-400">{room.giftsReceived || 0} coins</p>
              </div>
            </div>
          </Card>

          <Card>
            <CardHeader title="Moderation Tools" />
            <div className="p-4 grid grid-cols-2 gap-3">
              <button
                onClick={() => setWarningModalOpen(true)}
                className="flex flex-col items-center justify-center gap-2 p-3 rounded-lg bg-amber-500/10 hover:bg-amber-500/20 text-amber-300 transition-colors border border-amber-500/30"
              >
                <ShieldAlert className="h-5 w-5" />
                <span className="text-xs font-medium">Issue Warning</span>
              </button>
              <button
                onClick={handleToggleRoomMute}
                className={`flex flex-col items-center justify-center gap-2 p-3 rounded-lg border transition-colors ${
                  roomMuted ? 'bg-red-500/20 text-red-400 border-red-500/30' : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'
                }`}
              >
                {roomMuted ? <Mic className="h-5 w-5" /> : <MicOff className="h-5 w-5" />}
                <span className="text-xs font-medium">{roomMuted ? 'Unmute Room' : 'Mute Room'}</span>
              </button>
            </div>
          </Card>
        </div>
      </div>

      {/* Issue Warning Modal */}
      {warningModalOpen && (
        <Modal isOpen={true} onClose={() => setWarningModalOpen(false)} title="Issue Stream Moderation Warning">
          <div className="space-y-4">
            <p className="text-xs text-slate-300">
              Broadcast an authoritative administrative warning to <strong className="text-white">"{room.title}"</strong>. The warning will be displayed on the live broadcast stage on mobile and logged in the moderation audit trail:
            </p>
            <div className="space-y-2">
              <label className="text-xs font-medium text-slate-400">Select Warning Preset or Enter Custom Notice</label>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 mb-2">
                {[
                  'Community Guidelines Violation',
                  'Inappropriate Content Detected',
                  'Audio/Music Copyright Warning',
                  'Excessive Disruption / Spam',
                ].map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    onClick={() => setWarningReason(preset + ': Please adjust stream content immediately.')}
                    className="text-left text-xs p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 transition-colors"
                  >
                    ⚠️ {preset}
                  </button>
                ))}
              </div>
              <textarea
                className="w-full bg-slate-900 border border-slate-700 rounded-lg p-3 text-xs text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-amber-500 min-h-[90px]"
                placeholder="Enter warning notice text..."
                value={warningReason}
                onChange={(e) => setWarningReason(e.target.value)}
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setWarningModalOpen(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleIssueWarning} className="bg-amber-600 hover:bg-amber-500 text-white">
                Broadcast Warning
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Edit Room DP Modal */}
      {editDpModal && (
        <Modal isOpen={true} onClose={() => setEditDpModal(false)} title="Change Room Display Picture (DP)">
          <div className="space-y-4">
            <p className="text-xs text-slate-300">Enter a valid image URL for the room display picture:</p>
            <Input
              type="url"
              placeholder="https://example.com/cover-image.jpg"
              value={newDpUrl}
              onChange={(e) => setNewDpUrl(e.target.value)}
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setEditDpModal(false)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleUpdateRoomDp} disabled={!newDpUrl.trim()}>
                Save DP
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Delete DP Confirmation */}
      {deleteDpModal && (
        <ConfirmDialog
          isOpen={true}
          title="Delete Room Display Picture"
          message={`Are you sure you want to remove the cover image for "${room.title}"? The room will remain active with default placeholder styling.`}
          confirmLabel="Delete DP"
          variant="danger"
          onConfirm={handleDeleteRoomDp}
          onCancel={() => setDeleteDpModal(false)}
        />
      )}

      {/* Force Close Confirmation */}
      {closeModal && (
        <ConfirmDialog
          isOpen={true}
          title="Force Close Live Room"
          message={`Are you sure you want to terminate "${room.title}" immediately? All viewers will be disconnected.`}
          confirmLabel={isClosing ? 'Closing...' : 'Force Close Stream'}
          variant="danger"
          onConfirm={handleForceClose}
          onCancel={() => setCloseModal(false)}
        />
      )}
    </div>
  );
}

export default LiveRoomDetailPage;
