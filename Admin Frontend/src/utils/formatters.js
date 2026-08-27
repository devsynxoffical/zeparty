// ============================================================
// ZeParty Admin Portal — Formatters Barrel (JavaScript)
// Re-exports all format utilities with additional aliases
// ============================================================

export {
  formatNumber,
  formatCompact,
  formatCurrency,
  formatPercent,
  timeAgo,
  formatDate,
  capitalize,
  truncate,
  avatarColor,
  getInitials,
} from './format';

// Alias: formatDistanceToNow === timeAgo
export { timeAgo as formatDistanceToNow } from './format';
