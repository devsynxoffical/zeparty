// ============================================================
// ZeParty Admin Portal — Auth Context (JavaScript)
// ============================================================

import React, { createContext, useCallback, useEffect, useMemo, useState } from 'react';
import {
  clearSession,
  loadSession,
  loginAdmin,
  logoutAdmin,
  saveSession,
} from '../services/modules/auth.service';

export const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [isLoading, setIsLoading] = useState(true);

  // On mount, rehydrate from localStorage
  useEffect(() => {
    const storedSession = loadSession();
    if (storedSession) {
      setSession(storedSession);
    }
    setIsLoading(false);
  }, []);

  const login = useCallback(async (credentials) => {
    const newSession = await loginAdmin(credentials);
    saveSession(newSession);
    setSession(newSession);
  }, []);

  const setOwnerSession = useCallback((ownerData) => {
    const ownerSession = {
      admin: ownerData.owner || ownerData,
      token: ownerData.accessToken || 'mock_owner_jwt_token',
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    };
    saveSession(ownerSession);
    setSession(ownerSession);
  }, []);

  const logout = useCallback(async () => {
    await logoutAdmin();
    clearSession();
    setSession(null);
  }, []);

  const value = useMemo(
    () => ({
      admin: session?.admin || null,
      session,
      isAuthenticated: session !== null,
      isLoading,
      login,
      setOwnerSession,
      logout,
    }),
    [session, isLoading, login, setOwnerSession, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
