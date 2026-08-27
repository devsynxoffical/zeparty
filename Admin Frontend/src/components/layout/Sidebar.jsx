// ============================================================
// ZeParty Admin Portal — Master Sidebar Navigation (JSX)
// Client Excel 61-Module Complete Navigation Engine
// ============================================================

import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import {
  AlertTriangle,
  Banknote,
  BarChart3,
  Bell,
  BookOpen,
  ChevronDown,
  ChevronRight,
  Coins,
  Crown,
  FileText,
  Gamepad2,
  Gift,
  Image as ImageIcon,
  LayoutDashboard,
  Radio,
  Settings,
  ShieldCheck,
  ShoppingBag,
  Swords,
  Ticket,
  Trophy,
  Users,
  Wallet,
  X,
  Store,
  ShoppingCart,
  Layers,
  RotateCcw,
  ShieldAlert,
  Slash,
  Sparkles,
  Share2,
  MessageSquare,
  Globe,
  CreditCard,
  Terminal,
  Activity,
  ToggleLeft,
  HardDrive,
  History,
  Clock,
} from 'lucide-react';
import zepartyLogo from '../../assets/images/zeparty-logo.png';
import { usePermission } from '../../hooks/usePermission';

const NAV_GROUPS = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    icon: LayoutDashboard,
    path: '/admin',
  },
  {
    id: 'approvals',
    label: 'Approval Center',
    icon: ShieldCheck,
    path: '/admin/approvals',
    badge: '4-Eyes',
  },
  {
    id: 'users-group',
    label: 'User Management',
    icon: Users,
    children: [
      { id: 'users', label: 'Users Directory', path: '/admin/users' },
      { id: 'wallet', label: 'User Wallet', path: '/admin/wallet' },
    ],
  },
  {
    id: 'hosts-agencies-group',
    label: 'Hosts & Agencies',
    icon: Crown,
    children: [
      { id: 'hosts', label: 'Live Video Hosts', path: '/admin/hosts?type=live' },
      { id: 'audio-hosts', label: 'AUDIO HOSTS', path: '/admin/hosts?type=audio' },
      { id: 'agencies', label: 'Live Video Agencies', path: '/admin/agencies?type=live' },
      { id: 'audio-agencies', label: 'AUDIO AGENCIES', path: '/admin/agencies?type=audio' },
    ],
  },
  {
    id: 'rooms-group',
    label: 'ROOMS',
    icon: Radio,
    children: [
      { id: 'live-rooms', label: 'Live Rooms', path: '/admin/live-rooms?type=live' },
      { id: 'party-rooms', label: 'Party Rooms', path: '/admin/live-rooms?type=party' },
    ],
  },
  {
    id: 'merchants-resellers-group',
    label: 'Resellers & Merchants',
    icon: Store,
    children: [
      { id: 'coin-sellers', label: 'Coin Resellers', path: '/admin/coin-sellers' },
      { id: 'merchants', label: 'Merchant Management', path: '/admin/merchants' },
    ],
  },
  {
    id: 'recharge-withdrawals-group',
    label: 'Recharge & Withdrawals',
    icon: Banknote,
    children: [
      { id: 'recharge-plans', label: 'Recharge Plans', path: '/admin/recharge-plans' },
      { id: 'online-recharge', label: 'Online Recharge', path: '/admin/recharge-online' },
      { id: 'offline-recharge', label: 'Offline Recharge', path: '/admin/offline-recharge' },
      { id: 'withdrawals', label: 'Withdrawal Center', path: '/admin/withdrawals' },
      { id: 'transactions', label: 'Transaction Ledger', path: '/admin/transactions' },
      { id: 'finance', label: 'Earnings & Revenue', path: '/admin/finance' },
    ],
  },
  {
    id: 'refunds-risk-group',
    label: 'Refunds & Risk Center',
    icon: RotateCcw,
    children: [
      { id: 'coin-refunds', label: 'Coin Refund Center', path: '/admin/coin-refunds' },
      { id: 'reseller-corrections', label: 'Reseller Corrections', path: '/admin/reseller-corrections' },
      { id: 'refund-requests', label: 'Refund Requests', path: '/admin/refund-requests' },
      { id: 'chargebacks', label: 'Chargebacks & Disputes', path: '/admin/chargebacks' },
      { id: 'risk', label: 'Fraud & Risk Center', path: '/admin/risk' },
    ],
  },
  {
    id: 'economy-store-group',
    label: 'Virtual Economy',
    icon: Gift,
    children: [
      { id: 'assets', label: 'Asset Management', path: '/admin/assets' },
      { id: 'gifts', label: 'Gift Catalog', path: '/admin/gifts' },
      { id: 'vip-store', label: 'VIP / SVIP Levels', path: '/admin/vip-store' },
      { id: 'items', label: 'Virtual Items (Frames/Rides)', path: '/admin/items' },
      { id: 'store', label: 'Virtual Store', path: '/admin/store' },
      { id: 'games', label: 'Minigames', path: '/admin/games' },
      { id: 'economy', label: 'Economy Policy', path: '/admin/economy' },
    ],
  },
  {
    id: 'engagement-group',
    label: 'Engagement & PK',
    icon: Swords,
    children: [
      { id: 'pk-events', label: 'PK & Live Events', path: '/admin/pk-events' },
      { id: 'rankings', label: 'Global Rankings', path: '/admin/rankings' },
      { id: 'referrals', label: 'Referral System', path: '/admin/referrals' },
    ],
  },
  {
    id: 'content-comms-group',
    label: 'Content & Banners',
    icon: ImageIcon,
    children: [
      { id: 'banners', label: 'Banners & Home', path: '/admin/banners' },
      { id: 'announcements', label: 'Announcements', path: '/admin/announcements' },
      { id: 'room-theme-approval', label: 'Room Theme Approval', path: '/admin/room-theme-approval' },
      { id: 'notifications', label: 'Notifications', path: '/admin/notifications' },
    ],
  },
  {
    id: 'moderation-support-group',
    label: 'Moderation & Support',
    icon: AlertTriangle,
    children: [
      { id: 'moderation', label: 'Reports & Moderation', path: '/admin/moderation' },
      { id: 'restrictions', label: 'Ban & Restrictions', path: '/admin/restrictions' },
      { id: 'chat', label: 'Chat Moderation', path: '/admin/chat' },
      { id: 'support', label: 'Customer Support', path: '/admin/support' },
      { id: 'reports', label: 'Reports & Analytics', path: '/admin/reports' },
    ],
  },
  {
    id: 'system-governance-group',
    label: 'System Administration',
    icon: Settings,
    children: [
      { id: 'teams-roles', label: 'Admin Roles & RBAC', path: '/admin/teams-roles' },
      { id: 'audit-logs', label: 'Audit Logs', path: '/admin/audit-logs' },
      { id: 'settings', label: 'Portal Settings', path: '/admin/settings' },
      { id: 'localization', label: 'Localization Settings', path: '/admin/localization' },
      { id: 'payment-providers', label: 'Payment Providers', path: '/admin/payment-providers' },
      { id: 'api-logs', label: 'API & Webhook Logs', path: '/admin/api-logs' },
      { id: 'system-health', label: 'System Health', path: '/admin/system-health' },
      { id: 'app-config', label: 'App Feature Flags', path: '/admin/app-config' },
      { id: 'backups', label: 'Backup & Recovery', path: '/admin/backups' },
      { id: 'privacy', label: 'Privacy & Compliance', path: '/admin/privacy' },
      { id: 'policy-versioning', label: 'Policy Versioning', path: '/admin/policy-versioning' },
      { id: 'jobs', label: 'Scheduled Jobs', path: '/admin/jobs' },
    ],
  },
];

function SidebarItem({ group, isCollapsed, onMobileClose }) {
  const location = useLocation();

  const isActive =
    group.path !== undefined
      ? group.path === '/admin'
        ? location.pathname === '/admin'
        : location.pathname.startsWith(group.path)
      : group.children?.some((c) => {
          const childPathname = c.path.split('?')[0];
          return location.pathname === childPathname;
        }) || false;

  const [isExpanded, setIsExpanded] = useState(isActive);
  const hasChildren = group.children && group.children.length > 0;
  const Icon = group.icon;

  if (isCollapsed) {
    return (
      <div className="relative group/tip">
        {group.path ? (
          <Link
            to={group.path}
            onClick={onMobileClose}
            className={[
              'flex h-9 w-9 items-center justify-center rounded-lg mx-auto',
              'transition-colors duration-150',
              isActive
                ? 'bg-gold-500 text-slate-950 font-bold shadow-md shadow-gold-500/20'
                : 'text-slate-400 hover:bg-slate-800 hover:text-white',
            ].join(' ')}
            aria-label={group.label}
          >
            <Icon className="h-5 w-5" />
          </Link>
        ) : (
          <button
            className={[
              'flex h-9 w-9 items-center justify-center rounded-lg mx-auto',
              'transition-colors duration-150',
              isActive
                ? 'bg-gold-500 text-slate-950 font-bold shadow-md shadow-gold-500/20'
                : 'text-slate-400 hover:bg-slate-800 hover:text-white',
            ].join(' ')}
            aria-label={group.label}
          >
            <Icon className="h-5 w-5" />
          </button>
        )}
      </div>
    );
  }

  return (
    <div>
      {group.path ? (
        <Link
          to={group.path}
          onClick={onMobileClose}
          className={[
            'flex items-center gap-3 px-3 py-2 rounded-lg text-xs font-semibold',
            'transition-colors duration-150',
            isActive
              ? 'bg-gold-500 text-slate-950 font-bold shadow-sm shadow-gold-500/20'
              : 'text-slate-400 hover:bg-slate-800 hover:text-white',
          ].join(' ')}
        >
          <Icon className="h-4 w-4 flex-shrink-0" />
          <span className="truncate">{group.label}</span>
        </Link>
      ) : (
        <button
          onClick={() => setIsExpanded(!isExpanded)}
          className={[
            'flex w-full items-center gap-3 px-3 py-2 rounded-lg text-xs font-semibold',
            'transition-colors duration-150',
            isActive ? 'text-white' : 'text-slate-400 hover:bg-slate-800 hover:text-white',
          ].join(' ')}
        >
          <Icon className="h-4 w-4 flex-shrink-0" />
          <span className="flex-1 text-left truncate">{group.label}</span>
          {hasChildren &&
            (isExpanded ? (
              <ChevronDown className="h-3.5 w-3.5 text-slate-500" />
            ) : (
              <ChevronRight className="h-3.5 w-3.5 text-slate-500" />
            ))}
        </button>
      )}

      {hasChildren && isExpanded && (
        <div className="mt-1 ml-4 pl-3 border-l border-slate-800 space-y-1">
          {group.children.map((child) => {
            const childPathname = child.path.split('?')[0];
            const childQuery = child.path.split('?')[1] || '';
            const isPathActive = location.pathname === childPathname;
            const isQueryActive = childQuery ? location.search.includes(childQuery) : (!location.search || location.search === '?type=live' || location.search === '');
            const isChildActive = isPathActive && isQueryActive;
            return (
              <Link
                key={child.id}
                to={child.path}
                onClick={onMobileClose}
                className={[
                  'flex items-center px-3 py-1.5 rounded-lg text-[11px] font-medium',
                  'transition-colors duration-150',
                  isChildActive
                    ? 'text-gold-400 font-bold bg-gold-500/10'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/60',
                ].join(' ')}
              >
                <span className="truncate">{child.label}</span>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}

function SidebarBrand({ isCollapsed }) {
  return (
    <div className="flex items-center gap-3 px-3.5 py-4 border-b border-slate-700/60">
      <img
        src={zepartyLogo}
        alt="ZeParty Logo"
        className="h-8 w-8 rounded-lg object-cover border border-gold-500/30 flex-shrink-0 shadow-sm"
      />
      {!isCollapsed && (
        <div className="min-w-0">
          <span className="text-base font-bold text-white tracking-tight">ZeParty</span>
          <span className="ml-1.5 text-[10px] font-bold text-gold-400 uppercase tracking-widest bg-gold-500/15 px-1.5 py-0.5 rounded border border-gold-500/20">
            Admin
          </span>
        </div>
      )}
    </div>
  );
}

function SidebarNavList({ isCollapsed, onMobileClose }) {
  const { isSuperAdmin } = usePermission();

  return (
    <nav className="flex-1 overflow-y-auto py-3 px-2 space-y-1 scrollbar-thin">
      {NAV_GROUPS.map((group) => (
        <SidebarItem
          key={group.id}
          group={group}
          isCollapsed={isCollapsed}
          onMobileClose={onMobileClose}
        />
      ))}
    </nav>
  );
}

export function Sidebar({ isCollapsed, onToggleCollapse }) {
  return (
    <aside
      className={[
        'hidden lg:flex flex-col h-screen bg-slate-900 border-r border-slate-700/60',
        'transition-all duration-300 ease-in-out flex-shrink-0',
        isCollapsed ? 'w-[60px]' : 'w-[250px]',
      ].join(' ')}
    >
      <SidebarBrand isCollapsed={isCollapsed} />
      <SidebarNavList isCollapsed={isCollapsed} />

      <div className="border-t border-slate-700/60 p-2">
        <button
          onClick={onToggleCollapse}
          className="flex w-full items-center justify-center h-9 rounded-lg text-slate-500 hover:bg-slate-800 hover:text-white transition-colors duration-150"
        >
          <BookOpen className="h-4 w-4" />
          {!isCollapsed && <span className="ml-2 text-xs">Collapse</span>}
        </button>
      </div>
    </aside>
  );
}

export function MobileDrawer({ isOpen, onClose }) {
  return (
    <>
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-40 lg:hidden"
          onClick={onClose}
        />
      )}

      <aside
        className={[
          'fixed inset-y-0 left-0 z-50 w-[250px] bg-slate-900 border-r border-slate-700/60',
          'flex flex-col lg:hidden',
          'transition-transform duration-300 ease-in-out',
          isOpen ? 'translate-x-0' : '-translate-x-full',
        ].join(' ')}
      >
        <div className="flex items-center justify-between px-4 py-4 border-b border-slate-700/60">
          <div className="flex items-center gap-3">
            <img
              src={zepartyLogo}
              alt="ZeParty Logo"
              className="h-8 w-8 rounded-lg object-cover border border-gold-500/30 flex-shrink-0"
            />
            <div>
              <span className="text-base font-bold text-white tracking-tight">ZeParty</span>
              <span className="ml-1.5 text-[10px] font-bold text-gold-400 uppercase tracking-widest bg-gold-500/15 px-1.5 py-0.5 rounded border border-gold-500/20">
                Admin
              </span>
            </div>
          </div>
          <button
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-lg text-slate-400 hover:bg-slate-800 hover:text-white"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <SidebarNavList isCollapsed={false} onMobileClose={onClose} />
      </aside>
    </>
  );
}
