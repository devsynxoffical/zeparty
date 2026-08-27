// ============================================================
// ZeParty Admin Portal — VIP Service (JavaScript)
// ============================================================

import { MOCK_VIP_ITEMS } from '../../mocks/vip.mock';

let vipState = [...MOCK_VIP_ITEMS];

export async function getVIPItems() {
  await new Promise((res) => setTimeout(res, 200));
  return [...vipState];
}

export async function createVIPItem(vipData) {
  await new Promise((res) => setTimeout(res, 300));
  const newItem = {
    id: 'vip-' + Date.now(),
    name: vipData.name,
    type: vipData.type || 'badge',
    price: Number(vipData.price),
    durationDays: Number(vipData.durationDays || 30),
    active: true,
  };
  vipState = [newItem, ...vipState];
  return newItem;
}

export async function updateVIPItem(id, vipData) {
  await new Promise((res) => setTimeout(res, 300));
  vipState = vipState.map((v) =>
    v.id === id ? { ...v, ...vipData } : v
  );
  return { success: true };
}

export async function toggleVIPStatus(id) {
  await new Promise((res) => setTimeout(res, 250));
  vipState = vipState.map((v) =>
    v.id === id ? { ...v, active: !v.active } : v
  );
  return { success: true };
}
