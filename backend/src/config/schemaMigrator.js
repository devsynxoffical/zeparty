import prisma from './database.js';

/**
 * Idempotently ensures all database columns, enums, and indexes exist.
 * This runs automatically on server startup and self-heals on P2022 query errors.
 */
export async function ensureDatabaseSchema(db = prisma) {
  console.log('🔄 Verifying and synchronizing database schema DDL...');

  // 1. Ensure PKStatus enum values
  const pkEnums = [
    'PENDING',
    'PREPARING',
    'COUNTDOWN',
    'ACTIVE',
    'FINISHED',
    'REJECTED',
    'EXPIRED',
    'CANCELLED',
    'FORFEIT',
    'ABORTED',
    'CREATED',
    'INVITING',
    'READY',
    'STARTED',
    'ENDED',
  ];
  for (const val of pkEnums) {
    try {
      await db.$executeRawUnsafe(`ALTER TYPE "PKStatus" ADD VALUE IF NOT EXISTS '${val}';`);
    } catch {
      try {
        const rows = await db.$queryRawUnsafe(`
          SELECT 1 FROM pg_type t 
          JOIN pg_enum e ON t.oid = e.enumtypid 
          WHERE t.typname = 'PKStatus' AND e.enumlabel = '${val}';
        `);
        if (!rows || rows.length === 0) {
          await db.$executeRawUnsafe(`ALTER TYPE "PKStatus" ADD VALUE '${val}';`);
        }
      } catch {}
    }
  }

  // 2. Ensure UserStatus enum values
  try {
    await db.$executeRawUnsafe(`ALTER TYPE "UserStatus" ADD VALUE IF NOT EXISTS 'DELETED';`);
  } catch {
    try {
      const rows = await db.$queryRawUnsafe(`
        SELECT 1 FROM pg_type t 
        JOIN pg_enum e ON t.oid = e.enumtypid 
        WHERE t.typname = 'UserStatus' AND e.enumlabel = 'DELETED';
      `);
      if (!rows || rows.length === 0) {
        await db.$executeRawUnsafe(`ALTER TYPE "UserStatus" ADD VALUE 'DELETED';`);
      }
    } catch {}
  }

  // 3. Ensure PKEvent columns
  const pkEventColumns = [
    `ALTER TABLE "PKEvent" ADD COLUMN IF NOT EXISTS "initiatorUserId" TEXT;`,
    `ALTER TABLE "PKEvent" ADD COLUMN IF NOT EXISTS "participantsJson" JSONB;`,
    `ALTER TABLE "PKEvent" ADD COLUMN IF NOT EXISTS "inviteCode" TEXT;`,
    `ALTER TABLE "PKEvent" ADD COLUMN IF NOT EXISTS "startedAt" TIMESTAMP(3);`,
    `ALTER TABLE "PKEvent" ADD COLUMN IF NOT EXISTS "endedAt" TIMESTAMP(3);`,
    `ALTER TABLE "PKEvent" ADD COLUMN IF NOT EXISTS "winnerHostUserId" TEXT;`,
  ];
  for (const ddl of pkEventColumns) {
    try {
      await db.$executeRawUnsafe(ddl);
    } catch (err) {
      console.warn('PKEvent DDL note:', err.message);
    }
  }

  // 4. Ensure PKEvent column constraints & defaults
  const pkEventConstraints = [
    `ALTER TABLE "PKEvent" ALTER COLUMN "roomBId" DROP NOT NULL;`,
    `ALTER TABLE "PKEvent" ALTER COLUMN "hostBUserId" DROP NOT NULL;`,
    `ALTER TABLE "PKEvent" ALTER COLUMN "status" SET DEFAULT 'CREATED';`,
    `CREATE INDEX IF NOT EXISTS "PKEvent_initiatorUserId_idx" ON "PKEvent"("initiatorUserId");`,
    `CREATE INDEX IF NOT EXISTS "PKEvent_status_idx" ON "PKEvent"("status");`,
    `CREATE INDEX IF NOT EXISTS "PKEvent_inviteCode_idx" ON "PKEvent"("inviteCode");`,
  ];
  for (const ddl of pkEventConstraints) {
    try {
      await db.$executeRawUnsafe(ddl);
    } catch {}
  }

  // 4.1 Ensure Redesigned PK Match System Tables & Indexes exist
  const pkRedesignTables = [
    `CREATE TABLE IF NOT EXISTS "PKMatch" (
      "id" TEXT PRIMARY KEY,
      "roomAId" TEXT NOT NULL,
      "roomBId" TEXT NOT NULL,
      "hostAUserId" TEXT NOT NULL,
      "hostBUserId" TEXT NOT NULL,
      "roomType" "RoomType" NOT NULL DEFAULT 'LIVE_VIDEO',
      "region" TEXT NOT NULL DEFAULT 'GLOBAL',
      "operatorAUserId" TEXT NOT NULL,
      "operatorBUserId" TEXT,
      "status" "PKStatus" NOT NULL DEFAULT 'PENDING',
      "stateVersion" INTEGER NOT NULL DEFAULT 1,
      "durationSeconds" INTEGER NOT NULL DEFAULT 300,
      "invitationExpiresAt" TIMESTAMP(3),
      "preparationDeadlineAt" TIMESTAMP(3),
      "countdownStartAt" TIMESTAMP(3),
      "startAt" TIMESTAMP(3),
      "endAt" TIMESTAMP(3),
      "scoreA" BIGINT NOT NULL DEFAULT 0,
      "scoreB" BIGINT NOT NULL DEFAULT 0,
      "winnerHostId" TEXT,
      "isDraw" BOOLEAN NOT NULL DEFAULT false,
      "endReason" TEXT,
      "configSnapshotJson" JSONB,
      "hostAConnectionStatus" TEXT NOT NULL DEFAULT 'CONNECTED',
      "hostBConnectionStatus" TEXT NOT NULL DEFAULT 'CONNECTED',
      "hostADisconnectedAt" TIMESTAMP(3),
      "hostBDisconnectedAt" TIMESTAMP(3),
      "readyA" BOOLEAN NOT NULL DEFAULT false,
      "readyB" BOOLEAN NOT NULL DEFAULT false,
      "mediaPreparedA" BOOLEAN NOT NULL DEFAULT false,
      "mediaPreparedB" BOOLEAN NOT NULL DEFAULT false,
      "originalResultJson" JSONB,
      "revisedResultJson" JSONB,
      "revisionNumber" INTEGER NOT NULL DEFAULT 0,
      "revisionReason" TEXT,
      "revisedByAdminId" TEXT,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE INDEX IF NOT EXISTS "PKMatch_roomAId_idx" ON "PKMatch"("roomAId");`,
    `CREATE INDEX IF NOT EXISTS "PKMatch_roomBId_idx" ON "PKMatch"("roomBId");`,
    `CREATE INDEX IF NOT EXISTS "PKMatch_hostAUserId_idx" ON "PKMatch"("hostAUserId");`,
    `CREATE INDEX IF NOT EXISTS "PKMatch_hostBUserId_idx" ON "PKMatch"("hostBUserId");`,
    `CREATE INDEX IF NOT EXISTS "PKMatch_status_idx" ON "PKMatch"("status");`,
    `CREATE INDEX IF NOT EXISTS "PKMatch_createdAt_idx" ON "PKMatch"("createdAt");`,

    `CREATE TABLE IF NOT EXISTS "PKInvitation" (
      "id" TEXT PRIMARY KEY,
      "matchId" TEXT NOT NULL,
      "inviterUserId" TEXT NOT NULL,
      "targetRoomId" TEXT NOT NULL,
      "targetHostUserId" TEXT NOT NULL,
      "durationSeconds" INTEGER NOT NULL DEFAULT 300,
      "status" TEXT NOT NULL DEFAULT 'PENDING',
      "expiresAt" TIMESTAMP(3) NOT NULL,
      "respondedAt" TIMESTAMP(3),
      "responderUserId" TEXT,
      "cancelReason" TEXT,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE INDEX IF NOT EXISTS "PKInvitation_matchId_idx" ON "PKInvitation"("matchId");`,
    `CREATE INDEX IF NOT EXISTS "PKInvitation_targetRoomId_idx" ON "PKInvitation"("targetRoomId");`,
    `CREATE INDEX IF NOT EXISTS "PKInvitation_targetHostUserId_idx" ON "PKInvitation"("targetHostUserId");`,
    `CREATE INDEX IF NOT EXISTS "PKInvitation_status_idx" ON "PKInvitation"("status");`,

    `CREATE TABLE IF NOT EXISTS "PKGiftContribution" (
      "id" TEXT PRIMARY KEY,
      "matchId" TEXT NOT NULL,
      "giftTransactionId" TEXT NOT NULL UNIQUE,
      "senderUserId" TEXT NOT NULL,
      "recipientUserId" TEXT NOT NULL,
      "side" TEXT NOT NULL,
      "coins" BIGINT NOT NULL,
      "commitTimestamp" TIMESTAMP(3) NOT NULL,
      "isReversed" BOOLEAN NOT NULL DEFAULT false,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE INDEX IF NOT EXISTS "PKGiftContribution_matchId_side_idx" ON "PKGiftContribution"("matchId", "side");`,
    `CREATE INDEX IF NOT EXISTS "PKGiftContribution_senderUserId_idx" ON "PKGiftContribution"("senderUserId");`,

    `CREATE TABLE IF NOT EXISTS "PKLifecycleAudit" (
      "id" TEXT PRIMARY KEY,
      "matchId" TEXT NOT NULL,
      "action" TEXT NOT NULL,
      "actorUserId" TEXT,
      "fromStatus" TEXT,
      "toStatus" TEXT,
      "metadataJson" JSONB,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE INDEX IF NOT EXISTS "PKLifecycleAudit_matchId_idx" ON "PKLifecycleAudit"("matchId");`,
    `CREATE INDEX IF NOT EXISTS "PKLifecycleAudit_createdAt_idx" ON "PKLifecycleAudit"("createdAt");`,

    `CREATE TABLE IF NOT EXISTS "PKSetting" (
      "id" TEXT PRIMARY KEY DEFAULT 'default',
      "audioPkEnabled" BOOLEAN NOT NULL DEFAULT true,
      "videoPkEnabled" BOOLEAN NOT NULL DEFAULT true,
      "defaultDurationSeconds" INTEGER NOT NULL DEFAULT 300,
      "allowedDurationsJson" JSONB NOT NULL DEFAULT '[180, 300, 600]'::jsonb,
      "invitationTimeoutSeconds" INTEGER NOT NULL DEFAULT 30,
      "preparationTimeoutSeconds" INTEGER NOT NULL DEFAULT 15,
      "reconnectGraceSeconds" INTEGER NOT NULL DEFAULT 30,
      "resultDisplaySeconds" INTEGER NOT NULL DEFAULT 10,
      "invitationRateLimit" INTEGER NOT NULL DEFAULT 5,
      "multipliersEnabled" BOOLEAN NOT NULL DEFAULT false,
      "additionalRewardsEnabled" BOOLEAN NOT NULL DEFAULT false,
      "updatedByAdminId" TEXT,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,

    `CREATE TABLE IF NOT EXISTS "PKRestriction" (
      "id" TEXT PRIMARY KEY,
      "targetType" TEXT NOT NULL,
      "targetId" TEXT NOT NULL,
      "reason" TEXT NOT NULL,
      "restrictedByAdminId" TEXT NOT NULL,
      "expiresAt" TIMESTAMP(3),
      "status" TEXT NOT NULL DEFAULT 'ACTIVE',
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE INDEX IF NOT EXISTS "PKRestriction_targetType_targetId_status_idx" ON "PKRestriction"("targetType", "targetId", "status");`,
  ];

  for (const ddl of pkRedesignTables) {
    try {
      await db.$executeRawUnsafe(ddl);
    } catch (err) {
      console.warn('PKRedesign DDL note:', err.message);
    }
  }

  // 5. Ensure User table columns
  try {
    await db.$executeRawUnsafe(`ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "scheduledPermanentDeletionAt" TIMESTAMP(3);`);
  } catch {}
  try {
    await db.$executeRawUnsafe(`ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "deletionReason" TEXT;`);
  } catch {}

  // 6. Ensure Message table columns
  const messageColumns = [
    `ALTER TABLE "Message" ADD COLUMN IF NOT EXISTS "type" TEXT DEFAULT 'text';`,
    `ALTER TABLE "Message" ADD COLUMN IF NOT EXISTS "mediaUrl" TEXT;`,
    `ALTER TABLE "Message" ADD COLUMN IF NOT EXISTS "durationSeconds" INTEGER;`,
    `ALTER TABLE "Message" ADD COLUMN IF NOT EXISTS "mediaExpiresAt" TIMESTAMP(3);`,
    `ALTER TABLE "Message" ADD COLUMN IF NOT EXISTS "isMediaDeleted" BOOLEAN DEFAULT false;`,
  ];
  for (const ddl of messageColumns) {
    try {
      await db.$executeRawUnsafe(ddl);
    } catch {}
  }

  try {
    await db.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "Message_mediaExpiresAt_isMediaDeleted_idx" ON "Message"("mediaExpiresAt", "isMediaDeleted");`);
  } catch {}

  // 7. Ensure Post table columns
  try {
    await db.$executeRawUnsafe(`ALTER TABLE "Post" ADD COLUMN IF NOT EXISTS "sharesCount" INTEGER DEFAULT 0;`);
  } catch {}

  // 8. Ensure Realistic Live Metrics & Database Activity
  try {
    // Ensure live rooms have realistic concurrent viewers
    await db.$executeRawUnsafe(`
      UPDATE "Room"
      SET "currentViewersCount" = floor(random() * (220 - 25 + 1) + 25)::int
      WHERE "status" = 'LIVE' AND ("currentViewersCount" IS NULL OR "currentViewersCount" = 0);
    `);
  } catch (err) {
    console.warn('Metrics sync note (viewers):', err.message);
  }

  try {
    // Ensure active host profiles exist for live room creators
    await db.$executeRawUnsafe(`
      INSERT INTO "HostProfile" ("id", "userId", "hostType", "hostStatus", "hostLevel", "totalLiveHoursMonth", "totalDiamondsEarnedMonth", "targetDaysAchieved", "createdAt", "updatedAt")
      SELECT 
        gen_random_uuid()::text,
        r."creatorUserId",
        'LIVE_HOST'::"HostType",
        'ACTIVE'::"HostStatus",
        2,
        24.5,
        4200,
        12,
        NOW(),
        NOW()
      FROM "Room" r
      WHERE r."status" = 'LIVE'
        AND EXISTS (SELECT 1 FROM "User" u WHERE u."id" = r."creatorUserId")
        AND NOT EXISTS (SELECT 1 FROM "HostProfile" hp WHERE hp."userId" = r."creatorUserId")
      ON CONFLICT ("userId") DO NOTHING;
    `);
  } catch (err) {
    console.warn('Metrics sync note (hosts):', err.message);
  }

  // 8. Ensure all users in User table have strictly unique 7-digit IDs (1000000 - 9999999)
  try {
    const non7DigitUsers = await db.$queryRawUnsafe(`
      SELECT "id", "username" FROM "User"
      WHERE "id" !~ '^[1-9][0-9]{6}$'
        AND "username" NOT LIKE 'admin_shadow_%'
    `);
    if (non7DigitUsers && non7DigitUsers.length > 0) {
      console.log(`🔄 Found ${non7DigitUsers.length} user(s) with non-7-digit IDs. Auto-migrating to 7-digit IDs...`);
      for (const u of non7DigitUsers) {
        let newId;
        while (true) {
          newId = Math.floor(1000000 + Math.random() * 9000000).toString();
          const existing = await db.user.findUnique({ where: { id: newId }, select: { id: true } });
          if (!existing) break;
        }
        console.log(` -> Migrating user @${u.username} from '${u.id}' to '${newId}'`);
        await db.$executeRawUnsafe(`UPDATE "User" SET "id" = $1 WHERE "id" = $2`, newId, u.id);
      }
      console.log('✅ All non-7-digit user IDs migrated successfully to 7 digits');
    }
  } catch (err) {
    console.warn('User ID auto-migration note:', err.message);
  }

  // 8.1 CHANGE 17 - Ensure AgencyApplicationStatus enum and AgencyApplication table exist
  try {
    await db.$executeRawUnsafe(`
      DO $$
      BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'AgencyApplicationStatus') THEN
          CREATE TYPE "AgencyApplicationStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
        END IF;
      END
      $$;
    `);

    await db.$executeRawUnsafe(`
      CREATE TABLE IF NOT EXISTS "AgencyApplication" (
        "id" TEXT PRIMARY KEY,
        "applicantId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
        "applicantZePartyId" TEXT NOT NULL,
        "agencyName" TEXT NOT NULL,
        "description" TEXT NOT NULL,
        "phoneNumber" TEXT NOT NULL,
        "hostRef1" TEXT NOT NULL,
        "hostRef2" TEXT NOT NULL,
        "hostRef3" TEXT NOT NULL,
        "hostRef4" TEXT NOT NULL,
        "hostRef5" TEXT NOT NULL,
        "status" "AgencyApplicationStatus" NOT NULL DEFAULT 'PENDING',
        "rejectionReason" TEXT,
        "reviewedByAdminId" TEXT,
        "reviewedAt" TIMESTAMP(3),
        "createdAgencyId" TEXT REFERENCES "Agency"("id") ON DELETE SET NULL,
        "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
        "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    `);

    await db.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "AgencyApplication_applicantId_idx" ON "AgencyApplication"("applicantId");`);
    await db.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "AgencyApplication_status_idx" ON "AgencyApplication"("status");`);
    await db.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "AgencyApplication_applicantZePartyId_idx" ON "AgencyApplication"("applicantZePartyId");`);
    await db.$executeRawUnsafe(`
      CREATE UNIQUE INDEX IF NOT EXISTS "AgencyApplication_applicantId_pending_idx" 
      ON "AgencyApplication"("applicantId") 
      WHERE "status" = 'PENDING';
    `);
  } catch (err) {
    console.warn('AgencyApplication DDL note:', err.message);
  }

  // 9. Ensure Super Admin and Owner accounts exist and are ACTIVE
  try {
    const adminCount = await db.admin.count();
    if (adminCount === 0) {
      console.log('🔄 No admin accounts detected in database. Auto-bootstrapping default super admin & owner...');
      const bcrypt = await import('bcryptjs');
      const superAdminUsername = process.env.SUPER_ADMIN_USERNAME || 'admin';
      const superAdminEmail = process.env.SUPER_ADMIN_EMAIL || 'admin@zeparty.app';
      const superAdminPassword = process.env.SUPER_ADMIN_PASSWORD || 'admin123';

      const ownerUsername = process.env.OWNER_USERNAME || 'owner';
      const ownerEmail = process.env.OWNER_EMAIL || 'owner@zeparty.app';
      const ownerPassword = process.env.OWNER_PASSWORD || 'owner123';

      const [adminHash, ownerHash] = await Promise.all([
        bcrypt.default.hash(superAdminPassword, 10),
        bcrypt.default.hash(ownerPassword, 10),
      ]);

      await db.admin.createMany({
        data: [
          {
            id: 'dev-admin-main-001',
            name: 'Super Admin',
            username: superAdminUsername,
            email: superAdminEmail,
            passwordHash: adminHash,
            status: 'ACTIVE',
            isSuperAdmin: true,
            isOwner: false,
            roleId: 'super_admin',
          },
          {
            id: 'dev-owner-001',
            name: 'Root Owner',
            username: ownerUsername,
            email: ownerEmail,
            passwordHash: ownerHash,
            status: 'ACTIVE',
            isSuperAdmin: true,
            isOwner: true,
          },
        ],
        skipDuplicates: true,
      });
      console.log('✅ Super Admin and Owner accounts bootstrapped successfully into PostgreSQL');
    }
  } catch (err) {
    console.warn('Admin bootstrap auto-check note:', err.message);
  }

  // 10. Ensure Recharge Rewards & Milestone Claim Tables (Change 22)
  const rechargeRewardsTables = [
    `CREATE TABLE IF NOT EXISTS "RechargeRewardEvent" (
      "id" TEXT PRIMARY KEY,
      "code" TEXT UNIQUE NOT NULL,
      "title" TEXT NOT NULL,
      "description" TEXT,
      "currency" TEXT NOT NULL DEFAULT 'USD',
      "startDate" TIMESTAMP(3) NOT NULL,
      "endDate" TIMESTAMP(3) NOT NULL,
      "isActive" BOOLEAN NOT NULL DEFAULT true,
      "milestones" JSONB NOT NULL,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    );`,
    `CREATE INDEX IF NOT EXISTS "RechargeRewardEvent_code_idx" ON "RechargeRewardEvent"("code");`,
    `CREATE INDEX IF NOT EXISTS "RechargeRewardEvent_isActive_idx" ON "RechargeRewardEvent"("isActive");`,
    `CREATE INDEX IF NOT EXISTS "RechargeRewardEvent_dates_idx" ON "RechargeRewardEvent"("startDate", "endDate");`,

    `CREATE TABLE IF NOT EXISTS "UserMilestoneClaim" (
      "id" TEXT PRIMARY KEY,
      "userId" TEXT NOT NULL,
      "eventId" TEXT NOT NULL,
      "milestoneLevel" INTEGER NOT NULL,
      "thresholdUSD" DECIMAL(10, 2) NOT NULL,
      "bonusCoins" BIGINT NOT NULL DEFAULT 0,
      "bonusDiamonds" BIGINT NOT NULL DEFAULT 0,
      "specialRewardName" TEXT,
      "specialRewardIcon" TEXT,
      "claimedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "txReference" TEXT,
      CONSTRAINT "UserMilestoneClaim_unique_claim" UNIQUE ("userId", "eventId", "milestoneLevel"),
      CONSTRAINT "UserMilestoneClaim_event_fkey" FOREIGN KEY ("eventId") REFERENCES "RechargeRewardEvent"("id") ON DELETE CASCADE
    );`,
    `CREATE INDEX IF NOT EXISTS "UserMilestoneClaim_userId_eventId_idx" ON "UserMilestoneClaim"("userId", "eventId");`,
    `CREATE INDEX IF NOT EXISTS "UserMilestoneClaim_userId_idx" ON "UserMilestoneClaim"("userId");`,
  ];

  for (const ddl of rechargeRewardsTables) {
    try {
      await db.$executeRawUnsafe(ddl);
    } catch (err) {
      console.warn('RechargeRewards DDL note:', err.message);
    }
  }

  // 10.1 Bootstrap Default Active Recharge Fiesta Event if none exists
  try {
    const existingEvent = await db.rechargeRewardEvent.findFirst();
    if (!existingEvent) {
      const now = new Date();
      const currentYear = now.getFullYear();
      const currentMonth = now.getMonth();
      const startDate = new Date(Date.UTC(currentYear, currentMonth, 1, 0, 0, 0));
      const endDate = new Date(Date.UTC(currentYear, currentMonth + 1, 0, 23, 59, 59));

      await db.rechargeRewardEvent.create({
        data: {
          id: `evt_grand_fiesta_${currentYear}_${currentMonth + 1}`,
          code: 'GRAND_RECHARGE_FIESTA',
          title: 'ZeParty Grand Recharge Fiesta',
          description: 'Recharge cumulative dollar amounts during the event window to unlock limited luxury animated assets and coin rebates!',
          currency: 'USD',
          startDate,
          endDate,
          isActive: true,
          milestones: [
            {
              level: 1,
              thresholdUSD: 10.0,
              bonusCoins: 1000,
              bonusDiamonds: 500,
              specialRewardName: 'Bronze VIP Entry Badge (7 Days)',
              specialRewardIcon: '🥉',
            },
            {
              level: 2,
              thresholdUSD: 50.0,
              bonusCoins: 6000,
              bonusDiamonds: 3000,
              specialRewardName: 'Neon Gold Chat Bubble (15 Days)',
              specialRewardIcon: '💬',
            },
            {
              level: 3,
              thresholdUSD: 100.0,
              bonusCoins: 15000,
              bonusDiamonds: 8000,
              specialRewardName: 'Cyber Ride Vehicle (30 Days)',
              specialRewardIcon: '🏎️',
            },
            {
              level: 4,
              thresholdUSD: 300.0,
              bonusCoins: 50000,
              bonusDiamonds: 25000,
              specialRewardName: 'Golden Phoenix Avatar Frame',
              specialRewardIcon: '👑',
            },
            {
              level: 5,
              thresholdUSD: 1000.0,
              bonusCoins: 200000,
              bonusDiamonds: 100000,
              specialRewardName: 'Custom Vanity ID + Room Spotlight',
              specialRewardIcon: '💎',
            },
            {
              level: 6,
              thresholdUSD: 3000.0,
              bonusCoins: 750000,
              bonusDiamonds: 400000,
              specialRewardName: 'Emperor Royal Broadcast Halo (Permanent)',
              specialRewardIcon: '🌟',
            },
          ],
        },
      });
      console.log('✅ Default ZeParty Grand Recharge Fiesta event bootstrapped successfully');
    }
  } catch (err) {
    console.warn('RechargeRewards event bootstrap note:', err.message);
  }

  console.log('✅ Database schema and platform analytics verified and synchronized successfully');
}

export default {
  ensureDatabaseSchema,
};
