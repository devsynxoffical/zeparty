import tokenService from '../services/token.service.js';
import sessionRepository from '../repositories/session.repository.js';
import userRepository from '../repositories/user.repository.js';
import adminRepository from '../repositories/admin.repository.js';

export async function authenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Authentication token missing or invalid format',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Authentication token missing',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    // Verify JWT access token strictly against secret and claims
    let decoded = null;
    try {
      decoded = tokenService.verifyAccessToken(token);
    } catch (jwtErr) {
      if (jwtErr.name === 'TokenExpiredError' || jwtErr.code === 'TOKEN_EXPIRED') {
        return res.status(401).json({
          success: false,
          message: 'Access token has expired',
          error: { code: 'TOKEN_EXPIRED' },
        });
      }
      return res.status(401).json({
        success: false,
        message: jwtErr.message || 'Invalid or expired authentication token',
        error: { code: jwtErr.code || 'TOKEN_INVALID' },
      });
    }

    const subIdentifier = decoded.sub || decoded.userId || decoded.adminId;
    if (!subIdentifier) {
      return res.status(401).json({
        success: false,
        message: 'Token subject identifier missing',
        error: { code: 'TOKEN_INVALID' },
      });
    }

    // Determine target route domain and token domain
    const isAdminRoute = Boolean(
      req.baseUrl?.includes('admin') ||
      req.originalUrl?.includes('/admin') ||
      req.path?.includes('admin')
    );

    const isTokenAdmin = Boolean(
      decoded.isAdmin === true ||
      decoded.userType === 'ADMIN' ||
      decoded.aud === 'zeparty-admin'
    );

    // Purpose & Audience Separation Enforcement:
    // 1. Mobile user tokens cannot access admin endpoints
    if (isAdminRoute && !isTokenAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: administrative privileges required',
        error: { code: 'FORBIDDEN' },
      });
    }

    // 2. Admin tokens cannot access mobile user-only endpoints
    const isAuthEndpoint = Boolean(
      req.baseUrl?.includes('auth') ||
      req.originalUrl?.includes('/auth/me') ||
      req.originalUrl?.includes('/auth/logout')
    );

    if (!isAdminRoute && !isAuthEndpoint && isTokenAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Admin accounts cannot access mobile user endpoints',
        error: { code: 'FORBIDDEN' },
      });
    }

    // 3. Reject mismatched audience claims
    if (decoded.aud) {
      if (decoded.aud === 'zeparty-admin' && !isTokenAdmin) {
        return res.status(401).json({
          success: false,
          message: 'Token audience does not match account privileges',
          error: { code: 'TOKEN_INVALID' },
        });
      }
      if (decoded.aud === 'zeparty-mobile' && isTokenAdmin) {
        return res.status(401).json({
          success: false,
          message: 'Token audience does not match account privileges',
          error: { code: 'TOKEN_INVALID' },
        });
      }
    }

    // ==========================================
    // RESOLUTION A: Administrative Identity
    // ==========================================
    if (isTokenAdmin) {
      let admin = await adminRepository.findById(subIdentifier);
      if (!admin && typeof subIdentifier === 'string') {
        admin = await adminRepository.findByUsernameOrEmail(subIdentifier);
      }

      // Security requirement: NEVER use { isOwner: true } or synthetic dev-owner fallback!
      if (!admin) {
        return res.status(401).json({
          success: false,
          message: 'Administrative account not found',
          error: { code: 'UNAUTHORIZED' },
        });
      }

      if (admin.status !== 'ACTIVE') {
        return res.status(403).json({
          success: false,
          message: 'Admin account is inactive or suspended',
          error: { code: 'ACCOUNT_SUSPENDED' },
        });
      }

      req.admin = admin;
      req.auth = {
        userId: admin.id,
        sessionId: decoded.sessionId || 'admin_session',
        userType: 'ADMIN',
        isAdmin: true,
        isOwner: Boolean(admin.isOwner),
        isSuperAdmin: Boolean(admin.isSuperAdmin || admin.isOwner),
        roleId: admin.roleId || (admin.isOwner ? 'owner' : 'super_admin'),
        audience: decoded.aud || 'zeparty-admin',
      };
      req.session = { id: decoded.sessionId || 'admin_session', userId: admin.id };
      return next();
    }

    // ==========================================
    // RESOLUTION B: Mobile User Identity
    // ==========================================
    let user = null;
    if (/^[1-9]\d{6}$/.test(String(subIdentifier))) {
      user = await userRepository.findById(String(subIdentifier));
    } else if (typeof subIdentifier === 'string' && subIdentifier.includes('@')) {
      user = await userRepository.findByEmail(subIdentifier.trim().toLowerCase());
    } else {
      user = await userRepository.findById(String(subIdentifier));
      if (!user && typeof subIdentifier === 'string' && !subIdentifier.startsWith('google_') && !subIdentifier.startsWith('user_')) {
        user = await userRepository.findByUsername(subIdentifier);
      }
    }

    // Reject nonexistent accounts or synthetic shadow user records
    if (!user || user.userType === 'ADMIN' || user.username?.startsWith('admin_shadow') || user.id?.startsWith('dev-admin')) {
      return res.status(401).json({
        success: false,
        message: 'Authenticated user account not found',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    if (user.status !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: `Account is ${user.status.toLowerCase()}`,
        error: { code: user.status === 'SUSPENDED' ? 'ACCOUNT_SUSPENDED' : 'ACCOUNT_BANNED' },
      });
    }

    req.user = user;
    req.auth = {
      userId: user.id,
      sessionId: decoded.sessionId || 'active_session',
      userType: user.userType || 'USER',
      isAdmin: false,
      audience: decoded.aud || 'zeparty-mobile',
    };
    req.session = { id: decoded.sessionId || 'active_session', userId: user.id };

    return next();
  } catch (err) {
    if (err.status) {
      return res.status(err.status).json({
        success: false,
        message: err.message,
        error: { code: err.code || 'UNAUTHORIZED' },
      });
    }
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired authentication token',
      error: { code: 'TOKEN_INVALID' },
    });
  }
}

export async function optionalAuthenticate(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.split(' ')[1];
    if (!token) return next();

    let decoded = null;
    try {
      decoded = tokenService.verifyAccessToken(token);
    } catch {
      return next();
    }

    if (!decoded) return next();

    const subIdentifier = decoded.sub || decoded.userId || decoded.adminId;
    if (!subIdentifier) return next();

    const isTokenAdmin = Boolean(
      decoded.isAdmin === true ||
      decoded.userType === 'ADMIN' ||
      decoded.aud === 'zeparty-admin'
    );

    if (isTokenAdmin) {
      let admin = await adminRepository.findById(subIdentifier);
      if (!admin && typeof subIdentifier === 'string') {
        admin = await adminRepository.findByUsernameOrEmail(subIdentifier);
      }
      if (admin && admin.status === 'ACTIVE') {
        req.admin = admin;
        req.auth = {
          userId: admin.id,
          sessionId: decoded.sessionId || 'admin_session',
          userType: 'ADMIN',
          isAdmin: true,
          isOwner: Boolean(admin.isOwner),
          isSuperAdmin: Boolean(admin.isSuperAdmin || admin.isOwner),
          roleId: admin.roleId,
          audience: decoded.aud || 'zeparty-admin',
        };
        req.session = { id: decoded.sessionId || 'admin_session', userId: admin.id };
      }
      return next();
    }

    // Resolve regular user
    let user = null;
    if (/^[1-9]\d{6}$/.test(String(subIdentifier))) {
      user = await userRepository.findById(String(subIdentifier));
    } else if (typeof subIdentifier === 'string' && subIdentifier.includes('@')) {
      user = await userRepository.findByEmail(subIdentifier.trim().toLowerCase());
    } else {
      user = await userRepository.findById(String(subIdentifier));
      if (!user && typeof subIdentifier === 'string' && !subIdentifier.startsWith('google_') && !subIdentifier.startsWith('user_')) {
        user = await userRepository.findByUsername(subIdentifier);
      }
    }
    if (!user && typeof subIdentifier === 'string') {
      user = await userRepository.findByFirebaseUid(subIdentifier);
    }

    if (user && user.status === 'ACTIVE' && user.userType !== 'ADMIN' && !user.username?.startsWith('admin_shadow') && !user.id?.startsWith('dev-admin')) {
      req.user = user;
      req.auth = {
        userId: user.id,
        sessionId: decoded.sessionId || 'active_session',
        userType: user.userType || 'USER',
        isAdmin: false,
        audience: decoded.aud || 'zeparty-mobile',
      };
      req.session = { id: decoded.sessionId || 'active_session', userId: user.id };
    }

    return next();
  } catch (_) {
    return next();
  }
}

export default authenticate;
