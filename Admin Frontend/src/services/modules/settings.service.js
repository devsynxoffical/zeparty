// ============================================================
// ZeParty Admin Portal — Settings Service (JavaScript)
// ============================================================

let portalSettingsState = {
  portalName: 'ZeParty Admin Portal',
  supportEmail: 'support@zeparty.app',
  sessionTimeoutMinutes: 60,
  maxLoginAttempts: 5,
  require2FAForAdmins: true,
  passwordExpiryDays: 90,
  ipWhitelistEnabled: false,
  whitelistedIPs: '192.168.1.1, 10.0.0.1',
};

export async function getPortalSettings() {
  await new Promise((res) => setTimeout(res, 200));
  return { ...portalSettingsState };
}

export async function updatePortalSettings(newSettings) {
  await new Promise((res) => setTimeout(res, 350));
  portalSettingsState = { ...portalSettingsState, ...newSettings };
  return { success: true, settings: { ...portalSettingsState } };
}
