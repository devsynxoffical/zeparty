// ============================================================
// ZeParty Admin Portal — Central Media & Image URL Resolver
// Handles path resolution, local asset mapping & fallback states
// ============================================================

const FALLBACK_ASSETS = {
  gift: '/assets/images/party_gift_box.jpg',
  frame: '/assets/images/frame_neon.jpg',
  badge: '/assets/images/profile_medal.jpg',
  avatar: '/assets/images/zeparty_logo.jpg',
  emoji: '/assets/emojis/panel_icons/emoji_showlove.png',
  reaction: '/assets/emojis/reactions/emoji_showlove_reaction.webp',
  bubble: '/assets/animations/mystery_bubble.webp',
  entry: '/assets/animations/mystery_entry.webp',
  vip: '/assets/images/card_vip.jpg',
  svip: '/assets/svip/svip1_badge.webp',
  general: '/assets/images/zeparty_logo.jpg',
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
};

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
    return LEGACY_OVERRIDES[clean];
  }

  // Handle dummy test URLs
  if (clean.startsWith('http://example.com/')) {
    return FALLBACK_ASSETS[type] || FALLBACK_ASSETS.gift;
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
      return FALLBACK_ASSETS.gift;
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

    return FALLBACK_ASSETS[type] || FALLBACK_ASSETS.general;
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

  // Already fully-qualified valid URL (e.g. Unsplash, Cloudinary, Firebase)
  if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('blob:') || clean.startsWith('data:')) {
    return clean;
  }

  return clean;
}

/**
 * Handle `<img onError={...} />` to replace broken images with a verified fallback.
 */
export function handleImageError(e, type = 'general') {
  if (!e || !e.target) return;
  const fallback = FALLBACK_ASSETS[type] || FALLBACK_ASSETS.general;
  if (e.target.src !== fallback && !e.target.src.endsWith(fallback)) {
    e.target.onerror = null; // Prevent infinite loop
    e.target.src = fallback;
  }
}

export default {
  resolveMediaUrl,
  handleImageError,
  FALLBACK_ASSETS,
};
