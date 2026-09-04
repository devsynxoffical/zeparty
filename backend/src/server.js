import app from './app.js';
import env from './config/env.js';
import prisma from './config/database.js';
import redisClient from './config/redis.js';
import {
  runStartupRecoverySweep,
  startAutoRestoreScheduler,
  stopAutoRestoreScheduler,
} from './jobs/autoRestore.job.js';

let server;

async function startServer() {
  try {
    console.log('🔄 Initializing ZeParty Backend Foundation...');

    // 1. Initialize Database connection
    console.log('🔄 Connecting to PostgreSQL database via Prisma...');
    await prisma.$connect();
    console.log('✅ Database connected successfully');

    // 2. Initialize Redis connection
    console.log('🔄 Connecting to Redis...');
    await redisClient.connect();

    // 3. Run Phase 7 Auto-Restore Startup Recovery Sweep
    await runStartupRecoverySweep();

    // 4. Start Phase 7 Recurring Auto-Restore Scheduler
    startAutoRestoreScheduler({ intervalMs: 60000 });

    // 5. Start HTTP Server
    server = app.listen(env.PORT, () => {
      console.log(`🚀 Server listening on port ${env.PORT} in ${env.NODE_ENV} mode`);
      console.log(`🔗 Health check available at http://localhost:${env.PORT}/api/health`);
    });

  } catch (error) {
    console.error('❌ Failed to start ZeParty server:', error);
    process.exit(1);
  }
}

// Graceful shutdown handler
async function gracefulShutdown(signal) {
  console.log(`\n🛑 Received ${signal}. Starting graceful shutdown...`);

  // Stop background schedulers
  stopAutoRestoreScheduler();

  if (server) {
    console.log('🔄 Closing HTTP server...');
    server.close(() => {
      console.log('✅ HTTP server closed');
    });
  }

  try {
    console.log('🔄 Closing database connections...');
    await prisma.$disconnect();
    console.log('✅ Database connections disconnected');
  } catch (err) {
    console.error('❌ Error during database disconnect:', err);
  }

  try {
    if (redisClient.isOpen) {
      console.log('🔄 Closing Redis connection...');
      await redisClient.quit();
      console.log('✅ Redis connection closed');
    }
  } catch (err) {
    console.error('❌ Error during Redis disconnect:', err);
  }

  console.log('👋 Clean exit completed. Goodbye!');
  process.exit(0);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

startServer();
