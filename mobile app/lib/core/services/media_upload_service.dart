import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class MediaUploadResult {
  final String url;
  final String storageKey;
  final String mimeType;
  final int size;

  const MediaUploadResult({
    required this.url,
    required this.storageKey,
    required this.mimeType,
    required this.size,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      url: json['url']?.toString() ?? json['cdnUrl']?.toString() ?? json['publicUrl']?.toString() ?? '',
      storageKey: json['storageKey']?.toString() ?? json['key']?.toString() ?? '',
      mimeType: json['mimeType']?.toString() ?? '',
      size: json['size'] is int ? json['size'] as int : 0,
    );
  }
}

class MediaUploadService {
  static final MediaUploadService instance = MediaUploadService._internal();
  final ApiClient _apiClient = ApiClient.instance;

  MediaUploadService._internal();

  /// Uploads a local file (photo or video) to Cloudflare R2 through backend
  /// [filePath]: Local device path
  /// [folder]: Target storage bucket folder ('avatars', 'posts', 'videos', 'banners')
  Future<MediaUploadResult> uploadFile({
    required String filePath,
    String folder = 'misc',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ApiException(message: 'Selected media file does not exist on device.');
    }

    final bytes = await file.readAsBytes();
    final mimeType = _inferMimeType(filePath);
    final base64Data = base64Encode(bytes);

    try {
      final response = await _apiClient.post(
        '/v1/media/upload',
        data: {
          'folder': folder,
          'mimeType': mimeType,
          'dataBase64': 'data:$mimeType;base64,$base64Data',
        },
      );

      final responseData = response.data;
      if (responseData == null || responseData['success'] != true) {
        throw ApiException(
          message: responseData?['message']?.toString() ?? 'Media upload failed on server.',
        );
      }

      final data = responseData['data'] as Map<String, dynamic>;
      return MediaUploadResult.fromJson(data);
    } catch (e) {
      debugPrint('[MediaUploadService] Error uploading file: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to upload media: $e');
    }
  }

  String _inferMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'application/octet-stream';
  }
}
