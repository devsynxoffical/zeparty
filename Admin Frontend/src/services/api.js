// ============================================================
// ZeParty Admin Portal — Axios API Client (JavaScript)
// ============================================================
// Base URL is configured via environment variable VITE_API_BASE_URL.
// Do NOT hardcode a production URL here.
// ============================================================

import axios from 'axios';

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || 'https://zeparty-backend-production.up.railway.app/api',
  timeout: 60000, // 60 seconds timeout to prevent premature timeout errors
  headers: {
    'Content-Type': 'application/json',
  },
});

let isRefreshing = false;
let failedQueue = [];

const processQueue = (error, token = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });
  failedQueue = [];
};

let refreshPromise = null;

const isTokenValid = (token) => {
  if (!token || typeof token !== 'string') return false;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return false;
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    if (payload.exp) {
      return payload.exp * 1000 > Date.now() + 5000;
    }
    return true;
  } catch {
    return false;
  }
};

const getValidAccessToken = async () => {
  const token = localStorage.getItem('zeparty_admin_token');
  const rawSession = localStorage.getItem('zeparty_admin_session');

  if (token && isTokenValid(token)) {
    return token;
  }

  let refreshToken = null;
  try {
    if (rawSession) {
      const session = JSON.parse(rawSession);
      refreshToken = session?.refreshToken;
    }
  } catch { }

  if (!refreshToken) {
    if (token) {
      localStorage.removeItem('zeparty_admin_token');
      localStorage.removeItem('zeparty_admin_session');
    }
    return null;
  }

  if (!refreshPromise) {
    refreshPromise = axios
      .post(
        `${apiClient.defaults.baseURL}/v1/auth/refresh`,
        { refreshToken },
        { headers: { 'Content-Type': 'application/json' } }
      )
      .then((res) => {
        if (res.data?.success && res.data.data?.accessToken) {
          const newAccessToken = res.data.data.accessToken;
          const newRefreshToken = res.data.data.refreshToken || refreshToken;

          localStorage.setItem('zeparty_admin_token', newAccessToken);
          if (rawSession) {
            try {
              const session = JSON.parse(rawSession);
              session.token = newAccessToken;
              session.refreshToken = newRefreshToken;
              session.expiresAt = res.data.data.expiresAt || session.expiresAt;
              localStorage.setItem('zeparty_admin_session', JSON.stringify(session));
            } catch { }
          }
          return newAccessToken;
        }
        throw new Error('Token refresh failed');
      })
      .catch((err) => {
        localStorage.removeItem('zeparty_admin_token');
        localStorage.removeItem('zeparty_admin_session');
        if (window.location.pathname !== '/admin/login') {
          window.location.href = '/admin/login';
        }
        return null;
      })
      .finally(() => {
        refreshPromise = null;
      });
  }

  return refreshPromise;
};

// ---- Request interceptor — attach fresh auth token ----
apiClient.interceptors.request.use(
  async (config) => {
    if (config.url?.includes('/auth/admin/login') || config.url?.includes('/auth/refresh') || config.url?.includes('/auth/logout')) {
      const token = localStorage.getItem('zeparty_admin_token');
      if (token && !config.headers.Authorization) {
        config.headers.Authorization = `Bearer ${token}`;
      }
      return config;
    }

    const token = await getValidAccessToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// ---- Response interceptor — handle token refresh and errors ----
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    // Only attempt refresh on 401 and when not already retrying or logging in / logging out
    if (
      error.response?.status === 401 &&
      originalRequest &&
      !originalRequest._retry &&
      !originalRequest.url?.includes('/auth/admin/login') &&
      !originalRequest.url?.includes('/auth/refresh') &&
      !originalRequest.url?.includes('/auth/logout')
    ) {
      const rawSession = localStorage.getItem('zeparty_admin_session');
      let refreshToken = null;
      try {
        if (rawSession) {
          const session = JSON.parse(rawSession);
          refreshToken = session?.refreshToken;
        }
      } catch {
        refreshToken = null;
      }

      if (!refreshToken) {
        localStorage.removeItem('zeparty_admin_token');
        localStorage.removeItem('zeparty_admin_session');
        if (window.location.pathname !== '/admin/login') {
          window.location.href = '/admin/login';
        }
        return Promise.reject(error);
      }

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            originalRequest._retry = true;
            originalRequest.headers.Authorization = `Bearer ${token}`;
            return apiClient(originalRequest);
          })
          .catch((err) => Promise.reject(err));
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshResponse = await axios.post(
          `${apiClient.defaults.baseURL}/v1/auth/refresh`,
          { refreshToken },
          { headers: { 'Content-Type': 'application/json' } }
        );

        if (refreshResponse.data?.success && refreshResponse.data.data?.accessToken) {
          const newAccessToken = refreshResponse.data.data.accessToken;
          const newRefreshToken = refreshResponse.data.data.refreshToken || refreshToken;

          localStorage.setItem('zeparty_admin_token', newAccessToken);
          if (rawSession) {
            try {
              const session = JSON.parse(rawSession);
              session.token = newAccessToken;
              session.refreshToken = newRefreshToken;
              session.expiresAt = refreshResponse.data.data.expiresAt || session.expiresAt;
              localStorage.setItem('zeparty_admin_session', JSON.stringify(session));
            } catch { }
          }

          processQueue(null, newAccessToken);
          originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
          return apiClient(originalRequest);
        } else {
          throw new Error('Refresh token invalid');
        }
      } catch (refreshError) {
        processQueue(refreshError, null);
        localStorage.removeItem('zeparty_admin_token');
        localStorage.removeItem('zeparty_admin_session');
        if (window.location.pathname !== '/admin/login') {
          window.location.href = '/admin/login';
        }
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);

export default apiClient;

