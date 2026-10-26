import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'pool_assets.dart';

/// Thin wrapper over flame_audio that routes every clip through the shared
/// asset package and honours the user's mix. Missing files simply do not play.
class PoolAudio {
  PoolAudio._();
  static final PoolAudio instance = PoolAudio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      await FlameAudio.audioCache.loadAll([...PoolAssets.sfx.values, ...PoolAssets.commonSfx.values]);
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('PoolAudio disabled: $e');
    }
  }

  /// [intensity] 0..1 scales the volume (collision speed).
  void play(String key, {double intensity = 1}) {
    if (!_ready) return;
    final path = PoolAssets.sfx[key] ?? PoolAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume * intensity.clamp(0.15, 1.0);
    if (vol <= 0) return;
    FlameAudio.play(path, volume: vol).catchError((_) => _dummy());
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }

  static AudioPlayer _dummy() => AudioPlayer();
}
