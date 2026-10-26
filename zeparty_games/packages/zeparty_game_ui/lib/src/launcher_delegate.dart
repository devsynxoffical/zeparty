import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'screens/game_center_screen.dart';
import 'screens/game_details_screen.dart';
import 'screens/room_screen.dart';
import 'session_controller.dart';
import 'theme/zp_theme.dart';

/// Root widget the host app pushes. Owns the session for its lifetime.
///
/// Host integration:
/// ```dart
/// ZePartyGameLauncher.configure(
///   ZePartyGamesConfig(apiBaseUrl: 'https://games.zeparty.app', wsUrl: 'wss://games.zeparty.app/ws', hostBridge: MyBridge()),
///   NavigatorLauncherDelegate(navigatorKey),
/// );
/// GameModuleRegistry.instance.register(LudoRoyaleModule());
/// ```
class ZePartyGamesRoot extends StatefulWidget {
  const ZePartyGamesRoot({super.key, required this.request, this.wrapInTheme = true, this.showInitialGameDetails = true, this.navigatorKey});
  final GameLaunchRequest request;

  /// Optional key for the games' internal navigator so a host that embeds the
  /// root (for example as a tab) can route the system back button into it.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// When false and no room is requested, the Game Center opens directly
  /// without pushing the details screen of [GameLaunchRequest.gameId]. Hosts
  /// embedding the Game Center as a tab use this.
  final bool showInitialGameDetails;

  /// When embedded inside the host app's MaterialApp, keep true so the games use
  /// their own theme without changing the host's.
  final bool wrapInTheme;

  @override
  State<ZePartyGamesRoot> createState() => _ZePartyGamesRootState();
}

class _ZePartyGamesRootState extends State<ZePartyGamesRoot> {
  late final SessionController _controller = SessionController(config: ZePartyGameLauncher.config, session: widget.request.session);
  late final GlobalKey<NavigatorState> _navKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _controller.start().then((_) => _route());
    GraphicsSettings.instance.startAutoTuning();
  }

  Future<void> _route() async {
    final r = widget.request;
    if (r.roomId == null) return;
    // Wait until the socket is authenticated before joining.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (r.spectate) {
      await _controller.socket.spectate(r.roomId!);
    } else {
      await _controller.socket.joinRoom(r.roomId!, inviteCode: r.inviteCode);
    }
    _navKey.currentState?.push(RoomScreen.route(r.roomId!));
  }

  @override
  void dispose() {
    GraphicsSettings.instance.stopAutoTuning();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    Widget body = SessionScope(
      controller: _controller,
      child: Navigator(
        key: _navKey,
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => GameCenterScreen(initialGameId: r.gameId)),
        onGenerateInitialRoutes: (_, _) => [
          MaterialPageRoute(builder: (_) => GameCenterScreen(initialGameId: r.gameId)),
          if (r.roomId == null && widget.showInitialGameDetails) GameDetailsScreen.route(r.gameId),
        ],
      ),
    );
    if (widget.wrapInTheme) body = Theme(data: ZpTheme.dark(), child: body);
    return body;
  }
}

/// Default delegate: pushes [ZePartyGamesRoot] on the host navigator.
class NavigatorLauncherDelegate implements ZePartyGameLauncherDelegate {
  NavigatorLauncherDelegate(this.navigatorKey);
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Future<void> open(GameLaunchRequest request) async {
    final nav = navigatorKey.currentState;
    if (nav == null) throw StateError('navigatorKey is not attached');
    await nav.push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ZePartyGamesRoot(request: request)));
  }
}
