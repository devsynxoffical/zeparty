// ============================================================
// ZeParty Admin Portal — Economy & Policy Service (JavaScript)
// Server-authoritative PostgreSQL Policy & Economy Integration
// ============================================================

import apiClient from '../api';

const DEFAULT_ECONOMY_CONFIGS = {
  coinToUSD: 10000,
  diamondsToUSD: 10000,
  platformCutPercent: 45,
  hostCutPercent: 35,
  agencyCutPercent: 12,
  roomCutPercent: 8,
  minWithdrawalUSD: 50,
  maxWithdrawalUSD: 5000,
};

// ---- Dynamic Key-Value Configuration APIs ----

export async function getEconomyConfigs() {
  try {
    const res = await apiClient.get('/v1/admin/economy/configs');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (!import.meta.env.DEV) {
      throw new Error(err.response?.data?.message || 'Failed to load economy configurations.');
    }
    console.warn('API getEconomyConfigs failed, using fallback:', err.message);
  }
  return DEFAULT_ECONOMY_CONFIGS;
}

export async function getEconomyConfigByKey(key) {
  try {
    const res = await apiClient.get(`/v1/admin/economy/configs/${encodeURIComponent(key)}`);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (!import.meta.env.DEV) {
      throw new Error(err.response?.data?.message || `Failed to load config for key ${key}.`);
    }
    console.warn(`API getEconomyConfigByKey(${key}) failed:`, err.message);
  }
  return null;
}

export async function updateEconomyConfig(key, valueJson, reason = '') {
  try {
    const res = await apiClient.put(`/v1/admin/economy/configs/${encodeURIComponent(key)}`, {
      valueJson,
      reason: reason || `Updated ${key} configuration`,
    });
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (err.response?.data?.message) {
      throw new Error(err.response.data.message);
    }
    if (!import.meta.env.DEV) {
      throw new Error(`Failed to update ${key} configuration.`);
    }
    console.warn(`API updateEconomyConfig(${key}) failed:`, err.message);
  }
  return { key, valueJson, status: 'ACTIVE' };
}

export async function disableEconomyConfig(key, reason = '') {
  const res = await apiClient.post(`/v1/admin/economy/configs/${encodeURIComponent(key)}/disable`, { reason });
  return res.data;
}

export async function restoreEconomyConfig(key) {
  const res = await apiClient.post(`/v1/admin/economy/configs/${encodeURIComponent(key)}/restore`);
  return res.data;
}

// ---- Master Policy & Versioning APIs ----

export async function getPolicies() {
  try {
    const res = await apiClient.get('/v1/admin/policies');
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (!import.meta.env.DEV) {
      throw new Error(err.response?.data?.message || 'Failed to load master policies.');
    }
    console.warn('API getPolicies failed, using fallback:', err.message);
  }
  return [];
}

export async function getEffectivePolicy(policyType) {
  try {
    const res = await apiClient.get(`/v1/admin/policies/effective/${encodeURIComponent(policyType)}`);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (!import.meta.env.DEV) {
      throw new Error(err.response?.data?.message || `Failed to load effective policy for ${policyType}.`);
    }
    console.warn(`API getEffectivePolicy(${policyType}) failed:`, err.message);
  }
  return null;
}

export async function getPolicyById(id) {
  const res = await apiClient.get(`/v1/admin/policies/${id}`);
  return res.data?.data;
}

export async function createPolicy(policyData) {
  const res = await apiClient.post('/v1/admin/policies', policyData);
  return res.data?.data;
}

export async function getPolicyVersions(policyId) {
  try {
    const res = await apiClient.get(`/v1/admin/policies/${policyId}/versions`);
    if (res.data && res.data.success) {
      return res.data.data;
    }
  } catch (err) {
    if (!import.meta.env.DEV) {
      throw new Error(err.response?.data?.message || 'Failed to load policy versions.');
    }
    console.warn(`API getPolicyVersions(${policyId}) failed:`, err.message);
  }
  return [];
}

export async function createPolicyVersion(policyId, versionData) {
  const res = await apiClient.post(`/v1/admin/policies/${policyId}/versions`, versionData);
  return res.data?.data;
}

export async function publishPolicyVersion(policyId, versionId) {
  const res = await apiClient.post(`/v1/admin/policies/${policyId}/versions/${versionId}/publish`);
  return res.data?.data;
}

export async function rollbackPolicy(policyId, toVersionId) {
  const res = await apiClient.post(`/v1/admin/policies/${policyId}/rollback`, { toVersionId });
  return res.data?.data;
}

// ---- Legacy Compatibility Wrappers ----

export async function getEconomySettings() {
  const configs = await getEconomyConfigs();
  return {
    coinToUSD: configs?.coinToUSD || 10000,
    diamondsToUSD: configs?.diamondsToUSD || 10000,
    hostCommissionPct: configs?.hostCutPercent || 35,
    platformCommissionPct: configs?.platformCutPercent || 45,
    agencyCommissionPct: configs?.agencyCutPercent || 12,
    roomRewardPct: configs?.roomCutPercent || 8,
    dailyRewardBase: configs?.dailyRewardBase || 10,
    maxDailyReward: configs?.maxDailyReward || 100,
    minWithdrawalUSD: configs?.minWithdrawalUSD || 50,
    maxWithdrawalUSD: configs?.maxWithdrawalUSD || 5000,
  };
}

export async function updateEconomySettings(newSettings) {
  return updateEconomyConfig('ECONOMY_SETTINGS', newSettings, 'Updated portal economy settings');
}

export default {
  getEconomyConfigs,
  getEconomyConfigByKey,
  updateEconomyConfig,
  disableEconomyConfig,
  restoreEconomyConfig,
  getPolicies,
  getEffectivePolicy,
  getPolicyById,
  createPolicy,
  getPolicyVersions,
  createPolicyVersion,
  publishPolicyVersion,
  rollbackPolicy,
  getEconomySettings,
  updateEconomySettings,
};
