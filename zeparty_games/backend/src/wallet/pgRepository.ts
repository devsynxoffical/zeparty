import type pg from 'pg';
import { getPool, withTransaction } from '../db/pool.js';
import type {
  ApplyResult,
  ApplyTransactionInput,
  Cosmetic,
  InventoryItem,
  Wallet,
  WalletRepository,
  WalletTransaction,
} from './types.js';

function rowToWallet(r: Record<string, unknown>): Wallet {
  return {
    walletId: r['wallet_id'] as string,
    userId: r['user_id'] as string,
    currencyType: r['currency_type'] as string,
    balance: Number(r['balance']),
    createdAt: new Date(r['created_at'] as string).toISOString(),
    updatedAt: new Date(r['updated_at'] as string).toISOString(),
  };
}

function rowToTx(r: Record<string, unknown>): WalletTransaction {
  return {
    transactionId: r['transaction_id'] as string,
    walletId: r['wallet_id'] as string,
    userId: r['user_id'] as string,
    transactionType: r['transaction_type'] as WalletTransaction['transactionType'],
    amount: Number(r['amount']),
    balanceAfter: Number(r['balance_after']),
    referenceId: (r['reference_id'] as string | null) ?? null,
    idempotencyKey: r['idempotency_key'] as string,
    metadata: (r['metadata'] as Record<string, unknown>) ?? {},
    createdAt: new Date(r['created_at'] as string).toISOString(),
  };
}

function rowToCosmetic(r: Record<string, unknown>): Cosmetic {
  return {
    cosmeticId: r['cosmetic_id'] as string,
    gameId: r['game_id'] as string,
    category: r['category'] as string,
    name: r['name'] as string,
    description: r['description'] as string,
    price: Number(r['price']),
    previewAsset: (r['preview_asset'] as string | null) ?? null,
    enabled: r['enabled'] as boolean,
  };
}

/**
 * PostgreSQL ledger repository. Every mutation runs in a transaction and takes a row lock
 * on the wallet (SELECT ... FOR UPDATE) so concurrent debits cannot overdraw.
 */
export class PgWalletRepository implements WalletRepository {
  private async lockedWallet(client: pg.PoolClient, userId: string, currency: string): Promise<Wallet> {
    await client.query(
      `INSERT INTO wallets (user_id, currency_type) VALUES ($1, $2)
       ON CONFLICT (user_id, currency_type) DO NOTHING`,
      [userId, currency],
    );
    const res = await client.query(
      `SELECT * FROM wallets WHERE user_id = $1 AND currency_type = $2 FOR UPDATE`,
      [userId, currency],
    );
    return rowToWallet(res.rows[0]);
  }

  async getOrCreateWallet(userId: string, currencyType = 'ZCOIN'): Promise<Wallet> {
    return withTransaction((c) => this.lockedWallet(c, userId, currencyType));
  }

  private async applyWithin(client: pg.PoolClient, input: ApplyTransactionInput): Promise<ApplyResult> {
    const currency = input.currencyType ?? 'ZCOIN';
    const wallet = await this.lockedWallet(client, input.userId, currency);
    const dup = await client.query(
      `SELECT * FROM wallet_transactions WHERE wallet_id = $1 AND idempotency_key = $2`,
      [wallet.walletId, input.idempotencyKey],
    );
    if (dup.rows[0]) return { status: 'duplicate', transaction: rowToTx(dup.rows[0]), wallet };
    if (!Number.isInteger(input.amount) || input.amount === 0) throw new Error('invalid_amount');
    const newBalance = wallet.balance + input.amount;
    if (newBalance < 0) return { status: 'insufficient_funds', wallet };
    await client.query(`UPDATE wallets SET balance = $1, updated_at = now() WHERE wallet_id = $2`, [newBalance, wallet.walletId]);
    const ins = await client.query(
      `INSERT INTO wallet_transactions
         (wallet_id, user_id, transaction_type, amount, balance_after, reference_id, idempotency_key, metadata)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [
        wallet.walletId,
        input.userId,
        input.transactionType,
        input.amount,
        newBalance,
        input.referenceId ?? null,
        input.idempotencyKey,
        JSON.stringify(input.metadata ?? {}),
      ],
    );
    return { status: 'applied', transaction: rowToTx(ins.rows[0]), wallet: { ...wallet, balance: newBalance } };
  }

  async applyTransaction(input: ApplyTransactionInput): Promise<ApplyResult> {
    return withTransaction((c) => this.applyWithin(c, input));
  }

  async listTransactions(userId: string, limit: number, before?: string): Promise<WalletTransaction[]> {
    const res = await getPool().query(
      `SELECT * FROM wallet_transactions WHERE user_id = $1 AND ($2::timestamptz IS NULL OR created_at < $2)
       ORDER BY created_at DESC LIMIT $3`,
      [userId, before ?? null, limit],
    );
    return res.rows.map(rowToTx);
  }

  async listCosmetics(gameId?: string): Promise<Cosmetic[]> {
    const res = await getPool().query(
      `SELECT * FROM cosmetics WHERE $1::text IS NULL OR game_id = $1 OR game_id = 'common' ORDER BY game_id, category, price`,
      [gameId ?? null],
    );
    return res.rows.map(rowToCosmetic);
  }
  async getCosmetic(cosmeticId: string): Promise<Cosmetic | null> {
    const res = await getPool().query(`SELECT * FROM cosmetics WHERE cosmetic_id = $1`, [cosmeticId]);
    return res.rows[0] ? rowToCosmetic(res.rows[0]) : null;
  }
  async upsertCosmetic(c: Cosmetic): Promise<void> {
    await getPool().query(
      `INSERT INTO cosmetics (cosmetic_id, game_id, category, name, description, price, preview_asset, enabled)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       ON CONFLICT (cosmetic_id) DO UPDATE SET game_id=EXCLUDED.game_id, category=EXCLUDED.category, name=EXCLUDED.name,
         description=EXCLUDED.description, price=EXCLUDED.price, preview_asset=EXCLUDED.preview_asset, enabled=EXCLUDED.enabled`,
      [c.cosmeticId, c.gameId, c.category, c.name, c.description, c.price, c.previewAsset, c.enabled],
    );
  }
  async listInventory(userId: string): Promise<InventoryItem[]> {
    const res = await getPool().query(`SELECT * FROM inventory_items WHERE user_id = $1`, [userId]);
    return res.rows.map((r) => ({
      userId: r.user_id,
      cosmeticId: r.cosmetic_id,
      acquiredAt: new Date(r.acquired_at).toISOString(),
      sourceTx: r.source_tx ?? null,
    }));
  }
  async ownsCosmetic(userId: string, cosmeticId: string): Promise<boolean> {
    const res = await getPool().query(`SELECT 1 FROM inventory_items WHERE user_id = $1 AND cosmetic_id = $2`, [userId, cosmeticId]);
    return res.rowCount === 1;
  }

  async purchaseCosmetic(userId: string, cosmetic: Cosmetic, idempotencyKey: string) {
    return withTransaction(async (c) => {
      const result = await this.applyWithin(c, {
        userId,
        transactionType: 'purchase_cosmetic',
        amount: -cosmetic.price,
        referenceId: cosmetic.cosmeticId,
        idempotencyKey,
        metadata: { cosmeticId: cosmetic.cosmeticId, price: cosmetic.price },
      });
      if (result.status === 'insufficient_funds') return result;
      const ins = await c.query(
        `INSERT INTO inventory_items (user_id, cosmetic_id, source_tx) VALUES ($1,$2,$3)
         ON CONFLICT (user_id, cosmetic_id) DO UPDATE SET user_id = EXCLUDED.user_id RETURNING *`,
        [userId, cosmetic.cosmeticId, result.transaction.transactionId],
      );
      const r = ins.rows[0];
      return {
        ...result,
        item: { userId: r.user_id, cosmeticId: r.cosmetic_id, acquiredAt: new Date(r.acquired_at).toISOString(), sourceTx: r.source_tx },
      };
    });
  }

  async equip(userId: string, gameId: string, category: string, cosmeticId: string): Promise<void> {
    await getPool().query(
      `INSERT INTO equipped_cosmetics (user_id, game_id, category, cosmetic_id) VALUES ($1,$2,$3,$4)
       ON CONFLICT (user_id, game_id, category) DO UPDATE SET cosmetic_id = EXCLUDED.cosmetic_id`,
      [userId, gameId, category, cosmeticId],
    );
  }
  async listEquipped(userId: string, gameId: string): Promise<Record<string, string>> {
    const res = await getPool().query(`SELECT category, cosmetic_id FROM equipped_cosmetics WHERE user_id = $1 AND game_id = $2`, [userId, gameId]);
    return Object.fromEntries(res.rows.map((r) => [r.category, r.cosmetic_id]));
  }
}
