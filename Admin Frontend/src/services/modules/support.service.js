import { supportStatsMock, supportTicketsMock } from '../../mocks/support.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let tickets = [...supportTicketsMock];

export async function getSupportStats() { await delay(); return { ...supportStatsMock }; }
export async function getSupportTickets() { await delay(); return [...tickets]; }
export async function updateTicket(id, updateData) {
  await delay();
  tickets = tickets.map(t => t.id === id ? { ...t, ...updateData, updated: new Date().toISOString() } : t);
  return tickets.find(t => t.id === id);
}
