import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../core/constants/dummy_data.dart';
import '../core/utils/performance_utils.dart';

class WalletProvider extends ChangeNotifier {
  int _diamonds = 8520;
  int _coins = 45000;
  int _lockedCoins = 0;
  double _rCoins = 1450.75;
  final List<TransactionModel> _transactions = List.from(DummyData.transactions);
  final Set<String> _processedIdempotencyKeys = {};

  int get diamonds => _diamonds;
  int get coins => _coins;
  int get lockedCoins => _lockedCoins;
  double get rCoins => _rCoins;
  List<TransactionModel> get transactions => List.unmodifiable(_transactions);
  List<TransactionModel> get withdrawals =>
      _transactions.where((t) => t.type == 'Withdrawal').toList();

  bool spendCoins(int amount, [String? customIdempotencyKey, String? referenceId]) {
    if (amount > 0 && _coins < amount) {
      return false; // Insufficient funds
    }

    final key = customIdempotencyKey ?? referenceId ?? PerformanceUtils.generateIdempotencyKey('spend');
    if (_processedIdempotencyKeys.contains(key)) {
      return false; // Duplicate transaction prevented
    }
    _processedIdempotencyKeys.add(key);

    _coins -= amount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: amount > 0 ? 'Spent $amount Coins' : 'Reward ${-amount} Coins',
        type: amount > 0 ? 'Expense' : 'Reward',
        amount: amount.abs().toDouble(),
        currency: 'Coins',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  bool spendDiamonds(int amount, String giftName) {
    if (amount > 0 && _diamonds < amount) {
      return false; // Insufficient diamonds
    }

    final key = PerformanceUtils.generateIdempotencyKey('spend_diamond');
    if (_processedIdempotencyKeys.contains(key)) return false;
    _processedIdempotencyKeys.add(key);

    _diamonds -= amount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Sent Gift: $giftName',
        type: 'Gift Sent',
        amount: amount.toDouble(),
        currency: 'Diamonds',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  bool transferDiamonds(int amount, String receiverId, String receiverType) {
    if (amount <= 0 || _diamonds < amount) return false;
    final key = PerformanceUtils.generateIdempotencyKey('trf_dia');
    if (_processedIdempotencyKeys.contains(key)) return false;
    _processedIdempotencyKeys.add(key);

    _diamonds -= amount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Transfer to $receiverType ($receiverId)',
        type: 'Transfer',
        amount: amount.toDouble(),
        currency: 'Diamonds',
        status: 'Completed',
        date: DateTime.now(),
        targetUserId: receiverId,
      ),
    );
    notifyListeners();
    return true;
  }

  bool exchangeDiamondsToCoins(int diamondsAmount, int coinsAmount) {
    if (diamondsAmount <= 0 || _diamonds < diamondsAmount) return false;
    final key = PerformanceUtils.generateIdempotencyKey('exchange_dia_coin');
    _diamonds -= diamondsAmount;
    _coins += coinsAmount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Exchanged $diamondsAmount Diamonds for $coinsAmount Coins',
        type: 'Exchange',
        amount: coinsAmount.toDouble(),
        currency: 'Coins',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  void earnCoins(int amount, String title, {String? referenceId}) {
    if (amount <= 0) return;
    final key = referenceId ?? PerformanceUtils.generateIdempotencyKey('earn');
    if (_processedIdempotencyKeys.contains(key)) return;
    _processedIdempotencyKeys.add(key);

    _coins += amount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: title,
        type: 'Reward',
        amount: amount.toDouble(),
        currency: 'Coins',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }


  void rechargeCoins(int coinAmount, double priceUSD) {
    if (coinAmount <= 0) return;
    final key = PerformanceUtils.generateIdempotencyKey('recharge');

    _coins += coinAmount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Recharge $coinAmount Coins',
        type: 'Recharge',
        amount: coinAmount.toDouble(),
        currency: 'Coins',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void submitOfflineRecharge({
    required double amountUSD,
    required String paymentMethod,
    required String transactionId,
    required String proofFileName,
  }) {
    if (amountUSD <= 0) return;
    final key = 'tx_off_$transactionId';
    if (_processedIdempotencyKeys.contains(key)) return;
    _processedIdempotencyKeys.add(key);

    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Offline Recharge ($paymentMethod)',
        type: 'Offline Recharge',
        amount: amountUSD,
        currency: 'USD',
        status: 'Pending',
        date: DateTime.now(),
        proofUrl: proofFileName,
      ),
    );
    notifyListeners();
  }

  bool distributeCoinsToUser(String targetUserId, int coinAmount) {
    if (coinAmount <= 0 || _coins < coinAmount) return false;
    final key = PerformanceUtils.generateIdempotencyKey('dist');

    _coins -= coinAmount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Distributed to $targetUserId',
        type: 'Seller Distribution',
        amount: coinAmount.toDouble(),
        currency: 'Coins',
        status: 'Completed',
        date: DateTime.now(),
        targetUserId: targetUserId,
      ),
    );
    notifyListeners();
    return true;
  }

  bool requestWithdrawal(double amountUSD, String payoutMethod, String accountNumber) {
    if (amountUSD <= 0 || _rCoins < amountUSD) return false;
    final key = PerformanceUtils.generateIdempotencyKey('wd');

    _rCoins -= amountUSD;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Cashout ($payoutMethod - $accountNumber)',
        type: 'Withdrawal',
        amount: amountUSD,
        currency: 'USD',
        status: 'Pending',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  bool sellCoinsAndWithdraw({
    required int coinAmount,
    required double cashAmountUSD,
    required String payoutMethod,
    required String accountDetails,
  }) {
    if (coinAmount <= 0 || _coins < coinAmount) return false;
    final key = PerformanceUtils.generateIdempotencyKey('sell_wd');

    _coins -= coinAmount;
    _transactions.insert(
      0,
      TransactionModel(
        id: key,
        title: 'Coin Sale / Withdrawal ($payoutMethod - $accountDetails)',
        type: 'Withdrawal',
        amount: cashAmountUSD,
        currency: 'USD',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  // --- Escrow / P2P Locking ---
  bool lockCoins(int amount) {
    if (amount <= 0 || _coins < amount) return false;
    _coins -= amount;
    _lockedCoins += amount;
    notifyListeners();
    return true;
  }

  void unlockCoins(int amount) {
    if (amount <= 0 || _lockedCoins < amount) return;
    _lockedCoins -= amount;
    _coins += amount;
    notifyListeners();
  }

  void releaseLockedCoins(int amount) {
    if (amount <= 0 || _lockedCoins < amount) return;
    _lockedCoins -= amount;
    // Coins are permanently removed, typically sent to another user.
    notifyListeners();
  }
}
