/**
 * ZeParty Visual Assets Seeder
 * Seeds all 5 Visual Asset categories:
 * - Section 1: SVIP 1-12 Badges & Frames
 * - Section 2: Noble 1-12 Frames, Tags, Bags & Entry Effects
 * - Section 3: Mystery Frames, Tags, Bags, Entry Effects & Chat Bubbles
 * - Section 4: Role / Staff / Merchant Badges (BD, Coins Seller, Super Admin, Manager, CS, Agency, Assistant, Host, VIP, SVIP, Official, Top Fan, Merchant, Elite, Guardian, Boss, Family, Lover, Singer, Game Master, Dragon)
 * - Section 5: Matching Circular Profile Frames for all Roles
 */

import prisma from '../src/config/database.js';

const ASSET_BASE_CDN = 'https://assets.zeparty.app/visual_assets';

export const VISUAL_ASSETS_DATA = [
  // ─── SECTION 1: SVIP 1–12 (Badges & Profile Frames) ───
  ...Array.from({ length: 12 }, (_, i) => {
    const lvl = i + 1;
    const tiers = [
      '0 - 999', '1,000 - 4,999', '5,000 - 14,999', '15,000 - 29,999',
      '30,000 - 49,999', '50,000 - 79,999', '80,000 - 119,999', '120,000 - 179,999',
      '180,000 - 259,999', '260,000 - 399,999', '400,000 - 599,999', '600,000+'
    ];
    return [
      {
        id: `svip_badge_${lvl}`,
        name: `SVIP ${lvl} Level Badge`,
        assetType: 'BADGE',
        assetSubcategory: 'STATIC',
        thumbnailUrl: `${ASSET_BASE_CDN}/svip/badge_svip_${lvl}.png`,
        staticFileUrl: `${ASSET_BASE_CDN}/svip/badge_svip_${lvl}.png`,
        priceCoins: 0n,
        validDays: 30,
        isVipExclusive: true,
        minVipLevelRequired: lvl,
        isActive: true,
      },
      {
        id: `svip_frame_${lvl}`,
        name: `SVIP ${lvl} Profile Frame`,
        assetType: 'FRAME',
        assetSubcategory: 'ANIMATED_SVGA',
        thumbnailUrl: `${ASSET_BASE_CDN}/svip/frame_svip_${lvl}.png`,
        animationFileUrl: `${ASSET_BASE_CDN}/svip/frame_svip_${lvl}.svga`,
        priceCoins: 0n,
        validDays: 30,
        isVipExclusive: true,
        minVipLevelRequired: lvl,
        isActive: true,
      },
    ];
  }).flat(),

  // ─── SECTION 2: NOBLE / ARISTOCRACY 1–12 (Frames, Tags, Bags & Entry Effects) ───
  ...Array.from({ length: 12 }, (_, i) => {
    const lvl = i + 1;
    return [
      {
        id: `noble_frame_${lvl}`,
        name: `Noble ${lvl} Aristocracy Frame`,
        assetType: 'FRAME',
        assetSubcategory: 'ANIMATED_SVGA',
        thumbnailUrl: `${ASSET_BASE_CDN}/noble/frame_noble_${lvl}.png`,
        animationFileUrl: `${ASSET_BASE_CDN}/noble/frame_noble_${lvl}.svga`,
        priceCoins: BigInt(lvl * 50000),
        validDays: 30,
        minNobleRankRequired: `NOBLE_${lvl}`,
        isActive: true,
      },
      {
        id: `noble_tag_${lvl}`,
        name: `Noble ${lvl} Identity Tag`,
        assetType: 'BADGE',
        assetSubcategory: 'STATIC',
        thumbnailUrl: `${ASSET_BASE_CDN}/noble/tag_noble_${lvl}.png`,
        staticFileUrl: `${ASSET_BASE_CDN}/noble/tag_noble_${lvl}.png`,
        priceCoins: BigInt(lvl * 25000),
        validDays: 30,
        minNobleRankRequired: `NOBLE_${lvl}`,
        isActive: true,
      },
      {
        id: `noble_bag_${lvl}`,
        name: `Noble ${lvl} Aristocracy Backpack`,
        assetType: 'BADGE',
        assetSubcategory: 'STATIC',
        thumbnailUrl: `${ASSET_BASE_CDN}/noble/bag_noble_${lvl}.png`,
        staticFileUrl: `${ASSET_BASE_CDN}/noble/bag_noble_${lvl}.png`,
        priceCoins: BigInt(lvl * 30000),
        validDays: 30,
        minNobleRankRequired: `NOBLE_${lvl}`,
        isActive: true,
      },
      {
        id: `noble_entry_${lvl}`,
        name: `Noble ${lvl} Entrance Aura Effect`,
        assetType: 'ENTRY_EFFECT',
        assetSubcategory: 'ANIMATED_SVGA',
        thumbnailUrl: `${ASSET_BASE_CDN}/noble/entry_noble_${lvl}.png`,
        animationFileUrl: `${ASSET_BASE_CDN}/noble/entry_noble_${lvl}.svga`,
        priceCoins: BigInt(lvl * 80000),
        validDays: 30,
        minNobleRankRequired: `NOBLE_${lvl}`,
        isActive: true,
      },
    ];
  }).flat(),

  // ─── SECTION 3: MYSTERY SUIT / SUPER POWERS (Frames, Tags, Bags, Entry, Bubbles) ───
  ...Array.from({ length: 6 }, (_, i) => {
    const lvl = i + 1;
    return [
      {
        id: `mystery_frame_${lvl}`,
        name: `Mystery Tier ${lvl} Profile Frame`,
        assetType: 'FRAME',
        assetSubcategory: 'ANIMATED_SVGA',
        thumbnailUrl: `${ASSET_BASE_CDN}/mystery/frame_mystery_${lvl}.png`,
        animationFileUrl: `${ASSET_BASE_CDN}/mystery/frame_mystery_${lvl}.svga`,
        priceCoins: BigInt(800000),
        validDays: 30,
        isActive: true,
      },
      {
        id: `mystery_tag_${lvl}`,
        name: `Mystery Tier ${lvl} Identity Tag`,
        assetType: 'BADGE',
        assetSubcategory: 'STATIC',
        thumbnailUrl: `${ASSET_BASE_CDN}/mystery/tag_mystery_${lvl}.png`,
        staticFileUrl: `${ASSET_BASE_CDN}/mystery/tag_mystery_${lvl}.png`,
        priceCoins: BigInt(400000),
        validDays: 30,
        isActive: true,
      },
      {
        id: `mystery_bag_${lvl}`,
        name: `Mystery Tier ${lvl} Backpack`,
        assetType: 'BADGE',
        assetSubcategory: 'STATIC',
        thumbnailUrl: `${ASSET_BASE_CDN}/mystery/bag_mystery_${lvl}.png`,
        staticFileUrl: `${ASSET_BASE_CDN}/mystery/bag_mystery_${lvl}.png`,
        priceCoins: BigInt(500000),
        validDays: 30,
        isActive: true,
      },
      {
        id: `mystery_entry_${lvl}`,
        name: `Mystery Tier ${lvl} Entry Aura`,
        assetType: 'ENTRY_EFFECT',
        assetSubcategory: 'ANIMATED_SVGA',
        thumbnailUrl: `${ASSET_BASE_CDN}/mystery/entry_mystery_${lvl}.png`,
        animationFileUrl: `${ASSET_BASE_CDN}/mystery/entry_mystery_${lvl}.svga`,
        priceCoins: BigInt(800000),
        validDays: 30,
        isActive: true,
      },
      {
        id: `mystery_bubble_${lvl}`,
        name: `Mystery Tier ${lvl} Chat Bubble`,
        assetType: 'CHAT_BUBBLE',
        assetSubcategory: 'STATIC',
        thumbnailUrl: `${ASSET_BASE_CDN}/mystery/bubble_mystery_${lvl}.png`,
        staticFileUrl: `${ASSET_BASE_CDN}/mystery/bubble_mystery_${lvl}.png`,
        priceCoins: BigInt(300000),
        validDays: 30,
        isActive: true,
      },
    ];
  }).flat(),

  // ─── SECTIONS 4 & 5: ROLE / STAFF / MERCHANT / COMMUNITY BADGES & FRAMES ───
  ...[
    { code: 'BD', name: 'Business Development (BD)', color: 'Gold/Red', price: 0 },
    { code: 'COIN_SELLER', name: 'Coins Seller / Recharge Agency', color: 'Purple/Gold', price: 0 },
    { code: 'SUPER_ADMIN', name: 'Super Admin', color: 'Imperial Gold/Crown', price: 0 },
    { code: 'MANAGER', name: 'Operations Manager', color: 'Ruby Gold', price: 0 },
    { code: 'CS', name: 'Customer Service / Support', color: 'Orange Flame', price: 0 },
    { code: 'AGENCY', name: 'Agency Owner / Management', color: 'Emerald Green', price: 0 },
    { code: 'ASSISTANT', name: 'Host Assistant / Room Mod', color: 'Blue Gold', price: 0 },
    { code: 'HOST', name: 'Live / Audio Host', color: 'Neon Purple/Wings', price: 0 },
    { code: 'VIP', name: 'VIP Member', color: 'Purple Royal', price: 0 },
    { code: 'SVIP', name: 'SVIP Premier', color: 'Golden Diamond', price: 0 },
    { code: 'OFFICIAL', name: 'ZeParty Official', color: 'Cyan Sapphire Shield', price: 0 },
    { code: 'TOP_FAN', name: 'Top Fan Patron', color: 'Rose Pink Crown', price: 0 },
    { code: 'MERCHANT', name: 'Recharge Merchant', color: 'Steampunk Gold', price: 0 },
    { code: 'GAME_MASTER', name: 'Game Master', color: 'Neon Cyan Wings', price: 0 },
    { code: 'DRAGON', name: 'Dragon Guild Master', color: 'Fire Dragon Crest', price: 0 },
    { code: 'LOVER', name: 'CP Partner / Lover', color: 'Heart Valentine Rose', price: 0 },
    { code: 'ELITE', name: 'Elite Member', color: 'Gold Sapphire Star', price: 0 },
    { code: 'GUARDIAN', name: 'Room Guardian', color: 'Ruby Crest', price: 0 },
    { code: 'BOSS', name: 'Wealth Boss', color: 'Imperial Purple/Gold', price: 0 },
    { code: 'FAMILY', name: 'Family Leader', color: 'Neon Violet Wings', price: 0 },
    { code: 'SINGER', name: 'Live Vocalist / Singer', color: 'Electric Blue Crest', price: 0 },
  ].map((role) => [
    {
      id: `role_badge_${role.code.toLowerCase()}`,
      name: `${role.name} Badge`,
      assetType: 'BADGE',
      assetSubcategory: 'STATIC',
      thumbnailUrl: `${ASSET_BASE_CDN}/roles/badge_${role.code.toLowerCase()}.png`,
      staticFileUrl: `${ASSET_BASE_CDN}/roles/badge_${role.code.toLowerCase()}.png`,
      priceCoins: BigInt(role.price),
      validDays: 365,
      isActive: true,
    },
    {
      id: `role_frame_${role.code.toLowerCase()}`,
      name: `${role.name} Profile Frame`,
      assetType: 'FRAME',
      assetSubcategory: 'ANIMATED_SVGA',
      thumbnailUrl: `${ASSET_BASE_CDN}/roles/frame_${role.code.toLowerCase()}.png`,
      animationFileUrl: `${ASSET_BASE_CDN}/roles/frame_${role.code.toLowerCase()}.svga`,
      priceCoins: BigInt(role.price),
      validDays: 365,
      isActive: true,
    },
  ]).flat(),
];

export async function seedVisualAssets() {
  console.log('====================================================');
  console.log('💎 ZeParty Visual Assets Seeder: 5 Complete Sections');
  console.log('====================================================\n');

  console.log(`📦 Total Visual Assets to Upsert: ${VISUAL_ASSETS_DATA.length}`);

  let upsertedCount = 0;
  for (const item of VISUAL_ASSETS_DATA) {
    await prisma.asset.upsert({
      where: { id: item.id },
      update: {
        name: item.name,
        assetType: item.assetType,
        assetSubcategory: item.assetSubcategory,
        thumbnailUrl: item.thumbnailUrl,
        staticFileUrl: item.staticFileUrl || null,
        animationFileUrl: item.animationFileUrl || null,
        priceCoins: item.priceCoins,
        validDays: item.validDays,
        isVipExclusive: item.isVipExclusive || false,
        minVipLevelRequired: item.minVipLevelRequired || 0,
        minNobleRankRequired: item.minNobleRankRequired || null,
        isActive: true,
      },
      create: {
        id: item.id,
        name: item.name,
        assetType: item.assetType,
        assetSubcategory: item.assetSubcategory,
        thumbnailUrl: item.thumbnailUrl,
        staticFileUrl: item.staticFileUrl || null,
        animationFileUrl: item.animationFileUrl || null,
        priceCoins: item.priceCoins,
        validDays: item.validDays,
        isVipExclusive: item.isVipExclusive || false,
        minVipLevelRequired: item.minVipLevelRequired || 0,
        minNobleRankRequired: item.minNobleRankRequired || null,
        isActive: true,
      },
    });
    upsertedCount++;
  }

  console.log(`\n✅ Successfully seeded and verified ${upsertedCount} visual assets into PostgreSQL!\n`);
  return upsertedCount;
}

if (process.argv[1]?.endsWith('seed_visual_assets.js')) {
  seedVisualAssets()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('❌ Error seeding visual assets:', err);
      process.exit(1);
    });
}
