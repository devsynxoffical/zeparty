// ============================================================
// ZeParty Admin Portal — Teams & Roles Management Page (JSX)
// ============================================================

import React, { useEffect, useState } from 'react';
import {
  AlertTriangle,
  Check,
  CheckCircle2,
  ChevronRight,
  Edit2,
  Lock,
  Plus,
  RefreshCw,
  Search,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Trash2,
  UserCheck,
  UserPlus,
  Users,
  X,
  XCircle,
} from 'lucide-react';

import { Badge, StatusBadge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Select, Textarea } from '../../components/ui/Select';
import { Modal } from '../../components/ui/Modal';
import { StatCard } from '../../components/ui/StatCard';
import { usePermission } from '../../hooks/usePermission';
import { Avatar } from '../../components/common/Avatar';
import { formatDate } from '../../utils/format';

import {
  createAdmin,
  createRole,
  createTeam,
  deleteAdmin,
  getAdmins,
  getModulePermissions,
  getRoles,
  getTeams,
  toggleAdminStatus,
  toggleTeamStatus,
  updateAdmin,
  updateRole,
  updateTeam,
} from '../../services/modules/teamsRoles.service';

export function TeamsRolesPage() {
  const { canPerformAction } = usePermission();
  const [activeTab, setActiveTab] = useState('admins'); // 'admins' | 'teams' | 'roles'

  // Data states
  const [admins, setAdmins] = useState([]);
  const [teams, setTeams] = useState([]);
  const [roles, setRoles] = useState([]);
  const [modules, setModules] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  // Filters & Search
  const [searchQuery, setSearchQuery] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [teamFilter, setTeamFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  // Selected role for permission matrix edit
  const [selectedRoleId, setSelectedRoleId] = useState('super_admin');
  const [matrixPermissions, setMatrixPermissions] = useState([]);
  const [matrixDirty, setMatrixDirty] = useState(false);

  // Modals state
  const [adminModalOpen, setAdminModalOpen] = useState(false);
  const [editingAdmin, setEditingAdmin] = useState(null);
  const [presetTeamId, setPresetTeamId] = useState('');
  const [presetRoleId, setPresetRoleId] = useState('');

  const [teamModalOpen, setTeamModalOpen] = useState(false);
  const [editingTeam, setEditingTeam] = useState(null);

  const [roleModalOpen, setRoleModalOpen] = useState(false);
  const [editingRole, setEditingRole] = useState(null);

  // Confirm Dialog
  const [confirmDialog, setConfirmDialog] = useState({
    isOpen: false,
    title: '',
    message: '',
    actionType: '',
    payload: null,
  });

  // Notification Toast state
  const [toast, setToast] = useState(null);

  const showToast = (message, type = 'success') => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 4000);
  };

  // Load initial data
  const fetchData = async () => {
    setIsLoading(true);
    try {
      const [adminsData, teamsData, rolesData, modulesData] = await Promise.all([
        getAdmins(),
        getTeams(),
        getRoles(),
        getModulePermissions(),
      ]);

      setAdmins(adminsData);
      setTeams(teamsData);
      setRoles(rolesData);
      setModules(modulesData);

      // Initialize selected role permissions
      const initialRole = rolesData.find((r) => r.id === selectedRoleId) || rolesData[0];
      if (initialRole) {
        setSelectedRoleId(initialRole.id);
        setMatrixPermissions([...initialRole.permissions]);
        setMatrixDirty(false);
      }
    } catch (err) {
      showToast(err.message || 'Failed to load data', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // When selected role changes, update matrix permissions
  const handleRoleSelect = (roleId) => {
    const role = roles.find((r) => r.id === roleId);
    if (role) {
      setSelectedRoleId(roleId);
      setMatrixPermissions([...role.permissions]);
      setMatrixDirty(false);
    }
  };

  // Permission Matrix checkbox toggle
  const handleTogglePermission = (permId) => {
    const role = roles.find((r) => r.id === selectedRoleId);
    if (role?.isSuperAdmin) {
      showToast('Super Admin role has full unrestricted system access.', 'warning');
      return;
    }

    setMatrixPermissions((prev) => {
      const exists = prev.includes(permId);
      const updated = exists ? prev.filter((p) => p !== permId) : [...prev, permId];
      setMatrixDirty(true);
      return updated;
    });
  };

  // Select all permissions for a module
  const handleSelectModuleAll = (moduleId) => {
    const role = roles.find((r) => r.id === selectedRoleId);
    if (role?.isSuperAdmin) return;

    const moduleObj = modules.find((m) => m.id === moduleId);
    if (!moduleObj) return;

    const modPermIds = moduleObj.permissions.map((p) => p.id);
    setMatrixPermissions((prev) => {
      const newSet = new Set([...prev, ...modPermIds]);
      setMatrixDirty(true);
      return Array.from(newSet);
    });
  };

  // Clear all permissions for a module
  const handleClearModuleAll = (moduleId) => {
    const role = roles.find((r) => r.id === selectedRoleId);
    if (role?.isSuperAdmin) return;

    const moduleObj = modules.find((m) => m.id === moduleId);
    if (!moduleObj) return;

    const modPermIds = new Set(moduleObj.permissions.map((p) => p.id));
    setMatrixPermissions((prev) => {
      const updated = prev.filter((id) => !modPermIds.has(id));
      setMatrixDirty(true);
      return updated;
    });
  };

  // Save Role Permission Matrix changes
  const handleSaveMatrix = async () => {
    const role = roles.find((r) => r.id === selectedRoleId);
    if (!role) return;

    setIsSaving(true);
    try {
      const updated = await updateRole(role.id, { permissions: matrixPermissions });
      setRoles((prev) => prev.map((r) => (r.id === role.id ? updated : r)));
      setMatrixDirty(false);
      showToast(`Permission matrix saved for role: ${role.name}`);
    } catch (err) {
      showToast(err.message || 'Failed to update permissions', 'error');
    } finally {
      setIsSaving(false);
    }
  };

  // ---- ADMIN ACTIONS ----
  const handleOpenAddAdmin = (initialTeamId = '', initialRoleId = '') => {
    setEditingAdmin(null);
    setPresetTeamId(initialTeamId);
    setPresetRoleId(initialRoleId);
    setAdminModalOpen(true);
  };

  const handleOpenEditAdmin = (admin) => {
    setEditingAdmin(admin);
    setPresetTeamId('');
    setPresetRoleId('');
    setAdminModalOpen(true);
  };

  const handleToggleAdminStatusClick = (admin) => {
    if (admin.isSuperAdmin) {
      showToast('Action Prohibited: Super Admin account cannot be disabled.', 'error');
      return;
    }
    setConfirmDialog({
      isOpen: true,
      title: admin.status === 'active' ? 'Disable Account' : 'Enable Account',
      message: `Are you sure you want to ${
        admin.status === 'active' ? 'disable' : 'enable'
      } access for ${admin.name} (${admin.email})?`,
      actionType: 'toggleAdmin',
      payload: admin,
    });
  };

  const handleDeleteAdminClick = (admin) => {
    if (admin.isSuperAdmin) {
      showToast('Action Prohibited: Super Admin account cannot be deleted.', 'error');
      return;
    }
    setConfirmDialog({
      isOpen: true,
      title: 'Delete Admin Account',
      message: `Are you sure you want to permanently delete the admin account for ${admin.name}? This action cannot be undone.`,
      actionType: 'deleteAdmin',
      payload: admin,
    });
  };

  const handleConfirmAction = async () => {
    const { actionType, payload } = confirmDialog;
    setConfirmDialog((prev) => ({ ...prev, isOpen: false }));

    if (!payload) return;

    try {
      if (actionType === 'toggleAdmin') {
        const updated = await toggleAdminStatus(payload.id);
        setAdmins((prev) => prev.map((a) => (a.id === payload.id ? updated : a)));
        showToast(`Account status updated for ${updated.name}`);
      } else if (actionType === 'deleteAdmin') {
        await deleteAdmin(payload.id);
        setAdmins((prev) => prev.filter((a) => a.id !== payload.id));
        showToast(`Admin account deleted: ${payload.name}`);
      } else if (actionType === 'toggleTeam') {
        const updated = await toggleTeamStatus(payload.id);
        setTeams((prev) => prev.map((t) => (t.id === payload.id ? updated : t)));
        showToast(`Team status updated for ${updated.name}`);
      }
    } catch (err) {
      showToast(err.message || 'Action failed', 'error');
    }
  };

  // ---- TEAM ACTIONS ----
  const handleOpenAddTeam = () => {
    setEditingTeam(null);
    setTeamModalOpen(true);
  };

  const handleOpenEditTeam = (team) => {
    setEditingTeam(team);
    setTeamModalOpen(true);
  };

  // ---- ROLE ACTIONS ----
  const handleOpenAddRole = () => {
    setEditingRole(null);
    setRoleModalOpen(true);
  };

  // Filtered Admins List
  const filteredAdmins = admins.filter((a) => {
    const matchesSearch =
      !searchQuery ||
      a.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
      a.username.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesRole = !roleFilter || a.roleId === roleFilter;
    const matchesTeam = !teamFilter || a.teamIds?.includes(teamFilter);
    const matchesStatus = !statusFilter || a.status === statusFilter;
    return matchesSearch && matchesRole && matchesTeam && matchesStatus;
  });

  const selectedRoleObj = roles.find((r) => r.id === selectedRoleId);

  return (
    <div className="space-y-6 pb-12">
      {/* Toast Notification Banner */}
      {toast && (
        <div
          className={[
            'fixed top-16 right-6 z-50 flex items-center gap-3 px-4 py-3 rounded-xl shadow-2xl border text-sm font-medium transition-all duration-300 animate-in fade-in slide-in-from-top-4',
            toast.type === 'error'
              ? 'bg-red-950/90 border-red-500/50 text-red-200'
              : toast.type === 'warning'
              ? 'bg-amber-950/90 border-amber-500/50 text-amber-200'
              : 'bg-emerald-950/90 border-emerald-500/50 text-emerald-200',
          ].join(' ')}
          role="alert"
        >
          {toast.type === 'error' ? (
            <AlertTriangle className="h-5 w-5 text-red-400 flex-shrink-0" />
          ) : toast.type === 'warning' ? (
            <ShieldAlert className="h-5 w-5 text-amber-400 flex-shrink-0" />
          ) : (
            <CheckCircle2 className="h-5 w-5 text-emerald-400 flex-shrink-0" />
          )}
          <span>{toast.message}</span>
        </div>
      )}

      {/* Super Admin Access Control Banner */}
      <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between border-b border-slate-800 pb-5">
        <div>
          <div className="flex items-center gap-2.5">
            <h1 className="text-xl font-bold text-white tracking-tight">Teams & Roles</h1>
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-gold-500/15 text-gold-400 ring-1 ring-gold-500/30">
              <ShieldCheck className="h-4 w-4" />
              SUPER ADMIN — Full System Access
            </span>
          </div>
          <p className="mt-1 text-xs text-slate-400 max-w-2xl">
            Logged in as <strong className="text-white">Super Admin</strong>. You hold unrestricted administrative control to manage all Admins, Managers, Teams, Roles, and Permission Matrices.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          {canPerformAction('manage_admins') && (
            <Button
              variant="primary"
              size="sm"
              leftIcon={UserPlus}
              onClick={() => handleOpenAddAdmin()}
            >
              Add Admin
            </Button>
          )}
          {activeTab === 'teams' && canPerformAction('manage_teams') && (
            <Button
              variant="outline"
              size="sm"
              leftIcon={Plus}
              onClick={handleOpenAddTeam}
            >
              Create Team
            </Button>
          )}
          {activeTab === 'roles' && canPerformAction('manage_roles') && (
            <Button
              variant="outline"
              size="sm"
              leftIcon={Plus}
              onClick={handleOpenAddRole}
            >
              Create Role
            </Button>
          )}
        </div>
      </div>

      {/* Primary Navigation Tabs */}
      <div className="flex border-b border-slate-800">
        <button
          onClick={() => setActiveTab('admins')}
          className={[
            'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors duration-150',
            activeTab === 'admins'
              ? 'border-gold-500 text-gold-400 font-semibold'
              : 'border-transparent text-slate-400 hover:text-slate-200 hover:border-slate-700',
          ].join(' ')}
        >
          <Users className="h-4 w-4" />
          <span>Admins</span>
          <span className="ml-1.5 rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-300">
            {admins.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('teams')}
          className={[
            'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors duration-150',
            activeTab === 'teams'
              ? 'border-gold-500 text-gold-400 font-semibold'
              : 'border-transparent text-slate-400 hover:text-slate-200 hover:border-slate-700',
          ].join(' ')}
        >
          <UserCheck className="h-4 w-4" />
          <span>Teams</span>
          <span className="ml-1.5 rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-300">
            {teams.length}
          </span>
        </button>

        <button
          onClick={() => setActiveTab('roles')}
          className={[
            'flex items-center gap-2 px-5 py-3 text-sm font-medium border-b-2 transition-colors duration-150',
            activeTab === 'roles'
              ? 'border-gold-500 text-gold-400 font-semibold'
              : 'border-transparent text-slate-400 hover:text-slate-200 hover:border-slate-700',
          ].join(' ')}
        >
          <Shield className="h-4 w-4" />
          <span>Roles & Permissions</span>
          <span className="ml-1.5 rounded-full bg-slate-800 px-2 py-0.5 text-xs text-slate-300">
            {roles.length}
          </span>
        </button>
      </div>

      {/* ============================================================ */}
      {/* TAB 1: ADMINS MANAGEMENT                                      */}
      {/* ============================================================ */}
      {activeTab === 'admins' && (
        <div className="space-y-6">
          {/* Stat Cards */}
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard
              title="Total Admin Staff"
              value={admins.length}
              icon={Users}
              iconColor="text-gold-400"
              iconBg="bg-gold-500/10"
              subValue="Super Admin, Admins & Managers"
            />
            <StatCard
              title="Active Accounts"
              value={admins.filter((a) => a.status === 'active').length}
              icon={UserCheck}
              iconColor="text-emerald-400"
              iconBg="bg-emerald-500/10"
              subValue="Enabled credentials"
            />
            <StatCard
              title="Super Admin"
              value={1}
              icon={ShieldCheck}
              iconColor="text-amber-400"
              iconBg="bg-amber-500/10"
              subValue="Master System Admin"
            />
            <StatCard
              title="Assigned Teams"
              value={teams.length}
              icon={Shield}
              iconColor="text-sky-400"
              iconBg="bg-sky-500/10"
              subValue="Organizational groups"
            />
          </div>

          {/* Filters Bar */}
          <Card className="p-4">
            <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
              <div className="relative flex-1 max-w-md">
                <Input
                  placeholder="Search by admin name, email, or username..."
                  leftIcon={Search}
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                />
              </div>

              <div className="flex flex-wrap items-center gap-2.5">
                <Select
                  value={roleFilter}
                  onChange={(e) => setRoleFilter(e.target.value)}
                  className="w-40 text-xs"
                >
                  <option value="">All Roles</option>
                  {roles.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.name}
                    </option>
                  ))}
                </Select>

                <Select
                  value={teamFilter}
                  onChange={(e) => setTeamFilter(e.target.value)}
                  className="w-40 text-xs"
                >
                  <option value="">All Teams</option>
                  {teams.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name}
                    </option>
                  ))}
                </Select>

                <Select
                  value={statusFilter}
                  onChange={(e) => setStatusFilter(e.target.value)}
                  className="w-32 text-xs"
                >
                  <option value="">All Status</option>
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </Select>

                {(searchQuery || roleFilter || teamFilter || statusFilter) && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      setSearchQuery('');
                      setRoleFilter('');
                      setTeamFilter('');
                      setStatusFilter('');
                    }}
                  >
                    Clear Filters
                  </Button>
                )}
              </div>
            </div>
          </Card>

          {/* Admins Table */}
          <Card className="overflow-hidden p-0">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm text-slate-300">
                <thead className="bg-slate-900/80 text-xs uppercase text-slate-400 border-b border-slate-800">
                  <tr>
                    <th scope="col" className="px-5 py-3.5">Admin</th>
                    <th scope="col" className="px-4 py-3.5">Role</th>
                    <th scope="col" className="px-4 py-3.5">Team</th>
                    <th scope="col" className="px-4 py-3.5">Status</th>
                    <th scope="col" className="px-4 py-3.5">Access Summary</th>
                    <th scope="col" className="px-5 py-3.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 bg-slate-900/30">
                  {filteredAdmins.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="px-5 py-10 text-center text-slate-500">
                        No admin accounts found matching the current filters.
                      </td>
                    </tr>
                  ) : (
                    filteredAdmins.map((admin) => (
                      <tr
                        key={admin.id}
                        className="hover:bg-slate-800/40 transition-colors duration-150"
                      >
                        <td className="px-5 py-4">
                          <div className="flex items-center gap-3">
                            <Avatar name={admin.name} size="md" />
                            <div>
                              <div className="flex items-center gap-1.5">
                                <span className="font-semibold text-white">{admin.name}</span>
                                {admin.isSuperAdmin && (
                                  <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold bg-gold-500/20 text-gold-400 ring-1 ring-gold-500/40">
                                    SUPER ADMIN
                                  </span>
                                )}
                              </div>
                              <p className="text-xs text-slate-400">{admin.email}</p>
                            </div>
                          </div>
                        </td>

                        <td className="px-4 py-4">
                          <Badge
                            variant={
                              admin.isSuperAdmin
                                ? 'primary'
                                : admin.roleId === 'admin'
                                ? 'info'
                                : 'default'
                            }
                          >
                            {admin.roleName}
                          </Badge>
                        </td>

                        <td className="px-4 py-4">
                          <div className="flex flex-wrap items-center gap-1">
                            {admin.teamNames && admin.teamNames.length > 0 ? (
                              admin.teamNames.map((tn, i) => (
                                <span
                                  key={i}
                                  className="inline-block px-2 py-0.5 rounded text-xs bg-slate-800 text-slate-300 border border-slate-700/80"
                                >
                                  {tn}
                                </span>
                              ))
                            ) : (
                              <span className="text-xs text-slate-500 italic">Unassigned</span>
                            )}
                          </div>
                        </td>

                        <td className="px-4 py-4">
                          <StatusBadge status={admin.status} />
                        </td>

                        <td className="px-4 py-4 text-xs">
                          {admin.isSuperAdmin ? (
                            <span className="font-bold text-gold-400">Full System Access</span>
                          ) : (
                            <span className="text-slate-300 font-medium">
                              {admin.permissionsCount || 0} permissions
                            </span>
                          )}
                        </td>

                        <td className="px-5 py-4 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              onClick={() => handleOpenEditAdmin(admin)}
                              className="p-1.5 text-slate-400 hover:text-white hover:bg-slate-800 rounded-lg transition-colors"
                              title="Edit Admin Account"
                              aria-label={`Edit ${admin.name}`}
                            >
                              <Edit2 className="h-4 w-4" />
                            </button>

                            <button
                              onClick={() => handleToggleAdminStatusClick(admin)}
                              disabled={admin.isSuperAdmin}
                              className={[
                                'p-1.5 rounded-lg transition-colors',
                                admin.isSuperAdmin
                                  ? 'text-slate-600 cursor-not-allowed'
                                  : admin.status === 'active'
                                  ? 'text-amber-400 hover:bg-amber-500/10'
                                  : 'text-emerald-400 hover:bg-emerald-500/10',
                              ].join(' ')}
                              title={
                                admin.isSuperAdmin
                                  ? 'Super Admin cannot be disabled'
                                  : admin.status === 'active'
                                  ? 'Disable Account'
                                  : 'Enable Account'
                              }
                              aria-label={`Toggle status for ${admin.name}`}
                            >
                              {admin.status === 'active' ? (
                                <XCircle className="h-4 w-4" />
                              ) : (
                                <CheckCircle2 className="h-4 w-4" />
                              )}
                            </button>

                            <button
                              onClick={() => handleDeleteAdminClick(admin)}
                              disabled={admin.isSuperAdmin}
                              className={[
                                'p-1.5 rounded-lg transition-colors',
                                admin.isSuperAdmin
                                  ? 'text-slate-600 cursor-not-allowed'
                                  : 'text-red-400 hover:bg-red-500/10',
                              ].join(' ')}
                              title={
                                admin.isSuperAdmin
                                  ? 'Super Admin cannot be deleted'
                                  : 'Delete Account'
                              }
                              aria-label={`Delete ${admin.name}`}
                            >
                              <Trash2 className="h-4 w-4" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}

      {/* ============================================================ */}
      {/* TAB 2: TEAMS MANAGEMENT                                       */}
      {/* ============================================================ */}
      {activeTab === 'teams' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard
              title="Total Teams"
              value={teams.length}
              icon={UserCheck}
              iconColor="text-gold-400"
              iconBg="bg-gold-500/10"
              subValue="Organizational groups"
            />
            <StatCard
              title="Active Teams"
              value={teams.filter((t) => t.status === 'active').length}
              icon={CheckCircle2}
              iconColor="text-emerald-400"
              iconBg="bg-emerald-500/10"
              subValue="Currently active"
            />
            <StatCard
              title="Admins & Managers"
              value={admins.length}
              icon={Users}
              iconColor="text-sky-400"
              iconBg="bg-sky-500/10"
              subValue="Assigned personnel"
            />
            <StatCard
              title="Team Leads"
              value={teams.filter((t) => t.leadName).length}
              icon={Shield}
              iconColor="text-purple-400"
              iconBg="bg-purple-500/10"
              subValue="Designated heads"
            />
          </div>

          <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
            {teams.map((team) => {
              const teamAdmins = admins.filter((a) => a.teamIds?.includes(team.id));
              return (
                <Card key={team.id} className="p-5 flex flex-col justify-between hover:border-slate-700 transition-colors">
                  <div>
                    <div className="flex items-start justify-between">
                      <div>
                        <h3 className="text-base font-bold text-white">{team.name}</h3>
                        <p className="mt-1 text-xs text-slate-400 line-clamp-2">
                          {team.description || 'No description provided.'}
                        </p>
                      </div>
                      <StatusBadge status={team.status} />
                    </div>

                    <div className="mt-4 pt-4 border-t border-slate-800/80 space-y-2.5 text-xs">
                      <div className="flex items-center justify-between text-slate-300">
                        <span className="text-slate-400">Team Lead:</span>
                        <span className="font-semibold text-white">{team.leadName}</span>
                      </div>
                      <div className="flex items-center justify-between text-slate-300">
                        <span className="text-slate-400">Members ({teamAdmins.length}):</span>
                        <span className="inline-flex items-center gap-1 font-bold text-gold-400">
                          <Users className="h-3.5 w-3.5" />
                          {teamAdmins.length} assigned
                        </span>
                      </div>

                      {teamAdmins.length > 0 ? (
                        <div className="flex items-center gap-1.5 flex-wrap pt-1">
                          {teamAdmins.map((a) => (
                            <span
                              key={a.id}
                              className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-slate-800 text-[11px] text-slate-300 border border-slate-700"
                              title={`${a.name} (${a.roleName})`}
                            >
                              <Avatar name={a.name} size="xs" />
                              <span className="truncate max-w-[110px]">{a.name}</span>
                            </span>
                          ))}
                        </div>
                      ) : (
                        <p className="text-[11px] text-slate-500 italic pt-1">No admins assigned yet.</p>
                      )}

                      <div className="flex items-center justify-between text-slate-400 pt-1">
                        <span>Created:</span>
                        <span>{formatDate(team.createdAt)}</span>
                      </div>
                    </div>
                  </div>

                  <div className="mt-5 flex items-center justify-end gap-2 pt-3 border-t border-slate-800/60">
                    <Button
                      variant="primary"
                      size="sm"
                      leftIcon={UserPlus}
                      onClick={() => handleOpenAddAdmin(team.id, '')}
                    >
                      Add Admin
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      leftIcon={Edit2}
                      onClick={() => handleOpenEditTeam(team)}
                    >
                      Edit
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => {
                        setConfirmDialog({
                          isOpen: true,
                          title: team.status === 'active' ? 'Disable Team' : 'Enable Team',
                          message: `Are you sure you want to ${
                            team.status === 'active' ? 'disable' : 'enable'
                          } the ${team.name} team?`,
                          actionType: 'toggleTeam',
                          payload: team,
                        });
                      }}
                    >
                      {team.status === 'active' ? 'Disable' : 'Enable'}
                    </Button>
                  </div>
                </Card>
              );
            })}
          </div>
        </div>
      )}

      {/* ============================================================ */}
      {/* TAB 3: ROLES & PERMISSIONS MATRIX                            */}
      {/* ============================================================ */}
      {activeTab === 'roles' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
            {/* Roles Selection Sidebar */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                  Configurable Roles
                </h3>
                <button
                  onClick={handleOpenAddRole}
                  className="text-xs text-gold-400 hover:text-gold-300 font-semibold flex items-center gap-1"
                >
                  <Plus className="h-3.5 w-3.5" />
                  New Role
                </button>
              </div>

              <div className="space-y-2">
                {roles.map((role) => {
                  const isSelected = role.id === selectedRoleId;
                  return (
                    <button
                      key={role.id}
                      onClick={() => handleRoleSelect(role.id)}
                      className={[
                        'w-full text-left p-3.5 rounded-xl border transition-all duration-150',
                        isSelected
                          ? 'bg-slate-800 border-gold-500/50 ring-1 ring-gold-500/30 shadow-lg'
                          : 'bg-slate-900/60 border-slate-800 hover:bg-slate-800/50 hover:border-slate-700',
                      ].join(' ')}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-bold text-sm text-white">{role.name}</span>
                        {role.isSuperAdmin ? (
                          <span className="px-1.5 py-0.5 rounded text-[9px] font-bold bg-gold-500/20 text-gold-400 border border-gold-500/30">
                            SUPER ADMIN
                          </span>
                        ) : (
                          <span className="text-xs text-slate-500 font-medium">
                            {role.permissions.length} perms
                          </span>
                        )}
                      </div>
                      <p className="mt-1 text-xs text-slate-400 line-clamp-2">
                        {role.description}
                      </p>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Permission Matrix Panel */}
            <div className="lg:col-span-3 space-y-4">
              <Card className="p-5">
                {(() => {
                  const roleAdmins = admins.filter((a) => a.roleId === selectedRoleId);
                  return (
                    <div className="flex flex-col md:flex-row md:items-center md:justify-between border-b border-slate-800 pb-4 gap-3">
                      <div>
                        <div className="flex items-center gap-2">
                          <h2 className="text-lg font-bold text-white">
                            {selectedRoleObj?.name} Permission Matrix
                          </h2>
                          {selectedRoleObj?.isSuperAdmin && (
                            <Badge variant="primary">Full Access Unlocked</Badge>
                          )}
                        </div>
                        <p className="text-xs text-slate-400 mt-0.5">
                          {selectedRoleObj?.description}
                        </p>

                        <div className="mt-2.5 flex items-center gap-2 flex-wrap">
                          <span className="text-xs text-slate-400 font-medium">
                            Assigned Accounts ({roleAdmins.length}):
                          </span>
                          {roleAdmins.length > 0 ? (
                            roleAdmins.map((a) => (
                              <span
                                key={a.id}
                                className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-slate-800 text-[11px] text-slate-300 border border-slate-700"
                                title={a.email}
                              >
                                <Avatar name={a.name} size="xs" />
                                <span>{a.name}</span>
                              </span>
                            ))
                          ) : (
                            <span className="text-[11px] text-slate-500 italic">
                              No accounts assigned to this role yet
                            </span>
                          )}
                        </div>
                      </div>

                      <div className="flex flex-wrap items-center gap-2.5">
                        <Button
                          variant="outline"
                          size="sm"
                          leftIcon={UserPlus}
                          onClick={() => handleOpenAddAdmin('', selectedRoleId)}
                        >
                          Add Admin
                        </Button>

                        <Button
                          variant="primary"
                          size="sm"
                          isLoading={isSaving}
                          disabled={!matrixDirty || selectedRoleObj?.isSuperAdmin}
                          onClick={handleSaveMatrix}
                          leftIcon={Check}
                        >
                          Save Permission Matrix
                        </Button>
                      </div>
                    </div>
                  );
                })()}

                {/* Modules Permission List */}
                <div className="mt-6 space-y-6">
                  {modules.map((mod) => {
                    const modPermIds = mod.permissions.map((p) => p.id);
                    const grantedCount = modPermIds.filter((id) =>
                      matrixPermissions.includes(id)
                    ).length;

                    return (
                      <div
                        key={mod.id}
                        className="rounded-xl border border-slate-800 bg-slate-900/40 p-4 space-y-3"
                      >
                        <div className="flex items-center justify-between border-b border-slate-800/80 pb-2.5">
                          <div>
                            <span className="text-xs font-bold text-gold-400 uppercase tracking-wider">
                              {mod.label}
                            </span>
                            <p className="text-xs text-slate-400">{mod.description}</p>
                          </div>

                          <div className="flex items-center gap-2 text-xs">
                            <span className="text-slate-500 mr-2">
                              {grantedCount}/{modPermIds.length} granted
                            </span>
                            <button
                              type="button"
                              onClick={() => handleSelectModuleAll(mod.id)}
                              disabled={selectedRoleObj?.isSuperAdmin}
                              className="text-gold-400 hover:text-gold-300 font-medium disabled:opacity-50"
                            >
                              Select All
                            </button>
                            <span className="text-slate-700">|</span>
                            <button
                              type="button"
                              onClick={() => handleClearModuleAll(mod.id)}
                              disabled={selectedRoleObj?.isSuperAdmin}
                              className="text-slate-400 hover:text-slate-300 font-medium disabled:opacity-50"
                            >
                              Clear All
                            </button>
                          </div>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2.5 pt-1">
                          {mod.permissions.map((perm) => {
                            const isChecked = matrixPermissions.includes(perm.id);
                            return (
                              <label
                                key={perm.id}
                                className={[
                                  'flex items-center gap-2.5 p-2.5 rounded-lg border text-xs cursor-pointer select-none transition-colors duration-150',
                                  isChecked
                                    ? 'bg-gold-500/10 border-gold-500/40 text-gold-200'
                                    : 'bg-slate-800/40 border-slate-700/50 text-slate-400 hover:bg-slate-800 hover:text-slate-200',
                                  selectedRoleObj?.isSuperAdmin ? 'cursor-not-allowed opacity-80' : '',
                                ].join(' ')}
                              >
                                <input
                                  type="checkbox"
                                  checked={isChecked}
                                  disabled={selectedRoleObj?.isSuperAdmin}
                                  onChange={() => handleTogglePermission(perm.id)}
                                  className="h-4 w-4 rounded border-slate-700 bg-slate-900 text-gold-500 focus:ring-gold-500 focus:ring-offset-slate-900 cursor-pointer"
                                />
                                <span className="font-medium">{perm.label}</span>
                              </label>
                            );
                          })}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </Card>
            </div>
          </div>
        </div>
      )}

      {/* ============================================================ */}
      {/* MODAL: ADD / EDIT ADMIN FORM                                 */}
      {/* ============================================================ */}
      {adminModalOpen && (
        <AdminFormModal
          isOpen={adminModalOpen}
          onClose={() => setAdminModalOpen(false)}
          editingAdmin={editingAdmin}
          presetTeamId={presetTeamId}
          presetRoleId={presetRoleId}
          roles={roles}
          teams={teams}
          onSave={async (formData) => {
            try {
              if (editingAdmin) {
                const updated = await updateAdmin(editingAdmin.id, formData);
                setAdmins((prev) => prev.map((a) => (a.id === editingAdmin.id ? updated : a)));
                showToast(`Admin account updated for ${updated.name}`);
              } else {
                const created = await createAdmin(formData);
                setAdmins((prev) => [created, ...prev]);
                showToast(`New admin account created: ${created.name}`);
              }
              setAdminModalOpen(false);
            } catch (err) {
              showToast(err.message || 'Operation failed', 'error');
            }
          }}
        />
      )}

      {/* ============================================================ */}
      {/* MODAL: ADD / EDIT TEAM                                       */}
      {/* ============================================================ */}
      {teamModalOpen && (
        <TeamFormModal
          isOpen={teamModalOpen}
          onClose={() => setTeamModalOpen(false)}
          editingTeam={editingTeam}
          onSave={async (formData) => {
            try {
              if (editingTeam) {
                const updated = await updateTeam(editingTeam.id, formData);
                setTeams((prev) => prev.map((t) => (t.id === editingTeam.id ? updated : t)));
                showToast(`Team updated: ${updated.name}`);
              } else {
                const created = await createTeam(formData);
                setTeams((prev) => [...prev, created]);
                showToast(`New team created: ${created.name}`);
              }
              setTeamModalOpen(false);
            } catch (err) {
              showToast(err.message || 'Operation failed', 'error');
            }
          }}
        />
      )}

      {/* ============================================================ */}
      {/* MODAL: ADD / EDIT ROLE                                       */}
      {/* ============================================================ */}
      {roleModalOpen && (
        <RoleFormModal
          isOpen={roleModalOpen}
          onClose={() => setRoleModalOpen(false)}
          editingRole={editingRole}
          modules={modules}
          onSave={async (formData) => {
            try {
              if (editingRole) {
                const updated = await updateRole(editingRole.id, formData);
                setRoles((prev) => prev.map((r) => (r.id === editingRole.id ? updated : r)));
                showToast(`Role updated: ${updated.name}`);
              } else {
                const created = await createRole(formData);
                setRoles((prev) => [...prev, created]);
                setSelectedRoleId(created.id);
                setMatrixPermissions(created.permissions);
                showToast(`New role created: ${created.name}`);
              }
              setRoleModalOpen(false);
            } catch (err) {
              showToast(err.message || 'Operation failed', 'error');
            }
          }}
        />
      )}

      {/* ============================================================ */}
      {/* MODAL: CONFIRMATION DIALOG                                    */}
      {/* ============================================================ */}
      {confirmDialog.isOpen && (
        <Modal
          isOpen={confirmDialog.isOpen}
          onClose={() => setConfirmDialog((prev) => ({ ...prev, isOpen: false }))}
          title={confirmDialog.title}
          size="sm"
        >
          <div className="space-y-4">
            <p className="text-sm text-slate-300">{confirmDialog.message}</p>

            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-800">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setConfirmDialog((prev) => ({ ...prev, isOpen: false }))}
              >
                Cancel
              </Button>
              <Button
                variant={confirmDialog.actionType === 'deleteAdmin' ? 'danger' : 'primary'}
                size="sm"
                onClick={handleConfirmAction}
              >
                Confirm
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}

// ============================================================
// ADMIN FORM MODAL COMPONENT (STEP 1: ACCOUNT, STEP 2: ROLE, STEP 3: TEAMS)
// ============================================================
function AdminFormModal({
  isOpen,
  onClose,
  editingAdmin,
  presetTeamId,
  presetRoleId,
  roles,
  teams,
  onSave,
}) {
  const assignableRoles = roles.filter((r) => !r.isSuperAdmin || editingAdmin?.isSuperAdmin);

  const [formData, setFormData] = useState({
    name: editingAdmin?.name || '',
    email: editingAdmin?.email || '',
    username: editingAdmin?.username || '',
    roleId: editingAdmin?.roleId || presetRoleId || (assignableRoles[0]?.id || ''),
    teamIds: editingAdmin?.teamIds || (presetTeamId ? [presetTeamId] : []),
    status: editingAdmin?.status || 'active',
  });

  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const selectedRole = roles.find((r) => r.id === formData.roleId);

  const validate = () => {
    const errs = {};
    if (!formData.name.trim()) errs.name = 'Full name is required';
    if (!formData.email.trim()) errs.email = 'Email address is required';
    else if (!/\S+@\S+\.\S+/.test(formData.email)) errs.email = 'Invalid email address';
    if (!formData.roleId) errs.roleId = 'Role selection is required';
    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleToggleTeamSelection = (teamId) => {
    setFormData((prev) => {
      const exists = prev.teamIds.includes(teamId);
      const updated = exists
        ? prev.teamIds.filter((t) => t !== teamId)
        : [...prev.teamIds, teamId];
      return { ...prev, teamIds: updated };
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      await onSave(formData);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={editingAdmin ? 'Edit Admin Account' : 'Add Admin'}
      size="md"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Step 1: Account Details */}
        <Input
          label="Full Name"
          placeholder="e.g. John Smith"
          value={formData.name}
          onChange={(e) => setFormData((p) => ({ ...p, name: e.target.value }))}
          error={errors.name}
          required
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Input
            label="Email Address"
            type="email"
            placeholder="admin@zeparty.app"
            value={formData.email}
            onChange={(e) => setFormData((p) => ({ ...p, email: e.target.value }))}
            error={errors.email}
            required
          />

          <Input
            label="Username"
            placeholder="e.g. jsmith"
            value={formData.username}
            onChange={(e) => setFormData((p) => ({ ...p, username: e.target.value }))}
            hint="Leave blank to generate automatically"
          />
        </div>

        {/* Step 2: Role Assignment */}
        <Select
          label="Assign Role (Determines Permissions)"
          value={formData.roleId}
          onChange={(e) => setFormData((p) => ({ ...p, roleId: e.target.value }))}
          error={errors.roleId}
          required
        >
          {assignableRoles.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name}
            </option>
          ))}
        </Select>

        {selectedRole && (
          <div className="rounded-lg bg-slate-900/60 border border-slate-800 p-3 text-xs text-slate-400">
            <span className="font-semibold text-gold-400">{selectedRole.name}:</span>{' '}
            {selectedRole.description} ({selectedRole.permissions.length} module permissions)
          </div>
        )}

        {/* Step 3: Team Assignment */}
        <div className="space-y-1.5">
          <label className="text-xs font-medium text-slate-300">
            Assign Organizational Team(s)
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 pt-1">
            {teams.map((t) => {
              const isChecked = formData.teamIds.includes(t.id);
              return (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => handleToggleTeamSelection(t.id)}
                  className={[
                    'flex items-center gap-2 p-2 rounded-lg border text-xs text-left transition-colors',
                    isChecked
                      ? 'bg-gold-500/10 border-gold-500/40 text-gold-200 font-semibold'
                      : 'bg-slate-800/40 border-slate-700/60 text-slate-400 hover:bg-slate-800',
                  ].join(' ')}
                >
                  <div
                    className={[
                      'h-3.5 w-3.5 rounded flex items-center justify-center border',
                      isChecked
                        ? 'bg-gold-500 border-gold-500 text-slate-950'
                        : 'border-slate-600 bg-slate-900',
                    ].join(' ')}
                  >
                    {isChecked && <Check className="h-3 w-3 stroke-[3]" />}
                  </div>
                  <span className="truncate">{t.name}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Account Status */}
        <Select
          label="Account Status"
          value={formData.status}
          onChange={(e) => setFormData((p) => ({ ...p, status: e.target.value }))}
          disabled={editingAdmin?.isSuperAdmin}
        >
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </Select>

        <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
          <Button variant="ghost" size="sm" type="button" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" size="sm" type="submit" isLoading={isSubmitting}>
            {editingAdmin ? 'Save Changes' : 'Add Admin'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ============================================================
// TEAM FORM MODAL COMPONENT
// ============================================================
function TeamFormModal({ isOpen, onClose, editingTeam, onSave }) {
  const [formData, setFormData] = useState({
    name: editingTeam?.name || '',
    description: editingTeam?.description || '',
    leadName: editingTeam?.leadName || '',
    leadEmail: editingTeam?.leadEmail || '',
    status: editingTeam?.status || 'active',
  });
  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const validate = () => {
    const errs = {};
    if (!formData.name.trim()) errs.name = 'Team name is required';
    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      await onSave(formData);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={editingTeam ? 'Edit Administrative Team' : 'Create New Team'}
      size="md"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label="Team Name"
          placeholder="e.g. Moderation & Compliance"
          value={formData.name}
          onChange={(e) => setFormData((p) => ({ ...p, name: e.target.value }))}
          error={errors.name}
          required
        />

        <Textarea
          label="Description"
          placeholder="Describe the operational mandate of this team..."
          value={formData.description}
          onChange={(e) => setFormData((p) => ({ ...p, description: e.target.value }))}
        />

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <Input
            label="Team Lead Name"
            placeholder="e.g. Ahmed Khan"
            value={formData.leadName}
            onChange={(e) => setFormData((p) => ({ ...p, leadName: e.target.value }))}
          />

          <Input
            label="Team Lead Email"
            type="email"
            placeholder="lead@zeparty.app"
            value={formData.leadEmail}
            onChange={(e) => setFormData((p) => ({ ...p, leadEmail: e.target.value }))}
          />
        </div>

        <Select
          label="Status"
          value={formData.status}
          onChange={(e) => setFormData((p) => ({ ...p, status: e.target.value }))}
        >
          <option value="active">Active</option>
          <option value="inactive">Inactive</option>
        </Select>

        <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
          <Button variant="ghost" size="sm" type="button" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" size="sm" type="submit" isLoading={isSubmitting}>
            {editingTeam ? 'Save Team Changes' : 'Create Team'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

// ============================================================
// ROLE FORM MODAL COMPONENT
// ============================================================
function RoleFormModal({ isOpen, onClose, editingRole, modules, onSave }) {
  const [formData, setFormData] = useState({
    name: editingRole?.name || '',
    description: editingRole?.description || '',
    permissions: editingRole?.permissions || [],
  });
  const [errors, setErrors] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const validate = () => {
    const errs = {};
    if (!formData.name.trim()) errs.name = 'Role title is required';
    setErrors(errs);
    return Object.keys(errs).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setIsSubmitting(true);
    try {
      await onSave(formData);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={editingRole ? 'Edit Role Details' : 'Create New Role'}
      size="md"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label="Role Title"
          placeholder="e.g. Regional Support Manager"
          value={formData.name}
          onChange={(e) => setFormData((p) => ({ ...p, name: e.target.value }))}
          error={errors.name}
          required
        />

        <Textarea
          label="Description"
          placeholder="Outline the scope and responsibilities of this role..."
          value={formData.description}
          onChange={(e) => setFormData((p) => ({ ...p, description: e.target.value }))}
        />

        <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-800">
          <Button variant="ghost" size="sm" type="button" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" size="sm" type="submit" isLoading={isSubmitting}>
            {editingRole ? 'Save Role' : 'Create Role'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
