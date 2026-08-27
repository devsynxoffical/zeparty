// ============================================================
// ZeParty Admin Portal — Economy Service (JavaScript)
// ============================================================

let economySettingsState = {
  coinToUSD: 100, // 100 coins = $1.00
  diamondsToUSD: 200, // 200 diamonds = $1.00
  hostCommissionPct: 60, // Host gets 60%
  platformCommissionPct: 40,
  dailyRewardBase: 10,
  maxDailyReward: 100,
  minWithdrawalUSD: 50,
  maxWithdrawalUSD: 5000,
};

export async function getEconomySettings() {
  await new Promise((res) => setTimeout(res, 200));
  return { ...economySettingsState };
}

export async function updateEconomySettings(newSettings) {
  await new Promise((res) => setTimeout(res, 300));
  economySettingsState = { ...economySettingsState, ...newSettings };
  return { success: true, settings: { ...economySettingsState } };
}
