import { randomUUID } from 'node:crypto';
import prisma from '../../../config/database.js';

/**
 * Prisma-bridged wallet repository for embedded ZeParty-Backend mode.
 * Reads the user's real ZeParty `coinBalance` from Prisma when available,
 * and syncs coin rewards / cosmetic purchases back to `prisma.wallet`.
 */
export class MemoryWalletRepository {
  wallets = new Map();
  txByWallet = new Map();
  cosmetics = new Map();
  inventory = new Map();
  equipped = new Map();
  locks = new Map();

  async withLock(key, fn) {
    const prev = this.locks.get(key) ?? Promise.resolve();
    const next = prev.then(fn, fn);
    this.locks.set(
      key,
      next.catch(() => undefined)
    );
    return next;
  }

  async getOrCreateWallet(userId, currencyType = 'ZCOIN') {
    const key = `${userId}:${currencyType}`;
    let w = this.wallets.get(key);
    let prismaBalance = null;
    try {
      const dbWallet = await prisma.wallet.findUnique({
        where: { userId },
        select: { id: true, coinBalance: true },
      });
      if (dbWallet) {
        prismaBalance = Number(dbWallet.coinBalance || 0);
      }
    } catch {}

    if (!w) {
      const now = new Date().toISOString();
      w = {
        walletId: randomUUID(),
        userId,
        currencyType,
        balance: prismaBalance ?? 1000,
        createdAt: now,
        updatedAt: now,
      };
      this.wallets.set(key, w);
      this.txByWallet.set(w.walletId, []);
    } else if (prismaBalance !== null) {
      w.balance = prismaBalance;
    }
    return { ...w };
  }

  async applyTransaction(input) {
    const currency = input.currencyType ?? 'ZCOIN';
    const key = `${input.userId}:${currency}`;
    return this.withLock(key, async () => {
      const wallet = await this.getOrCreateWallet(input.userId, currency);
      const stored = this.wallets.get(key);
      const ledger = this.txByWallet.get(stored.walletId);
      const dup = ledger.find((t) => t.idempotencyKey === input.idempotencyKey);
      if (dup) return { status: 'duplicate', transaction: dup, wallet: { ...stored } };
      if (!Number.isInteger(input.amount) || input.amount === 0) {
        throw new Error('invalid_amount');
      }
      const newBalance = stored.balance + input.amount;
      if (newBalance < 0) return { status: 'insufficient_funds', wallet };
      stored.balance = newBalance;
      stored.updatedAt = new Date().toISOString();

      try {
        await prisma.wallet.update({
          where: { userId: input.userId },
          data: { coinBalance: { increment: BigInt(input.amount) } },
        });
      } catch {}

      const tx = {
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

  async listTransactions(userId, limit, before) {
    const all = [];
    for (const w of this.wallets.values()) {
      if (w.userId === userId) all.push(...(this.txByWallet.get(w.walletId) ?? []));
    }
    return all
      .filter((t) => !before || t.createdAt < before)
      .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1))
      .slice(0, limit);
  }

  async listCosmetics(gameId) {
    return [...this.cosmetics.values()].filter((c) => !gameId || c.gameId === gameId || c.gameId === 'common');
  }
  async getCosmetic(cosmeticId) {
    return this.cosmetics.get(cosmeticId) ?? null;
  }
  async upsertCosmetic(cosmetic) {
    this.cosmetics.set(cosmetic.cosmeticId, { ...cosmetic });
  }
  async listInventory(userId) {
    return [...(this.inventory.get(userId)?.values() ?? [])];
  }
  async ownsCosmetic(userId, cosmeticId) {
    return this.inventory.get(userId)?.has(cosmeticId) ?? false;
  }

  async purchaseCosmetic(userId, cosmetic, idempotencyKey) {
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
      item = {
        userId,
        cosmeticId: cosmetic.cosmeticId,
        acquiredAt: new Date().toISOString(),
        sourceTx: result.transaction.transactionId,
      };
      inv.set(cosmetic.cosmeticId, item);
    }
    return { ...result, item };
  }

  async equip(userId, gameId, category, cosmeticId) {
    const k = `${userId}|${gameId}`;
    let m = this.equipped.get(k);
    if (!m) {
      m = new Map();
      this.equipped.set(k, m);
    }
    m.set(category, cosmeticId);
  }

  async listEquipped(userId, gameId) {
    return Object.fromEntries(this.equipped.get(`${userId}|${gameId}`) ?? []);
  }
}
