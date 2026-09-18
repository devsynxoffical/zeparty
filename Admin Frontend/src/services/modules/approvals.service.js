// ============================================================
// ZeParty Admin Portal — Approvals Service (JavaScript)
// ============================================================

import apiClient from '../api';
import { logEvent } from './auditLogs.service';

export async function getApprovals(params = {}) {
  const res = await apiClient.get('/v1/admin/approvals', { params });
  const items = res.data?.data || [];

  return items.map((item) => {
    const payload = item.payloadStateJson || {};
    const before = item.beforeStateJson || {};
    const amountVal = payload.amount || payload.coinAmount || payload.diamondAmount || payload.amountUSD || 0;

    return {
      id: item.id,
      category: item.module?.toUpperCase() || 'WALLET',
      type: item.actionType || 'APPROVAL_REQUEST',
      title: `${item.actionType || 'Action'} for ${payload.targetUserId || payload.targetName || item.module || 'Entity'}`,
      targetName: payload.targetUserId || payload.targetName || item.module,
      targetId: payload.targetUserId || item.id,
      amount: amountVal ? Number(amountVal) : null,
      currency: payload.asset || (payload.coins ? 'Coins' : payload.diamonds ? 'Diamonds' : 'USD'),
      status: item.status || 'PENDING',
      completedSteps: item.status === 'APPROVED' ? 1 : 0,
      requiredSteps: 1,
      approvalModel: 'SINGLE',
      requesterName: item.requester?.username || item.requester?.name || item.requesterId || 'Admin',
      requesterRole: 'Staff Admin',
      reason: payload.reason || item.rejectionReason || 'Administrative approval request',
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      approver: item.approver?.username || item.approver?.name || item.approverId,
      rejectionReason: item.rejectionReason,
      payloadStateJson: payload,
      beforeStateJson: before,
      history: [
        {
          step: 1,
          action: 'REQUESTED',
          operator: item.requester?.username || item.requesterId || 'Requester',
          role: 'Administrator',
          timestamp: item.createdAt,
          note: payload.reason || 'Approval request submitted.',
        },
        ...(item.status === 'APPROVED'
          ? [
              {
                step: 2,
                action: 'APPROVED',
                operator: item.approver?.username || item.approverId || 'Approver',
                role: 'Super Admin',
                timestamp: item.updatedAt,
                note: 'Request approved.',
              },
            ]
          : []),
        ...(item.status === 'REJECTED'
          ? [
              {
                step: 2,
                action: 'REJECTED',
                operator: item.approver?.username || item.approverId || 'Reviewer',
                role: 'Super Admin',
                timestamp: item.updatedAt,
                note: item.rejectionReason || 'Request rejected.',
              },
            ]
          : []),
      ],
    };
  });
}

export async function getApprovalById(id) {
  const res = await apiClient.get(`/v1/admin/approvals/${id}`);
  return res.data?.data;
}

export async function createApprovalRequest(requestData) {
  const res = await apiClient.post('/v1/admin/approvals', requestData);
  return res.data?.data;
}

export async function processApprovalStep(id, actionType, operatorName, operatorRole, note = '') {
  if (actionType === 'APPROVE') {
    const res = await apiClient.post(`/v1/admin/approvals/${id}/approve`);
    await logEvent(
      'APPROVAL_APPROVE',
      'approval',
      id,
      `${operatorName} (${operatorRole}) approved request ${id}`
    );
    return res.data;
  } else if (actionType === 'REJECT') {
    const res = await apiClient.post(`/v1/admin/approvals/${id}/reject`, {
      reason: note || 'Rejected by administrator',
    });
    await logEvent(
      'APPROVAL_REJECT',
      'approval',
      id,
      `${operatorName} (${operatorRole}) rejected request ${id}: ${note}`
    );
    return res.data;
  }

  return { success: true };
}

export default {
  getApprovals,
  getApprovalById,
  createApprovalRequest,
  processApprovalStep,
};
