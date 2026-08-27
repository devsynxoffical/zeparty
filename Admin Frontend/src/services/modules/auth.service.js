// ============================================================
// ZeParty Admin Portal — Auth Service (JavaScript)
// ============================================================
// This module abstracts all authentication API calls.
// DEVELOPMENT: Uses a mock authentication mechanism until the
// real backend Auth API is available.
// ============================================================

// ---- Mock credentials (DEV ONLY — isolated here) ----
const DEV_MOCK_CREDENTIAL = {
  username: 'admin',
  password: 'admin123',
};

const DEV_MOCK_ADMIN = {
  id: 'dev-admin-001',
  username: 'admin',
  email: 'admin@zeparty.app',
  displayName: 'Super Admin',
  role: 'super_admin',
  createdAt: new Date().toISOString(),
};

const SESSION_KEY = 'zeparty_admin_session';
const TOKEN_KEY = 'zeparty_admin_token';

// ---- Login ----
// When the real backend is available, replace this function body
// with an actual API call: apiClient.post('/auth/admin/login', credentials)
export async function loginAdmin(credentials) {
  // Simulate network delay
  await new Promise((resolve) => setTimeout(resolve, 800));

  if (
    credentials.username === DEV_MOCK_CREDENTIAL.username &&
    credentials.password === DEV_MOCK_CREDENTIAL.password
  ) {
    const session = {
      admin: DEV_MOCK_ADMIN,
      token: 'dev-mock-token-' + Date.now(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
    return session;
  }

  throw new Error('Invalid username or password.');
}

// ---- Logout ----
export async function logoutAdmin() {
  // When backend exists: apiClient.post('/auth/admin/logout')
  await new Promise((resolve) => setTimeout(resolve, 300));
}

// ---- Session persistence ----
export function saveSession(session) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  localStorage.setItem(TOKEN_KEY, session.token);
}

export function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
    // Check expiry
    if (new Date(session.expiresAt) < new Date()) {
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
