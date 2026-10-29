import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MIME_TYPES = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.mp3': 'audio/mpeg',
  '.m4a': 'audio/mp4',
  '.wav': 'audio/wav',
  '.svga': 'application/octet-stream',
};

function staticAssetsMiddleware(prefix, targetDir) {
  return (req, res, next) => {
    if (!req.url.startsWith(prefix)) return next();
    const rawPath = req.url.slice(prefix.length).split('?')[0];
    const decodedPath = decodeURIComponent(rawPath).replace(/^\/+/, '');
    const safePath = path.normalize(decodedPath).replace(/^(\.\.(\/|\\|$))+/, '');
    const fullPath = path.join(targetDir, safePath);

    // Cross-platform directory containment check (case-insensitive for Windows drive letters)
    const rel = path.relative(targetDir, fullPath);
    if (rel.startsWith('..') || path.isAbsolute(rel)) {
      return next();
    }

    if (fs.existsSync(fullPath) && fs.statSync(fullPath).isFile()) {
      const ext = path.extname(fullPath).toLowerCase();
      const contentType = MIME_TYPES[ext] || 'application/octet-stream';
      res.setHeader('Content-Type', contentType);
      res.setHeader('Cache-Control', 'public, max-age=604800, immutable');
      res.setHeader('Access-Control-Allow-Origin', '*');
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      return fs.createReadStream(fullPath).pipe(res);
    }

    // Resilient fallback: redirect to canonical CDN if local file is missing
    const cleanRel = safePath.replace(/\\/g, '/');
    const remoteUrl = `https://raw.githubusercontent.com/devsynxoffical/zeparty/main/mobile%20app/assets/${encodeURI(cleanRel)}`;
    res.writeHead(302, {
      'Location': remoteUrl,
      'Access-Control-Allow-Origin': '*',
      'Cross-Origin-Resource-Policy': 'cross-origin'
    });
    return res.end();
  };
}

function mobileAssetsPlugin() {
  const assetsDir = path.resolve(__dirname, '../mobile app/assets');
  const uploadsDir = path.resolve(__dirname, '../backend/public/uploads');

  return {
    name: 'mobile-assets-plugin',
    configureServer(server) {
      server.middlewares.use(staticAssetsMiddleware('/assets', assetsDir));
      server.middlewares.use(staticAssetsMiddleware('/uploads', uploadsDir));
    },
    configurePreviewServer(server) {
      server.middlewares.use(staticAssetsMiddleware('/assets', assetsDir));
      server.middlewares.use(staticAssetsMiddleware('/uploads', uploadsDir));
    },
  };
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), mobileAssetsPlugin()],
  server: {
    port: 5173,
    fs: {
      allow: ['..'],
    },
    proxy: {
      '/api': {
        target: process.env.VITE_BACKEND_URL || 'http://localhost:5000',
        changeOrigin: true,
        secure: false,
      },
    },
  },
});

