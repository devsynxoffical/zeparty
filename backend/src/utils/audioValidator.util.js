import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

/**
 * Validates MP3 buffer by checking ID3 tag or MPEG audio sync frames.
 */
export function validateMp3Buffer(buffer) {
  if (!buffer || !Buffer.isBuffer(buffer)) {
    throw new Error('Invalid audio buffer provided.');
  }

  if (buffer.length < 128) {
    throw new Error('Audio file is too small or corrupt.');
  }

  // 1. Check ID3v2 tag (bytes 0..2 = 'ID3')
  if (buffer[0] === 0x49 && buffer[1] === 0x44 && buffer[2] === 0x33) {
    return { isValid: true, type: 'mp3', detectedType: 'mp3', mimeType: 'audio/mpeg', format: 'ID3v2' };
  }

  // 2. Check for MPEG audio frame sync: 11 bits set (0xFF, then top 3 bits of next byte = 0xE0)
  // Scans up to first 16KB for frame header
  const maxScan = Math.min(buffer.length - 4, 16384);
  for (let i = 0; i < maxScan; i++) {
    if (buffer[i] === 0xFF && (buffer[i + 1] & 0xE0) === 0xE0) {
      const layerBits = (buffer[i + 1] >> 1) & 0x03;
      const sampleRateBits = (buffer[i + 2] >> 2) & 0x03;
      // Valid MPEG Layer (1, 2, or 3) and valid sample rate (not 3)
      if (layerBits !== 0 && sampleRateBits !== 3) {
        return { isValid: true, type: 'mp3', detectedType: 'mp3', mimeType: 'audio/mpeg', format: 'MPEG-Frame' };
      }
    }
  }

  // 3. Check ID3v1 tag at end of file (last 128 bytes start with 'TAG')
  if (buffer.length >= 128) {
    const endTag = buffer.slice(buffer.length - 128, buffer.length - 125).toString('ascii');
    if (endTag === 'TAG') {
      return { isValid: true, type: 'mp3', detectedType: 'mp3', mimeType: 'audio/mpeg', format: 'ID3v1' };
    }
  }

  throw new Error('Corrupt or invalid MP3 file. Valid audio header not found.');
}

/**
 * Validates WAV audio buffer (RIFF...WAVE).
 */
export function validateWavBuffer(buffer) {
  if (!buffer || buffer.length < 44) {
    throw new Error('Audio file is too small or corrupt.');
  }
  const riff = buffer.slice(0, 4).toString('ascii');
  const wave = buffer.slice(8, 12).toString('ascii');
  if (riff === 'RIFF' && wave === 'WAVE') {
    return { isValid: true, type: 'wav', detectedType: 'wav', mimeType: 'audio/wav', format: 'RIFF-WAVE' };
  }
  throw new Error('Corrupt or invalid WAV audio file.');
}

/**
 * Validates an MP4 file buffer and verifies whether it contains an audio track.
 * Parses ISOBMFF atoms/boxes for 'soun', 'smhd', or 'mp4a'.
 */
export function validateMp4Audio(buffer) {
  if (!buffer || !Buffer.isBuffer(buffer)) {
    throw new Error('Invalid media buffer provided.');
  }

  if (buffer.length < 32) {
    throw new Error('Media file is too small or corrupt.');
  }

  // Check ISOBMFF signature (ftyp box)
  let hasFtyp = false;
  let offset = 0;
  while (offset + 8 <= Math.min(buffer.length, 1024)) {
    const boxSize = buffer.readUInt32BE(offset);
    const boxType = buffer.toString('ascii', offset + 4, offset + 8);
    if (boxType === 'ftyp' || boxType === 'moov') {
      hasFtyp = true;
      break;
    }
    if (boxSize === 0 || boxSize > buffer.length) break;
    offset += boxSize;
  }

  if (!hasFtyp) {
    // If not standard atom, check if string representation has ftyp/moov
    const head = buffer.slice(0, 64).toString('latin1');
    if (!head.includes('ftyp') && !head.includes('moov')) {
      throw new Error('Invalid MP4 container. Missing ISO media file signature.');
    }
  }

  // Scan entire buffer for sound track indicators ('soun', 'smhd', 'mp4a')
  // In ISOBMFF:
  // - 'soun' is the media handler type in mdia/hdlr for audio
  // - 'smhd' is the sound media header in mdia/minf
  // - 'mp4a' is the audio sample description format
  const latin1 = buffer.toString('latin1');
  const hasSoundHandler = latin1.includes('soun');
  const hasSoundHeader = latin1.includes('smhd');
  const hasMp4a = latin1.includes('mp4a');

  if (!hasSoundHandler && !hasSoundHeader && !hasMp4a) {
    const error = new Error('The uploaded MP4 file does not contain a usable audio track.');
    error.statusCode = 400;
    error.code = 'NO_AUDIO_TRACK';
    throw error;
  }

  return {
    isValid: true,
    hasAudio: true,
    format: 'MP4-Audio',
    type: 'mp4',
    detectedType: 'mp4',
    mimeType: 'audio/mp4',
  };
}

/**
 * Universal audio validator for MP3, WAV, and MP4.
 */
export function validateAudioUpload({ buffer, fileName = '', mimeType = '' }) {
  if (!buffer || buffer.length === 0) {
    throw new Error('No audio file data provided.');
  }

  // Max size: 25 MB for audio
  const MAX_AUDIO_BYTES = 25 * 1024 * 1024;
  if (buffer.length > MAX_AUDIO_BYTES) {
    throw new Error('Audio file exceeds the maximum allowed limit of 25 MB.');
  }

  const ext = (path.extname(fileName) || '').toLowerCase().replace('.', '');
  const mime = (mimeType || '').toLowerCase();

  // 1. WAV file
  if (ext === 'wav' || mime.includes('wav')) {
    return validateWavBuffer(buffer);
  }

  // 2. MP3 file
  if (ext === 'mp3' || mime.includes('mpeg') || mime.includes('mp3')) {
    return validateMp3Buffer(buffer);
  }

  // 3. MP4 container
  if (ext === 'mp4' || ext === 'm4a' || mime.includes('mp4')) {
    return validateMp4Audio(buffer);
  }

  // 4. Try auto-detecting by content if extension is ambiguous
  try {
    return validateMp3Buffer(buffer);
  } catch (_) {
    try {
      return validateWavBuffer(buffer);
    } catch (__) {
      try {
        return validateMp4Audio(buffer);
      } catch (___) {
        throw new Error('Unsupported audio format. Only MP3 and MP4 files with a usable audio track are supported.');
      }
    }
  }
}
