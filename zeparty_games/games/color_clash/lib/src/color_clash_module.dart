import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'color_clash_assets.dart';
import 'color_clash_screen.dart';

/// Registers Color Clash with the platform.
class ColorClashModule extends ZePartyGameModule {
  @override
  String get gameId => 'color_clash';

  @override
  List<String> get preloadAssets => ColorClashAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    return ColorClashScreen(session: session, channel: channel);
  }
}
