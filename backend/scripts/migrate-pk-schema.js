import prisma from '../src/config/database.js';
import { ensureDatabaseSchema } from '../src/config/schemaMigrator.js';

async function main() {
  console.log('🚀 Running manual database schema migration for PKEvent & related tables...');
  try {
    await prisma.$connect();
    await ensureDatabaseSchema(prisma);
    console.log('🎉 Database migration finished successfully!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect().catch(() => {});
  }
}

main();
