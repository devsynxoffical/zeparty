import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'chess_assets.dart';
import 'chess_game.dart';
import 'chess_screen.dart';

/// Registers Chess Legends with the platform. Cosmetics come from the player's
/// equipped inventory: `chess_legends.board.ivory`, `chess_legends.pieces.onyx`.
class ChessLegendsModule extends ZePartyGameModule {
  @override
  String get gameId => 'chess_legends';

  @override
  List<String> get preloadAssets => ChessAssets.preload();

  @override
  Widget buildGame(BuildContext context, GameSessionContext session, GameChannel channel) {
    final wallet = SessionScope.read(context).wallet;
    final equipped = wallet.equipped('chess_legends');
    final cosmetics = ChessCosmetics(
      board: equipped['board'] == 'chess_legends.board.ivory' ? 'ivory' : 'obsidian',
      pieces: equipped['pieces'] == 'chess_legends.pieces.onyx' ? 'onyx' : 'crystal',
    );
    return ChessScreen(session: session, channel: channel, cosmetics: cosmetics);
  }
}
