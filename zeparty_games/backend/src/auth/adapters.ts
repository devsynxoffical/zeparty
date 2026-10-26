import jwt from 'jsonwebtoken';
import type { AuthAdapter, ZePartyIdentity } from './types.js';

interface TokenClaims {
  sub: string;
  name?: string;
  avatar?: string | null;
  roles?: string[];
}

/**
 * Production adapter. Verifies HS256 tokens signed by the ZeParty host backend.
 * Replace `secret` with the host's signing key, or swap jwt.verify for RS256 with the
 * host's public key. Claim names are configurable through `claimMap`.
 */
export class JwtAuthAdapter implements AuthAdapter {
  constructor(
    private readonly secret: string,
    private readonly issuer: string,
    private readonly claimMap: { name: string; avatar: string; roles: string } = {
      name: 'name',
      avatar: 'avatar',
      roles: 'roles',
    },
  ) {}

  async verify(token: string): Promise<ZePartyIdentity | null> {
    try {
      const payload = jwt.verify(token, this.secret, { issuer: this.issuer }) as Record<string, unknown>;
      const sub = payload['sub'];
      if (typeof sub !== 'string' || sub.length === 0) return null;
      const name = payload[this.claimMap.name];
      const avatar = payload[this.claimMap.avatar];
      const roles = payload[this.claimMap.roles];
      return {
        userId: sub,
        displayName: typeof name === 'string' ? name : sub,
        avatarUrl: typeof avatar === 'string' ? avatar : null,
        roles: Array.isArray(roles) ? roles.filter((r): r is string => typeof r === 'string') : [],
      };
    } catch {
      return null;
    }
  }
}

/**
 * Development adapter. Same verification path as JwtAuthAdapter but also able to mint tokens,
 * used by POST /auth/dev-login so the demo Flutter app can obtain identities without the host.
 */
export class MockAuthAdapter extends JwtAuthAdapter {
  constructor(private readonly devSecret: string, private readonly devIssuer: string) {
    super(devSecret, devIssuer);
  }

  issue(identity: Omit<ZePartyIdentity, 'roles'> & { roles?: string[] }, ttlSeconds = 60 * 60 * 24): string {
    const claims: TokenClaims = {
      sub: identity.userId,
      name: identity.displayName,
      avatar: identity.avatarUrl,
      roles: identity.roles ?? [],
    };
    return jwt.sign(claims, this.devSecret, { issuer: this.devIssuer, expiresIn: ttlSeconds });
  }
}
