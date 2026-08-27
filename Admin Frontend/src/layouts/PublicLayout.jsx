// ============================================================
// ZeParty Public — Layout (JSX)
// ============================================================

import React, { useEffect } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { PublicNavbar } from '../components/public/PublicNavbar';
import { PublicFooter } from '../components/public/PublicFooter';

export function PublicLayout() {
  const location = useLocation();

  // Scroll to top on route change
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [location.pathname]);

  return (
    <div className="min-h-screen bg-[#050505] text-slate-300 font-sans selection:bg-[#D4AF37]/30 selection:text-white flex flex-col">
      <PublicNavbar />
      <main className="flex-1 flex flex-col">
        <Outlet />
      </main>
      <PublicFooter />
    </div>
  );
}
