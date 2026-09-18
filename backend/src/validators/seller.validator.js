import { z } from 'zod';

export const createSellerSchema = z.object({
  userId: z.string().optional(),
  username: z.string().optional(),
  email: z.string().email().optional(),
  country: z.string().optional(),
  countryCode: z.string().optional(),
  businessName: z.string().min(2, 'Business name must be at least 2 characters').max(100),
  profitMarginPercent: z.coerce.number().min(0, 'Profit margin must be >= 0').max(100, 'Profit margin must be <= 100').default(10.0),
  creditLimitUSD: z.coerce.number().min(0, 'Credit limit must be >= 0').default(1000.00),
  initialCredit: z.union([z.string(), z.number()]).optional(),
  initialCoins: z.union([z.string(), z.number()]).optional(),
});

export const updateSellerStatusSchema = z.preprocess(
  (val) => {
    if (!val || typeof val !== 'object') return val;
    const rawStatus = val.sellerStatus || val.status;
    if (!rawStatus) return val;
    let normalized = String(rawStatus).toUpperCase().trim();
    if (normalized === 'INACTIVE' || normalized === 'BANNED' || normalized === 'SUSPEND' || normalized === 'SUSPENDED') {
      normalized = 'SUSPENDED';
    } else if (normalized === 'ACTIVE' || normalized === 'ACTIVATE') {
      normalized = 'ACTIVE';
    }
    return {
      ...val,
      sellerStatus: normalized,
    };
  },
  z.object({
    sellerStatus: z.enum(['ACTIVE', 'SUSPENDED'], {
      required_error: 'Valid seller status is required (ACTIVE, SUSPENDED)',
    }),
    reason: z.string().max(500).optional().nullable(),
  })
);

export const updateSellerSchema = z.object({
  businessName: z.string().min(2).max(100).optional(),
  profitMarginPercent: z.coerce.number().min(0).max(100).optional(),
  creditLimitUSD: z.coerce.number().min(0).optional(),
  sellerStatus: z.enum(['ACTIVE', 'SUSPENDED']).optional(),
  countryCode: z.string().length(2).optional(),
});

export const allocateSellerCoinsSchema = z.object({
  amountCoins: z.union([z.string(), z.number(), z.bigint()]).refine(
    (val) => {
      try {
        const bi = BigInt(val);
        return bi > 0n;
      } catch {
        return false;
      }
    },
    { message: 'amountCoins must be a positive integer value' }
  ),
  notes: z.string().max(500).optional().nullable(),
});

export const correctSellerBalanceSchema = z.object({
  deltaCoins: z.union([z.string(), z.number(), z.bigint()]).refine(
    (val) => {
      try {
        const bi = BigInt(val);
        return bi !== 0n;
      } catch {
        return false;
      }
    },
    { message: 'deltaCoins must be a non-zero integer amount (positive to credit, negative to debit)' }
  ),
  reason: z.string().min(3, 'Correction reason must be at least 3 characters').max(500),
});

export const querySellersSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional().default(''),
  sellerStatus: z.enum(['ACTIVE', 'SUSPENDED']).optional(),
});
