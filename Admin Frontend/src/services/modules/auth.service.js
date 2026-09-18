// ============================================================
// ZeParty Admin Portal — Auth Service (JavaScript)
// ============================================================
import apiClient from '../api';

const SESSION_KEY = 'zeparty_admin_session';
const TOKEN_KEY = 'zeparty_admin_token';

export async function loginAdmin(credentials) {
  const username = (credentials.username || '').trim();
  const password = (credentials.password || '').trim();

  try {
    const response = await apiClient.post('/v1/auth/admin/login', {
      usernameOrEmail: username,
      password: password,
    });
    if (response.data && response.data.success) {
      const data = response.data.data;
      const session = {
        admin: data.admin,
        token: data.accessToken || data.token,
        refreshToken: data.refreshToken,
        expiresAt: data.expiresAt || new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      };
      saveSession(session);
      return session;
    }
    throw new Error('Unexpected response format from server.');
  } catch (err) {
    if (err.response) {
      const errorMsg =
        err.response.data?.message ||
        err.response.data?.error?.message ||
        'Invalid administrative credentials.';
      throw new Error(errorMsg);
    }
    throw new Error(err.message || 'Unable to connect to ZeParty Authentication API. Please verify network connectivity.');
  }
}

export async function logoutAdmin() {
  try {
    const rawSession = localStorage.getItem(SESSION_KEY);
    let refreshToken = null;
    if (rawSession) {
      try {
        const parsed = JSON.parse(rawSession);
        refreshToken = parsed?.refreshToken;
      } catch {}
    }
    await apiClient.post('/v1/auth/logout', { refreshToken });
  } catch {
    // ignore
  } finally {
    clearSession();
  }
}

export function saveSession(session) {
  if (!session) return;
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  if (session.token) {
    localStorage.setItem(TOKEN_KEY, session.token);
  }
}

export function isTokenValid(token) {
  if (!token || typeof token !== 'string') return false;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    if (payload.exp) {
      return payload.exp * 1000 > Date.now() + 5000;
    }
    return true;
  } catch {
    return false;
  }
}

export function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    if (!session || !session.token) {
      clearSession();
      return null;
    }
    // If the access token is invalid/expired AND there is no refresh token
    if (!isTokenValid(session.token) && !session.refreshToken) {
      clearSession();
      return null;
    }
    return session;
  } catch {
    clearSession();
    return null;
  }
}

export function clearSession() {
  localStorage.removeItem(SESSION_KEY);
  localStorage.removeItem(TOKEN_KEY);
}

export default {
  isTokenValid,
  loginAdmin,
  logoutAdmin,
  saveSession,
  loadSession,
  clearSession,
};

