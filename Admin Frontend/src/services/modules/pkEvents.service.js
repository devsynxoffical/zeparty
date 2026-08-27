import { pkEventsMock, pkStats, pkLeaderboard } from '../../mocks/pkEvents.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let data = [...pkEventsMock];

export async function getPKEvents() { await delay(); return [...data]; }
export async function getPKStats() { await delay(); return { ...pkStats }; }
export async function getPKLeaderboard() { await delay(); return [...pkLeaderboard]; }
export async function createPKEvent(eventData) {
  await delay();
  const newEvent = { id: `PK-${Date.now()}`, ...eventData, status: 'SCHEDULED' };
  data = [newEvent, ...data];
  return newEvent;
}
export async function updatePKEvent(id, updateData) {
  await delay();
  data = data.map(d => d.id === id ? { ...d, ...updateData } : d);
  return data.find(d => d.id === id);
}
