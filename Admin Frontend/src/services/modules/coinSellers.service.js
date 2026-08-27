// ============================================================
// ZeParty Admin Portal — Coin Sellers Service (JavaScript)
// ============================================================

const MOCK_SELLERS = [
  {
    id: 'seller-001',
    name: 'Global Pay Solutions',
    contactEmail: 'sales@globalpay.io',
    allocatedQuota: 10000000,
    soldCoins: 7500000,
    commissionPct: 5.0,
    status: 'active',
  },
  {
    id: 'seller-002',
    name: 'Asia Direct Coins',
    contactEmail: 'support@asiadirect.com',
    allocatedQuota: 5000000,
    soldCoins: 4200000,
    commissionPct: 4.5,
    status: 'active',
  },
  {
    id: 'seller-003',
    name: 'Middle East Resellers',
    contactEmail: 'me@coinreseller.ae',
    allocatedQuota: 8000000,
    soldCoins: 1200000,
    commissionPct: 6.0,
    status: 'inactive',
  },
];

let sellersState = [...MOCK_SELLERS];

export async function getCoinSellers() {
  await new Promise((res) => setTimeout(res, 200));
  return [...sellersState];
}

export async function toggleSellerStatus(id) {
  await new Promise((res) => setTimeout(res, 250));
  sellersState = sellersState.map((s) =>
    s.id === id ? { ...s, status: s.status === 'active' ? 'inactive' : 'active' } : s
  );
  return { success: true };
}
