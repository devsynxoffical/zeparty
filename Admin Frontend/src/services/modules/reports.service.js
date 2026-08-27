import { reportsCardsMock, reportsUserGrowthChartMock, reportsDeviceBreakdownMock, reportsCountryBreakdownMock } from '../../mocks/reports.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));

export async function getReportCards() { await delay(); return { ...reportsCardsMock }; }
export async function getUserGrowthChart() { await delay(); return [...reportsUserGrowthChartMock]; }
export async function getDeviceBreakdown() { await delay(); return [...reportsDeviceBreakdownMock]; }
export async function getCountryBreakdown() { await delay(); return [...reportsCountryBreakdownMock]; }
