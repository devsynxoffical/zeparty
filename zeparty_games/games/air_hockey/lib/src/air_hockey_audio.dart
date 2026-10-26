import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'air_hockey_assets.dart';

/// Thin wrapper over flame_audio routed through the shared asset package.
/// Missing files or platforms without audio simply stay silent.
class AirHockeyAudio {
  AirHockeyAudio._();
  static final AirHockeyAudio instance = AirHockeyAudio._();
  bool _ready = false;
  bool _failed = false;
  double _lastHitAt = -1;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      await FlameAudio.audioCache.loadAll([...AirHockeyAssets.sfx.values, ...AirHockeyAssets.commonSfx.values]);
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('AirHockeyAudio disabled: $e');
    }
  }

  /// [volumeScale] lets fast hits sound louder than taps. [clock] throttles
  /// rapid repeats (seconds, any monotonic source).
  void play(String key, {double volumeScale = 1, double? clock}) {
    if (!_ready) return;
    if (clock != null && (key == 'hit' || key == 'wall')) {
      if (clock - _lastHitAt < 0.04) return;
      _lastHitAt = clock;
    }
    final path = AirHockeyAssets.sfx[key] ?? AirHockeyAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume * volumeScale.clamp(0.0, 1.0);
    if (vol <= 0) return;
    FlameAudio.play(path, volume: vol).catchError((_) => _dummy());
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }

  static AudioPlayer _dummy() => AudioPlayer();
}
