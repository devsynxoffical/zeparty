// ============================================================
// ZeParty Public — Footer (JSX)
// ============================================================

import React from 'react';
import { Link } from 'react-router-dom';
import logoUrl from '../../assets/images/zeparty-logo.png';

export function PublicFooter() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-[#050505] border-t border-white/5 pt-16 pb-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12 mb-12">
          
          {/* Brand Col */}
          <div className="col-span-1">
            <Link to="/" className="flex items-center gap-2 mb-4">
              <img src={logoUrl} alt="ZeParty Logo" className="h-8 w-auto opacity-90" />
              <span className="text-white font-bold text-xl tracking-tight">ZeParty</span>
            </Link>
            <p className="text-slate-400 text-sm leading-relaxed max-w-sm">
              The premier platform for social entertainment, live streaming, and interactive community building.
            </p>
          </div>

          {/* Navigation Col */}
          <div>
            <h3 className="text-white font-semibold mb-4 tracking-wide text-sm uppercase">Navigation</h3>
            <ul className="space-y-3">
              <li>
                <Link to="/" className="text-slate-400 hover:text-[#D4AF37] text-sm transition-colors">Home</Link>
              </li>
              <li>
                <Link to="/about" className="text-slate-400 hover:text-[#D4AF37] text-sm transition-colors">About Us</Link>
              </li>
              <li>
                <Link to="/contact" className="text-slate-400 hover:text-[#D4AF37] text-sm transition-colors">Contact</Link>
              </li>
            </ul>
          </div>

          {/* Admin / Portal Col */}
          <div>
            <h3 className="text-white font-semibold mb-4 tracking-wide text-sm uppercase">Portal</h3>
            <ul className="space-y-3">
              <li>
                <Link to="/admin/login" className="text-slate-400 hover:text-[#D4AF37] text-sm transition-colors flex items-center gap-2">
                  Admin Login
                </Link>
              </li>
            </ul>
          </div>

        </div>

        {/* Bottom Bar */}
        <div className="border-t border-white/10 pt-8 flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-slate-500 text-sm">
            &copy; {currentYear} ZeParty. All rights reserved.
          </p>
          <div className="flex space-x-6 text-sm">
            <span className="text-slate-600 cursor-not-allowed hover:text-slate-400 transition-colors">Privacy Policy</span>
            <span className="text-slate-600 cursor-not-allowed hover:text-slate-400 transition-colors">Terms of Service</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
