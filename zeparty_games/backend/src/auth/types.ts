/**
 * Identity contract between the ZeParty host application and the games backend.
 *
 * The games backend never creates its own user accounts. It verifies a token issued by
 * the host and derives a ZePartyIdentity from it. Two adapters exist:
 *  - MockAuthAdapter (development): issues and verifies HS256 dev tokens locally.
 *  - JwtAuthAdapter (production): verifies tokens issued by the host backend with a shared
 *    secret or public key. Claims mapping is documented in docs/integration/auth.md.
 */
export interface ZePartyIdentity {
  userId: string;
  displayName: string;
  avatarUrl: string | null;
  /** Host-side roles such as "admin", "host", "moderator". Informational for games. */
  roles: string[];
}

export interface AuthAdapter {
  /** Verify a bearer token and return the identity, or null when invalid or expired. */
  verify(token: string): Promise<ZePartyIdentity | null>;
}

export class AuthError extends Error {
  constructor(message = 'unauthorized') {
    super(message);
    this.name = 'AuthError';
  }
}
