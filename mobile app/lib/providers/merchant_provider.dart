import 'package:flutter/material.dart';
import '../models/merchant_model.dart';

class MerchantProvider extends ChangeNotifier {
  MerchantModel _merchant = const MerchantModel(
    id: '',
    name: 'Merchant Center',
    userId: '',
    status: 'Inactive',
    countryCode: 'GLOBAL',
    availableCoins: 0,
    pendingCoins: 0,
    totalCoinsDistributed: 0,
    todaysTotalCoins: 0,
    userRechargeTotal: 0,
    sellerRechargeTotal: 0,
    dailyLimit: 0,
  );

  final List<MerchantTransactionModel> _transactions = [];
  final List<Map<String, dynamic>> _auditLogs = [];

  MerchantModel get merchant => _merchant;
  List<MerchantTransactionModel> get transactions => List.unmodifiable(_transactions);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  MerchantProvider() {
    // Clean initial state
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
