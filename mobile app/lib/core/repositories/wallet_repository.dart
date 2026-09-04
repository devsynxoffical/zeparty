import '../../models/transaction_model.dart';

/// Abstract repository interface for wallet transactions.
/// Disconnects direct UI manipulation from transaction logic.
/// Can be replaced with ApiWalletRepository or FirebaseWalletRepository when backend is connected.
abstract class WalletRepository {
  Future<int> fetchCoinBalance();
  Future<int> fetchDiamondBalance();
  Future<double> fetchRCoinBalance();
  Future<List<TransactionModel>> fetchTransactions();
  Future<bool> processCoinSpend(int amount, String idempotencyKey);
  Future<bool> processCoinRecharge(int coinAmount, double priceUSD);
  Future<bool> processWithdrawalRequest(double amountUSD, String payoutMethod, String accountNumber);
}

/// Development local implementation of WalletRepository.
class LocalWalletRepository implements WalletRepository {
  int _coins = 45000;
  final int _diamonds = 8520;
  double _rCoins = 1450.75;
  final List<TransactionModel> _transactions = [];

  @override
  Future<int> fetchCoinBalance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _coins;
  }

  @override
  Future<int> fetchDiamondBalance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _diamonds;
  }

  @override
  Future<double> fetchRCoinBalance() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _rCoins;
  }

  @override
  Future<List<TransactionModel>> fetchTransactions() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_transactions);
  }

  @override
  Future<bool> processCoinSpend(int amount, String idempotencyKey) async {
    if (_coins < amount) return false;
    _coins -= amount;
    _transactions.insert(
      0,
      TransactionModel(
        id: idempotencyKey,
        title: 'Spent $amount Coins [DEV MODE]',
        type: 'Expense',
        amount: amount.toDouble(),
        currency: 'Coins',
        status: 'Completed',
        date: DateTime.now(),
      ),
    );
    return true;
  }

  @override
  Future<bool> processCoinRecharge(int coinAmount, double priceUSD) async {
    _coins += coinAmount;
    _transactions.insert(
      0,
      TransactionModel(
        id: 'tx_dev_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Recharge $coinAmount Coins [DEV MODE]',
        type: 'Recharge',
        amount: coinAmount.toDouble(),
        currency: 'Coins',
        status: 'Completed (Development)',
        date: DateTime.now(),
      ),
    );
    return true;
  }

  @override
  Future<bool> processWithdrawalRequest(double amountUSD, String payoutMethod, String accountNumber) async {
    if (_rCoins < amountUSD) return false;
    _rCoins -= amountUSD;
    _transactions.insert(
      0,
      TransactionModel(
        id: 'wd_dev_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Cashout ($payoutMethod) [DEV MODE]',
        type: 'Withdrawal',
        amount: amountUSD,
        currency: 'USD',
        status: 'Pending Verification',
        date: DateTime.now(),
      ),
    );
    return true;
  }
}
