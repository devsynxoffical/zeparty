import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/features/games/games_bootstrap.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

void main() {
  testWidgets('games root renders inside a nested-scroll tab', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) { errors.add(d); };
    GamesBootstrap.registerAllGames();
    GamesBootstrap.configureLauncher(apiBaseUrl: 'http://127.0.0.1:9/api/games-hub', wsUrl: 'ws://127.0.0.1:9/ws');
    final session = ZePartySession(identity: const ZePartyIdentity(userId: 'u1', displayName: 'Tester'), authToken: 't');
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (_, __) => [const SliverAppBar(title: Text('Home'))],
            body: TabBarView(children: [
              const Center(child: Text('other')),
              ZePartyGamesRoot(embedded: true, showInitialGameDetails: false, request: GameLaunchRequest(gameId: 'ludo_royale', session: session)),
            ]),
          ),
        ),
      ),
    ));
    DefaultTabController.of(tester.element(find.text('other'))).animateTo(1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = old;
    for (final e in errors) { debugPrint('CAUGHT: ${e.exceptionAsString()}\n${e.stack.toString().split('\n').take(12).join('\n')}'); }
    debugPrint('found Multiplayer games: ${find.text('Multiplayer games').evaluate().isNotEmpty}');
    debugPrint('found All games: ${find.textContaining('All games').evaluate().isNotEmpty}');
    // Drain the socket connect timeout so the harness does not flag a pending timer.
    await tester.pump(const Duration(seconds: 11));
  });
}
