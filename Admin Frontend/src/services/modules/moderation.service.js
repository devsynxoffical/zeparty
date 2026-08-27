import { moderationStatsMock, moderationReportsMock } from '../../mocks/moderation.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let reports = [...moderationReportsMock];

export async function getModerationStats() { await delay(); return { ...moderationStatsMock }; }
export async function getModerationReports() { await delay(); return [...reports]; }
export async function updateReportStatus(id, status) {
  await delay();
  reports = reports.map(r => r.id === id ? { ...r, status } : r);
  return reports.find(r => r.id === id);
}
