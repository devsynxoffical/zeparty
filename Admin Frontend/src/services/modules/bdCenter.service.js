// ============================================================
// ZeParty Admin Portal — BD Center Service (JavaScript)
// ============================================================

import { MOCK_BD_CENTERS } from '../../mocks/bdCenters.mock';

let bdCentersState = [...MOCK_BD_CENTERS];

export async function getBDCenters() {
  await new Promise((res) => setTimeout(res, 200));
  return [...bdCentersState];
}

export async function getBDCenterById(id) {
  await new Promise((res) => setTimeout(res, 150));
  const found = bdCentersState.find((b) => b.id === id);
  if (!found) throw new Error(`BD Center with ID ${id} not found`);
  return { ...found };
}

export async function createBDCenter(payload) {
  await new Promise((res) => setTimeout(res, 300));
  const newCenter = {
    id: `bdc-${Date.now().toString().slice(-4)}`,
    code: `BDC-${(payload.region || 'GEN').toUpperCase().slice(0, 4)}-${Math.floor(10 + Math.random() * 90)}`,
    status: 'ACTIVE',
    activeHostsCount: 0,
    activeAgenciesCount: 0,
    monthlyVolumeCoins: 0,
    createdAt: new Date().toISOString(),
    ...payload,
  };
  bdCentersState = [newCenter, ...bdCentersState];
  return newCenter;
}

export async function updateBDCenter(id, updates) {
  await new Promise((res) => setTimeout(res, 300));
  bdCentersState = bdCentersState.map((b) => (b.id === id ? { ...b, ...updates } : b));
  return { success: true };
}

export async function deactivateBDCenter(id) {
  await new Promise((res) => setTimeout(res, 300));
  bdCentersState = bdCentersState.map((b) => (b.id === id ? { ...b, status: 'INACTIVE' } : b));
  return { success: true };
}

export async function assignBDCenter(entityType, entityId, bdCenterId) {
  await new Promise((res) => setTimeout(res, 250));
  return { success: true, entityType, entityId, bdCenterId };
}
