/**
 * ZeParty Asset Classification & Security Utility
 * CHANGE 16: Public Store Catalog Eligibility & Special Asset Isolation
 *
 * Defines authoritative rules to distinguish public store items from
 * restricted/privileged/special assets (SVIP, Noble, BD, Official, and Role badges).
 */

export const RESTRICTED_ROLE_IDS = [
  'role_badge_admin',
  'role_frame_admin',
  'badge_role_admin',
  'role_badge_super_admin',
  'role_frame_super_admin',
  'badge_role_super_admin',
  'role_badge_agency',
  'role_frame_agency',
  'badge_role_agency',
  'role_badge_assistant',
  'role_frame_assistant',
  'badge_role_assistant',
  'role_badge_bd',
  'role_frame_bd',
  'badge_role_bd',
  'role_badge_boss',
  'role_frame_boss',
  'badge_role_boss',
  'role_badge_ceo',
  'role_frame_ceo',
  'badge_role_ceo',
  'role_badge_coins_seller',
  'role_frame_coins_seller',
  'badge_role_coins_seller',
  'role_badge_cs',
  'role_frame_cs',
  'badge_role_cs',
  'role_badge_game_master',
  'role_frame_game_master',
  'badge_role_game_master',
  'role_badge_host',
  'role_frame_host',
  'badge_role_host',
  'role_badge_lover',
  'role_frame_lover',
  'badge_role_lover',
  'role_badge_manager',
  'role_frame_manager',
  'badge_role_manager',
  'role_badge_merchant',
  'role_frame_merchant',
  'badge_role_merchant',
  'role_badge_official',
  'role_frame_official',
  'badge_role_official',
  'role_badge_top_fan',
  'role_frame_top_fan',
  'badge_role_top_fan',
  'role_badge_vip',
  'role_frame_vip',
  'role_badge_svip',
  'role_frame_svip',
];

export const RESTRICTED_SVIP_BADGE_IDS = [
  'badge_zp054', // SVIP Star Badge
  'badge_zp056', // Royalty Crown Badge
  'badge_zp065', // Cyber Elite Badge
  'badge_zp079', // Gold Phoenix Badge
  'badge_zp093', // SVIP 10 Dragon Badge
  'card_zp098',  // SVIP 10 Dragon Profile Card
  'frame_zp097', // SVIP 10 Dragon Profile Frame
  'badge_zp100', // Imperial Dragon Badge
  'badge_zp127', // Supreme Sovereign Badge
];

export const RESTRICTED_NAME_KEYPHRASES = [
  'official',
  'top fan patron',
  'top fan elite',
  'game master',
  'recharge merchant',
  'zeparty official',
  'svip premier',
  'vip member',
  'admin role',
  'agency master',
  'assistant officer',
  'bd director',
  'grand boss',
  'ceo executive',
  'coins merchant',
  'customer support',
  'star host',
  'general manager',
  'super admin',
  'business development',
  'aristocracy',
];

/**
 * Returns true if the asset is classified as a Special / Privileged / Restricted asset.
 * Restricted assets must never appear in public store endpoints and cannot be purchased directly.
 */
export function isRestrictedSpecialAsset(asset) {
  if (!asset) return false;

  // 1. Explicit booleans if populated
  if (asset.isSpecial === true) return true;
  if (asset.isPublic === false) return true;

  const id = String(asset.id || '').toLowerCase();
  const name = String(asset.name || '').toLowerCase();
  const rawType = String(asset.assetType || '').toUpperCase();

  // 2. Direct ID matches
  if (RESTRICTED_ROLE_IDS.includes(id)) return true;
  if (RESTRICTED_SVIP_BADGE_IDS.includes(id)) return true;

  // 3. ID Prefix checks
  if (id.startsWith('role_') || id.startsWith('badge_role_') || id.startsWith('frame_role_')) {
    return true;
  }
  if (id.startsWith('svip_') || id.startsWith('ast-svip-')) {
    return true;
  }
  if (id.startsWith('noble_') || id.startsWith('ast-noble-')) {
    return true;
  }

  // 4. BD specific checks
  if (id.includes('_bd') || id.startsWith('bd_') || /\bbd\b/i.test(name)) {
    return true;
  }

  // 5. Official ZeParty items
  if (id.includes('official') || name.includes('official')) {
    return true;
  }

  // 6. Noble rank requirements or naming
  if (asset.minNobleRankRequired != null && String(asset.minNobleRankRequired).trim() !== '') {
    return true;
  }
  if (name.startsWith('noble ') || name.includes('aristocracy')) {
    return true;
  }

  // 7. SVIP tier badges and frames
  if (name.includes('svip') && (rawType === 'BADGE' || rawType === 'FRAME')) {
    return true;
  }

  // 8. Restricted name keyphrases
  for (const phrase of RESTRICTED_NAME_KEYPHRASES) {
    if (name.includes(phrase)) {
      return true;
    }
  }

  return false;
}

/**
 * Returns true if an asset is valid for public store display and purchase.
 */
export function isPublicStoreItem(asset) {
  if (!asset) return false;
  if (!asset.isActive) return false;
  return !isRestrictedSpecialAsset(asset);
}

/**
 * Returns Prisma OR-conditions matching restricted special assets.
 * Used with `NOT: getPrismaRestrictedAssetWhereClauses()` in store catalog queries.
 */
export function getPrismaRestrictedAssetWhereClauses() {
  return [
    { id: { startsWith: 'role_' } },
    { id: { startsWith: 'badge_role_' } },
    { id: { startsWith: 'frame_role_' } },
    { id: { startsWith: 'svip_' } },
    { id: { startsWith: 'noble_' } },
    { id: { startsWith: 'ast-noble' } },
    { id: { startsWith: 'ast-svip' } },
    { id: { in: RESTRICTED_SVIP_BADGE_IDS } },
    { name: { contains: 'Official', mode: 'insensitive' } },
    { name: { contains: 'Top Fan Patron', mode: 'insensitive' } },
    { name: { contains: 'Game Master', mode: 'insensitive' } },
    { name: { contains: 'Recharge Merchant', mode: 'insensitive' } },
    { name: { contains: 'SVIP Premier', mode: 'insensitive' } },
    { name: { contains: 'VIP Member', mode: 'insensitive' } },
    { name: { contains: 'Role Badge', mode: 'insensitive' } },
    { name: { contains: 'Aristocracy', mode: 'insensitive' } },
    { name: { contains: 'BD Director', mode: 'insensitive' } },
    { name: { contains: 'Business Development', mode: 'insensitive' } },
    { minNobleRankRequired: { not: null } },
  ];
}

export default {
  RESTRICTED_ROLE_IDS,
  RESTRICTED_SVIP_BADGE_IDS,
  RESTRICTED_NAME_KEYPHRASES,
  isRestrictedSpecialAsset,
  isPublicStoreItem,
  getPrismaRestrictedAssetWhereClauses,
};
