import 'package:flutter/widgets.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'ludo_game.dart';
import 'ludo_screen.dart';

/// Registers Ludo Royale with the platform. Cosmetics are read from the
/// player's equipped inventory (board / dice / token categories).
class LudoRoyaleModule extends ZePartyGameModule {
  @override
  String get gameId => 'ludo_royale';

  @override
  List<String> get preloadAssets => LudoAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('ludo_royale');
    final cosmetics = LudoCosmetics(
      board: _suffix(equipped['board'], fallback: 'imperial_palace'),
      tokens: equipped['token'] == 'ludo_royale.token.crown' ? 'crown' : 'classic',
      dice: _suffix(equipped['dice'], fallback: 'crystal'),
    );
    return LudoScreen(session: session, channel: channel, cosmetics: cosmetics);
  }

  static String _suffix(String? cosmeticId, {required String fallback}) {
    if (cosmeticId == null) return fallback;
    final idx = cosmeticId.lastIndexOf('.');
    return idx == -1 ? fallback : cosmeticId.substring(idx + 1);
  }
}
