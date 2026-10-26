/// Asset access for ZeParty games. All paths are relative to the shared
/// `assets/` root and resolved through this package so the host app does not
/// have to re-declare them.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

const String kAssetPackage = 'zeparty_game_assets';

/// Resolve a logical asset path (e.g. `games/ludo_royale/tokens/token_red.webp`)
/// to the bundled key, picking the @1x or @2x tier from graphics quality.
class ZpAssets {
  ZpAssets._();

  static String key(String logical, {GraphicsQuality? quality}) {
    final q = quality ?? GraphicsSettings.instance.current;
    final dot = logical.lastIndexOf('.');
    final tiered = dot == -1 ? logical : '${logical.substring(0, dot)}${q.textureSuffix}${logical.substring(dot)}';
    return 'packages/$kAssetPackage/assets/$tiered';
  }

  /// Key without tier suffix for assets that have a single variant (audio, manifest).
  static String flat(String logical) => 'packages/$kAssetPackage/assets/$logical';

  /// Audio key relative to the package `assets/` root, for flame_audio's prefix.
  static String audio(String logical) => 'packages/$kAssetPackage/assets/$logical';

  static ImageProvider image(String logical, {GraphicsQuality? quality}) => AssetImage(key(logical, quality: quality));

  static Future<ui.Image> loadUiImage(String logical, {GraphicsQuality? quality}) async {
    final data = await rootBundle.load(key(logical, quality: quality));
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<List<AssetManifestEntry>> manifest() async {
    final raw = await rootBundle.loadString(flat('manifest.json'));
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => AssetManifestEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Warm the image cache for a list of logical paths (used by the loading screen).
  static Future<void> precache(BuildContext context, List<String> logicals, {void Function(int done, int total)? onProgress}) async {
    var done = 0;
    for (final l in logicals) {
      if (!context.mounted) return;
      await precacheImage(image(l), context);
      done++;
      onProgress?.call(done, logicals.length);
    }
  }
}

class AssetManifestEntry {
  const AssetManifestEntry({required this.file, required this.game, required this.description, required this.resolution, required this.format, required this.use, required this.source, required this.license, this.frames});
  final String file;
  final String game;
  final String description;
  final String resolution;
  final String format;
  final String use;
  final String source;
  final String license;
  final int? frames;
  factory AssetManifestEntry.fromJson(Map<String, dynamic> j) => AssetManifestEntry(
        file: j['file'] as String,
        game: j['game'] as String,
        description: j['description'] as String,
        resolution: j['resolution'] as String,
        format: j['format'] as String,
        use: j['use'] as String,
        source: j['source'] as String,
        license: j['license'] as String,
        frames: j['frames'] as int?,
      );
}

/// Logical asset paths for Ludo Royale, kept in one place so tests can verify
/// every referenced file exists in the bundle.
class LudoAssets {
  LudoAssets._();
  static const backgrounds = {
    'imperial_palace': 'games/ludo_royale/backgrounds/chamber_imperial_palace.webp',
    'crystal_kingdom': 'games/ludo_royale/backgrounds/chamber_crystal_kingdom.webp',
    'midnight_gold': 'games/ludo_royale/backgrounds/chamber_midnight_gold.webp',
  };
  static const surfaces = {
    'imperial_palace': 'games/ludo_royale/boards/tex_marble_ivory.webp',
    'crystal_kingdom': 'games/ludo_royale/boards/tex_crystal_ice.webp',
    'midnight_gold': 'games/ludo_royale/boards/tex_marble_obsidian.webp',
  };
  static const goldTrim = 'games/ludo_royale/boards/tex_gold_filigree.webp';
  static const centerCrest = 'games/ludo_royale/boards/center_crest.webp';
  static const safeStar = 'games/ludo_royale/boards/safe_star.webp';
  static const victoryCrown = 'games/ludo_royale/effects/victory_crown.webp';
  static const cardArt = 'games/ludo_royale/ui/card_art.webp';
  static String token(String skin, String color) => skin == 'crown' ? 'games/ludo_royale/tokens/token_crown_$color.webp' : 'games/ludo_royale/tokens/token_$color.webp';
  static String dice(String skin, int face) => 'games/ludo_royale/dice/dice_${skin}_$face.webp';
  static const particles = 'common/particles/particles_sheet.webp';
  static const coin = 'common/icons/coin.webp';

  static const sfx = {
    'dice_roll': 'games/ludo_royale/audio/dice_roll.mp3',
    'token_place': 'games/ludo_royale/audio/token_place.mp3',
    'capture': 'games/ludo_royale/audio/capture.mp3',
    'token_home': 'games/ludo_royale/audio/token_home.mp3',
    'extra_turn': 'games/ludo_royale/audio/extra_turn.mp3',
    'turn_change': 'games/ludo_royale/audio/turn_change.mp3',
    'illegal_move': 'games/ludo_royale/audio/illegal_move.mp3',
    'victory_fanfare': 'games/ludo_royale/audio/victory_fanfare.mp3',
    'match_start': 'games/ludo_royale/audio/match_start.mp3',
    'timer_tick': 'games/ludo_royale/audio/timer_tick.mp3',
  };
  static const commonSfx = {
    'ui_tap': 'common/audio/ui_tap.mp3',
    'coins_award': 'common/audio/coins_award.mp3',
  };
  static const lobbyMusic = 'common/audio/lobby_ambience.mp3';

  /// Everything the game screen needs before first frame for a given skin.
  static List<String> preload({String board = 'imperial_palace', String tokenSkin = 'classic', String diceSkin = 'crystal'}) => [
        backgrounds[board]!,
        surfaces[board]!,
        goldTrim,
        centerCrest,
        safeStar,
        victoryCrown,
        particles,
        coin,
        for (final c in ['red', 'green', 'yellow', 'blue']) token(tokenSkin, c),
        for (var i = 1; i <= 6; i++) dice(diceSkin, i),
      ];
}
