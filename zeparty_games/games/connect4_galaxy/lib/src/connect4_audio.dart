import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'connect4_assets.dart';

/// Thin wrapper over flame_audio routed through the shared asset package.
/// Missing clips simply do not play; audio is never allowed to crash the game.
class Connect4Audio {
  Connect4Audio._();
  static final Connect4Audio instance = Connect4Audio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      // Load each clip on its own so one missing file does not disable the rest.
      for (final path in [...Connect4Assets.sfx.values, ...Connect4Assets.commonSfx.values]) {
        try {
          await FlameAudio.audioCache.load(path);
        } catch (_) {
          // Not bundled yet: skip.
        }
      }
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('Connect4Audio disabled: $e');
    }
  }

  void play(String key) {
    if (!_ready) return;
    final path = Connect4Assets.sfx[key] ?? Connect4Assets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume;
    if (vol <= 0) return;
    try {
      FlameAudio.play(path, volume: vol).catchError((_) => _dummy());
    } catch (_) {
      // ignore: audio is non-critical
    }
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }

  static AudioPlayer _dummy() => AudioPlayer();
}
