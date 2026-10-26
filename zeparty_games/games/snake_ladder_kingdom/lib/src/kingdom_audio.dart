import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'kingdom_assets.dart';

/// Thin wrapper over flame_audio. Missing clips simply do not play.
class KingdomAudio {
  KingdomAudio._();
  static final KingdomAudio instance = KingdomAudio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      // Load each clip on its own so one missing file does not disable the rest.
      for (final path in [...KingdomAssets.sfx.values, ...KingdomAssets.commonSfx.values]) {
        try {
          await FlameAudio.audioCache.load(path);
        } catch (_) {
          // Missing optional clip.
        }
      }
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('KingdomAudio disabled: $e');
    }
  }

  void play(String key) {
    if (!_ready) return;
    final path = KingdomAssets.sfx[key] ?? KingdomAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume;
    if (vol <= 0) return;
    FlameAudio.play(path, volume: vol).catchError((_) => AudioPlayer());
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }
}
