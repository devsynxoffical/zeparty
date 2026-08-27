// ============================================================
// ZeParty Admin Portal — Admin Profile Page (JSX)
// ============================================================

import React, { useState } from 'react';
import {
  User,
  ShieldCheck,
  Mail,
  Key,
  Save,
  CheckCircle2,
  Lock,
  Clock,
  Shield,
  BadgeCheck,
  Building,
  Phone,
  Calendar,
  Activity,
  Award,
  Globe,
  BellRing,
  AlertCircle,
} from 'lucide-react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { Badge } from '../../components/ui/Badge';
import { StatCard } from '../../components/ui/StatCard';
import { Avatar } from '../../components/common/Avatar';
import { useAuth } from '../../hooks/useAuth';

export function ProfilePage() {
  const { admin } = useAuth();
  const [activeSubTab, setActiveSubTab] = useState('overview'); // 'overview' | 'security' | 'activity'

  const [profile, setProfile] = useState({
    displayName: admin?.displayName || 'Super Admin',
    email: admin?.email || 'superadmin@zeparty.app',
    username: admin?.username || 'superadmin',
    phone: '+1 (555) 019-2834',
    department: 'Executive Governance & Operations',
    timezone: 'UTC -05:00 (EST)',
    bio: 'Master Administrator overseeing platform safety, financial transactions, agency verifications, and staff permissions.',
  });

  const [passwords, setPasswords] = useState({
    currentPassword: '',
    newPassword: '',
    confirmPassword: '',
  });

  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [isSavingPassword, setIsSavingPassword] = useState(false);
  const [toast, setToast] = useState(null);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3500);
  };

  const handleUpdateProfile = (e) => {
    e.preventDefault();
    setIsSavingProfile(true);
    setTimeout(() => {
      setIsSavingProfile(false);
      showToast('Admin profile details updated successfully.');
    }, 500);
  };

  const handleUpdatePassword = (e) => {
    e.preventDefault();
    if (passwords.newPassword !== passwords.confirmPassword) {
      showToast('New passwords do not match.', 'error');
      return;
    }
    if (passwords.newPassword.length < 6) {
      showToast('Password must be at least 6 characters.', 'error');
      return;
    }
    setIsSavingPassword(true);
    setTimeout(() => {
      setIsSavingPassword(false);
      setPasswords({ currentPassword: '', newPassword: '', confirmPassword: '' });
      showToast('Password changed successfully.');
    }, 500);
  };

  const AUDIT_LOGS = [
    {
      id: 1,
      action: 'Saved Permission Matrix',
      details: 'Updated Finance Manager module access',
      time: '15 mins ago',
      ip: '192.168.1.102',
    },
    {
      id: 2,
      action: 'Created Admin Account',
      details: 'Added Sarah Jenkins (Operations Team)',
      time: '2 hours ago',
      ip: '192.168.1.102',
    },
    {
      id: 3,
      action: 'Approved Withdrawal',
      details: 'Payout #WD-9942 approved ($1,250.00)',
      time: 'Yesterday at 4:20 PM',
      ip: '192.168.1.102',
    },
    {
      id: 4,
      action: 'System Settings Update',
      details: 'Enabled 2FA enforcement policy',
      time: 'Aug 15, 2026 at 11:30 AM',
      ip: '192.168.1.102',
    },
  ];

  return (
    <div className="space-y-6 pb-12">
      {/* Toast Banner */}
      {toast && (
        <div
          className={[
            'fixed top-16 right-6 z-50 flex items-center gap-3 px-4 py-3 rounded-xl shadow-2xl border text-sm font-medium transition-all duration-300 animate-in fade-in slide-in-from-top-4',
            toast.type === 'error'
              ? 'bg-red-950/90 border-red-500/50 text-red-200'
              : 'bg-emerald-950/90 border-emerald-500/50 text-emerald-200',
          ].join(' ')}
          role="alert"
        >
          {toast.type === 'error' ? (
            <AlertCircle className="h-5 w-5 text-red-400 flex-shrink-0" />
          ) : (
            <CheckCircle2 className="h-5 w-5 text-emerald-400 flex-shrink-0" />
          )}
          <span>{toast.message}</span>
        </div>
      )}

      {/* Header Banner */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between border-b border-slate-800 pb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="text-xl font-bold text-white tracking-tight">Admin Profile</h1>
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-gold-500/15 text-gold-400 border border-gold-500/30">
              <ShieldCheck className="h-4 w-4" />
              SUPER ADMIN — Master System Access
            </span>
          </div>
          <p className="mt-1 text-xs text-slate-400">
            View and manage your master administrator profile, security settings, and audit log session details.
          </p>
        </div>

        <div className="flex items-center gap-2 mt-3 md:mt-0">
          <Button
            variant={activeSubTab === 'overview' ? 'primary' : 'outline'}
            size="sm"
            onClick={() => setActiveSubTab('overview')}
          >
            Overview & Profile
          </Button>
          <Button
            variant={activeSubTab === 'security' ? 'primary' : 'outline'}
            size="sm"
            onClick={() => setActiveSubTab('security')}
          >
            Security & Passwords
          </Button>
          <Button
            variant={activeSubTab === 'activity' ? 'primary' : 'outline'}
            size="sm"
            onClick={() => setActiveSubTab('activity')}
          >
            Audit Log
          </Button>
        </div>
      </div>

      {/* Profile Header Hero Card */}
      <Card className="p-6">
        <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5">
          <Avatar name={profile.displayName} size="xl" />
          <div className="flex-1 text-center sm:text-left space-y-2">
            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-2.5">
              <h2 className="text-xl font-bold text-white">{profile.displayName}</h2>
              <Badge variant="primary">Super Admin</Badge>
              <span className="inline-flex items-center gap-1 text-xs text-emerald-400 font-semibold bg-emerald-500/10 px-2.5 py-0.5 rounded-full border border-emerald-500/20">
                <BadgeCheck className="h-3.5 w-3.5" /> Account Verified
              </span>
            </div>

            <p className="text-xs text-slate-300 max-w-2xl">{profile.bio}</p>

            <div className="flex flex-wrap items-center justify-center sm:justify-start gap-4 pt-1 text-xs text-slate-400">
              <span className="flex items-center gap-1.5">
                <Mail className="h-3.5 w-3.5 text-gold-400" />
                {profile.email}
              </span>
              <span className="flex items-center gap-1.5">
                <Building className="h-3.5 w-3.5 text-sky-400" />
                {profile.department}
              </span>
              <span className="flex items-center gap-1.5">
                <Globe className="h-3.5 w-3.5 text-purple-400" />
                {profile.timezone}
              </span>
              <span className="flex items-center gap-1.5">
                <Clock className="h-3.5 w-3.5 text-emerald-400" />
                Active Session
              </span>
            </div>
          </div>
        </div>
      </Card>

      {/* Statistics Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          title="Account Role"
          value="Super Admin"
          icon={ShieldCheck}
          iconColor="text-gold-400"
          iconBg="bg-gold-500/10"
          subValue="Unrestricted Master Control"
        />
        <StatCard
          title="Module Access"
          value="11 / 11 Modules"
          icon={Award}
          iconColor="text-emerald-400"
          iconBg="bg-emerald-500/10"
          subValue="100% Unlocked Access"
        />
        <StatCard
          title="Security Protocol"
          value="2FA Enforced"
          icon={Lock}
          iconColor="text-sky-400"
          iconBg="bg-sky-500/10"
          subValue="TOTP Authenticator Active"
        />
        <StatCard
          title="Active Sessions"
          value="1 Device"
          icon={Activity}
          iconColor="text-purple-400"
          iconBg="bg-purple-500/10"
          subValue="Current Admin Web App"
        />
      </div>

      {/* TAB 1: OVERVIEW & PROFILE EDIT */}
      {activeSubTab === 'overview' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <Card className="lg:col-span-2 p-6">
            <h3 className="text-sm font-bold text-white uppercase tracking-wider text-gold-400 border-b border-slate-800 pb-3 mb-4">
              Edit Account Credentials
            </h3>
            <form onSubmit={handleUpdateProfile} className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="Display Name"
                  value={profile.displayName}
                  onChange={(e) => setProfile({ ...profile, displayName: e.target.value })}
                  required
                />
                <Input
                  label="Email Address"
                  type="email"
                  value={profile.email}
                  onChange={(e) => setProfile({ ...profile, email: e.target.value })}
                  required
                />
                <Input
                  label="Username"
                  value={profile.username}
                  onChange={(e) => setProfile({ ...profile, username: e.target.value })}
                  required
                />
                <Input
                  label="Contact Phone"
                  value={profile.phone}
                  onChange={(e) => setProfile({ ...profile, phone: e.target.value })}
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <Input
                  label="Department"
                  value={profile.department}
                  onChange={(e) => setProfile({ ...profile, department: e.target.value })}
                />
                <Input
                  label="Timezone"
                  value={profile.timezone}
                  onChange={(e) => setProfile({ ...profile, timezone: e.target.value })}
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-medium text-slate-300">Admin Bio / Responsibility Scope</label>
                <textarea
                  rows="3"
                  value={profile.bio}
                  onChange={(e) => setProfile({ ...profile, bio: e.target.value })}
                  className="w-full rounded-xl border border-slate-700/80 bg-slate-900/60 p-3 text-xs text-white placeholder-slate-500 focus:border-gold-500 focus:outline-none focus:ring-1 focus:ring-gold-500"
                />
              </div>

              <div className="flex justify-end pt-3 border-t border-slate-800">
                <Button type="submit" variant="primary" size="sm" leftIcon={Save} isLoading={isSavingProfile}>
                  Save Profile Changes
                </Button>
              </div>
            </form>
          </Card>

          {/* Governance & Access Overview */}
          <Card className="p-6 flex flex-col justify-between">
            <div>
              <h3 className="text-sm font-bold text-white uppercase tracking-wider text-gold-400 border-b border-slate-800 pb-3 mb-4 flex items-center gap-2">
                <Shield className="h-4 w-4 text-gold-400" />
                Administrative Scope
              </h3>

              <div className="space-y-3 text-xs">
                <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/60 space-y-1">
                  <span className="text-slate-400">Governance Level:</span>
                  <p className="font-bold text-gold-400">Master Super Admin (Unrestricted)</p>
                </div>
                <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/60 space-y-1">
                  <span className="text-slate-400">Admin Management:</span>
                  <p className="font-semibold text-white">Full control over Admin & Manager accounts</p>
                </div>
                <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/60 space-y-1">
                  <span className="text-slate-400">Teams & Permissions:</span>
                  <p className="font-semibold text-white">Can create teams, edit roles & permission matrix</p>
                </div>
                <div className="p-3 rounded-xl bg-slate-800/60 border border-slate-700/60 space-y-1">
                  <span className="text-slate-400">Platform Financial Control:</span>
                  <p className="font-semibold text-emerald-400">Withdrawals, recharges & gift catalog audit</p>
                </div>
              </div>
            </div>

            <div className="mt-4 pt-3 border-t border-slate-800 text-[11px] text-slate-500">
              Account Created: Jan 1, 2026 • Account Status: Active
            </div>
          </Card>
        </div>
      )}

      {/* TAB 2: SECURITY & PASSWORDS */}
      {activeSubTab === 'security' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card className="p-6">
            <h3 className="text-sm font-bold text-white uppercase tracking-wider text-gold-400 border-b border-slate-800 pb-3 mb-4 flex items-center gap-2">
              <Lock className="h-4 w-4 text-gold-400" />
              Change Admin Password
            </h3>
            <form onSubmit={handleUpdatePassword} className="space-y-4">
              <Input
                label="Current Password"
                type="password"
                placeholder="••••••••"
                value={passwords.currentPassword}
                onChange={(e) => setPasswords({ ...passwords, currentPassword: e.target.value })}
                required
              />
              <Input
                label="New Password"
                type="password"
                placeholder="••••••••"
                value={passwords.newPassword}
                onChange={(e) => setPasswords({ ...passwords, newPassword: e.target.value })}
                required
              />
              <Input
                label="Confirm New Password"
                type="password"
                placeholder="••••••••"
                value={passwords.confirmPassword}
                onChange={(e) => setPasswords({ ...passwords, confirmPassword: e.target.value })}
                required
              />
              <div className="flex justify-end pt-3 border-t border-slate-800">
                <Button type="submit" variant="primary" size="sm" leftIcon={Key} isLoading={isSavingPassword}>
                  Update Password
                </Button>
              </div>
            </form>
          </Card>

          <Card className="p-6 space-y-4">
            <h3 className="text-sm font-bold text-white uppercase tracking-wider text-gold-400 border-b border-slate-800 pb-3 mb-4 flex items-center gap-2">
              <ShieldCheck className="h-4 w-4 text-gold-400" />
              Two-Factor Authentication (2FA)
            </h3>

            <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-xs text-emerald-300 space-y-2">
              <div className="flex items-center gap-2 font-bold text-emerald-400">
                <BadgeCheck className="h-4 w-4" />
                Two-Factor Authentication Enforced
              </div>
              <p className="text-slate-300">
                Your account is protected with Google Authenticator TOTP token verification on every login.
              </p>
            </div>

            <div className="space-y-2.5 text-xs text-slate-400 pt-2">
              <div className="flex justify-between items-center p-3 rounded-lg bg-slate-900 border border-slate-800">
                <span>Authenticator App Status:</span>
                <span className="font-semibold text-emerald-400">Active</span>
              </div>
              <div className="flex justify-between items-center p-3 rounded-lg bg-slate-900 border border-slate-800">
                <span>Session Timeout:</span>
                <span className="font-semibold text-white">60 Minutes</span>
              </div>
              <div className="flex justify-between items-center p-3 rounded-lg bg-slate-900 border border-slate-800">
                <span>IP Binding:</span>
                <span className="font-semibold text-white">Enabled (192.168.1.102)</span>
              </div>
            </div>
          </Card>
        </div>
      )}

      {/* TAB 3: AUDIT LOG */}
      {activeSubTab === 'activity' && (
        <Card className="p-6">
          <h3 className="text-sm font-bold text-white uppercase tracking-wider text-gold-400 border-b border-slate-800 pb-3 mb-4 flex items-center gap-2">
            <Activity className="h-4 w-4 text-gold-400" />
            Recent Admin Session Activity Log
          </h3>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs text-slate-300">
              <thead className="bg-slate-900 text-slate-400 uppercase text-[10px] border-b border-slate-800">
                <tr>
                  <th scope="col" className="px-4 py-3">Action</th>
                  <th scope="col" className="px-4 py-3">Details</th>
                  <th scope="col" className="px-4 py-3">Timestamp</th>
                  <th scope="col" className="px-4 py-3 text-right">IP Address</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/80">
                {AUDIT_LOGS.map((log) => (
                  <tr key={log.id} className="hover:bg-slate-800/40">
                    <td className="px-4 py-3 font-semibold text-white">{log.action}</td>
                    <td className="px-4 py-3 text-slate-400">{log.details}</td>
                    <td className="px-4 py-3 text-slate-400">{log.time}</td>
                    <td className="px-4 py-3 text-right font-mono text-slate-400">{log.ip}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}
