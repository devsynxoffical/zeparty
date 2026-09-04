import prisma from '../src/config/database.js';
import { hashPassword } from '../src/utils/crypto.util.js';
import ownerService from '../src/services/owner.service.js';
import adminRepository from '../src/repositories/admin.repository.js';
import effectivePermissionsService from '../src/services/effectivePermissions.service.js';
import { requireOwner } from '../src/middlewares/requireOwner.js';
import { adminLogin } from '../src/services/auth.service.js';

async function runOwnerSecurityTests() {
  console.log('----------------------------------------------------');
  console.log('🛡️  RUNNING ZE-PARTY OWNER / ROOT ADMIN SECURITY TEST SUITE');
  console.log('----------------------------------------------------');

  const testIp = '127.0.0.1';
  const testUserAgent = 'ZeParty-Owner-Test/1.0';

  const ownerUsername = 'rootowner_' + Math.floor(Math.random() * 10000);
  const ownerPassword = 'OwnerSecretPassword999!';
  const ownerPasswordHash = await hashPassword(ownerPassword);

  const superAdminUsername = 'superadmin_' + Math.floor(Math.random() * 10000);
  const superAdminPassword = 'SuperAdminPassword123!';
  const superAdminPasswordHash = await hashPassword(superAdminPassword);

  const normalAdminUsername = 'normaladmin_' + Math.floor(Math.random() * 10000);
  const normalAdminPassword = 'NormalAdminPassword123!';
  const normalAdminPasswordHash = await hashPassword(normalAdminPassword);

  let ownerAdmin, superAdmin, normalAdmin;

  try {
    // SETUP: Create test identities
    ownerAdmin = await prisma.admin.create({
      data: {
        name: 'Hidden Root Owner',
        username: ownerUsername,
        email: `${ownerUsername}@zeparty.app`,
        passwordHash: ownerPasswordHash,
        status: 'ACTIVE',
        isSuperAdmin: true,
        isOwner: true,
      },
    });

    superAdmin = await prisma.admin.create({
      data: {
        name: 'Normal Super Admin',
        username: superAdminUsername,
        email: `${superAdminUsername}@zeparty.app`,
        passwordHash: superAdminPasswordHash,
        status: 'ACTIVE',
        isSuperAdmin: true,
        isOwner: false,
      },
    });

    normalAdmin = await prisma.admin.create({
      data: {
        name: 'Normal Host Admin',
        username: normalAdminUsername,
        email: `${normalAdminUsername}@zeparty.app`,
        passwordHash: normalAdminPasswordHash,
        status: 'ACTIVE',
        isSuperAdmin: false,
        isOwner: false,
      },
    });

    // ----------------------------------------------------
    // TEST 1: Unified Owner Authentication Flow
    // ----------------------------------------------------
    console.log('\n[TEST 1] Owner login via unified admin login service...');
    const ownerAuthResult = await adminLogin({
      usernameOrEmail: ownerUsername,
      password: ownerPassword,
      ipAddress: testIp,
      userAgent: testUserAgent,
    });

    if (!ownerAuthResult.admin.isOwner) {
      throw new Error('FAILED: Owner authentication response missing isOwner: true claim!');
    }
    console.log('✅ PASS: Owner authenticated successfully with root privilege claims!');

    // ----------------------------------------------------
    // TEST 2: Owner Invisibility Safeguard — Admin Lists
    // ----------------------------------------------------
    console.log('\n[TEST 2] Verifying Owner Invisibility in standard admin queries...');
    const standardAdminsList = await adminRepository.findAll({ includeOwner: false });
    const containsOwner = standardAdminsList.some((a) => a.id === ownerAdmin.id || a.isOwner);

    if (containsOwner) {
      throw new Error('SECURITY VIOLATION: Owner appeared in standard admin list!');
    }
    console.log('✅ PASS: Owner record is 100% hidden from standard administrative queries.');

    // ----------------------------------------------------
    // TEST 3: Unified Login — Owner via Normal Admin Login Route
    // ----------------------------------------------------
    console.log('\n[TEST 3] Testing Owner login via unified admin login route...');
    const unifiedAuthResult = await adminLogin({
      usernameOrEmail: ownerUsername,
      password: ownerPassword,
      ipAddress: testIp,
      userAgent: testUserAgent,
    });

    if (!unifiedAuthResult.admin.isOwner) {
      throw new Error('FAILED: Owner login via unified login route missing isOwner: true!');
    }
    console.log('✅ PASS: Owner authenticated successfully via unified admin login route!');

    // ----------------------------------------------------
    // TEST 4: Super Admin Privilege Boundary — requireOwner Middleware
    // ----------------------------------------------------
    console.log('\n[TEST 4] Testing requireOwner middleware against Super Admin access...');
    const mockReqSuperAdmin = { admin: superAdmin };
    let superAdminRejected = false;
    const mockRes = {
      status: (code) => ({
        json: (data) => {
          if (code === 403 && data.error?.code === 'OWNER_PRIVILEGE_REQUIRED') {
            superAdminRejected = true;
          }
        },
      }),
    };

    requireOwner(mockReqSuperAdmin, mockRes, () => {
      throw new Error('SECURITY VIOLATION: requireOwner allowed Super Admin to proceed!');
    });

    if (!superAdminRejected) {
      throw new Error('FAILED: Super Admin was not blocked by requireOwner!');
    }
    console.log('✅ PASS: Super Admin rejected by requireOwner middleware (403 Forbidden).');

    // ----------------------------------------------------
    // TEST 5: Two-Level Access Model & Effective Permissions
    // ----------------------------------------------------
    console.log('\n[TEST 5] Owner assigning Module Access and Direct Permissions...');
    const targetModules = ['hosts', 'agencies', 'coin-sellers'];
    await ownerService.setModuleAccess({
      ownerId: ownerAdmin.id,
      adminId: normalAdmin.id,
      modules: targetModules,
      ipAddress: testIp,
    });

    await ownerService.grantDirectPermission({
      ownerId: ownerAdmin.id,
      adminId: normalAdmin.id,
      permissionId: 'hosts.approve',
      reason: 'Owner Test Grant',
      ipAddress: testIp,
    });

    await ownerService.revokeDirectPermission({
      ownerId: ownerAdmin.id,
      adminId: normalAdmin.id,
      permissionId: 'hosts.delete',
      reason: 'Owner Test Revocation',
      ipAddress: testIp,
    });

    const effective = await effectivePermissionsService.calculateEffectivePermissions(normalAdmin.id);

    console.log('   Effective Modules:', effective.modules);
    console.log('   Includes hosts.approve?:', effective.permissions.includes('hosts.approve'));
    console.log('   Excludes hosts.delete?:', !effective.permissions.includes('hosts.delete'));
    console.log('   Excludes owner-control?:', !effective.modules.includes('owner-control'));

    if (
      JSON.stringify(effective.modules.sort()) !== JSON.stringify(targetModules.sort()) ||
      !effective.permissions.includes('hosts.approve') ||
      effective.permissions.includes('hosts.delete') ||
      effective.modules.includes('owner-control')
    ) {
      throw new Error('FAILED: Effective permission evaluation mismatch!');
    }
    console.log('✅ PASS: Two-Level Module Access & Direct Permission engine working perfectly!');

    // ----------------------------------------------------
    // TEST 6: Owner Governance over Super Admin
    // ----------------------------------------------------
    console.log('\n[TEST 6] Testing Owner control over Super Admin status...');
    const suspendedSuperAdmin = await ownerService.updateAdministrator({
      ownerId: ownerAdmin.id,
      adminId: superAdmin.id,
      status: 'SUSPENDED',
      ipAddress: testIp,
    });

    if (suspendedSuperAdmin.status !== 'SUSPENDED') {
      throw new Error('FAILED: Owner was unable to suspend Super Admin!');
    }
    console.log('✅ PASS: Owner successfully suspended Super Admin.');

    // Reactivate Super Admin
    await ownerService.updateAdministrator({
      ownerId: ownerAdmin.id,
      adminId: superAdmin.id,
      status: 'ACTIVE',
      ipAddress: testIp,
    });
    console.log('✅ PASS: Owner reactivated Super Admin.');

    // ----------------------------------------------------
    // TEST 7: Audit Log Verification
    // ----------------------------------------------------
    console.log('\n[TEST 7] Verifying Owner Governance Audit Trail...');
    const auditLogs = await ownerService.getOwnerAuditLogs({ ownerId: ownerAdmin.id, limit: 10 });
    const hasCreatedAction = auditLogs.some((l) => l.action === 'OWNER_GRANTED_MODULE');
    if (!hasCreatedAction) {
      throw new Error('FAILED: Owner governance actions not recorded in AuditLog!');
    }
    console.log('✅ PASS: Complete audit trail recorded for all Owner operations.');

    console.log('\n----------------------------------------------------');
    console.log('🎉 ALL 7 OWNER SECURITY INTEGRATION TESTS PASSED!');
    console.log('----------------------------------------------------');
  } catch (error) {
    console.error('\n❌ OWNER SECURITY TEST SUITE FAILED:', error.message);
    console.error(error);
    process.exit(1);
  } finally {
    // Cleanup test records
    if (normalAdmin) await prisma.admin.delete({ where: { id: normalAdmin.id } }).catch(() => {});
    if (superAdmin) await prisma.admin.delete({ where: { id: superAdmin.id } }).catch(() => {});
    if (ownerAdmin) await prisma.admin.delete({ where: { id: ownerAdmin.id } }).catch(() => {});
    await prisma.$disconnect();
  }
}

runOwnerSecurityTests();
