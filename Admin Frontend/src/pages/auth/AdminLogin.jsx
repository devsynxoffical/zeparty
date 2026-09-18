// ============================================================
// ZeParty Admin Portal — Admin Login Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Eye, EyeOff, Lock, User } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import zepartyLogo from '../../assets/images/zeparty-logo.png';

export function AdminLogin() {
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const from = '/admin';

  const [credentials, setCredentials] = useState({ username: '', password: '' });
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Redirect already-authenticated users — must be in useEffect, not render body,
  // to avoid an infinite re-render loop (navigate() during render causes a loop).
  useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true });
    }
  }, [isAuthenticated, navigate, from]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!credentials.username || !credentials.password) {
      setError('Please enter your username and password.');
      return;
    }

    setError(null);
    setIsLoading(true);
    try {
      await login(credentials);
      navigate(from, { replace: true });
    } catch (err) {
      setError(err.message || 'Authentication failed. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage: `radial-gradient(circle at 20% 50%, rgba(212,175,55,0.08) 0%, transparent 50%),
                            radial-gradient(circle at 80% 20%, rgba(184,150,46,0.06) 0%, transparent 40%)`,
        }}
        aria-hidden="true"
      />

      <div className="relative w-full max-w-sm">
        <div className="mb-8 flex flex-col items-center text-center">
          <div className="mb-3 flex h-20 w-20 items-center justify-center rounded-2xl bg-slate-900 border border-gold-500/30 p-1.5 shadow-xl shadow-gold-500/10">
            <img
              src={zepartyLogo}
              alt="ZeParty Logo"
              className="h-full w-full rounded-xl object-cover"
            />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">ZeParty</h1>
          <p className="mt-0.5 text-xs font-semibold text-gold-400 uppercase tracking-widest bg-gold-500/10 px-2 py-0.5 rounded border border-gold-500/20">
            Admin Portal
          </p>
        </div>

        <div className="rounded-2xl border border-slate-700/60 bg-slate-900/70 p-6 shadow-2xl backdrop-blur-md">
          <div className="mb-6">
            <h2 className="text-lg font-semibold text-white">Sign in</h2>
            <p className="mt-1 text-xs text-slate-400">
              Enter your admin credentials to continue
            </p>
          </div>

          <form onSubmit={handleSubmit} noValidate>
            <div className="space-y-4">
              <Input
                id="username"
                label="Username"
                type="text"
                autoComplete="username"
                autoFocus
                placeholder="Enter username"
                leftIcon={User}
                value={credentials.username}
                onChange={(e) =>
                  setCredentials((prev) => ({ ...prev, username: e.target.value }))
                }
                required
                disabled={isLoading}
              />

              <div className="flex flex-col gap-1.5">
                <label htmlFor="password" className="text-xs font-medium text-slate-300">
                  Password<span className="ml-0.5 text-red-400">*</span>
                </label>
                <div className="relative">
                  <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                    <Lock className="h-4 w-4 text-slate-400" aria-hidden="true" />
                  </div>
                  <input
                    id="password"
                    type={showPassword ? 'text' : 'password'}
                    autoComplete="current-password"
                    placeholder="Enter password"
                    className="w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 pl-9 pr-10 h-9 text-sm text-white placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-gold-500 focus:border-transparent transition-colors disabled:opacity-50"
                    value={credentials.password}
                    onChange={(e) =>
                      setCredentials((prev) => ({ ...prev, password: e.target.value }))
                    }
                    required
                    disabled={isLoading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    className="absolute inset-y-0 right-0 flex items-center pr-3 text-slate-400 hover:text-white transition-colors"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? (
                      <EyeOff className="h-4 w-4" aria-hidden="true" />
                    ) : (
                      <Eye className="h-4 w-4" aria-hidden="true" />
                    )}
                  </button>
                </div>
              </div>
            </div>

            {error && (
              <div
                role="alert"
                className="mt-4 rounded-lg border border-red-500/30 bg-red-500/10 px-3 py-2.5 text-xs text-red-400"
              >
                {error}
              </div>
            )}

            <Button
              type="submit"
              variant="primary"
              size="md"
              isLoading={isLoading}
              className="mt-5 w-full"
            >
              Sign in to portal
            </Button>
          </form>
        </div>

        <p className="mt-6 text-center text-xs text-slate-600">
          &copy; {new Date().getFullYear()} ZeParty. All rights reserved.
        </p>
      </div>
    </div>
  );
}
