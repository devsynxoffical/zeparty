// ============================================================
// ZeParty Admin Portal — Admin Header & Global Search (JSX)
// ============================================================

import React, { useState, useRef, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import {
  Bell,
  ChevronDown,
  LogOut,
  Menu,
  Settings,
  User,
  Search,
  X,
  Radio,
  Coins,
  Crown,
  Building2,
  Ticket
} from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { Avatar } from '../common/Avatar';
import { Modal } from '../ui/Modal';
import { MOCK_USERS } from '../../mocks/users.mock';
import { MOCK_COIN_SELLERS } from '../../mocks/leaderboards.mock';

const PAGE_TITLES = {
  '/admin': 'Dashboard',
  '/admin/users': 'User Management',
  '/admin/live-rooms': 'Live Rooms',
  '/admin/recharge-plans': 'Recharge Plans',
  '/admin/offline-recharge': 'Offline Recharge',
  '/admin/recharge-online': 'Online Recharge',
  '/admin/withdrawals': 'Withdrawals Center',
  '/admin/gifts': 'Gift Catalog',
  '/admin/vip-store': 'VIP / SVIP Store',
  '/admin/economy': 'Economy Policy Settings',
  '/admin/leaderboards': 'Leaderboards',
  '/admin/rankings': 'Global Rankings Engine',
  '/admin/hosts': 'Host Management',
  '/admin/agencies': 'Agency Management',
  '/admin/coin-sellers': 'Resellers & Coin Distribution',
  '/admin/merchants': 'Merchant Management',
  '/admin/transactions': 'Transaction Ledger',
  '/admin/coin-refunds': 'Coin Refund Center',
  '/admin/reseller-corrections': 'Reseller Corrections',
  '/admin/refund-requests': 'Refund Requests',
  '/admin/chargebacks': 'Chargebacks & Disputes',
  '/admin/risk': 'Fraud & Risk Intelligence',
  '/admin/restrictions': 'Ban & Restrictions',
  '/admin/referrals': 'Referral System',
  '/admin/items': 'Virtual Items Catalog',
  '/admin/games': 'Games Configuration',
  '/admin/chat': 'Chat Moderation',
  '/admin/banners': 'Banners & Homepage',
  '/admin/announcements': 'Announcements',
  '/admin/notifications': 'Notifications Broadcast',
  '/admin/reports': 'Reports & Analytics',
  '/admin/moderation': 'Moderation Center',
  '/admin/support': 'Customer Support Tickets',
  '/admin/teams-roles': 'Admin Roles & RBAC',
  '/admin/audit-logs': 'Audit Logs',
  '/admin/profile': 'Admin Profile',
  '/admin/settings': 'System Settings',
  '/admin/localization': 'Localization & Currencies',
  '/admin/payment-providers': 'Payment Provider Gateway Settings',
  '/admin/api-logs': 'API & Webhook Logs',
  '/admin/system-health': 'System Health',
  '/admin/app-config': 'App Feature Flags',
  '/admin/backups': 'Backup & Recovery',
  '/admin/privacy': 'Privacy & Compliance',
  '/admin/policy-versioning': 'Policy Versioning Engine',
  '/admin/jobs': 'Scheduled Cron Jobs',
};

function getPageTitle(pathname) {
  if (PAGE_TITLES[pathname]) return PAGE_TITLES[pathname];
  for (const [key, value] of Object.entries(PAGE_TITLES)) {
    if (pathname.startsWith(key) && key !== '/admin') return value;
  }
  return 'Admin Portal';
}

function GlobalSearchModal({ isOpen, onClose }) {
  const [query, setQuery] = useState('');
  const navigate = useNavigate();

  const results = query.trim()
    ? MOCK_USERS.filter(
        (u) =>
          u.displayName.toLowerCase().includes(query.toLowerCase()) ||
          u.username.toLowerCase().includes(query.toLowerCase()) ||
          u.id.toLowerCase().includes(query.toLowerCase())
      )
    : [];

  if (!isOpen) return null;

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Global Portal Search" size="md">
      <div className="space-y-4">
        <div className="relative">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            autoFocus
            placeholder="Search by User ID, Name, Txn ID, Room ID..."
            className="w-full rounded-lg border border-slate-700 bg-slate-800 py-2 pl-9 pr-3 text-sm text-white placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-gold-500"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>

        <div className="max-h-60 overflow-y-auto space-y-1">
          {results.length > 0 ? (
            results.map((u) => (
              <div
                key={u.id}
                onClick={() => {
                  onClose();
                  navigate(`/admin/users/${u.id}`);
                }}
                className="flex items-center justify-between p-2.5 rounded-lg hover:bg-slate-800 cursor-pointer text-xs"
              >
                <div>
                  <p className="font-bold text-white">{u.displayName}</p>
                  <p className="text-slate-400">@{u.username} • ID: {u.id}</p>
                </div>
                <span className="text-gold-400 font-mono">View Details →</span>
              </div>
            ))
          ) : query ? (
            <p className="text-xs text-slate-500 text-center py-4">No matching records found for "{query}"</p>
          ) : (
            <p className="text-xs text-slate-500 text-center py-4">Type a query to search across Users, Hosts, Agencies, Rooms, Transactions...</p>
          )}
        </div>
      </div>
    </Modal>
  );
}

function ProfileMenu({ onLogout, displayName, email }) {
  const [isOpen, setIsOpen] = useState(false);
  const navigate = useNavigate();
  const menuRef = useRef(null);

  useEffect(() => {
    if (!isOpen) return;

    function handleOutsideClick(e) {
      if (menuRef.current && !menuRef.current.contains(e.target)) {
        setIsOpen(false);
      }
    }

    document.addEventListener('mousedown', handleOutsideClick);
    document.addEventListener('touchstart', handleOutsideClick);

    return () => {
      document.removeEventListener('mousedown', handleOutsideClick);
      document.removeEventListener('touchstart', handleOutsideClick);
    };
  }, [isOpen]);

  return (
    <div className="relative z-50" ref={menuRef}>
      <button
        onClick={() => setIsOpen((prev) => !prev)}
        className="flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-slate-800 transition-colors duration-150"
      >
        <Avatar name={displayName} size="sm" />
        <div className="hidden md:block text-left">
          <p className="text-xs font-medium text-white leading-none">{displayName}</p>
          <p className="mt-0.5 text-[11px] text-slate-500 leading-none truncate max-w-[120px]">
            {email}
          </p>
        </div>
        <ChevronDown className="h-3.5 w-3.5 text-slate-500" />
      </button>

      {isOpen && (
        <div className="absolute right-0 top-full mt-1.5 z-50 w-48 rounded-xl border border-slate-700 bg-slate-900 shadow-2xl py-1">
          <div
            className="px-3 py-2 border-b border-slate-700/60 cursor-pointer hover:bg-slate-800/60"
            onClick={() => {
              setIsOpen(false);
              navigate('/admin/profile');
            }}
          >
            <p className="text-xs font-semibold text-white">{displayName}</p>
            <p className="text-[11px] text-slate-500">{email}</p>
          </div>

          <button
            className="flex w-full items-center gap-2.5 px-3 py-2 text-sm text-slate-400 hover:bg-slate-800 hover:text-white"
            onClick={() => {
              setIsOpen(false);
              navigate('/admin/profile');
            }}
          >
            <User className="h-4 w-4 text-gold-400" />
            Profile
          </button>

          <button
            className="flex w-full items-center gap-2.5 px-3 py-2 text-sm text-slate-400 hover:bg-slate-800 hover:text-white"
            onClick={() => {
              setIsOpen(false);
              navigate('/admin/settings');
            }}
          >
            <Settings className="h-4 w-4 text-gold-400" />
            Settings
          </button>

          <div className="my-1 border-t border-slate-700/60" />

          <button
            className="flex w-full items-center gap-2.5 px-3 py-2 text-sm text-red-400 hover:bg-slate-800 hover:text-red-300"
            onClick={() => {
              setIsOpen(false);
              onLogout();
            }}
          >
            <LogOut className="h-4 w-4" />
            Sign out
          </button>
        </div>
      )}
    </div>
  );
}

export function AdminHeader({ onMenuClick }) {
  const { admin, logout } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [searchOpen, setSearchOpen] = useState(false);
  const pageTitle = getPageTitle(location.pathname);

  const handleLogout = async () => {
    await logout();
    navigate('/', { replace: true });
  };

  return (
    <header className="relative z-50 flex h-14 flex-shrink-0 items-center justify-between border-b border-slate-700/60 bg-slate-900/80 backdrop-blur-sm px-4 md:px-6">
      <div className="flex items-center gap-3">
        <button
          onClick={onMenuClick}
          className="lg:hidden flex h-9 w-9 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-800 hover:text-white"
        >
          <Menu className="h-5 w-5" />
        </button>
        <h1 className="text-sm font-semibold text-white">{pageTitle}</h1>
      </div>

      <div className="flex items-center gap-3">
        {/* Global Search Trigger */}
        <button
          onClick={() => setSearchOpen(true)}
          className="flex items-center gap-2 bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-400 text-xs px-3 py-1.5 rounded-lg transition-colors"
        >
          <Search className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">Global Search...</span>
          <kbd className="hidden sm:inline bg-slate-900 px-1.5 py-0.5 rounded text-[10px] text-slate-500 font-mono">Ctrl+K</kbd>
        </button>

        {admin && (
          <ProfileMenu
            displayName={admin.displayName}
            email={admin.email}
            onLogout={handleLogout}
          />
        )}
      </div>

      <GlobalSearchModal isOpen={searchOpen} onClose={() => setSearchOpen(false)} />
    </header>
  );
}
