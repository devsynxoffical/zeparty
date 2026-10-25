import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'air_hockey_assets.dart';
import 'air_hockey_screen.dart';

/// Registers Neon Air Hockey with the platform.
class AirHockeyModule extends ZePartyGameModule {
  @override
  String get gameId => 'air_hockey';

  @override
  List<String> get preloadAssets => AirHockeyAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) => AirHockeyScreen(session: session, channel: channel);
}
