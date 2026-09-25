import prisma from '../src/config/database.js';

async function migrateRemainingUsers() {
  try {
    const users = await prisma.user.findMany({
      select: { id: true, username: true, phone: true }
    });

    console.log(`Total users in DB: ${users.length}`);
    const is7Digit = (id) => /^[1-9]\d{6}$/.test(id);
    const usedIds = new Set();
    users.forEach(u => {
      if (is7Digit(u.id)) usedIds.add(u.id);
    });

    const toMigrate = users.filter(u => !is7Digit(u.id));
    console.log(`Users needing migration: ${toMigrate.length}`);

    for (const u of toMigrate) {
      let newId;
      do {
        newId = Math.floor(1000000 + Math.random() * 9000000).toString();
      } while (usedIds.has(newId));
      usedIds.add(newId);

      console.log(`Migrating @${u.username}: ${u.id} -> ${newId}`);
      await prisma.$executeRawUnsafe(`UPDATE "User" SET "id" = $1 WHERE "id" = $2`, newId, u.id);
      console.log(` -> Done.`);
    }

    console.log('✅ ALL USERS MIGRATED SUCCESSFULLY!');
    const finalUsers = await prisma.user.findMany({
      select: { id: true, username: true, phone: true }
    });
    console.log('--- FINAL USER LIST (ALL 7-DIGIT IDS) ---');
    finalUsers.forEach(u => console.log(`ID: ${u.id} | @${u.username}`));
  } catch (err) {
    console.error('Migration error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

migrateRemainingUsers();
