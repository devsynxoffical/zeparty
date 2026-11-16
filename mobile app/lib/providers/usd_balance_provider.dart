import 'package:flutter/material.dart';
import '../core/services/api_client.dart';

class UsdTransactionModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'Audio Host', 'Live Host', 'Agency Owner', 'BD Operator', 'Coin Seller', 'Merchant'
  final String? agencyId;
  final String? agencyName;
  final String recipientId; // Seller ID or Merchant ID
  final String recipientName;
  final String recipientType; // 'Coin Seller' or 'Merchant'
  final double usdAmount;
  final String payoutPeriod;
  final DateTime timestamp;
  final String referenceId;
  final String status; // 'Completed', 'Pending', 'Failed'
  final String type; // 'Payout Withdrawal', 'Direct Transfer', 'Exchange to Coins'

  UsdTransactionModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.agencyId,
    this.agencyName,
    required this.recipientId,
    required this.recipientName,
    required this.recipientType,
    required this.usdAmount,
    required this.payoutPeriod,
    required this.timestamp,
    required this.referenceId,
    required this.status,
    required this.type,
  });
}

class SellerMerchantRecipient {
  final String id;
  final String name;
  final String type; // 'Coin Seller' or 'Merchant'
  final String agencyName;
  final String avatarUrl;

  const SellerMerchantRecipient({
    required this.id,
    required this.name,
    required this.type,
    required this.agencyName,
    required this.avatarUrl,
  });
}

class AudioHostSalaryPeriod {
  final String periodId;
  final String periodLabel; // e.g. 'Sep 16 - Sep 30, 2026'
  final double earnedAmount;
  final double pendingAmount;
  final double availableAmount;
  final String status; // 'Eligible', 'Pending Payout', 'Paid'

  const AudioHostSalaryPeriod({
    required this.periodId,
    required this.periodLabel,
    required this.earnedAmount,
    required this.pendingAmount,
    required this.availableAmount,
    required this.status,
  });
}

class UsdBalanceProvider extends ChangeNotifier {
  static final UsdBalanceProvider instance = UsdBalanceProvider._internal();
  factory UsdBalanceProvider() => instance;
  UsdBalanceProvider._internal();

  // Audio Host Personal USD Balance
  double _audioHostAvailableBalance = 0.00;
  final double _audioHostPendingBalance = 0.00;

  final List<AudioHostSalaryPeriod> _audioHostSalaryPeriods = [];

  final List<UsdTransactionModel> _audioHostWithdrawalHistory = [];

  // BD Operator Wallet
  double _bdAvailableBalance = 0.00;
  double _bdPendingBalance = 0.00;
  final String _bdCurrentEarningPeriod = 'Current Period';
  final double _bdCommissionEarned = 0.00;

  final List<UsdTransactionModel> _bdWithdrawalHistory = [];

  // Coin Seller USD Accounting
  double _sellerAvailableUsd = 0.00;
  double _sellerPendingUsd = 0.00;
  double _sellerTotalReceivedUsd = 0.00;

  final List<UsdTransactionModel> _sellerUsdTransactions = [];

  // Merchant USD Accounting
  double _merchantAvailableUsd = 0.00;
  double _merchantPendingUsd = 0.00;
  double _merchantTotalReceivedUsd = 0.00;
  bool _isLoadingMerchantUsd = false;

  final List<UsdTransactionModel> _merchantUsdTransactions = [];

  bool get isLoadingMerchantUsd => _isLoadingMerchantUsd;

  // Recipient Catalog
  final List<SellerMerchantRecipient> _coinSellers = [
    const SellerMerchantRecipient(
      id: 'SEL-101',
      name: 'Global Reseller Alpha',
      type: 'Coin Seller',
      agencyName: 'ZeParty Resellers Network',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
    ),
    const SellerMerchantRecipient(
      id: 'SEL-102',
      name: 'Prime Coin Seller Express',
      type: 'Coin Seller',
      agencyName: 'Star Stream Agency',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
    ),
  ];

  final List<SellerMerchantRecipient> _merchants = [
    const SellerMerchantRecipient(
      id: 'MRC-201',
      name: 'ZeParty Premier Merchant',
      type: 'Merchant',
      agencyName: 'Official Merchant Network',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
    ),
    const SellerMerchantRecipient(
      id: 'MRC-202',
      name: 'Apex Merchant Exchange',
      type: 'Merchant',
      agencyName: 'Apex Global Hub',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
    ),
  ];

  // Getters
  double get audioHostAvailableBalance => _audioHostAvailableBalance;
  double get audioHostPendingBalance => _audioHostPendingBalance;
  List<AudioHostSalaryPeriod> get audioHostSalaryPeriods => List.unmodifiable(_audioHostSalaryPeriods);
  List<UsdTransactionModel> get audioHostWithdrawalHistory => List.unmodifiable(_audioHostWithdrawalHistory);

  double get bdAvailableBalance => _bdAvailableBalance;
  double get bdPendingBalance => _bdPendingBalance;
  String get bdCurrentEarningPeriod => _bdCurrentEarningPeriod;
  double get bdCommissionEarned => _bdCommissionEarned;
  List<UsdTransactionModel> get bdWithdrawalHistory => List.unmodifiable(_bdWithdrawalHistory);

  double get sellerAvailableUsd => _sellerAvailableUsd;
  double get sellerPendingUsd => _sellerPendingUsd;
  double get sellerTotalReceivedUsd => _sellerTotalReceivedUsd;
  List<UsdTransactionModel> get sellerUsdTransactions => List.unmodifiable(_sellerUsdTransactions);

  double get merchantAvailableUsd => _merchantAvailableUsd;
  double get merchantPendingUsd => _merchantPendingUsd;
  double get merchantTotalReceivedUsd => _merchantTotalReceivedUsd;
  List<UsdTransactionModel> get merchantUsdTransactions => List.unmodifiable(_merchantUsdTransactions);

  List<SellerMerchantRecipient> get coinSellers => List.unmodifiable(_coinSellers);
  List<SellerMerchantRecipient> get merchants => List.unmodifiable(_merchants);

  // Audio Host Withdrawal Request
  String? requestAudioHostWithdrawal({
    required SellerMerchantRecipient recipient,
    required double amountUsd,
    required String payoutPeriod,
    required String senderName,
    required String senderId,
    required String agencyName,
  }) {
    if (amountUsd <= 0) return 'Invalid withdrawal amount.';
    if (amountUsd > _audioHostAvailableBalance) return 'Requested amount exceeds available host balance.';

    _audioHostAvailableBalance -= amountUsd;

    final refId = 'REF-HOST-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final tx = UsdTransactionModel(
      id: 'w_host_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      senderRole: 'Audio Host',
      agencyId: 'ag_royal',
      agencyName: agencyName,
      recipientId: recipient.id,
      recipientName: recipient.name,
      recipientType: recipient.type,
      usdAmount: amountUsd,
      payoutPeriod: payoutPeriod,
      timestamp: DateTime.now(),
      referenceId: refId,
      status: 'Completed',
      type: 'Payout Withdrawal',
    );

    _audioHostWithdrawalHistory.insert(0, tx);

    if (recipient.type == 'Coin Seller') {
      _sellerAvailableUsd += amountUsd;
      _sellerTotalReceivedUsd += amountUsd;
      _sellerUsdTransactions.insert(0, tx);
    } else {
      _merchantAvailableUsd += amountUsd;
      _merchantTotalReceivedUsd += amountUsd;
      _merchantUsdTransactions.insert(0, tx);
    }

    notifyListeners();
    return null;
  }

  // BD Operator Withdrawal Request
  String? requestBDWithdrawal({
    required SellerMerchantRecipient recipient,
    required double amountUsd,
    required String senderName,
    required String senderId,
  }) {
    if (amountUsd <= 0) return 'Invalid withdrawal amount.';
    if (amountUsd > _bdAvailableBalance) return 'Requested amount exceeds available BD wallet balance.';

    _bdAvailableBalance -= amountUsd;

    final refId = 'REF-BD-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final tx = UsdTransactionModel(
      id: 'w_bd_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      senderRole: 'BD Operator',
      agencyId: 'bd_corp',
      agencyName: 'MENA BD Division',
      recipientId: recipient.id,
      recipientName: recipient.name,
      recipientType: recipient.type,
      usdAmount: amountUsd,
      payoutPeriod: _bdCurrentEarningPeriod,
      timestamp: DateTime.now(),
      referenceId: refId,
      status: 'Completed',
      type: 'Payout Withdrawal',
    );

    _bdWithdrawalHistory.insert(0, tx);

    if (recipient.type == 'Coin Seller') {
      _sellerAvailableUsd += amountUsd;
      _sellerTotalReceivedUsd += amountUsd;
      _sellerUsdTransactions.insert(0, tx);
    } else {
      _merchantAvailableUsd += amountUsd;
      _merchantTotalReceivedUsd += amountUsd;
      _merchantUsdTransactions.insert(0, tx);
    }

    notifyListeners();
    return null;
  }

  // Exchange USD to Coins for Seller or Merchant
  String? exchangeUsdToCoins({
    required String entityType, // 'Coin Seller' or 'Merchant'
    required double usdAmount,
    required int ratePerDollar, // e.g. 10000
  }) {
    if (usdAmount <= 0) return 'Invalid USD amount.';

    if (entityType == 'Coin Seller') {
      if (usdAmount > _sellerAvailableUsd) return 'Insufficient available USD balance.';
      _sellerAvailableUsd -= usdAmount;
      final tx = UsdTransactionModel(
        id: 'ex_sel_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'SEL-101',
        senderName: 'Global Reseller Alpha',
        senderRole: 'Coin Seller',
        recipientId: 'SEL-101',
        recipientName: 'Gold Coins Conversion',
        recipientType: 'Coin Seller',
        usdAmount: usdAmount,
        payoutPeriod: 'Instant Exchange',
        timestamp: DateTime.now(),
        referenceId: 'EX-SEL-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        status: 'Completed',
        type: 'Exchange to Coins',
      );
      _sellerUsdTransactions.insert(0, tx);
    } else {
      if (usdAmount > _merchantAvailableUsd) return 'Insufficient available USD balance.';
      _merchantAvailableUsd -= usdAmount;
      final tx = UsdTransactionModel(
        id: 'ex_mrc_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'MRC-201',
        senderName: 'ZeParty Premier Merchant',
        senderRole: 'Merchant',
        recipientId: 'MRC-201',
        recipientName: 'Gold Coins Conversion',
        recipientType: 'Merchant',
        usdAmount: usdAmount,
        payoutPeriod: 'Instant Exchange',
        timestamp: DateTime.now(),
        referenceId: 'EX-MRC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
        status: 'Completed',
        type: 'Exchange to Coins',
      );
      _merchantUsdTransactions.insert(0, tx);
    }

    notifyListeners();
    return null;
  }

  // ---- Authoritative Remote Backend USD Synchronization ----

  Future<void> fetchMerchantUsdBalance() async {
    _isLoadingMerchantUsd = true;
    notifyListeners();

    try {
      final res = await ApiClient.instance.get('/v1/merchants/usd-balance');
      if (res.statusCode == 200 && res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        _merchantAvailableUsd = double.tryParse(data['availableUSD']?.toString() ?? '0') ?? 0.0;
        _merchantTotalReceivedUsd = double.tryParse(data['totalReceivedUSD']?.toString() ?? '0') ?? 0.0;

        if (data['transactions'] is List) {
          _merchantUsdTransactions.clear();
          for (final raw in (data['transactions'] as List)) {
            final t = Map<String, dynamic>.from(raw as Map);
            _merchantUsdTransactions.add(
              UsdTransactionModel(
                id: t['id']?.toString() ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
                senderId: t['senderId']?.toString() ?? 'MRC',
                senderName: t['senderName']?.toString() ?? 'Merchant',
                senderRole: 'Merchant',
                agencyId: null,
                agencyName: null,
                recipientId: t['recipientId']?.toString() ?? 'MRC',
                recipientName: t['notes']?.toString() ?? 'ZeParty System',
                recipientType: 'Merchant',
                usdAmount: double.tryParse(t['usdAmount']?.toString() ?? '0') ?? 0.0,
                payoutPeriod: t['payoutPeriod']?.toString() ?? 'Ledger Record',
                timestamp: DateTime.tryParse(t['timestamp']?.toString() ?? '') ?? DateTime.now(),
                referenceId: t['referenceId']?.toString() ?? 'REF',
                status: t['status']?.toString() ?? 'Completed',
                type: t['type']?.toString() ?? 'USD Transaction',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[UsdBalanceProvider] fetchMerchantUsdBalance error: $e');
    } finally {
      _isLoadingMerchantUsd = false;
      notifyListeners();
    }
  }

  Future<String?> exchangeUsdToCoinsRemote({
    required double usdAmount,
    int ratePerDollar = 7000,
  }) async {
    if (usdAmount <= 0) return 'Invalid USD amount. Must be greater than 0.';
    if (usdAmount > _merchantAvailableUsd) {
      return 'Requested amount (\$${usdAmount.toStringAsFixed(2)}) exceeds available USD balance (\$${_merchantAvailableUsd.toStringAsFixed(2)}).';
    }

    try {
      final res = await ApiClient.instance.post(
        '/v1/merchants/exchange-usd',
        data: {
          'usdAmount': usdAmount,
          'ratePerDollar': ratePerDollar,
        },
      );

      if (res.statusCode == 200 && res.data?['success'] == true) {
        // Refetch authoritative balance after exchange
        await fetchMerchantUsdBalance();
        return null;
      } else {
        return res.data?['message']?.toString() ?? 'Failed to exchange USD to coins.';
      }
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Network error executing exchange: $e';
    }
  }

  // Transfer USD between Coin Sellers and Merchants
  String? transferUsd({
    required String senderType, // 'Coin Seller' or 'Merchant'
    required SellerMerchantRecipient recipient,
    required double usdAmount,
  }) {
    if (usdAmount <= 0) return 'Invalid transfer amount.';

    if (senderType == 'Coin Seller') {
      if (usdAmount > _sellerAvailableUsd) return 'Insufficient available USD balance.';
      _sellerAvailableUsd -= usdAmount;
    } else {
      if (usdAmount > _merchantAvailableUsd) return 'Insufficient available USD balance.';
      _merchantAvailableUsd -= usdAmount;
    }

    final refId = 'TRF-USD-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    final outgoingTx = UsdTransactionModel(
      id: 'tx_out_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderType == 'Coin Seller' ? 'SEL-101' : 'MRC-201',
      senderName: senderType == 'Coin Seller' ? 'Global Reseller Alpha' : 'ZeParty Premier Merchant',
      senderRole: senderType,
      recipientId: recipient.id,
      recipientName: recipient.name,
      recipientType: recipient.type,
      usdAmount: usdAmount,
      payoutPeriod: 'Direct USD Transfer',
      timestamp: DateTime.now(),
      referenceId: refId,
      status: 'Completed',
      type: 'Direct Transfer',
    );

    if (senderType == 'Coin Seller') {
      _sellerUsdTransactions.insert(0, outgoingTx);
    } else {
      _merchantUsdTransactions.insert(0, outgoingTx);
    }

    if (recipient.type == 'Coin Seller') {
      _sellerAvailableUsd += usdAmount;
      _sellerTotalReceivedUsd += usdAmount;
      _sellerUsdTransactions.insert(0, outgoingTx);
    } else {
      _merchantAvailableUsd += usdAmount;
      _merchantTotalReceivedUsd += usdAmount;
      _merchantUsdTransactions.insert(0, outgoingTx);
    }

    notifyListeners();
    return null;
  }
}
