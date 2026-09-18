// ============================================================
// ZeParty Admin Portal — Audit Logs Service (JavaScript)
// Server-authoritative PostgreSQL Audit Trail Integration
// ============================================================

import apiClient from '../api';

function determineRiskLevel(action = '') {
  const upper = action.toUpperCase();
  if (
    upper.includes('DELETE') ||
    upper.includes('BAN') ||
    upper.includes('OVERRIDE') ||
    upper.includes('SETTLEMENT') ||
    upper.includes('ADJUST_BALANCE') ||
    upper.includes('OWNER')
  ) {
    return 'HIGH';
  }
  if (upper.includes('UPDATE') || upper.includes('PATCH') || upper.includes('CREATE') || upper.includes('STATUS')) {
    return 'MEDIUM';
  }
  return 'LOW';
}

function formatAuditLogRecord(log) {
  if (!log) return null;
  return {
    id: log.id,
    timestamp: log.createdAt || log.timestamp || new Date().toISOString(),
    operatorId: log.adminId || log.operatorId || 'SYSTEM',
    operatorName: log.adminName || log.operatorName || 'System Admin',
    operatorRole: log.operatorRole || (log.adminId ? 'Administrator' : 'System'),
    module: log.targetEntity || log.module || 'System',
    action: log.action || 'ADMIN_ACTION',
    targetType: log.targetEntity || log.targetType || 'ENTITY',
    targetId: log.targetEntityId || log.targetId || '-',
    targetName: log.targetName || log.targetEntityId || log.targetEntity || '-',
    riskLevel: log.riskLevel || determineRiskLevel(log.action),
    status: log.status || 'SUCCESS',
    reason: log.reason || null,
    beforeValue: log.beforeStateJson || log.beforeValue || null,
    afterValue: log.afterStateJson || log.afterValue || null,
    deviceIp: log.ipAddress || log.deviceIp || '127.0.0.1',
    approvalId: log.approvalId || null,
  };
}

export async function getAuditLogs(params = {}) {
  try {
    const res = await apiClient.get('/v1/admin/audit-logs', { params });
    if (res.data && res.data.success && Array.isArray(res.data.data)) {
      return res.data.data.map(formatAuditLogRecord);
    }
    return [];
  } catch (err) {
    const errorMsg =
      err.response?.data?.message ||
      err.response?.data?.error?.message ||
      err.message ||
      'Failed to fetch audit logs from backend.';
    throw new Error(errorMsg);
  }
}

export async function getAuditLogById(id) {
  try {
    const res = await apiClient.get(`/v1/admin/audit-logs/${id}`);
    if (res.data && res.data.success && res.data.data) {
      return formatAuditLogRecord(res.data.data);
    }
    const logs = await getAuditLogs();
    const found = logs.find((l) => l.id === id);
    if (found) return found;
    throw new Error('Audit log record not found');
  } catch (err) {
    throw new Error(err.response?.data?.message || 'Failed to fetch audit log details.');
  }
}

export async function filterAuditLogs(filters = {}) {
  const logs = await getAuditLogs(filters);
  return logs.filter((log) => {
    let match = true;
    if (filters.module && filters.module !== 'ALL' && filters.module !== 'All Modules') {
      match = match && (log.module === filters.module || log.targetType === filters.module);
    }
    if (filters.action) match = match && log.action.includes(filters.action);
    if (filters.operatorId) match = match && log.operatorId === filters.operatorId;
    if (filters.targetType) match = match && log.targetType === filters.targetType;
    if (filters.targetId) match = match && log.targetId === filters.targetId;
    if (filters.riskLevel && filters.riskLevel !== 'ALL' && filters.riskLevel !== 'All Risk Levels') {
      match = match && log.riskLevel === filters.riskLevel;
    }
    if (filters.status && filters.status !== 'ALL' && filters.status !== 'All Status') {
      match = match && log.status === filters.status;
    }
    if (filters.search) {
      const q = filters.search.toLowerCase();
      match =
        match &&
        (log.targetName?.toLowerCase().includes(q) ||
          log.operatorName?.toLowerCase().includes(q) ||
          log.action?.toLowerCase().includes(q) ||
          log.id?.toLowerCase().includes(q));
    }
    return match;
  });
}

export async function getLogsForModule(moduleName) {
  return getAuditLogs({ targetEntity: moduleName });
}

export async function getLogsForTarget(targetId) {
  return getAuditLogs({ targetEntityId: targetId });
}

export async function getLogsForOperator(operatorId) {
  return getAuditLogs({ adminId: operatorId });
}

export async function addAuditLog(payload = {}) {
  const formatted = formatAuditLogRecord({
    id: payload.id || `audit-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
    ...payload,
  });
  return formatted;
}

export async function logEvent(actionOrPayload, targetType, targetId, reason) {
  let logData;
  if (typeof actionOrPayload === 'object' && actionOrPayload !== null) {
    logData = actionOrPayload;
  } else {
    logData = {
      action: actionOrPayload,
      targetType,
      targetId,
      reason,
    };
  }
  return addAuditLog(logData);
}

export default {
  getAuditLogs,
  getAuditLogById,
  filterAuditLogs,
  getLogsForModule,
  getLogsForTarget,
  getLogsForOperator,
  addAuditLog,
  logEvent,
};

