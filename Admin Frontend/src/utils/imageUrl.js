// ============================================================
// ZeParty Admin Portal — Central Media & Image URL Resolver
// Handles path resolution, local asset mapping & resilient fallbacks
// ============================================================

// Guaranteed, self-contained SVG Data URIs for graceful category fallbacks
// Never fails over the network, maintains crisp styling in dark mode
const SVG_DATA_FALLBACKS = {
  frame: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><circle cx="50" cy="50" r="44" stroke="%23D4AF37" stroke-width="4" stroke-dasharray="8 4"/><circle cx="50" cy="50" r="38" stroke="%23AA7C11" stroke-width="2" opacity="0.6"/><circle cx="50" cy="50" r="32" fill="%230f172a"/></svg>`,
  gift: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><rect width="100" height="100" rx="20" fill="%231e1b4b"/><rect x="22" y="38" width="56" height="46" rx="8" fill="%234338ca" stroke="%23818cf8" stroke-width="2"/><path d="M50 38v46M22 61h56" stroke="%23fbbf24" stroke-width="5"/><rect x="18" y="28" width="64" height="14" rx="4" fill="%236366f1" stroke="%23a5b4fc" stroke-width="2"/><circle cx="42" cy="22" r="7" stroke="%23fbbf24" stroke-width="3"/><circle cx="58" cy="22" r="7" stroke="%23fbbf24" stroke-width="3"/></svg>`,
  badge: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><path d="M50 8l12 24 26 4-19 18 4 26-23-12-23 12 4-26-19-18 26-4z" fill="%23d97706" stroke="%23fbbf24" stroke-width="2"/><circle cx="50" cy="46" r="14" fill="%2378350f"/><path d="M50 38l3 7 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1z" fill="%23fef08a"/></svg>`,
  card: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><rect x="12" y="16" width="76" height="68" rx="8" fill="%231e293b" stroke="%2338bdf8" stroke-width="2"/><circle cx="50" cy="44" r="16" fill="%230284c7"/><path d="M30 72c0-11 9-20 20-20s20 9 20 20H30z" fill="%230ea5e9"/></svg>`,
  avatar: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><circle cx="50" cy="50" r="46" fill="%230f172a" stroke="%23334155" stroke-width="2"/><circle cx="50" cy="40" r="16" fill="%2364748b"/><path d="M24 82c0-14.36 11.64-26 26-26s26 11.64 26 26H24z" fill="%23475569"/></svg>`,
  emoji: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><circle cx="50" cy="50" r="42" fill="%23eab308"/><circle cx="36" cy="42" r="5" fill="%2378350f"/><circle cx="64" cy="42" r="5" fill="%2378350f"/><path d="M34 60c4 10 28 10 32 0" stroke="%2378350f" stroke-width="5" stroke-linecap="round"/></svg>`,
  reaction: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><circle cx="50" cy="50" r="44" fill="%234c0519"/><path d="M50 72s-22-14-22-28a12 12 0 0122-7 12 12 0 0122 7c0 14-22 28-22 28z" fill="%23f43f5e"/><circle cx="50" cy="30" r="4" fill="%23fda4af"/></svg>`,
  bubble: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><rect x="12" y="18" width="76" height="52" rx="16" fill="%230f172a" stroke="%2338bdf8" stroke-width="3"/><path d="M28 70l-8 14 18-6" fill="%230f172a" stroke="%2338bdf8" stroke-width="3"/><circle cx="36" cy="44" r="4" fill="%2338bdf8"/><circle cx="50" cy="44" r="4" fill="%2338bdf8"/><circle cx="64" cy="44" r="4" fill="%2338bdf8"/></svg>`,
  entry: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><rect width="100" height="100" rx="20" fill="%230f172a"/><path d="M16 58l10-18h48l10 18H16z" fill="%23e11d48"/><path d="M12 58h76v14a4 4 0 01-4 4H16a4 4 0 01-4-4V58z" fill="%23be123c"/><circle cx="30" cy="74" r="8" fill="%23334155" stroke="%2394a3b8" stroke-width="3"/><circle cx="70" cy="74" r="8" fill="%23334155" stroke="%2394a3b8" stroke-width="3"/></svg>`,
  vip: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><rect width="100" height="100" rx="20" fill="%2318181b"/><path d="M22 36l14-16h28l14 16-28 44z" fill="%23eab308" stroke="%23fbbf24" stroke-width="2"/><text x="50" y="44" font-family="sans-serif" font-weight="900" font-size="13" fill="%23000" text-anchor="middle">VIP</text></svg>`,
  svip: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><rect width="100" height="100" rx="20" fill="%232e1065"/><path d="M18 38l16-18h32l16 18-32 46z" fill="%23a855f7" stroke="%23c084fc" stroke-width="2"/><text x="50" y="46" font-family="sans-serif" font-weight="900" font-size="12" fill="%23fff" text-anchor="middle">SVIP</text></svg>`,
  general: `data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none"><circle cx="50" cy="50" r="44" fill="%230f172a" stroke="%23475569" stroke-width="2"/><path d="M50 20l9 19 21 3-15 15 4 21-19-10-19 10 4-21-15-15 21-3z" fill="%23D4AF37"/></svg>`,
};

export const FALLBACK_ASSETS = SVG_DATA_FALLBACKS;

const NOBLE_TIERS = {
  1: 'baron',
  2: 'viscount',
  3: 'count',
  4: 'marquis',
  5: 'duke',
  6: 'king',
  7: 'emperor',
};

export const CANONICAL_CDN_BASE = 'https://raw.githubusercontent.com/devsynxoffical/zeparty/main/mobile%20app/assets';

export function getCanonicalCdnUrl(path) {
  if (!path || typeof path !== 'string') return '';
  const clean = path.replace(/^\/+/, '').replace(/^assets\//, '').replace(/^\/+/, '');
  const encoded = clean.split('/').map(encodeURIComponent).join('/');
  return `${CANONICAL_CDN_BASE}/${encoded}`;
}

const ID_ASSET_MAPPINGS = {
  car_supercar: 'images/gift_supercar.jpg',
  noble_frame_emperor: 'nobles/emperor_frame.webp',
  noble_badge_emperor: 'nobles/emperor_badge.webp',
  noble_card_emperor: 'nobles/tier-7-emperor_profilecard.webp',
  noble_frame_king: 'nobles/king_frame.webp',
  noble_badge_king: 'nobles/king_badge.webp',
  noble_card_king: 'nobles/king_card.webp',
  noble_frame_duke: 'nobles/duke_frame.webp',
  noble_badge_duke: 'nobles/duke_badge.webp',
  noble_card_duke: 'nobles/duke_card.webp',
  noble_frame_marquis: 'nobles/marquis_frame.webp',
  noble_badge_marquis: 'nobles/marquis_badge.webp',
  noble_card_marquis: 'nobles/marquis_card.webp',
  noble_frame_count: 'nobles/count_frame.webp',
  noble_badge_count: 'nobles/count_badge.webp',
  noble_card_count: 'nobles/count_card.webp',
  noble_frame_viscount: 'nobles/viscount_frame.webp',
  noble_badge_viscount: 'nobles/viscount_badge.webp',
  noble_card_viscount: 'nobles/viscount_card.webp',
  noble_frame_baron: 'nobles/baron_frame.webp',
  noble_badge_baron: 'nobles/baron_badge.webp',
  noble_card_baron: 'nobles/baron_card.webp',
  test_cosmetic_frame_cyber: 'images/frame_neon.jpg',
  test_cosmetic_frame_cyb: 'images/frame_neon.jpg',
  'ast-car-01': 'animations/mystery_entry.webp',
  'ast-car-02': 'images/gift_supercar.jpg',
  'ast-frame-01': 'nobles/king_frame.webp',
  'ast-frame-02': 'nobles/emperor_frame.webp',
  'ast-bub-01': 'animations/mystery_bubble.webp',
};

const ROLE_ASSETS = {
  admin: { badge: 'roles/ZP-179_admin_badge.webp', frame: 'roles/admin_frame.webp' },
  agency: { badge: 'roles/ZP-182_agency_badge.webp', frame: 'roles/agency_frame.webp' },
  assistant: { badge: 'roles/ZP-185_assistant_badge.webp', frame: 'roles/assistant_frame.webp' },
  bd: { badge: 'roles/ZP-188_bd_badge.webp', frame: 'roles/bd_frame.webp' },
  boss: { badge: 'roles/ZP-191_boss_badge.webp', frame: 'roles/boss_frame.webp' },
  ceo: { badge: 'roles/ZP-194_ceo_badge.webp', frame: 'roles/ceo_frame.webp' },
  coins_seller: { badge: 'roles/coins_saller_tag.webp', frame: 'roles/coins_saller_frame.webp' },
  coin_seller: { badge: 'roles/coins_saller_tag.webp', frame: 'roles/coins_saller_frame.webp' },
  cs: { badge: 'roles/ZP-199_cs_badge.webp', frame: 'roles/cs_frame.webp' },
  game_master: { badge: 'roles/game_master_badge.webp', frame: 'roles/game_master_frame.webp' },
  host: { badge: 'roles/ZP-205_host_badge.webp', frame: 'roles/host_frame.webp' },
  lover: { badge: 'roles/ZP-208_lover_badge.webp', frame: 'roles/lover_frame.webp' },
  manager: { badge: 'roles/manager_tag.webp', frame: 'roles/manager_frame.webp' },
  merchant: { badge: 'roles/ZP-213_marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  marchent: { badge: 'roles/ZP-213_marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  official: { badge: 'roles/ZP-216_official_badge.webp', frame: 'roles/official_frame.webp' },
  super_admin: { badge: 'roles/super_admin_tag.webp', frame: 'roles/super_admin_frame.webp' },
  top_fan: { badge: 'roles/top_fan_badge.webp', frame: 'roles/top_fan_frame.webp' },
  vip: { badge: 'roles/ZP-216_official_badge.webp', frame: 'roles/official_frame.webp' },
  svip: { badge: 'svip/ZP-054_svip-1_badge.webp', frame: 'svip/svip1_frame.webp' },
  dragon: { badge: 'nobles/emperor_badge.webp', frame: 'nobles/emperor_frame.webp' },
  elite: { badge: 'nobles/king_badge.webp', frame: 'nobles/king_frame.webp' },
  guardian: { badge: 'nobles/duke_badge.webp', frame: 'nobles/duke_frame.webp' },
  singer: { badge: 'nobles/marquis_badge.webp', frame: 'nobles/marquis_frame.webp' },
  family: { badge: 'nobles/count_badge.webp', frame: 'nobles/count_frame.webp' },
};

const LEGACY_OVERRIDES = {
  'assets/roles/ZP-220_top-fan_badge.webp': 'roles/top_fan_badge.webp',
  'assets/roles/ZP-218_super-admin_badge.webp': 'roles/super_admin_tag.webp',
  'assets/roles/ZP-215_official_badge.webp': 'roles/ZP-216_official_badge.webp',
  'assets/roles/ZP-212_marchent_badge.webp': 'roles/ZP-213_marchent_badge.webp',
  'assets/roles/ZP-210_manager_badge.webp': 'roles/manager_tag.webp',
  'assets/roles/ZP-207_lover_badge.webp': 'roles/ZP-208_lover_badge.webp',
  'assets/roles/ZP-204_host_badge.webp': 'roles/ZP-205_host_badge.webp',
  'assets/roles/ZP-201_game-master_badge.webp': 'roles/game_master_badge.webp',
  'assets/roles/ZP-198_cs_badge.webp': 'roles/ZP-199_cs_badge.webp',
  'assets/roles/ZP-196_coins-saller_badge.webp': 'roles/coins_saller_tag.webp',
  'assets/roles/ZP-193_ceo_badge.webp': 'roles/ZP-194_ceo_badge.webp',
  'assets/roles/ZP-190_boss_badge.webp': 'roles/ZP-191_boss_badge.webp',
  'assets/roles/ZP-187_bd_badge.webp': 'roles/ZP-188_bd_badge.webp',
  'assets/roles/ZP-184_assistant_badge.webp': 'roles/ZP-185_assistant_badge.webp',
  'assets/roles/ZP-181_agency_badge.webp': 'roles/ZP-182_agency_badge.webp',
  'assets/roles/ZP-178_admin_badge.webp': 'roles/ZP-179_admin_badge.webp',
  'assets/nobles/emperor_entrance.png': 'nobles/emperor_entrance.webp',
  'assets/nobles/marquis_entrance.png': 'nobles/marquis_entrance.webp',
  'assets/cars/suv_black.png': 'images/gift_supercar.jpg',
  '/assets/cars/suv_black.png': 'images/gift_supercar.jpg',
  'assets/frames/warrior.png': 'nobles/king_frame.webp',
  '/assets/frames/warrior.png': 'nobles/king_frame.webp',
  'assets/frames/spider.png': 'nobles/emperor_frame.webp',
  '/assets/frames/spider.png': 'nobles/emperor_frame.webp',
  'assets/bubbles/unicorn.png': 'animations/mystery_bubble.webp',
  '/assets/bubbles/unicorn.png': 'animations/mystery_bubble.webp',
};

function normalizeType(type) {
  if (!type || typeof type !== 'string') return 'general';
  const t = type.toLowerCase().trim();
  if (t.includes('frame')) return 'frame';
  if (t.includes('gift')) return 'gift';
  if (t.includes('car') || t.includes('vehicle') || t.includes('entry')) return 'entry';
  if (t.includes('bubble')) return 'bubble';
  if (t.includes('card')) return 'card';
  if (t.includes('badge') || t.includes('tag')) return 'badge';
  if (t.includes('svip')) return 'svip';
  if (t.includes('vip')) return 'vip';
  if (t.includes('reaction')) return 'reaction';
  if (t.includes('emoji')) return 'emoji';
  if (t.includes('avatar')) return 'avatar';
  return 'general';
}

function resolveAssetSubpath(raw) {
  if (!raw || typeof raw !== 'string') return null;
  const clean = raw.trim();

  // Direct ID check
  if (ID_ASSET_MAPPINGS[clean]) {
    return ID_ASSET_MAPPINGS[clean];
  }

  // Explicit known overrides
  if (LEGACY_OVERRIDES[clean]) {
    return LEGACY_OVERRIDES[clean];
  }

  // Legacy CDN domains
  if (clean.includes('assets.zeparty.app') || clean.includes('cdn.zeparty.app') || clean.includes('cdn.zeparty.io')) {
    if (clean.includes('cyber_neon')) {
      return 'images/frame_neon.jpg';
    }
    if (clean.includes('car_gold')) {
      return 'animations/mystery_entry.webp';
    }

    if (clean.includes('cdn.zeparty.app/gifts/')) {
      const giftName = clean.split('gifts/')[1]?.replace(/\.[^.]+$/, '');
      if (giftName === 'rose') return 'images/gift_rose.jpg';
      if (giftName === 'heart') return 'gifts/classic/CG05_Heart_Hands_500_coins.png';
      if (giftName === 'car') return 'images/gift_supercar.jpg';
      if (giftName === 'jet') return 'gifts/classic/CG23_Private_Jet_22000_coins.png';
      if (giftName === 'crown') return 'images/gift_gold_crown.jpg';
      if (giftName === 'castle') return 'gifts/classic/CG26_Crystal_Castle_35000_coins.png';
      if (giftName === 'firework') return 'gifts/classic/CG29_Meteor_Storm_60000_coins.png';
      if (giftName === 'wand') return 'gifts/classic/CG14_Magic_Lamp_4000_coins.png';
      return 'images/party_gift_box.jpg';
    }

    // Role assets
    const roleMatch = clean.match(/roles\/(badge|frame)_([a-z_]+)/);
    if (roleMatch) {
      const mType = roleMatch[1];
      const role = roleMatch[2];
      if (ROLE_ASSETS[role]) {
        return mType === 'frame' ? ROLE_ASSETS[role].frame : ROLE_ASSETS[role].badge;
      }
    }

    // Noble assets
    const nobleMatch = clean.match(/(?:noble|nobles)\/(frame|tag|bag|entry)_noble_(\d+)/);
    if (nobleMatch) {
      const mType = nobleMatch[1];
      const num = parseInt(nobleMatch[2], 10);
      const tier = NOBLE_TIERS[Math.min(num, 7)] || 'baron';

      if (mType === 'frame') return `nobles/${tier}_frame.webp`;
      if (mType === 'tag' || mType === 'bag') return `nobles/${tier}_badge.webp`;
      if (mType === 'entry') {
        return num >= 6
          ? 'nobles/emperor_entrance.webp'
          : num >= 5
          ? 'nobles/duke_entrance.webp'
          : 'nobles/marquis_entrance.webp';
      }
    }

    // Mystery assets
    const mysteryMatch = clean.match(/mystery\/(frame|entry|bubble|tag|bag)_mystery_(\d+)/);
    if (mysteryMatch) {
      const mType = mysteryMatch[1];
      if (mType === 'frame') return 'animations/mystery_frame.webp';
      if (mType === 'entry') return 'animations/mystery_entry.webp';
      if (mType === 'bubble') return 'animations/mystery_bubble.webp';
      return 'animations/mystery_badge.webp';
    }

    // SVIP assets
    const svipMatch = clean.match(/svip\/(badge|frame|entry|bubble)_svip_(\d+)/);
    if (svipMatch) {
      const mType = svipMatch[1];
      const num = svipMatch[2];
      if (mType === 'badge') return `svip/svip${num}_badge.webp`;
      if (mType === 'frame') return `svip/svip${num}_frame.webp`;
      if (mType === 'entry') return `svip/svip${num}_entry.webp`;
      if (mType === 'bubble') return `svip/svip${num}_chat_bubble.webp`;
    }

    const after = clean.split(/zeparty\.(?:app|io)\/(?:visual_assets\/)?/)[1];
    if (after) {
      const trimmedAfter = after.replace(/^assets\//, '').replace(/^\/+/, '');
      return LEGACY_OVERRIDES[trimmedAfter] || trimmedAfter;
    }
  }

  // If starts with assets/ or /assets/
  if (clean.startsWith('assets/') || clean.startsWith('/assets/')) {
    const sub = clean.replace(/^\/+/, '').replace(/^assets\//, '').replace(/^\/+/, '');
    return LEGACY_OVERRIDES[sub] || sub;
  }

  return null;
}

/**
 * Resolves any image URL or asset key to an accessible, valid URL with appropriate fallbacks.
 *
 * @param {string} url - The raw URL or path stored in the database or returned by API.
 * @param {string} type - Asset type for fallback ('gift', 'frame', 'badge', 'emoji', etc.)
 * @returns {string} The resolved URL suitable for `<img src="...">`.
 */
export function resolveMediaUrl(url, type = 'general') {
  const normType = normalizeType(type);

  if (!url || typeof url !== 'string' || !url.trim()) {
    return SVG_DATA_FALLBACKS[normType] || SVG_DATA_FALLBACKS.general;
  }

  const clean = url.trim();

  // Direct test URLs fallback
  if (clean.startsWith('http://example.com/')) {
    return SVG_DATA_FALLBACKS[normType] || SVG_DATA_FALLBACKS.gift;
  }

  // Already a full canonical CDN link
  if (clean.startsWith(CANONICAL_CDN_BASE)) {
    return clean;
  }

  // Resolve subpath
  const subPath = resolveAssetSubpath(clean);
  if (subPath) {
    const isLocalhost =
      typeof window !== 'undefined' &&
      (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1');

    // On deployed environments (Vercel, Railway, etc.), load canonical CDN directly to avoid 404s
    if (!isLocalhost) {
      return getCanonicalCdnUrl(subPath);
    }

    // On localhost, use relative /assets/ path for local dev speed
    return `/assets/${subPath}`;
  }

  // Handle local /uploads/
  if (clean.startsWith('/uploads/') || clean.startsWith('uploads/')) {
    return clean.startsWith('/') ? clean : '/' + clean;
  }

  // Already fully-qualified valid URL (e.g. Unsplash, Cloudinary, Firebase, Data URI)
  if (
    clean.startsWith('http://') ||
    clean.startsWith('https://') ||
    clean.startsWith('blob:') ||
    clean.startsWith('data:')
  ) {
    return clean;
  }

  return clean;
}

/**
 * Handle `<img onError={...} />` to replace broken images with a two-stage fallback:
 * Stage 1: Retry using canonical CDN if local /assets/ failed.
 * Stage 2: Verified graceful SVG fallback if CDN also fails.
 */
export function handleImageError(e, type = 'general') {
  if (!e || !e.target) return;
  const target = e.target;
  const currentSrc = target.src || '';

  // Stage 1: Try canonical CDN if local request failed and hasn't retried yet
  const assetMatch = currentSrc.match(/(?:assets|uploads)\/(.+)$/);
  if (assetMatch && !currentSrc.includes('raw.githubusercontent.com') && !target.dataset.cdnRetried) {
    target.dataset.cdnRetried = 'true';
    const subPath = assetMatch[1];
    target.src = getCanonicalCdnUrl(subPath);
    return;
  }

  // Stage 2: Graceful SVG fallback
  const normType = normalizeType(type);
  const fallback = SVG_DATA_FALLBACKS[normType] || SVG_DATA_FALLBACKS.general;
  if (target.src !== fallback) {
    target.onerror = null; // Prevent infinite loop
    target.src = fallback;
  }
}

export default {
  resolveMediaUrl,
  handleImageError,
  getCanonicalCdnUrl,
  CANONICAL_CDN_BASE,
  FALLBACK_ASSETS,
};

