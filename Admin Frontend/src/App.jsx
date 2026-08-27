// ============================================================
// ZeParty Admin Portal — App Root Component (JSX)
// ============================================================

import React from 'react';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { PermissionProvider } from './context/PermissionContext';
import { AuditLogProvider } from './context/AuditLogContext';
import { AppRoutes } from './routes/AppRoutes';

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <PermissionProvider>
          <AuditLogProvider>
            <AppRoutes />
          </AuditLogProvider>
        </PermissionProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
