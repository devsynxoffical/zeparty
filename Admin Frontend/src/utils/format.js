// ============================================================
// ZeParty Admin Portal — Utility Functions (JavaScript)
// ============================================================

function sanitizeNum(val) {
  if (val === null || val === undefined) return 0;
  const num = Number(val);
  return isNaN(num) || !isFinite(num) ? 0 : num;
}

/**
 * Format a number with locale-aware comma separation
 */
export function formatNumber(value) {
  const num = sanitizeNum(value);
  return new Intl.NumberFormat('en-US').format(num);
}

/**
 * Format a compact number (e.g. 1.2K, 4.5M)
 */
export function formatCompact(value) {
  const num = sanitizeNum(value);
  return new Intl.NumberFormat('en-US', {
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(num);
}

/**
 * Format currency value in USD
 */
export function formatCurrency(value, currency = 'USD') {
  const num = sanitizeNum(value);
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    maximumFractionDigits: 0,
  }).format(num);
}

/**
 * Format a percentage with sign
 */
export function formatPercent(value, showSign = true) {
  const sign = showSign && value > 0 ? '+' : '';
  return `${sign}${value.toFixed(1)}%`;
}

/**
 * Format a timestamp to a readable relative time (e.g. "2 hours ago")
 */
export function timeAgo(timestamp) {
  if (!timestamp) return '—';
  const date = typeof timestamp === 'string' ? new Date(timestamp) : timestamp;
  if (!(date instanceof Date) || isNaN(date.getTime())) return '—';
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSecs = Math.floor(diffMs / 1000);
  const diffMins = Math.floor(diffSecs / 60);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSecs < 60) return 'just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;

  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/**
 * Format an ISO date string to a short date
 */
export function formatDate(timestamp) {
  if (!timestamp) return '—';
  const date = typeof timestamp === 'string' ? new Date(timestamp) : timestamp;
  if (!(date instanceof Date) || isNaN(date.getTime())) return '—';
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

/**
 * Capitalize the first letter of a string
 */
export function capitalize(str) {
  if (!str) return '';
  return str.charAt(0).toUpperCase() + str.slice(1);
}

/**
 * Truncate a string with ellipsis
 */
export function truncate(str, maxLength) {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - 3) + '...';
}

/**
 * Generate a random avatar background color from a seed string
 */
export function avatarColor(seed) {
  const colors = [
    '#6366f1', '#8b5cf6', '#ec4899', '#f59e0b',
    '#10b981', '#3b82f6', '#ef4444', '#14b8a6',
  ];
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = seed.charCodeAt(i) + ((hash << 5) - hash);
  }
  return colors[Math.abs(hash) % colors.length];
}

/**
 * Get initials from a display name
 */
export function getInitials(name) {
  if (!name) return 'ZP';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}
