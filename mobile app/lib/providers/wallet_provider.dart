import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/recharge_plan_model.dart';
import '../core/repositories/wallet_repository.dart';
import '../core/services/api_client.dart';
import '../core/utils/performance_utils.dart';

class WalletProvider extends ChangeNotifier {
  final WalletRepository _repository = WalletRepository.instance;

  WalletModel? _wallet;
  final List<TransactionModel> _transactions = [];
  final List<RechargePlanModel> _plans = [];

  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUserId;
  final Set<String> _processedIdempotencyKeys = {};

  WalletModel? get wallet => _wallet;
  int get coins => _wallet?.coinBalance ?? 0;
  int get diamonds => _wallet?.diamondBalance ?? 0;
  int get lockedCoins => _wallet?.lockedCoins ?? 0;
  int get sellerBalance => _wallet?.sellerBalanceCoins ?? 0;
  double get rCoins => (_wallet?.diamondBalance ?? 0) * 0.01;

  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<RechargePlanModel> get plans => List.unmodifiable(_plans);
  List<TransactionModel> get withdrawals =>
      _transactions.where((t) => t.type.toUpperCase() == 'WITHDRAWAL').toList();

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  WalletProvider() {
    fetchWallet();
    fetchLedger();
  }

  /// Synchronize authoritative wallet state with current authenticated user
  Future<void> syncWithUser(UserModel user) async {
    if (user.id.isEmpty) {
      clearWallet();
      return;
    }

    if (_activeUserId != user.id) {
      _activeUserId = user.id;
      _errorMessage = null;

      // 1. Try restoring isolated local cache for this specific user
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString('zeparty_wallet_cache_${user.id}');
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final map = jsonDecode(cachedJson) as Map<String, dynamic>;
          _wallet = WalletModel.fromJson(map);
        } else {
          // Fallback to user authoritative balance snapshot until remote fetch completes
          _wallet = WalletModel(
            id: user.id,
            userId: user.id,
            coinBalance: user.coins,
            diamondBalance: user.diamonds,
          );
        }
      } catch (_) {
        _wallet = WalletModel(
          id: user.id,
          userId: user.id,
          coinBalance: user.coins,
          diamondBalance: user.diamonds,
        );
      }
      notifyListeners();
    }

    // Always fetch latest authoritative balance from backend
    fetchWallet();
  }

  /// Clear or isolate cached balance data on account switches / logout
  void clearWallet() {
    _wallet = null;
    _activeUserId = null;
    _errorMessage = null;
    _isLoading = false;
    _transactions.clear();
    _plans.clear();
    notifyListeners();
  }

  /// Fetch user's authoritative wallet balance from backend
  Future<void> fetchWallet() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final w = await _repository.fetchWallet();
      _wallet = w;
      _activeUserId = w.userId;
      _errorMessage = null;
      _isLoading = false;

      // Persist isolated cache per user account
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('zeparty_wallet_cache_${w.userId}', jsonEncode(w.toJson()));
      } catch (_) {}

      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load authoritative wallet balance';
      notifyListeners();
    }
  }

  /// Fetch user's transaction ledger history from backend
  Future<void> fetchLedger({bool refresh = false, String? type}) async {
    if (refresh) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final items = await _repository.fetchLedger(type: type);
      _transactions.clear();
      _transactions.addAll(items);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load transaction ledger';
      notifyListeners();
    }
  }

  /// Fetch active recharge plans configured on the platform
  Future<List<RechargePlanModel>> fetchRechargePlans() async {
    try {
      final fetchedPlans = await _repository.fetchRechargePlans();
      _plans.clear();
      _plans.addAll(fetchedPlans);
      notifyListeners();
      return _plans;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return _plans;
    } catch (e) {
      _errorMessage = 'Failed to load recharge packages';
      notifyListeners();
      return _plans;
    }
  }

  /// Create online payment intent with provider (Stripe, PayPal, etc.)
  Future<Map<String, dynamic>?> createPaymentIntent({
    required String planId,
    required String paymentProvider,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final idempotencyKey = PerformanceUtils.generateIdempotencyKey('pi');
    try {
      final result = await _repository.createPaymentIntent(
        planId: planId,
        paymentProvider: paymentProvider,
        idempotencyKey: idempotencyKey,
      );
      _isLoading = false;
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to initiate payment. Please try again.';
      notifyListeners();
      return null;
    }
  }

  /// Submit manual offline deposit receipt for admin review
  Future<bool> submitOfflineRecharge({
    required double amountUSD,
    required String bankName,
    required String receiptPhotoUrl,
    required String transactionRef,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final key = 'tx_off_$transactionRef';
    if (_processedIdempotencyKeys.contains(key)) {
      _isLoading = false;
      _errorMessage = 'Transaction reference already submitted';
      notifyListeners();
      return false;
    }

    try {
      await _repository.submitOfflineRecharge(
        amountUSD: amountUSD,
        bankName: bankName,
        receiptPhotoUrl: receiptPhotoUrl,
        transactionRef: transactionRef,
        idempotencyKey: key,
      );
      _processedIdempotencyKeys.add(key);
      _isLoading = false;
      await fetchLedger(refresh: true);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to submit offline deposit.';
      notifyListeners();
      return false;
    }
  }

  // --- Interaction helper methods ---
  bool spendCoins(int amount, [String? customIdempotencyKey, String? referenceId]) {
    _wallet ??= const WalletModel(id: 'local', userId: 'local', coinBalance: 10000, diamondBalance: 5000);
    if (amount > 0 && coins < amount) {
      return false;
    }
    
    _wallet = _wallet!.copyWith(coinBalance: max(0, _wallet!.coinBalance - amount));
    notifyListeners();
    fetchWallet();
    return true;
  }

  bool spendDiamonds(int amount, String giftName) {
    _wallet ??= const WalletModel(id: 'local', userId: 'local', coinBalance: 10000, diamondBalance: 5000);
    if (amount > 0 && diamonds < amount) {
      return false;
    }
    _wallet = _wallet!.copyWith(diamondBalance: max(0, _wallet!.diamondBalance - amount));
    notifyListeners();
    fetchWallet();
    return true;
  }

  bool transferDiamonds(int amount, String receiverId, String receiverType) {
    if (amount <= 0 || diamonds < amount) return false;
    fetchWallet();
    return true;
  }

  /// Prohibited per Item 21: Diamonds are for display within ZeParty only.
  /// Conversion between Diamonds and Coins in either direction is strictly prohibited.
  bool exchangeDiamondsToCoins(int diamondsAmount, int coinsAmount) {
    debugPrint('[WalletProvider] Coin/Diamond exchange is prohibited on ZeParty.');
    return false;
  }

  void earnCoins(int amount, String title, {String? referenceId}) {
    _wallet ??= const WalletModel(id: 'local', userId: 'local', coinBalance: 10000, diamondBalance: 5000);
    _wallet = _wallet!.copyWith(coinBalance: _wallet!.coinBalance + amount);
    notifyListeners();
    fetchWallet();
  }

  void rechargeCoins(int coinAmount, double priceUSD) {
    fetchWallet();
  }

  bool distributeCoinsToUser(String targetUserId, int coinAmount) {
    if (coinAmount <= 0 || coins < coinAmount) return false;
    fetchWallet();
    return true;
  }

  bool requestWithdrawal(double amountUSD, String payoutMethod, String accountNumber) {
    if (amountUSD <= 0 || rCoins < amountUSD) return false;
    fetchWallet();
    return true;
  }

  bool sellCoinsAndWithdraw({
    required int coinAmount,
    required double cashAmountUSD,
    required String payoutMethod,
    required String accountDetails,
  }) {
    if (coinAmount <= 0 || coins < coinAmount) return false;
    fetchWallet();
    return true;
  }

  bool lockCoins(int amount) {
    if (amount <= 0 || coins < amount) return false;
    fetchWallet();
    return true;
  }

  void unlockCoins(int amount) {
    fetchWallet();
  }

  void releaseLockedCoins(int amount) {
    fetchWallet();
  }
}
