/**
 * Utility for safe serialization of BigInt and Prisma Decimal values
 * into strings to prevent JSON.stringify crashes and precision loss.
 */

function isDecimalLike(val) {
  if (!val || typeof val !== 'object') return false;
  if (typeof val.toFixed === 'function' && typeof val.toNumber === 'function') return true;
  if (val.constructor && (val.constructor.name === 'Decimal' || val.constructor.isDecimal?.(val))) return true;
  if (val.isDecimal === true) return true;
  if (Array.isArray(val.d) && typeof val.s === 'number' && typeof val.e === 'number') return true;
  return false;
}

export function sanitizeFinancial(obj) {
  if (obj === null || obj === undefined) {
    return obj;
  }

  if (typeof obj === 'bigint') {
    return obj.toString();
  }

  if (isDecimalLike(obj)) {
    return obj.toString();
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => sanitizeFinancial(item));
  }

  if (typeof obj === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      if (typeof value === 'bigint') {
        sanitized[key] = value.toString();
      } else if (value instanceof Date) {
        sanitized[key] = value.toISOString();
      } else if (isDecimalLike(value)) {
        sanitized[key] = value.toString();
      } else if (value && typeof value === 'object') {
        sanitized[key] = sanitizeFinancial(value);
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  return obj;
}

export default {
  sanitizeFinancial,
};
