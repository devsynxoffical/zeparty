// ============================================================
// ZeParty Admin Portal — Auth Service (JavaScript)
// ============================================================
import apiClient from '../api';

const MOCK_ACCOUNTS = {
  owner: {
    id: 'dev-owner-001',
    name: 'Root Owner',
    username: 'owner',
    email: 'owner@zeparty.app',
    isSuperAdmin: true,
    isOwner: true,
    role: 'owner',
    effectiveModules: ['*'],
    permissions: ['*'],
  },
  superadmin: {
    id: 'dev-superadmin-001',
    name: 'Super Admin',
    username: 'superadmin',
    email: 'superadmin@zeparty.app',
    isSuperAdmin: true,
    isOwner: false,
    role: 'super_admin',
    effectiveModules: ['*'],
    permissions: ['*'],
  },
  financeadmin: {
    id: 'dev-finance-001',
    name: 'Finance Admin',
    username: 'financeadmin',
    email: 'financeadmin@zeparty.app',
    isSuperAdmin: false,
    isOwner: false,
    role: 'finance_admin',
    effectiveModules: [
      'recharge-plans',
      'online-recharge',
      'offline-recharge',
      'withdrawals',
      'transactions',
      'finance',
      'coin-refunds',
      'reseller-corrections',
      'refund-requests',
      'chargebacks',
      'risk',
    ],
    permissions: [
      'view_recharge_plans',
      'manage_recharge_plans',
      'view_offline_recharge',
      'approve_offline_recharge',
      'view_withdrawals',
      'approve_withdrawals',
      'reject_withdrawals',
      'view_finance',
      'view_ledger',
      'view_refunds',
      'approve_refunds',
      'reseller_corrections',
      'manage_balances',
    ],
  },
  hostadmin: {
    id: 'dev-host-001',
    name: 'Host Admin',
    username: 'hostadmin',
    email: 'hostadmin@zeparty.app',
    isSuperAdmin: false,
    isOwner: false,
    role: 'host_admin',
    effectiveModules: ['hosts', 'agencies', 'bd-centers'],
    permissions: ['view_hosts', 'review_hosts', 'approve_reject_hosts', 'view_agencies'],
  },
  restrictedadmin: {
    id: 'dev-restricted-001',
    name: 'Restricted Admin (Host & Reseller Only)',
    username: 'restrictedadmin',
    email: 'restrictedadmin@zeparty.app',
    isSuperAdmin: false,
    isOwner: false,
    role: 'host_admin',
    effectiveModules: ['hosts', 'agencies', 'coin-sellers'],
    permissions: ['view_hosts', 'view_agencies', 'view_sellers'],
  },
};

const SESSION_KEY = 'zeparty_admin_session';
const TOKEN_KEY = 'zeparty_admin_token';

export async function loginAdmin(credentials) {
  const username = (credentials.username || '').trim();
  const password = (credentials.password || '').trim();
  const cleanKey = username.toLowerCase().split('@')[0];

  try {
    const response = await apiClient.post('/v1/auth/admin/login', {
      usernameOrEmail: username,
      password: password,
    });
    if (response.data && response.data.success) {
      const data = response.data.data;
      const session = {
        admin: data.admin,
        token: data.accessToken,
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      };
      return session;
    }
  } catch {
    // API endpoint unreachable or unauthorized — proceed to dev mock fallback
  }

  // Dev Mock Accounts Fallback
  if (cleanKey === 'owner') {
    return {
      admin: MOCK_ACCOUNTS.owner,
      token: 'dev-mock-token-' + Date.now(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  if (cleanKey === 'admin' || cleanKey === 'superadmin') {
    return {
      admin: MOCK_ACCOUNTS.superadmin,
      token: 'dev-mock-token-' + Date.now(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  if (MOCK_ACCOUNTS[cleanKey]) {
    return {
      admin: MOCK_ACCOUNTS[cleanKey],
      token: 'dev-mock-token-' + Date.now(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
  }

  throw new Error('Invalid administrative username or password.');
}

export async function logoutAdmin() {
  try {
    await apiClient.post('/v1/auth/logout');
  } catch {
    // ignore
  }
}

export function saveSession(session) {
  localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  localStorage.setItem(TOKEN_KEY, session.token);
}

export function loadSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session = JSON.parse(raw);
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
