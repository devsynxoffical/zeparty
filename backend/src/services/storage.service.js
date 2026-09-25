import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import env from '../config/env.js';

/**
 * Storage Service for ZeParty Media & Asset Management.
 * Supports Local Disk Storage with CDN mapping as well as S3-compatible cloud storage.
 */
export class StorageService {
  constructor() {
    this.cdnBaseUrl = process.env.CDN_BASE_URL || `http://localhost:${env.PORT}/uploads`;
    this.storageProvider = process.env.STORAGE_PROVIDER || 'local'; // 'local', 's3', 'r2'
    this.uploadDir = path.resolve(process.cwd(), 'public', 'uploads');

    // Ensure local upload directories exist
    if (this.storageProvider === 'local') {
      const subdirs = ['avatars', 'posts', 'rooms', 'banners', 'receipts', 'assets', 'misc'];
      for (const dir of subdirs) {
        const fullPath = path.join(this.uploadDir, dir);
        if (!fs.existsSync(fullPath)) {
          fs.mkdirSync(fullPath, { recursive: true });
        }
      }
    }
  }

  /**
   * Allowed MIME types and size constraints
   */
  static ALLOWED_MIME_TYPES = {
    // Images
    'image/jpeg': { ext: 'jpg', maxBytes: 5 * 1024 * 1024 }, // 5 MB
    'image/png': { ext: 'png', maxBytes: 5 * 1024 * 1024 },
    'image/webp': { ext: 'webp', maxBytes: 5 * 1024 * 1024 },
    'image/gif': { ext: 'gif', maxBytes: 8 * 1024 * 1024 },
    // Videos
    'video/mp4': { ext: 'mp4', maxBytes: 50 * 1024 * 1024 }, // 50 MB
    'video/webm': { ext: 'webm', maxBytes: 50 * 1024 * 1024 },
    // Documents / Receipts
    'application/pdf': { ext: 'pdf', maxBytes: 10 * 1024 * 1024 },
  };

  /**
   * Validate file buffer, MIME type, and size
   */
  validateFile({ buffer, mimeType, size }) {
    const config = StorageService.ALLOWED_MIME_TYPES[mimeType];
    if (!config) {
      const error = new Error(`Unsupported file type: ${mimeType}. Allowed: JPG, PNG, WEBP, GIF, MP4, WEBM, PDF.`);
      error.status = 400;
      error.code = 'INVALID_MIME_TYPE';
      throw error;
    }

    const actualSize = size || (buffer ? buffer.length : 0);
    if (actualSize > config.maxBytes) {
      const maxMb = config.maxBytes / (1024 * 1024);
      const error = new Error(`File exceeds maximum allowed size of ${maxMb} MB for ${mimeType}.`);
      error.status = 400;
      error.code = 'FILE_TOO_LARGE';
      throw error;
    }

    return config;
  }

  /**
   * Generate secure unique storage key
   */
  generateStorageKey({ folder = 'misc', ext = 'bin', userId }) {
    const randomHex = crypto.randomBytes(16).toString('hex');
    const timestamp = Date.now();
    const cleanFolder = folder.replace(/[^a-zA-Z0-9_-]/g, '');
    const userPrefix = userId ? `u_${userId.replace(/[^a-zA-Z0-9_-]/g, '')}_` : '';
    return `${cleanFolder}/${userPrefix}${timestamp}_${randomHex}.${ext}`;
  }

  /**
   * Construct full public CDN URL from storage key
   */
  getPublicUrl(storageKey) {
    if (!storageKey) return null;
    const cleanBase = this.cdnBaseUrl.replace(/\/+$/, '');
    const cleanKey = storageKey.replace(/^\/+/, '');
    return `${cleanBase}/${cleanKey}`;
  }

  /**
   * Upload file buffer to storage
   */
  async uploadFile({ buffer, mimeType, folder = 'misc', userId }) {
    const config = this.validateFile({ buffer, mimeType });
    const storageKey = this.generateStorageKey({ folder, ext: config.ext, userId });

    // Clean up older profile/cover images for this specific user so older ones are automatically deleted
    if (userId && (folder === 'avatars' || folder === 'covers')) {
      try {
        const folderDir = path.join(this.uploadDir, folder);
        if (fs.existsSync(folderDir)) {
          const files = await fs.promises.readdir(folderDir);
          const prefix = `u_${userId.replace(/[^a-zA-Z0-9_-]/g, '')}_`;
          for (const file of files) {
            if (file.startsWith(prefix)) {
              await fs.promises.unlink(path.join(folderDir, file)).catch(() => {});
            }
          }
        }
      } catch (cleanErr) {
        console.warn('[StorageService] Cleanup of older images notice:', cleanErr.message);
      }
    }

    // Write to local disk to guarantee immediate availability
    const targetPath = path.join(this.uploadDir, storageKey);
    const targetDir = path.dirname(targetPath);
    if (!fs.existsSync(targetDir)) {
      fs.mkdirSync(targetDir, { recursive: true });
    }
    await fs.promises.writeFile(targetPath, buffer);

    // Also sync to Cloudflare R2 if configured
    if (this.storageProvider === 'r2' || this.storageProvider === 's3') {
      try {
        const s3Client = await this._getS3Client();
        if (s3Client) {
          const { PutObjectCommand, DeleteObjectCommand, ListObjectsV2Command } = await import('@aws-sdk/client-s3');
          
          // Delete old user objects from R2 if avatar or cover
          if (userId && (folder === 'avatars' || folder === 'covers')) {
            const prefix = `${folder}/u_${userId.replace(/[^a-zA-Z0-9_-]/g, '')}_`;
            const listRes = await s3Client.send(new ListObjectsV2Command({
              Bucket: process.env.S3_BUCKET_NAME || 'zeparty-media',
              Prefix: prefix,
            })).catch(() => null);

            if (listRes?.Contents?.length) {
              for (const obj of listRes.Contents) {
                if (obj.Key && obj.Key !== storageKey) {
                  await s3Client.send(new DeleteObjectCommand({
                    Bucket: process.env.S3_BUCKET_NAME || 'zeparty-media',
                    Key: obj.Key,
                  })).catch(() => {});
                }
              }
            }
          }

          await s3Client.send(new PutObjectCommand({
            Bucket: process.env.S3_BUCKET_NAME || 'zeparty-media',
            Key: storageKey,
            Body: buffer,
            ContentType: mimeType,
          }));
        }
      } catch (r2Err) {
        console.warn('[StorageService] Cloud R2 upload notice:', r2Err.message);
      }
    }

    return {
      storageKey,
      url: this.getPublicUrl(storageKey),
      cdnUrl: this.getPublicUrl(storageKey),
      mimeType,
      size: buffer.length,
      uploadedAt: new Date().toISOString(),
    };
  }

  /**
   * Generate presigned URL for direct client-to-cloud upload
   */
  async generatePresignedUploadUrl({ mimeType, folder = 'misc', userId, expiresInSeconds = 300 }) {
    const config = this.validateFile({ mimeType });
    const storageKey = this.generateStorageKey({ folder, ext: config.ext, userId });

    if (this.storageProvider === 'local') {
      // Direct backend upload endpoint URL for local/staging
      return {
        uploadUrl: `${this.cdnBaseUrl.replace('/uploads', '')}/api/v1/media/upload-direct`,
        method: 'POST',
        storageKey,
        publicUrl: this.getPublicUrl(storageKey),
        expiresInSeconds,
      };
    }

    // Cloud presigned URL generation (S3/R2)
    return {
      uploadUrl: `https://${process.env.S3_BUCKET_NAME || 'zeparty-media'}.s3.${process.env.AWS_REGION || 'us-east-1'}.amazonaws.com/${storageKey}`,
      method: 'PUT',
      headers: {
        'Content-Type': mimeType,
      },
      storageKey,
      publicUrl: this.getPublicUrl(storageKey),
      expiresInSeconds,
    };
  }

  /**
   * Delete file from storage (handles local disk and S3/R2 cloud storage)
   */
  async deleteFile(storageKeyOrUrl) {
    if (!storageKeyOrUrl || typeof storageKeyOrUrl !== 'string') return false;

    let cleanKey = storageKeyOrUrl.trim();
    if (cleanKey.includes('/uploads/')) {
      cleanKey = cleanKey.split('/uploads/')[1];
    } else if (cleanKey.startsWith('http://') || cleanKey.startsWith('https://')) {
      try {
        const u = new URL(cleanKey);
        cleanKey = u.pathname.replace(/^\/+/, '');
        if (cleanKey.includes('uploads/')) {
          cleanKey = cleanKey.split('uploads/')[1];
        }
      } catch (_) {}
    }
    cleanKey = cleanKey.replace(/^\/+/, '');

    // 1. Delete from local disk
    try {
      const targetPath = path.join(this.uploadDir, cleanKey);
      if (fs.existsSync(targetPath)) {
        await fs.promises.unlink(targetPath).catch(() => {});
      }
    } catch (localErr) {
      console.warn('[StorageService] Local file deletion notice:', localErr.message);
    }

    // 2. Delete from Cloud Storage (S3 / R2) if configured
    try {
      const s3Client = await this._getS3Client();
      if (s3Client) {
        const { DeleteObjectCommand } = await import('@aws-sdk/client-s3');
        await s3Client.send(new DeleteObjectCommand({
          Bucket: process.env.S3_BUCKET_NAME || 'zeparty-media',
          Key: cleanKey,
        })).catch(() => {});
      }
    } catch (cloudErr) {
      console.warn('[StorageService] Cloud file deletion notice:', cloudErr.message);
    }

    return true;
  }

  async _getS3Client() {
    if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
      return null;
    }
    // Dynamic import to maintain resilience
    try {
      const { S3Client } = await import('@aws-sdk/client-s3');
      // S3_ENDPOINT_URL is required for Cloudflare R2 and other S3-compatible providers
      return new S3Client({
        region: process.env.AWS_REGION || 'auto',
        ...(process.env.S3_ENDPOINT_URL && { endpoint: process.env.S3_ENDPOINT_URL }),
        forcePathStyle: false, // R2 uses virtual-hosted style (default)
        credentials: {
          accessKeyId: process.env.AWS_ACCESS_KEY_ID,
          secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        },
      });
    } catch {
      return null;
    }
  }
}

export const storageService = new StorageService();
export default storageService;
