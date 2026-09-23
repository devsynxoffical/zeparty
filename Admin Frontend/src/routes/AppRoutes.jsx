// ============================================================
// ZeParty Admin Portal — App Routes Engine (JSX)
// Client Excel Complete 61 Module Route Registrations
// ============================================================

import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AdminLayout } from '../layouts/AdminLayout';
import { PublicLayout } from '../layouts/PublicLayout';
import { ProtectedRoute, ModuleRouteGuard } from './ProtectedRoute';

// Public Pages
import { HomePage } from '../pages/public/HomePage';
import { AboutPage } from '../pages/public/AboutPage';
import { ContactPage } from '../pages/public/ContactPage';
import { PublicNotFoundPage } from '../pages/public/PublicNotFoundPage';

// Admin Auth
import { AdminLogin } from '../pages/auth/AdminLogin';

// Existing & Expanded Admin Pages
import { Dashboard } from '../pages/admin/Dashboard';
import { UsersPage } from '../pages/admin/UsersPage';
import { UserDetailPage } from '../pages/admin/UserDetailPage';
import { LiveRoomsPage } from '../pages/admin/LiveRoomsPage';
import { LiveRoomDetailPage } from '../pages/admin/LiveRoomDetailPage';
import { RoomPinManagementPage } from '../pages/admin/RoomPinManagementPage';
import { RechargePlansPage } from '../pages/admin/RechargePlansPage';
import { OfflineRechargePage } from '../pages/admin/OfflineRechargePage';
import { WithdrawalsPage } from '../pages/admin/WithdrawalsPage';
import { GiftsPage } from '../pages/admin/GiftsPage';
import { VIPStorePage } from '../pages/admin/VIPStorePage';
import { EconomySettingsPage } from '../pages/admin/EconomySettingsPage';
import { LeaderboardsPage } from '../pages/admin/LeaderboardsPage';
import { HostsPage } from '../pages/admin/HostsPage';
import { AgenciesPage } from '../pages/admin/AgenciesPage';
import { BDCentersPage } from '../pages/admin/BDCentersPage';
import { EmojiManagementPage } from '../pages/admin/EmojiManagementPage';
import { CoinSellersPage } from '../pages/admin/CoinSellersPage';
import { GamesPage } from '../pages/admin/GamesPage';
import { AnnouncementsPage } from '../pages/admin/AnnouncementsPage';
import { NotificationsPage } from '../pages/admin/NotificationsPage';
import { TeamsRolesPage } from '../pages/admin/TeamsRolesPage';
import { ProfilePage } from '../pages/admin/ProfilePage';
import { SettingsPage } from '../pages/admin/SettingsPage';
import { PKEventsPage } from '../pages/admin/PKEventsPage';
import { WalletPage } from '../pages/admin/WalletPage';
import { FinancePage } from '../pages/admin/FinancePage';
import { StorePage } from '../pages/admin/StorePage';
import { BannersPage } from '../pages/admin/BannersPage';
import { PostsPage } from '../pages/admin/PostsPage';
import { ModerationPage } from '../pages/admin/ModerationPage';
import { ReportsPage } from '../pages/admin/ReportsPage';
import { SupportPage } from '../pages/admin/SupportPage';
import { AuditLogsPage } from '../pages/admin/AuditLogsPage';
import { ApprovalsPage } from '../pages/admin/ApprovalsPage';

// New Client Excel Required Pages
import { MerchantsPage } from '../pages/admin/MerchantsPage';
import { OnlineRechargePage } from '../pages/admin/OnlineRechargePage';
import { TransactionLedgerPage } from '../pages/admin/TransactionLedgerPage';
import { CoinRefundCenterPage } from '../pages/admin/CoinRefundCenterPage';
import { ResellerCorrectionsPage } from '../pages/admin/ResellerCorrectionsPage';
import { RefundRequestsPage } from '../pages/admin/RefundRequestsPage';
import { ChargebacksPage } from '../pages/admin/ChargebacksPage';
import { FraudRiskPage } from '../pages/admin/FraudRiskPage';
import { RestrictionsPage } from '../pages/admin/RestrictionsPage';
import { RankingsPage } from '../pages/admin/RankingsPage';
import { ReferralsPage } from '../pages/admin/ReferralsPage';
import { VirtualItemsPage } from '../pages/admin/VirtualItemsPage';
import { ChatModerationPage } from '../pages/admin/ChatModerationPage';
import { LocalizationPage } from '../pages/admin/LocalizationPage';
import { PaymentProvidersPage } from '../pages/admin/PaymentProvidersPage';
import { ApiLogsPage } from '../pages/admin/ApiLogsPage';
import { SystemHealthPage } from '../pages/admin/SystemHealthPage';
import { AppConfigPage } from '../pages/admin/AppConfigPage';
import { BackupsPage } from '../pages/admin/BackupsPage';
import { PrivacyCompliancePage } from '../pages/admin/PrivacyCompliancePage';
import { PolicyVersioningPage } from '../pages/admin/PolicyVersioningPage';
import { ScheduledJobsPage } from '../pages/admin/ScheduledJobsPage';
import { AssetsPage } from '../pages/admin/AssetsPage';
import { RoomThemeApprovalPage } from '../pages/admin/RoomThemeApprovalPage';

import { MasterOwnerControlPage } from '../pages/admin/MasterOwnerControlPage';

export function AppRoutes() {
  return (
    <Routes>
      {/* Unified Admin & Owner Login */}
      <Route path="/admin/login" element={<AdminLogin />} />

      {/* Public Website */}
      <Route element={<PublicLayout />}>
        <Route path="/" element={<HomePage />} />
        <Route path="/about" element={<AboutPage />} />
        <Route path="/contact" element={<ContactPage />} />
        <Route path="*" element={<PublicNotFoundPage />} />
      </Route>

      {/* Protected Admin Portal */}
      <Route
        path="/admin"
        element={
          <ProtectedRoute>
            <AdminLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<Dashboard />} />

        {/* User Management */}
        <Route path="users" element={<ModuleRouteGuard requiredPermission="view_users"><UsersPage /></ModuleRouteGuard>} />
        <Route path="users/:id" element={<ModuleRouteGuard requiredPermission="view_user_details"><UserDetailPage /></ModuleRouteGuard>} />
        <Route path="wallet" element={<ModuleRouteGuard requiredPermission="view_users"><WalletPage /></ModuleRouteGuard>} />

        {/* Live Rooms & Pin Management */}
        <Route path="live-rooms" element={<ModuleRouteGuard requiredPermission="view_live_rooms"><LiveRoomsPage /></ModuleRouteGuard>} />
        <Route path="live-rooms/:id" element={<ModuleRouteGuard requiredPermission="view_room_details"><LiveRoomDetailPage /></ModuleRouteGuard>} />
        <Route path="room-pin-management" element={<ModuleRouteGuard requiredPermission="view_live_rooms"><RoomPinManagementPage /></ModuleRouteGuard>} />

        {/* Gifts, Assets & Emojis */}
        <Route path="gifts" element={<ModuleRouteGuard requiredPermission="view_gifts"><GiftsPage /></ModuleRouteGuard>} />
        <Route path="emojis" element={<ModuleRouteGuard requiredPermission="view_gifts"><EmojiManagementPage /></ModuleRouteGuard>} />
        <Route path="hosts" element={<ModuleRouteGuard requiredPermission="view_hosts"><HostsPage /></ModuleRouteGuard>} />
        <Route path="agencies" element={<ModuleRouteGuard requiredPermission="view_agencies"><AgenciesPage /></ModuleRouteGuard>} />
        <Route path="bd-centers" element={<ModuleRouteGuard requiredPermission="manage_bd_centers"><BDCentersPage /></ModuleRouteGuard>} />

        {/* Resellers & Merchants */}
        <Route path="coin-sellers" element={<ModuleRouteGuard requiredPermission="view_sellers"><CoinSellersPage /></ModuleRouteGuard>} />
        <Route path="merchants" element={<ModuleRouteGuard requiredPermission="view_merchants"><MerchantsPage /></ModuleRouteGuard>} />

        {/* Recharge & Withdrawals */}
        <Route path="recharge-plans" element={<ModuleRouteGuard requiredPermission="view_recharge_plans"><RechargePlansPage /></ModuleRouteGuard>} />
        <Route path="recharge-online" element={<ModuleRouteGuard requiredPermission="view_recharge_plans"><OnlineRechargePage /></ModuleRouteGuard>} />
        <Route path="offline-recharge" element={<ModuleRouteGuard requiredPermission="view_offline_recharge"><OfflineRechargePage /></ModuleRouteGuard>} />
        <Route path="withdrawals" element={<ModuleRouteGuard requiredPermission="view_withdrawals"><WithdrawalsPage /></ModuleRouteGuard>} />
        <Route path="transactions" element={<ModuleRouteGuard requiredPermission="view_ledger"><TransactionLedgerPage /></ModuleRouteGuard>} />
        <Route path="finance" element={<ModuleRouteGuard requiredPermission="view_finance"><FinancePage /></ModuleRouteGuard>} />

        {/* Refunds & Risk */}
        <Route path="coin-refunds" element={<ModuleRouteGuard requiredPermission="view_refunds"><CoinRefundCenterPage /></ModuleRouteGuard>} />
        <Route path="reseller-corrections" element={<ModuleRouteGuard requiredPermission="reseller_corrections"><ResellerCorrectionsPage /></ModuleRouteGuard>} />
        <Route path="refund-requests" element={<ModuleRouteGuard requiredPermission="view_refunds"><RefundRequestsPage /></ModuleRouteGuard>} />
        <Route path="chargebacks" element={<ModuleRouteGuard requiredPermission="view_chargebacks"><ChargebacksPage /></ModuleRouteGuard>} />
        <Route path="risk" element={<ModuleRouteGuard requiredPermission="view_fraud_risk"><FraudRiskPage /></ModuleRouteGuard>} />
        <Route path="restrictions" element={<ModuleRouteGuard requiredPermission="manage_restrictions"><RestrictionsPage /></ModuleRouteGuard>} />

        {/* Virtual Economy & Games */}
        <Route path="assets" element={<ModuleRouteGuard requiredPermission="view_gifts"><AssetsPage /></ModuleRouteGuard>} />
        <Route path="gifts" element={<ModuleRouteGuard requiredPermission="view_gifts"><GiftsPage /></ModuleRouteGuard>} />
        <Route path="vip-store" element={<ModuleRouteGuard requiredPermission="view_vip_store"><VIPStorePage /></ModuleRouteGuard>} />
        <Route path="items" element={<ModuleRouteGuard requiredPermission="view_store"><VirtualItemsPage /></ModuleRouteGuard>} />
        <Route path="store" element={<ModuleRouteGuard requiredPermission="view_store"><StorePage /></ModuleRouteGuard>} />
        <Route path="games" element={<ModuleRouteGuard requiredPermission="view_games"><GamesPage /></ModuleRouteGuard>} />
        <Route path="economy" element={<ModuleRouteGuard requiredPermission="economy_settings"><EconomySettingsPage /></ModuleRouteGuard>} />

        {/* Engagement & Content */}
        <Route path="pk-events" element={<ModuleRouteGuard requiredPermission="view_pk_events"><PKEventsPage /></ModuleRouteGuard>} />
        <Route path="rankings" element={<ModuleRouteGuard requiredPermission="view_users"><RankingsPage /></ModuleRouteGuard>} />
        <Route path="leaderboards" element={<ModuleRouteGuard requiredPermission="view_users"><LeaderboardsPage /></ModuleRouteGuard>} />
        <Route path="referrals" element={<ModuleRouteGuard requiredPermission="view_users"><ReferralsPage /></ModuleRouteGuard>} />
        <Route path="banners" element={<ModuleRouteGuard requiredPermission="view_banners"><BannersPage /></ModuleRouteGuard>} />
        <Route path="posts" element={<ModuleRouteGuard requiredPermission="view_users"><PostsPage /></ModuleRouteGuard>} />
        <Route path="announcements" element={<ModuleRouteGuard requiredPermission="view_announcements"><AnnouncementsPage /></ModuleRouteGuard>} />
        <Route path="room-theme-approval" element={<ModuleRouteGuard requiredPermission="manage_banners"><RoomThemeApprovalPage /></ModuleRouteGuard>} />
        <Route path="notifications" element={<ModuleRouteGuard requiredPermission="view_notifications"><NotificationsPage /></ModuleRouteGuard>} />

        {/* Moderation & Support */}
        <Route path="moderation" element={<ModuleRouteGuard requiredPermission="view_moderation"><ModerationPage /></ModuleRouteGuard>} />
        <Route path="chat" element={<ModuleRouteGuard requiredPermission="view_chat"><ChatModerationPage /></ModuleRouteGuard>} />
        <Route path="reports" element={<ModuleRouteGuard requiredPermission="view_reports"><ReportsPage /></ModuleRouteGuard>} />
        <Route path="support" element={<ModuleRouteGuard requiredPermission="view_support"><SupportPage /></ModuleRouteGuard>} />

        {/* Master Control & Governance */}
        <Route path="master-control" element={<MasterOwnerControlPage />} />
        <Route path="approvals" element={<ApprovalsPage />} />
        <Route path="teams-roles" element={<ModuleRouteGuard requiredPermission="view_admins"><TeamsRolesPage /></ModuleRouteGuard>} />
        <Route path="audit-logs" element={<ModuleRouteGuard requiredPermission="view_audit_logs"><AuditLogsPage /></ModuleRouteGuard>} />
        <Route path="profile" element={<ProfilePage />} />
        <Route path="settings" element={<ModuleRouteGuard requiredPermission="view_settings"><SettingsPage /></ModuleRouteGuard>} />
        <Route path="localization" element={<ModuleRouteGuard requiredPermission="view_settings"><LocalizationPage /></ModuleRouteGuard>} />
        <Route path="payment-providers" element={<ModuleRouteGuard requiredPermission="view_settings"><PaymentProvidersPage /></ModuleRouteGuard>} />
        <Route path="api-logs" element={<ModuleRouteGuard requiredPermission="view_system_health"><ApiLogsPage /></ModuleRouteGuard>} />
        <Route path="system-health" element={<ModuleRouteGuard requiredPermission="view_system_health"><SystemHealthPage /></ModuleRouteGuard>} />
        <Route path="app-config" element={<ModuleRouteGuard requiredPermission="view_settings"><AppConfigPage /></ModuleRouteGuard>} />
        <Route path="backups" element={<ModuleRouteGuard requiredPermission="view_settings"><BackupsPage /></ModuleRouteGuard>} />
        <Route path="privacy" element={<ModuleRouteGuard requiredPermission="view_settings"><PrivacyCompliancePage /></ModuleRouteGuard>} />
        <Route path="policy-versioning" element={<ModuleRouteGuard requiredPermission="view_settings"><PolicyVersioningPage /></ModuleRouteGuard>} />
        <Route path="jobs" element={<ModuleRouteGuard requiredPermission="view_settings"><ScheduledJobsPage /></ModuleRouteGuard>} />

        {/* Admin 404 Fallback */}
        <Route path="*" element={<Navigate to="/admin" replace />} />
      </Route>
    </Routes>
  );
}
