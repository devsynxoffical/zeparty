// ============================================================
// ZeParty Canonical Country Normalization Utility
// ISO 3166-1 alpha-2 authoritative mapping and validation
// ============================================================

export const CANONICAL_COUNTRIES = [
  { code: 'PK', name: 'Pakistan', shortName: 'PAK', aliases: ['pk', 'pak', 'pakistan'] },
  { code: 'US', name: 'United States', shortName: 'USA', aliases: ['us', 'usa', 'united states', 'united states of america'] },
  { code: 'GB', name: 'United Kingdom', shortName: 'UK', aliases: ['gb', 'uk', 'united kingdom', 'great britain', 'england'] },
  { code: 'AE', name: 'United Arab Emirates', shortName: 'UAE', aliases: ['ae', 'uae', 'united arab emirates', 'dubai'] },
  { code: 'SA', name: 'Saudi Arabia', shortName: 'KSA', aliases: ['sa', 'ksa', 'saudi arabia', 'saudi'] },
  { code: 'IN', name: 'India', shortName: 'IND', aliases: ['in', 'ind', 'india'] },
  { code: 'BD', name: 'Bangladesh', shortName: 'BAN', aliases: ['bd', 'ban', 'bangladesh'] },
  { code: 'CA', name: 'Canada', shortName: 'CAN', aliases: ['ca', 'can', 'canada'] },
  { code: 'AU', name: 'Australia', shortName: 'AUS', aliases: ['au', 'aus', 'australia'] },
  { code: 'DE', name: 'Germany', shortName: 'GER', aliases: ['de', 'ger', 'germany', 'deutschland'] },
  { code: 'FR', name: 'France', shortName: 'FRA', aliases: ['fr', 'fra', 'france'] },
  { code: 'IT', name: 'Italy', shortName: 'ITA', aliases: ['it', 'ita', 'italy'] },
  { code: 'ES', name: 'Spain', shortName: 'ESP', aliases: ['es', 'esp', 'spain'] },
  { code: 'TR', name: 'Turkey', shortName: 'TUR', aliases: ['tr', 'tur', 'turkey', 'turkiye'] },
  { code: 'EG', name: 'Egypt', shortName: 'EGY', aliases: ['eg', 'egy', 'egypt'] },
  { code: 'ID', name: 'Indonesia', shortName: 'IDN', aliases: ['id', 'idn', 'indonesia'] },
  { code: 'MY', name: 'Malaysia', shortName: 'MAS', aliases: ['my', 'mas', 'mys', 'malaysia'] },
  { code: 'PH', name: 'Philippines', shortName: 'PHI', aliases: ['ph', 'phi', 'philippines'] },
  { code: 'BR', name: 'Brazil', shortName: 'BRA', aliases: ['br', 'bra', 'brazil', 'brasil'] },
  { code: 'MX', name: 'Mexico', shortName: 'MEX', aliases: ['mx', 'mex', 'mexico'] },
  { code: 'NG', name: 'Nigeria', shortName: 'NGA', aliases: ['ng', 'nga', 'nigeria'] },
  { code: 'ZA', name: 'South Africa', shortName: 'RSA', aliases: ['za', 'rsa', 'south africa'] },
  { code: 'KW', name: 'Kuwait', shortName: 'KUW', aliases: ['kw', 'kuw', 'kuwait'] },
  { code: 'QA', name: 'Qatar', shortName: 'QAT', aliases: ['qa', 'qat', 'qatar'] },
  { code: 'OM', name: 'Oman', shortName: 'OMA', aliases: ['om', 'oma', 'oman'] },
  { code: 'BH', name: 'Bahrain', shortName: 'BHR', aliases: ['bh', 'bhr', 'bahrain'] },
  { code: 'IQ', name: 'Iraq', shortName: 'IRQ', aliases: ['iq', 'irq', 'iraq'] },
  { code: 'JO', name: 'Jordan', shortName: 'JOR', aliases: ['jo', 'jor', 'jordan'] },
  { code: 'LB', name: 'Lebanon', shortName: 'LBN', aliases: ['lb', 'lbn', 'lebanon'] },
  { code: 'AF', name: 'Afghanistan', shortName: 'AFG', aliases: ['af', 'afg', 'afghanistan'] },
  { code: 'NP', name: 'Nepal', shortName: 'NEP', aliases: ['np', 'nep', 'nepal'] },
  { code: 'LK', name: 'Sri Lanka', shortName: 'SRI', aliases: ['lk', 'sri', 'sri lanka'] },
  { code: 'TH', name: 'Thailand', shortName: 'THA', aliases: ['th', 'tha', 'thailand'] },
  { code: 'VN', name: 'Vietnam', shortName: 'VIE', aliases: ['vn', 'vie', 'vietnam'] },
  { code: 'JP', name: 'Japan', shortName: 'JPN', aliases: ['jp', 'jpn', 'japan'] },
  { code: 'KR', name: 'South Korea', shortName: 'KOR', aliases: ['kr', 'kor', 'korea', 'south korea'] },
  { code: 'CN', name: 'China', shortName: 'CHN', aliases: ['cn', 'chn', 'china'] },
  { code: 'RU', name: 'Russia', shortName: 'RUS', aliases: ['ru', 'rus', 'russia'] },
  { code: 'NL', name: 'Netherlands', shortName: 'NED', aliases: ['nl', 'ned', 'netherlands', 'holland'] },
  { code: 'SE', name: 'Sweden', shortName: 'SWE', aliases: ['se', 'swe', 'sweden'] },
  { code: 'NO', name: 'Norway', shortName: 'NOR', aliases: ['no', 'nor', 'norway'] },
  { code: 'DK', name: 'Denmark', shortName: 'DEN', aliases: ['dk', 'den', 'denmark'] },
  { code: 'FI', name: 'Finland', shortName: 'FIN', aliases: ['fi', 'fin', 'finland'] },
  { code: 'CH', name: 'Switzerland', shortName: 'SUI', aliases: ['ch', 'sui', 'switzerland'] },
  { code: 'AT', name: 'Austria', shortName: 'AUT', aliases: ['at', 'aut', 'austria'] },
  { code: 'BE', name: 'Belgium', shortName: 'BEL', aliases: ['be', 'bel', 'belgium'] },
  { code: 'IE', name: 'Ireland', shortName: 'IRL', aliases: ['ie', 'irl', 'ireland'] },
  { code: 'NZ', name: 'New Zealand', shortName: 'NZL', aliases: ['nz', 'nzl', 'new zealand'] },
  { code: 'SG', name: 'Singapore', shortName: 'SGP', aliases: ['sg', 'sgp', 'singapore'] },
];

/**
 * Normalizes any country input (2-letter code, 3-letter code, or country name)
 * to an authoritative canonical representation: { code: 'PK', name: 'Pakistan', shortName: 'PAK' }
 * Returns null if the country is unresolvable or invalid.
 */
export function normalizeCountry(input) {
  if (!input || typeof input !== 'string') return null;
  const clean = input.trim().toLowerCase();
  if (!clean || clean === 'all' || clean === 'global' || clean === 'xx' || clean === 'unknown') {
    return null;
  }

  // 1. Direct match on code
  const upper = clean.toUpperCase();
  const directMatch = CANONICAL_COUNTRIES.find((c) => c.code === upper);
  if (directMatch) {
    return { code: directMatch.code, name: directMatch.name, shortName: directMatch.shortName };
  }

  // 2. Match on aliases, shortName, or name
  for (const c of CANONICAL_COUNTRIES) {
    if (c.shortName.toLowerCase() === clean) {
      return { code: c.code, name: c.name, shortName: c.shortName };
    }
    if (c.name.toLowerCase() === clean) {
      return { code: c.code, name: c.name, shortName: c.shortName };
    }
    if (c.aliases && c.aliases.includes(clean)) {
      return { code: c.code, name: c.name, shortName: c.shortName };
    }
  }

  // 3. Substring matching for multi-word country names
  for (const c of CANONICAL_COUNTRIES) {
    if (c.name.toLowerCase().includes(clean) || clean.includes(c.name.toLowerCase())) {
      return { code: c.code, name: c.name, shortName: c.shortName };
    }
  }

  // If 2 uppercase ASCII letters, accept as valid ISO code even if not in popular list
  if (upper.length === 2 && /^[A-Z]{2}$/.test(upper)) {
    return { code: upper, name: upper, shortName: upper };
  }

  return null;
}

/**
 * Checks whether two country representations resolve to the same canonical country.
 */
export function isCountryMatch(countryA, countryB) {
  const normA = normalizeCountry(countryA);
  const normB = normalizeCountry(countryB);
  if (!normA || !normB) return false;
  return normA.code === normB.code;
}

export default {
  CANONICAL_COUNTRIES,
  normalizeCountry,
  isCountryMatch,
};
