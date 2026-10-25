import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'mini_golf_assets.dart';
import 'mini_golf_game.dart';
import 'mini_golf_screen.dart';

/// Registers Mini Golf Paradise with the platform. The equipped `ball` cosmetic
/// (`mini_golf_paradise.ball.gold`) swaps the local player's ball sprite.
class MiniGolfParadiseModule extends ZePartyGameModule {
  @override
  String get gameId => 'mini_golf_paradise';

  @override
  List<String> get preloadAssets => MiniGolfAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('mini_golf_paradise');
    final cosmetics = MiniGolfCosmetics(ballSkin: equipped['ball'] == 'mini_golf_paradise.ball.gold' ? 'gold' : 'white');
    return MiniGolfScreen(session: session, channel: channel, cosmetics: cosmetics);
  }
}
