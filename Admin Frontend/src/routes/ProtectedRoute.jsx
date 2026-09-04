// ============================================================
// ZeParty Admin Portal — ProtectedRoute (JSX)
// ============================================================

import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';
import { usePermission } from '../context/PermissionContext';
import { LoadingState } from '../components/common/States';
import { ShieldAlert } from 'lucide-react';
import { Button } from '../components/ui/Button';

export function ProtectedRoute({ children }) {
  const { isAuthenticated, isLoading } = useAuth();
  const location = useLocation();

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-slate-950">
        <LoadingState message="Verifying session..." />
      </div>
    );
  }

  if (!isAuthenticated) {
    return (
      <Navigate
        to="/"
        replace
      />
    );
  }

  return <>{children}</>;
}

export function ModuleRouteGuard({ children, permission, requiredModule }) {
  const { canAccessRoute, hasPermission, hasModuleAccess } = usePermission();
  const location = useLocation();

  let isAuthorized = canAccessRoute(location.pathname);
  if (permission) {
    isAuthorized = isAuthorized && hasPermission(permission);
  }
  if (requiredModule) {
    isAuthorized = isAuthorized && hasModuleAccess(requiredModule);
  }

  if (!isAuthorized) {
    return (
      <div className="flex h-[75vh] flex-col items-center justify-center text-center px-4">
        <div className="p-4 rounded-full bg-red-500/10 border border-red-500/30 text-red-400 mb-4">
          <ShieldAlert className="h-12 w-12" />
        </div>
        <h1 className="text-2xl font-bold text-white mb-2">403 — Access Denied</h1>
        <p className="text-sm text-slate-400 max-w-md mb-6">
          You do not have sufficient administrative privileges to access this page. Please contact your system administrator or Root Owner to request delegation.
        </p>
        <Button variant="outline" onClick={() => window.history.back()}>
          Go Back
        </Button>
      </div>
    );
  }

  return <>{children}</>;
}
