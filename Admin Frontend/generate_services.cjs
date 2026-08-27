const fs = require('fs');
const path = require('path');

const servicesDir = path.join(__dirname, 'src', 'services', 'modules');
if (!fs.existsSync(servicesDir)) {
  fs.mkdirSync(servicesDir, { recursive: true });
}

const templates = [
  {
    name: 'pkEvents.service.js',
    content: `import { pkEventsMock, pkStats, pkLeaderboard } from '../../mocks/pkEvents.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let data = [...pkEventsMock];

export async function getPKEvents() { await delay(); return [...data]; }
export async function getPKStats() { await delay(); return { ...pkStats }; }
export async function getPKLeaderboard() { await delay(); return [...pkLeaderboard]; }
export async function createPKEvent(eventData) {
  await delay();
  const newEvent = { id: \`PK-\${Date.now()}\`, ...eventData, status: 'SCHEDULED' };
  data = [newEvent, ...data];
  return newEvent;
}
export async function updatePKEvent(id, updateData) {
  await delay();
  data = data.map(d => d.id === id ? { ...d, ...updateData } : d);
  return data.find(d => d.id === id);
}
`
  },
  {
    name: 'wallet.service.js',
    content: `import { walletStatsMock, walletTransactionsMock } from '../../mocks/wallet.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let txData = [...walletTransactionsMock];

export async function getWalletStats() { await delay(); return { ...walletStatsMock }; }
export async function getWalletTransactions() { await delay(); return [...txData]; }
export async function adjustBalance(payload) {
  await delay();
  const newTx = {
    id: \`TX-\${Date.now()}\`,
    date: new Date().toISOString(),
    type: payload.type || 'ADJUSTMENT',
    user: payload.user,
    source: 'Admin',
    destination: 'Wallet',
    coins: payload.currency === 'Coins' ? payload.amount : 0,
    diamonds: payload.currency === 'Diamonds' ? payload.amount : 0,
    amount: '-',
    status: 'SUCCESS',
    operator: 'Current_Admin',
    reason: payload.reason
  };
  txData = [newTx, ...txData];
  return newTx;
}
export async function refundTransaction(txId, reason) {
  await delay();
  txData = txData.map(t => t.id === txId ? { ...t, status: 'REFUNDED' } : t);
  const original = txData.find(t => t.id === txId);
  if(original) {
     const refundTx = { ...original, id: \`REF-\${Date.now()}\`, date: new Date().toISOString(), type: 'REFUND', status: 'SUCCESS', operator: 'Current_Admin', reason };
     txData = [refundTx, ...txData];
  }
  return true;
}
`
  },
  {
    name: 'finance.service.js',
    content: `import { financeDashboardMock, financeRevenueChartMock, financeSettlementsMock } from '../../mocks/finance.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let settlements = [...financeSettlementsMock];

export async function getFinanceDashboard() { await delay(); return { ...financeDashboardMock }; }
export async function getRevenueChart() { await delay(); return [...financeRevenueChartMock]; }
export async function getSettlements() { await delay(); return [...settlements]; }
export async function updateSettlementStatus(id, status) {
  await delay();
  settlements = settlements.map(s => s.id === id ? { ...s, status } : s);
  return settlements.find(s => s.id === id);
}
`
  },
  {
    name: 'store.service.js',
    content: `import { storeStatsMock, storeItemsMock } from '../../mocks/store.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let items = [...storeItemsMock];

export async function getStoreStats() { await delay(); return { ...storeStatsMock }; }
export async function getStoreItems() { await delay(); return [...items]; }
export async function createStoreItem(itemData) {
  await delay();
  const newItem = { id: \`ITM-\${Date.now()}\`, ...itemData, status: 'ACTIVE', purchases: 0, revenue: 0 };
  items = [newItem, ...items];
  return newItem;
}
export async function updateStoreItem(id, updateData) {
  await delay();
  items = items.map(i => i.id === id ? { ...i, ...updateData } : i);
  return items.find(i => i.id === id);
}
`
  },
  {
    name: 'banners.service.js',
    content: `import { bannersStatsMock, bannersMock } from '../../mocks/banners.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let banners = [...bannersMock];

export async function getBannerStats() { await delay(); return { ...bannersStatsMock }; }
export async function getBanners() { await delay(); return [...banners]; }
export async function createBanner(bannerData) {
  await delay();
  const newBanner = { id: \`BAN-\${Date.now()}\`, ...bannerData };
  banners = [newBanner, ...banners];
  return newBanner;
}
export async function updateBanner(id, updateData) {
  await delay();
  banners = banners.map(b => b.id === id ? { ...b, ...updateData } : b);
  return banners.find(b => b.id === id);
}
`
  },
  {
    name: 'moderation.service.js',
    content: `import { moderationStatsMock, moderationReportsMock } from '../../mocks/moderation.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let reports = [...moderationReportsMock];

export async function getModerationStats() { await delay(); return { ...moderationStatsMock }; }
export async function getModerationReports() { await delay(); return [...reports]; }
export async function updateReportStatus(id, status) {
  await delay();
  reports = reports.map(r => r.id === id ? { ...r, status } : r);
  return reports.find(r => r.id === id);
}
`
  },
  {
    name: 'reports.service.js',
    content: `import { reportsCardsMock, reportsUserGrowthChartMock, reportsDeviceBreakdownMock, reportsCountryBreakdownMock } from '../../mocks/reports.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));

export async function getReportCards() { await delay(); return { ...reportsCardsMock }; }
export async function getUserGrowthChart() { await delay(); return [...reportsUserGrowthChartMock]; }
export async function getDeviceBreakdown() { await delay(); return [...reportsDeviceBreakdownMock]; }
export async function getCountryBreakdown() { await delay(); return [...reportsCountryBreakdownMock]; }
`
  },
  {
    name: 'support.service.js',
    content: `import { supportStatsMock, supportTicketsMock } from '../../mocks/support.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let tickets = [...supportTicketsMock];

export async function getSupportStats() { await delay(); return { ...supportStatsMock }; }
export async function getSupportTickets() { await delay(); return [...tickets]; }
export async function updateTicket(id, updateData) {
  await delay();
  tickets = tickets.map(t => t.id === id ? { ...t, ...updateData, updated: new Date().toISOString() } : t);
  return tickets.find(t => t.id === id);
}
`
  }
];

templates.forEach(t => {
  fs.writeFileSync(path.join(servicesDir, t.name), t.content);
  console.log(\`Generated \${t.name}\`);
});
