import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

import { MODULE_PERMISSIONS, DEFAULT_ROLES } from '../src/constants/permissions.js';

async function seed() {
  console.log('🌱 Starting ZeParty Database Seeding...');

  // 1. Seed Permissions
  for (const moduleGroup of MODULE_PERMISSIONS) {
    for (const perm of moduleGroup.permissions) {
      await prisma.permission.upsert({
        where: { id: perm.id },
        update: {
          label: perm.label,
          module: moduleGroup.module,
        },
        create: {
          id: perm.id,
          label: perm.label,
          module: moduleGroup.module,
        },
      });
    }
  }

  // 2. Seed Default Roles
  for (const roleDef of DEFAULT_ROLES) {
    const role = await prisma.role.upsert({
      where: { id: roleDef.id },
      update: {
        name: roleDef.name,
        description: roleDef.description,
        isSystemRole: roleDef.isSystemRole,
      },
      create: {
        id: roleDef.id,
        name: roleDef.name,
        description: roleDef.description,
        isSystemRole: roleDef.isSystemRole,
      },
    });

    for (const permId of roleDef.permissions) {
      await prisma.rolePermission.upsert({
        where: {
          roleId_permissionId: {
            roleId: role.id,
            permissionId: permId,
          },
        },
        update: {},
        create: {
          roleId: role.id,
          permissionId: permId,
        },
      });
    }
  }

  const ownerEmail = process.env.OWNER_EMAIL || 'owner@zeparty.app';
  const ownerPassword = process.env.OWNER_PASSWORD || 'admin123';
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';

  const adminPasswordHash = await bcrypt.hash(adminPassword, 10);
  const ownerPasswordHash = await bcrypt.hash(ownerPassword, 10);

  // 3. Seed Default Admin & Super Admin Accounts
  await prisma.admin.upsert({
    where: { username: 'admin' },
    update: {
      passwordHash: adminPasswordHash,
      isSuperAdmin: true,
      isOwner: false,
      roleId: 'super_admin',
    },
    create: {
      id: 'dev-admin-main-001',
      name: 'Admin',
      username: 'admin',
      email: 'admin@zeparty.app',
      passwordHash: adminPasswordHash,
      status: 'ACTIVE',
      isSuperAdmin: true,
      isOwner: false,
      roleId: 'super_admin',
    },
  });

  await prisma.admin.upsert({
    where: { username: 'superadmin' },
    update: {
      passwordHash: adminPasswordHash,
      isSuperAdmin: true,
      isOwner: false,
      roleId: 'super_admin',
    },
    create: {
      id: 'dev-admin-001',
      name: 'Super Admin',
      username: 'superadmin',
      email: 'superadmin@zeparty.app',
      passwordHash: adminPasswordHash,
      status: 'ACTIVE',
      isSuperAdmin: true,
      isOwner: false,
      roleId: 'super_admin',
    },
  });

  // 4. Seed Default Owner Account
  await prisma.admin.upsert({
    where: { username: 'owner' },
    update: {
      email: ownerEmail,
      passwordHash: ownerPasswordHash,
      isSuperAdmin: true,
      isOwner: true,
    },
    create: {
      id: 'dev-owner-001',
      name: 'Root Owner',
      username: 'owner',
      email: ownerEmail,
      passwordHash: ownerPasswordHash,
      status: 'ACTIVE',
      isSuperAdmin: true,
      isOwner: true,
    },
  });

  const financeAdminPasswordHash = await bcrypt.hash('FinanceadminSecret123!', 10);
  const hostAdminPasswordHash = await bcrypt.hash('HostadminSecret123!', 10);
  const restrictedAdminPasswordHash = await bcrypt.hash('RestrictedadminSecret123!', 10);

  // 5. Seed Finance Admin Account
  const financeAdmin = await prisma.admin.upsert({
    where: { username: 'financeadmin' },
    update: {
      passwordHash: financeAdminPasswordHash,
      roleId: 'finance_admin',
    },
    create: {
      id: 'dev-finance-001',
      name: 'Finance Admin',
      username: 'financeadmin',
      email: 'financeadmin@zeparty.app',
      passwordHash: financeAdminPasswordHash,
      status: 'ACTIVE',
      isSuperAdmin: false,
      isOwner: false,
      roleId: 'finance_admin',
    },
  });

  const financeModules = [
    'recharge-plans', 'online-recharge', 'offline-recharge',
    'withdrawals', 'transactions', 'finance', 'coin-refunds',
    'reseller-corrections', 'refund-requests', 'chargebacks', 'risk'
  ];
  await prisma.adminModuleAccess.deleteMany({ where: { adminId: financeAdmin.id } });
  await prisma.adminModuleAccess.createMany({
    data: financeModules.map(m => ({ adminId: financeAdmin.id, module: m, grantedBy: 'dev-owner-001' }))
  });

  // 6. Seed Host Admin Account
  const hostAdmin = await prisma.admin.upsert({
    where: { username: 'hostadmin' },
    update: {
      passwordHash: hostAdminPasswordHash,
      roleId: 'host_admin',
    },
    create: {
      id: 'dev-host-001',
      name: 'Host Admin',
      username: 'hostadmin',
      email: 'hostadmin@zeparty.app',
      passwordHash: hostAdminPasswordHash,
      status: 'ACTIVE',
      isSuperAdmin: false,
      isOwner: false,
      roleId: 'host_admin',
    },
  });
  await prisma.adminModuleAccess.deleteMany({ where: { adminId: hostAdmin.id } });
  await prisma.adminModuleAccess.createMany({
    data: ['hosts', 'agencies', 'bd-centers'].map(m => ({ adminId: hostAdmin.id, module: m, grantedBy: 'dev-owner-001' }))
  });

  // 7. Seed Restricted Admin Account (Hosts, Agencies, Resellers ONLY)
  const restrictedAdmin = await prisma.admin.upsert({
    where: { username: 'restrictedadmin' },
    update: {
      passwordHash: restrictedAdminPasswordHash,
      roleId: 'host_admin',
    },
    create: {
      id: 'dev-restricted-001',
      name: 'Restricted Admin',
      username: 'restrictedadmin',
      email: 'restrictedadmin@zeparty.app',
      passwordHash: restrictedAdminPasswordHash,
      status: 'ACTIVE',
      isSuperAdmin: false,
      isOwner: false,
      roleId: 'host_admin',
    },
  });
  await prisma.adminModuleAccess.deleteMany({ where: { adminId: restrictedAdmin.id } });
  await prisma.adminModuleAccess.createMany({
    data: ['hosts', 'agencies', 'coin-sellers'].map(m => ({ adminId: restrictedAdmin.id, module: m, grantedBy: 'dev-owner-001' }))
  });

  // 8. Seed Baseline Phase 7 Policies & Versions
  const { BASELINE_POLICY_TEMPLATES, BASELINE_CONFIG_VALUES } = await import('../src/constants/policyDefaults.js');

  for (const [pType, template] of Object.entries(BASELINE_POLICY_TEMPLATES)) {
    const policy = await prisma.policy.upsert({
      where: { policyType: pType },
      update: {
        description: template.description,
      },
      create: {
        policyType: pType,
        version: template.version,
        description: template.description,
      },
    });

    const existingVersion = await prisma.policyVersion.findFirst({
      where: {
        policyId: policy.id,
        version: template.version,
      },
    });

    if (!existingVersion) {
      await prisma.policyVersion.create({
        data: {
          policyId: policy.id,
          version: template.version,
          summary: `Baseline ${pType} policy release`,
          configJson: template.config,
          approvedBy: 'Root Owner',
        },
      });
    }
  }

  // 9. Seed Baseline Phase 7 Economy Configurations
  for (const [cfgKey, cfgVal] of Object.entries(BASELINE_CONFIG_VALUES)) {
    await prisma.policyConfiguration.upsert({
      where: { key: cfgKey },
      update: {}, // Preserve existing admin modifications
      create: {
        key: cfgKey,
        valueJson: cfgVal,
        status: 'ACTIVE',
      },
    });
  }

  // 10. Seed Baseline Phase 8 Host Level Configurations
  const liveTiers = BASELINE_POLICY_TEMPLATES.LIVE_HOST.config.tiers;
  for (const tier of liveTiers) {
    await prisma.hostLevelConfig.upsert({
      where: {
        level_hostType: {
          level: tier.level,
          hostType: 'LIVE_HOST',
        },
      },
      update: {
        targetDiamonds: BigInt(tier.targetDiamonds),
        basicSalaryUSD: tier.basicSalaryUSD,
        dailyHoursRequired: 1.0,
        daysRequiredPerMonth: tier.durationDays || 10,
      },
      create: {
        level: tier.level,
        hostType: 'LIVE_HOST',
        targetDiamonds: BigInt(tier.targetDiamonds),
        basicSalaryUSD: tier.basicSalaryUSD,
        dailyHoursRequired: 1.0,
        daysRequiredPerMonth: tier.durationDays || 10,
      },
    });
  }

  // 11. Seed Baseline Sample BD Center, Agency, Reseller & Merchant
  // Ensure default dev user exists for relations
  const devUser = await prisma.user.upsert({
    where: { phone: '+10000000001' },
    update: {},
    create: {
      id: 'dev-user-001',
      phone: '+10000000001',
      username: 'dev_platform_user',
      email: 'dev_user@zeparty.app',
      userType: 'USER',
      userStatus: 'ACTIVE',
    },
  });

  const devBDCenter = await prisma.bDCenter.upsert({
    where: { id: 'dev-bdc-001' },
    update: {},
    create: {
      id: 'dev-bdc-001',
      centerName: 'Asia Pacific BD Center',
      regionCode: 'US',
      managerUserId: devUser.id,
      currentTier: 'BRONZE',
      baseSalaryUSD: 500.00,
    },
  });

  await prisma.agency.upsert({
    where: { agencyCode: 'STAR-01' },
    update: {},
    create: {
      id: 'dev-agency-001',
      agencyName: 'StarMedia Entertainment',
      agencyCode: 'STAR-01',
      agencyType: 'LIVE_AGENCY',
      ownerUserId: devUser.id,
      bdCenterId: devBDCenter.id,
      commissionRate: 20.0,
      status: 'ACTIVE',
    },
  });

  await prisma.coinSeller.upsert({
    where: { userId: devUser.id },
    update: {},
    create: {
      id: 'dev-seller-001',
      userId: devUser.id,
      businessName: 'Global Pay Solutions',
      profitMarginPercent: 10.0,
      creditLimitUSD: 1000.00,
      sellerStatus: 'ACTIVE',
      resellerBalanceCoins: 0n,
    },
  });

  // 12. Seed Baseline Phase 9 Virtual Gifts
  const baselineGifts = [
    { id: 'gift-rose-01', name: 'Rose', coinValue: 10n, giftCategory: 'POPULAR', iconUrl: 'https://cdn.zeparty.app/gifts/rose.png', isAnimated: false, isFullScreen: false },
    { id: 'gift-heart-02', name: 'Love Heart', coinValue: 50n, giftCategory: 'POPULAR', iconUrl: 'https://cdn.zeparty.app/gifts/heart.png', isAnimated: false, isFullScreen: false },
    { id: 'gift-car-03', name: 'Sports Car', coinValue: 500n, giftCategory: 'LUXURY', iconUrl: 'https://cdn.zeparty.app/gifts/car.png', svgaAssetUrl: 'https://cdn.zeparty.app/svga/sports_car.svga', isAnimated: true, isFullScreen: true },
    { id: 'gift-jet-04', name: 'Private Jet', coinValue: 2000n, giftCategory: 'LUXURY', iconUrl: 'https://cdn.zeparty.app/gifts/jet.png', svgaAssetUrl: 'https://cdn.zeparty.app/svga/private_jet.svga', isAnimated: true, isFullScreen: true },
    { id: 'gift-crown-05', name: 'Golden Crown', coinValue: 1000n, giftCategory: 'VIP', iconUrl: 'https://cdn.zeparty.app/gifts/crown.png', svgaAssetUrl: 'https://cdn.zeparty.app/svga/golden_crown.svga', isAnimated: true, isFullScreen: false },
    { id: 'gift-castle-06', name: 'Castle', coinValue: 5000n, giftCategory: 'VIP', iconUrl: 'https://cdn.zeparty.app/gifts/castle.png', svgaAssetUrl: 'https://cdn.zeparty.app/svga/castle.svga', isAnimated: true, isFullScreen: true },
    { id: 'gift-firework-07', name: 'Firework', coinValue: 300n, giftCategory: 'POPULAR', iconUrl: 'https://cdn.zeparty.app/gifts/firework.png', svgaAssetUrl: 'https://cdn.zeparty.app/svga/firework.svga', isAnimated: true, isFullScreen: false },
    { id: 'gift-wand-08', name: 'Magic Wand', coinValue: 150n, giftCategory: 'AUDIO', iconUrl: 'https://cdn.zeparty.app/gifts/wand.png', isAnimated: false, isFullScreen: false },
  ];

  for (const g of baselineGifts) {
    await prisma.gift.upsert({
      where: { id: g.id },
      update: {},
      create: {
        id: g.id,
        name: g.name,
        coinValue: g.coinValue,
        giftCategory: g.giftCategory,
        iconUrl: g.iconUrl,
        svgaAssetUrl: g.svgaAssetUrl || null,
        isAnimated: g.isAnimated,
        isFullScreen: g.isFullScreen,
        platformCutPercent: 45.0,
        hostCutPercent: 35.0,
        agencyCutPercent: 12.0,
        roomCutPercent: 8.0,
        isActive: true,
      },
    });
  }

  // 13. Seed Baseline Phase 9 Store Dynamic Assets
  const baselineAssets = [
    { id: 'ast-car-01', name: 'Golden Sports Car', assetType: 'VEHICLE', assetSubcategory: 'ANIMATED_SVGA', priceCoins: 500000n, validDays: 30, thumbnailUrl: 'https://cdn.zeparty.app/assets/cars/car_gold.png', animationFileUrl: 'https://cdn.zeparty.app/svga/car_gold.svga', isVipExclusive: true, minVipLevelRequired: 3 },
    { id: 'ast-car-02', name: 'Luxury SUV', assetType: 'VEHICLE', assetSubcategory: 'STATIC', priceCoins: 400000n, validDays: 30, thumbnailUrl: 'https://cdn.zeparty.app/assets/cars/suv_black.png', isVipExclusive: false, minVipLevelRequired: 0 },
    { id: 'ast-frame-01', name: 'Golden Warrior Frame', assetType: 'FRAME', assetSubcategory: 'STATIC', priceCoins: 300000n, validDays: 15, thumbnailUrl: 'https://cdn.zeparty.app/assets/frames/warrior.png', isVipExclusive: false, minVipLevelRequired: 0 },
    { id: 'ast-frame-02', name: 'Spider Hero Frame', assetType: 'FRAME', assetSubcategory: 'STATIC', priceCoins: 400000n, validDays: 15, thumbnailUrl: 'https://cdn.zeparty.app/assets/frames/spider.png', isVipExclusive: false, minVipLevelRequired: 0 },
    { id: 'ast-bubble-01', name: 'Unicorn Dream Bubble', assetType: 'CHAT_BUBBLE', assetSubcategory: 'STATIC', priceCoins: 250000n, validDays: 30, thumbnailUrl: 'https://cdn.zeparty.app/assets/bubbles/unicorn.png', isVipExclusive: false, minVipLevelRequired: 0 },
  ];

  for (const a of baselineAssets) {
    await prisma.asset.upsert({
      where: { id: a.id },
      update: {},
      create: {
        id: a.id,
        name: a.name,
        assetType: a.assetType,
        assetSubcategory: a.assetSubcategory,
        priceCoins: a.priceCoins,
        validDays: a.validDays,
        thumbnailUrl: a.thumbnailUrl,
        animationFileUrl: a.animationFileUrl || null,
        roomAvailability: 'BOTH',
        isVipExclusive: a.isVipExclusive,
        minVipLevelRequired: a.minVipLevelRequired,
        isActive: true,
      },
    });
  }

  console.log('✅ Seeding completed! Super Admin, Owner, Roles, Permissions, Baseline Policies, Configurations, Host Configs, Agencies, BD Centers, Resellers, Gifts & Store Assets seeded.');
}

seed()
  .catch((e) => {
    console.error('❌ Seeding error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
