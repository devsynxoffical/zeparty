import { z } from 'zod';

export const createBannerSchema = z
  .object({
    title: z.string().trim().min(1, 'Title is required').max(150),
    imageUrl: z.string().min(1, 'Image or banner creative is required').optional(),
    image: z.string().min(1).optional(),
    imageWidth: z.coerce.number().optional(),
    imageHeight: z.coerce.number().optional(),
    destinationUrl: z.string().optional().nullable(),
    linkUrl: z.string().optional().nullable(),
    placement: z.string().optional(),
    targetType: z.enum(['GLOBAL', 'COUNTRY_WISE', 'GLOBAL_OR_SELECTED', 'Global', 'Country-wise']).optional(),
    countries: z.union([z.array(z.string()), z.string()]).optional(),
    position: z.coerce.number().int().optional(),
    priority: z.coerce.number().int().optional(),
    isActive: z.union([z.boolean(), z.string()]).optional(),
    status: z.string().optional(),
    startsAt: z.string().optional().nullable(),
    startDate: z.string().optional().nullable(),
    endsAt: z.string().optional().nullable(),
    endDate: z.string().optional().nullable(),
  })
  .refine(
    (data) => {
      if (data.imageWidth !== undefined && data.imageHeight !== undefined) {
        if (Number(data.imageWidth) !== 700 || Number(data.imageHeight) !== 200) {
          return false;
        }
      }
      return true;
    },
    { message: 'Image size must be exactly 700 × 200 px' }
  )
  .transform((data) => {
    const isAct = data.isActive !== undefined
      ? (typeof data.isActive === 'boolean' ? data.isActive : data.isActive === 'true')
      : (data.status ? data.status.toUpperCase() === 'ACTIVE' : true);

    const sAt = data.startsAt || data.startDate || null;
    const eAt = data.endsAt || data.endDate || null;

    let countryList = [];
    if (Array.isArray(data.countries)) {
      countryList = data.countries.map((c) => String(c).toUpperCase());
    } else if (typeof data.countries === 'string' && data.countries.trim()) {
      countryList = data.countries.split(',').map((c) => c.trim().toUpperCase());
    }

    const normTargetType = (data.targetType || (countryList.length > 0 ? 'COUNTRY_WISE' : 'GLOBAL')).toUpperCase().includes('COUNTRY')
      ? 'COUNTRY_WISE'
      : 'GLOBAL';

    return {
      title: data.title,
      imageUrl: data.imageUrl || data.image || 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=700&h=200&q=80',
      destinationUrl: data.destinationUrl || data.linkUrl || null,
      placement: data.placement || 'HOME_CAROUSEL',
      targetType: normTargetType,
      countries: countryList,
      position: Number(data.position !== undefined ? data.position : (data.priority !== undefined ? data.priority : 0)),
      isActive: isAct,
      startsAt: sAt ? new Date(sAt).toISOString() : null,
      endsAt: eAt ? new Date(eAt).toISOString() : null,
    };
  });


export const updateBannerSchema = z
  .object({
    title: z.string().trim().min(1).max(150).optional(),
    imageUrl: z.string().min(1).optional(),
    image: z.string().min(1).optional(),
    destinationUrl: z.string().optional().nullable(),
    linkUrl: z.string().optional().nullable(),
    position: z.coerce.number().int().optional(),
    priority: z.coerce.number().int().optional(),
    isActive: z.union([z.boolean(), z.string()]).optional(),
    status: z.string().optional(),
    startsAt: z.string().optional().nullable(),
    startDate: z.string().optional().nullable(),
    endsAt: z.string().optional().nullable(),
    endDate: z.string().optional().nullable(),
  })
  .transform((data) => {
    const res = {};
    if (data.title !== undefined) res.title = data.title;
    if (data.imageUrl !== undefined || data.image !== undefined) res.imageUrl = data.imageUrl || data.image;
    if (data.destinationUrl !== undefined || data.linkUrl !== undefined) res.destinationUrl = data.destinationUrl || data.linkUrl;
    if (data.position !== undefined || data.priority !== undefined) res.position = Number(data.position !== undefined ? data.position : data.priority);
    if (data.isActive !== undefined) {
      res.isActive = typeof data.isActive === 'boolean' ? data.isActive : data.isActive === 'true';
    } else if (data.status !== undefined) {
      res.isActive = data.status.toUpperCase() === 'ACTIVE';
    }
    const sAt = data.startsAt || data.startDate;
    if (sAt !== undefined) res.startsAt = sAt ? new Date(sAt).toISOString() : null;
    const eAt = data.endsAt || data.endDate;
    if (eAt !== undefined) res.endsAt = eAt ? new Date(eAt).toISOString() : null;
    return res;
  });

export const queryAdminBannersSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  isActive: z.string().optional(),
  search: z.string().trim().optional(),
});

export const bannerIdParamSchema = z.object({
  id: z.string().min(1, 'Banner ID is required'),
});

export default {
  createBannerSchema,
  updateBannerSchema,
  queryAdminBannersSchema,
  bannerIdParamSchema,
};
