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
      logout,
    }),
    [session, isLoading, login, logout]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
