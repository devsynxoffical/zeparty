// ============================================================
// ZeParty Admin Portal — Teams & Roles Service (JavaScript)
// Server-authoritative PostgreSQL RBAC & Governance Integration
// ============================================================

import apiClient from '../api';
import { MODULE_PERMISSIONS, DEFAULT_ROLES } from '../../constants/permissions';

function formatAdminRecord(a) {
  if (!a) return null;
  return {
    id: a.id,
    name: a.name,
    email: a.email,
    username: a.username,
    roleId: a.roleId || 'custom_admin',
    roleName: a.role ? a.role.name : a.isSuperAdmin ? 'Super Admin' : 'Admin',
    teamIds: a.teamMemberships ? a.teamMemberships.map((t) => t.teamId) : [],
    teamNames:
      a.teamMemberships && a.teamMemberships.length > 0
        ? a.teamMemberships.map((t) => t.team?.name || 'Team')
        : ['Unassigned'],
    status: a.status ? a.status.toLowerCase() : 'active',
    isSuperAdmin: Boolean(a.isSuperAdmin),
    isOwner: Boolean(a.isOwner),
    permissionsCount: a.role && a.role.permissions ? a.role.permissions.length : 0,
    createdAt: a.createdAt || new Date().toISOString(),
  };
}

// ---- ADMIN MANAGEMENT SERVICE METHODS ----

export async function getAdmins(filters = {}) {
  const res = await apiClient.get('/v1/admin/admins', { params: filters });
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data.map(formatAdminRecord).filter((a) => !a.isOwner);
  }
  return [];
}

export async function getAdminById(id) {
  const res = await apiClient.get(`/v1/admin/admins/${id}`);
  if (res.data && res.data.success && res.data.data) {
    return formatAdminRecord(res.data.data);
  }
  throw new Error('Admin account not found');
}

export async function createAdmin(adminData) {
  const payload = {
    name: adminData.name,
    email: adminData.email,
    username: adminData.username || adminData.email.split('@')[0],
    password: adminData.password || 'ZePartyAdmin123!',
    roleId: adminData.roleId,
    status: adminData.status ? adminData.status.toUpperCase() : 'ACTIVE',
    isSuperAdmin: Boolean(adminData.isSuperAdmin),
  };

  const res = await apiClient.post('/v1/admin/admins', payload);
  if (res.data && res.data.success) {
    return formatAdminRecord(res.data.data);
  }
  throw new Error('Failed to create admin on backend.');
}

export async function updateAdmin(id, updates) {
  const payload = {
    ...(updates.name !== undefined && { name: updates.name }),
    ...(updates.email !== undefined && { email: updates.email }),
    ...(updates.username !== undefined && { username: updates.username }),
    ...(updates.roleId !== undefined && { roleId: updates.roleId }),
    ...(updates.status !== undefined && { status: updates.status.toUpperCase() }),
  };

  const res = await apiClient.patch(`/v1/admin/admins/${id}`, payload);
  if (res.data && res.data.success) {
    return formatAdminRecord(res.data.data);
  }
  throw new Error('Failed to update admin on backend.');
}

export async function toggleAdminStatus(id) {
  const current = await getAdminById(id);
  const newStatus = current.status === 'active' ? 'INACTIVE' : 'ACTIVE';
  const res = await apiClient.patch(`/v1/admin/admins/${id}/status`, { status: newStatus });
  if (res.data && res.data.success) {
    return formatAdminRecord(res.data.data);
  }
  throw new Error('Failed to toggle admin status on backend.');
}

export async function deleteAdmin(id) {
  const res = await apiClient.delete(`/v1/admin/admins/${id}`);
  return res.data;
}

// ---- TEAMS SERVICE METHODS ----

export async function getTeams() {
  const res = await apiClient.get('/v1/admin/teams');
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data;
  }
  return [];
}

export async function createTeam(teamData) {
  const res = await apiClient.post('/v1/admin/teams', teamData);
  if (res.data && res.data.success) {
    return res.data.data;
  }
  throw new Error('Failed to create team on backend.');
}

export async function updateTeam(id, updates) {
  const res = await apiClient.put(`/v1/admin/teams/${id}`, updates);
  if (res.data && res.data.success) {
    return res.data.data;
  }
  throw new Error('Failed to update team on backend.');
}

export async function deleteTeam(id) {
  const res = await apiClient.delete(`/v1/admin/teams/${id}`);
  return res.data;
}

export async function toggleTeamStatus(id) {
  return updateTeam(id, {});
}

// ---- ROLES & PERMISSIONS SERVICE METHODS ----

export async function getRoles() {
  const res = await apiClient.get('/v1/admin/roles');
  if (res.data && res.data.success && Array.isArray(res.data.data)) {
    return res.data.data;
  }
  return DEFAULT_ROLES;
}

export async function getModulePermissions() {
  try {
    const res = await apiClient.get('/v1/admin/permissions');
    if (res.data && res.data.success && Array.isArray(res.data.data)) {
      const rawPerms = res.data.data;
      if (rawPerms.length > 0 && rawPerms[0].module && !rawPerms[0].permissions) {
        const moduleMap = {};
        for (const mod of MODULE_PERMISSIONS) {
          moduleMap[mod.id || mod.module] = { ...mod, permissions: [] };
        }
        for (const p of rawPerms) {
          const modKey = p.module || 'system';
          if (!moduleMap[modKey]) {
            moduleMap[modKey] = {
              id: modKey,
              label: modKey.toUpperCase(),
              description: `${modKey} permissions`,
              permissions: [],
            };
          }
          moduleMap[modKey].permissions.push({
            id: p.id,
            label: p.label || p.id,
            description: p.description || '',
          });
        }
        return Object.values(moduleMap).filter((m) => m.permissions && m.permissions.length > 0);
      }
      return res.data.data;
    }
  } catch (err) {
    console.warn('API getModulePermissions failed, using canonical list:', err.message);
  }
  return MODULE_PERMISSIONS;
}

export async function createRole(roleData) {
  const res = await apiClient.post('/v1/admin/roles', roleData);
  if (res.data && res.data.success) {
    return res.data.data;
  }
  throw new Error('Failed to create role on backend.');
}

export async function updateRole(id, updates) {
  const res = await apiClient.patch(`/v1/admin/roles/${id}`, updates);
  if (res.data && res.data.success) {
    return res.data.data;
  }
  throw new Error('Failed to update role on backend.');
}

export default {
  getAdmins,
  getAdminById,
  createAdmin,
  updateAdmin,
  toggleAdminStatus,
  deleteAdmin,
  getTeams,
  createTeam,
  updateTeam,
  deleteTeam,
  toggleTeamStatus,
  getRoles,
  getModulePermissions,
  createRole,
  updateRole,
};
