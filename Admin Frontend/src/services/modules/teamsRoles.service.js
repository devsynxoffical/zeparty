// ============================================================
// ZeParty Admin Portal — Teams & Roles Service (JSX)
// ============================================================
// API-ready abstraction for Super Admin administrative access,
// staff accounts, team configurations, roles, and permission matrix.
// ============================================================

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
  await new Promise((res) => setTimeout(res, 200));
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
  if (filters.teamId) {
    result = result.filter((a) => a.teamIds?.includes(filters.teamId));
  }
  if (filters.status) {
    result = result.filter((a) => a.status === filters.status);
  }

  return result;
}

export async function getAdminById(id) {
  await new Promise((res) => setTimeout(res, 150));
  const found = adminsState.find((a) => a.id === id);
  if (!found) throw new Error('Admin account not found');
  return { ...found };
}

export async function createAdmin(adminData) {
  await new Promise((res) => setTimeout(res, 300));

  const role = rolesState.find((r) => r.id === adminData.roleId);
  const selectedTeamIds = Array.isArray(adminData.teamIds)
    ? adminData.teamIds
    : adminData.teamId
    ? [adminData.teamId]
    : [];

  const assignedTeams = teamsState.filter((t) => selectedTeamIds.includes(t.id));
  const teamNames = assignedTeams.map((t) => t.name);

  // Prevent creating secondary Super Admin
  if (role?.isSuperAdmin) {
    const existingSuperAdmin = adminsState.find((a) => a.isSuperAdmin);
    if (existingSuperAdmin) {
      throw new Error('Action Restricted: Master Super Admin already exists.');
    }
  }

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
    lastLogin: null,
    createdAt: new Date().toISOString(),
  };

  adminsState = [newAdmin, ...adminsState];

  // Update member counts
  if (role) {
    rolesState = rolesState.map((r) =>
      r.id === role.id ? { ...r, memberCount: r.memberCount + 1 } : r
    );
  }

  return newAdmin;
}

export async function updateAdmin(id, updates) {
  await new Promise((res) => setTimeout(res, 300));
  const target = adminsState.find((a) => a.id === id);
  if (!target) throw new Error('Admin not found');

  if (target.isSuperAdmin && updates.status === 'inactive') {
    throw new Error('Super Admin account cannot be disabled.');
  }

  const role = updates.roleId ? rolesState.find((r) => r.id === updates.roleId) : null;
  const selectedTeamIds = updates.teamIds
    ? updates.teamIds
    : updates.teamId
    ? [updates.teamId]
    : target.teamIds;

  const assignedTeams = teamsState.filter((t) => selectedTeamIds.includes(t.id));
  const teamNames = assignedTeams.map((t) => t.name);

  const updated = {
    ...target,
    ...updates,
    roleName: role ? role.name : target.roleName,
    teamIds: selectedTeamIds,
    teamNames: teamNames.length > 0 ? teamNames : ['Unassigned'],
    permissionsCount: role ? role.permissions.length : target.permissionsCount,
    isSuperAdmin: target.isSuperAdmin, // Preserve Super Admin identity
  };

  adminsState = adminsState.map((a) => (a.id === id ? updated : a));
  return updated;
}

export async function toggleAdminStatus(id) {
  await new Promise((res) => setTimeout(res, 200));
  const target = adminsState.find((a) => a.id === id);
  if (!target) throw new Error('Admin not found');
  if (target.isSuperAdmin) {
    throw new Error('Action Prohibited: Super Admin account cannot be disabled.');
  }

  const newStatus = target.status === 'active' ? 'inactive' : 'active';
  const updated = { ...target, status: newStatus };
  adminsState = adminsState.map((a) => (a.id === id ? updated : a));
  return updated;
}

export async function deleteAdmin(id) {
  await new Promise((res) => setTimeout(res, 250));
  const target = adminsState.find((a) => a.id === id);
  if (!target) throw new Error('Admin not found');
  if (target.isSuperAdmin) {
    throw new Error('Action Prohibited: Super Admin account cannot be deleted.');
  }

  adminsState = adminsState.filter((a) => a.id !== id);
  return { success: true, id };
}

// ---- TEAMS SERVICE METHODS ----

export async function getTeams() {
  await new Promise((res) => setTimeout(res, 150));
  return [...teamsState];
}

export async function createTeam(teamData) {
  await new Promise((res) => setTimeout(res, 300));
  const newTeam = {
    id: `team_${Date.now()}`,
    name: teamData.name,
    description: teamData.description || '',
    leadName: teamData.leadName || 'Unassigned',
    leadEmail: teamData.leadEmail || '',
    status: teamData.status || 'active',
    createdAt: new Date().toISOString(),
  };

  teamsState = [...teamsState, newTeam];
  return newTeam;
}

export async function updateTeam(id, updates) {
  await new Promise((res) => setTimeout(res, 250));
  const target = teamsState.find((t) => t.id === id);
  if (!target) throw new Error('Team not found');

  const updated = { ...target, ...updates };
  teamsState = teamsState.map((t) => (t.id === id ? updated : t));

  // Sync team name in admins list if updated
  if (updates.name) {
    adminsState = adminsState.map((a) => {
      if (a.teamIds?.includes(id)) {
        const teamNames = teamsState
          .filter((t) => a.teamIds.includes(t.id))
          .map((t) => (t.id === id ? updates.name : t.name));
        return { ...a, teamNames };
      }
      return a;
    });
  }

  return updated;
}

export async function toggleTeamStatus(id) {
  await new Promise((res) => setTimeout(res, 200));
  const target = teamsState.find((t) => t.id === id);
  if (!target) throw new Error('Team not found');

  const newStatus = target.status === 'active' ? 'inactive' : 'active';
  const updated = { ...target, status: newStatus };
  teamsState = teamsState.map((t) => (t.id === id ? updated : t));
  return updated;
}

// ---- ROLES & PERMISSIONS SERVICE METHODS ----

export async function getRoles() {
  await new Promise((res) => setTimeout(res, 150));
  return [...rolesState];
}

export async function getModulePermissions() {
  await new Promise((res) => setTimeout(res, 100));
  return [...MODULE_PERMISSIONS];
}

export async function createRole(roleData) {
  await new Promise((res) => setTimeout(res, 300));
  const newRole = {
    id: `role_${Date.now()}`,
    name: roleData.name,
    description: roleData.description || '',
    isSuperAdmin: false,
    isSystemRole: false,
    memberCount: 0,
    permissions: roleData.permissions || [],
    createdAt: new Date().toISOString(),
  };

  rolesState = [...rolesState, newRole];
  return newRole;
}

export async function updateRole(id, updates) {
  await new Promise((res) => setTimeout(res, 300));
  const target = rolesState.find((r) => r.id === id);
  if (!target) throw new Error('Role not found');

  if (target.isSuperAdmin) {
    // Keep Super Admin with all permissions
    updates.permissions = ALL_PERMISSION_IDS;
  }

  const updated = { ...target, ...updates };
  rolesState = rolesState.map((r) => (r.id === id ? updated : r));

  // Sync role name and permissions count in admins list if updated
  adminsState = adminsState.map((a) => {
    if (a.roleId === id) {
      return {
        ...a,
        roleName: updates.name || a.roleName,
        permissionsCount: updates.permissions ? updates.permissions.length : a.permissionsCount,
      };
    }
    return a;
  });

  return updated;
}
