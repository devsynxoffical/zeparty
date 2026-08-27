// ============================================================
// ZeParty Admin Portal — Hosts Service (JavaScript)
// ============================================================

import { MOCK_HOST_APPLICATIONS } from '../../mocks/hosts.mock';

let hostsState = [...MOCK_HOST_APPLICATIONS];

export async function getHostApplications() {
  await new Promise((res) => setTimeout(res, 200));
  return [...hostsState];
}

export async function getHostApplicationById(id) {
  await new Promise((res) => setTimeout(res, 150));
  const app = hostsState.find((h) => h.id === id);
  if (!app) throw new Error('Host application not found');
  return { ...app };
}

export async function approveHostApplication(id) {
  await new Promise((res) => setTimeout(res, 300));
  hostsState = hostsState.map((h) =>
    h.id === id ? { ...h, status: 'approved', reviewedAt: new Date().toISOString() } : h
  );
  return { success: true };
}

export async function rejectHostApplication(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  hostsState = hostsState.map((h) =>
    h.id === id ? { ...h, status: 'rejected', rejectReason: reason, reviewedAt: new Date().toISOString() } : h
  );
  return { success: true };
}
