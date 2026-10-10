import { z } from 'zod';

export const applyHostSchema = z.object({
  hostType: z.enum(['LIVE_HOST', 'AUDIO_HOST', 'BOTH', 'live_host', 'audio_host', 'both'], {
    required_error: 'Host type is required (LIVE_HOST, AUDIO_HOST, BOTH)',
  }).transform((val) => val.toUpperCase()),
  idCardFrontUrl: z.string().optional().nullable(),
  idCardBackUrl: z.string().optional().nullable(),
  videoSampleUrl: z.string().optional().nullable(),
  name: z.string().optional().nullable(),
  displayName: z.string().optional().nullable(),
  dob: z.string().optional().nullable(),
  gender: z.string().optional().nullable(),
  phone: z.string().optional().nullable(),
  contentCategory: z.string().optional().nullable(),
  introduction: z.string().optional().nullable(),
});

export const reviewHostApplicationSchema = z.object({
  status: z.enum(['ACTIVE', 'APPROVED', 'REJECTED', 'active', 'approved', 'rejected'], {
    required_error: 'Status must be ACTIVE/APPROVED or REJECTED',
  }).transform((val) => {
    const upper = val.toUpperCase();
    return upper === 'APPROVED' ? 'ACTIVE' : upper;
  }),
  rejectionReason: z.string().max(500).optional().nullable(),
  reason: z.string().max(500).optional().nullable(),
}).transform((data) => ({
  status: data.status,
  rejectionReason: data.rejectionReason || data.reason || null,
})).refine(
  (data) => {
    if (data.status === 'REJECTED' && (!data.rejectionReason || data.rejectionReason.trim().length < 2)) {
      return false;
    }
    return true;
  },
  {
    message: 'rejectionReason is required when status is REJECTED',
    path: ['rejectionReason'],
  }
);

export const updateHostStatusSchema = z.object({
  hostStatus: z.enum(['APPLIED', 'ACTIVE', 'SUSPENDED', 'REJECTED']).optional(),
  status: z.enum(['APPLIED', 'ACTIVE', 'SUSPENDED', 'REJECTED', 'applied', 'active', 'suspended', 'rejected']).optional(),
  reason: z.string().max(500).optional().nullable(),
}).transform((data) => ({
  hostStatus: (data.hostStatus || data.status || 'ACTIVE').toUpperCase(),
  reason: data.reason,
}));

export const updateHostPerformanceSchema = z.object({
  liveHoursDelta: z.number().min(0, 'liveHoursDelta must be non-negative').optional(),
  diamondsDelta: z.union([z.string(), z.number(), z.bigint()]).refine(
    (val) => {
      try {
        const bi = BigInt(val);
        return bi >= 0n;
      } catch {
        return false;
      }
    },
    { message: 'diamondsDelta must be a non-negative integer amount' }
  ).optional(),
  targetDaysDelta: z.number().int().min(0, 'targetDaysDelta must be non-negative').optional(),
});

export const queryHostsSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional().default(''),
  status: z.enum(['APPLIED', 'ACTIVE', 'SUSPENDED', 'REJECTED']).optional(),
  hostType: z.enum(['LIVE_HOST', 'AUDIO_HOST', 'BOTH']).optional(),
  agencyId: z.string().optional(),
  bdCenterId: z.string().optional(),
});
