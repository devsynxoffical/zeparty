// ============================================================
// ZeParty Admin Portal — Permission Context & RBAC Evaluator (JSX)
// ============================================================

import React, { createContext, useContext, useMemo } from 'react';
import { useAuth } from '../hooks/useAuth';
import { MOCK_ROLES, ALL_PERMISSION_IDS } from '../mocks/teamsRoles.mock';

export const PermissionContext = createContext(null);

// Route path to required module permission mapping
const ROUTE_PERMISSIONS = {
  '/admin': null,
  '/admin/approvals': null,
  '/admin/users': 'view_users',
  '/admin/live-rooms': 'view_live_rooms',
  '/admin/recharge-plans': 'view_recharge_plans',
  '/admin/recharge-online': 'view_recharge_plans',
  '/admin/offline-recharge': 'view_offline_recharge',
  '/admin/withdrawals': 'view_withdrawals',
  '/admin/gifts': 'view_gifts',
  '/admin/vip-store': 'view_vip_store',
  '/admin/items': 'view_store',
  '/admin/economy': 'economy_settings',
  '/admin/leaderboards': 'view_users',
  '/admin/rankings': 'view_users',
  '/admin/hosts': 'view_hosts',
  '/admin/agencies': 'view_agencies',
  '/admin/coin-sellers': 'view_sellers',
  '/admin/merchants': 'view_merchants',
  '/admin/transactions': 'view_ledger',
  '/admin/coin-refunds': 'view_refunds',
  '/admin/reseller-corrections': 'reseller_corrections',
  '/admin/refund-requests': 'view_refunds',
  '/admin/chargebacks': 'view_chargebacks',
  '/admin/risk': 'view_fraud_risk',
  '/admin/restrictions': 'manage_restrictions',
  '/admin/referrals': 'view_users',
  '/admin/games': 'view_games',
  '/admin/chat': 'view_chat',
  '/admin/announcements': 'view_announcements',
  '/admin/notifications': 'view_notifications',
  '/admin/teams-roles': 'view_admins',
  '/admin/profile': null,
  '/admin/settings': 'view_settings',
  '/admin/localization': 'view_settings',
  '/admin/payment-providers': 'view_settings',
  '/admin/api-logs': 'view_system_health',
  '/admin/system-health': 'view_system_health',
  '/admin/app-config': 'view_settings',
  '/admin/backups': 'view_settings',
  '/admin/privacy': 'view_settings',
  '/admin/policy-versioning': 'view_settings',
  '/admin/jobs': 'view_settings',
};

export function PermissionProvider({ children }) {
  const { admin } = useAuth();

  const isSuperAdmin = useMemo(() => {
    if (!admin) return false;
    return Boolean(
      admin.isSuperAdmin || admin.role === 'super_admin' || admin.roleId === 'super_admin'
    );
  }, [admin]);

  const userPermissions = useMemo(() => {
    if (!admin) return [];
    if (isSuperAdmin) return ALL_PERMISSION_IDS;

    if (Array.isArray(admin.permissions)) {
      return admin.permissions;
    }

    const roleObj = MOCK_ROLES.find(
      (r) => r.id === admin.role || r.id === admin.roleId
    );

    return roleObj ? roleObj.permissions : [];
  }, [admin, isSuperAdmin]);

  const hasPermission = (permissionId) => {
    if (!admin) return false;
    if (isSuperAdmin) return true;
    if (!permissionId) return true;
    return userPermissions.includes(permissionId);
  };

  const hasModuleAccess = (moduleId) => {
    if (!admin) return false;
    if (isSuperAdmin) return true;
    return true; // Expandable per specific role checks
  };

  const canAccessRoute = (pathname) => {
    if (!admin) return false;
    if (isSuperAdmin) return true;

    if (ROUTE_PERMISSIONS.hasOwnProperty(pathname)) {
      const required = ROUTE_PERMISSIONS[pathname];
      return required ? userPermissions.includes(required) : true;
    }

    for (const [routeKey, requiredPerm] of Object.entries(ROUTE_PERMISSIONS)) {
      if (routeKey !== '/admin' && pathname.startsWith(routeKey)) {
        return requiredPerm ? userPermissions.includes(requiredPerm) : true;
      }
    }

    return true;
  };

  const value = useMemo(
    () => ({
      isSuperAdmin,
      userPermissions,
      hasPermission,
      hasModuleAccess,
      canAccessRoute,
      canPerformAction: hasPermission,
    }),
    [isSuperAdmin, userPermissions, admin]
  );

  return (
    <PermissionContext.Provider value={value}>
      {children}
    </PermissionContext.Provider>
  );
}

export function usePermission() {
  const context = useContext(PermissionContext);
  if (!context) {
    throw new Error('usePermission must be used within a PermissionProvider');
  }
  return context;
}
