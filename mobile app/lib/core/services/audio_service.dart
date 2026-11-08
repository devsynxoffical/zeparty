import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _giftPlayer;

  Future<void> playGiftSound(String? soundSource) async {
    if (soundSource == null || soundSource.trim().isEmpty) return;

    try {
      _giftPlayer ??= AudioPlayer();
      await _giftPlayer?.stop();

      final source = soundSource.trim();
      if (source.startsWith('http://') || source.startsWith('https://')) {
        await _giftPlayer?.play(UrlSource(source));
      } else {
        // Local asset
        final assetPath = source.startsWith('assets/')
            ? source.replaceFirst('assets/', '')
            : source;
        await _giftPlayer?.play(AssetSource(assetPath));
      }
    } catch (e) {
      debugPrint('[AudioService] Could not play gift audio ($soundSource): $e');
    }
  }

  void stopAll() {
    try {
      _giftPlayer?.stop();
    } catch (_) {}
  }

  void dispose() {
    try {
      _giftPlayer?.dispose();
      _giftPlayer = null;
    } catch (_) {}
  }
}

