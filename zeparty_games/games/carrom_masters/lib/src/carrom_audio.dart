import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'carrom_assets.dart';

/// Thin wrapper over flame_audio routed through the shared asset package.
/// Missing clips simply do not play; init failures disable audio entirely.
class CarromAudio {
  CarromAudio._();
  static final CarromAudio instance = CarromAudio._();
  bool _ready = false;
  bool _failed = false;
  final Map<String, double> _lastPlayed = {};

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      for (final path in [...CarromAssets.sfx.values, ...CarromAssets.commonSfx.values]) {
        try {
          await FlameAudio.audioCache.load(path);
        } catch (_) {
          // Optional clip; keep going.
        }
      }
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('CarromAudio disabled: $e');
    }
  }

  /// Play a clip. [volume] scales the user's SFX mix; [minGapMs] rate-limits a
  /// key so a flurry of collisions does not stack dozens of players.
  void play(String key, {double volume = 1, int minGapMs = 0, double? nowSeconds}) {
    if (!_ready) return;
    final path = CarromAssets.sfx[key] ?? CarromAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume * volume.clamp(0.0, 1.0);
    if (vol <= 0.01) return;
    if (minGapMs > 0) {
      final now = nowSeconds ?? DateTime.now().millisecondsSinceEpoch / 1000;
      final last = _lastPlayed[key];
      if (last != null && (now - last) * 1000 < minGapMs) return;
      _lastPlayed[key] = now;
    }
    FlameAudio.play(path, volume: vol).catchError((_) => AudioPlayer());
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }
}
