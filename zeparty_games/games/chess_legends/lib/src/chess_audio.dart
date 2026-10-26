import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'chess_assets.dart';

/// Thin wrapper over flame_audio routed through the shared asset package.
/// Missing clips simply do not play.
class ChessAudio {
  ChessAudio._();
  static final ChessAudio instance = ChessAudio._();
  bool _ready = false;
  bool _failed = false;

  Future<void> init() async {
    if (_ready || _failed) return;
    try {
      FlameAudio.audioCache = AudioCache(prefix: 'packages/$kAssetPackage/assets/');
      await FlameAudio.audioCache.loadAll([...ChessAssets.sfx.values, ...ChessAssets.commonSfx.values]);
      _ready = true;
    } catch (e) {
      _failed = true;
      debugPrint('ChessAudio disabled: $e');
    }
  }

  void play(String key) {
    if (!_ready) return;
    final path = ChessAssets.sfx[key] ?? ChessAssets.commonSfx[key];
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
