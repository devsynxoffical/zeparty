import prisma from '../config/database.js';

/**
 * Middleware: requireActiveMerchant
 * Enforces authoritative active Merchant authorization.
 *
 * Verifies that the authenticated user possesses an approved and ACTIVE
 * Merchant record in the database.
 */
export async function requireActiveMerchant(req, res, next) {
  try {
    const userId = req.auth?.userId;
    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required to access merchant portal',
        error: { code: 'UNAUTHORIZED' },
      });
    }

    // Defensive check: reject synthetic admin / shadow identities
    if (typeof userId === 'string' && (userId.startsWith('dev-admin') || userId.startsWith('admin_shadow'))) {
      return res.status(403).json({
        success: false,
        message: 'Administrative identities cannot access user merchant portals',
        error: { code: 'FORBIDDEN' },
      });
    }

    const merchant = await prisma.merchant.findUnique({
      where: { userId },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            status: true,
            countryCode: true,
            profile: true,
            wallet: true,
          },
        },
      },
    });

    if (!merchant) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: You do not have an authorized Merchant account',
        error: { code: 'MERCHANT_NOT_FOUND' },
      });
    }

    if (merchant.status !== 'ACTIVE') {
      return res.status(403).json({
        success: false,
        message: 'Access denied: Your Merchant account is inactive or suspended',
        error: { code: 'MERCHANT_INACTIVE' },
      });
    }

    req.merchant = merchant;
    next();
  } catch (err) {
    next(err);
  }
}

export default requireActiveMerchant;

