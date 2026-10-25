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

  Future<void> start() async {
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
