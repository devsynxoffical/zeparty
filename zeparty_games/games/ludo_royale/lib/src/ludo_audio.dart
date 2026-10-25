import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Thin wrapper over flame_audio that routes every clip through the shared
/// asset package and honours the user's mix and the voice-ducking rule.
class LudoAudio {
  LudoAudio._();
  static final LudoAudio instance = LudoAudio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      await FlameAudio.audioCache.loadAll([...LudoAssets.sfx.values, ...LudoAssets.commonSfx.values]);
      _ready = true;
    } catch (e) {
      // Audio is non-critical (e.g. tests, web without user gesture).
      _failed = true;
      debugPrint('LudoAudio disabled: $e');
    }
  }

  void play(String key) {
    if (!_ready) return;
    final path = LudoAssets.sfx[key] ?? LudoAssets.commonSfx[key];
    if (path == null) return;
    final vol = AudioSettings.instance.sfxVolume;
    if (vol <= 0) return;
    FlameAudio.play(path, volume: vol).catchError((_) => _dummy());
  }

  void dispose() {
    if (_ready) FlameAudio.audioCache.clearAll();
    _ready = false;
  }

  static AudioPlayer _dummy() => AudioPlayer();
}
