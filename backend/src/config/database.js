import { PrismaClient } from '@prisma/client';
import env from './env.js';

const getPrismaLogLevels = () => {
  if (env.PRISMA_LOG_QUERIES) {
    return ['query', 'info', 'warn', 'error'];
  }
  if (env.NODE_ENV === 'development') {
    return ['warn', 'error'];
  }
  return ['error'];
};

let dbUrl = process.env.DATABASE_URL || process.env.DATABASE_PUBLIC_URL || env.DATABASE_URL;
if (dbUrl && dbUrl.includes('sslmode=no-verify')) {
  dbUrl = dbUrl.replace('sslmode=no-verify', 'sslmode=disable');
}
if (dbUrl && dbUrl.includes('altaria.proxy.rlwy.net')) {
  dbUrl = dbUrl.replace('altaria.proxy.rlwy.net', '66.33.22.220');
}
if (dbUrl && !dbUrl.includes('connect_timeout=')) {
  const sep = dbUrl.includes('?') ? '&' : '?';
  dbUrl = `${dbUrl}${sep}connect_timeout=30&pool_timeout=30&socket_timeout=30`;
}

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: dbUrl,
    },
  },
  log: getPrismaLogLevels(),
});

export default prisma;
