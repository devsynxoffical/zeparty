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
  Share2, Trash2, FileText
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Badge, StatusBadge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { Input } from '../../components/ui/Input';
import { DataTable } from '../../components/tables/DataTable';
import { MOCK_USERS } from '../../mocks/users.mock';
import { MOCK_BD_CENTERS } from '../../mocks/bdCenters.mock';
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

  const initialUser = MOCK_USERS.find((u) => u.id === id) || MOCK_USERS[0];
  const [user, setUser] = useState(initialUser);
  const [activeTab, setActiveTab] = useState('overview');
  const [history, setHistory] = useState([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);

  // Posts State
  const [userPosts, setUserPosts] = useState([]);
  const [isLoadingPosts, setIsLoadingPosts] = useState(false);
  const [postToDelete, setPostToDelete] = useState(null);

  // BD Center Assignment State
  const [selectedBDCenter, setSelectedBDCenter] = useState(user.bdCenterId || 'bdc-101');

  // Modals state
  const [modalAction, setModalAction] = useState(null); // 'ban' | 'freeze' | 'reset' | 'grant_prop' | 'revoke_session' | 'change_country'
  const [actionReason, setActionReason] = useState('');
  const [selectedProp, setSelectedProp] = useState('avatarFrame');
  const [propValue, setPropValue] = useState('');
  const [targetSessionId, setTargetSessionId] = useState(null);

  // Country Change state
  const [newCountry, setNewCountry] = useState(user.country || 'PK');
  const [newRegion, setNewRegion] = useState(user.region || 'South Asia');

  const handleCountryChange = async () => {
    setUser({ ...user, country: newCountry, region: newRegion });
    await logAdminAction({
      action: 'USER_COUNTRY_CHANGED',
      module: 'User Management',
      targetType: 'USER',
      targetId: user.id,
      targetName: user.displayName,
      reason: actionReason || `Country updated to ${newCountry} (${newRegion})`,
      riskLevel: 'HIGH',
      status: 'SUCCESS'
    });
    setModalAction(null);
    setActionReason('');
  };

  useEffect(() => {
    if (user) {
      getLogsForTarget(user.id).then((data) => {
        setHistory(data);
        setIsLoadingHistory(false);
      });
      setIsLoadingPosts(true);
      getUserPosts(user.id).then((posts) => {
        setUserPosts(posts);
        setIsLoadingPosts(false);
      });
    }
  }, [user]);

  const handleDeletePost = async () => {
    if (!postToDelete) return;
    await deleteUserPost(postToDelete.id, actionReason || 'Violation of content policy');
    setUserPosts((prev) => prev.filter((p) => p.id !== postToDelete.id));

    await logEvent({
      action: 'DELETE_USER_POST',
      targetId: user.id,
      targetType: 'POST',
      operatorName: 'Super Admin',
      reason: actionReason || 'Moderation content removal',
      riskLevel: 'MEDIUM',
      status: 'SUCCESS',
    });

    setPostToDelete(null);
    setActionReason('');
    const freshLogs = await getLogsForTarget(user.id);
    setHistory(freshLogs);
  };

  const handleApplyControl = async (newStatus, actionLabel, defaultReason = 'Platform security alignment and moderation compliance') => {
    const finalReason = actionReason || defaultReason;
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
    setHistory(freshLogs);
  };

  const handleGrantProp = async () => {
    if (!propValue) return;
    const updatedProps = { ...user.props, [selectedProp]: propValue };
    setUser({ ...user, props: updatedProps });

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
        <Badge variant={row.status === 'active' ? 'success' : 'danger'}>
          {row.status.toUpperCase()}
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

  if (!user) return null;

  const bgColor = avatarColor(user.id);

  return (
    <div className="flex flex-col gap-6">
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
              className="h-20 w-20 rounded-2xl flex items-center justify-center text-white text-3xl font-bold flex-shrink-0 shadow-xl border border-white/10"
              style={{ backgroundColor: bgColor }}
            >
              {user.displayName.charAt(0)}
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
                  {MOCK_BD_CENTERS.map((bdc) => (
                    <option key={bdc.id} value={bdc.id}>
                      {bdc.name} ({bdc.code}) - {bdc.managerName}
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
              {userPosts.map((post) => (
                <div key={post.id} className="p-4 rounded-xl bg-slate-800/60 border border-slate-700/60 flex flex-col justify-between space-y-3">
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <span className="text-[11px] font-mono text-gold-400">{post.id}</span>
                      <div className="flex items-center gap-2">
                        <Badge variant={post.visibility === 'public' ? 'success' : 'warning'}>
                          {post.visibility.toUpperCase()}
                        </Badge>
                        <Badge variant={post.status === 'active' ? 'purple' : 'danger'}>
                          {post.status.toUpperCase()}
                        </Badge>
                      </div>
                    </div>
                    <p className="text-xs text-slate-200 line-clamp-3 mb-2">{post.content}</p>
                    {post.mediaUrl && (
                      <div className="rounded-lg overflow-hidden border border-slate-700/50 max-h-40 mb-2">
                        <img src={post.mediaUrl} alt="Post Media" className="w-full h-36 object-cover" />
                      </div>
                    )}
                  </div>

                  <div>
                    <div className="flex items-center justify-between text-[11px] text-slate-400 pt-2 border-t border-slate-700/40">
                      <div className="flex items-center gap-3">
                        <span className="flex items-center gap-1"><Heart className="h-3 w-3 text-rose-400" /> {post.likesCount}</span>
                        <span className="flex items-center gap-1"><MessageSquare className="h-3 w-3 text-sky-400" /> {post.commentsCount}</span>
                        <span className="flex items-center gap-1"><Share2 className="h-3 w-3 text-emerald-400" /> {post.sharesCount}</span>
                      </div>
                      <span>{new Date(post.createdAt).toLocaleDateString()}</span>
                    </div>

                    <div className="pt-2 flex justify-end">
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
              ))}
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
              label="Reason for Post Removal (Audit Log Required)"
              placeholder="e.g. Inappropriate content or copyright policy violation"
              value={actionReason}
              onChange={(e) => setActionReason(e.target.value)}
              required
            />

            <div className="flex justify-end gap-3 pt-2">
              <Button variant="outline" size="sm" onClick={() => setPostToDelete(null)}>
                Cancel
              </Button>
              <Button
                variant="danger"
                size="sm"
                onClick={handleDeletePost}
                disabled={!actionReason}
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
    </div>
  );
}
