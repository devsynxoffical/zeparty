import prisma from '../config/database.js';

export async function upsertDevice(
  { userId, deviceToken, platform = 'ANDROID', macAddress = null, deviceModel = null, appVersion = null },
  db = prisma
) {
  if (!deviceToken && !macAddress) return null;

  // Search existing device record for this user
  const existing = await db.userDevice.findFirst({
    where: {
      userId,
      OR: [
        ...(deviceToken ? [{ deviceToken }] : []),
        ...(macAddress ? [{ macAddress }] : []),
      ],
    },
  });

  if (existing) {
    return await db.userDevice.update({
      where: { id: existing.id },
      data: {
        platform,
        deviceModel: deviceModel || existing.deviceModel,
        appVersion: appVersion || existing.appVersion,
        lastSeenAt: new Date(),
      },
    });
  }

  return await db.userDevice.create({
    data: {
      userId,
      deviceToken,
      platform,
      macAddress,
      deviceModel,
      appVersion,
      lastSeenAt: new Date(),
    },
  });
}

export async function isDeviceBlocked({ deviceToken, macAddress }, db = prisma) {
  if (!deviceToken && !macAddress) return false;

  if (db.blockedDevice) {
    const blocked = await db.blockedDevice.findFirst({
      where: {
        OR: [
          ...(deviceToken ? [{ deviceToken }] : []),
        ],
      },
    });
    if (blocked) return true;
  }

  const userDeviceBlocked = await db.userDevice.findFirst({
    where: {
      isBlocked: true,
      OR: [
        ...(deviceToken ? [{ deviceToken }] : []),
        ...(macAddress ? [{ macAddress }] : []),
      ],
    },
  });

  return Boolean(userDeviceBlocked);
}

export async function isIpBlocked(ipAddress, db = prisma) {
  if (!ipAddress || !db.blockedIP) return false;

  const blocked = await db.blockedIP.findUnique({
    where: { ipAddress },
  });

  return Boolean(blocked);
}

export default {
  upsertDevice,
  isDeviceBlocked,
  isIpBlocked,
};
