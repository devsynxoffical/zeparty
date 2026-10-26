import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:zeparty_game_network/zeparty_game_network.dart';

import 'models.dart';

/// Client wallet state. Balances always come from the server; the client only
/// caches the last server response and refreshes after any server-side change.
class WalletController extends ChangeNotifier {
  WalletController(this.api);
  final ZePartyApiClient api;
  static const _uuid = Uuid();

  WalletBalance? _balance;
  List<WalletTransaction> _transactions = const [];
  List<Cosmetic> _cosmetics = const [];
  Set<String> _owned = const {};
  Map<String, Map<String, String>> _equippedByGame = const {};
  List<Achievement> _achievements = const [];
  bool _loading = false;
  Object? _error;

  WalletBalance? get balance => _balance;
  int get coins => _balance?.balance ?? 0;
  List<WalletTransaction> get transactions => _transactions;
  List<Cosmetic> get cosmetics => _cosmetics;
  Set<String> get owned => _owned;
  List<Achievement> get achievements => _achievements;
  bool get loading => _loading;
  Object? get error => _error;

  bool owns(Cosmetic c) => c.isFree || _owned.contains(c.cosmeticId);
  Map<String, String> equipped(String gameId) => _equippedByGame[gameId] ?? const {};
  String? equippedFor(String gameId, String category) => equipped(gameId)[category];

  Future<void> refreshBalance() async {
    try {
      _balance = WalletBalance.fromJson(await api.wallet());
      _error = null;
    } catch (e) {
      _error = e;
    }
    notifyListeners();
  }

  Future<void> refreshAll({String? gameId}) async {
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        api.wallet(),
        api.walletTransactions(),
        api.cosmetics(),
        api.inventory(gameId: gameId),
        api.achievements(),
      ]);
      _balance = WalletBalance.fromJson(results[0] as Map<String, dynamic>);
      _transactions = (results[1] as List<Map<String, dynamic>>).map(WalletTransaction.fromJson).toList();
      _cosmetics = (results[2] as List<Map<String, dynamic>>).map(Cosmetic.fromJson).toList();
      final inv = results[3] as ({List<Map<String, dynamic>> items, Map<String, String> equipped});
      _owned = inv.items.map((i) => i['cosmeticId'] as String).toSet();
      if (gameId != null) _equippedByGame = {..._equippedByGame, gameId: inv.equipped};
      _achievements = (results[4] as List<Map<String, dynamic>>).map(Achievement.fromJson).toList();
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadEquipped(String gameId) async {
    final inv = await api.inventory(gameId: gameId);
    _equippedByGame = {..._equippedByGame, gameId: inv.equipped};
    _owned = inv.items.map((i) => i['cosmeticId'] as String).toSet();
    notifyListeners();
  }

  /// Purchase with a fresh idempotency key. Safe to retry with the same key on
  /// a network timeout; the server returns the original result.
  Future<PurchaseOutcome> purchase(Cosmetic c, {String? idempotencyKey}) async {
    final key = idempotencyKey ?? _uuid.v4();
    try {
      final r = await api.purchase(c.cosmeticId, key);
      _balance = WalletBalance.fromJson(r['wallet'] as Map<String, dynamic>);
      _owned = {..._owned, c.cosmeticId};
      notifyListeners();
      unawaited(refreshAll());
      return PurchaseOutcome.success(r['status'] as String);
    } on ApiException catch (e) {
      return PurchaseOutcome.failure(e.code);
    }
  }

  Future<void> equip(Cosmetic c) async {
    await api.equip(c.cosmeticId);
    final current = Map<String, String>.from(equipped(c.gameId));
    current[c.category] = c.cosmeticId;
    _equippedByGame = {..._equippedByGame, c.gameId: current};
    notifyListeners();
  }

  Future<int> claimAchievement(Achievement a) async {
    final r = await api.claimAchievement(a.id);
    final w = r['wallet'];
    if (w is Map<String, dynamic>) _balance = WalletBalance.fromJson(w);
    await refreshAll();
    return a.rewardCoins;
  }

  Future<int> claimDaily() async {
    final r = await api.claimDaily();
    final w = r['wallet'];
    if (w is Map<String, dynamic>) _balance = WalletBalance.fromJson(w);
    notifyListeners();
    unawaited(refreshAll());
    return (r['amount'] as num?)?.toInt() ?? 0;
  }

  static void unawaited(Future<void> f) {}
}

class PurchaseOutcome {
  const PurchaseOutcome._(this.ok, this.code);
  final bool ok;
  final String code;
  factory PurchaseOutcome.success(String status) => PurchaseOutcome._(true, status);
  factory PurchaseOutcome.failure(String code) => PurchaseOutcome._(false, code);
  String get message => switch (code) {
        'insufficient_funds' => 'Not enough coins',
        'already_owned' => 'Already owned',
        'cosmetic_disabled' => 'Not available right now',
        'applied' || 'duplicate' => 'Purchased',
        _ => code,
      };
}
