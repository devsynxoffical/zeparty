// ============================================================
// ZeParty Admin Portal — ModuleRouteGuard Component (JSX)
// ============================================================

import React from 'react';
import { useLocation } from 'react-router-dom';
import { usePermission } from '../hooks/usePermission';
import { AccessDenied } from '../components/common/AccessDenied';

export function ModuleRouteGuard({ children, requiredPermission, requiredModule }) {
  const { canAccessRoute, hasPermission, hasModuleAccess, isSuperAdmin } = usePermission();
  const location = useLocation();

  if (isSuperAdmin) {
    return <>{children}</>;
  }

  let isAllowed = true;

  if (requiredPermission) {
    isAllowed = hasPermission(requiredPermission);
  } else if (requiredModule) {
    isAllowed = hasModuleAccess(requiredModule);
  } else {
    isAllowed = canAccessRoute(location.pathname);
  }

  if (!isAllowed) {
    return <AccessDenied />;
  }

  return <>{children}</>;
}
