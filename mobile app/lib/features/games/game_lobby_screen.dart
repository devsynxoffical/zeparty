import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../../core/config/app_config.dart';
import '../../providers/auth_provider.dart';
import 'games_bootstrap.dart';
import 'games_session_service.dart';

/// Game Center hub: the ten premium multiplayer games with rooms, matchmaking,
/// coins wallet, store, achievements, leaderboards and match history.
///
/// Used as the body of the home "Games" tab and as a pushed route from banners.
/// It owns the games session (socket + REST) for as long as it is mounted.
class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key, this.initialGameId = 'ludo_royale'});

  /// Game highlighted in the Game Center when it opens.
  final String initialGameId;

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> with AutomaticKeepAliveClientMixin {
  final GlobalKey<NavigatorState> _gamesNavKey = GlobalKey<NavigatorState>();
  Future<(ZePartySession, GamesSessionInfo)>? _sessionFuture;
  String? _sessionUserId;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final userId = auth.isAuthenticated ? auth.currentUser.id : '';
    if (userId != _sessionUserId) {
      _sessionUserId = userId;
      _sessionFuture = userId.isEmpty ? null : GamesBootstrap.prepareSession(context);
    }
  }



  @override
  Widget build(BuildContext context) {
    super.build(context);
    final future = _sessionFuture;
    if (future == null) {
      return const _GamesMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to play',
        message: 'Games, coins and leaderboards are tied to your ZeParty account.',
      );
    }

    return FutureBuilder<(ZePartySession, GamesSessionInfo)>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _GamesMessage(loading: true, title: 'Connecting to the Game Center');
        }
        ZePartySession session;
        if (snap.hasData) {
          session = snap.data!.$1;
        } else {
          final auth = context.read<AuthProvider>();
          final fallbackUser = auth.currentUser;
          final fallbackInfo = GamesSessionInfo(
            token: 'offline_token_${fallbackUser.id}',
            expiresAt: DateTime.now().add(const Duration(days: 7)),
            apiBaseUrl: AppConfig.gamesApiBaseUrl,
            wsUrl: AppConfig.gamesWsUrl,
          );
          session = GamesSessionService.instance.toSession(fallbackUser, fallbackInfo);
        }

        return PopScope(
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
            key: ValueKey('games_root_${session.identity.userId}'),
            navigatorKey: _gamesNavKey,
            showInitialGameDetails: false,
            request: GameLaunchRequest(gameId: widget.initialGameId, session: session),
          ),
        );
      },
    );
  }
}

class _GamesMessage extends StatelessWidget {
  const _GamesMessage({required this.title, this.message, this.icon, this.loading = false});
  final String title;
  final String? message;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ZpColors.obsidian,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(width: 36, height: 36, child: CircularProgressIndicator(color: ZpColors.gold, strokeWidth: 3))
              else if (icon != null)
                Icon(icon, color: ZpColors.gold, size: 48),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: ZpColors.ivory, fontSize: 18, fontWeight: FontWeight.w700)),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center, style: TextStyle(color: ZpColors.ivory.withValues(alpha: 0.7), fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
