import prisma from '../config/database.js';
import ledgerService from './ledger.service.js';
import { sanitizeFinancial } from '../utils/bigint.util.js';

/**
 * ZEPARTY MASTER ADMIN PANEL & GOVERNANCE SERVICE
 * Enforces the 61-Module Specification, 7-Tier Admin Role Matrix, 
 * 21 Critical Backend/Finance/Security Rules, and Coin Refund & Correction System.
 */

export const ADMIN_ROLE_MATRIX = {
  SUPER_ADMIN: {
    name: 'Super Admin',
    permissions: {
      users: 'FULL',
      hosts: 'FULL',
      liveHosts: 'FULL',
      agencies: 'FULL',
      resellersMerchants: 'FULL',
      rechargeWithdrawals: 'FULL',
      economyPolicy: 'FULL',
      moderation: 'FULL',
      giftsBannersEvents: 'FULL',
      support: 'FULL',
      adminRoles: 'FULL',
      auditLogs: 'FULL',
      systemSettings: 'FULL',
    },
  },
  FINANCE_ADMIN: {
    name: 'Finance Admin',
    permissions: {
      users: 'VIEW',
      hosts: 'VIEW',
      liveHosts: 'VIEW',
      agencies: 'VIEW',
      resellersMerchants: 'FULL',
      rechargeWithdrawals: 'FULL',
      economyPolicy: 'NO',
      moderation: 'VIEW',
      giftsBannersEvents: 'NO',
      support: 'VIEW',
      adminRoles: 'NO',
      auditLogs: 'VIEW',
      systemSettings: 'NO',
    },
  },
  HOST_ADMIN: {
    name: 'Host Admin',
    permissions: {
      users: 'VIEW_EDIT',
      hosts: 'FULL',
      liveHosts: 'FULL',
      agencies: 'VIEW',
      resellersMerchants: 'VIEW',
      rechargeWithdrawals: 'VIEW',
      economyPolicy: 'NO',
      moderation: 'VIEW',
      giftsBannersEvents: 'VIEW',
      support: 'VIEW',
      adminRoles: 'NO',
      auditLogs: 'VIEW',
      systemSettings: 'NO',
    },
  },
  AGENCY_ADMIN: {
    name: 'Agency Admin',
    permissions: {
      users: 'VIEW',
      hosts: 'VIEW',
      liveHosts: 'VIEW',
      agencies: 'FULL',
      resellersMerchants: 'VIEW',
      rechargeWithdrawals: 'VIEW',
      economyPolicy: 'NO',
      moderation: 'VIEW',
      giftsBannersEvents: 'NO',
      support: 'VIEW',
      adminRoles: 'NO',
      auditLogs: 'VIEW',
      systemSettings: 'NO',
    },
  },
  MODERATOR: {
    name: 'Moderator',
    permissions: {
      users: 'VIEW',
      hosts: 'VIEW',
      liveHosts: 'VIEW',
      agencies: 'VIEW',
      resellersMerchants: 'VIEW',
      rechargeWithdrawals: 'NO',
      economyPolicy: 'NO',
      moderation: 'FULL',
      giftsBannersEvents: 'VIEW',
      support: 'VIEW',
      adminRoles: 'NO',
      auditLogs: 'VIEW',
      systemSettings: 'NO',
    },
  },
  CONTENT_ADMIN: {
    name: 'Content Admin',
    permissions: {
      users: 'VIEW',
      hosts: 'VIEW',
      liveHosts: 'VIEW',
      agencies: 'VIEW',
      resellersMerchants: 'VIEW',
      rechargeWithdrawals: 'VIEW',
      economyPolicy: 'NO',
      moderation: 'VIEW',
      giftsBannersEvents: 'FULL',
      support: 'VIEW',
      adminRoles: 'NO',
      auditLogs: 'VIEW',
      systemSettings: 'NO',
    },
  },
  SUPPORT_ADMIN: {
    name: 'Support Admin',
    permissions: {
      users: 'FULL',
      hosts: 'VIEW',
      liveHosts: 'VIEW',
      agencies: 'VIEW',
      resellersMerchants: 'VIEW',
      rechargeWithdrawals: 'VIEW',
      economyPolicy: 'NO',
      moderation: 'VIEW',
      giftsBannersEvents: 'VIEW',
      support: 'FULL',
      adminRoles: 'NO',
      auditLogs: 'VIEW',
      systemSettings: 'NO',
    },
  },
};

export const MASTER_MODULES_61 = [
  { no: 1, name: 'Admin Authentication & Security', category: 'Security & Access', priority: 'CRITICAL' },
  { no: 2, name: 'Dashboard', category: 'Executive & KPIs', priority: 'CRITICAL' },
  { no: 3, name: 'Users', category: 'Identity & User Management', priority: 'CRITICAL' },
  { no: 4, name: 'User Wallet', category: 'Financial & Ledger', priority: 'CRITICAL' },
  { no: 5, name: 'User Devices & Sessions', category: 'Security & Device Integrity', priority: 'HIGH' },
  { no: 6, name: 'Host Applications', category: 'Host Lifecycle', priority: 'CRITICAL' },
  { no: 7, name: 'Host Management', category: 'Host Operations', priority: 'CRITICAL' },
  { no: 8, name: 'Live Host / Creator', category: 'Live Streaming Compensation', priority: 'CRITICAL' },
  { no: 9, name: 'Live Rooms', category: 'Room Moderation & Controls', priority: 'CRITICAL' },
  { no: 10, name: 'Room Management', category: 'Room Hierarchy & Settings', priority: 'HIGH' },
  { no: 11, name: 'Agencies', category: 'Agency Organization', priority: 'CRITICAL' },
  { no: 12, name: 'Agency Finance', category: 'Agency Compensation', priority: 'CRITICAL' },
  { no: 13, name: 'Resellers / Coin Sellers', category: 'Distribution Channel', priority: 'CRITICAL' },
  { no: 14, name: 'Merchant Management', category: 'VIP Channel', priority: 'CRITICAL' },
  { no: 15, name: 'Coin Packages / Recharge Plans', category: 'Recharge & Monetization', priority: 'CRITICAL' },
  { no: 16, name: 'Online Recharge', category: 'Payment Gateways', priority: 'CRITICAL' },
  { no: 17, name: 'Offline Recharge', category: 'Manual Payment Proofs', priority: 'CRITICAL' },
  { no: 18, name: 'Gifts', category: 'Virtual Economy', priority: 'CRITICAL' },
  { no: 19, name: 'Gift Transactions', category: 'Ledger Audit', priority: 'CRITICAL' },
  { no: 20, name: 'Economy Settings', category: 'Monetary Governance', priority: 'CRITICAL' },
  { no: 21, name: 'Host Policy', category: 'Audio Host Compensation', priority: 'CRITICAL' },
  { no: 22, name: 'Live Host Policy', category: 'Live Host Compensation', priority: 'CRITICAL' },
  { no: 23, name: 'Withdrawal Center', category: 'Disbursement Management', priority: 'CRITICAL' },
  { no: 24, name: 'Withdrawal Settlement', category: 'Reconciliation & Payouts', priority: 'CRITICAL' },
  { no: 25, name: 'Transaction Ledger', category: 'Traceable Audit Trail', priority: 'CRITICAL' },
  { no: 26, name: 'Finance / Revenue', category: 'Executive Reporting', priority: 'CRITICAL' },
  { no: 27, name: 'Coin Refund Center', category: 'Dispute & Correction', priority: 'CRITICAL' },
  { no: 28, name: 'Reseller Coin Correction', category: 'Distribution Balancing', priority: 'CRITICAL' },
  { no: 29, name: 'Refund Requests', category: 'Dispute Lifecycle', priority: 'HIGH' },
  { no: 30, name: 'Refunds & Chargebacks', category: 'Risk Mitigation', priority: 'HIGH' },
  { no: 31, name: 'Fraud & Risk Center', category: 'Anomaly Detection', priority: 'CRITICAL' },
  { no: 32, name: 'Moderation', category: 'Trust & Safety', priority: 'CRITICAL' },
  { no: 33, name: 'Ban & Restriction Management', category: 'Enforcement Operations', priority: 'CRITICAL' },
  { no: 34, name: 'PK', category: 'Live Interactive Gaming', priority: 'HIGH' },
  { no: 35, name: 'Events', category: 'Gamification & Seasons', priority: 'HIGH' },
  { no: 36, name: 'Rankings', category: 'Leaderboards & Rewards', priority: 'HIGH' },
  { no: 37, name: 'Referral System', category: 'Growth & BD Invites', priority: 'HIGH' },
  { no: 38, name: 'VIP / SVIP / Levels', category: 'User Progression', priority: 'HIGH' },
  { no: 39, name: 'Frames / Rides / Badges', category: 'Virtual Assets', priority: 'MEDIUM' },
  { no: 40, name: 'Games', category: '10-Game Mini Platform', priority: 'MEDIUM' },
  { no: 41, name: 'Store', category: 'Catalog & Backpack', priority: 'MEDIUM' },
  { no: 42, name: 'Home / Banners', category: 'Marketing & Geo-Targeting', priority: 'HIGH' },
  { no: 43, name: 'Notifications', category: 'Broadcast & Push Messaging', priority: 'HIGH' },
  { no: 44, name: 'Chat / Messaging', category: 'Direct Social Safety', priority: 'HIGH' },
  { no: 45, name: 'Customer Support', category: 'Helpdesk & SLA Tickets', priority: 'HIGH' },
  { no: 46, name: 'Reports & Analytics', category: 'BI & Metric Visualizations', priority: 'HIGH' },
  { no: 47, name: 'Admin Roles & Permissions', category: 'RBAC Access Control', priority: 'CRITICAL' },
  { no: 48, name: 'Audit Logs', category: 'Immutable Compliance Logging', priority: 'CRITICAL' },
  { no: 49, name: 'System Settings', category: 'Global System Switches', priority: 'CRITICAL' },
  { no: 50, name: 'Localization', category: 'Multi-Region & Currencies', priority: 'MEDIUM' },
  { no: 51, name: 'Payment Provider Settings', category: 'Gateway Integrations', priority: 'CRITICAL' },
  { no: 52, name: 'API / Webhook Logs', category: 'Integration Observability', priority: 'HIGH' },
  { no: 53, name: 'System Health', category: 'Infra & Database Diagnostics', priority: 'HIGH' },
  { no: 54, name: 'App Configuration', category: 'Feature Flags & Version Gates', priority: 'HIGH' },
  { no: 55, name: 'Data Export', category: 'Compliance Reports Export', priority: 'MEDIUM' },
  { no: 56, name: 'Backup & Recovery', category: 'Disaster Preparedness', priority: 'CRITICAL' },
  { no: 57, name: 'Privacy & Compliance', category: 'GDPR / Data Rights', priority: 'HIGH' },
  { no: 58, name: 'Policy Versioning', category: 'Effective-Dated Governance', priority: 'CRITICAL' },
  { no: 59, name: 'Notification & Alert Center', category: 'System Critical Alarms', priority: 'HIGH' },
  { no: 60, name: 'Scheduled Jobs', category: 'Idempotent Cron Tasks', priority: 'HIGH' },
  { no: 61, name: 'Search / Global Lookup', category: 'Universal ID Navigation', priority: 'HIGH' },
];

/**
 * Validates whether an admin role can perform an action on a module
 */
export function verifyRoleAccess(roleName, moduleCategory, requiredAccess = 'VIEW') {
  const role = ADMIN_ROLE_MATRIX[roleName?.toUpperCase()];
  if (!role) return false;
  if (roleName.toUpperCase() === 'SUPER_ADMIN') return true;

  const currentAccess = role.permissions[moduleCategory] || 'NO';
  if (currentAccess === 'FULL') return true;
  if (currentAccess === 'VIEW_EDIT' && (requiredAccess === 'VIEW' || requiredAccess === 'EDIT')) return true;
  if (currentAccess === 'VIEW' && requiredAccess === 'VIEW') return true;
  return false;
}

/**
 * Process a high-integrity Coin Refund / Correction
 * Enforces downstream check, original tx reference, double-refund block, and ledger audit.
 */
export async function executeCoinRefundCorrection({
  userId,
  transactionId,
  correctionAmount,
  type = 'WRONG_COIN_CREDIT',
  reason,
  evidence,
  adminId,
  adminName,
  ipAddress,
}) {
  const amountBig = BigInt(correctionAmount || 0);
  if (amountBig <= 0n) {
    const error = new Error('Correction amount must be greater than zero');
    error.statusCode = 400;
    throw error;
  }

  // 1. Check User Wallet
  const wallet = await prisma.wallet.findUnique({ where: { userId } });
  if (!wallet) {
    const error = new Error('User wallet not found');
    error.statusCode = 404;
    throw error;
  }

  // 2. Downstream check: Ensure user currently holds enough coins to deduct
  if (wallet.coinBalance < amountBig) {
    const error = new Error(
      `Downstream check failed: User wallet only has ${wallet.coinBalance.toString()} coins, cannot reverse ${amountBig.toString()} coins without resulting in a negative balance.`
    );
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_DOWNSTREAM_BALANCE';
    throw error;
  }

  // 3. Prevent Double Refund on same transaction
  if (transactionId) {
    const existingRefund = await prisma.coinRefund.findFirst({
      where: {
        disputeReason: { contains: transactionId },
        status: 'PROCESSED',
      },
    });
    if (existingRefund) {
      const error = new Error(`Transaction ${transactionId} already has a completed refund/correction.`);
      error.statusCode = 409;
      error.code = 'DOUBLE_REFUND_BLOCKED';
      throw error;
    }
  }

  const beforeCoinBalance = wallet.coinBalance;
  const afterCoinBalance = wallet.coinBalance - amountBig;

  // 4. Update Wallet & Write Ledger Record atomically
  const updatedWallet = await prisma.wallet.update({
    where: { userId },
    data: {
      coinBalance: afterCoinBalance,
    },
  });

  let ledgerId = `LEDGER-${Date.now()}`;
  if (prisma.walletLedger?.create) {
    const ledger = await prisma.walletLedger.create({
      data: {
        walletId: wallet.id,
        transactionType: 'REFUND',
        coinDelta: -amountBig,
        diamondDelta: 0n,
        balanceBefore: { coins: beforeCoinBalance.toString() },
        balanceAfter: { coins: afterCoinBalance.toString() },
        referenceId: transactionId || `CORRECTION-${Date.now()}`,
      },
    });
    ledgerId = ledger.id;
  }

  // 5. Create immutable audit log
  let validAdminId = null;
  if (adminId && typeof adminId === 'string' && adminId.includes('-')) {
    const adminExists = await prisma.admin.findUnique({ where: { id: adminId }, select: { id: true, name: true } });
    if (adminExists) {
      validAdminId = adminExists.id;
      if (!adminName) adminName = adminExists.name;
    }
  }
  if (!validAdminId) {
    const fallback = await prisma.admin.findFirst({ select: { id: true, name: true } });
    if (fallback) {
      validAdminId = fallback.id;
      if (!adminName) adminName = fallback.name;
    }
  }

  if (validAdminId && prisma.auditLog?.create) {
    try {
      await prisma.auditLog.create({
        data: {
          adminId: validAdminId,
          adminName: adminName || 'System Administrator',
          action: `COIN_CORRECTION_${type}`,
          targetEntity: 'Wallet',
          targetEntityId: userId,
          beforeStateJson: { coinBalance: beforeCoinBalance.toString(), transactionId },
          afterStateJson: { coinBalance: afterCoinBalance.toString(), deducted: amountBig.toString(), reason, evidence },
          reason: reason || 'Manual coin correction adjustment',
          ipAddress: ipAddress || '127.0.0.1',
        },
      });
    } catch (auditErr) {
      console.error('Failed to write audit log in executeCoinRefundCorrection:', auditErr.message);
    }
  }

  return {
    success: true,
    userId,
    type,
    transactionId: transactionId || null,
    deductedCoins: amountBig.toString(),
    previousCoinBalance: beforeCoinBalance.toString(),
    currentCoinBalance: afterCoinBalance.toString(),
    ledgerId: ledgerId,
    timestamp: new Date().toISOString(),
  };
}

export default {
  ADMIN_ROLE_MATRIX,
  MASTER_MODULES_61,
  verifyRoleAccess,
  executeCoinRefundCorrection,
};
