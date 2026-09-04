// ============================================================
// ZeParty Admin Portal — Teams & Roles Service (JSX)
// ============================================================
// API-ready abstraction for Super Admin administrative access,
// staff accounts, team configurations, roles, and permission matrix.
// ============================================================

import apiClient from '../api';
import {
  MOCK_ADMINS,
  MOCK_ROLES,
  MOCK_TEAMS,
  MODULE_PERMISSIONS,
  ALL_PERMISSION_IDS,
} from '../../mocks/teamsRoles.mock';

let adminsState = [...MOCK_ADMINS];
let teamsState = [...MOCK_TEAMS];
let rolesState = [...MOCK_ROLES];

// ---- ADMIN MANAGEMENT SERVICE METHODS ----

export async function getAdmins(filters = {}) {
  try {
    const res = await apiClient.get('/v1/admin/admins', { params: filters });
    if (res.data && res.data.success && Array.isArray(res.data.data)) {
      return res.data.data.map((a) => ({
        id: a.id,
        name: a.name,
        email: a.email,
        username: a.username,
        roleId: a.roleId || 'custom_admin',
        roleName: a.role ? a.role.name : a.isSuperAdmin ? 'Super Admin' : 'Admin',
        teamIds: a.teamMemberships ? a.teamMemberships.map((t) => t.teamId) : [],
        teamNames: a.teamMemberships && a.teamMemberships.length > 0 ? a.teamMemberships.map((t) => t.team?.name || 'Team') : ['Unassigned'],
        status: a.status ? a.status.toLowerCase() : 'active',
        isSuperAdmin: Boolean(a.isSuperAdmin),
        isOwner: Boolean(a.isOwner),
        permissionsCount: a.role && a.role.permissions ? a.role.permissions.length : 0,
        createdAt: a.createdAt,
      }));
    }
  } catch (err) {
    console.warn('API getAdmins failed, using local state:', err.message);
  }

  let result = [...adminsState];
  if (filters.search) {
    const q = filters.search.toLowerCase();
    result = result.filter(
      (a) =>
        a.name.toLowerCase().includes(q) ||
        a.email.toLowerCase().includes(q) ||
        a.username.toLowerCase().includes(q)
    );
  }
  if (filters.roleId) {
    result = result.filter((a) => a.roleId === filters.roleId);
  }
  if (filters.status) {
    result = result.filter((a) => a.status === filters.status);
  }

  return result.filter((a) => !a.isOwner);
}

export async function getAdminById(id) {
  try {
    const res = await apiClient.get(`/v1/admin/admins/${id}`);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API getAdminById failed, using local lookup:', err.message);
  }

  const found = adminsState.find((a) => a.id === id);
  if (!found) throw new Error('Admin account not found');
  return { ...found };
}

export async function createAdmin(adminData) {
  try {
    const res = await apiClient.post('/v1/admin/admins', adminData);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
    console.warn('API createAdmin failed, using mock fallback:', err.message);
  }

  const role = rolesState.find((r) => r.id === adminData.roleId);
  const selectedTeamIds = Array.isArray(adminData.teamIds)
    ? adminData.teamIds
    : adminData.teamId
    ? [adminData.teamId]
    : [];

  const assignedTeams = teamsState.filter((t) => selectedTeamIds.includes(t.id));
  const teamNames = assignedTeams.map((t) => t.name);

  const newAdmin = {
    id: `admin-${Date.now()}`,
    name: adminData.name,
    email: adminData.email,
    username: adminData.username || adminData.email.split('@')[0],
    roleId: adminData.roleId,
    roleName: role ? role.name : 'Custom Role',
    teamIds: selectedTeamIds,
    teamNames: teamNames.length > 0 ? teamNames : ['Unassigned'],
    status: adminData.status || 'active',
    isSuperAdmin: role ? role.isSuperAdmin : false,
    permissionsCount: role ? role.permissions.length : 0,
    createdAt: new Date().toISOString(),
  };

  adminsState = [newAdmin, ...adminsState];
  return newAdmin;
}

export async function updateAdmin(id, updates) {
  try {
    const res = await apiClient.patch(`/v1/admin/admins/${id}`, updates);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
    console.warn('API updateAdmin failed, using mock fallback:', err.message);
  }

  const target = adminsState.find((a) => a.id === id);
  if (!target) throw new Error('Admin not found');

  const updated = {
    ...target,
    ...updates,
  };
  adminsState = adminsState.map((a) => (a.id === id ? updated : a));
  return updated;
}

export async function toggleAdminStatus(id) {
  try {
    const target = adminsState.find((a) => a.id === id);
    const newStatus = target && target.status === 'active' ? 'INACTIVE' : 'ACTIVE';
    const res = await apiClient.patch(`/v1/admin/admins/${id}/status`, { status: newStatus });
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
  }

  const target = adminsState.find((a) => a.id === id);
  if (!target) throw new Error('Admin not found');

  const newStatus = target.status === 'active' ? 'inactive' : 'active';
  const updated = { ...target, status: newStatus };
  adminsState = adminsState.map((a) => (a.id === id ? updated : a));
  return updated;
}

export async function deleteAdmin(id) {
  try {
    const res = await apiClient.delete(`/v1/admin/admins/${id}`);
    if (res.data && res.data.success) {
      return res.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
  }

  const target = adminsState.find((a) => a.id === id);
  if (!target) throw new Error('Admin not found');

  adminsState = adminsState.filter((a) => a.id !== id);
  return { success: true, id };
}

// ---- TEAMS SERVICE METHODS ----

export async function getTeams() {
  try {
    const res = await apiClient.get('/v1/admin/teams');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API getTeams failed, using local state:', err.message);
  }
  return [...teamsState];
}

export async function createTeam(teamData) {
  try {
    const res = await apiClient.post('/v1/admin/teams', teamData);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
  }
  const newTeam = {
    id: `team_${Date.now()}`,
    name: teamData.name,
    description: teamData.description || '',
    createdAt: new Date().toISOString(),
  };

  teamsState = [...teamsState, newTeam];
  return newTeam;
}

export async function updateTeam(id, updates) {
  try {
    const res = await apiClient.put(`/v1/admin/teams/${id}`, updates);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
  }

  const target = teamsState.find((t) => t.id === id);
  if (!target) throw new Error('Team not found');

  const updated = { ...target, ...updates };
  teamsState = teamsState.map((t) => (t.id === id ? updated : t));
  return updated;
}

export async function toggleTeamStatus(id) {
  return updateTeam(id, {});
}

// ---- ROLES & PERMISSIONS SERVICE METHODS ----

export async function getRoles() {
  try {
    const res = await apiClient.get('/v1/admin/roles');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API getRoles failed, using local state:', err.message);
  }
  return [...rolesState];
}

export async function getModulePermissions() {
  try {
    const res = await apiClient.get('/v1/admin/permissions');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API getModulePermissions failed, using default list:', err.message);
  }
  return [...MODULE_PERMISSIONS];
}

export async function createRole(roleData) {
  try {
    const res = await apiClient.post('/v1/admin/roles', roleData);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
  }

  const newRole = {
    id: `role_${Date.now()}`,
    name: roleData.name,
    description: roleData.description || '',
    isSuperAdmin: false,
    permissions: roleData.permissions || [],
    createdAt: new Date().toISOString(),
  };

  rolesState = [...rolesState, newRole];
  return newRole;
}

export async function updateRole(id, updates) {
  try {
    const res = await apiClient.patch(`/v1/admin/roles/${id}`, updates);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
  }

  const target = rolesState.find((r) => r.id === id);
  if (!target) throw new Error('Role not found');

  const updated = { ...target, ...updates };
  rolesState = rolesState.map((r) => (r.id === id ? updated : r));
  return updated;
}
