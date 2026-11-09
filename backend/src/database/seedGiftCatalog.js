import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import prisma from '../config/database.js';

const CATALOG_FILE = path.join(path.dirname(fileURLToPath(import.meta.url)), '../constants/giftCatalog.json');
let cached = null;
function loadCatalog() {
  if (!cached) cached = JSON.parse(fs.readFileSync(CATALOG_FILE, 'utf8'));
  return cached;
}

/**
 * Keeps the Gift table in sync with the canonical catalog that ships inside the mobile
 * app (src/constants/giftCatalog.json, generated from the app's AnimatedGiftsCatalog).
 *
 * Why: production only had 50 of the app's 119 gifts. Sending any other gift made the
 * server auto-create it at a flat 100 coins (whatever its real price), or made the app
 * fall back to a sender-only "local delivery" that nobody else in the room ever saw.
 * Runs on every startup; upsert by id, so admin-edited cut percentages are preserved and
 * only name / price / assets / flags are refreshed.
 */
export async function seedGiftCatalog(db = prisma) {
  const catalog = loadCatalog();
  let created = 0;
  let updated = 0;
  for (const g of catalog) {
    const data = {
      name: g.name,
      coinValue: BigInt(g.coinValue),
      giftCategory: g.giftCategory,
      iconUrl: g.iconUrl,
      svgaAssetUrl: g.svgaAssetUrl ?? null,
      isAnimated: Boolean(g.isAnimated),
      isFullScreen: Boolean(g.isFullScreen),
      isActive: true,
    };
    const existing = await db.gift.findUnique({ where: { id: g.id }, select: { id: true } });
    if (existing) {
      await db.gift.update({ where: { id: g.id }, data });
      updated += 1;
    } else {
      await db.gift.create({ data: { id: g.id, ...data } });
      created += 1;
    }
  }
  console.log(`🎁 Gift catalog synced: ${catalog.length} gifts (${created} created, ${updated} updated)`);
  return { created, updated, total: catalog.length };
}

/** Case-insensitive lookup by id, then by name, against the canonical catalog. */
export function resolveCatalogGiftId(idOrName) {
  if (!idOrName) return null;
  const needle = String(idOrName).trim().toLowerCase();
  const catalog = loadCatalog();
  const hit = catalog.find((g) => g.id.toLowerCase() === needle) || catalog.find((g) => g.name.toLowerCase() === needle);
  return hit ? hit.id : null;
}
