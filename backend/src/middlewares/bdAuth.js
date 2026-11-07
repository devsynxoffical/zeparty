import prisma from '../config/database.js';

/**
 * Middleware: requireActiveBD
 * Enforces authoritative active Business Development (BD) Agent / Center authorization.
 *
 * Verifies that the authenticated user either manages an active BDCenter
 * or holds the BD_AGENT role.
 */
export async function requireActiveBD(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to access BD Center',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    // Defensive check: reject synthetic admin / shadow identities
    if (typeof userId === 'string' && (userId.startsWith('dev-admin') || userId.startsWith('admin_shadow'))) {
      return res.status(403).json({
        success: false,
        message: 'Administrative identities cannot access user BD centers',
        error: { code: 'FORBIDDEN' },
      });
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        userType: true,
        status: true,
        managedBDCenters: {
          take: 1,
        },
      },
    });

    if (!user || user.status !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: 'Access denied: User account is inactive or not found',
        error: { code: 'USER_INACTIVE' },
      });
    }

    const bdCenter = user.managedBDCenters?.[0] || null;
    const isBDAgent = user.userType === 'BD_AGENT';

    if (!bdCenter && !isBDAgent) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: You are not authorized as a BD Agent or Center Manager',
        error: { code: 'BD_ACCESS_DENIED' },
      });
    }

    req.bdCenter = bdCenter;
    req.bdUser = user;
    next();
  } catch (err) {
    next(err);
  }
}

export default requireActiveBD;

