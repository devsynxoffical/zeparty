import { storeStatsMock, storeItemsMock } from '../../mocks/store.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let items = [...storeItemsMock];

export async function getStoreStats() { await delay(); return { ...storeStatsMock }; }
export async function getStoreItems() { await delay(); return [...items]; }
export async function createStoreItem(itemData) {
  await delay();
  const newItem = { id: `ITM-${Date.now()}`, ...itemData, status: 'ACTIVE', purchases: 0, revenue: 0 };
  items = [newItem, ...items];
  return newItem;
}
export async function updateStoreItem(id, updateData) {
  await delay();
  items = items.map(i => i.id === id ? { ...i, ...updateData } : i);
  return items.find(i => i.id === id);
}
