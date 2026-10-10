import { z } from 'zod';

export const queryUsersSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().trim().optional(),
  status: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED', 'DELETED']).optional(),
  userType: z.enum(['USER', 'HOST', 'AGENCY_OWNER', 'BD_AGENT', 'COIN_SELLER', 'MERCHANT']).optional(),
  countryCode: z.string().trim().min(2).max(10).optional().or(z.literal('')),
  createdFrom: z.string().optional(),
  createdTo: z.string().optional(),
});

export const updateUserStatusSchema = z.object({
  status: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED', 'DELETED'], {
    required_error: 'Status is required and must be ACTIVE, SUSPENDED, BANNED, or DELETED',
  }),
  reason: z.string().trim().max(500).optional(),
});

export const deleteAccountSchema = z.object({
  password: z.string().optional(),
  reason: z.string().trim().max(500).optional(),
});

export const updateUserProfileSchema = z.object({
  username: z.string().trim().min(3).max(30).optional(),
  name: z.string().trim().min(1).max(50).optional(),
  displayName: z.string().trim().min(1).max(50).optional(),
  avatarUrl: z.string().max(1000).optional().or(z.literal('')),
  coverUrl: z.string().max(1000).optional().or(z.literal('')),
  bio: z.string().trim().max(500).optional().or(z.literal('')),
  gender: z.string().max(20).optional().or(z.literal('')),
  dob: z.string().optional().or(z.literal('')),
  birthDate: z.string().optional().or(z.literal('')),
  dateOfBirth: z.string().optional().or(z.literal('')),
  region: z.string().max(50).optional().or(z.literal('')),
  signature: z.string().trim().max(100).optional().or(z.literal('')),
  countryCode: z.string().trim().min(2).max(10).optional().or(z.literal('')),
  // Explicitly disallow protected fields
  role: z.undefined({ invalid_type_error: 'Role cannot be modified through profile' }),
  permissions: z.undefined({ invalid_type_error: 'Permissions cannot be modified through profile' }),
  userType: z.undefined({ invalid_type_error: 'UserType cannot be modified through profile' }),
  wallet: z.undefined({ invalid_type_error: 'Wallet balances cannot be modified through profile' }),
  coinBalance: z.undefined({ invalid_type_error: 'Coin balance cannot be modified through profile' }),
  diamondBalance: z.undefined({ invalid_type_error: 'Diamond balance cannot be modified through profile' }),
  status: z.undefined({ invalid_type_error: 'Status cannot be modified through profile' }),
  level: z.undefined({ invalid_type_error: 'Level cannot be modified through profile' }),
  vipLevel: z.undefined({ invalid_type_error: 'VIP level cannot be modified through profile' }),
  svipLevel: z.undefined({ invalid_type_error: 'SVIP level cannot be modified through profile' }),
});

export const createAdminUserSchema = z.object({
  username: z.string().trim().min(3, 'Username must be at least 3 characters').max(30),
  displayName: z.string().trim().min(1).max(50).optional(),
  phone: z.string().trim().max(30).optional().or(z.literal('')),
  email: z.string().trim().email('Invalid email address').optional().or(z.literal('')),
  countryCode: z.string().trim().min(2).max(10).optional().or(z.literal('')),
  status: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED']).default('ACTIVE').optional(),
  userType: z.enum(['USER', 'HOST', 'AGENCY_OWNER', 'BD_AGENT', 'COIN_SELLER', 'MERCHANT']).default('USER').optional(),
  coins: z.coerce.number().min(0).default(0).optional(),
  diamonds: z.coerce.number().min(0).default(0).optional(),
});

export const updateAdminUserByAdminSchema = z.object({
  displayName: z.string().trim().min(1).max(50).optional(),
  phone: z.string().trim().max(30).optional().or(z.literal('')),
  email: z.string().trim().email().optional().or(z.literal('')),
  countryCode: z.string().trim().min(2).max(10).optional().or(z.literal('')),
  status: z.enum(['ACTIVE', 'SUSPENDED', 'BANNED', 'DELETED']).optional(),
  userType: z.enum(['USER', 'HOST', 'AGENCY_OWNER', 'BD_AGENT', 'COIN_SELLER', 'MERCHANT']).optional(),
  avatarUrl: z.string().max(1000).optional().or(z.literal('')),
  bio: z.string().trim().max(500).optional(),
  gender: z.string().max(20).optional(),
  dob: z.string().optional(),
});

export const userIdParamSchema = z.object({
  id: z.string().min(1, 'User ID is required'),
});

export const updateBankInfoSchema = z.object({
  bankName: z.string().trim().max(100).optional().or(z.literal('')),
  accountHolderName: z.string().trim().max(100).optional().or(z.literal('')),
  bankAccountNumber: z.string().trim().max(100).optional().or(z.literal('')),
  payoutMethod: z.enum(['BANK', 'PAYPAL', 'USDT', 'PAYONEER', 'OTHER']).default('BANK').optional(),
  country: z.string().trim().max(50).optional().or(z.literal('')),
  isVerified: z.boolean().default(false).optional(),
});

export const banUserSchema = z.object({
  isBanned: z.boolean().default(true),
  banDurationDays: z.coerce.number().int().min(0).max(36500).default(0).optional(), // 0 = permanent
  reason: z.string().trim().max(500).default('Account banned by Administrator').optional(),
});

export const freezeUserSchema = z.object({
  isFrozen: z.boolean().default(true),
  reason: z.string().trim().max(500).default('Account frozen by Administrator').optional(),
});

export const fraudRiskStatusSchema = z.object({
  riskStatus: z.enum(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
  notes: z.string().trim().max(500).optional(),
});

export const assignAgencySchema = z.object({
  agencyId: z.string().min(1, 'Agency ID is required'),
  role: z.enum(['HOST', 'MEMBER']).default('HOST').optional(),
  reason: z.string().trim().max(500).optional(),
});

export const assignHostSchema = z.object({
  hostType: z.enum(['LIVE_HOST', 'AUDIO_HOST', 'BOTH']).default('BOTH').optional(),
  hostStatus: z.enum(['ACTIVE', 'SUSPENDED', 'REJECTED']).default('ACTIVE').optional(),
  reason: z.string().trim().max(500).optional(),
});

export const assignParentBOSchema = z.object({
  bdCenterId: z.string().min(1, 'BD Center ID is required'),
  reason: z.string().trim().max(500).optional(),
});

export const grantPropSchema = z.object({
  propType: z.enum(['AVATAR_FRAME', 'RIDE', 'VIP', 'CHAT_BUBBLE', 'BADGE', 'SPECIAL_ID']),
  propId: z.string().trim().optional(),
  propName: z.string().trim().optional(),
  duration: z.union([z.string(), z.number()]).default('PERMANENT').optional(),
  vipLevel: z.coerce.number().int().min(0).max(10).optional(),
  iconUrl: z.string().max(1000).optional(),
  reason: z.string().trim().max(500).optional(),
});

export const revokePropSchema = z.object({
  propType: z.enum(['AVATAR_FRAME', 'RIDE', 'VIP', 'CHAT_BUBBLE', 'BADGE', 'SPECIAL_ID']),
  propId: z.string().trim().optional(),
  reason: z.string().trim().max(500).optional(),
});

export const adjustWalletBalanceSchema = z.object({
  coinDelta: z.coerce.number().int().default(0),
  diamondDelta: z.coerce.number().int().default(0),
  reason: z.string().trim().min(3, 'Audit reason is required for balance adjustment').max(500),
});

export const coinRefundCorrectionSchema = z.object({
  transactionRef: z.string().trim().min(1, 'Transaction reference/ID is required'),
  coinAmount: z.coerce.number().int().positive('Coin amount must be positive'),
  reason: z.string().trim().min(3, 'Reason is required').max(500),
});

export const resetPasswordAdminSchema = z.object({
  temporaryPassword: z.string().min(6).optional(),
  forceChangeOnLogin: z.boolean().default(true).optional(),
  reason: z.string().trim().max(500).optional(),
});

export const resetRoomNameSchema = z.object({
  roomTitle: z.string().trim().max(100).optional(),
  reason: z.string().trim().max(500).optional(),
});

export const resetRoomCoverSchema = z.object({
  coverImageUrl: z.string().max(1000).optional(),
  reason: z.string().trim().max(500).optional(),
});

export default {
  queryUsersSchema,
  updateUserStatusSchema,
  deleteAccountSchema,
  updateUserProfileSchema,
  createAdminUserSchema,
  updateAdminUserByAdminSchema,
  userIdParamSchema,
  updateBankInfoSchema,
  banUserSchema,
  freezeUserSchema,
  fraudRiskStatusSchema,
  assignAgencySchema,
  assignHostSchema,
  assignParentBOSchema,
  grantPropSchema,
  revokePropSchema,
  adjustWalletBalanceSchema,
  coinRefundCorrectionSchema,
  resetPasswordAdminSchema,
  resetRoomNameSchema,
  resetRoomCoverSchema,
};
