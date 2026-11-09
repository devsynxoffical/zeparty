import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/core/config/app_config.dart';
import 'package:zeparty/features/games/game_lobby_screen.dart';
import 'package:zeparty/features/games/games_bootstrap.dart';
import 'package:zeparty/providers/auth_provider.dart';

void main() {
  testWidgets('GameLobbyScreen full path renders', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) { errors.add(d.exceptionAsString()); };
    AppConfig.initialize(customBaseUrl: 'http://127.0.0.1:9/api');
    GamesBootstrap.initialize();
    final auth = AuthProvider();
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider<AuthProvider>.value(value: auth)],
      child: const MaterialApp(home: Scaffold(body: GameLobbyScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 2));
    FlutterError.onError = old;
    for (final e in errors) { debugPrint('CAUGHT: $e'); }
    debugPrint('signin msg: ${find.text('Sign in to play').evaluate().isNotEmpty}');
    debugPrint('connecting: ${find.textContaining('Connecting').evaluate().isNotEmpty}');
    debugPrint('center: ${find.text('Multiplayer games').evaluate().isNotEmpty}');
    // Drain the socket connect timeout so the harness does not flag a pending timer.
    await tester.pump(const Duration(seconds: 11));
  });
}
