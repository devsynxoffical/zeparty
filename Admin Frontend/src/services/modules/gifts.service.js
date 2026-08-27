// ============================================================
// ZeParty Admin Portal — Gifts Service (JavaScript)
// ============================================================

import { MOCK_GIFTS } from '../../mocks/gifts.mock';

let giftsState = [...MOCK_GIFTS];

export async function getGifts() {
  await new Promise((res) => setTimeout(res, 200));
  return [...giftsState];
}

export async function createGift(giftData) {
  await new Promise((res) => setTimeout(res, 300));
  const newGift = {
    id: 'gift-' + Date.now(),
    name: giftData.name,
    coinPrice: Number(giftData.coinPrice),
    category: giftData.category || 'popular',
    icon: giftData.icon || '🎁',
    active: true,
  };
  giftsState = [newGift, ...giftsState];
  return newGift;
}

export async function updateGift(id, giftData) {
  await new Promise((res) => setTimeout(res, 300));
  giftsState = giftsState.map((g) =>
    g.id === id ? { ...g, ...giftData } : g
  );
  return { success: true };
}

export async function toggleGiftStatus(id) {
  await new Promise((res) => setTimeout(res, 250));
  giftsState = giftsState.map((g) =>
    g.id === id ? { ...g, active: !g.active } : g
  );
  return { success: true };
}
