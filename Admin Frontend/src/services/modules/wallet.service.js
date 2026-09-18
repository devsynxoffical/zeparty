// ============================================================
// ZeParty Admin Portal — Wallet Service (JavaScript)
// ============================================================

import apiClient from '../api';

export async function getWalletStats() {
  const res = await apiClient.get('/v1/wallet/stats');
  const d = res.data?.data || {};
  return {
    totalCoinsInCirculation: Number(d.totalCoins || d.totalCoinsInCirculation || 0),
    totalDiamonds: Number(d.totalDiamonds || 0),
    coinsPurchased: Number(d.totalRechargedUSD || d.coinsPurchased || 0),
    coinsGifted: Number(d.totalWithdrawnUSD || d.coinsGifted || 0),
    totalWallets: d.totalWallets || 0,
  };
}

export async function getWalletTransactions(params = {}) {
  const res = await apiClient.get('/v1/finance/transactions', { params });
  const rawItems = res.data?.data || [];
  return rawItems.map((tx) => ({
    id: tx.id,
    date: tx.createdAt,
    type: tx.type,
    user: tx.wallet?.user?.username || tx.wallet?.userId || tx.userId || 'System',
    source: tx.source || (tx.type === 'RECHARGE' ? 'Gateway' : 'Wallet'),
    destination: tx.destination || (tx.type === 'WITHDRAWAL' ? 'Bank/Payout' : 'Wallet'),
    coins: Number(tx.coinAmount || tx.coins || 0),
    diamonds: Number(tx.diamondAmount || tx.diamonds || 0),
    amount: tx.amount ? `$${tx.amount}` : '-',
    status: tx.status || 'COMPLETED',
    operator: tx.operator || 'System',
    reason: tx.reason || '',
    referenceId: tx.referenceId || '',
  }));
}

export async function adjustBalance(payload) {
  const amountNum = Number(payload.amount);
  const direction = payload.direction || (amountNum < 0 ? 'DEBIT' : 'CREDIT');
  const absAmount = Math.abs(amountNum);
  const asset = (payload.currency || payload.asset || 'COINS').toUpperCase() === 'DIAMONDS' ? 'DIAMONDS' : 'COINS';

  const res = await apiClient.post('/v1/wallet/adjust', {
    targetUserId: payload.targetUserId || payload.user,
    asset,
    direction,
    amount: absAmount,
    reason: payload.reason,
  });

  return res.data;
}

export async function refundTransaction(txId, reason) {
  const res = await apiClient.post(`/v1/admin/chargebacks`, {
    transactionId: txId,
    reason: reason,
  });
  return res.data;
}

export default {
  getWalletStats,
  getWalletTransactions,
  adjustBalance,
  refundTransaction,
};
