import 'package:flutter/material.dart';
import '../models/recharge_agency_model.dart';

class RechargeAgencyProvider extends ChangeNotifier {
  int _availableCoins = 0;
  final int _pendingCoins = 0;
  int _totalCoinsRecharged = 0;
  int _todaysRechargeTotal = 0;
  final int _dailyLimit = 0;
  final String _sellerId = '';
  final String _sellerName = 'Coin Reseller Agency';
  final String _countryCode = 'GLOBAL';

  final List<SavedCustomerModel> _savedCustomers = [];
  final List<SellerRechargeTransactionModel> _transactions = [];
  final List<Map<String, dynamic>> _auditLogs = [];

  int get availableCoins => _availableCoins;
  int get pendingCoins => _pendingCoins;
  int get totalCoinsRecharged => _totalCoinsRecharged;
  int get todaysRechargeTotal => _todaysRechargeTotal;
  int get dailyLimit => _dailyLimit;
  String get sellerId => _sellerId;
  String get sellerName => _sellerName;
  String get countryCode => _countryCode;

  List<SavedCustomerModel> get savedCustomers => List.unmodifiable(_savedCustomers);
  List<SellerRechargeTransactionModel> get transactions => List.unmodifiable(_transactions);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  RechargeAgencyProvider() {
    // Clean initial state
  }

  // Atomic User Verification
  Map<String, dynamic>? verifyUser(String userId) {
    if (userId.trim().isEmpty) return null;
    if (userId == 'banned_user') return {'error': 'User account is suspended.'};
    
    return {
      'userId': userId,
      'name': userId == 'user_1002' ? 'Sophia Rose' : (userId == 'user_1003' ? 'Alex Rivera' : 'Verified Recipient $userId'),
      'avatarUrl': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      'countryCode': 'GLOBAL',
      'status': 'Active',
    };
  }

  // Atomic Coin Recharge Transaction
  String? executeRecharge({
    required String recipientUserId,
    required String recipientName,
    required String recipientAvatarUrl,
    required int coins,
    required String pin,
  }) {
    if (coins <= 0) return 'Invalid coin amount.';
    if (_availableCoins < coins) return 'Insufficient Seller Available Coins.';
    if (pin != '1234' && pin != '0000') return 'Incorrect Security PIN.';

    final before = _availableCoins;
    final after = before - coins;

    _availableCoins = after;
    _todaysRechargeTotal += coins;
    _totalCoinsRecharged += coins;

    final tx = SellerRechargeTransactionModel(
      transactionId: 'tx_sel_${DateTime.now().millisecondsSinceEpoch}',
      sellerId: _sellerId,
      sellerName: _sellerName,
      recipientUserId: recipientUserId,
      recipientName: recipientName,
      recipientAvatarUrl: recipientAvatarUrl,
      coins: coins,
      feeOrBonus: 0,
      sellerBalanceBefore: before,
      sellerBalanceAfter: after,
      status: 'Successful',
      countryCode: _countryCode,
      timestamp: DateTime.now(),
    );

    _transactions.insert(0, tx);
    _logAudit(action: 'COIN_RECHARGE', targetId: recipientUserId, reason: 'Seller recharged $coins coins');
    notifyListeners();
    return null;
  }

  // Saved Customers
  void addSavedCustomer({required String linkedUserId, required String recipientName, required String label, required String contactNumber}) {
    _savedCustomers.add(SavedCustomerModel(
      id: 'sc_${DateTime.now().millisecondsSinceEpoch}',
      sellerId: _sellerId,
      linkedUserId: linkedUserId,
      recipientName: recipientName,
      label: label,
      contactNumber: contactNumber,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void _logAudit({required String action, required String targetId, required String reason}) {
    _auditLogs.add({
      'sellerId': _sellerId,
      'action': action,
      'targetId': targetId,
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
