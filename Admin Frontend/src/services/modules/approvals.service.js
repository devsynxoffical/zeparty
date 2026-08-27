// ============================================================
// ZeParty Admin Portal — Approvals Service (JavaScript)
// ============================================================

import { MOCK_APPROVALS } from '../../mocks/approvals.mock';
import { logEvent } from './auditLogs.service';

let approvalsState = [...MOCK_APPROVALS];

export async function getApprovals() {
  return new Promise((resolve) => {
    setTimeout(() => resolve([...approvalsState]), 50);
  });
}

export async function getApprovalById(id) {
  return new Promise((resolve) => {
    const item = approvalsState.find((a) => a.id === id);
    setTimeout(() => resolve(item ? { ...item } : null), 50);
  });
}

export async function createApprovalRequest(requestData) {
  const newId = `APP-${Math.floor(1000 + Math.random() * 9000)}`;
  const newRecord = {
    id: newId,
    status: 'PENDING',
    completedSteps: 0,
    createdAt: new Date().toISOString(),
    history: [
      {
        step: 1,
        action: 'REQUESTED',
        operator: requestData.requesterName || 'Admin User',
        role: requestData.requesterRole || 'Administrator',
        timestamp: new Date().toISOString(),
        note: requestData.reason || 'Approval request submitted.',
      },
    ],
    ...requestData,
  };

  approvalsState.unshift(newRecord);

  await logEvent(
    'APPROVAL_REQUESTED',
    'approval',
    newId,
    `Created ${requestData.type || 'Approval Request'} for ${requestData.targetName || newId}`
  );

  return newRecord;
}

export async function processApprovalStep(id, actionType, operatorName, operatorRole, note = '') {
  const itemIndex = approvalsState.findIndex((a) => a.id === id);
  if (itemIndex === -1) throw new Error('Approval request not found');

  const item = { ...approvalsState[itemIndex] };
  const now = new Date().toISOString();

  if (actionType === 'REJECT') {
    item.status = 'REJECTED';
    item.history.push({
      step: item.history.length + 1,
      action: 'REJECTED',
      operator: operatorName,
      role: operatorRole,
      timestamp: now,
      note: note || 'Request was rejected.',
    });
  } else if (actionType === 'HOLD') {
    item.status = 'HELD';
    item.history.push({
      step: item.history.length + 1,
      action: 'HELD',
      operator: operatorName,
      role: operatorRole,
      timestamp: now,
      note: note || 'Request placed on hold pending additional verification.',
    });
  } else if (actionType === 'ESCALATE') {
    item.status = 'ESCALATED';
    item.history.push({
      step: item.history.length + 1,
      action: 'ESCALATED',
      operator: operatorName,
      role: operatorRole,
      timestamp: now,
      note: note || 'Request escalated to Super Admin review.',
    });
  } else if (actionType === 'APPROVE') {
    if (item.approvalModel === 'FOUR_EYES' && item.requiredSteps === 2) {
      if (item.completedSteps === 0) {
        // Step 1 approval
        item.completedSteps = 1;
        item.status = 'UNDER_REVIEW';
        item.reviewer1 = operatorName;
        item.history.push({
          step: item.history.length + 1,
          action: 'FIRST_APPROVAL',
          operator: operatorName,
          role: operatorRole,
          timestamp: now,
          note: note || 'First-admin review approved. Awaiting second-admin confirmation.',
        });
      } else {
        // Step 2 approval - check second admin
        if (item.reviewer1 === operatorName) {
          throw new Error('Four-Eyes Enforcement: The second reviewer must be a different administrator.');
        }
        item.completedSteps = 2;
        item.status = 'APPROVED';
        item.reviewer2 = operatorName;
        item.approver = `${item.reviewer1} & ${operatorName}`;
        item.history.push({
          step: item.history.length + 1,
          action: 'FINAL_APPROVAL',
          operator: operatorName,
          role: operatorRole,
          timestamp: now,
          note: note || 'Second-admin review approved. Workflow completed.',
        });
      }
    } else {
      // Single approval model
      item.completedSteps = 1;
      item.status = 'APPROVED';
      item.approver = operatorName;
      item.history.push({
        step: item.history.length + 1,
        action: 'APPROVED',
        operator: operatorName,
        role: operatorRole,
        timestamp: now,
        note: note || 'Request approved.',
      });
    }
  }

  approvalsState[itemIndex] = item;

  await logEvent(
    `APPROVAL_${actionType}`,
    'approval',
    id,
    `${operatorName} (${operatorRole}) performed ${actionType} on ${item.title}`
  );

  return item;
}
