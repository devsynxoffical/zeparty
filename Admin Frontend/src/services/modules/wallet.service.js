import { walletStatsMock, walletTransactionsMock } from '../../mocks/wallet.mock.js';

const delay = (ms = 300) => new Promise(r => setTimeout(r, ms));
let txData = [...walletTransactionsMock];

export async function getWalletStats() { await delay(); return { ...walletStatsMock }; }
export async function getWalletTransactions() { await delay(); return [...txData]; }
export async function adjustBalance(payload) {
  await delay();
  const newTx = {
    id: `TX-${Date.now()}`,
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
     const refundTx = { ...original, id: `REF-${Date.now()}`, date: new Date().toISOString(), type: 'REFUND', status: 'SUCCESS', operator: 'Current_Admin', reason };
     txData = [refundTx, ...txData];
  }
  return true;
}
