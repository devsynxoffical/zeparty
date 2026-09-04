import apiClient from '../api';

export async function fetchAdmins(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/admins', { params });
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API fetchAdmins failed, returning fallback state:', err.message);
  }
  return null;
}

export async function createAdminAccount(adminData) {
  const res = await apiClient.post('/v1/admin/admins', adminData);
  return res.data;
}

export async function updateAdminAccount(id, adminData) {
  const res = await apiClient.patch(`/v1/admin/admins/${id}`, adminData);
  return res.data;
}

export async function updateAdminStatus(id, status) {
  const res = await apiClient.patch(`/v1/admin/admins/${id}/status`, { status });
  return res.data;
}

export async function deleteAdminAccount(id) {
  const res = await apiClient.delete(`/v1/admin/admins/${id}`);
  return res.data;
}

export async function fetchRoles() {
  try {
    const res = await apiClient.get('/v1/admin/roles');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API fetchRoles failed, returning fallback state:', err.message);
  }
  return null;
}

export async function createRole(roleData) {
  const res = await apiClient.post('/v1/admin/roles', roleData);
  return res.data;
}

export async function updateRole(id, roleData) {
  const res = await apiClient.patch(`/v1/admin/roles/${id}`, roleData);
  return res.data;
}

export async function fetchPermissions() {
  try {
    const res = await apiClient.get('/v1/admin/permissions');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API fetchPermissions failed:', err.message);
  }
  return null;
}

export async function updateAdminPermissions(id, { grants = [], revocations = [] }) {
  const res = await apiClient.put(`/v1/admin/admins/${id}/permissions`, { grants, revocations });
  return res.data;
}

export async function fetchTeams() {
  try {
    const res = await apiClient.get('/v1/admin/teams');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    console.warn('API fetchTeams failed:', err.message);
  }
  return null;
}

export async function createTeam(teamData) {
  const res = await apiClient.post('/v1/admin/teams', teamData);
  return res.data;
}

export async function updateTeam(id, teamData) {
  const res = await apiClient.put(`/v1/admin/teams/${id}`, teamData);
  return res.data;
}

export async function deleteTeam(id) {
  const res = await apiClient.delete(`/v1/admin/teams/${id}`);
  return res.data;
}

export async function addTeamMember(teamId, { adminId, roleInTeam }) {
  const res = await apiClient.post(`/v1/admin/teams/${teamId}/members`, { adminId, roleInTeam });
  return res.data;
}

export async function removeTeamMember(teamId, adminId) {
  const res = await apiClient.delete(`/v1/admin/teams/${teamId}/members/${adminId}`);
  return res.data;
}

export default {
  fetchAdmins,
  createAdminAccount,
  updateAdminAccount,
  updateAdminStatus,
  deleteAdminAccount,
  fetchRoles,
  createRole,
  updateRole,
  fetchPermissions,
  updateAdminPermissions,
  fetchTeams,
  createTeam,
  updateTeam,
  deleteTeam,
  addTeamMember,
  removeTeamMember,
};
