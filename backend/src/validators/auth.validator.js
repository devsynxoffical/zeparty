import { z } from 'zod';

export const requestOtpSchema = z.object({
  phone: z
    .string({ required_error: 'Phone number is required' })
    .min(6, 'Phone number must be at least 6 characters')
    .max(20, 'Phone number must be at most 20 characters'),
  purpose: z.enum(['REGISTRATION', 'LOGIN', 'PASSWORD_RESET']).optional().default('LOGIN'),
});

export const verifyOtpSchema = z.object({
  phone: z
    .string({ required_error: 'Phone number is required' })
    .min(6, 'Phone number must be at least 6 characters'),
  code: z
    .string({ required_error: 'OTP code is required' })
    .length(6, 'OTP code must be exactly 6 digits'),
  purpose: z.enum(['REGISTRATION', 'LOGIN', 'PASSWORD_RESET']).optional().default('LOGIN'),
  device: z
    .object({
      deviceToken: z.string().optional(),
      platform: z.enum(['ANDROID', 'IOS', 'WEB']).optional().default('ANDROID'),
      macAddress: z.string().optional(),
      deviceModel: z.string().optional(),
      appVersion: z.string().optional(),
    })
    .optional(),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string({ required_error: 'Refresh token is required' }).min(1),
});

export const adminLoginSchema = z.object({
  usernameOrEmail: z.string({ required_error: 'Username or email is required' }).min(1),
  password: z.string({ required_error: 'Password is required' }).min(1),
});

export const syncUserSchema = z.object({
  uid: z.string().optional(),
  id: z.string().optional(),
  email: z.string().email().optional().or(z.literal('')).nullable(),
  phone: z.string().optional().nullable(),
  username: z.string().optional().nullable(),
  name: z.string().optional().nullable(),
  displayName: z.string().optional().nullable(),
  avatarUrl: z.string().optional().nullable(),
  bio: z.string().optional().nullable(),
  gender: z.string().optional().nullable(),
  dob: z.string().optional().nullable(),
  countryCode: z.string().optional().nullable(),
  coins: z.number().optional().nullable(),
  diamonds: z.number().optional().nullable(),
  device: z
    .object({
      deviceToken: z.string().optional(),
      platform: z.enum(['ANDROID', 'IOS', 'WEB', 'FLUTTER']).optional().default('ANDROID'),
      macAddress: z.string().optional(),
      deviceModel: z.string().optional(),
      appVersion: z.string().optional(),
    })
    .optional(),
});

export default {
  requestOtpSchema,
  verifyOtpSchema,
  refreshTokenSchema,
  adminLoginSchema,
  syncUserSchema,
};

