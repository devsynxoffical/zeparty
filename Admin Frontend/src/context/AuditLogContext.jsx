import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { getAuditLogs, addAuditLog } from '../services/modules/auditLogs.service';

const AuditLogContext = createContext();

export function AuditLogProvider({ children }) {
  const [logs, setLogs] = useState([]);

  useEffect(() => {
    getAuditLogs().then(setLogs);
  }, []);

  const logAdminAction = useCallback(async (payload) => {
    const defaultPayload = {
      operatorId: 'admin-1',
      operatorName: 'Current User', // This would come from Auth context
      operatorRole: 'Super Admin',
      timestamp: new Date().toISOString(),
      status: 'SUCCESS',
      riskLevel: 'LOW',
      metadata: { ip: '127.0.0.1' },
      ...payload
    };
    
    const newLog = await addAuditLog(defaultPayload);
    setLogs((prevLogs) => [newLog, ...prevLogs]);
    return newLog;
  }, []);

  // Keep addLog for backwards compatibility with existing pages until they are migrated
  const addLog = useCallback(async (action, targetId, module, details) => {
    return logAdminAction({
      action,
      targetId,
      module,
      reason: details,
      targetType: 'unknown',
    });
  }, [logAdminAction]);

  return (
    <AuditLogContext.Provider value={{ logs, logAdminAction, addLog }}>
      {children}
    </AuditLogContext.Provider>
  );
}

export function useAuditLog() {
  return useContext(AuditLogContext);
}
