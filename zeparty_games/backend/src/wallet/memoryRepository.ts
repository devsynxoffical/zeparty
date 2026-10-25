import { randomUUID } from 'node:crypto';
import type {
  ApplyResult,
  ApplyTransactionInput,
  Cosmetic,
  InventoryItem,
  Wallet,
  WalletRepository,
  WalletTransaction,
} from './types.js';

/**
 * In-memory repository for development and tests. Serializes all mutations through a
 * per-wallet promise chain so concurrent requests observe the same guarantees as the
 * Postgres implementation (row lock + unique idempotency key).
 */
export class MemoryWalletRepository implements WalletRepository {
  private wallets = new Map<string, Wallet>(); // key user:currency
  private txByWallet = new Map<string, WalletTransaction[]>();
  private cosmetics = new Map<string, Cosmetic>();
  private inventory = new Map<string, Map<string, InventoryItem>>();
  private equipped = new Map<string, Map<string, string>>(); // user|game -> category -> cosmetic
  private locks = new Map<string, Promise<unknown>>();

  private async withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const prev = this.locks.get(key) ?? Promise.resolve();
    const next = prev.then(fn, fn);
    this.locks.set(key, next.catch(() => undefined));
    return next;
  }

  async getOrCreateWallet(userId: string, currencyType = 'ZCOIN'): Promise<Wallet> {
    const key = `${userId}:${currencyType}`;
    let w = this.wallets.get(key);
    if (!w) {
      const now = new Date().toISOString();
      w = { walletId: randomUUID(), userId, currencyType, balance: 0, createdAt: now, updatedAt: now };
      this.wallets.set(key, w);
      this.txByWallet.set(w.walletId, []);
    }
    return { ...w };
  }

  async applyTransaction(input: ApplyTransactionInput): Promise<ApplyResult> {
    const currency = input.currencyType ?? 'ZCOIN';
    const key = `${input.userId}:${currency}`;
    return this.withLock(key, async () => {
      const wallet = await this.getOrCreateWallet(input.userId, currency);
      const stored = this.wallets.get(key)!;
      const ledger = this.txByWallet.get(stored.walletId)!;
      const dup = ledger.find((t) => t.idempotencyKey === input.idempotencyKey);
      if (dup) return { status: 'duplicate', transaction: dup, wallet: { ...stored } };
      if (!Number.isInteger(input.amount) || input.amount === 0) {
        throw new Error('invalid_amount');
      }
      const newBalance = stored.balance + input.amount;
      if (newBalance < 0) return { status: 'insufficient_funds', wallet };
      stored.balance = newBalance;
      stored.updatedAt = new Date().toISOString();
      const tx: WalletTransaction = {
        transactionId: randomUUID(),
        walletId: stored.walletId,
        userId: input.userId,
        transactionType: input.transactionType,
        amount: input.amount,
        balanceAfter: newBalance,
        referenceId: input.referenceId ?? null,
        idempotencyKey: input.idempotencyKey,
        metadata: input.metadata ?? {},
        createdAt: stored.updatedAt,
      };
      ledger.push(tx);
      return { status: 'applied', transaction: tx, wallet: { ...stored } };
    });
  }

  async listTransactions(userId: string, limit: number, before?: string): Promise<WalletTransaction[]> {
    const all: WalletTransaction[] = [];
    for (const w of this.wallets.values()) {
      if (w.userId === userId) all.push(...(this.txByWallet.get(w.walletId) ?? []));
    }
    return all
      .filter((t) => !before || t.createdAt < before)
      .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
      .slice(0, limit);
  }

  async listCosmetics(gameId?: string): Promise<Cosmetic[]> {
    return [...this.cosmetics.values()].filter((c) => !gameId || c.gameId === gameId || c.gameId === 'common');
  }
  async getCosmetic(cosmeticId: string): Promise<Cosmetic | null> {
    return this.cosmetics.get(cosmeticId) ?? null;
  }
  async upsertCosmetic(cosmetic: Cosmetic): Promise<void> {
    this.cosmetics.set(cosmetic.cosmeticId, { ...cosmetic });
  }
  async listInventory(userId: string): Promise<InventoryItem[]> {
    return [...(this.inventory.get(userId)?.values() ?? [])];
  }
  async ownsCosmetic(userId: string, cosmeticId: string): Promise<boolean> {
    return this.inventory.get(userId)?.has(cosmeticId) ?? false;
  }

  async purchaseCosmetic(userId: string, cosmetic: Cosmetic, idempotencyKey: string) {
    const result = await this.applyTransaction({
      userId,
      transactionType: 'purchase_cosmetic',
      amount: -cosmetic.price,
      referenceId: cosmetic.cosmeticId,
      idempotencyKey,
      metadata: { cosmeticId: cosmetic.cosmeticId, price: cosmetic.price },
    });
    if (result.status === 'insufficient_funds') return result;
    let inv = this.inventory.get(userId);
    if (!inv) {
      inv = new Map();
      this.inventory.set(userId, inv);
    }
    let item = inv.get(cosmetic.cosmeticId);
    if (!item) {
      item = { userId, cosmeticId: cosmetic.cosmeticId, acquiredAt: new Date().toISOString(), sourceTx: result.transaction.transactionId };
      inv.set(cosmetic.cosmeticId, item);
    }
    return { ...result, item };
  }

  async equip(userId: string, gameId: string, category: string, cosmeticId: string): Promise<void> {
    const k = `${userId}|${gameId}`;
    let m = this.equipped.get(k);
    if (!m) {
      m = new Map();
      this.equipped.set(k, m);
    }
    m.set(category, cosmeticId);
  }
  async listEquipped(userId: string, gameId: string): Promise<Record<string, string>> {
    return Object.fromEntries(this.equipped.get(`${userId}|${gameId}`) ?? []);
  }
}
