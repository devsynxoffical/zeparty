import { bannersStatsMock, bannersMock } from '../../mocks/banners.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let banners = [...bannersMock];

export async function getBannerStats() { await delay(); return { ...bannersStatsMock }; }
export async function getBanners() { await delay(); return [...banners]; }
export async function createBanner(bannerData) {
  await delay();
  const newBanner = { id: `BAN-${Date.now()}`, ...bannerData };
  banners = [newBanner, ...banners];
  return newBanner;
}
export async function updateBanner(id, updateData) {
  await delay();
  banners = banners.map(b => b.id === id ? { ...b, ...updateData } : b);
  return banners.find(b => b.id === id);
}
