import type { ApplyResult, Cosmetic, InventoryItem, Wallet, WalletRepository, WalletTransaction } from './types.js';
import { WalletError } from './types.js';
import type { GameConfigStore } from '../admin/gameConfig.js';

/**
 * Wallet service. All coin movement in the system goes through here. Nothing in this file is
 * reachable from a client except through the HTTP/WS handlers, which never accept an amount
 * from the client: amounts come from server configuration (fixed rewards, cosmetic prices).
 */
export class WalletService {
  constructor(
    private readonly repo: WalletRepository,
    private readonly gameConfig: GameConfigStore,
  ) {}

  getBalance(userId: string): Promise<Wallet> {
    return this.repo.getOrCreateWallet(userId, 'ZCOIN');
  }

  listTransactions(userId: string, limit = 50, before?: string): Promise<WalletTransaction[]> {
    return this.repo.listTransactions(userId, Math.min(Math.max(limit, 1), 200), before);
  }

  /**
   * Fixed participation / completion reward. The amount is read from the game config,
   * never from the request. Idempotent per (match, user, kind).
   */
  async grantMatchReward(userId: string, gameId: string, matchId: string, kind: 'participation' | 'win'): Promise<ApplyResult | null> {
    const cfg = await this.gameConfig.get(gameId);
    const amount = kind === 'win' ? cfg.rewards.winCoins : cfg.rewards.participationCoins;
    if (amount <= 0) return null;
    return this.repo.applyTransaction({
      userId,
      transactionType: 'reward_match',
      amount,
      referenceId: matchId,
      idempotencyKey: `match:${matchId}:${userId}:${kind}`,
      metadata: { gameId, kind },
    });
  }

  async grantAchievementReward(userId: string, achievementId: string, amount: number): Promise<ApplyResult | null> {
    if (amount <= 0) return null;
    return this.repo.applyTransaction({
      userId,
      transactionType: 'reward_achievement',
      amount,
      referenceId: achievementId,
      idempotencyKey: `achievement:${achievementId}:${userId}`,
    });
  }

  async grantDailyReward(userId: string, dayIso: string, amount: number): Promise<ApplyResult | null> {
    if (amount <= 0) return null;
    return this.repo.applyTransaction({
      userId,
      transactionType: 'reward_daily',
      amount,
      referenceId: dayIso,
      idempotencyKey: `daily:${dayIso}:${userId}`,
    });
  }

  async grantPromo(userId: string, promoId: string, amount: number): Promise<ApplyResult> {
    if (!Number.isInteger(amount) || amount <= 0) throw new WalletError('invalid_amount');
    return this.repo.applyTransaction({
      userId,
      transactionType: 'reward_promo',
      amount,
      referenceId: promoId,
      idempotencyKey: `promo:${promoId}:${userId}`,
    });
  }

  /** Admin-only signed adjustment. Caller must supply a unique idempotency key. */
  async adminAdjust(userId: string, amount: number, idempotencyKey: string, reason: string): Promise<ApplyResult> {
    if (!Number.isInteger(amount) || amount === 0) throw new WalletError('invalid_amount');
    return this.repo.applyTransaction({
      userId,
      transactionType: 'admin_adjust',
      amount,
      idempotencyKey: `admin:${idempotencyKey}`,
      metadata: { reason },
    });
  }

  listCosmetics(gameId?: string): Promise<Cosmetic[]> {
    return this.repo.listCosmetics(gameId);
  }
  listInventory(userId: string): Promise<InventoryItem[]> {
    return this.repo.listInventory(userId);
  }
  listEquipped(userId: string, gameId: string): Promise<Record<string, string>> {
    return this.repo.listEquipped(userId, gameId);
  }

  async purchaseCosmetic(userId: string, cosmeticId: string, idempotencyKey: string) {
    const cosmetic = await this.repo.getCosmetic(cosmeticId);
    if (!cosmetic) throw new WalletError('cosmetic_not_found');
    if (!cosmetic.enabled) throw new WalletError('cosmetic_disabled');
    const cfg = await this.gameConfig.get(cosmetic.gameId === 'common' ? 'common' : cosmetic.gameId);
    if (!cfg.cosmeticsEnabled) throw new WalletError('cosmetic_disabled');
    if (await this.repo.ownsCosmetic(userId, cosmeticId)) throw new WalletError('already_owned');
    const result = await this.repo.purchaseCosmetic(userId, cosmetic, `purchase:${cosmeticId}:${userId}:${idempotencyKey}`);
    if (result.status === 'insufficient_funds') throw new WalletError('insufficient_funds');
    return result;
  }

  async equip(userId: string, cosmeticId: string): Promise<void> {
    const cosmetic = await this.repo.getCosmetic(cosmeticId);
    if (!cosmetic) throw new WalletError('cosmetic_not_found');
    const owned = cosmetic.price === 0 || (await this.repo.ownsCosmetic(userId, cosmeticId));
    if (!owned) throw new WalletError('cosmetic_not_found', 'not owned');
    await this.repo.equip(userId, cosmetic.gameId, cosmetic.category, cosmeticId);
  }
}
