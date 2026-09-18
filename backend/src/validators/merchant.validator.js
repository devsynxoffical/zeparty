import { z } from 'zod';

export const createMerchantSchema = z.object({
  userId: z.string().optional(),
  userRef: z.string().optional(),
  username: z.string().optional(),
  companyName: z.string().min(2).max(100).optional(),
  merchantName: z.string().min(2).max(100).optional(),
  email: z.string().email().optional(),
  contactPerson: z.string().optional(),
  country: z.string().optional(),
  countryCode: z.string().optional(),
  initialAllocation: z.union([z.string(), z.number(), z.bigint()]).optional(),
  monthlyQuotaCoins: z.union([z.string(), z.number(), z.bigint()]).refine(
    (val) => {
      try {
        const bi = BigInt(val);
        return bi > 0n;
      } catch {
        return false;
      }
    },
    { message: 'monthlyQuotaCoins must be a positive integer value' }
  ).default('25200000'),
});

export const updateMerchantSchema = z.object({
  companyName: z.string().min(2).max(100).optional(),
  merchantName: z.string().min(2).max(100).optional(),
  contactPerson: z.string().optional(),
  email: z.string().email().optional(),
  country: z.string().optional(),
  countryCode: z.string().optional(),
  dailySettlementLimitUSD: z.coerce.number().optional(),
  linkedToWithdrawalSettlement: z.boolean().optional(),
  totalSpentUSD: z.union([z.string(), z.number()]).optional(),
  status: z.preprocess(
    (val) => (typeof val === 'string' ? val.toUpperCase() : val),
    z.enum(['ACTIVE', 'SUSPENDED'])
  ).optional(),
  monthlyQuotaCoins: z.union([z.string(), z.number(), z.bigint()]).refine(
    (val) => {
      try {
        const bi = BigInt(val);
        return bi >= 0n;
      } catch {
        return false;
      }
    },
    { message: 'monthlyQuotaCoins must be a valid non-negative integer value' }
  ).optional(),
  coinAllocation: z.union([z.string(), z.number(), z.bigint()]).optional(),
});

export const adjustMerchantBalanceSchema = z.object({
  amount: z.union([z.string(), z.number(), z.bigint()]).refine(
    (val) => {
      try {
        const bi = BigInt(val);
        return bi > 0n;
      } catch {
        return false;
      }
    },
    { message: 'Amount must be a positive number' }
  ),
  type: z.enum(['CREDIT', 'DEBIT', 'SET']).default('CREDIT'),
  reason: z.string().max(500).optional(),
});

export const queryMerchantsSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  search: z.string().optional().default(''),
  status: z.preprocess(
    (val) => (typeof val === 'string' ? val.toUpperCase() : val),
    z.enum(['ACTIVE', 'SUSPENDED'])
  ).optional(),
});
