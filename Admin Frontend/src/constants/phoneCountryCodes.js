// ============================================================
// ZeParty Admin Portal — Country Phone & Dial Code Directory
// ============================================================

export const COUNTRY_PHONE_CONFIG = {
  PK: { code: 'PK', name: 'Pakistan', dialCode: '+92', digits: 10, placeholder: '301 5431674' },
  US: { code: 'US', name: 'United States', dialCode: '+1', digits: 10, placeholder: '555 123 4567' },
  CA: { code: 'CA', name: 'Canada', dialCode: '+1', digits: 10, placeholder: '555 123 4567' },
  GB: { code: 'GB', name: 'United Kingdom', dialCode: '+44', digits: 10, placeholder: '7911 123456' },
  SA: { code: 'SA', name: 'Saudi Arabia', dialCode: '+966', digits: 9, placeholder: '50 123 4567' },
  AE: { code: 'AE', name: 'United Arab Emirates', dialCode: '+971', digits: 9, placeholder: '50 123 4567' },
  IN: { code: 'IN', name: 'India', dialCode: '+91', digits: 10, placeholder: '98765 43210' },
  BD: { code: 'BD', name: 'Bangladesh', dialCode: '+880', digits: 10, placeholder: '1711 123456' },
  TR: { code: 'TR', name: 'Turkey', dialCode: '+90', digits: 10, placeholder: '501 123 4567' },
  DE: { code: 'DE', name: 'Germany', dialCode: '+49', digits: 11, placeholder: '151 1234567' },
  FR: { code: 'FR', name: 'France', dialCode: '+33', digits: 9, placeholder: '6 12 34 56 78' },
  EG: { code: 'EG', name: 'Egypt', dialCode: '+20', digits: 10, placeholder: '100 123 4567' },
  ID: { code: 'ID', name: 'Indonesia', dialCode: '+62', digits: 11, placeholder: '812 3456 7890' },
  MY: { code: 'MY', name: 'Malaysia', dialCode: '+60', digits: 10, placeholder: '12 345 6789' },
  PH: { code: 'PH', name: 'Philippines', dialCode: '+63', digits: 10, placeholder: '917 123 4567' },
  NG: { code: 'NG', name: 'Nigeria', dialCode: '+234', digits: 10, placeholder: '803 123 4567' },
  BR: { code: 'BR', name: 'Brazil', dialCode: '+55', digits: 11, placeholder: '11 91234 5678' },
  MX: { code: 'MX', name: 'Mexico', dialCode: '+52', digits: 10, placeholder: '55 1234 5678' },
  KW: { code: 'KW', name: 'Kuwait', dialCode: '+965', digits: 8, placeholder: '9123 4567' },
  QA: { code: 'QA', name: 'Qatar', dialCode: '+974', digits: 8, placeholder: '5512 3456' },
  OM: { code: 'OM', name: 'Oman', dialCode: '+968', digits: 8, placeholder: '9123 4567' },
  BH: { code: 'BH', name: 'Bahrain', dialCode: '+973', digits: 8, placeholder: '3912 3456' },
  JO: { code: 'JO', name: 'Jordan', dialCode: '+962', digits: 9, placeholder: '7 9123 4567' },
  IQ: { code: 'IQ', name: 'Iraq', dialCode: '+964', digits: 10, placeholder: '790 123 4567' },
  AU: { code: 'AU', name: 'Australia', dialCode: '+61', digits: 9, placeholder: '412 345 678' },
  ZA: { code: 'ZA', name: 'South Africa', dialCode: '+27', digits: 9, placeholder: '82 123 4567' },
  AF: { code: 'AF', name: 'Afghanistan', dialCode: '+93', digits: 9, placeholder: '70 123 4567' },
  CN: { code: 'CN', name: 'China', dialCode: '+86', digits: 11, placeholder: '138 1234 5678' },
  JP: { code: 'JP', name: 'Japan', dialCode: '+81', digits: 10, placeholder: '90 1234 5678' },
  KR: { code: 'KR', name: 'South Korea', dialCode: '+82', digits: 10, placeholder: '10 1234 5678' },
  RU: { code: 'RU', name: 'Russia', dialCode: '+7', digits: 10, placeholder: '912 345 6789' },
  ES: { code: 'ES', name: 'Spain', dialCode: '+34', digits: 9, placeholder: '612 345 678' },
  IT: { code: 'IT', name: 'Italy', dialCode: '+39', digits: 10, placeholder: '312 345 6789' },
  NL: { code: 'NL', name: 'Netherlands', dialCode: '+31', digits: 9, placeholder: '6 12345678' },
  SE: { code: 'SE', name: 'Sweden', dialCode: '+46', digits: 9, placeholder: '70 123 4567' },
  CH: { code: 'CH', name: 'Switzerland', dialCode: '+41', digits: 9, placeholder: '78 123 4567' },
  SG: { code: 'SG', name: 'Singapore', dialCode: '+65', digits: 8, placeholder: '8123 4567' },
  NZ: { code: 'NZ', name: 'New Zealand', dialCode: '+64', digits: 9, placeholder: '21 123 4567' },
  TH: { code: 'TH', name: 'Thailand', dialCode: '+66', digits: 9, placeholder: '81 234 5678' },
  VN: { code: 'VN', name: 'Vietnam', dialCode: '+84', digits: 9, placeholder: '91 234 5678' },
};

export const POPULAR_COUNTRY_CODES = [
  'PK', 'US', 'GB', 'SA', 'AE', 'IN', 'CA', 'TR', 'DE', 'FR', 'BD', 'EG', 'ID', 'MY', 'PH', 'NG', 'BR', 'MX', 'KW', 'QA'
];

/**
 * Get phone configuration for a country code
 */
export function getPhoneConfig(countryCode = 'PK') {
  const code = (countryCode || 'PK').toUpperCase();
  return COUNTRY_PHONE_CONFIG[code] || {
    code: code,
    name: code,
    dialCode: '+1',
    digits: 15,
    placeholder: 'Phone number',
  };
}

/**
 * Format local raw digits into spaced national representation (e.g., 3015431674 -> 301 5431674 or 0301 5431674)
 */
export function formatLocalPhoneNumber(rawDigits, countryCode = 'PK') {
  if (!rawDigits) return '';
  const digits = rawDigits.replace(/\D/g, '');
  if (!digits) return '';

  if (countryCode === 'PK') {
    // Pakistan: Handle leading 0 gracefully
    if (digits.startsWith('0')) {
      const trimmed = digits.slice(0, 11);
      if (trimmed.length <= 4) return trimmed;
      return `${trimmed.slice(0, 4)} ${trimmed.slice(4)}`;
    }
    const trimmed = digits.slice(0, 10);
    if (trimmed.length <= 3) return trimmed;
    return `${trimmed.slice(0, 3)} ${trimmed.slice(3)}`;
  }

  if (countryCode === 'US' || countryCode === 'CA') {
    const trimmed = digits.slice(0, 10);
    if (trimmed.length <= 3) return trimmed;
    if (trimmed.length <= 6) return `${trimmed.slice(0, 3)} ${trimmed.slice(3)}`;
    return `${trimmed.slice(0, 3)} ${trimmed.slice(3, 6)} ${trimmed.slice(6)}`;
  }

  if (digits.length <= 3) return digits;
  if (digits.length <= 6) return `${digits.slice(0, 3)} ${digits.slice(3)}`;
  return `${digits.slice(0, 3)} ${digits.slice(3, 6)} ${digits.slice(6, 12)}`;
}

/**
 * Compose full international phone number e.g., +923015431674
 */
export function toE164(localDigits, countryCode = 'PK') {
  if (!localDigits) return '';
  const config = getPhoneConfig(countryCode);
  let digits = localDigits.replace(/\D/g, '');
  if (!digits) return '';

  // Remove leading 0 if entered with trunk prefix (e.g., 0301 -> 301)
  if (digits.startsWith('0')) {
    digits = digits.slice(1);
  }

  // If user already typed dial code, keep it
  if (localDigits.startsWith('+')) {
    return localDigits.replace(/\s+/g, '');
  }

  return `${config.dialCode}${digits}`;
}
