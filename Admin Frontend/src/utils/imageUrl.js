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
  'assets/roles/ZP-220_top-fan_badge.webp': '/assets/roles/top_fan_badge.webp',
  'assets/roles/ZP-218_super-admin_badge.webp': '/assets/roles/super_admin_tag.webp',
  'assets/roles/ZP-215_official_badge.webp': '/assets/roles/ZP-216_official_badge.webp',
  'assets/roles/ZP-212_marchent_badge.webp': '/assets/roles/ZP-213_marchent_badge.webp',
  'assets/roles/ZP-210_manager_badge.webp': '/assets/roles/manager_tag.webp',
  'assets/roles/ZP-207_lover_badge.webp': '/assets/roles/ZP-208_lover_badge.webp',
  'assets/roles/ZP-204_host_badge.webp': '/assets/roles/ZP-205_host_badge.webp',
  'assets/roles/ZP-201_game-master_badge.webp': '/assets/roles/game_master_badge.webp',
  'assets/roles/ZP-198_cs_badge.webp': '/assets/roles/ZP-199_cs_badge.webp',
  'assets/roles/ZP-196_coins-saller_badge.webp': '/assets/roles/coins_saller_tag.webp',
  'assets/roles/ZP-193_ceo_badge.webp': '/assets/roles/ZP-194_ceo_badge.webp',
  'assets/roles/ZP-190_boss_badge.webp': '/assets/roles/ZP-191_boss_badge.webp',
  'assets/roles/ZP-187_bd_badge.webp': '/assets/roles/ZP-188_bd_badge.webp',
  'assets/roles/ZP-184_assistant_badge.webp': '/assets/roles/ZP-185_assistant_badge.webp',
  'assets/roles/ZP-181_agency_badge.webp': '/assets/roles/ZP-182_agency_badge.webp',
  'assets/roles/ZP-178_admin_badge.webp': '/assets/roles/ZP-179_admin_badge.webp',
  'assets/nobles/emperor_entrance.png': '/assets/nobles/emperor_entrance.webp',
  'assets/nobles/marquis_entrance.png': '/assets/nobles/marquis_entrance.webp',
  'assets/cars/suv_black.png': '/assets/images/gift_supercar.jpg',
  '/assets/cars/suv_black.png': '/assets/images/gift_supercar.jpg',
  'assets/frames/warrior.png': '/assets/nobles/king_frame.webp',
  '/assets/frames/warrior.png': '/assets/nobles/king_frame.webp',
  'assets/frames/spider.png': '/assets/nobles/emperor_frame.webp',
  '/assets/frames/spider.png': '/assets/nobles/emperor_frame.webp',
  'assets/bubbles/unicorn.png': '/assets/animations/mystery_bubble.webp',
  '/assets/bubbles/unicorn.png': '/assets/animations/mystery_bubble.webp',
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

  // Explicit known typo overrides
  if (LEGACY_OVERRIDES[clean]) {
    return LEGACY_OVERRIDES[clean];
  }

  // Handle dummy test URLs
  if (clean.startsWith('http://example.com/')) {
    return SVG_DATA_FALLBACKS[normType] || SVG_DATA_FALLBACKS.gift;
  }

  // Map legacy / placeholder CDN domains to verified local assets
  if (clean.includes('assets.zeparty.app') || clean.includes('cdn.zeparty.app') || clean.includes('cdn.zeparty.io')) {
    if (clean.includes('cyber_neon')) {
      return '/assets/images/frame_neon.jpg';
    }
    if (clean.includes('car_gold')) {
      return '/assets/animations/mystery_entry.webp';
    }

    // Gift CDN matches
    if (clean.includes('cdn.zeparty.app/gifts/')) {
      const giftName = clean.split('gifts/')[1]?.replace(/\.[^.]+$/, '');
      if (giftName === 'rose') return '/assets/images/gift_rose.jpg';
      if (giftName === 'heart') return '/assets/gifts/classic/CG05_Heart_Hands_500_coins.png';
      if (giftName === 'car') return '/assets/images/gift_supercar.jpg';
      if (giftName === 'jet') return '/assets/gifts/classic/CG23_Private_Jet_22000_coins.png';
      if (giftName === 'crown') return '/assets/images/gift_gold_crown.jpg';
      if (giftName === 'castle') return '/assets/gifts/classic/CG26_Crystal_Castle_35000_coins.png';
      if (giftName === 'firework') return '/assets/gifts/classic/CG29_Meteor_Storm_60000_coins.png';
      if (giftName === 'wand') return '/assets/gifts/classic/CG14_Magic_Lamp_4000_coins.png';
      return SVG_DATA_FALLBACKS.gift;
    }

    // Role assets
    const roleMatch = clean.match(/roles\/(badge|frame)_([a-z_]+)/);
    if (roleMatch) {
      const mType = roleMatch[1];
      const role = roleMatch[2];
      if (ROLE_ASSETS[role]) {
        return '/assets/' + (mType === 'frame' ? ROLE_ASSETS[role].frame : ROLE_ASSETS[role].badge);
      }
    }

    // Noble assets
    const nobleMatch = clean.match(/(?:noble|nobles)\/(frame|tag|bag|entry)_noble_(\d+)/);
    if (nobleMatch) {
      const mType = nobleMatch[1];
      const num = parseInt(nobleMatch[2], 10);
      const tier = NOBLE_TIERS[Math.min(num, 7)] || 'baron';

      if (mType === 'frame') return `/assets/nobles/${tier}_frame.webp`;
      if (mType === 'tag' || mType === 'bag') return `/assets/nobles/${tier}_badge.webp`;
      if (mType === 'entry') return num >= 6 ? '/assets/nobles/emperor_entrance.webp' : (num >= 5 ? '/assets/nobles/duke_entrance.webp' : '/assets/nobles/marquis_entrance.webp');
    }

    // Mystery assets
    const mysteryMatch = clean.match(/mystery\/(frame|entry|bubble|tag|bag)_mystery_(\d+)/);
    if (mysteryMatch) {
      const mType = mysteryMatch[1];
      if (mType === 'frame') return '/assets/animations/mystery_frame.webp';
      if (mType === 'entry') return '/assets/animations/mystery_entry.webp';
      if (mType === 'bubble') return '/assets/animations/mystery_bubble.webp';
      return '/assets/animations/mystery_badge.webp';
    }

    // SVIP assets
    const svipMatch = clean.match(/svip\/(badge|frame|entry|bubble)_svip_(\d+)/);
    if (svipMatch) {
      const mType = svipMatch[1];
      const num = svipMatch[2];
      if (mType === 'badge') return `/assets/svip/svip${num}_badge.webp`;
      if (mType === 'frame') return `/assets/svip/svip${num}_frame.webp`;
      if (mType === 'entry') return `/assets/svip/svip${num}_entry.webp`;
      if (mType === 'bubble') return `/assets/svip/svip${num}_chat_bubble.webp`;
    }

    const after = clean.split(/zeparty\.(?:app|io)\/(?:visual_assets\/)?/)[1];
    if (after) {
      const rel = after.startsWith('assets/') ? '/' + after : '/assets/' + after;
      if (LEGACY_OVERRIDES[after] || LEGACY_OVERRIDES[rel]) {
        return LEGACY_OVERRIDES[after] || LEGACY_OVERRIDES[rel];
      }
      return rel;
    }

    return SVG_DATA_FALLBACKS[normType] || SVG_DATA_FALLBACKS.general;
  }

  // Handle local relative paths
  if (clean.startsWith('assets/')) {
    return '/' + clean;
  }
  if (clean.startsWith('/assets/') || clean.startsWith('/uploads/')) {
    return clean;
  }
  if (clean.startsWith('uploads/')) {
    return '/' + clean;
  }

  // Already fully-qualified valid URL (e.g. Unsplash, Cloudinary, Firebase, Data URI)
  if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('blob:') || clean.startsWith('data:')) {
    return clean;
  }

  return clean;
}

/**
 * Handle `<img onError={...} />` to replace broken images with a verified graceful SVG fallback.
 */
export function handleImageError(e, type = 'general') {
  if (!e || !e.target) return;
  const normType = normalizeType(type);
  const fallback = SVG_DATA_FALLBACKS[normType] || SVG_DATA_FALLBACKS.general;
  if (e.target.src !== fallback) {
    e.target.onerror = null; // Prevent infinite loop
    e.target.src = fallback;
  }
}

export default {
  resolveMediaUrl,
  handleImageError,
  FALLBACK_ASSETS,
};
