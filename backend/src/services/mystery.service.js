import prisma from '../config/database.js';
import * as walletRepository from '../repositories/wallet.repository.js';
import * as userAssetRepository from '../repositories/userAsset.repository.js';
import * as userRepository from '../repositories/user.repository.js';
import { emitToUser, broadcastGlobal } from '../socket/socket.emitter.js';

const MYSTERY_ASSETS = [
  {
    id: 'assigned-asset-mystery-frame',
    name: 'Mystery Dynamic Avatar Frame',
    assetType: 'FRAME',
    url: 'assets/animations/mystery_frame.webp',
  },
  {
    id: 'assigned-asset-mystery-entry',
    name: 'Phantom Hypercar Entrance',
    assetType: 'ENTRY_EFFECT',
    url: 'assets/animations/mystery_entry.webp',
  },
  {
    id: 'assigned-asset-mystery-bubble',
    name: 'Mystery Chat Bubble',
    assetType: 'BUBBLE',
    url: 'assets/animations/mystery_bubble.webp',
  },
  {
    id: 'assigned-asset-mystery-medal',
    name: 'Mystic Medal',
    assetType: 'BADGE',
    url: 'assets/animations/mystery_badge.webp',
  },
  {
    id: 'assigned-asset-mystery-tag',
    name: 'Mystery Tag',
    assetType: 'TAG',
    url: 'assets/animations/mystery_tag.webp',
  },
];

export async function getMysteryStatus({ userId }, db = prisma) {
  if (!userId) return { isActive: false, expiresAt: null, durationDaysRemaining: 0 };

  const user = await userRepository.findById(userId, db);
  if (!user) return { isActive: false, expiresAt: null, durationDaysRemaining: 0 };

  // Check active Mystery asset expiry
  const activeMysteryAsset = await db.userAsset.findFirst({
    where: {
      userId,
      assetId: 'assigned-asset-mystery-frame',
      expiresAt: { gt: new Date() },
    },
    orderBy: { expiresAt: 'desc' },
  });

  const nobleRank = String(user.profile?.nobleRank || '').toUpperCase();
  const isDuke = nobleRank.includes('DUKE');
  const isKing = nobleRank.includes('KING');
  const isEmperor = nobleRank.includes('EMPEROR');
  const hasDukeFreeAccess = isDuke || isKing || isEmperor;

  const isActive = Boolean(activeMysteryAsset || (hasDukeFreeAccess && user.profile?.isMysteryActive));
  const expiresAt = activeMysteryAsset?.expiresAt || (isActive ? new Date(Date.now() + 7 * 86400000) : null);
  const durationDaysRemaining = expiresAt ? Math.max(0, Math.ceil((new Date(expiresAt).getTime() - Date.now()) / 86400000)) : 0;

  return {
    isActive,
    expiresAt: expiresAt ? expiresAt.toISOString() : null,
    durationDaysRemaining,
    hasDukeFreeAccess,
    nobleRank: user.profile?.nobleRank || null,
    isMysteryIdentityEnabled: Boolean(user.profile?.isPrivate || false),
  };
}

export async function purchaseMysterySuit({ userId, isDukeFreeClaim = false, ipAddress }, db = prisma) {
  const user = await userRepository.findById(userId, db);
  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    throw error;
  }

  const nobleRank = String(user.profile?.nobleRank || '').toUpperCase();
  const isDuke = nobleRank.includes('DUKE');
  const isKing = nobleRank.includes('KING');
  const isEmperor = nobleRank.includes('EMPEROR');
  const hasFreeEligibility = isDuke || isKing || isEmperor;

  let freeDays = 0;
  if (isEmperor) freeDays = 30;
  else if (isKing) freeDays = 15;
  else if (isDuke) freeDays = 7;

  const isFreeClaim = Boolean(isDukeFreeClaim && hasFreeEligibility);
  const packageDays = isFreeClaim ? freeDays : 30;
  const cost = isFreeClaim ? 0n : 800000n;

  // Execute purchase / activation in transaction
  const result = await db.$transaction(async (tx) => {
    if (cost > 0n) {
      let wallet = await walletRepository.findByUserId(userId, tx);
      if (!wallet) wallet = await walletRepository.createWallet(userId, tx);

      if (BigInt(wallet.coinBalance) < cost) {
        const error = new Error('Insufficient coins to purchase Mystery Suit (800,000 coins required)');
        error.statusCode = 400;
        error.code = 'INSUFFICIENT_BALANCE';
        throw error;
      }

      await walletRepository.updateWalletBalances(
        wallet.id,
        { coinBalanceDelta: -cost },
        tx
      );

      await tx.walletLedger.create({
        data: {
          walletId: wallet.id,
          type: 'ADMIN_ADJUSTMENT',
          amount: cost,
          balanceAfter: BigInt(wallet.coinBalance) - cost,
          reason: 'Mystery Suit 30-Day Entitlement Purchase',
          idempotencyKey: `mystery_${userId}_${Date.now()}`,
        },
      });
    }

    // Determine target expiry (stack if currently active)
    const existingAsset = await tx.userAsset.findFirst({
      where: {
        userId,
        assetId: 'assigned-asset-mystery-frame',
        expiresAt: { gt: new Date() },
      },
      orderBy: { expiresAt: 'desc' },
    });

    const baseTime = existingAsset ? new Date(existingAsset.expiresAt).getTime() : Date.now();
    const newExpiresAt = new Date(baseTime + packageDays * 86400000);

    // Ensure assets exist & upsert UserAsset records
    for (const item of MYSTERY_ASSETS) {
      let assetRecord = await tx.asset.findUnique({ where: { id: item.id } });
      if (!assetRecord) {
        assetRecord = await tx.asset.create({
          data: {
            id: item.id,
            name: item.name,
            assetType: item.assetType,
            thumbnailUrl: item.url,
            staticFileUrl: item.url,
            animationFileUrl: item.url,
            priceCoins: 0,
            validDays: packageDays,
            isActive: true,
          },
        });
      }

      // Unequip existing of same category
      await userAssetRepository.unequipAssetsByType(userId, item.assetType, tx);

      const existingUserAsset = await tx.userAsset.findFirst({
        where: { userId, assetId: item.id },
      });

      if (existingUserAsset) {
        await tx.userAsset.update({
          where: { id: existingUserAsset.id },
          data: {
            isEquipped: true,
            expiresAt: newExpiresAt,
          },
        });
      } else {
        await tx.userAsset.create({
          data: {
            userId,
            assetId: item.id,
            isEquipped: true,
            expiresAt: newExpiresAt,
          },
        });
      }
    }

    // Update user profile
    await tx.userProfile.update({
      where: { userId },
      data: {
        avatarFrame: 'assets/animations/mystery_frame.webp',
      },
    }).catch(() => {});

    return {
      success: true,
      isActive: true,
      expiresAt: newExpiresAt.toISOString(),
      durationDaysRemaining: Math.ceil((newExpiresAt.getTime() - Date.now()) / 86400000),
      isFreeClaim,
    };
  });

  // Emit realtime updates
  emitToUser(userId, 'user:outfit_updated', {
    userId,
    equippedFrame: 'assets/animations/mystery_frame.webp',
    avatarFrame: 'assets/animations/mystery_frame.webp',
    action: 'EQUIP',
    timestamp: new Date().toISOString(),
  });

  return result;
}

export default {
  getMysteryStatus,
  purchaseMysterySuit,
};
