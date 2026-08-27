// ============================================================
// ZeParty Admin Portal — AdminLayout (JSX)
// ============================================================

import React, { useState } from 'react';
import { Outlet } from 'react-router-dom';
import { Sidebar, MobileDrawer } from '../components/layout/Sidebar';
import { AdminHeader } from '../components/layout/Header';

export function AdminLayout() {
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [isMobileDrawerOpen, setIsMobileDrawerOpen] = useState(false);

  return (
    <div className="flex h-screen overflow-hidden bg-slate-950 text-white">
      <Sidebar
        isCollapsed={isSidebarCollapsed}
        onToggleCollapse={() => setIsSidebarCollapsed((v) => !v)}
      />

      <MobileDrawer
        isOpen={isMobileDrawerOpen}
        onClose={() => setIsMobileDrawerOpen(false)}
      />

      <div className="flex flex-1 flex-col min-w-0 overflow-hidden">
        <AdminHeader onMenuClick={() => setIsMobileDrawerOpen(true)} />

        <main
          id="main-content"
          className="flex-1 overflow-y-auto p-4 md:p-6"
          aria-label="Main content"
        >
          <Outlet />
        </main>
      </div>
    </div>
  );
}
