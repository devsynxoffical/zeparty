// Country code resolver utility from phone prefixes, HTTP headers, and locales

const COUNTRY_NAMES = {
  PK: 'Pakistan',
  US: 'United States',
  GB: 'United Kingdom',
  SA: 'Saudi Arabia',
  AE: 'United Arab Emirates',
  IN: 'India',
  BD: 'Bangladesh',
  CA: 'Canada',
  AU: 'Australia',
  DE: 'Germany',
  FR: 'France',
  TR: 'Turkey',
  EG: 'Egypt',
  ID: 'Indonesia',
  MY: 'Malaysia',
  PH: 'Philippines',
  BR: 'Brazil',
  CN: 'China',
  JP: 'Japan',
  KR: 'South Korea',
  RU: 'Russia',
  IT: 'Italy',
  ES: 'Spain',
  NL: 'Netherlands',
  SE: 'Sweden',
  CH: 'Switzerland',
  QA: 'Qatar',
  KW: 'Kuwait',
  OM: 'Oman',
  BH: 'Bahrain',
  IQ: 'Iraq',
  JO: 'Jordan',
  LB: 'Lebanon',
  AF: 'Afghanistan',
  ZA: 'South Africa',
  NG: 'Nigeria',
  KE: 'Kenya',
  GH: 'Ghana',
  MX: 'Mexico',
  AR: 'Argentina',
  CL: 'Chile',
  CO: 'Colombia',
  SG: 'Singapore',
  TH: 'Thailand',
  VN: 'Vietnam',
  NZ: 'New Zealand',
  NO: 'Norway',
  DK: 'Denmark',
  FI: 'Finland',
  PL: 'Poland',
};

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

export function countryCodeToEmoji(code) {
  if (!code || typeof code !== 'string') return '';
  const clean = code.trim().toUpperCase();
  if (clean.length !== 2) return '';
  const c1 = clean.charCodeAt(0) - 65 + 0x1F1E6;
  const c2 = clean.charCodeAt(1) - 65 + 0x1F1E6;
  if (c1 < 0x1F1E6 || c1 > 0x1F1FF || c2 < 0x1F1E6 || c2 > 0x1F1FF) return '';
  return String.fromCodePoint(c1, c2);
}

export function emojiToCountryCode(str) {
  if (!str || typeof str !== 'string') return null;
  const match = str.match(/[\uD83C][\uDDE6-\uDDFF][\uD83C][\uDDE6-\uDDFF]/);
  if (match) {
    const f = match[0];
    const c1 = String.fromCharCode(f.codePointAt(0) - 0x1F1E6 + 65);
    const c2 = String.fromCharCode(f.codePointAt(2) - 0x1F1E6 + 65);
    return (c1 + c2).toUpperCase();
  }
  return null;
}

export function getCountryName(code) {
  if (!code || typeof code !== 'string') return '';
  return COUNTRY_NAMES[code.trim().toUpperCase()] || code.trim().toUpperCase();
}

export function formatRegionString(code) {
  if (!code || typeof code !== 'string') return null;
  const clean = code.trim().toUpperCase();
  if (clean.length !== 2) return clean;
  const emoji = countryCodeToEmoji(clean);
  const name = getCountryName(clean);
  return emoji ? `${emoji} ${name}` : name;
}

export function resolveCountryCodeFromAny(input) {
  if (!input || typeof input !== 'string') return null;
  const trimmed = input.trim();
  if (!trimmed) return null;

  // 1. Check if input is a 2-letter ISO code
  if (/^[A-Za-z]{2}$/.test(trimmed)) {
    const upper = trimmed.toUpperCase();
    if (upper !== 'XX' && upper !== 'GLOBAL') return upper;
  }

  // 2. Check if input contains an emoji flag
  const emojiCode = emojiToCountryCode(trimmed);
  if (emojiCode) return emojiCode;

  // 3. Match country name against COUNTRY_NAMES dictionary
  const lower = trimmed.toLowerCase();
  for (const [c, name] of Object.entries(COUNTRY_NAMES)) {
    if (lower.includes(name.toLowerCase())) {
      return c;
    }
  }

  return null;
}

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
  
  // Cloudflare Geolocation Header (accurate real network country from edge IP)
  const cfCountry = headers['cf-ipcountry'] || headers['CF-IPCountry'];
  if (cfCountry && typeof cfCountry === 'string' && cfCountry.length === 2 && cfCountry !== 'XX' && cfCountry !== 'T1') {
    return cfCountry.toUpperCase();
  }

  return null;
}

export function resolveEffectiveCountryCode({ countryCode, phone, headers = {} } = {}) {
  // 1. If explicit valid 2-letter countryCode provided and not empty
  if (countryCode && typeof countryCode === 'string') {
    const trimmed = countryCode.trim().toUpperCase();
    if (trimmed.length === 2 && trimmed !== 'XX' && trimmed !== 'GLOBAL') {
      return trimmed;
    }
  }

  // 2. Resolve from phone number dialing prefix (accurate country of mobile carrier)
  if (phone) {
    const phoneCountry = resolveCountryFromPhone(phone);
    if (phoneCountry) return phoneCountry;
  }

  // 3. Resolve from request headers (Cloudflare IP geolocation)
  const headerCountry = resolveCountryFromHeaders(headers);
  if (headerCountry) return headerCountry;

  // 4. Default to null if accurate country cannot be determined (never assign random country)
  return null;
}

export default {
  COUNTRY_NAMES,
  countryCodeToEmoji,
  emojiToCountryCode,
  getCountryName,
  formatRegionString,
  resolveCountryCodeFromAny,
  resolveCountryFromPhone,
  resolveCountryFromHeaders,
  resolveEffectiveCountryCode,
};
