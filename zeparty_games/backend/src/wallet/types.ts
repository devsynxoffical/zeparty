export type TransactionType =
  | 'reward_match'
  | 'reward_achievement'
  | 'reward_daily'
  | 'reward_tutorial'
  | 'reward_promo'
  | 'purchase_cosmetic'
  | 'admin_adjust';

export interface Wallet {
  walletId: string;
  userId: string;
  currencyType: string;
  balance: number;
  createdAt: string;
  updatedAt: string;
}

export interface WalletTransaction {
  transactionId: string;
  walletId: string;
  userId: string;
  transactionType: TransactionType;
  amount: number;
  balanceAfter: number;
  referenceId: string | null;
  idempotencyKey: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

export interface Cosmetic {
  cosmeticId: string;
  gameId: string;
  category: string;
  name: string;
  description: string;
  price: number;
  previewAsset: string | null;
  enabled: boolean;
}

export interface InventoryItem {
  userId: string;
  cosmeticId: string;
  acquiredAt: string;
  sourceTx: string | null;
}

export interface ApplyTransactionInput {
  userId: string;
  currencyType?: string;
  transactionType: TransactionType;
  amount: number; // signed
  referenceId?: string | null;
  idempotencyKey: string;
  metadata?: Record<string, unknown>;
}

export type ApplyResult =
  | { status: 'applied'; transaction: WalletTransaction; wallet: Wallet }
  | { status: 'duplicate'; transaction: WalletTransaction; wallet: Wallet }
  | { status: 'insufficient_funds'; wallet: Wallet };

export class WalletError extends Error {
  constructor(
    public readonly code: 'insufficient_funds' | 'cosmetic_not_found' | 'cosmetic_disabled' | 'already_owned' | 'invalid_amount',
    message?: string,
  ) {
    super(message ?? code);
    this.name = 'WalletError';
  }
}

export interface WalletRepository {
  getOrCreateWallet(userId: string, currencyType: string): Promise<Wallet>;
  /**
   * Atomically apply a ledger entry. Implementations must guarantee:
   *  - the (wallet, idempotencyKey) pair is unique; a repeat returns the original entry
   *  - balance never drops below zero
   *  - balance and ledger are written in one transaction
   */
  applyTransaction(input: ApplyTransactionInput): Promise<ApplyResult>;
  listTransactions(userId: string, limit: number, before?: string): Promise<WalletTransaction[]>;

  listCosmetics(gameId?: string): Promise<Cosmetic[]>;
  getCosmetic(cosmeticId: string): Promise<Cosmetic | null>;
  upsertCosmetic(cosmetic: Cosmetic): Promise<void>;
  listInventory(userId: string): Promise<InventoryItem[]>;
  ownsCosmetic(userId: string, cosmeticId: string): Promise<boolean>;
  /** Debit the price and grant the item in one atomic unit of work. */
  purchaseCosmetic(userId: string, cosmetic: Cosmetic, idempotencyKey: string): Promise<ApplyResult & { item?: InventoryItem }>;
  equip(userId: string, gameId: string, category: string, cosmeticId: string): Promise<void>;
  listEquipped(userId: string, gameId: string): Promise<Record<string, string>>;
}
