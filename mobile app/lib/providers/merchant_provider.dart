import 'package:flutter/material.dart';
import '../core/services/api_client.dart';
import '../models/merchant_model.dart';

class MerchantProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

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

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MerchantModel get merchant => _merchant;
  List<MerchantTransactionModel> get transactions => List.unmodifiable(_transactions);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  MerchantProvider() {
    // Initial load
  }

  /// Authoritative fetch of current active merchant profile and live balance
  Future<void> fetchMyMerchantCenter() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.instance.get('/v1/merchants/me');
      if (response.data?['success'] == true && response.data['data'] != null) {
        _merchant = MerchantModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Authoritative fetch of merchant transaction ledger
  Future<void> fetchTransactions({int page = 1, int limit = 20}) async {
    try {
      final response = await ApiClient.instance.get(
        '/v1/merchants/ledger',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (response.data?['success'] == true && response.data['data'] is List) {
        final list = (response.data['data'] as List)
            .map((item) => MerchantTransactionModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _transactions.clear();
        _transactions.addAll(list);
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Authoritative atomic merchant recharge execution
  Future<String?> executeMerchantRecharge({
    required String recipientType, // 'User Recharge' or 'Coin Seller Recharge'
    required String recipientId,
    required String recipientName,
    required int coinAmount,
    required String pin,
  }) async {
    if (coinAmount <= 0) return 'Invalid coin amount.';
    if (_merchant.availableCoins > 0 && _merchant.availableCoins < coinAmount) {
      return 'Insufficient Merchant Balance.';
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.instance.post(
        '/v1/merchants/recharge',
        data: {
          'recipientId': recipientId.trim(),
          'amountCoins': coinAmount,
          'notes': '$recipientType - $recipientName',
        },
      );

      if (response.data?['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final remaining = int.tryParse(data?['remainingQuota']?.toString() ?? '') ??
            (_merchant.availableCoins - coinAmount);

        _merchant = _merchant.copyWith(
          availableCoins: remaining >= 0 ? remaining : 0,
          totalCoinsDistributed: _merchant.totalCoinsDistributed + coinAmount,
          todaysTotalCoins: _merchant.todaysTotalCoins + coinAmount,
          userRechargeTotal: recipientType == 'User Recharge'
              ? _merchant.userRechargeTotal + coinAmount
              : _merchant.userRechargeTotal,
          sellerRechargeTotal: recipientType == 'Coin Seller Recharge'
              ? _merchant.sellerRechargeTotal + coinAmount
              : _merchant.sellerRechargeTotal,
        );

        final destType = recipientType == 'User Recharge'
            ? 'User Wallet'
            : 'Seller Recharge Operational Balance';

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
            merchantBalanceBefore: _merchant.availableCoins + coinAmount,
            merchantBalanceAfter: remaining >= 0 ? remaining : 0,
            destinationBalanceType: destType,
            status: 'Successful',
            timestamp: DateTime.now(),
          ),
        );

        _logAudit(
          action: 'MERCHANT_RECHARGE',
          targetId: recipientId,
          reason: 'Merchant transferred $coinAmount coins to $destType',
        );

        // Also refresh ledger from backend
        fetchTransactions();

        return null;
      } else {
        return response.data?['message']?.toString() ?? 'Failed to execute recharge';
      }
    } catch (e) {
      final err = e.toString();
      _errorMessage = err;
      return err.contains('403')
          ? 'Unauthorized or inactive merchant.'
          : err.contains('404')
              ? 'Recipient not found.'
              : err.contains('400')
                  ? 'Insufficient balance or invalid amount.'
                  : 'Recharge failed: $err';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
