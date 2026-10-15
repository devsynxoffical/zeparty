import { z } from 'zod';

export const createAgencySchema = z.object({
  agencyName: z.string().min(2, 'Agency name must be at least 2 characters').max(100),
  agencyCode: z
    .string()
    .min(3, 'Agency code must be at least 3 characters')
    .max(30)
    .regex(/^[A-Za-z0-9_-]+$/, 'Agency code must contain only alphanumeric characters, underscores, or hyphens')
    .transform((val) => val.toUpperCase().trim())
    .optional(),
  description: z.string().max(500).optional().nullable(),
  phoneNumber: z.string().optional().nullable(),
  countryCallingCode: z.string().optional().nullable(),
  hostIds: z.array(z.string()).max(5).optional().default([]),
  agencyType: z
    .enum(['AUDIO_AGENCY'], {
      errorMap: () => ({
        message: 'Agencies are exclusively for Audio Hosts. Live video hosts register directly with the platform.',
      }),
    })
    .default('AUDIO_AGENCY'),
  commissionRate: z.coerce.number().min(0, 'Commission rate must be >= 0').max(100, 'Commission rate must be <= 100').default(20.0),
  bdCenterId: z.string().optional().nullable(),
});

export const updateAgencySchema = z.object({
  agencyName: z.string().min(2).max(100).optional(),
  commissionRate: z.coerce.number().min(0).max(100).optional(),
  status: z.enum(['ACTIVE', 'SUSPENDED']).optional(),
  bdCenterId: z.string().optional().nullable(),
});

export const transferHostSchema = z.object({
  hostProfileId: z.string().min(1, 'Host profile ID is required'),
  fromAgencyId: z.string().min(1, 'Source agency ID is required'),
  toAgencyId: z.string().min(1, 'Destination agency ID is required'),
  reason: z.string().min(3, 'Transfer reason must be at least 3 characters').max(500),
}).refine(
  (data) => data.fromAgencyId !== data.toAgencyId,
  {
    message: 'Source agency and destination agency cannot be the same',
    path: ['toAgencyId'],
  }
);

export const bindHostSchema = z.object({
  hostProfileId: z.string().min(1, 'Host profile ID is required'),
});

export const queryAgenciesSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional().default(''),
  status: z.enum(['ACTIVE', 'SUSPENDED']).optional(),
  agencyType: z.enum(['LIVE_AGENCY', 'AUDIO_AGENCY', 'HYBRID']).optional(),
  bdCenterId: z.string().optional(),
});

// ==========================================
// CHANGE 17: Agency Application Schemas
// ==========================================

const E164_PHONE_REGEX = /^\+[1-9]\d{6,14}$/;

function validateAndNormalizePhone(rawPhone) {
  if (!rawPhone || typeof rawPhone !== 'string') {
    return { valid: false, error: 'Phone number with country code is required' };
  }
  const trimmed = rawPhone.trim();
  if (!trimmed.startsWith('+')) {
    return { valid: false, error: 'Phone number must include country code starting with "+" (e.g. +15551234567)' };
  }
  // Strip out spaces, dashes, parentheses after the leading '+'
  const cleaned = '+' + trimmed.slice(1).replace(/[\s\-\(\)\.]/g, '');
  if (!E164_PHONE_REGEX.test(cleaned)) {
    return { valid: false, error: 'Invalid international phone number format. Must include country code and 7-15 digits total' };
  }
  return { valid: true, value: cleaned };
}

export const submitAgencyApplicationSchema = z.object({
  agencyName: z
    .string({ required_error: 'Agency name is required' })
    .trim()
    .min(2, 'Agency name must be at least 2 characters')
    .max(100, 'Agency name must not exceed 100 characters'),
  name: z.string().trim().min(2).max(100).optional(),
  description: z
    .string({ required_error: 'Agency description is required' })
    .trim()
    .min(5, 'Agency description must be at least 5 characters')
    .max(1000, 'Agency description must not exceed 1000 characters'),
  phoneNumber: z.string().optional(),
  phone: z.string().optional(),
  contactNumber: z.string().optional(),

  // Individual fields
  hostRef1: z.string().optional(),
  hostRef2: z.string().optional(),
  hostRef3: z.string().optional(),
  hostRef4: z.string().optional(),
  hostRef5: z.string().optional(),

  // Aliases
  hostId1: z.string().optional(),
  hostId2: z.string().optional(),
  hostId3: z.string().optional(),
  hostId4: z.string().optional(),
  hostId5: z.string().optional(),

  // Array alias
  hostIds: z.array(z.string()).optional(),
  externalHostIds: z.array(z.string()).optional(),
}).superRefine((data, ctx) => {
  // 1. Phone number validation
  const rawPhone = data.phoneNumber || data.phone || data.contactNumber;
  if (!rawPhone || String(rawPhone).trim().length === 0) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Phone number with country code is required',
      path: ['phoneNumber'],
    });
  } else {
    const phoneRes = validateAndNormalizePhone(rawPhone);
    if (!phoneRes.valid) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: phoneRes.error,
        path: ['phoneNumber'],
      });
    }
  }

  // 2. Resolve 5 external host references
  const refs = [
    data.hostRef1 ?? data.hostId1 ?? (data.hostIds ? data.hostIds[0] : undefined) ?? (data.externalHostIds ? data.externalHostIds[0] : undefined),
    data.hostRef2 ?? data.hostId2 ?? (data.hostIds ? data.hostIds[1] : undefined) ?? (data.externalHostIds ? data.externalHostIds[1] : undefined),
    data.hostRef3 ?? data.hostId3 ?? (data.hostIds ? data.hostIds[2] : undefined) ?? (data.externalHostIds ? data.externalHostIds[2] : undefined),
    data.hostRef4 ?? data.hostId4 ?? (data.hostIds ? data.hostIds[3] : undefined) ?? (data.externalHostIds ? data.externalHostIds[3] : undefined),
    data.hostRef5 ?? data.hostId5 ?? (data.hostIds ? data.hostIds[4] : undefined) ?? (data.externalHostIds ? data.externalHostIds[4] : undefined),
  ];

  for (let i = 0; i < 5; i++) {
    const ref = refs[i];
    const fieldName = `hostId${i + 1}`;
    if (!ref || typeof ref !== 'string' || ref.trim().length === 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: `Host ID ${i + 1} (external host reference) is required`,
        path: [fieldName],
      });
    } else if (ref.trim().length > 100) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: `Host ID ${i + 1} must not exceed 100 characters`,
        path: [fieldName],
      });
    }
  }

  // 3. Distinctness check across all 5 host references (case-insensitive & trimmed)
  const nonNullRefs = refs.filter((r) => r && typeof r === 'string' && r.trim().length > 0);
  if (nonNullRefs.length === 5) {
    const normalized = nonNullRefs.map((r) => r.trim().toLowerCase());
    const uniqueNormalized = new Set(normalized);
    if (uniqueNormalized.size < 5) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'All 5 external host references must be distinct',
        path: ['hostIds'],
      });
    }
  }
}).transform((data) => {
  const finalPhone = validateAndNormalizePhone(data.phoneNumber || data.phone || data.contactNumber);
  const refs = [
    data.hostRef1 ?? data.hostId1 ?? (data.hostIds ? data.hostIds[0] : undefined) ?? (data.externalHostIds ? data.externalHostIds[0] : undefined),
    data.hostRef2 ?? data.hostId2 ?? (data.hostIds ? data.hostIds[1] : undefined) ?? (data.externalHostIds ? data.externalHostIds[1] : undefined),
    data.hostRef3 ?? data.hostId3 ?? (data.hostIds ? data.hostIds[2] : undefined) ?? (data.externalHostIds ? data.externalHostIds[2] : undefined),
    data.hostRef4 ?? data.hostId4 ?? (data.hostIds ? data.hostIds[3] : undefined) ?? (data.externalHostIds ? data.externalHostIds[3] : undefined),
    data.hostRef5 ?? data.hostId5 ?? (data.hostIds ? data.hostIds[4] : undefined) ?? (data.externalHostIds ? data.externalHostIds[4] : undefined),
  ];

  return {
    agencyName: (data.agencyName || data.name).trim(),
    description: data.description.trim(),
    phoneNumber: finalPhone.valid ? finalPhone.value : String(data.phoneNumber || data.phone || data.contactNumber).trim(),
    hostRef1: String(refs[0]).trim(),
    hostRef2: String(refs[1]).trim(),
    hostRef3: String(refs[2]).trim(),
    hostRef4: String(refs[3]).trim(),
    hostRef5: String(refs[4]).trim(),
  };
});

export const rejectAgencyApplicationSchema = z.object({
  reason: z
    .string({ required_error: 'Rejection reason is required' })
    .trim()
    .min(3, 'Rejection reason must be at least 3 characters')
    .max(500, 'Rejection reason must not exceed 500 characters'),
});

export const queryAgencyApplicationsSchema = z.object({
  status: z.enum(['PENDING', 'APPROVED', 'REJECTED', 'ALL']).optional().default('ALL'),
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional().default(''),
});
