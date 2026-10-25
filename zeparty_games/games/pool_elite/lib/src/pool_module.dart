import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'pool_assets.dart';
import 'pool_game.dart';
import 'pool_screen.dart';

/// Registers 8 Ball Pool Elite with the platform. Cosmetics are read from the
/// player's equipped inventory: `pool_elite.cue.<skin>` swaps the cue sprite and
/// `pool_elite.table.<skin>` tints the felt.
class PoolEliteModule extends ZePartyGameModule {
  @override
  String get gameId => 'pool_elite';

  @override
  List<String> get preloadAssets => PoolAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('pool_elite');
    final cosmetics = PoolCosmetics(
      cue: cueSkinFromCosmetic(equipped['cue']),
      table: tableSkinFromCosmetic(equipped['table']),
    );
    return PoolScreen(session: session, channel: channel, cosmetics: cosmetics);
  }

  /// `pool_elite.cue.ebony` -> `ebony`; anything else -> `classic`.
  static String cueSkinFromCosmetic(String? cosmeticId) => _suffix(cosmeticId) == 'ebony' ? 'ebony' : 'classic';

  /// `pool_elite.table.ruby` -> `ruby`, `pool_elite.table.midnight` -> `midnight`; anything else -> `classic`.
  static String tableSkinFromCosmetic(String? cosmeticId) {
    final s = _suffix(cosmeticId);
    return s == 'ruby' || s == 'midnight' ? s! : 'classic';
  }

  static String? _suffix(String? cosmeticId) {
    if (cosmeticId == null) return null;
    final idx = cosmeticId.lastIndexOf('.');
    return idx == -1 ? cosmeticId : cosmeticId.substring(idx + 1);
  }
}
