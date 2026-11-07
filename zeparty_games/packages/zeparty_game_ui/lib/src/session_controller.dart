import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';
import 'package:zeparty_game_wallet/zeparty_game_wallet.dart';

/// Holds the authenticated session, socket, API client and wallet for the
/// lifetime of the game UI. Provided through [SessionScope].
class SessionController extends ChangeNotifier {
  SessionController({required this.config, required this.session})
      : api = ZePartyApiClient(baseUrl: config.apiBaseUrl, authToken: session.authToken),
        socket = ZePartySocketClient(wsUrl: config.wsUrl, authToken: session.authToken) {
    wallet = WalletController(api);
    socket.addListener(notifyListeners);
    _subs.add(socket.errorStream.listen((e) => _lastError = e));
    _subs.add(socket.inviteStream.listen((m) => _invites.add(m)));
    _subs.add(config.hostBridge.voiceState.listen((v) {
      if (v.userId == session.identity.userId && socket.status == SocketStatus.connected) {
        socket.setVoiceState(micActive: v.speaking, muted: v.muted).ignore();
      }
    }));
  }

  final ZePartyGamesConfig config;
  final ZePartySession session;
  final ZePartyApiClient api;
  final ZePartySocketClient socket;
  late final WalletController wallet;
  final List<StreamSubscription<dynamic>> _subs = [];
  final _invites = StreamController<Map<String, dynamic>>.broadcast();

  ServerError? _lastError;
  List<GameCatalogEntry> _catalog = kBuiltInCatalog;
  int _onlineUsers = 0;
  bool _catalogLoaded = false;

  ZePartyIdentity get me => session.identity;
  String get userId => me.userId;
  List<GameCatalogEntry> get catalog => _catalog;
  int get onlineUsers => _onlineUsers;
  bool get catalogLoaded => _catalogLoaded;
  ServerError? get lastError => _lastError;
  Stream<Map<String, dynamic>> get invites => _invites.stream;
  ZePartyHostBridge get host => config.hostBridge;

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await socket.connect();
    unawaited(refreshCatalog());
    unawaited(wallet.refreshBalance());
  }

  Future<void> refreshCatalog() async {
    try {
      final r = await api.games();
      final serverIds = r.games.map((g) => g.gameId).toSet();
      // Keep local entries the server disabled out of the list, order by server.
      _catalog = [...r.games, ...kBuiltInCatalog.where((g) => !serverIds.contains(g.gameId) && false)];
      _onlineUsers = r.onlineUsers;
      _catalogLoaded = true;
    } catch (_) {
      _catalog = kBuiltInCatalog;
    }
    notifyListeners();
  }

  GameCatalogEntry? entry(String gameId) {
    for (final g in _catalog) {
      if (g.gameId == gameId) return g;
    }
    for (final g in kBuiltInCatalog) {
      if (g.gameId == gameId) return g;
    }
    return null;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _invites.close();
    socket.removeListener(notifyListeners);
    socket.dispose();
    api.close();
    super.dispose();
  }
}

/// One live games session (socket + REST + wallet) per signed-in user.
///
/// The host app can mount more than one [ZePartyGamesRoot] at the same time,
/// for example the Game Center tab kept alive on the home screen plus a game
/// opened full screen from a live room. Each root used to open its own
/// WebSocket for the same user; the server keeps one socket per user and
/// replaces the previous one, both clients reconnected in turn and every reply
/// (dice rolls, turn changes) landed on whichever socket won last. Sharing the
/// controller keeps a single connection per user.
class SessionRegistry {
  SessionRegistry._();

  static final Map<String, _SessionEntry> _entries = {};

  static String _key(ZePartyGamesConfig config, ZePartySession session) => '${config.wsUrl}|${session.identity.userId}';

  /// Returns the controller for this user and backend, creating and starting
  /// it on first use. Pair every call with [release].
  static SessionController acquire(ZePartyGamesConfig config, ZePartySession session) {
    final key = _key(config, session);
    final existing = _entries[key];
    if (existing != null) {
      existing.refs++;
      // A fresher token (the host refreshed it) replaces the one in use.
      if (existing.controller.session.authToken != session.authToken) {
        existing.controller.api.authToken = session.authToken;
        existing.controller.socket.authToken = session.authToken;
      }
      return existing.controller;
    }
    final controller = SessionController(config: config, session: session);
    _entries[key] = _SessionEntry(controller);
    return controller;
  }

  /// Drops one reference; the session is torn down when the last root goes.
  static void release(SessionController controller) {
    for (final e in _entries.entries) {
      if (e.value.controller == controller) {
        e.value.refs--;
        if (e.value.refs <= 0) {
          _entries.remove(e.key);
          controller.dispose();
        }
        return;
      }
    }
    controller.dispose();
  }

  static int get liveSessions => _entries.length;
}

class _SessionEntry {
  _SessionEntry(this.controller);
  final SessionController controller;
  int refs = 1;
}

/// Whether the enclosing [ZePartyGamesRoot] is the topmost one. Screens that
/// navigate on their own in reaction to server events (a room appearing, a
/// match starting) only do so in the active root, so a root hidden behind
/// another never pushes screens or starts a second game engine.
class GamesRootActivity extends InheritedWidget {
  const GamesRootActivity({super.key, required this.active, required super.child});
  final bool active;

  static bool isActive(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GamesRootActivity>()?.active ?? true;

  static bool readActive(BuildContext context) => context.getInheritedWidgetOfExactType<GamesRootActivity>()?.active ?? true;

  @override
  bool updateShouldNotify(GamesRootActivity old) => old.active != active;
}

class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({super.key, required SessionController controller, required super.child}) : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope missing above this widget');
    return scope!.notifier!;
  }

  static SessionController read(BuildContext context) => (context.getInheritedWidgetOfExactType<SessionScope>()!).notifier!;
}

extension on Future<void> {
  void ignore() {}
}
