import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'carrom_assets.dart';
import 'carrom_game.dart';
import 'carrom_screen.dart';

/// Registers Carrom Masters with the platform. The striker skin is read from
/// the player's equipped inventory (`carrom_masters.striker.gold`).
class CarromMastersModule extends ZePartyGameModule {
  @override
  String get gameId => 'carrom_masters';

  @override
  List<String> get preloadAssets => CarromAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('carrom_masters');
    final cosmetics = CarromCosmetics(strikerSkin: strikerSkinFromCosmetic(equipped['striker']));
    return CarromScreen(session: session, channel: channel, cosmetics: cosmetics);
  }

  /// `carrom_masters.striker.gold` -> `gold`; anything else -> `classic`.
  static String strikerSkinFromCosmetic(String? cosmeticId) {
    if (cosmeticId == null) return 'classic';
    final idx = cosmeticId.lastIndexOf('.');
    final suffix = idx == -1 ? cosmeticId : cosmeticId.substring(idx + 1);
    return suffix == 'gold' ? 'gold' : 'classic';
  }
}
