import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'darts_assets.dart';

/// Thin wrapper over flame_audio routed through the shared asset package.
/// Missing clips simply do not play; audio never crashes the game.
class DartsAudio {
  DartsAudio._();
  static final DartsAudio instance = DartsAudio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      for (final path in [...DartsAssets.sfx.values, ...DartsAssets.commonSfx.values]) {
        try {
          await FlameAudio.audioCache.load(path);
        } catch (_) {
          // Not bundled: skip this clip.
        }
      }
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('DartsAudio disabled: $e');
    }
  }

  void play(String key) {
    if (!_ready) return;
    final path = DartsAssets.sfx[key] ?? DartsAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume;
    if (vol <= 0) return;
    try {
      FlameAudio.play(path, volume: vol).catchError((_) => _dummy());
    } catch (_) {
      // audio is non-critical
    }
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }

  static AudioPlayer _dummy() => AudioPlayer();
}
