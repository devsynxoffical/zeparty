import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'mini_golf_assets.dart';

/// Thin wrapper over flame_audio routed through the shared asset package.
/// Missing clips simply do not play; audio never crashes the game.
class MiniGolfAudio {
  MiniGolfAudio._();
  static final MiniGolfAudio instance = MiniGolfAudio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      for (final path in [...MiniGolfAssets.sfx.values, ...MiniGolfAssets.commonSfx.values]) {
        try {
          await FlameAudio.audioCache.load(path);
        } catch (_) {
          // Not bundled yet: skip.
        }
      }
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('MiniGolfAudio disabled: $e');
    }
  }

  void play(String key, {double volume = 1}) {
    if (!_ready) return;
    final path = MiniGolfAssets.sfx[key] ?? MiniGolfAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume * volume;
    if (vol <= 0) return;
    try {
      FlameAudio.play(path, volume: vol.clamp(0, 1)).catchError((_) => _dummy());
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
