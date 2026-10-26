// ============================================================
// ZeParty Admin Portal — Privacy Policy & Eligibility Service (JavaScript)
// ============================================================

import apiClient from '../api';

/**
 * Retrieves the effective privacy feature eligibility policy.
 */
export async function getPrivacyEligibilityPolicy() {
  const response = await apiClient.get('/v1/admin/policies/privacy/eligibility');
  return response.data?.data || response.data || {};
}

/**
 * Updates the eligibility rules (SVIP tiers, Noble ranks, grants) for a feature.
 *
 * @param {Object} payload
 * @param {string} payload.featureKey
 * @param {number[]} [payload.eligibleSvipLevels]
 * @param {string[]} [payload.eligibleNobleRanks]
 * @param {string[]} [payload.individualUserGrants]
 */
export async function updatePrivacyEligibilityPolicy(payload) {
  const response = await apiClient.put('/v1/admin/policies/privacy/eligibility', payload);
  return response.data?.data || response.data || {};
}

/**
 * Explicitly grants individual access to a privacy feature for a user.
 *
 * @param {string} userId
 * @param {string} featureKey
 */
export async function grantIndividualPrivacyAccess(userId, featureKey) {
  const response = await apiClient.post('/v1/admin/policies/privacy/eligibility/grant', {
    userId,
    featureKey,
  });
  return response.data?.data || response.data || {};
}

/**
 * Revokes explicit individual access to a privacy feature for a user.
 *
 * @param {string} userId
 * @param {string} featureKey
 */
export async function revokeIndividualPrivacyAccess(userId, featureKey) {
  const response = await apiClient.post('/v1/admin/policies/privacy/eligibility/revoke', {
    userId,
    featureKey,
  });
  return response.data?.data || response.data || {};
}

export default {
  getPrivacyEligibilityPolicy,
  updatePrivacyEligibilityPolicy,
  grantIndividualPrivacyAccess,
  revokeIndividualPrivacyAccess,
};
