import prisma from '../config/database.js';

/**
 * Middleware: requireActiveSeller
 * Enforces authoritative active Coins Seller authorization.
 *
 * Verifies that the authenticated user possesses an approved and ACTIVE
 * CoinSeller portal record in the database. A decorative badge alone or
 * client-supplied flags will NEVER pass this gate.
 */
export async function requireActiveSeller(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to access coins seller portal',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    // Defensive check: reject synthetic admin / shadow identities
    if (typeof userId === 'string' && (userId.startsWith('dev-admin') || userId.startsWith('admin_shadow'))) {
      return res.status(403).json({
        success: false,
        message: 'Administrative identities cannot access user seller portals',
        error: { code: 'FORBIDDEN' },
      });
    }

    const seller = await prisma.coinSeller.findUnique({
      where: { userId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            status: true,
            countryCode: true,
            profile: true,
          },
        },
      },
    });

    if (!seller) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: You do not have an authorized Coins Seller portal account',
        error: { code: 'SELLER_PORTAL_NOT_FOUND' },
      });
    }

    if (seller.sellerStatus !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Your Coins Seller portal account is suspended or inactive',
        error: { code: 'SELLER_PORTAL_SUSPENDED' },
      });
    }

    req.seller = seller;
    next();
  } catch (err) {
    next(err);
  }
}

export default requireActiveSeller;
