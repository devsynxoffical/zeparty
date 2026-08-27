// ============================================================
// ZeParty Admin Portal — Audit Logs Service (Mock)
// ============================================================

import { generateMockAuditLogs } from '../../mocks/auditLogs.mock';

let auditLogs = generateMockAuditLogs();

export const getAuditLogs = async () => {
  return [...auditLogs];
};

export const getAuditLogById = async (id) => {
  return auditLogs.find((l) => l.id === id) || null;
};

export const addAuditLog = async (payload) => {
  const newLog = {
    id: `log-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
    timestamp: new Date().toISOString(),
    ...payload,
  };
  auditLogs = [newLog, ...auditLogs];
  return newLog;
};

export const logEvent = addAuditLog;

export const filterAuditLogs = async (filters = {}) => {
  return auditLogs.filter((log) => {
    let match = true;
    if (filters.module && filters.module !== 'All Modules') match = match && log.module === filters.module;
    if (filters.action) match = match && log.action.includes(filters.action);
    if (filters.operatorId) match = match && log.operatorId === filters.operatorId;
    if (filters.targetType) match = match && log.targetType === filters.targetType;
    if (filters.targetId) match = match && log.targetId === filters.targetId;
    if (filters.riskLevel && filters.riskLevel !== 'All Risk Levels') match = match && log.riskLevel === filters.riskLevel;
    if (filters.status && filters.status !== 'All Status') match = match && log.status === filters.status;
    if (filters.search) {
      const q = filters.search.toLowerCase();
      match = match && (
        log.targetName?.toLowerCase().includes(q) ||
        log.operatorName?.toLowerCase().includes(q) ||
        log.action.toLowerCase().includes(q) ||
        log.id.toLowerCase().includes(q)
      );
    }
    return match;
  });
};

export const getLogsForModule = async (moduleName) => {
  return filterAuditLogs({ module: moduleName });
};

export const getLogsForTarget = async (targetId) => {
  return filterAuditLogs({ targetId });
};

export const getLogsForOperator = async (operatorId) => {
  return filterAuditLogs({ operatorId });
};
