import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'darts_assets.dart';
import 'darts_game.dart';
import 'darts_screen.dart';

/// Registers Darts Arena with the platform. The dart skin is read from the
/// player's equipped inventory (`darts_arena.dart.gold` swaps the sprite).
class DartsArenaModule extends ZePartyGameModule {
  @override
  String get gameId => 'darts_arena';

  @override
  List<String> get preloadAssets => DartsAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('darts_arena');
    final cosmetics = DartsCosmetics(dartSkin: dartSkinFromCosmetic(equipped['dart']));
    return DartsScreen(session: session, channel: channel, cosmetics: cosmetics);
  }

  /// `darts_arena.dart.gold` -> `gold`; anything else -> `steel`.
  static String dartSkinFromCosmetic(String? cosmeticId) {
    if (cosmeticId == null) return 'steel';
    final idx = cosmeticId.lastIndexOf('.');
    final suffix = idx == -1 ? cosmeticId : cosmeticId.substring(idx + 1);
    return suffix == 'gold' ? 'gold' : 'steel';
  }
}
