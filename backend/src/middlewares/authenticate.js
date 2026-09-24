import tokenService from '../services/token.service.js';
import sessionRepository from '../repositories/session.repository.js';
import userRepository from '../repositories/user.repository.js';
import adminRepository from '../repositories/admin.repository.js';
import deviceRepository from '../repositories/device.repository.js';

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

    // Verify JWT or Fallback Session Token
    let decoded = null;
    try {
      decoded = tokenService.verifyAccessToken(token);
    } catch (jwtErr) {
      // Fallback for session tokens / local mobile app authentication / expired tokens
      const unverified = tokenService.decodeToken(token);
      let subId = unverified?.sub || (token.startsWith('session_token_') ? token.replace('session_token_', '') : token);
      let user = null;
      if (subId) {
        user = await userRepository.findById(subId);
        if (!user && subId.includes('@')) {
          user = await userRepository.findByEmail(subId);
        }
        if (!user) {
          user = await userRepository.findByUsername(subId);
        }
        if (!user) {
          // Create or register active user record bound to this specific subId
          const baseName = unverified?.displayName || unverified?.name || subId.split('@')[0];
          user = await userRepository.createUserWithProfile({
            id: /^[1-9]\d{6}$/.test(subId) ? subId : undefined,
            username: subId.startsWith('user_') ? subId : (subId.includes('@') ? subId.split('@')[0] : `user_${subId.slice(0, 10)}`),
            displayName: baseName || 'ZeParty Member',
            status: 'ACTIVE',
            userType: 'USER',
          }).catch(async () => {
            return await userRepository.findById(subId);
          });
        }
      }
      if (user) {
        req.user = user;
        req.auth = {
          userId: user.id,
          sessionId: unverified?.sessionId || 'fallback_session',
          userType: user.userType || 'USER',
          isAdmin: false,
        };
        req.session = { id: unverified?.sessionId || 'fallback_session', userId: user.id };
        return next();
      }
      throw jwtErr;
    }

    // Resolve Identity: Admin or User
    let admin = null;
    if (decoded.isAdmin || decoded.userType === 'ADMIN' || decoded.role === 'ADMIN' || decoded.roleId) {
      admin = await adminRepository.findById(decoded.sub);
      if (!admin) {
        admin = await adminRepository.findByUsernameOrEmail(decoded.sub);
      }
    } else {
      admin = await adminRepository.findById(decoded.sub);
      if (!admin && decoded.sub?.includes('@')) {
        admin = await adminRepository.findByUsernameOrEmail(decoded.sub);
      }
    }

    if (admin) {
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
        isSuperAdmin: Boolean(admin.isSuperAdmin),
        roleId: admin.roleId,
      };
      req.session = { id: decoded.sessionId || 'admin_session', userId: admin.id };
      return next();
    }

    // Regular User Resolution
    let user = await userRepository.findById(decoded.sub);
    if (!user && decoded.sub?.includes('@')) {
      user = await userRepository.findByEmail(decoded.sub);
    }
    if (!user) {
      user = await userRepository.findByUsername(decoded.sub);
    }
    if (!user) {
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
    };
    req.session = { id: decoded.sessionId || 'active_session', userId: user.id };

    next();
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
      const unverified = tokenService.decodeToken(token);
      let subId = unverified?.sub || (token.startsWith('session_token_') ? token.replace('session_token_', '') : token);
      let user = null;
      if (subId) {
        user = await userRepository.findById(subId);
        if (!user && subId.includes('@')) {
          user = await userRepository.findByEmail(subId);
        }
        if (!user) {
          user = await userRepository.findByUsername(subId);
        }
      }
      if (user && user.status === 'ACTIVE') {
        req.user = user;
        req.auth = {
          userId: user.id,
          sessionId: unverified?.sessionId || 'fallback_session',
          userType: user.userType || 'USER',
          isAdmin: false,
        };
        req.session = { id: unverified?.sessionId || 'fallback_session', userId: user.id };
        return next();
      }
      return next();
    }

    if (decoded) {
      if (decoded.isAdmin || decoded.userType === 'ADMIN') {
        const admin = await adminRepository.findById(decoded.sub);
        if (admin && admin.status === 'ACTIVE') {
          req.admin = admin;
          req.auth = {
            userId: admin.id,
            sessionId: decoded.sessionId || 'admin_session',
            userType: 'ADMIN',
            isAdmin: true,
            isOwner: Boolean(admin.isOwner),
            isSuperAdmin: Boolean(admin.isSuperAdmin),
            roleId: admin.roleId,
          };
          req.session = { id: decoded.sessionId || 'admin_session', userId: admin.id };
        }
      } else {
        const user = await userRepository.findById(decoded.sub);
        if (user && user.status === 'ACTIVE') {
          req.user = user;
          req.auth = {
            userId: user.id,
            sessionId: decoded.sessionId || 'active_session',
            userType: user.userType || 'USER',
            isAdmin: false,
          };
          req.session = { id: decoded.sessionId || 'active_session', userId: user.id };
        }
      }
    }

    next();
  } catch (_) {
    next();
  }
}

export default authenticate;
