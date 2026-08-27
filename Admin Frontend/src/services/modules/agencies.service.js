// ============================================================
// ZeParty Admin Portal — Agencies Service (JavaScript)
// ============================================================

import { MOCK_AGENCY_APPLICATIONS, MOCK_AGENCIES_LIST } from '../../mocks/hosts.mock';

let agenciesState = [...MOCK_AGENCY_APPLICATIONS];
let activeAgenciesState = [...MOCK_AGENCIES_LIST];

export async function getAgencies() {
  await new Promise((res) => setTimeout(res, 50));
  return [...agenciesState];
}

export async function getActiveAgencies() {
  await new Promise((res) => setTimeout(res, 50));
  return [...activeAgenciesState];
}

export async function getAgencyById(id) {
  await new Promise((res) => setTimeout(res, 50));
  const agency = activeAgenciesState.find((a) => a.id === id) || agenciesState.find((a) => a.id === id);
  if (!agency) throw new Error('Agency not found');
  return { ...agency };
}

export async function approveAgency(id) {
  await new Promise((res) => setTimeout(res, 100));
  agenciesState = agenciesState.map((a) =>
    a.id === id ? { ...a, status: 'approved', reviewedAt: new Date().toISOString() } : a
  );
  return { success: true };
}

export async function rejectAgency(id, reason) {
  await new Promise((res) => setTimeout(res, 100));
  agenciesState = agenciesState.map((a) =>
    a.id === id ? { ...a, status: 'rejected', rejectReason: reason, reviewedAt: new Date().toISOString() } : a
  );
  return { success: true };
}

export async function transferHostAgency(hostId, fromAgencyId, toAgencyId, reason) {
  await new Promise((res) => setTimeout(res, 100));
  return { success: true, hostId, fromAgencyId, toAgencyId, transferredAt: new Date().toISOString() };
}
