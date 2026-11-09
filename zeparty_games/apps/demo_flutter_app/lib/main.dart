import 'package:flutter/material.dart';
import 'package:air_hockey/air_hockey.dart';
import 'package:carrom_masters/carrom_masters.dart';
import 'package:chess_legends/chess_legends.dart';
import 'package:color_clash/color_clash.dart';
import 'package:connect4_galaxy/connect4_galaxy.dart';
import 'package:darts_arena/darts_arena.dart';
import 'package:ludo_royale/ludo_royale.dart';
import 'package:mini_golf_paradise/mini_golf_paradise.dart';
import 'package:pool_elite/pool_elite.dart';
import 'package:snake_ladder_kingdom/snake_ladder_kingdom.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'screens/dev_login_screen.dart';

/// Backend location. Override at build time:
///   flutter run --dart-define=ZP_API=http://10.0.2.2:8080 --dart-define=ZP_WS=ws://10.0.2.2:8080/ws
const String kApiBase = String.fromEnvironment('ZP_API', defaultValue: 'http://localhost:8080');
const String kWsUrl = String.fromEnvironment('ZP_WS', defaultValue: 'ws://localhost:8080/ws');

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerAllGames();
  runApp(const DemoApp());
}

/// Registers every shipped game module. The host app does the same at startup.
void registerAllGames() {
  GameModuleRegistry.instance
    ..register(LudoRoyaleModule())
    ..register(Connect4GalaxyModule())
    ..register(SnakeLadderKingdomModule())
    ..register(ChessLegendsModule())
    ..register(ColorClashModule())
    ..register(CarromMastersModule())
    ..register(PoolEliteModule())
    ..register(AirHockeyModule())
    ..register(DartsArenaModule())
    ..register(MiniGolfParadiseModule());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ZeParty Games Demo',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ZpTheme.dark(),
        home: const DevLoginScreen(),
      );
}

/// Simulates what the host app does once: configure the launcher, then open a game.
Future<void> launchGames(BuildContext context, {required String apiBase, required String wsUrl, required ZePartySession session, String gameId = 'ludo_royale'}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('zp_last_user', session.identity.userId);
  await prefs.setString('zp_api', apiBase);
  await prefs.setString('zp_ws', wsUrl);
  ZePartyGameLauncher.configure(
    ZePartyGamesConfig(apiBaseUrl: apiBase, wsUrl: wsUrl, hostBridge: const NoopHostBridge()),
    NavigatorLauncherDelegate(navigatorKey),
  );
  // `?embedded=1` mirrors the ZeParty app, which hosts the Game Center as a tab
  // (bottom navigation + nested navigator) instead of pushing it full screen.
  if (Uri.base.queryParameters['embedded'] == '1' && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EmbeddedHostPage(session: session, gameId: gameId)));
    return;
  }
  await ZePartyGameLauncher.openGame(
    gameId: gameId,
    userId: session.identity.userId,
    authToken: session.authToken,
    displayName: session.identity.displayName,
    avatarUrl: session.identity.avatarUrl,
  );
}

Future<ZePartySession> devLogin(String apiBase, String userId, String name) => ZePartyApiClient.devLogin(apiBase, userId: userId, displayName: name);

/// Stand-in for the host app's tab shell: the Game Center lives inside an
/// IndexedStack behind a bottom navigation bar, exactly like the Games tab.
class EmbeddedHostPage extends StatefulWidget {
  const EmbeddedHostPage({super.key, required this.session, required this.gameId});
  final ZePartySession session;
  final String gameId;
  @override
  State<EmbeddedHostPage> createState() => _EmbeddedHostPageState();
}

class _EmbeddedHostPageState extends State<EmbeddedHostPage> {
  final GlobalKey<NavigatorState> _gamesNavKey = GlobalKey<NavigatorState>();
  int _tab = 1;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: [
              const Center(child: Text('Home tab')),
              PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (didPop) return;
                  final inner = _gamesNavKey.currentState;
                  if (inner != null && inner.canPop()) {
                    inner.pop();
                  } else {
                    final outer = Navigator.maybeOf(context);
                    if (outer != null && outer.canPop()) outer.pop();
                  }
                },
                child: ZePartyGamesRoot(
                  key: ValueKey('games_root_${widget.session.identity.userId}'),
                  navigatorKey: _gamesNavKey,
                  showInitialGameDetails: false,
                  embedded: true,
                  request: GameLaunchRequest(gameId: widget.gameId, session: widget.session),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.sports_esports), label: 'Games'),
          ],
        ),
      );
}
