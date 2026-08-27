// ============================================================
// ZeParty Admin Portal — Axios API Client (JavaScript)
// ============================================================
// Base URL is configured via environment variable VITE_API_BASE_URL.
// Do NOT hardcode a production URL here.
// ============================================================

import axios from 'axios';

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// ---- Request interceptor — attach auth token ----
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('zeparty_admin_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// ---- Response interceptor — handle global errors ----
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid — clear session and redirect
      localStorage.removeItem('zeparty_admin_token');
      localStorage.removeItem('zeparty_admin_session');
      window.location.href = '/admin/login';
    }
    return Promise.reject(error);
  }
);

export default apiClient;
