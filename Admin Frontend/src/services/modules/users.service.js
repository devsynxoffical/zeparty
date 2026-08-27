// ============================================================
// ZeParty Admin Portal — Users Service (JavaScript)
// ============================================================

import { MOCK_USERS } from '../../mocks/users.mock';

let usersState = [...MOCK_USERS];

export async function getUsers() {
  await new Promise((res) => setTimeout(res, 200));
  return [...usersState];
}

export async function getUserById(id) {
  await new Promise((res) => setTimeout(res, 150));
  const user = usersState.find((u) => u.id === id);
  if (!user) throw new Error('User not found');
  return { ...user };
}

export async function suspendUser(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  usersState = usersState.map((u) =>
    u.id === id ? { ...u, status: 'suspended', suspendReason: reason } : u
  );
  return { success: true };
}

export async function banUser(id, reason) {
  await new Promise((res) => setTimeout(res, 300));
  usersState = usersState.map((u) =>
    u.id === id ? { ...u, status: 'banned', banReason: reason } : u
  );
  return { success: true };
}

export async function unbanUser(id) {
  await new Promise((res) => setTimeout(res, 300));
  usersState = usersState.map((u) =>
    u.id === id ? { ...u, status: 'active', banReason: null, suspendReason: null } : u
  );
  return { success: true };
}

export async function adjustUserBalance(id, amount, type, note) {
  await new Promise((res) => setTimeout(res, 300));
  usersState = usersState.map((u) => {
    if (u.id !== id) return u;
    const delta = type === 'add' ? Number(amount) : -Number(amount);
    return { ...u, coins: Math.max(0, u.coins + delta) };
  });
  return { success: true };
}
