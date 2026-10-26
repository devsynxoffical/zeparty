import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'connect4_assets.dart';
import 'connect4_game.dart';
import 'connect4_screen.dart';

/// Registers Connect 4 Galaxy with the platform. The disc skin is read from
/// the player's equipped inventory (`connect4_galaxy.disc.<skin>`).
class Connect4GalaxyModule extends ZePartyGameModule {
  Connect4GalaxyModule({this.confirmDrop = true});

  /// Two-tap drop (preview then confirm). The host may expose this as a setting.
  final bool confirmDrop;

  @override
  String get gameId => 'connect4_galaxy';

  @override
  List<String> get preloadAssets => Connect4Assets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('connect4_galaxy');
    final cosmetics = Connect4Cosmetics(discSkin: discSkinFromCosmetic(equipped['disc']), confirmDrop: confirmDrop);
    return Connect4Screen(session: session, channel: channel, cosmetics: cosmetics);
  }

  /// `connect4_galaxy.disc.plasma` -> `plasma`; anything else -> `classic`.
  static String discSkinFromCosmetic(String? cosmeticId) {
    if (cosmeticId == null) return 'classic';
    final idx = cosmeticId.lastIndexOf('.');
    final suffix = idx == -1 ? cosmeticId : cosmeticId.substring(idx + 1);
    return suffix == 'plasma' ? 'plasma' : 'classic';
  }
}
