export const walletStatsMock = {
  totalCoinsInCirculation: 150000000,
  totalDiamonds: 50000000,
  coinsPurchased: 450000,
  coinsSpent: 320000,
  coinsGifted: 280000,
  coinsRefunded: 15000,
  pendingAdjustments: 5,
  pendingRefunds: 12,
};

export const walletTransactionsMock = [
  { id: 'TX-2001', date: '2026-08-19T08:15:00Z', type: 'RECHARGE', user: 'User_Alpha', source: 'Apple Pay', destination: 'Wallet', coins: 5000, diamonds: 0, amount: '$49.99', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2002', date: '2026-08-19T09:30:00Z', type: 'GIFT', user: 'User_Beta', source: 'Wallet', destination: 'Host_X', coins: -1000, diamonds: 500, amount: '-', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2003', date: '2026-08-18T14:20:00Z', type: 'REFUND', user: 'User_Charlie', source: 'Admin', destination: 'Wallet', coins: 500, diamonds: 0, amount: '-', status: 'SUCCESS', operator: 'Admin_Sarah' },
  { id: 'TX-2004', date: '2026-08-18T16:45:00Z', type: 'ADJUSTMENT', user: 'User_Delta', source: 'Admin', destination: 'Wallet', coins: -100, diamonds: 0, amount: '-', status: 'SUCCESS', operator: 'Admin_John' },
  { id: 'TX-2005', date: '2026-08-17T11:10:00Z', type: 'WITHDRAWAL', user: 'Host_Y', source: 'Earnings', destination: 'Bank Transfer', coins: 0, diamonds: -10000, amount: '$100.00', status: 'PENDING', operator: 'System' },
  { id: 'TX-2006', date: '2026-08-17T12:00:00Z', type: 'RECHARGE', user: 'User_Echo', source: 'Google Pay', destination: 'Wallet', coins: 1000, diamonds: 0, amount: '$9.99', status: 'FAILED', operator: 'System' },
  { id: 'TX-2007', date: '2026-08-16T09:00:00Z', type: 'CONVERSION', user: 'Host_Z', source: 'Diamonds', destination: 'Coins', coins: 500, diamonds: -500, amount: '-', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2008', date: '2026-08-16T15:30:00Z', type: 'SELLER_DISTRIBUTION', user: 'Seller_One', source: 'Platform', destination: 'Seller Wallet', coins: 100000, diamonds: 0, amount: '-', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2009', date: '2026-08-15T08:00:00Z', type: 'GIFT', user: 'User_Alpha', source: 'Wallet', destination: 'Host_Y', coins: -50, diamonds: 25, amount: '-', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2010', date: '2026-08-15T10:15:00Z', type: 'RECHARGE', user: 'User_Beta', source: 'Credit Card', destination: 'Wallet', coins: 10000, diamonds: 0, amount: '$99.99', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2011', date: '2026-08-14T11:00:00Z', type: 'GIFT', user: 'User_Delta', source: 'Wallet', destination: 'Host_X', coins: -200, diamonds: 100, amount: '-', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2012', date: '2026-08-14T13:45:00Z', type: 'ADJUSTMENT', user: 'User_Echo', source: 'Admin', destination: 'Wallet', coins: 1000, diamonds: 0, amount: '-', status: 'PENDING', operator: 'Admin_Mike' },
  { id: 'TX-2013', date: '2026-08-13T09:20:00Z', type: 'WITHDRAWAL', user: 'Host_X', source: 'Earnings', destination: 'PayPal', coins: 0, diamonds: -50000, amount: '$500.00', status: 'SUCCESS', operator: 'Admin_Sarah' },
  { id: 'TX-2014', date: '2026-08-13T14:30:00Z', type: 'RECHARGE', user: 'User_Charlie', source: 'Apple Pay', destination: 'Wallet', coins: 500, diamonds: 0, amount: '$4.99', status: 'SUCCESS', operator: 'System' },
  { id: 'TX-2015', date: '2026-08-12T16:00:00Z', type: 'GIFT', user: 'User_Echo', source: 'Wallet', destination: 'Host_Z', coins: -5000, diamonds: 2500, amount: '-', status: 'SUCCESS', operator: 'System' },
];
