import { z } from 'zod';

export const giftCategoryEnum = z.enum(['POPULAR', 'LUXURY', 'VIP', 'AUDIO']);

export const createGiftSchema = z.object({
  name: z.string().trim().min(1, 'Gift name is required').max(100, 'Gift name cannot exceed 100 characters'),
  coinValue: z
    .union([z.string(), z.number(), z.bigint()])
    .transform((val) => val.toString())
    .refine((val) => {
      try {
        const b = BigInt(val);
        return b > 0n;
      } catch {
        return false;
      }
    }, 'Coin value must be a positive integer'),
  iconUrl: z.string().min(1, 'Icon URL or asset path is required'),
  svgaAssetUrl: z.string().optional().nullable(),
  soundUrl: z.string().optional().nullable(),
  giftCategory: z
    .string()
    .transform((val) => val.toUpperCase())
    .pipe(giftCategoryEnum)
    .default('POPULAR'),
  isAnimated: z.boolean().default(false),
  isFullScreen: z.boolean().default(false),
  platformCutPercent: z.number().min(0).max(100).default(45.0),
  hostCutPercent: z.number().min(0).max(100).default(35.0),
  agencyCutPercent: z.number().min(0).max(100).default(12.0),
  roomCutPercent: z.number().min(0).max(100).default(8.0),
  isActive: z.boolean().default(true),
});

export const updateGiftSchema = createGiftSchema.partial();

export const sendGiftSchema = z
  .object({
    giftId: z.string().min(1, 'Gift ID is required'),
    recipientUserId: z.string().min(1).optional(),
    receiverUserId: z.string().min(1).optional(),
    recipientId: z.string().min(1).optional(),
    quantity: z
      .union([z.number(), z.string()])
      .transform((val) => Number(val))
      .refine((val) => Number.isInteger(val) && val >= 1 && val <= 10000, {
        message: 'Quantity must be an integer between 1 and 10,000',
      })
      .default(1),
    roomId: z.string().optional().nullable(),
    sessionId: z.string().optional().nullable(),
    liveSessionId: z.string().optional().nullable(),
    partyRoomId: z.string().optional().nullable(),
    channelName: z.string().optional().nullable(),
    pkId: z.string().optional().nullable(),
    matchId: z.string().optional().nullable(),
    transactionId: z.string().optional().nullable(),
    idempotencyKey: z.string().optional().nullable(),
  })
  .refine((data) => Boolean(data.recipientUserId || data.receiverUserId || data.recipientId), {
    message: 'Recipient User ID is required',
    path: ['recipientUserId'],
  })
  .transform((data) => ({
    ...data,
    recipientUserId: data.recipientUserId || data.receiverUserId || data.recipientId,
  }));

export const queryGiftsSchema = z.object({
  page: z
    .union([z.string(), z.number()])
    .transform((val) => Math.max(1, Number(val) || 1))
    .default(1),
  limit: z
    .union([z.string(), z.number()])
    .transform((val) => Math.min(250, Math.max(1, Number(val) || 50)))
    .default(50),
  giftCategory: z.string().optional(),
  category: z.string().optional(),
  appCategory: z.string().optional(),
  isActive: z
    .union([z.boolean(), z.string()])
    .transform((val) => {
      if (typeof val === 'string') {
        if (val.toLowerCase() === 'all' || val.trim() === '') return undefined;
        return val.toLowerCase() === 'true';
      }
      return Boolean(val);
    })
    .optional(),
  search: z.string().optional().default(''),
});

export default {
  createGiftSchema,
  updateGiftSchema,
  sendGiftSchema,
  queryGiftsSchema,
  giftCategoryEnum,
};
