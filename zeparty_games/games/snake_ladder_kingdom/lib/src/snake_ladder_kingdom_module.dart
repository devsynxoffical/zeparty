import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'kingdom_assets.dart';
import 'snake_ladder_kingdom_screen.dart';

/// Registers Snake & Ladder Kingdom with the platform.
class SnakeLadderKingdomModule extends ZePartyGameModule {
  @override
  String get gameId => 'snake_ladder_kingdom';

  @override
  List<String> get preloadAssets => KingdomAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) => SnakeLadderKingdomScreen(session: session, channel: channel);
}
