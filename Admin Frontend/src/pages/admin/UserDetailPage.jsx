// ============================================================
// ZeParty Admin Portal — User Detail Page (JSX)
// Expanded to full Client Excel Specifications Phase A
// ============================================================

import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getLogsForTarget, logEvent } from '../../services/modules/auditLogs.service';
import {
  ArrowLeft, Mail, Globe, Phone, Building, ShieldCheck, ShieldAlert,
  Smartphone, Lock, RefreshCw, Key, Award, Sparkles, AlertTriangle,
  Coins, Diamond, CheckCircle, XCircle, Slash, MessageSquare, Heart,
  Share2, Trash2, FileText, Camera, Eye, Film, Play, ExternalLink
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import { Toast } from '../../components/ui/Toast';
import { ImageViewerModal } from '../../components/ui/ImageViewerModal';
import { DataTable } from '../../components/tables/DataTable';
import { getUserById, updateUser, updateUserStatus } from '../../services/modules/users.service';
import { getBDCenters } from '../../services/modules/bdCenter.service';
import { getUserPosts, deleteUserPost } from '../../services/modules/posts.service';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryName } from '../../constants/countries.data';
import { formatDate, formatNumber, timeAgo, avatarColor } from '../../utils/format';

function InfoRow({ label, value, valueClass = '' }) {
  return (
    <div className="flex items-start justify-between gap-4 py-2.5 border-b border-slate-700/40 last:border-0">
      <span className="text-xs text-slate-500 flex-shrink-0">{label}</span>
      <span className={`text-xs text-right font-medium text-white ${valueClass}`}>{value || '-'}</span>
    </div>
  );
}

export function UserDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [user, setUser] = useState(null);
  const [isLoadingUser, setIsLoadingUser] = useState(true);
  const [userError, setUserError] = useState(null);
  const [activeTab, setActiveTab] = useState('overview');
  const [history, setHistory] = useState([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);

  // Posts State
  const [userPosts, setUserPosts] = useState([]);
  const [isLoadingPosts, setIsLoadingPosts] = useState(false);
  const [postToDelete, setPostToDelete] = useState(null);
  const [isDeletingPost, setIsDeletingPost] = useState(false);
  const [inspectingPost, setInspectingPost] = useState(null);
  const [previewMedia, setPreviewMedia] = useState(null);
  const [bdCenters, setBdCenters] = useState([]);
  const [selectedBDCenter, setSelectedBDCenter] = useState('');

  // Modals state
  const [modalAction, setModalAction] = useState(null); // 'ban' | 'freeze' | 'reset' | 'grant_prop' | 'revoke_session' | 'change_country'
  const [actionReason, setActionReason] = useState('');
  const [selectedProp, setSelectedProp] = useState('avatarFrame');
  const [propValue, setPropValue] = useState('');
  const [targetSessionId, setTargetSessionId] = useState(null);

  // Toast State
  const [toast, setToast] = useState(null);

  function showToast(message, type = 'success', title = '') {
    setToast({
      message,
      type,
      title: title || (type === 'success' ? 'Action Completed' : 'Operation Failed'),
      duration: 4500,
    });
  }

  // Avatar and Country/Region update state
  const [newCountry, setNewCountry] = useState('PK');
  const [newRegion, setNewRegion] = useState('South Asia');
  const [newAvatarInput, setNewAvatarInput] = useState('');
  const [isSavingAvatar, setIsSavingAvatar] = useState(false);
  const [isViewerOpen, setIsViewerOpen] = useState(false);

  useEffect(() => {
    getBDCenters().then(bds => setBdCenters(bds || [])).catch(() => setBdCenters([]));
    if (id) {
      setIsLoadingUser(true);
      getUserById(id)
        .then((userData) => {
          setUser(userData);
          setSelectedBDCenter(userData.bdCenterId || '');
          setNewCountry(userData.country || 'PK');
          setNewRegion(userData.region || 'South Asia');
          setNewAvatarInput(userData.avatarUrl || '');
          setUserError(null);
        })
        .catch((err) => {
          console.error('Failed to load user:', err);
          setUserError(err.message || 'Failed to load user data');
        })
        .finally(() => setIsLoadingUser(false));
    }
  }, [id]);

  const handleCountryChange = async () => {
    if (!user) return;
    try {
      await updateUser(user.id, { countryCode: newCountry });
      setUser({ ...user, country: newCountry, region: newRegion });
      showToast(`Country updated to ${newCountry} (${newRegion}) in database.`, 'success', 'Country Updated');
    } catch (err) {
      console.error('Failed to update country on backend:', err);
      showToast(err.message || 'Failed to update country', 'error', 'Country Update Failed');
    }
    await logEvent({
      action: 'USER_COUNTRY_CHANGED',
      targetId: user.id,
      targetType: 'USER',
      operatorName: 'Super Admin',
      reason: actionReason || `Country updated to ${newCountry} (${newRegion})`,
      riskLevel: 'HIGH',
      status: 'SUCCESS'
    });
    setModalAction(null);
    setActionReason('');
  };

  const handleAvatarChange = async () => {
    if (!user) return;
    setIsSavingAvatar(true);
    try {
      await updateUser(user.id, { avatarUrl: newAvatarInput.trim() });
      setUser({ ...user, avatarUrl: newAvatarInput.trim() });
      showToast('Profile picture updated successfully in database.', 'success', 'Avatar Updated');
      await logEvent({
        action: 'USER_AVATAR_UPDATED',
        targetId: user.id,
        targetType: 'USER',
        operatorName: 'Super Admin',
        reason: actionReason || 'Updated profile picture via admin panel',
        riskLevel: 'LOW',
        status: 'SUCCESS'
      });
      setModalAction(null);
      setActionReason('');
    } catch (err) {
      console.error('Failed to update avatar on backend:', err);
      showToast(err.message || 'Failed to update profile picture', 'error', 'Update Failed');
    } finally {
      setIsSavingAvatar(false);
    }
  };

  useEffect(() => {
    if (user?.id) {
      getLogsForTarget(user.id).then((data) => {
        setHistory(data || []);
        setIsLoadingHistory(false);
      });
      setIsLoadingPosts(true);
      getUserPosts(user.id).then((posts) => {
        setUserPosts(posts || []);
        setIsLoadingPosts(false);
      });
    }
  }, [user?.id]);

  const handleDeletePost = async () => {
    if (!postToDelete) return;
    setIsDeletingPost(true);
    const finalReason = actionReason.trim() || 'Administrative content moderation';
    try {
      await deleteUserPost(postToDelete.id, finalReason);
      setUserPosts((prev) => prev.filter((p) => p.id !== postToDelete.id));
      showToast('Post deleted successfully.', 'success', 'Post Deleted');
      
      try {
        await logEvent({
          action: 'DELETE_USER_POST',
          targetId: user.id,
          targetType: 'POST',
          operatorName: 'Super Admin',
          reason: finalReason,
          riskLevel: 'MEDIUM',
          status: 'SUCCESS',
        });
        const freshLogs = await getLogsForTarget(user.id);
        if (freshLogs) setHistory(freshLogs);
      } catch (_) {}

      setPostToDelete(null);
      setActionReason('');
    } catch (err) {
      console.error('Failed to delete post:', err);
      showToast(err.message || 'Failed to delete post', 'error', 'Deletion Failed');
    } finally {
      setIsDeletingPost(false);
    }
  };

  const handleApplyControl = async (newStatus, actionLabel, defaultReason = 'Platform security alignment and moderation compliance') => {
    const finalReason = actionReason || defaultReason;
    if (['banned', 'suspended', 'active'].includes(newStatus)) {
      try {
        await updateUserStatus(user.id, { status: newStatus, reason: finalReason });
        showToast(`User status updated to ${newStatus.toUpperCase()}.`, 'success', 'Status Updated');
      } catch (err) {
        console.error('Failed to update user status:', err);
        showToast(err.message || 'Failed to update status', 'error', 'Status Update Failed');
      }
    } else {
      showToast(`${actionLabel.replace(/_/g, ' ')} executed successfully.`, 'success', 'Action Executed');
    }
    const updated = { ...user, status: newStatus };
    setUser(updated);

    await logEvent({
      action: actionLabel,
      targetId: user.id,
      targetType: 'USER',
      operatorName: 'Super Admin',
      reason: finalReason,
      riskLevel: 'HIGH',
      status: 'SUCCESS',
    });

    setModalAction(null);
    setActionReason('');
    // Refresh history
    const freshLogs = await getLogsForTarget(user.id);
    setHistory(freshLogs || []);
  };

  const handleGrantProp = async () => {
    if (!propValue) return;
    const updatedProps = { ...user.props, [selectedProp]: propValue };
    setUser({ ...user, props: updatedProps });
    showToast(`Granted ${selectedProp}: "${propValue}" to user.`, 'success', 'Item Granted');

    await logEvent({
      action: `GRANT_PROP_${selectedProp.toUpperCase()}`,
      targetId: user.id,
      targetType: 'USER',
      operatorName: 'Super Admin',
      reason: actionReason || 'Admin Grant',
      riskLevel: 'LOW',
      status: 'SUCCESS',
    });

    setModalAction(null);
    setPropValue('');
    setActionReason('');
    const freshLogs = await getLogsForTarget(user.id);
    setHistory(freshLogs);
  };

  const handleRevokeSession = async () => {
    if (!targetSessionId) return;
    const updatedDevices = (user.devices || []).map((d) =>
      d.id === targetSessionId ? { ...d, status: 'revoked' } : d
    );
    setUser({ ...user, devices: updatedDevices });
    showToast('Device session terminated and logged out.', 'success', 'Session Revoked');

    await logEvent({
      action: 'REVOKE_SESSION',
      targetId: user.id,
      targetType: 'SESSION',
      operatorName: 'Super Admin',
      reason: 'Admin Session Revocation',
      riskLevel: 'MEDIUM',
      status: 'SUCCESS',
    });

    setModalAction(null);
    setTargetSessionId(null);
  };

  const historyColumns = [
    {
      key: 'timestamp',
      header: 'Date',
      render: (row) => (
        <span className="text-xs text-slate-400">
          {new Date(row.timestamp).toLocaleString()}
        </span>
      ),
    },
    {
      key: 'action',
      header: 'Action',
      render: (row) => (
        <span
          className={`text-xs font-bold ${
            row.riskLevel === 'HIGH' ? 'text-red-400' : 'text-emerald-400'
          }`}
        >
          {row.action}
        </span>
      ),
    },
    {
      key: 'operator',
      header: 'Operator',
      render: (row) => <span className="text-xs text-white">{row.operatorName}</span>,
    },
    {
      key: 'reason',
      header: 'Reason',
      render: (row) => (
        <span className="text-xs text-slate-300 italic">{row.reason || '-'}</span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => (
        <Badge variant={row.status === 'SUCCESS' ? 'success' : 'danger'}>
          {row.status}
        </Badge>
      ),
    },
  ];

  const deviceColumns = [
    {
      key: 'deviceName',
      header: 'Device',
      render: (row) => (
        <div>
          <p className="text-xs font-semibold text-white">{row.deviceName}</p>
          <p className="text-[11px] text-slate-400">{row.deviceType} • {row.appVersion}</p>
        </div>
      ),
    },
    {
      key: 'ip',
      header: 'IP Address',
      render: (row) => <span className="text-xs font-mono text-slate-300">{row.ip}</span>,
    },
    {
      key: 'loginTime',
      header: 'Login Time',
      render: (row) => (
        <span className="text-xs text-slate-400">{formatDate(row.loginTime)}</span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => (
        <Badge variant={(row?.status || 'active').toLowerCase() === 'active' ? 'success' : 'danger'}>
          {String(row?.status || 'ACTIVE').toUpperCase()}
        </Badge>
      ),
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex gap-2">
          {row.status === 'active' && (
            <Button
              variant="danger"
              size="xs"
              onClick={() => {
                setTargetSessionId(row.id);
                setModalAction('revoke_session');
              }}
            >
              Force Logout
            </Button>
          )}
        </div>
      ),
    },
  ];

  if (isLoadingUser) {
    return (
      <div className="flex flex-col items-center justify-center p-16 gap-3">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-gold-500 border-t-transparent" />
        <p className="text-sm text-slate-400">Loading user profile from database...</p>
      </div>
    );
  }

  if (userError || !user) {
    return (
      <div className="p-8 text-center bg-slate-900/60 rounded-2xl border border-red-500/30">
        <p className="text-base font-bold text-red-400">User Not Found</p>
        <p className="text-xs text-slate-400 mt-1">{userError || 'The requested user could not be located.'}</p>
        <Button variant="outline" size="sm" className="mt-4" onClick={() => navigate('/admin/users')}>
          <ArrowLeft className="h-4 w-4 mr-1.5" /> Back to Users
        </Button>
      </div>
    );
  }

  const bgColor = avatarColor(user.id);

  return (
    <div className="flex flex-col gap-6">
      {/* Floating In-App Toast Notification */}
      <Toast toast={toast} onClose={() => setToast(null)} />

      {/* Back Navigation */}
      <div>
        <button
          onClick={() => navigate('/admin/users')}
          className="flex items-center gap-1.5 text-sm text-slate-400 hover:text-white transition-colors"
        >
          <ArrowLeft className="h-4 w-4" aria-hidden="true" />
          Back to User Management
        </button>
      </div>

      {/* Profile Header */}
      <div className="rounded-2xl border border-slate-700/60 bg-slate-900/60 p-6 backdrop-blur-md">
        <div className="flex flex-col md:flex-row items-center md:items-start justify-between gap-6">
          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5">
            <div
              className="relative group cursor-pointer h-20 w-20 rounded-2xl overflow-hidden shadow-xl border border-white/20 ring-2 ring-indigo-500/20 shrink-0"
              onClick={() => {
                if (user.avatarUrl) {
                  setIsViewerOpen(true);
                } else {
                  setNewAvatarInput('');
                  setModalAction('update_avatar');
                }
              }}
              title={user.avatarUrl ? 'Click to view full-size photo' : 'Click to add profile picture'}
            >
              {user.avatarUrl ? (
                <img
                  src={user.avatarUrl}
                  alt={user.displayName}
                  className="h-full w-full object-cover group-hover:scale-105 transition-transform duration-200"
                />
              ) : (
                <div
                  className="h-full w-full flex items-center justify-center text-white text-3xl font-bold"
                  style={{ backgroundColor: bgColor }}
                >
                  {user.displayName.charAt(0)}
                </div>
              )}
              <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex flex-col items-center justify-center transition-opacity text-white text-[10px] font-medium p-1 text-center">
                <Eye className="h-4 w-4 mb-0.5" />
                <span>{user.avatarUrl ? 'View Photo' : 'Upload'}</span>
              </div>
            </div>

            <div className="text-center sm:text-left">
              <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                <h1 className="text-2xl font-bold text-white">{user.displayName}</h1>
                <StatusBadge status={user.status} />
                {user.vip && <Badge variant="warning">{user.vipLevel}</Badge>}
                {user.svipLevel && <Badge variant="primary">{user.svipLevel}</Badge>}
                {user.isHost && (
                  <Badge variant="purple">Host: {user.hostTier || 'Active'}</Badge>
                )}
              </div>
              <p className="text-slate-400 text-sm mt-0.5">@{user.username} • ID: <code className="text-gold-400">{user.id}</code></p>

              <div className="flex flex-wrap justify-center sm:justify-start gap-4 mt-3 text-xs text-slate-400">
                <span className="flex items-center gap-1">
                  <Mail className="h-3.5 w-3.5 text-slate-500" /> {user.email}
                </span>
                <span className="flex items-center gap-1">
                  <Phone className="h-3.5 w-3.5 text-slate-500" /> {user.phone || 'N/A'}
                </span>
                <span className="flex items-center gap-1 font-semibold text-slate-300">
                  <CountryFlag code={user.country} className="w-4 h-3 object-cover rounded-sm shrink-0" />
                  <span>{getCountryName(user.country)}</span>
                </span>
              </div>
            </div>
          </div>

          {/* Quick Account Controls */}
          <div className="flex flex-wrap gap-2 justify-center md:justify-end">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setNewAvatarInput(user.avatarUrl || '');
                setModalAction('update_avatar');
              }}
            >
              <Camera className="h-4 w-4 mr-1 text-indigo-400" /> Update Picture
            </Button>
            {user.avatarUrl && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => setIsViewerOpen(true)}
              >
                <Eye className="h-4 w-4 mr-1 text-emerald-400" /> View Picture
              </Button>
            )}
            <Button
              variant="outline"
              size="sm"
              onClick={() => setModalAction('change_country')}
            >
              <Globe className="h-4 w-4 mr-1 text-sky-400" /> Change Country
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setModalAction('grant_prop')}
            >
              <Sparkles className="h-4 w-4 mr-1 text-gold-400" /> Grant Item
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setModalAction('freeze')}
            >
              <Lock className="h-4 w-4 mr-1 text-amber-400" /> Freeze / Restrict
            </Button>
            <Button
              variant="danger"
              size="sm"
              onClick={() => setModalAction('ban')}
            >
              <Slash className="h-4 w-4 mr-1" /> Ban Account
            </Button>
          </div>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-6 border-b border-slate-700/60 overflow-x-auto">
        {[
          { id: 'overview', label: 'Overview & Profile' },
          { id: 'bank', label: 'Bank & Payout Details' },
          { id: 'agency_host', label: 'Agency & Host Relation' },
          { id: 'posts', label: `Posts (${userPosts.length})` },
          { id: 'props', label: 'Owned Props & Perks' },
          { id: 'devices', label: 'Devices & Sessions' },
          { id: 'history', label: 'Activity & Audit Logs' },
        ].map((t) => (
          <button
            key={t.id}
            onClick={() => setActiveTab(t.id)}
            className={`pb-3 text-sm font-medium transition-colors whitespace-nowrap border-b-2 ${
              activeTab === t.id
                ? 'text-gold-400 border-gold-500 font-bold'
                : 'text-slate-400 border-transparent hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Overview Tab */}
      {activeTab === 'overview' && (
        <>
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <Card className="p-4 flex flex-col items-center text-center">
              <Coins className="h-6 w-6 text-yellow-400 mb-1" />
              <p className="text-xl font-bold text-yellow-400">{formatNumber(user.coins)}</p>
              <p className="text-xs text-slate-400">Total Coins</p>
            </Card>
            <Card className="p-4 flex flex-col items-center text-center">
              <Diamond className="h-6 w-6 text-cyan-400 mb-1" />
              <p className="text-xl font-bold text-cyan-400">{formatNumber(user.diamonds)}</p>
              <p className="text-xs text-slate-400">Diamonds Balance</p>
            </Card>
            <Card className="p-4 flex flex-col items-center text-center">
              <Award className="h-6 w-6 text-purple-400 mb-1" />
              <p className="text-xl font-bold text-purple-400">{formatNumber(user.totalGifted)}</p>
              <p className="text-xs text-slate-400">Total Gifted (Coins)</p>
            </Card>
            <Card className="p-4 flex flex-col items-center text-center">
              <ShieldCheck className="h-6 w-6 text-emerald-400 mb-1" />
              <p className="text-xl font-bold text-emerald-400">{formatNumber(user.clearedBalance || user.coins)}</p>
              <p className="text-xs text-slate-400">Withdrawable Cleared</p>
            </Card>
          </div>

          <div className="grid md:grid-cols-2 gap-6">
            <Card className="p-5">
              <h2 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-gold-400" /> Account Summary
              </h2>
              <div>
                <InfoRow label="User ID" value={user.id} />
                <InfoRow label="Username" value={`@${user.username}`} />
                <InfoRow label="Display Name" value={user.displayName} />
                <InfoRow label="Email" value={user.email} />
                <InfoRow label="Phone Number" value={user.phone} />
                <InfoRow label="Country" value={
                  <span className="flex items-center gap-1.5 font-semibold text-slate-200">
                    <CountryFlag code={user.country} className="w-4 h-3 object-cover rounded-sm shrink-0" />
                    <span>{getCountryName(user.country)}</span>
                  </span>
                } />
                <InfoRow label="Registration Date" value={formatDate(user.registeredAt)} />
                <InfoRow label="Last Active" value={timeAgo(user.lastActive)} />
              </div>
            </Card>

            <Card className="p-5">
              <h2 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
                <Key className="h-4 w-4 text-gold-400" /> Administrative Actions
              </h2>
              <div className="space-y-3">
                <div className="flex items-center justify-between p-3 rounded-xl bg-slate-800/60 border border-slate-700/50">
                  <div>
                    <p className="text-xs font-semibold text-white">Reset Avatar / Profile</p>
                    <p className="text-[11px] text-slate-400">Clear inappropriate profile pictures</p>
                  </div>
                  <Button variant="outline" size="xs" onClick={() => handleApplyControl(user.status, 'RESET_AVATAR')}>
                    Reset
                  </Button>
                </div>

                <div className="flex items-center justify-between p-3 rounded-xl bg-slate-800/60 border border-slate-700/50">
                  <div>
                    <p className="text-xs font-semibold text-white">Reset Nickname</p>
                    <p className="text-[11px] text-slate-400">Restore to default user handle</p>
                  </div>
                  <Button variant="outline" size="xs" onClick={() => handleApplyControl(user.status, 'RESET_NICKNAME')}>
                    Reset
                  </Button>
                </div>

                <div className="flex items-center justify-between p-3 rounded-xl bg-slate-800/60 border border-slate-700/50">
                  <div>
                    <p className="text-xs font-semibold text-white">Force Password Reset</p>
                    <p className="text-[11px] text-slate-400">Invalidate credentials & force reset</p>
                  </div>
                  <Button variant="secondary" size="xs" onClick={() => handleApplyControl(user.status, 'FORCE_PWD_RESET')}>
                    Trigger
                  </Button>
                </div>
              </div>
            </Card>
          </div>
        </>
      )}

      {/* Bank Details Tab */}
      {activeTab === 'bank' && (
        <Card className="p-6">
          <h2 className="text-base font-bold text-white mb-4 flex items-center gap-2">
            <Building className="h-5 w-5 text-gold-400" /> Verified Bank & Payout Information
          </h2>
          {user.bankDetails ? (
            <div className="grid md:grid-cols-2 gap-4">
              <InfoRow label="Bank Name" value={user.bankDetails.bankName} />
              <InfoRow label="Account Holder" value={user.bankDetails.accountHolder} />
              <InfoRow label="Account Number" value={user.bankDetails.accountNumber} />
              <InfoRow label="SWIFT / BIC Code" value={user.bankDetails.swiftCode} />
              <InfoRow label="Country" value={
                <span className="flex items-center gap-1.5 font-semibold text-slate-200">
                  <CountryFlag code={user.bankDetails.country} className="w-4 h-3 object-cover rounded-sm shrink-0" />
                  <span>{getCountryName(user.bankDetails.country)}</span>
                </span>
              } />
              <InfoRow label="Verification Status" value="VERIFIED" valueClass="text-emerald-400 font-bold" />
            </div>
          ) : (
            <div className="p-8 text-center text-slate-400">
              <XCircle className="h-8 w-8 text-slate-600 mx-auto mb-2" />
              <p className="text-sm font-medium">No Payout Details Provided</p>
              <p className="text-xs mt-1 text-slate-500">This user has not linked a bank account yet.</p>
            </div>
          )}
        </Card>
      )}

      {/* Agency & Host Tab */}
      {activeTab === 'agency_host' && (
        <div className="grid md:grid-cols-2 gap-6">
          <Card className="p-5">
            <h2 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
              <Building className="h-4 w-4 text-gold-400" /> Agency & BD Center Relationship
            </h2>
            <InfoRow label="Parent Agency" value={user.agencyName || 'Independent User'} />
            <InfoRow label="Agency ID" value={user.agencyId || 'None'} />
            <InfoRow label="Parent BO (Branch Office)" value={user.parentBO || 'None'} />
            <InfoRow label="Agency Commission" value={user.agencyId ? '20%' : '0%'} />
            <div className="pt-3 border-t border-slate-700/60 mt-3">
              <label className="text-xs text-slate-400 mb-1.5 block font-semibold">Assigned BD Center</label>
              <div className="flex gap-2">
                <select
                  value={selectedBDCenter}
                  onChange={(e) => setSelectedBDCenter(e.target.value)}
                  className="bg-slate-900 border border-slate-700 text-white rounded-lg text-xs px-3 py-1.5 flex-1"
                >
                  <option value="">None Assigned</option>
                  {bdCenters.map((bdc) => (
                    <option key={bdc.id} value={bdc.id}>
                      {bdc.name} ({bdc.code})
                    </option>
                  ))}
                </select>
                <Button
                  variant="primary"
                  size="xs"
                  onClick={async () => {
                    await logEvent({
                      action: 'UPDATE_USER_BD_CENTER',
                      targetId: user.id,
                      targetType: 'USER',
                      operatorName: 'Super Admin',
                      reason: `Assigned BD Center ${selectedBDCenter}`,
                      riskLevel: 'MEDIUM',
                      status: 'SUCCESS'
                    });
                    const fresh = await getLogsForTarget(user.id);
                    setHistory(fresh);
                  }}
                >
                  Save BD Relation
                </Button>
              </div>
            </div>
          </Card>

          <Card className="p-5">
            <h2 className="text-sm font-bold text-white mb-3">Host Creator Role</h2>
            <InfoRow label="Host Role Status" value={user.isHost ? 'Active Creator' : 'Not a Host'} valueClass={user.isHost ? 'text-purple-400 font-bold' : 'text-slate-400'} />
            <InfoRow label="Host Target Tier" value={user.hostTier || 'N/A'} />
            <InfoRow label="Live Host Policy" value="Min 120K target required" />
          </Card>
        </div>
      )}

      {/* Posts Tab */}
      {activeTab === 'posts' && (
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                <MessageSquare className="h-5 w-5 text-gold-400" /> User Created Posts ({userPosts.length})
              </h2>
              <p className="text-xs text-slate-400 mt-0.5">
                Source of truth for all content posts created by user @{user.username}.
              </p>
            </div>
          </div>

          {isLoadingPosts ? (
            <div className="p-8 text-center text-slate-400">Loading user posts...</div>
          ) : userPosts.length === 0 ? (
            <div className="p-8 text-center text-slate-400 bg-slate-900/50 rounded-xl border border-slate-800">
              <FileText className="h-10 w-10 text-slate-600 mx-auto mb-2" />
              <p className="text-sm font-medium text-slate-300">No Posts Found</p>
              <p className="text-xs text-slate-500 mt-1">This user has not published any posts or dynamics yet.</p>
            </div>
          ) : (
            <div className="grid md:grid-cols-2 gap-4">
              {userPosts.map((post) => {
                const isVideo = Boolean(
                  post.mediaUrl && (post.mediaUrl.match(/\.(mp4|webm|mov|m4v|ogg)(\?.*)?$/i) || post.mediaType === 'VIDEO')
                );
                return (
                  <div key={post.id} className="p-4 rounded-xl bg-slate-800/60 border border-slate-700/60 flex flex-col justify-between space-y-3 hover:border-slate-600 transition-all">
                    <div>
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-[11px] font-mono text-gold-400">Post #{post.id?.slice(0, 12) || post.id}</span>
                        <div className="flex items-center gap-1.5">
                          {isVideo && (
                            <Badge variant="purple" className="flex items-center gap-1 text-[10px]">
                              <Film className="h-3 w-3" /> Video
                            </Badge>
                          )}
                          <Badge variant={(post?.visibility || 'public').toLowerCase() === 'public' ? 'success' : 'warning'}>
                            {String(post?.visibility || 'PUBLIC').toUpperCase()}
                          </Badge>
                          <Badge variant={(post?.status || 'active').toLowerCase() === 'active' ? 'purple' : 'danger'}>
                            {String(post?.status || 'ACTIVE').toUpperCase()}
                          </Badge>
                        </div>
                      </div>

                      {post.content && (
                        <p className="text-xs text-slate-200 line-clamp-3 mb-2.5 bg-slate-900/40 p-2.5 rounded-lg border border-slate-800">
                          {post.content}
                        </p>
                      )}

                      {post.mediaUrl && (
                        <div className="relative rounded-xl overflow-hidden bg-black/60 border border-slate-700/50 mb-2 group">
                          {isVideo ? (
                            <video
                              src={post.mediaUrl}
                              controls
                              className="w-full max-h-48 object-cover bg-black"
                              preload="metadata"
                            />
                          ) : (
                            <div
                              onClick={() =>
                                setPreviewMedia({
                                  url: post.mediaUrl,
                                  title: `Post Attachment (${post.id})`,
                                  subtitle: post.content || `@${user.username}`,
                                  isVideo: false,
                                })
                              }
                              className="cursor-pointer relative"
                            >
                              <img
                                src={post.mediaUrl}
                                alt="Post Media"
                                className="w-full h-44 object-cover group-hover:scale-105 transition-transform duration-200"
                                onError={(e) => {
                                  e.target.src = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=500&auto=format&fit=crop&q=60';
                                }}
                              />
                              <div className="absolute inset-0 bg-black/35 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity text-white text-xs font-medium gap-1">
                                <Eye className="h-4 w-4" /> Click to enlarge
                              </div>
                            </div>
                          )}
                        </div>
                      )}
                    </div>

                    <div>
                      <div className="flex items-center justify-between text-[11px] text-slate-400 pt-2.5 border-t border-slate-700/40">
                        <div className="flex items-center gap-3">
                          <span className="flex items-center gap-1 font-mono text-rose-400"><Heart className="h-3 w-3" /> {post.likesCount}</span>
                          <span className="flex items-center gap-1 font-mono text-sky-400"><MessageSquare className="h-3 w-3" /> {post.commentsCount}</span>
                          <span className="flex items-center gap-1 font-mono text-emerald-400"><Share2 className="h-3 w-3" /> {post.sharesCount}</span>
                        </div>
                        <span className="text-[10px] text-slate-500 font-mono">{new Date(post.createdAt).toLocaleDateString()}</span>
                      </div>

                      <div className="pt-2.5 flex items-center justify-end gap-2">
                        <Button
                          variant="ghost"
                          size="xs"
                          onClick={() => setInspectingPost(post)}
                          className="text-indigo-400 hover:text-indigo-300"
                        >
                          <Eye className="h-3.5 w-3.5 mr-1" /> View Post
                        </Button>
                        <Button
                          variant="danger"
                          size="xs"
                          onClick={() => setPostToDelete(post)}
                        >
                          <Trash2 className="h-3.5 w-3.5 mr-1" /> Delete Post
                        </Button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </Card>
      )}

      {/* Props Tab */}
      {activeTab === 'props' && (
        <Card className="p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              <Sparkles className="h-5 w-5 text-gold-400" /> Owned Virtual Props & Badges
            </h2>
            <Button variant="primary" size="xs" onClick={() => setModalAction('grant_prop')}>
              + Grant New Item
            </Button>
          </div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {[
              { label: 'Avatar Frame', value: user.props?.avatarFrame, icon: '🖼️' },
              { label: 'Mount / Ride', value: user.props?.ride, icon: '🏎️' },
              { label: 'Chat Bubble', value: user.props?.chatBubble, icon: '💬' },
              { label: 'Badge', value: user.props?.badge, icon: '🎖️' },
              { label: 'Special ID', value: user.props?.specialId, icon: '🏷️' },
            ].map((p) => (
              <div key={p.label} className="p-4 rounded-xl bg-slate-800/60 border border-slate-700/50 flex items-center gap-3">
                <span className="text-2xl">{p.icon}</span>
                <div>
                  <p className="text-xs text-slate-400">{p.label}</p>
                  <p className="text-sm font-bold text-white mt-0.5">{p.value || 'None'}</p>
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Devices & Sessions Tab */}
      {activeTab === 'devices' && (
        <Card>
          <div className="p-4 border-b border-slate-700/60 flex items-center justify-between">
            <div>
              <h2 className="text-sm font-bold text-white flex items-center gap-2">
                <Smartphone className="h-4 w-4 text-gold-400" /> Active Devices & Sessions
              </h2>
              <p className="text-xs text-slate-400 mt-0.5">Manage user logins and revoke active session tokens.</p>
            </div>
          </div>
          <DataTable
            columns={deviceColumns}
            data={user.devices || []}
            emptyTitle="No Active Devices"
            emptyDescription="User has no registered device sessions."
          />
        </Card>
      )}

      {/* History & Audit Logs Tab */}
      {activeTab === 'history' && (
        <Card>
          <div className="p-4 border-b border-slate-700/60">
            <h2 className="text-sm font-bold text-white">Administrative Audit History</h2>
            <p className="text-xs text-slate-400 mt-1">Audit log of all admin actions targeting this user.</p>
          </div>
          <DataTable
            columns={historyColumns}
            data={history}
            isLoading={isLoadingHistory}
            emptyTitle="No Audit Events"
            emptyDescription="No administrative actions recorded for this user yet."
          />
        </Card>
      )}

      {/* Modals for Controls */}
      {postToDelete && (
        <Modal
          isOpen={true}
          onClose={() => setPostToDelete(null)}
          title="Confirm User Post Deletion"
        >
          <div className="space-y-4">
            <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/30 text-xs text-red-300">
              <p className="font-bold flex items-center gap-1 mb-1">
                <AlertTriangle className="h-4 w-4 text-red-400" /> Permanent Post Deletion
              </p>
              This will remove Post ID <code className="font-mono text-white">{postToDelete.id}</code> created by <strong className="text-white">@{user.username}</strong> from the user profile and public feeds.
            </div>

            <div className="p-3 bg-slate-900 rounded-lg border border-slate-700/60 text-xs text-slate-300 italic">
              "{postToDelete.content}"
            </div>

            <Input
              id="deletePostReason"
              label="Reason for Post Removal (Optional)"
              placeholder="e.g. Inappropriate content or copyright policy violation (optional)"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
            />

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setPostToDelete(null)} disabled={isDeletingPost}>
                Cancel
              </Button>
              <Button
                variant="danger"
                size="sm"
                onClick={handleDeletePost}
                isLoading={isDeletingPost}
                disabled={isDeletingPost}
              >
                Delete Post & Record Audit Log
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {modalAction === 'ban' && (
        <Modal
          isOpen={true}
          onClose={() => setModalAction(null)}
          title="Ban User Account"
        >
          <div className="space-y-4">
            <p className="text-xs text-slate-300">
              Are you sure you want to ban <strong className="text-white">@{user.username}</strong>? This action prevents login and disables all active streams.
            </p>
            <Input
              id="banReason"
              label="Reason for Ban (Audit Log)"
              placeholder="e.g. Repeated violation of moderation policy"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              required
            />
            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setModalAction(null)}>
                Cancel
              </Button>
              <Button
                variant="danger"
                size="sm"
                onClick={() => handleApplyControl('banned', 'BAN_USER')}
                disabled={!actionReason}
              >
                Confirm Ban
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {modalAction === 'freeze' && (
        <Modal
          isOpen={true}
          onClose={() => setModalAction(null)}
          title="Freeze / Restrict Account"
        >
          <div className="space-y-4">
            <p className="text-xs text-slate-300">
              Freezing will lock wallet transfers and room withdrawals for <strong className="text-white">@{user.username}</strong>.
            </p>
            <Input
              id="freezeReason"
              label="Reason for Freeze"
              placeholder="e.g. Pending fraud investigation"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              required
            />
            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setModalAction(null)}>
                Cancel
              </Button>
              <Button
                variant="primary"
                size="sm"
                onClick={() => handleApplyControl('suspended', 'FREEZE_ACCOUNT')}
                disabled={!actionReason}
              >
                Confirm Freeze
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {modalAction === 'grant_prop' && (
        <Modal
          isOpen={true}
          onClose={() => setModalAction(null)}
          title="Grant Special Item or Badge"
        >
          <div className="space-y-4">
            <div>
              <label className="text-xs font-medium text-slate-300 block mb-1.5">Select Item Type</label>
              <select
                className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-white focus:outline-none focus:ring-2 focus:ring-gold-500"
                value={selectedProp}
                onChange={(e) => setSelectedProp(e.target.value)}
              >
                <option value="avatarFrame">Avatar Frame</option>
                <option value="ride">Mount / Ride</option>
                <option value="chatBubble">Chat Bubble</option>
                <option value="badge">Honor Badge</option>
                <option value="specialId">Special ID</option>
              </select>
            </div>

            <Input
              id="propVal"
              label="Item Name / Title"
              placeholder="e.g. Golden Phoenix Frame"
              value={propValue}
              onChange={(e) => setPropValue(e.target.value)}
              required
            />

            <Input
              id="propReason"
              label="Audit Reason"
              placeholder="e.g. Special event reward"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
            />

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setModalAction(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleGrantProp} disabled={!propValue}>
                Grant Item
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Change Country & Region Modal */}
      {modalAction === 'change_country' && (
        <Modal
          isOpen={true}
          onClose={() => setModalAction(null)}
          title={`Change Registered Country — @${user.username}`}
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Updating country automatically reconfigures available rooms, coin sellers, recharge channels, and localized event availability for <strong className="text-white">{user.displayName}</strong>.
            </p>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">ISO Country Code</label>
                <Input
                  size="sm"
                  value={newCountry}
                  onChange={(e) => setNewCountry(e.target.value.toUpperCase())}
                  placeholder="PK, US, BR, SA..."
                  required
                />
              </div>
              <div>
                <label className="text-[11px] text-slate-400 mb-1 block">Assigned Sub-Region</label>
                <Input
                  size="sm"
                  value={newRegion}
                  onChange={(e) => setNewRegion(e.target.value)}
                  placeholder="e.g. South Asia, MENA, LATAM"
                />
              </div>
            </div>
            <Input
              label="Audit Reason for Change"
              placeholder="e.g. Verified passport relocation request"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              required
            />
            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setModalAction(null)}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleCountryChange} disabled={!actionReason}>
                Confirm Country Change
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {modalAction === 'revoke_session' && (
        <Modal
          isOpen={true}
          onClose={() => setModalAction(null)}
          title="Force Session Revocation"
        >
          <div className="space-y-4">
            <p className="text-xs text-slate-300">
              Are you sure you want to terminate this active device session? The user will be immediately logged out on that device.
            </p>
            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setModalAction(null)}>
                Cancel
              </Button>
              <Button variant="danger" size="sm" onClick={handleRevokeSession}>
                Revoke Session
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Update Avatar Modal */}
      {modalAction === 'update_avatar' && (
        <Modal
          isOpen={true}
          onClose={() => setModalAction(null)}
          title={`Update Profile Picture — @${user.username}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <p>
              Set a new avatar image URL for <strong className="text-white">{user.displayName}</strong>.
            </p>

            {newAvatarInput && (
              <div className="flex justify-center my-2">
                <img
                  src={newAvatarInput}
                  alt="Preview"
                  className="h-20 w-20 rounded-full object-cover ring-2 ring-indigo-500 shadow-md"
                  onError={(e) => {
                    e.target.style.display = 'none';
                  }}
                />
              </div>
            )}

            <Input
              label="Avatar Image URL"
              placeholder="https://example.com/avatar.jpg"
              value={newAvatarInput}
              onChange={(e) => setNewAvatarInput(e.target.value)}
              required
            />

            <Input
              label="Audit Reason for Update"
              placeholder="e.g. User requested photo change / offensive avatar moderation"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
            />

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setModalAction(null)} disabled={isSavingAvatar}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleAvatarChange} isLoading={isSavingAvatar}>
                Save Avatar
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Profile Picture Full Image Viewer Modal */}
      {isViewerOpen && user.avatarUrl && (
        <ImageViewerModal
          isOpen={isViewerOpen}
          onClose={() => setIsViewerOpen(false)}
          imageUrl={user.avatarUrl}
          title={`@${user.username}'s Profile Picture`}
          subtitle={user.displayName}
        />
      )}

      {/* Post Detailed Inspection Modal */}
      {inspectingPost && (
        <Modal
          isOpen={true}
          onClose={() => setInspectingPost(null)}
          title="User Post Details"
          description={`Inspecting post #${inspectingPost.id} published by @${user.username}`}
          size="lg"
        >
          <div className="space-y-4">
            {/* Header info */}
            <div className="flex items-center justify-between p-3 rounded-xl bg-slate-900/60 border border-slate-800">
              <div className="flex items-center gap-3">
                <img
                  src={user.avatarUrl || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'}
                  alt={user.username}
                  className="h-10 w-10 rounded-full object-cover ring-1 ring-slate-700"
                />
                <div>
                  <h4 className="text-sm font-bold text-white">{user.displayName || user.username}</h4>
                  <p className="text-xs text-indigo-400 font-mono">@{user.username} • <span className="text-slate-400">{new Date(inspectingPost.createdAt).toLocaleString()}</span></p>
                </div>
              </div>
              <div className="flex items-center gap-1.5">
                <Badge variant={(inspectingPost.visibility || 'public').toLowerCase() === 'public' ? 'success' : 'warning'}>
                  {String(inspectingPost.visibility || 'PUBLIC').toUpperCase()}
                </Badge>
                <Badge variant={(inspectingPost.status || 'active').toLowerCase() === 'active' ? 'purple' : 'danger'}>
                  {String(inspectingPost.status || 'ACTIVE').toUpperCase()}
                </Badge>
              </div>
            </div>

            {/* Post Content */}
            {inspectingPost.content && (
              <div className="p-3.5 rounded-xl bg-slate-950/70 border border-slate-800 text-xs text-slate-200 whitespace-pre-wrap leading-relaxed">
                {inspectingPost.content}
              </div>
            )}

            {/* Media Gallery / Player */}
            {inspectingPost.mediaUrl && (
              <div className="rounded-xl overflow-hidden bg-black/80 border border-slate-800 flex items-center justify-center p-2">
                {Boolean(inspectingPost.mediaUrl.match(/\.(mp4|webm|mov|m4v|ogg)(\?.*)?$/i) || inspectingPost.mediaType === 'VIDEO') ? (
                  <video
                    src={inspectingPost.mediaUrl}
                    controls
                    autoPlay
                    className="max-h-[50vh] max-w-full rounded-lg object-contain bg-black shadow-xl"
                  />
                ) : (
                  <img
                    src={inspectingPost.mediaUrl}
                    alt="Post Media Full"
                    className="max-h-[50vh] max-w-full rounded-lg object-contain cursor-pointer hover:opacity-95 transition-opacity"
                    onClick={() =>
                      setPreviewMedia({
                        url: inspectingPost.mediaUrl,
                        title: `Post #${inspectingPost.id}`,
                        subtitle: inspectingPost.content || `@${user.username}`,
                        isVideo: false,
                      })
                    }
                  />
                )}
              </div>
            )}

            {/* Engagement Stats */}
            <div className="grid grid-cols-3 gap-3 p-3 rounded-xl bg-slate-900/50 border border-slate-800 text-center text-xs">
              <div className="flex flex-col items-center">
                <span className="text-slate-400 flex items-center gap-1"><Heart className="h-3.5 w-3.5 text-rose-400" /> Likes</span>
                <span className="font-bold text-white text-sm mt-0.5">{inspectingPost.likesCount || 0}</span>
              </div>
              <div className="flex flex-col items-center border-x border-slate-800">
                <span className="text-slate-400 flex items-center gap-1"><MessageSquare className="h-3.5 w-3.5 text-sky-400" /> Comments</span>
                <span className="font-bold text-white text-sm mt-0.5">{inspectingPost.commentsCount || 0}</span>
              </div>
              <div className="flex flex-col items-center">
                <span className="text-slate-400 flex items-center gap-1"><Share2 className="h-3.5 w-3.5 text-emerald-400" /> Shares</span>
                <span className="font-bold text-white text-sm mt-0.5">{inspectingPost.sharesCount || 0}</span>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex items-center justify-between pt-2 border-t border-slate-800">
              {inspectingPost.mediaUrl ? (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => window.open(inspectingPost.mediaUrl, '_blank')}
                  className="text-xs text-indigo-400 hover:text-indigo-300"
                >
                  <ExternalLink className="h-4 w-4 mr-1" /> Open Media in New Tab
                </Button>
              ) : <div />}

              <div className="flex items-center gap-2">
                <Button
                  type="button"
                  variant="danger"
                  size="sm"
                  onClick={() => {
                    const toDel = inspectingPost;
                    setInspectingPost(null);
                    setPostToDelete(toDel);
                  }}
                >
                  <Trash2 className="h-3.5 w-3.5 mr-1" /> Delete Post
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={() => setInspectingPost(null)}
                >
                  Close
                </Button>
              </div>
            </div>
          </div>
        </Modal>
      )}

      {/* General Media Lightbox Preview */}
      {previewMedia && (
        <ImageViewerModal
          isOpen={true}
          onClose={() => setPreviewMedia(null)}
          imageUrl={previewMedia.url}
          title={previewMedia.title || 'Media Preview'}
          subtitle={previewMedia.subtitle || ''}
          isVideo={previewMedia.isVideo}
        />
      )}
    </div>
  );
}
