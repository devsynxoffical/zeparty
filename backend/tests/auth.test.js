import { requestOtp, verifyOtpAndAuthenticate, refreshToken, logout, getCurrentUser, adminLogin } from '../src/services/auth.service.js';
import tokenService from '../src/services/token.service.js';
import prisma from '../src/config/database.js';
import { hashPassword } from '../src/utils/crypto.util.js';

async function runAuthTests() {
  console.log('----------------------------------------------------');
  console.log('🧪 RUNNING ZE-PARTY PHASE 3 AUTHENTICATION TEST SUITE');
  console.log('----------------------------------------------------');

  const testPhone = '+15550199' + Math.floor(1000 + Math.random() * 9000);
  const testIp = '127.0.0.1';
  const testUserAgent = 'ZeParty-Test-Runner/1.0';

  try {
    // ----------------------------------------------------
    // TEST 1: Request OTP
    // ----------------------------------------------------
    console.log('\n[TEST 1] Requesting OTP for phone:', testPhone);
    const reqOtpResult = await requestOtp({
      phone: testPhone,
      purpose: 'LOGIN',
      ipAddress: testIp,
    });
    console.log('✅ OTP Requested successfully. Expiration:', reqOtpResult.expiresInSeconds, 's');
    const devOtp = reqOtpResult.devOtp;
    if (!devOtp) {
      throw new Error('Dev OTP code was not returned in mock test mode.');
    }
    console.log('🔑 Mock Dev OTP Code Received:', devOtp);

    // ----------------------------------------------------
    // TEST 2: Verify OTP & User Auto-Creation
    // ----------------------------------------------------
    console.log('\n[TEST 2] Verifying OTP and authenticating...');
    const authResult = await verifyOtpAndAuthenticate({
      phone: testPhone,
      code: devOtp,
      purpose: 'LOGIN',
      device: {
        deviceToken: 'test-device-token-abc-123',
        platform: 'ANDROID',
        deviceModel: 'Pixel 8 Pro',
        appVersion: '1.0.0',
      },
      ipAddress: testIp,
      userAgent: testUserAgent,
    });

    console.log('✅ User Authenticated!');
    console.log('   New User?:', authResult.isNewUser);
    console.log('   User ID:', authResult.user.id);
    console.log('   Phone:', authResult.user.phone);
    console.log('   Username:', authResult.user.username);
    console.log('   Wallet Coin Balance:', authResult.user.wallet?.coinBalance);
    console.log('   Access Token (JWT) Length:', authResult.accessToken.length);
    console.log('   Refresh Token Length:', authResult.refreshToken.length);

    const initialAccessToken = authResult.accessToken;
    const initialRefreshToken = authResult.refreshToken;

    // ----------------------------------------------------
    // TEST 3: Access Token Claims & Verification
    // ----------------------------------------------------
    console.log('\n[TEST 3] Verifying JWT Access Token claims...');
    const decoded = tokenService.verifyAccessToken(initialAccessToken);
    console.log('✅ JWT claims valid!');
    console.log('   Subject (User ID):', decoded.sub);
    console.log('   Session ID:', decoded.sessionId);
    console.log('   User Type:', decoded.userType);

    // ----------------------------------------------------
    // TEST 4: Get Current User Identity (/me endpoint logic)
    // ----------------------------------------------------
    console.log('\n[TEST 4] Retrieving Current User details (/me)...');
    const currentUser = await getCurrentUser({ userId: decoded.sub });
    console.log('✅ Current user fetched! Username:', currentUser.username, 'Level:', currentUser.profile?.level);

    // ----------------------------------------------------
    // TEST 5: Refresh Token Rotation
    // ----------------------------------------------------
    console.log('\n[TEST 5] Testing Refresh Token Rotation...');
    const refreshResult = await refreshToken({
      refreshToken: initialRefreshToken,
      ipAddress: testIp,
      userAgent: testUserAgent,
    });

    console.log('✅ Refresh Token rotated successfully!');
    console.log('   New Access Token Length:', refreshResult.accessToken.length);
    console.log('   New Refresh Token Length:', refreshResult.refreshToken.length);

    // ----------------------------------------------------
    // TEST 6: Replay Attack Defense (Old Refresh Token Reuse)
    // ----------------------------------------------------
    console.log('\n[TEST 6] Testing Replay Attack Defense with rotated old refresh token...');
    try {
      await refreshToken({
        refreshToken: initialRefreshToken,
        ipAddress: testIp,
        userAgent: testUserAgent,
      });
      throw new Error('FAILED: Old refresh token should have been rejected!');
    } catch (err) {
      if (err.code === 'TOKEN_INVALID' || err.code === 'SESSION_REVOKED') {
        console.log('✅ PASS: Reused old refresh token rejected with error code:', err.code);
      } else {
        throw err;
      }
    }

    // ----------------------------------------------------
    // TEST 7: Session Revocation / Logout
    // ----------------------------------------------------
    console.log('\n[TEST 7] Testing Logout & Session Revocation...');
    await logout({ sessionId: decoded.sessionId });
    console.log('✅ Session revoked via logout.');

    try {
      await refreshToken({
        refreshToken: refreshResult.refreshToken,
        ipAddress: testIp,
        userAgent: testUserAgent,
      });
      throw new Error('FAILED: Revoked session should not be allowed to refresh!');
    } catch (err) {
      if (err.code === 'SESSION_REVOKED') {
        console.log('✅ PASS: Revoked session refresh attempt rejected with SESSION_REVOKED');
      } else {
        throw err;
      }
    }

    // ----------------------------------------------------
    // TEST 8: Admin Authentication Flow
    // ----------------------------------------------------
    console.log('\n[TEST 8] Testing Admin Login Flow...');
    const testAdminUsername = 'testadmin_' + Math.floor(Math.random() * 10000);
    const testAdminPassword = 'SuperSecretAdminPassword123!';
    const passwordHash = await hashPassword(testAdminPassword);

    const testAdmin = await prisma.admin.create({
      data: {
        name: 'Test Administrator',
        username: testAdminUsername,
        email: `${testAdminUsername}@zeparty.app`,
        passwordHash,
        status: 'ACTIVE',
        isSuperAdmin: true,
      },
    });

    const adminAuth = await adminLogin({
      usernameOrEmail: testAdminUsername,
      password: testAdminPassword,
      ipAddress: testIp,
      userAgent: testUserAgent,
    });

    console.log('✅ Admin Login Successful!');
    console.log('   Admin Name:', adminAuth.admin.name);
    console.log('   Is SuperAdmin?:', adminAuth.admin.isSuperAdmin);
    console.log('   Admin Access Token Length:', adminAuth.accessToken.length);

    // Clean up test admin
    await prisma.admin.delete({ where: { id: testAdmin.id } });

    console.log('\n----------------------------------------------------');
    console.log('🎉 ALL 8 AUTHENTICATION INTEGRATION TESTS PASSED!');
    console.log('----------------------------------------------------');
  } catch (error) {
    console.error('\n❌ AUTH TEST SUITE FAILED:', error.message);
    console.error(error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

runAuthTests();
