// ============================================================
// ZeParty Public — Not Found Page (JSX)
// ============================================================

import React from 'react';
import { Link } from 'react-router-dom';

export function PublicNotFoundPage() {
  return (
    <div className="flex-1 flex items-center justify-center pt-20 pb-20 px-4">
      <div className="text-center">
        <h1 className="text-9xl font-bold text-[#D4AF37] opacity-20">404</h1>
        <h2 className="text-2xl font-bold text-white mt-4 tracking-tight">Page Not Found</h2>
        <p className="text-slate-400 mt-2 max-w-sm mx-auto mb-8">
          The page you are looking for doesn't exist or has been moved.
        </p>
        <Link
          to="/"
          className="inline-block bg-[#D4AF37] hover:bg-[#B8962E] text-black font-semibold py-3 px-8 rounded-lg transition-colors"
        >
          Return Home
        </Link>
      </div>
    </div>
  );
}
