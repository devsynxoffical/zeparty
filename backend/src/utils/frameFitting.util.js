/**
 * ZeParty Avatar Frame Fitting & Normalization Utility
 * BUG #36: Avatar Frame Fitting Across Complete Catalog
 *
 * Provides authoritative normalized fitting metadata (scale, X/Y offsets,
 * opening diameter ratio, center ratios, aspect ratio) for every catalog frame.
 */

export const DEFAULT_FRAME_FITTING = Object.freeze({
  scale: 1.55,
  offsetX: 0.0,
  offsetY: 0.0,
  openingDiameterRatio: 0.64,
  centerRatioX: 0.50,
  centerRatioY: 0.50,
  aspectRatio: 1.00,
});

/**
 * Calibrated fitting metadata per frame key / asset path.
 * Keys match lowercase filenames, asset keys, or canonical item IDs.
 */
export const FRAME_FITTING_CATALOG = Object.freeze({
  // --- High-Crown Nobles (Top-heavy crown, center of circle is pushed down) ---
  'king': {
    scale: 1.62,
    offsetX: 0.0,
    offsetY: 0.045,
    openingDiameterRatio: 0.62,
    centerRatioX: 0.50,
    centerRatioY: 0.535,
    aspectRatio: 1.00,
  },
  'emperor': {
    scale: 1.65,
    offsetX: 0.0,
    offsetY: 0.050,
    openingDiameterRatio: 0.61,
    centerRatioX: 0.50,
    centerRatioY: 0.540,
    aspectRatio: 1.00,
  },
  'duke': {
    scale: 1.58,
    offsetX: 0.0,
    offsetY: 0.030,
    openingDiameterRatio: 0.63,
    centerRatioX: 0.50,
    centerRatioY: 0.525,
    aspectRatio: 1.00,
  },
  'marquis': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.020,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.515,
    aspectRatio: 1.00,
  },
  'count': {
    scale: 1.54,
    offsetX: 0.0,
    offsetY: 0.010,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.510,
    aspectRatio: 1.00,
  },
  'viscount': {
    scale: 1.52,
    offsetX: 0.0,
    offsetY: 0.000,
    openingDiameterRatio: 0.65,
    centerRatioX: 0.50,
    centerRatioY: 0.500,
    aspectRatio: 1.00,
  },
  'baron': {
    scale: 1.50,
    offsetX: 0.0,
    offsetY: 0.000,
    openingDiameterRatio: 0.66,
    centerRatioX: 0.50,
    centerRatioY: 0.500,
    aspectRatio: 1.00,
  },

  // --- Official & Role Frames ---
  'host': {
    scale: 1.60,
    offsetX: 0.0,
    offsetY: 0.035,
    openingDiameterRatio: 0.63,
    centerRatioX: 0.50,
    centerRatioY: 0.528,
    aspectRatio: 1.00,
  },
  'admin': {
    scale: 1.58,
    offsetX: 0.0,
    offsetY: 0.025,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.520,
    aspectRatio: 1.00,
  },
  'super_admin': {
    scale: 1.62,
    offsetX: 0.0,
    offsetY: 0.040,
    openingDiameterRatio: 0.62,
    centerRatioX: 0.50,
    centerRatioY: 0.530,
    aspectRatio: 1.00,
  },
  'agency': {
    scale: 1.56,
    offsetX: 0.0,
    offsetY: 0.020,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.515,
    aspectRatio: 1.00,
  },
  'boss': {
    scale: 1.60,
    offsetX: 0.0,
    offsetY: 0.035,
    openingDiameterRatio: 0.63,
    centerRatioX: 0.50,
    centerRatioY: 0.525,
    aspectRatio: 1.00,
  },
  'ceo': {
    scale: 1.58,
    offsetX: 0.0,
    offsetY: 0.025,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.520,
    aspectRatio: 1.00,
  },
  'coins_saller': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },
  'coins_seller': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },
  'marchent': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },
  'merchant': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },
  'game_master': {
    scale: 1.57,
    offsetX: 0.0,
    offsetY: 0.020,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.516,
    aspectRatio: 1.00,
  },
  'official': {
    scale: 1.56,
    offsetX: 0.0,
    offsetY: 0.020,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.515,
    aspectRatio: 1.00,
  },
  'top_fan': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },
  'lover': {
    scale: 1.53,
    offsetX: 0.0,
    offsetY: 0.010,
    openingDiameterRatio: 0.65,
    centerRatioX: 0.50,
    centerRatioY: 0.508,
    aspectRatio: 1.00,
  },
  'assistant': {
    scale: 1.54,
    offsetX: 0.0,
    offsetY: 0.010,
    openingDiameterRatio: 0.65,
    centerRatioX: 0.50,
    centerRatioY: 0.510,
    aspectRatio: 1.00,
  },
  'manager': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },
  'cs': {
    scale: 1.54,
    offsetX: 0.0,
    offsetY: 0.010,
    openingDiameterRatio: 0.65,
    centerRatioX: 0.50,
    centerRatioY: 0.510,
    aspectRatio: 1.00,
  },
  'bd': {
    scale: 1.55,
    offsetX: 0.0,
    offsetY: 0.015,
    openingDiameterRatio: 0.64,
    centerRatioX: 0.50,
    centerRatioY: 0.512,
    aspectRatio: 1.00,
  },

  // --- SVIP Frames ---
  'svip1': { scale: 1.52, offsetX: 0.0, offsetY: 0.005, openingDiameterRatio: 0.65, centerRatioX: 0.50, centerRatioY: 0.505, aspectRatio: 1.00 },
  'svip2': { scale: 1.52, offsetX: 0.0, offsetY: 0.005, openingDiameterRatio: 0.65, centerRatioX: 0.50, centerRatioY: 0.505, aspectRatio: 1.00 },
  'svip3': { scale: 1.54, offsetX: 0.0, offsetY: 0.010, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.510, aspectRatio: 1.00 },
  'svip4': { scale: 1.54, offsetX: 0.0, offsetY: 0.010, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.510, aspectRatio: 1.00 },
  'svip5': { scale: 1.55, offsetX: 0.0, offsetY: 0.015, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.512, aspectRatio: 1.00 },
  'svip6': { scale: 1.56, offsetX: 0.0, offsetY: 0.020, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.515, aspectRatio: 1.00 },
  'svip7': { scale: 1.56, offsetX: 0.0, offsetY: 0.020, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.515, aspectRatio: 1.00 },
  'svip8': { scale: 1.58, offsetX: 0.0, offsetY: 0.025, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.520, aspectRatio: 1.00 },
  'svip9': {
    // 512x460 non-square asset compensation
    scale: 1.60,
    offsetX: 0.0,
    offsetY: 0.045,
    openingDiameterRatio: 0.62,
    centerRatioX: 0.50,
    centerRatioY: 0.538,
    aspectRatio: 1.113,
  },
  'svip10': { scale: 1.60, offsetX: 0.0, offsetY: 0.035, openingDiameterRatio: 0.62, centerRatioX: 0.50, centerRatioY: 0.528, aspectRatio: 1.00 },
  'svip11': { scale: 1.60, offsetX: 0.0, offsetY: 0.035, openingDiameterRatio: 0.62, centerRatioX: 0.50, centerRatioY: 0.528, aspectRatio: 1.00 },
  'svip12': { scale: 1.62, offsetX: 0.0, offsetY: 0.040, openingDiameterRatio: 0.61, centerRatioX: 0.50, centerRatioY: 0.532, aspectRatio: 1.00 },
  'svip13': { scale: 1.62, offsetX: 0.0, offsetY: 0.040, openingDiameterRatio: 0.61, centerRatioX: 0.50, centerRatioY: 0.532, aspectRatio: 1.00 },
  'svip14': { scale: 1.64, offsetX: 0.0, offsetY: 0.045, openingDiameterRatio: 0.61, centerRatioX: 0.50, centerRatioY: 0.536, aspectRatio: 1.00 },
  'svip15': { scale: 1.65, offsetX: 0.0, offsetY: 0.050, openingDiameterRatio: 0.60, centerRatioX: 0.50, centerRatioY: 0.540, aspectRatio: 1.00 },
  'svip16': {
    // 923x1704 full profile skin card format
    scale: 1.00,
    offsetX: 0.0,
    offsetY: 0.0,
    openingDiameterRatio: 1.00,
    centerRatioX: 0.50,
    centerRatioY: 0.50,
    aspectRatio: 0.542,
    isFullProfileSkin: true,
  },

  // --- Store Standard Frames (ZP-134 to ZP-143) ---
  'zp-134': { scale: 1.55, offsetX: 0.0, offsetY: 0.015, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.512, aspectRatio: 1.00 },
  'zp-135': { scale: 1.58, offsetX: 0.0, offsetY: 0.030, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.524, aspectRatio: 1.00 },
  'zp-136': { scale: 1.55, offsetX: 0.0, offsetY: 0.010, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.508, aspectRatio: 1.00 },
  'zp-137': { scale: 1.55, offsetX: 0.0, offsetY: 0.015, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.512, aspectRatio: 1.00 },
  'zp-138': { scale: 1.54, offsetX: 0.0, offsetY: 0.010, openingDiameterRatio: 0.65, centerRatioX: 0.50, centerRatioY: 0.508, aspectRatio: 1.00 },
  'zp-139': { scale: 1.58, offsetX: 0.0, offsetY: 0.025, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.520, aspectRatio: 1.00 },
  'zp-140': { scale: 1.55, offsetX: 0.0, offsetY: 0.015, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.512, aspectRatio: 1.00 },
  'zp-141': { scale: 1.54, offsetX: 0.0, offsetY: 0.010, openingDiameterRatio: 0.65, centerRatioX: 0.50, centerRatioY: 0.508, aspectRatio: 1.00 },
  'zp-142': { scale: 1.55, offsetX: 0.0, offsetY: 0.015, openingDiameterRatio: 0.64, centerRatioX: 0.50, centerRatioY: 0.512, aspectRatio: 1.00 },
  'zp-143': { scale: 1.56, offsetX: 0.0, offsetY: 0.020, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.515, aspectRatio: 1.00 },
  'mystery': { scale: 1.56, offsetX: 0.0, offsetY: 0.020, openingDiameterRatio: 0.63, centerRatioX: 0.50, centerRatioY: 0.515, aspectRatio: 1.00 },
});

/**
 * Resolves normalized fitting metadata for any frame asset.
 * @param {string|object} assetOrPath Asset object, file path, name, or key
 * @returns {object} Validated fitting metadata with safe default fallback
 */
export function resolveFrameFitting(assetOrPath) {
  if (!assetOrPath) return { ...DEFAULT_FRAME_FITTING };

  let key = '';
  if (typeof assetOrPath === 'string') {
    key = assetOrPath.toLowerCase();
  } else if (typeof assetOrPath === 'object') {
    key = (
      assetOrPath.id ||
      assetOrPath.key ||
      assetOrPath.thumbnailUrl ||
      assetOrPath.imageUrl ||
      assetOrPath.staticFileUrl ||
      assetOrPath.animationFileUrl ||
      assetOrPath.name ||
      ''
    ).toLowerCase();
  }

  // Normalize key from filename or path (e.g. "assets/nobles/king_frame.webp" -> "king")
  const cleaned = key.replace(/\\/g, '/').split('/').pop() || key;
  const stripped = cleaned
    .replace(/_frame\.(webp|png|jpg|jpeg|gif)$/i, '')
    .replace(/^frame_/, '')
    .replace(/^role_frame_/, '')
    .replace(/^noble_frame_/, '')
    .replace(/^svip_frame_/, 'svip')
    .replace(/-avatar-frames_frame\.(webp|png)$/i, '')
    .replace(/^zp-/, 'zp-')
    .trim();

  // Try exact stripped match
  if (FRAME_FITTING_CATALOG[stripped]) {
    return { ...FRAME_FITTING_CATALOG[stripped] };
  }

  // Try key contains match
  for (const [catalogKey, meta] of Object.entries(FRAME_FITTING_CATALOG)) {
    if (stripped === catalogKey || stripped.includes(catalogKey) || key.includes(catalogKey)) {
      return { ...meta };
    }
  }

  return { ...DEFAULT_FRAME_FITTING };
}

export default {
  DEFAULT_FRAME_FITTING,
  FRAME_FITTING_CATALOG,
  resolveFrameFitting,
};
