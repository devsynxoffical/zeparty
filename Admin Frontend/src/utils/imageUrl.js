// ============================================================
// ZeParty Admin Portal — Central Media & Image URL Resolver
// Resilient CDN mapping, reliable fallbacks & SVG data URIs
// ============================================================

// High-fidelity inline SVG Data URIs for bulletproof 0ms fallbacks that never 404
const svgWrap = (inner) =>
  `data:image/svg+xml;utf8,${encodeURIComponent(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">${inner}</svg>`
  )}`;

export const FALLBACK_ASSETS = {
  frame: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <circle cx="50" cy="50" r="34" fill="none" stroke="#a855f7" stroke-width="4" stroke-dasharray="4 2"/>
    <circle cx="50" cy="50" r="28" fill="#1e1b4b" stroke="#06b6d4" stroke-width="2"/>
    <polygon points="50,30 55,42 67,42 57,50 61,62 50,54 39,62 43,50 33,42 45,42" fill="#f59e0b"/>
  `),
  gift: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <rect x="25" y="42" width="50" height="36" rx="4" fill="#ec4899"/>
    <rect x="22" y="34" width="56" height="10" rx="3" fill="#f43f5e"/>
    <rect x="46" y="34" width="8" height="44" fill="#fbbf24"/>
    <path d="M50 34 C42 22 28 26 44 34 Z M50 34 C58 22 72 26 56 34 Z" fill="#fbbf24"/>
  `),
  badge: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <polygon points="50,20 74,32 74,62 50,80 26,62 26,32" fill="#1e293b" stroke="#eab308" stroke-width="3"/>
    <polygon points="50,32 54,42 65,42 56,49 59,60 50,53 41,60 44,49 35,42 46,42" fill="#eab308"/>
  `),
  avatar: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <circle cx="50" cy="38" r="16" fill="#64748b"/>
    <path d="M26 78 C26 62 36 56 50 56 C64 56 74 62 74 78 Z" fill="#64748b"/>
  `),
  emoji: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <circle cx="50" cy="50" r="32" fill="#fbbf24"/>
    <circle cx="38" cy="42" r="4" fill="#78350f"/>
    <circle cx="62" cy="42" r="4" fill="#78350f"/>
    <path d="M35 56 Q50 72 65 56" fill="none" stroke="#78350f" stroke-width="4" stroke-linecap="round"/>
  `),
  reaction: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <path d="M50 74 C26 56 18 42 26 28 C34 16 48 22 50 32 C52 22 66 16 74 28 C82 42 74 56 50 74 Z" fill="#ef4444"/>
  `),
  bubble: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <rect x="22" y="28" width="56" height="38" rx="8" fill="#3b82f6"/>
    <polygon points="36,66 48,66 32,76" fill="#3b82f6"/>
    <circle cx="38" cy="47" r="3" fill="#ffffff"/>
    <circle cx="50" cy="47" r="3" fill="#ffffff"/>
    <circle cx="62" cy="47" r="3" fill="#ffffff"/>
  `),
  entry: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <path d="M20 58 L28 44 L40 40 L64 40 L76 46 L82 58 Z" fill="#3b82f6"/>
    <circle cx="34" cy="62" r="7" fill="#0f172a" stroke="#93c5fd" stroke-width="3"/>
    <circle cx="68" cy="62" r="7" fill="#0f172a" stroke="#93c5fd" stroke-width="3"/>
    <path d="M36 44 L44 44 L44 52 L30 52 Z" fill="#93c5fd"/>
    <path d="M48 44 L60 44 L66 52 L48 52 Z" fill="#93c5fd"/>
  `),
  vip: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <polygon points="24,62 30,34 42,48 50,30 58,48 70,34 76,62" fill="#f59e0b" stroke="#fbbf24" stroke-width="2"/>
    <rect x="24" y="62" width="52" height="8" rx="2" fill="#d97706"/>
  `),
  svip: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <polygon points="50,18 78,34 70,72 50,86 30,72 22,34" fill="#4c1d95" stroke="#a855f7" stroke-width="3"/>
    <polygon points="50,28 54,40 66,40 56,48 60,60 50,52 40,60 44,48 34,40 46,40" fill="#f59e0b"/>
  `),
  general: svgWrap(`
    <rect width="100" height="100" rx="16" fill="#0f172a"/>
    <polygon points="50,24 76,44 64,76 36,76 24,44" fill="#3b82f6" stroke="#60a5fa" stroke-width="3"/>
    <circle cx="50" cy="50" r="8" fill="#ffffff"/>
  `),
};

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
  admin: { badge: 'roles/admin_badge.webp', frame: 'roles/admin_frame.webp' },
  agency: { badge: 'roles/agency_tag.webp', frame: 'roles/agency_frame.webp' },
  assistant: { badge: 'roles/assistant_tag.webp', frame: 'roles/assistant_frame.webp' },
  bd: { badge: 'roles/bd_tag.webp', frame: 'roles/bd_frame.webp' },
  boss: { badge: 'roles/boss_tag.webp', frame: 'roles/boss_frame.webp' },
  ceo: { badge: 'roles/ceo_tag.webp', frame: 'roles/ceo_frame.webp' },
  coins_seller: { badge: 'roles/coins_saller_tag.webp', frame: 'roles/coins_saller_frame.webp' },
  coin_seller: { badge: 'roles/coins_saller_tag.webp', frame: 'roles/coins_saller_frame.webp' },
  cs: { badge: 'roles/cs_badge.webp', frame: 'roles/cs_frame.webp' },
  game_master: { badge: 'roles/game_master_badge.webp', frame: 'roles/game_master_frame.webp' },
  host: { badge: 'roles/host_badge.webp', frame: 'roles/host_frame.webp' },
  lover: { badge: 'roles/lover_tag.webp', frame: 'roles/lover_frame.webp' },
  manager: { badge: 'roles/manager_tag.webp', frame: 'roles/manager_frame.webp' },
  merchant: { badge: 'roles/marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  marchent: { badge: 'roles/marchent_badge.webp', frame: 'roles/marchent_frame.webp' },
  official: { badge: 'roles/official_tag.webp', frame: 'roles/official_frame.webp' },
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
  'assets/nobles/tier-6-king_profilecard.webp': 'nobles/king_card.webp',
  '/assets/nobles/tier-6-king_profilecard.webp': 'nobles/king_card.webp',
  'nobles/tier-6-king_profilecard.webp': 'nobles/king_card.webp',
  'assets/cars/suv_black.png': 'images/gift_supercar.jpg',
  '/assets/cars/suv_black.png': 'images/gift_supercar.jpg',
  'assets/frames/warrior.png': 'nobles/king_frame.webp',
  '/assets/frames/warrior.png': 'nobles/king_frame.webp',
  'assets/frames/spider.png': 'nobles/emperor_frame.webp',
  '/assets/frames/spider.png': 'nobles/emperor_frame.webp',
  'assets/bubbles/unicorn.png': 'animations/mystery_bubble.webp',
  '/assets/bubbles/unicorn.png': 'animations/mystery_bubble.webp',
};

// Raw CDN base where all 932 static assets are tracked in Git
export const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/devsynxoffical/zeparty/main/mobile%20app/assets';

// Backend origin for dynamic /uploads
const API_BASE = (typeof import.meta !== 'undefined' && import.meta.env?.VITE_API_BASE_URL) || 'https://zeparty-backend-production.up.railway.app/api';
const BACKEND_HOST = API_BASE.replace(/\/api\/?$/, '');

// Configurable media base URL with raw GitHub CDN fallback
export const MEDIA_BASE_URL = (typeof import.meta !== 'undefined' && import.meta.env?.VITE_MEDIA_BASE_URL)
  ? import.meta.env.VITE_MEDIA_BASE_URL.replace(/\/+$/, '')
  : GITHUB_RAW_BASE;

/**
 * Builds an absolute CDN URL for any relative asset path
 */
function buildAssetUrl(subPath) {
  const cleanSub = String(subPath).replace(/^\/+/, '').replace(/^assets\//, '');
  return `${MEDIA_BASE_URL}/${encodeURI(cleanSub)}`;
}

/**
 * Resolves any image URL or asset key to an accessible, valid URL with appropriate fallbacks.
 *
 * @param {string} url - The raw URL or path stored in the database or returned by API.
 * @param {string} type - Asset type for fallback ('gift', 'frame', 'badge', 'emoji', etc.)
 * @returns {string} The resolved URL suitable for `<img src="...">`.
 */
export function resolveMediaUrl(url, type = 'general') {
  if (!url || typeof url !== 'string' || !url.trim()) {
    return FALLBACK_ASSETS[type] || FALLBACK_ASSETS.general;
  }

  const clean = url.trim();

  // Explicit known typo overrides
  if (LEGACY_OVERRIDES[clean]) {
    return buildAssetUrl(LEGACY_OVERRIDES[clean]);
  }

  // Handle dummy test URLs
  if (clean.startsWith('http://example.com/')) {
    return FALLBACK_ASSETS[type] || FALLBACK_ASSETS.gift;
  }

  // Map legacy / placeholder CDN domains to verified local assets
  if (clean.includes('assets.zeparty.app') || clean.includes('cdn.zeparty.app') || clean.includes('cdn.zeparty.io')) {
    if (clean.includes('cyber_neon')) {
      return buildAssetUrl('images/frame_neon.jpg');
    }
    if (clean.includes('car_gold')) {
      return buildAssetUrl('animations/mystery_entry.webp');
    }

    // Gift CDN matches
    if (clean.includes('cdn.zeparty.app/gifts/')) {
      const giftName = clean.split('gifts/')[1]?.replace(/\.[^.]+$/, '');
      if (giftName === 'rose') return buildAssetUrl('images/gift_rose.jpg');
      if (giftName === 'heart') return buildAssetUrl('gifts/classic/CG05_Heart_Hands_500_coins.png');
      if (giftName === 'car') return buildAssetUrl('images/gift_supercar.jpg');
      if (giftName === 'jet') return buildAssetUrl('gifts/classic/CG23_Private_Jet_22000_coins.png');
      if (giftName === 'crown') return buildAssetUrl('images/gift_gold_crown.jpg');
      if (giftName === 'castle') return buildAssetUrl('gifts/classic/CG26_Crystal_Castle_35000_coins.png');
      if (giftName === 'firework') return buildAssetUrl('gifts/classic/CG29_Meteor_Storm_60000_coins.png');
      if (giftName === 'wand') return buildAssetUrl('gifts/classic/CG14_Magic_Lamp_4000_coins.png');
      return FALLBACK_ASSETS[type] || FALLBACK_ASSETS.gift;
    }

    // Role assets
    const roleMatch = clean.match(/roles\/(badge|frame)_([a-z_]+)/);
    if (roleMatch) {
      const mType = roleMatch[1];
      const role = roleMatch[2];
      if (ROLE_ASSETS[role]) {
        return buildAssetUrl(mType === 'frame' ? ROLE_ASSETS[role].frame : ROLE_ASSETS[role].badge);
      }
    }

    // Noble assets
    const nobleMatch = clean.match(/(?:noble|nobles)\/(frame|tag|bag|entry)_noble_(\d+)/);
    if (nobleMatch) {
      const mType = nobleMatch[1];
      const num = parseInt(nobleMatch[2], 10);
      const tier = NOBLE_TIERS[Math.min(num, 7)] || 'baron';

      if (mType === 'frame') return buildAssetUrl(`nobles/${tier}_frame.webp`);
      if (mType === 'tag' || mType === 'bag') return buildAssetUrl(`nobles/${tier}_badge.webp`);
      if (mType === 'entry') return buildAssetUrl(num >= 6 ? 'nobles/emperor_entrance.webp' : (num >= 5 ? 'nobles/duke_entrance.webp' : 'nobles/marquis_entrance.webp'));
    }

    // Mystery assets
    const mysteryMatch = clean.match(/mystery\/(frame|entry|bubble|tag|bag)_mystery_(\d+)/);
    if (mysteryMatch) {
      const mType = mysteryMatch[1];
      if (mType === 'frame') return buildAssetUrl('animations/mystery_frame.webp');
      if (mType === 'entry') return buildAssetUrl('animations/mystery_entry.webp');
      if (mType === 'bubble') return buildAssetUrl('animations/mystery_bubble.webp');
      return buildAssetUrl('animations/mystery_badge.webp');
    }

    // SVIP assets
    const svipMatch = clean.match(/svip\/(badge|frame|entry|bubble)_svip_(\d+)/);
    if (svipMatch) {
      const mType = svipMatch[1];
      const num = svipMatch[2];
      if (mType === 'badge') return buildAssetUrl(`svip/svip${num}_badge.webp`);
      if (mType === 'frame') return buildAssetUrl(`svip/svip${num}_frame.webp`);
      if (mType === 'entry') return buildAssetUrl(`svip/svip${num}_entry.webp`);
      if (mType === 'bubble') return buildAssetUrl(`svip/svip${num}_chat_bubble.webp`);
    }

    return FALLBACK_ASSETS[type] || FALLBACK_ASSETS.general;
  }

  // Dynamic uploads (hosted on backend server)
  if (clean.startsWith('/uploads/') || clean.startsWith('uploads/')) {
    const rel = clean.replace(/^\/+/, '');
    return `${BACKEND_HOST}/${rel}`;
  }

  // Already fully-qualified URL or data URI
  if (clean.startsWith('blob:') || clean.startsWith('data:')) {
    return clean;
  }
  if (clean.startsWith('http://') || clean.startsWith('https://')) {
    // If it points to an inaccessible localhost or backend asset URL, route to CDN
    if (clean.includes('/assets/')) {
      const sub = clean.split('/assets/')[1];
      if (sub) return buildAssetUrl(sub);
    }
    return clean;
  }

  // Static visual assets (/assets/... or assets/...)
  if (clean.startsWith('/assets/') || clean.startsWith('assets/')) {
    return buildAssetUrl(clean);
  }

  // Default to relative asset subpath
  return buildAssetUrl(clean);
}

/**
 * Handle `<img onError={...} />` to replace broken images with a verified fallback.
 */
export function handleImageError(e, type = 'general') {
  if (!e || !e.target) return;
  const currentSrc = e.target.src || '';
  const fallback = FALLBACK_ASSETS[type] || FALLBACK_ASSETS.general;

  // If already at an inline SVG data URI, prevent any further loops
  if (currentSrc.startsWith('data:image/svg+xml') || currentSrc === fallback) {
    e.target.onerror = null;
    return;
  }

  // If failed on a local path or custom URL that wasn't GitHub raw, attempt GitHub raw before SVG fallback
  if (currentSrc.includes('/assets/') && !currentSrc.includes('raw.githubusercontent.com')) {
    const assetPath = currentSrc.split('/assets/')[1];
    if (assetPath) {
      e.target.src = `${GITHUB_RAW_BASE}/${encodeURI(assetPath.replace(/^\/+/, ''))}`;
      return;
    }
  }

  // Guaranteed fallback: inline SVG data URI (cannot 404)
  e.target.onerror = null;
  e.target.src = fallback;
}

export default {
  resolveMediaUrl,
  handleImageError,
  FALLBACK_ASSETS,
  MEDIA_BASE_URL,
  GITHUB_RAW_BASE,
};
