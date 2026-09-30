// Country code resolver utility from phone prefixes, HTTP headers, and locales

const PHONE_DIAL_PREFIX_MAP = [
  { prefix: '+92', country: 'PK' },
  { prefix: '+966', country: 'SA' },
  { prefix: '+971', country: 'AE' },
  { prefix: '+91', country: 'IN' },
  { prefix: '+880', country: 'BD' },
  { prefix: '+62', country: 'ID' },
  { prefix: '+90', country: 'TR' },
  { prefix: '+44', country: 'GB' },
  { prefix: '+1', country: 'US' },
  { prefix: '+49', country: 'DE' },
  { prefix: '+33', country: 'FR' },
  { prefix: '+55', country: 'BR' },
  { prefix: '+20', country: 'EG' },
  { prefix: '+234', country: 'NG' },
  { prefix: '+60', country: 'MY' },
  { prefix: '+63', country: 'PH' },
  { prefix: '+84', country: 'VN' },
  { prefix: '+81', country: 'JP' },
  { prefix: '+82', country: 'KR' },
  { prefix: '+964', country: 'IQ' },
  { prefix: '+965', country: 'KW' },
  { prefix: '+974', country: 'QA' },
  { prefix: '+968', country: 'OM' },
  { prefix: '+973', country: 'BH' },
  { prefix: '+962', country: 'JO' },
  { prefix: '+961', country: 'LB' },
  { prefix: '+212', country: 'MA' },
  { prefix: '+213', country: 'DZ' },
  { prefix: '+216', country: 'TN' },
  { prefix: '+218', country: 'LY' },
  { prefix: '+249', country: 'SD' },
  { prefix: '+967', country: 'YE' },
  { prefix: '+963', country: 'SY' },
  { prefix: '+970', country: 'PS' },
  { prefix: '+93', country: 'AF' },
  { prefix: '+98', country: 'IR' },
  { prefix: '+7', country: 'RU' },
  { prefix: '+39', country: 'IT' },
  { prefix: '+34', country: 'ES' },
  { prefix: '+31', country: 'NL' },
  { prefix: '+41', country: 'CH' },
  { prefix: '+46', country: 'SE' },
  { prefix: '+47', country: 'NO' },
  { prefix: '+45', country: 'DK' },
  { prefix: '+358', country: 'FI' },
  { prefix: '+48', country: 'PL' },
  { prefix: '+43', country: 'AT' },
  { prefix: '+32', country: 'BE' },
  { prefix: '+61', country: 'AU' },
  { prefix: '+64', country: 'NZ' },
  { prefix: '+27', country: 'ZA' },
  { prefix: '+254', country: 'KE' },
  { prefix: '+255', country: 'TZ' },
  { prefix: '+256', country: 'UG' },
  { prefix: '+233', country: 'GH' },
  { prefix: '+977', country: 'NP' },
  { prefix: '+94', country: 'LK' },
  { prefix: '+95', country: 'MM' },
  { prefix: '+66', country: 'TH' },
  { prefix: '+855', country: 'KH' },
  { prefix: '+856', country: 'LA' },
  { prefix: '+65', country: 'SG' },
];

export function resolveCountryFromPhone(phone) {
  if (!phone || typeof phone !== 'string') return null;
  const clean = phone.trim().replace(/[^\d+]/g, '');
  const withPlus = clean.startsWith('+') ? clean : `+${clean}`;
  
  for (const item of PHONE_DIAL_PREFIX_MAP) {
    if (withPlus.startsWith(item.prefix)) {
      return item.country;
    }
  }
  return null;
}

export function resolveCountryFromHeaders(headers = {}) {
  if (!headers) return null;
  
  // Cloudflare Header
  const cfCountry = headers['cf-ipcountry'] || headers['CF-IPCountry'];
  if (cfCountry && typeof cfCountry === 'string' && cfCountry.length === 2 && cfCountry !== 'XX' && cfCountry !== 'T1') {
    return cfCountry.toUpperCase();
  }

  // Custom App Headers
  const appCountry = headers['x-country-code'] || headers['x-app-country'] || headers['x-country'];
  if (appCountry && typeof appCountry === 'string' && appCountry.trim().length === 2) {
    return appCountry.trim().toUpperCase();
  }

  // Accept-Language fallback (e.g. "ur-PK", "en-US", "ar-SA")
  const acceptLang = headers['accept-language'] || headers['Accept-Language'];
  if (acceptLang && typeof acceptLang === 'string') {
    const match = acceptLang.match(/[a-z]{2}-([A-Z]{2})/);
    if (match && match[1]) {
      return match[1];
    }
  }

  return null;
}

export function resolveEffectiveCountryCode({ countryCode, phone, headers = {} } = {}) {
  // 1. If explicit valid 2-letter countryCode provided and not empty
  if (countryCode && typeof countryCode === 'string') {
    const trimmed = countryCode.trim().toUpperCase();
    if (trimmed.length === 2 && trimmed !== 'XX') {
      return trimmed;
    }
  }

  // 2. Resolve from phone number dialing prefix
  if (phone) {
    const phoneCountry = resolveCountryFromPhone(phone);
    if (phoneCountry) return phoneCountry;
  }

  // 3. Resolve from request headers (Cloudflare, App, Accept-Language)
  const headerCountry = resolveCountryFromHeaders(headers);
  if (headerCountry) return headerCountry;

  // 4. Default to GLOBAL
  return 'GLOBAL';
}

export default {
  resolveCountryFromPhone,
  resolveCountryFromHeaders,
  resolveEffectiveCountryCode,
};
