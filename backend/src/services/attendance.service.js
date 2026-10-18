import crypto from 'crypto';
import prisma from '../config/database.js';

export function getUtcDateString(d = new Date()) {
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Authoritative Host Streaming Attendance Service
 * Tracks genuine live video broadcast heartbeats, enforces 60-minute valid day rule,
 * deduplicates rapid heartbeats, excludes dead gaps, and splits across UTC midnight.
 */

export async function recordBroadcastHeartbeat({ roomId, hostUserId }, db = prisma) {
  if (!roomId || !hostUserId) {
    const error = new Error('roomId and hostUserId are required');
    error.statusCode = 400;
    error.code = 'INVALID_PARAMETERS';
    throw error;
  }

  // 1. Verify Room authenticity & status
  const room = await db.room.findUnique({
    where: { id: roomId },
  });

  if (!room) {
    const error = new Error('Live room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  if (room.status !== 'LIVE') {
    const error = new Error('Cannot track attendance on inactive or ended room');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  // Verify room creator identity
  if (room.creatorUserId !== hostUserId) {
    const error = new Error('Only the genuine room host can record broadcast streaming attendance');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Verify Room Type: genuine live video broadcast only
  const isLiveVideo = (room.roomType === 'LIVE_VIDEO' || room.roomType === 'LIVE');
  if (!isLiveVideo) {
    return {
      success: false,
      isStreamingAttended: false,
      reason: 'ATTENDANCE_REQUIRES_LIVE_VIDEO',
      message: 'Streaming attendance tracking is authoritative for genuine live video broadcasts only',
      dailyLiveMinutes: 0,
      isTodayValid: false,
    };
  }

  const now = new Date();
  const nowDateStr = getUtcDateString(now);

  // 2. Locate or create active broadcast session
  let session = await db.hostBroadcastSession.findFirst({
    where: {
      roomId,
      hostUserId,
      status: 'ACTIVE',
    },
  });

  if (!session) {
    session = await db.hostBroadcastSession.create({
      data: {
        id: `hbs_${crypto.randomUUID().replace(/-/g, '')}`,
        hostUserId,
        roomId,
        roomType: room.roomType,
        startedAt: now,
        lastHeartbeatAt: now,
        verifiedMinutes: 0.0,
        status: 'ACTIVE',
      },
    });

    const summary = await getHostAttendanceSummary(hostUserId, db);
    return {
      success: true,
      sessionId: session.id,
      roomId,
      hostUserId,
      heartbeatStatus: 'INITIALIZED',
      creditedMinutes: 0,
      dailyLiveMinutes: summary.dailyLiveMinutes,
      isTodayValid: summary.isTodayValid,
      completedValidDays: summary.completedValidDays,
      requiredValidDays: summary.requiredValidDays,
      requiredLiveHostDailyMinutes: 60,
      attendanceDate: nowDateStr,
      lastHeartbeatAt: now.toISOString(),
    };
  }

  // 3. Time calculation & Deduplication
  const lastHb = new Date(session.lastHeartbeatAt);
  const diffMs = now.getTime() - lastHb.getTime();

  // Deduplicate if heartbeat arrives too quickly (less than 15 seconds)
  if (diffMs < 15000) {
    const summary = await getHostAttendanceSummary(hostUserId, db);
    return {
      success: true,
      sessionId: session.id,
      roomId,
      hostUserId,
      heartbeatStatus: 'DEDUPLICATED',
      creditedMinutes: 0,
      dailyLiveMinutes: summary.dailyLiveMinutes,
      isTodayValid: summary.isTodayValid,
      completedValidDays: summary.completedValidDays,
      requiredValidDays: summary.requiredValidDays,
      requiredLiveHostDailyMinutes: 60,
      attendanceDate: nowDateStr,
      lastHeartbeatAt: session.lastHeartbeatAt.toISOString(),
    };
  }

  // Bounded grace period:
  // If gap > 3 minutes (180,000 ms), the host was absent or disconnected.
  // Inactive gap is strictly excluded from attendance! Credit at most 1 minute for resumption.
  let creditedMinutes = 0;
  if (diffMs > 180000) {
    creditedMinutes = 1.0;
  } else {
    creditedMinutes = diffMs / 60000.0;
  }

  // 4. Midnight boundary handling
  const lastHbDateStr = getUtcDateString(lastHb);
  const distribution = [];

  if (lastHbDateStr === nowDateStr) {
    distribution.push({ date: nowDateStr, minutes: creditedMinutes });
  } else {
    // Crosses UTC midnight: split between previous date and today
    const midnightUtc = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
    const msBefore = Math.max(0, midnightUtc.getTime() - lastHb.getTime());
    const msAfter = Math.max(0, now.getTime() - midnightUtc.getTime());
    const totalMs = msBefore + msAfter;

    if (totalMs > 0) {
      const minsBefore = (msBefore / totalMs) * creditedMinutes;
      const minsAfter = (msAfter / totalMs) * creditedMinutes;
      distribution.push({ date: lastHbDateStr, minutes: minsBefore });
      distribution.push({ date: nowDateStr, minutes: minsAfter });
    } else {
      distribution.push({ date: nowDateStr, minutes: creditedMinutes });
    }
  }

  // 5. Atomic state update
  await db.$transaction(async (tx) => {
    for (const dist of distribution) {
      const existingDaily = await tx.hostDailyAttendance.findUnique({
        where: {
          hostUserId_attendanceDate: {
            hostUserId,
            attendanceDate: dist.date,
          },
        },
      });

      const previousMins = existingDaily?.verifiedMinutes || 0.0;
      const newMins = previousMins + dist.minutes;
      const wasValid = Boolean(existingDaily?.isValidDay);
      const nowValid = newMins >= 60.0;
      const newlyBecameValid = !wasValid && nowValid;

      await tx.hostDailyAttendance.upsert({
        where: {
          hostUserId_attendanceDate: {
            hostUserId,
            attendanceDate: dist.date,
          },
        },
        create: {
          id: `hda_${crypto.randomUUID().replace(/-/g, '')}`,
          hostUserId,
          attendanceDate: dist.date,
          verifiedMinutes: newMins,
          isValidDay: nowValid,
          markedValidAt: nowValid ? now : null,
          sessionCount: 1,
        },
        update: {
          verifiedMinutes: newMins,
          isValidDay: wasValid || nowValid,
          markedValidAt: newlyBecameValid ? now : existingDaily?.markedValidAt,
          updatedAt: now,
        },
      });

      if (newlyBecameValid) {
        // Increment targetDaysAchieved on HostProfile exactly once per calendar date
        await tx.hostProfile.updateMany({
          where: { userId: hostUserId },
          data: {
            targetDaysAchieved: { increment: 1 },
          },
        });
      }
    }

    // Update active session
    await tx.hostBroadcastSession.update({
      where: { id: session.id },
      data: {
        verifiedMinutes: { increment: creditedMinutes },
        lastHeartbeatAt: now,
        updatedAt: now,
      },
    });

    // Update host profile overall stats
    const todayRecord = await tx.hostDailyAttendance.findUnique({
      where: {
        hostUserId_attendanceDate: {
          hostUserId,
          attendanceDate: nowDateStr,
        },
      },
    });

    await tx.hostProfile.updateMany({
      where: { userId: hostUserId },
      data: {
        totalLiveHoursMonth: { increment: creditedMinutes / 60.0 },
        todayOnlineMinutes: todayRecord?.verifiedMinutes || 0.0,
      },
    });
  });

  const summary = await getHostAttendanceSummary(hostUserId, db);

  return {
    success: true,
    sessionId: session.id,
    roomId,
    hostUserId,
    heartbeatStatus: 'RECORDED',
    creditedMinutes: Number(creditedMinutes.toFixed(2)),
    dailyLiveMinutes: summary.dailyLiveMinutes,
    isTodayValid: summary.isTodayValid,
    completedValidDays: summary.completedValidDays,
    requiredValidDays: summary.requiredValidDays,
    requiredLiveHostDailyMinutes: 60,
    attendanceDate: nowDateStr,
    lastHeartbeatAt: now.toISOString(),
  };
}

export async function endBroadcastSession({ roomId, hostUserId }, db = prisma) {
  const whereClause = {
    roomId,
    status: 'ACTIVE',
  };
  if (hostUserId) {
    whereClause.hostUserId = hostUserId;
  }

  const activeSessions = await db.hostBroadcastSession.findMany({
    where: whereClause,
  });

  const now = new Date();
  for (const s of activeSessions) {
    await db.hostBroadcastSession.update({
      where: { id: s.id },
      data: {
        status: 'COMPLETED',
        endedAt: now,
        updatedAt: now,
      },
    });
  }

  return {
    success: true,
    endedCount: activeSessions.length,
  };
}

export async function getHostAttendanceSummary(hostUserId, db = prisma) {
  const nowDateStr = getUtcDateString(new Date());

  const [todayAttendance, hostProfile] = await Promise.all([
    db.hostDailyAttendance.findUnique({
      where: {
        hostUserId_attendanceDate: {
          hostUserId,
          attendanceDate: nowDateStr,
        },
      },
    }),
    db.hostProfile.findUnique({
      where: { userId: hostUserId },
    }),
  ]);

  const verifiedMinutes = todayAttendance?.verifiedMinutes ? Math.floor(todayAttendance.verifiedMinutes) : 0;
  const isTodayValid = Boolean(todayAttendance?.isValidDay);
  const completedValidDays = Number(hostProfile?.targetDaysAchieved || 0);

  return {
    dailyLiveMinutes: verifiedMinutes,
    verifiedMinutesToday: verifiedMinutes,
    streamingMinutes: verifiedMinutes,
    isTodayValid,
    completedValidDays,
    validDays: completedValidDays,
    targetDaysAchieved: completedValidDays,
    requiredValidDays: 10,
    requiredLiveHostDailyMinutes: 60,
    attendanceCycle: 'MONTHLY',
    attendanceTimezone: 'UTC',
    todayStatus: isTodayValid ? 'COMPLETED' : (verifiedMinutes > 0 ? 'IN_PROGRESS' : 'PENDING'),
  };
}

export function rejectSimulation() {
  const error = new Error('Client-side attendance simulation is permanently disabled. Attendance is authoritatively verified via real-time live video broadcast heartbeats.');
  error.statusCode = 400;
  error.code = 'SIMULATION_FORBIDDEN';
  throw error;
}

export default {
  getUtcDateString,
  recordBroadcastHeartbeat,
  endBroadcastSession,
  getHostAttendanceSummary,
  rejectSimulation,
};
