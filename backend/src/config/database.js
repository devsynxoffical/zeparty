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

const dbUrl = process.env.DATABASE_URL || process.env.DATABASE_PUBLIC_URL || env.DATABASE_URL;

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: dbUrl,
    },
  },
  log: getPrismaLogLevels(),
});

export default prisma;
