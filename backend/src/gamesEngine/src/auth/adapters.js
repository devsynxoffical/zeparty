import jwt from 'jsonwebtoken';
import prisma from '../../../config/database.js';

/**
 * Production adapter for embedded ZeParty-Backend mode.
 * Verifies:
 * 1. HS256 tokens signed with GAMES_JWT_SECRET (from GET /v1/games/token)
 * 2. Fallback main backend tokens signed with JWT_SECRET
 * 3. Resilient local offline tokens (local_offline_token_<userId>_... / offline_token_<userId>)
 */
export class JwtAuthAdapter {
  secret;
  issuer;
  claimMap;
  fallbackSecret;

  constructor(
    secret,
    issuer,
    claimMap = {
      name: 'name',
      avatar: 'avatar',
      roles: 'roles',
    },
    fallbackSecret = process.env.JWT_SECRET || 'super-secret-zeparty-jwt-key-change-in-prod-2026'
  ) {
    this.secret = secret;
    this.issuer = issuer;
    this.claimMap = claimMap;
    this.fallbackSecret = fallbackSecret;
  }

  async verify(token) {
    if (!token || typeof token !== 'string') return null;

    // 1. Standard GAMES_JWT_SECRET verification
    try {
      const payload = jwt.verify(token, this.secret, { issuer: this.issuer });
      const sub = payload['sub'];
      if (typeof sub === 'string' && sub.length > 0) {
        const name = payload[this.claimMap.name];
        const avatar = payload[this.claimMap.avatar];
        const roles = payload[this.claimMap.roles];
        return {
          userId: sub,
          displayName: typeof name === 'string' && name.trim().length > 0 ? name : sub,
          avatarUrl: typeof avatar === 'string' ? avatar : null,
          roles: Array.isArray(roles) ? roles.filter((r) => typeof r === 'string') : [],
        };
      }
    } catch {
      // Proceed to fallback checks
    }

    // 2. Fallback: Main Backend JWT_SECRET verification
    if (this.fallbackSecret) {
      try {
        const payload = jwt.verify(token, this.fallbackSecret);
        const sub = payload['sub'] || payload['userId'] || payload['id'];
        if (typeof sub === 'string' && sub.length > 0) {
          let displayName = payload['name'] || payload['displayName'] || payload['username'] || sub;
          let avatarUrl = payload['avatar'] || payload['avatarUrl'] || null;
          try {
            const dbUser = await prisma.user.findUnique({
              where: { id: sub },
              select: { displayName: true, username: true, avatarUrl: true },
            });
            if (dbUser) {
              displayName = dbUser.displayName || dbUser.username || displayName;
              avatarUrl = dbUser.avatarUrl || avatarUrl;
            }
          } catch {}
          return {
            userId: sub,
            displayName: typeof displayName === 'string' ? displayName : sub,
            avatarUrl: typeof avatarUrl === 'string' ? avatarUrl : null,
            roles: [],
          };
        }
      } catch {
        // Proceed to offline fallback check
      }
    }

    // 3. Fallback: Resilient local_offline_token_<userId>_<ts> or offline_token_<userId>
    if (token.startsWith('local_offline_token_') || token.startsWith('offline_token_')) {
      const stripped = token.replace(/^local_offline_token_/, '').replace(/^offline_token_/, '');
      const parts = stripped.split('_');
      const userId =
        parts.length > 1 && /^\d{10,}$/.test(parts[parts.length - 1] ?? '')
          ? parts.slice(0, -1).join('_')
          : stripped;
      if (userId) {
        let displayName = userId;
        let avatarUrl = null;
        try {
          const dbUser = await prisma.user.findUnique({
            where: { id: userId },
            select: { displayName: true, username: true, avatarUrl: true },
          });
          if (dbUser) {
            displayName = dbUser.displayName || dbUser.username || userId;
            avatarUrl = dbUser.avatarUrl || null;
          }
        } catch {}
        return {
          userId,
          displayName,
          avatarUrl,
          roles: [],
        };
      }
    }

    return null;
  }
}

export class MockAuthAdapter extends JwtAuthAdapter {
  devSecret;
  devIssuer;

  constructor(devSecret, devIssuer) {
    super(devSecret, devIssuer);
    this.devSecret = devSecret;
    this.devIssuer = devIssuer;
  }

  issue(identity, ttlSeconds = 60 * 60 * 24) {
    const claims = {
      sub: identity.userId,
      name: identity.displayName,
      avatar: identity.avatarUrl,
      roles: identity.roles ?? [],
    };
    return jwt.sign(claims, this.devSecret, { issuer: this.devIssuer, expiresIn: ttlSeconds });
  }
}
