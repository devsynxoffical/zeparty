// Embedded mode pool stub: ZeParty-Backend uses Prisma + in-memory stores for gamesEngine.
export function hasDatabase() {
  return false;
}

export function getPool() {
  throw new Error('Direct pg pool is disabled in embedded ZeParty-Backend mode');
}

export async function closePool() {}

export async function withTransaction(fn) {
  throw new Error('Direct pg pool is disabled in embedded ZeParty-Backend mode');
}
