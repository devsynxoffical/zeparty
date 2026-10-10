import prisma from '../config/database.js';
import bannerRepository from '../repositories/banner.repository.js';
import socketEmitter from '../socket/socket.emitter.js';

export const DEFAULT_BANNER_TEMPLATES = [
  {
    title: '🎉 Welcome to ZeParty!',
    imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://party',
    position: 1,
    isActive: true,
  },
  {
    title: '🚀 Big Updates Coming Soon!',
    imageUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://updates',
    position: 2,
    isActive: true,
  },
  {
    title: '⚔️ Epic PK Battles & Live Streaming',
    imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://live',
    position: 3,
    isActive: true,
  },
  {
    title: '🎁 Send Luxury Gifts & Win Big',
    imageUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=1200&h=400&q=80',
    destinationUrl: 'zeparty://store',
    position: 4,
    isActive: true,
  },
];

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || 'SYSTEM',
        adminName: adminName || 'System',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in banner.service:', err);
  }
}

export async function createBanner(
  data,
  { adminId, adminName, ipAddress } = {},
  db = prisma
) {
  const banner = await bannerRepository.createBanner(data, db);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'BANNER_CREATED',
      targetEntity: 'Banner',
      targetEntityId: banner.id,
      afterStateJson: banner,
      ipAddress,
    },
    db
  );

  try {
    socketEmitter.broadcastGlobal('banner:created', banner);
    socketEmitter.broadcastGlobal('banner:updated', banner);
  } catch (_) {}

  return banner;
}

export async function getActiveBanners(userCountryCode, db = prisma) {
  let banners = await bannerRepository.findActiveBanners(new Date(), db);
  
  // Auto-seed default rich templates if table is completely empty
  if (!banners || banners.length === 0) {
    try {
      const count = await db.banner.count();
      if (count === 0) {
        for (const tpl of DEFAULT_BANNER_TEMPLATES) {
          await bannerRepository.createBanner(tpl, db);
        }
        banners = await bannerRepository.findActiveBanners(new Date(), db);
      }
    } catch (seedErr) {
      console.warn('[BannerService] Auto-seed notice:', seedErr.message);
    }
  }

  if (userCountryCode && userCountryCode !== 'GLOBAL') {
    const targetCountry = String(userCountryCode).toUpperCase();
    banners = banners.filter((b) => {
      // If banner has specific country targeting, enforce matching
      if (b.targetType === 'COUNTRY_WISE' && b.countries) {
        const countryArr = Array.isArray(b.countries)
          ? b.countries.map((c) => String(c).toUpperCase())
          : String(b.countries).split(',').map((c) => c.trim().toUpperCase());
        return countryArr.includes(targetCountry);
      }
      return true; // Global banners
    });
  }

  return banners;
}


export async function getBannerById(id, db = prisma) {
  const banner = await bannerRepository.findBannerById(id, db);
  if (!banner) {
    const error = new Error('Banner not found');
    error.statusCode = 404;
    error.code = 'BANNER_NOT_FOUND';
    throw error;
  }
  return banner;
}

export async function listBannersForAdmin(filters, db = prisma) {
  return await bannerRepository.findAdminBanners(filters, db);
}

export async function updateBanner(
  id,
  data,
  { adminId, adminName, ipAddress } = {},
  db = prisma
) {
  const existing = await bannerRepository.findBannerById(id, db);
  if (!existing) {
    const error = new Error('Banner not found');
    error.statusCode = 404;
    error.code = 'BANNER_NOT_FOUND';
    throw error;
  }

  const updated = await bannerRepository.updateBanner(id, data, db);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'BANNER_UPDATED',
      targetEntity: 'Banner',
      targetEntityId: id,
      beforeStateJson: existing,
      afterStateJson: updated,
      ipAddress,
    },
    db
  );

  try {
    socketEmitter.broadcastGlobal('banner:updated', updated);
  } catch (_) {}

  return updated;
}

export async function deleteBanner(
  id,
  { adminId, adminName, ipAddress } = {},
  db = prisma
) {
  const existing = await bannerRepository.findBannerById(id, db);
  if (!existing) {
    const error = new Error('Banner not found');
    error.statusCode = 404;
    error.code = 'BANNER_NOT_FOUND';
    throw error;
  }

  await bannerRepository.deleteBanner(id, db);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'BANNER_DELETED',
      targetEntity: 'Banner',
      targetEntityId: id,
      beforeStateJson: existing,
      ipAddress,
    },
    db
  );

  try {
    socketEmitter.broadcastGlobal('banner:deleted', { id });
    socketEmitter.broadcastGlobal('banner:updated', { id, isDeleted: true });
  } catch (_) {}

  return { success: true, id };
}

export default {
  createBanner,
  getActiveBanners,
  getBannerById,
  listBannersForAdmin,
  updateBanner,
  deleteBanner,
};
