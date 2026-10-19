import prisma from '../config/database.js';

/**
 * Stable Machine-Readable Error Codes for Hosting Mutual Exclusion
 */
export const HOSTING_ERROR_CODES = {
  HOSTING_ROLE_CONFLICT: 'HOSTING_ROLE_CONFLICT',
  HOSTING_REQUEST_ALREADY_PENDING: 'HOSTING_REQUEST_ALREADY_PENDING',
  HOSTING_ROLE_ALREADY_ACTIVE: 'HOSTING_ROLE_ALREADY_ACTIVE',
  HOSTING_REQUEST_CONFLICT_PENDING: 'HOSTING_REQUEST_CONFLICT_PENDING',
  HOSTING_ELIGIBILITY_REVIEW_REQUIRED: 'HOSTING_ELIGIBILITY_REVIEW_REQUIRED',
};

/**
 * Client-Approved User Messages
 */
export const HOSTING_ERROR_MESSAGES = {
  AUDIO_HOST_ATTEMPTING_LIVE:
    'You are already an Audio Host. You cannot apply for or join Live Hosting while your Audio Host membership is active.',
  AGENCY_OWNER_ATTEMPTING_LIVE:
    'You are already an Agency Owner. You cannot apply for or join Live Hosting while you own an agency.',
  LIVE_HOST_ATTEMPTING_AUDIO_OR_AGENCY:
    'You are already a Live Host. You cannot join Audio Hosting or become an Agency Owner while your Live Host membership is active.',
  CONFLICTING_PENDING_REQUEST:
    'You already have a pending hosting or agency request. Resolve or cancel that request before applying to the other hosting system.',
  DUPLICATE_PENDING_REQUEST:
    'You already have a pending verification request under administrative review.',
  DUPLICATE_ACTIVE_ROLE:
    'You are already active in this hosting role.',
  HISTORICAL_CONFLICT_REVIEW_REQUIRED:
    'Your account has conflicting hosting memberships that require administrative review. Please contact support.',
};

/**
 * Standard Hosting Eligibility Error class
 */
export class HostingEligibilityError extends Error {
  constructor({ code, message, statusCode = 409, conflictingRole, requestedRole, details = {} }) {
    super(message);
    this.name = 'HostingEligibilityError';
    this.code = code;
    this.statusCode = statusCode;
    this.status = statusCode;
    this.conflictingRole = conflictingRole || null;
    this.requestedRole = requestedRole || null;
    this.details = {
      code,
      conflictingRole,
      requestedRole,
      ...details,
    };
  }
}

/**
 * Evaluates the full persisted hosting & agency state for a given user.
 * Supports row locking if executed within an interactive transaction `tx`.
 *
 * @param {string} userId
 * @param {Object} db - Prisma Client or Transaction instance
 * @param {Object} options - { lockRow: boolean }
 */
export async function getPersistedHostingState(userId, db = prisma, { lockRow = false } = {}) {
  if (!userId) {
    throw new Error('User ID is required to evaluate hosting eligibility');
  }

  // 1. Transactional Row-Level Lock for concurrency protection
  if (lockRow && typeof db.$queryRaw === 'function') {
    try {
      await db.$queryRaw`SELECT id FROM "User" WHERE id = ${userId}::text FOR UPDATE`;
    } catch (err) {
      // Non-fatal if DB provider / mocking doesn't support SELECT FOR UPDATE
      if (process.env.NODE_ENV === 'test') {
        // Fallback for tests
      }
    }
  }

  // 2. Fetch User along with persisted relations
  const user = await db.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      username: true,
      userType: true,
      status: true,
      hostProfile: {
        select: {
          id: true,
          hostType: true,
          hostStatus: true,
          agencyId: true,
        },
      },
      agencyMemberships: {
        select: {
          id: true,
          agencyId: true,
          agency: {
            select: {
              id: true,
              agencyName: true,
              status: true,
            },
          },
        },
      },
      ownedAgencies: {
        select: {
          id: true,
          agencyName: true,
          agencyCode: true,
          status: true,
        },
      },
      hostApplications: {
        where: {
          status: { in: ['APPLIED', 'ACTIVE', 'SUSPENDED'] },
        },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          hostType: true,
          status: true,
          createdAt: true,
        },
      },
      agencyApplications: {
        where: {
          status: { in: ['PENDING', 'APPROVED'] },
        },
        orderBy: { createdAt: 'desc' },
        take: 5,
        select: {
          id: true,
          agencyName: true,
          status: true,
          createdAt: true,
        },
      },
    },
  });

  if (!user) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  // 3. Classify Roles based on persisted state
  // LIVE HOST: HostProfile is ACTIVE/SUSPENDED with hostType LIVE_HOST or BOTH (and not bound to an agency)
  const hostProf = user.hostProfile;
  const isLiveHostType = hostProf && (hostProf.hostType === 'LIVE_HOST' || hostProf.hostType === 'BOTH');

  const isActiveLiveHost =
    isLiveHostType && hostProf.hostStatus === 'ACTIVE';

  const isSuspendedLiveHost =
    isLiveHostType && hostProf.hostStatus === 'SUSPENDED';

  // Pending Live Host application
  const pendingLiveHostApp = user.hostApplications.find(
    (app) => app.status === 'APPLIED' && (app.hostType === 'LIVE_HOST' || app.hostType === 'BOTH')
  );

  // AUDIO HOST: Active/Suspended agency membership or audio-only host profile
  const activeAgencyMembership = user.agencyMemberships.find(
    (m) => m.agency?.status === 'ACTIVE'
  );
  const suspendedAgencyMembership = user.agencyMemberships.find(
    (m) => m.agency?.status === 'SUSPENDED'
  );

  const isActiveAudioHost =
    Boolean(activeAgencyMembership) ||
    (hostProf && hostProf.hostStatus === 'ACTIVE' && (hostProf.hostType === 'AUDIO_HOST' || hostProf.agencyId != null));

  const isSuspendedAudioHost =
    Boolean(suspendedAgencyMembership) ||
    (hostProf && hostProf.hostStatus === 'SUSPENDED' && (hostProf.hostType === 'AUDIO_HOST' || hostProf.agencyId != null));

  // Pending Audio Host application
  const pendingAudioHostApp = user.hostApplications.find(
    (app) => app.status === 'APPLIED' && app.hostType === 'AUDIO_HOST'
  );

  // AGENCY OWNER: Active or suspended owned agency
  const activeOwnedAgency = user.ownedAgencies.find((a) => a.status === 'ACTIVE');
  const suspendedOwnedAgency = user.ownedAgencies.find((a) => a.status === 'SUSPENDED');

  const isActiveAgencyOwner = Boolean(activeOwnedAgency);
  const isSuspendedAgencyOwner = Boolean(suspendedOwnedAgency);

  // Pending Agency Application
  const pendingAgencyApp = user.agencyApplications.find(
    (app) => app.status === 'PENDING'
  );

  // Unresolved Requests summary
  const hasPendingLiveHostRequest = Boolean(pendingLiveHostApp);
  const hasPendingAudioHostRequest = Boolean(pendingAudioHostApp);
  const hasPendingAgencyOwnerRequest = Boolean(pendingAgencyApp);
  const hasPendingAudioOrAgencyRequest = hasPendingAudioHostRequest || hasPendingAgencyOwnerRequest;

  // Active / Suspended role summary
  const hasActiveOrSuspendedLive = isActiveLiveHost || isSuspendedLiveHost;
  const hasActiveOrSuspendedAudio = isActiveAudioHost || isSuspendedAudioHost;
  const hasActiveOrSuspendedAgencyOwner = isActiveAgencyOwner || isSuspendedAgencyOwner;
  const hasActiveOrSuspendedAudioOrAgency = hasActiveOrSuspendedAudio || hasActiveOrSuspendedAgencyOwner;

  // Historical Dual Enrollment Check (Account already has both live host and agency/audio active)
  const isHistoricalDualConflict = hasActiveOrSuspendedLive && hasActiveOrSuspendedAudioOrAgency;

  return {
    userId,
    username: user.username,
    userType: user.userType,
    userStatus: user.status,
    isActiveLiveHost,
    isSuspendedLiveHost,
    hasActiveOrSuspendedLive,
    isActiveAudioHost,
    isSuspendedAudioHost,
    hasActiveOrSuspendedAudio,
    isActiveAgencyOwner,
    isSuspendedAgencyOwner,
    hasActiveOrSuspendedAgencyOwner,
    hasActiveOrSuspendedAudioOrAgency,
    pendingLiveHostApp: pendingLiveHostApp || null,
    hasPendingLiveHostRequest,
    pendingAudioHostApp: pendingAudioHostApp || null,
    hasPendingAudioHostRequest,
    pendingAgencyApp: pendingAgencyApp || null,
    hasPendingAgencyOwnerRequest,
    hasPendingAudioOrAgencyRequest,
    isHistoricalDualConflict,
    rawUser: user,
  };
}

/**
 * Shared Validator: Evaluates and enforces hosting mutual exclusion.
 * Throws `HostingEligibilityError` if the requested operation is prohibited.
 *
 * @param {string} userId
 * @param {string} requestedAction - Action enum below
 * @param {Object} db - Prisma Client or Transaction instance
 * @param {Object} options - { lockRow: boolean, adminOverride: boolean }
 */
export async function validateHostingEligibility(
  userId,
  requestedAction,
  db = prisma,
  { lockRow = true } = {}
) {
  const state = await getPersistedHostingState(userId, db, { lockRow });

  // 1. Historical Data Dual-Conflict Check
  if (state.isHistoricalDualConflict) {
    throw new HostingEligibilityError({
      code: HOSTING_ERROR_CODES.HOSTING_ELIGIBILITY_REVIEW_REQUIRED,
      message: HOSTING_ERROR_MESSAGES.HISTORICAL_CONFLICT_REVIEW_REQUIRED,
      conflictingRole: 'DUAL_ENROLLMENT',
      requestedRole: requestedAction,
      details: {
        hasActiveLiveHost: state.isActiveLiveHost,
        hasActiveAudioHost: state.isActiveAudioHost,
        hasActiveAgencyOwner: state.isActiveAgencyOwner,
        reviewRequired: true,
      },
    });
  }

  switch (requestedAction) {
    // ─────────────────────────────────────────────────────────────
    // LIVE HOST ACTIONS
    // ─────────────────────────────────────────────────────────────
    case 'APPLY_LIVE_HOST':
    case 'BECOME_LIVE_HOST':
    case 'ACTIVATE_LIVE_HOST':
    case 'GRANT_LIVE_HOST': {
      // Rule 1: Active/Suspended Audio Host blocked from Live Host
      if (state.hasActiveOrSuspendedAudio) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT,
          message: HOSTING_ERROR_MESSAGES.AUDIO_HOST_ATTEMPTING_LIVE,
          conflictingRole: 'AUDIO_HOST',
          requestedRole: 'LIVE_HOST',
          details: { isSuspended: state.isSuspendedAudioHost },
        });
      }

      // Rule 2: Active/Suspended Agency Owner blocked from Live Host
      if (state.hasActiveOrSuspendedAgencyOwner) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT,
          message: HOSTING_ERROR_MESSAGES.AGENCY_OWNER_ATTEMPTING_LIVE,
          conflictingRole: 'AGENCY_OWNER',
          requestedRole: 'LIVE_HOST',
          details: { isSuspended: state.isSuspendedAgencyOwner },
        });
      }

      // Rule 3: Pending Audio Host or Agency Owner request blocks Live Host request
      if (state.hasPendingAudioOrAgencyRequest) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_REQUEST_CONFLICT_PENDING,
          message: HOSTING_ERROR_MESSAGES.CONFLICTING_PENDING_REQUEST,
          conflictingRole: state.hasPendingAgencyOwnerRequest ? 'PENDING_AGENCY_APPLICATION' : 'PENDING_AUDIO_HOST_REQUEST',
          requestedRole: 'LIVE_HOST',
        });
      }

      // Duplicate Check: Same role already active
      if (state.isActiveLiveHost) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_ALREADY_ACTIVE,
          message: HOSTING_ERROR_MESSAGES.DUPLICATE_ACTIVE_ROLE,
          conflictingRole: 'LIVE_HOST',
          requestedRole: 'LIVE_HOST',
        });
      }

      // Duplicate Check: Same role already pending (for application submissions)
      if (requestedAction === 'APPLY_LIVE_HOST' || requestedAction === 'BECOME_LIVE_HOST') {
        if (state.hasPendingLiveHostRequest) {
          throw new HostingEligibilityError({
            code: HOSTING_ERROR_CODES.HOSTING_REQUEST_ALREADY_PENDING,
            message: HOSTING_ERROR_MESSAGES.DUPLICATE_PENDING_REQUEST,
            conflictingRole: 'PENDING_LIVE_HOST_APPLICATION',
            requestedRole: 'LIVE_HOST',
          });
        }
      }

      break;
    }

    // ─────────────────────────────────────────────────────────────
    // AUDIO HOST ACTIONS (Join Agency / Accept Invitation / Grant)
    // ─────────────────────────────────────────────────────────────
    case 'JOIN_AUDIO_HOST':
    case 'ACCEPT_AUDIO_HOST_INVITE':
    case 'ACTIVATE_AUDIO_HOST':
    case 'GRANT_AUDIO_HOST': {
      // Rule 4: Active/Suspended Live Host blocked from joining Audio Host
      if (state.hasActiveOrSuspendedLive) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT,
          message: HOSTING_ERROR_MESSAGES.LIVE_HOST_ATTEMPTING_AUDIO_OR_AGENCY,
          conflictingRole: 'LIVE_HOST',
          requestedRole: 'AUDIO_HOST',
          details: { isSuspended: state.isSuspendedLiveHost },
        });
      }

      // Rule 5: Pending Live Host request blocks Audio Host enrollment
      if (state.hasPendingLiveHostRequest) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_REQUEST_CONFLICT_PENDING,
          message: HOSTING_ERROR_MESSAGES.CONFLICTING_PENDING_REQUEST,
          conflictingRole: 'PENDING_LIVE_HOST_APPLICATION',
          requestedRole: 'AUDIO_HOST',
        });
      }

      // Duplicate Check: Already active in agency
      if (state.isActiveAudioHost) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_ALREADY_ACTIVE,
          message: HOSTING_ERROR_MESSAGES.DUPLICATE_ACTIVE_ROLE,
          conflictingRole: 'AUDIO_HOST',
          requestedRole: 'AUDIO_HOST',
        });
      }

      break;
    }

    // ─────────────────────────────────────────────────────────────
    // AGENCY OWNER ACTIONS (Create Agency / Apply / Approve / Grant)
    // ─────────────────────────────────────────────────────────────
    case 'APPLY_AGENCY_OWNER':
    case 'APPROVE_AGENCY_OWNER':
    case 'GRANT_AGENCY_OWNER':
    case 'CREATE_AGENCY': {
      // Rule 6: Active/Suspended Live Host blocked from becoming Agency Owner
      if (state.hasActiveOrSuspendedLive) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT,
          message: HOSTING_ERROR_MESSAGES.LIVE_HOST_ATTEMPTING_AUDIO_OR_AGENCY,
          conflictingRole: 'LIVE_HOST',
          requestedRole: 'AGENCY_OWNER',
          details: { isSuspended: state.isSuspendedLiveHost },
        });
      }

      // Rule 7: Pending Live Host request blocks Agency Owner request
      if (state.hasPendingLiveHostRequest) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_REQUEST_CONFLICT_PENDING,
          message: HOSTING_ERROR_MESSAGES.CONFLICTING_PENDING_REQUEST,
          conflictingRole: 'PENDING_LIVE_HOST_APPLICATION',
          requestedRole: 'AGENCY_OWNER',
        });
      }

      // Duplicate Check: Already active Agency Owner
      if (state.isActiveAgencyOwner) {
        throw new HostingEligibilityError({
          code: HOSTING_ERROR_CODES.HOSTING_ROLE_ALREADY_ACTIVE,
          message: 'You already own an active agency.',
          conflictingRole: 'AGENCY_OWNER',
          requestedRole: 'AGENCY_OWNER',
        });
      }

      // Duplicate Check: Same role already pending (for application submissions)
      if (requestedAction === 'APPLY_AGENCY_OWNER') {
        if (state.hasPendingAgencyOwnerRequest) {
          throw new HostingEligibilityError({
            code: HOSTING_ERROR_CODES.HOSTING_REQUEST_ALREADY_PENDING,
            message: 'You already have a pending agency application under review.',
            conflictingRole: 'PENDING_AGENCY_APPLICATION',
            requestedRole: 'AGENCY_OWNER',
          });
        }
      }

      break;
    }

    default:
      break;
  }

  return {
    eligible: true,
    state,
  };
}

/**
 * Public/Mobile Eligibility Overview for UI refresh
 * Returns boolean capabilities and current role states so screens can adapt.
 */
export async function getHostingEligibilityOverview(userId, db = prisma) {
  const state = await getPersistedHostingState(userId, db, { lockRow: false });

  let canApplyLiveHost = true;
  let canJoinAudioHost = true;
  let canCreateAgency = true;
  let conflictMessage = null;
  let conflictCode = null;

  if (state.isHistoricalDualConflict) {
    canApplyLiveHost = false;
    canJoinAudioHost = false;
    canCreateAgency = false;
    conflictCode = HOSTING_ERROR_CODES.HOSTING_ELIGIBILITY_REVIEW_REQUIRED;
    conflictMessage = HOSTING_ERROR_MESSAGES.HISTORICAL_CONFLICT_REVIEW_REQUIRED;
  } else if (state.hasActiveOrSuspendedLive) {
    canJoinAudioHost = false;
    canCreateAgency = false;
    canApplyLiveHost = !state.isActiveLiveHost; // false if active
    conflictCode = HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT;
    conflictMessage = HOSTING_ERROR_MESSAGES.LIVE_HOST_ATTEMPTING_AUDIO_OR_AGENCY;
  } else if (state.hasActiveOrSuspendedAudio) {
    canApplyLiveHost = false;
    canJoinAudioHost = !state.isActiveAudioHost; // false if already in agency
    conflictCode = HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT;
    conflictMessage = HOSTING_ERROR_MESSAGES.AUDIO_HOST_ATTEMPTING_LIVE;
  } else if (state.hasActiveOrSuspendedAgencyOwner) {
    canApplyLiveHost = false;
    canCreateAgency = false;
    conflictCode = HOSTING_ERROR_CODES.HOSTING_ROLE_CONFLICT;
    conflictMessage = HOSTING_ERROR_MESSAGES.AGENCY_OWNER_ATTEMPTING_LIVE;
  } else if (state.hasPendingLiveHostRequest) {
    canJoinAudioHost = false;
    canCreateAgency = false;
    canApplyLiveHost = false;
    conflictCode = HOSTING_ERROR_CODES.HOSTING_REQUEST_CONFLICT_PENDING;
    conflictMessage = HOSTING_ERROR_MESSAGES.CONFLICTING_PENDING_REQUEST;
  } else if (state.hasPendingAudioOrAgencyRequest) {
    canApplyLiveHost = false;
    canCreateAgency = !state.hasPendingAgencyOwnerRequest;
    canJoinAudioHost = !state.hasPendingAudioHostRequest;
    conflictCode = HOSTING_ERROR_CODES.HOSTING_REQUEST_CONFLICT_PENDING;
    conflictMessage = HOSTING_ERROR_MESSAGES.CONFLICTING_PENDING_REQUEST;
  }

  const activeRoles = [];
  if (state.isActiveLiveHost) activeRoles.push('LIVE_HOST');
  if (state.isActiveAudioHost) activeRoles.push('AUDIO_HOST');
  if (state.isActiveAgencyOwner) activeRoles.push('AGENCY_OWNER');

  const suspendedRoles = [];
  if (state.isSuspendedLiveHost) suspendedRoles.push('LIVE_HOST');
  if (state.isSuspendedAudioHost) suspendedRoles.push('AUDIO_HOST');
  if (state.isSuspendedAgencyOwner) suspendedRoles.push('AGENCY_OWNER');

  const pendingRequests = [];
  if (state.hasPendingLiveHostRequest) pendingRequests.push({ type: 'LIVE_HOST', id: state.pendingLiveHostApp.id });
  if (state.hasPendingAudioHostRequest) pendingRequests.push({ type: 'AUDIO_HOST', id: state.pendingAudioHostApp.id });
  if (state.hasPendingAgencyOwnerRequest) pendingRequests.push({ type: 'AGENCY_OWNER', id: state.pendingAgencyApp.id });

  return {
    userId,
    canApplyLiveHost,
    canJoinAudioHost,
    canCreateAgency,
    activeRoles,
    suspendedRoles,
    pendingRequests,
    conflictMessage,
    conflictCode,
    isHistoricalDualConflict: state.isHistoricalDualConflict,
  };
}

export default {
  validateHostingEligibility,
  getPersistedHostingState,
  getHostingEligibilityOverview,
  HostingEligibilityError,
  HOSTING_ERROR_CODES,
  HOSTING_ERROR_MESSAGES,
};
