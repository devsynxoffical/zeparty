import 'package:flutter/material.dart';
import '../models/merchant_model.dart';

class MerchantProvider extends ChangeNotifier {
  MerchantModel _merchant = const MerchantModel(
    id: 'merch_501',
    name: 'Premier Merchant Hub',
    userId: 'user_1001',
    status: 'Active',
    countryCode: 'GLOBAL',
    availableCoins: 10000000,
    pendingCoins: 0,
    totalCoinsDistributed: 45000000,
    todaysTotalCoins: 1200000,
    userRechargeTotal: 30000000,
    sellerRechargeTotal: 15000000,
    dailyLimit: 20000000,
  );

  final List<MerchantTransactionModel> _transactions = [];
  final List<Map<String, dynamic>> _auditLogs = [];

  MerchantModel get merchant => _merchant;
  List<MerchantTransactionModel> get transactions => List.unmodifiable(_transactions);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  MerchantProvider() {
    _initMockData();
  }

  void _initMockData() {
    final now = DateTime.now();
    _transactions.addAll([
      MerchantTransactionModel(transactionId: 'tx_merch_801', merchantId: _merchant.id, recipientType: 'User Recharge', recipientId: 'user_1002', recipientName: 'Sophia Rose', coinAmount: 500000, feeOrBonus: 0, merchantBalanceBefore: 10500000, merchantBalanceAfter: 10000000, destinationBalanceType: 'User Wallet', status: 'Successful', timestamp: now.subtract(const Duration(hours: 2))),
      MerchantTransactionModel(transactionId: 'tx_merch_802', merchantId: _merchant.id, recipientType: 'Coin Seller Recharge', recipientId: 'seller_8801', recipientName: 'Danial Coin Agency', coinAmount: 1000000, feeOrBonus: 0, merchantBalanceBefore: 11500000, merchantBalanceAfter: 10500000, destinationBalanceType: 'Seller Recharge Operational Balance', status: 'Successful', timestamp: now.subtract(const Duration(hours: 8))),
    ]);
  }

  // Atomic Merchant Recharge Execution
  String? executeMerchantRecharge({
    required String recipientType, // 'User Recharge' or 'Coin Seller Recharge'
    required String recipientId,
    required String recipientName,
    required int coinAmount,
    required String pin,
  }) {
    if (coinAmount <= 0) return 'Invalid coin amount.';
    if (_merchant.availableCoins < coinAmount) return 'Insufficient Merchant Balance.';
    if (pin != '1234' && pin != '0000') return 'Incorrect Security PIN.';

    final before = _merchant.availableCoins;
    final after = before - coinAmount;

    _merchant = _merchant.copyWith(
      availableCoins: after,
      totalCoinsDistributed: _merchant.totalCoinsDistributed + coinAmount,
      todaysTotalCoins: _merchant.todaysTotalCoins + coinAmount,
      userRechargeTotal: recipientType == 'User Recharge' ? _merchant.userRechargeTotal + coinAmount : _merchant.userRechargeTotal,
      sellerRechargeTotal: recipientType == 'Coin Seller Recharge' ? _merchant.sellerRechargeTotal + coinAmount : _merchant.sellerRechargeTotal,
    );

    final destType = recipientType == 'User Recharge' ? 'User Wallet' : 'Seller Recharge Operational Balance';

    _transactions.insert(
      0,
      MerchantTransactionModel(
        transactionId: 'tx_merch_${DateTime.now().millisecondsSinceEpoch}',
        merchantId: _merchant.id,
        recipientType: recipientType,
        recipientId: recipientId,
        recipientName: recipientName,
        coinAmount: coinAmount,
        feeOrBonus: 0,
        merchantBalanceBefore: before,
        merchantBalanceAfter: after,
        destinationBalanceType: destType,
        status: 'Successful',
        timestamp: DateTime.now(),
      ),
    );

    _logAudit(action: 'MERCHANT_RECHARGE', targetId: recipientId, reason: 'Merchant transferred $coinAmount coins to $destType');
    notifyListeners();
    return null;
  }

  void _logAudit({required String action, required String targetId, required String reason}) {
    _auditLogs.add({
      'merchantId': _merchant.id,
      'action': action,
      'targetId': targetId,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
