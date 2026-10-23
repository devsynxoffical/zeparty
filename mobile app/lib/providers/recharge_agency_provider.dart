import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/api_client.dart';
import '../models/recharge_agency_model.dart';

class RechargeAgencyProvider extends ChangeNotifier {
  int _availableCoins = 0;
  final int _pendingCoins = 0;
  int _totalCoinsRecharged = 0;
  int _todaysRechargeTotal = 0;
  final int _dailyLimit = 0;
  String _sellerId = '';
  String _sellerName = 'Coin Reseller Agency';
  String _countryCode = 'GLOBAL';

  final List<SavedCustomerModel> _savedCustomers = [];
  final List<SellerRechargeTransactionModel> _transactions = [];
  final List<Map<String, dynamic>> _auditLogs = [];

  VerifiedRecipientModel? _verifiedRecipient;
  bool _isVerifyingRecipient = false;
  String? _verificationError;
  int _verificationRequestId = 0;

  bool _isExecutingTransfer = false;
  String? _transferError;
  String? _transferErrorCode;
  SellerRechargeResult? _lastTransferResult;

  bool _isLoadingHistory = false;
  bool _isLoadingMoreHistory = false;
  String? _historyError;
  int _historyCurrentPage = 1;
  int _historyTotalPages = 1;
  int _historyTotalCount = 0;

  int get availableCoins => _availableCoins;
  int get pendingCoins => _pendingCoins;
  int get totalCoinsRecharged => _totalCoinsRecharged;
  int get todaysRechargeTotal => _todaysRechargeTotal;
  int get dailyLimit => _dailyLimit;
  String get sellerId => _sellerId;
  String get sellerName => _sellerName;
  String get countryCode => _countryCode;

  VerifiedRecipientModel? get verifiedRecipient => _verifiedRecipient;
  bool get isVerifyingRecipient => _isVerifyingRecipient;
  String? get verificationError => _verificationError;
  String? get currentRecipientAccountId => _verifiedRecipient?.accountId;

  bool get isExecutingTransfer => _isExecutingTransfer;
  String? get transferError => _transferError;
  String? get transferErrorCode => _transferErrorCode;
  SellerRechargeResult? get lastTransferResult => _lastTransferResult;

  bool get isLoadingHistory => _isLoadingHistory;
  bool get isLoadingMoreHistory => _isLoadingMoreHistory;
  String? get historyError => _historyError;
  int get historyCurrentPage => _historyCurrentPage;
  int get historyTotalPages => _historyTotalPages;
  int get historyTotalCount => _historyTotalCount;
  bool get hasMoreHistory => _historyCurrentPage <= _historyTotalPages;

  List<SavedCustomerModel> get savedCustomers => List.unmodifiable(_savedCustomers);
  List<SellerRechargeTransactionModel> get transactions => List.unmodifiable(_transactions);
  List<Map<String, dynamic>> get auditLogs => List.unmodifiable(_auditLogs);

  RechargeAgencyProvider() {
    // Clean initial state
  }

  /// Synchronize authoritative seller details from current authenticated account
  void syncForSeller({
    required String sellerId,
    required String sellerName,
    required String countryCode,
    int? initialCoins,
  }) {
    // If switching seller accounts, reset transaction history to prevent leakage
    if (_sellerId.isNotEmpty && _sellerId != sellerId) {
      _transactions.clear();
      _savedCustomers.clear();
      _auditLogs.clear();
      _totalCoinsRecharged = 0;
      _todaysRechargeTotal = 0;
      _availableCoins = 0;
      _verifiedRecipient = null;
      _verificationError = null;
      _isVerifyingRecipient = false;
      _verificationRequestId++;
    }

    _sellerId = sellerId;
    _sellerName = sellerName;
    _countryCode = countryCode;
    if (initialCoins != null && initialCoins >= 0) {
      _availableCoins = initialCoins;
    }
    notifyListeners();
  }

  /// Reset provider state completely on logout or account switch
  void reset() {
    _availableCoins = 0;
    _totalCoinsRecharged = 0;
    _todaysRechargeTotal = 0;
    _sellerId = '';
    _sellerName = 'Coin Reseller Agency';
    _countryCode = 'GLOBAL';
    _savedCustomers.clear();
    _transactions.clear();
    _auditLogs.clear();
    _verifiedRecipient = null;
    _verificationError = null;
    _isVerifyingRecipient = false;
    _verificationRequestId++;
    notifyListeners();
  }

  /// Clear verified recipient state immediately on input change
  void clearVerifiedRecipient() {
    _verificationRequestId++;
    _verifiedRecipient = null;
    _verificationError = null;
    _isVerifyingRecipient = false;
    notifyListeners();
  }

  /// Authoritative Recipient Identity Resolution:
  /// GET /v1/sellers/verify-recipient?identifier=USER_PUBLIC_ID
  Future<VerifiedRecipientModel?> verifyRecipient(String identifier) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      clearVerifiedRecipient();
      return null;
    }

    final requestId = ++_verificationRequestId;
    _isVerifyingRecipient = true;
    _verificationError = null;
    _verifiedRecipient = null;
    notifyListeners();

    try {
      final response = await _fetchVerifiedRecipient(cleanId);

      // Prevent stale asynchronous responses from displaying wrong recipient
      if (requestId != _verificationRequestId) {
        return null;
      }

      final Map<String, dynamic> data = (response['data'] is Map<String, dynamic>)
          ? response['data'] as Map<String, dynamic>
          : response;

      final recipient = VerifiedRecipientModel.fromJson(data);
      _verifiedRecipient = recipient;
      _verificationError = null;
      return recipient;
    } on ApiException catch (e) {
      if (requestId != _verificationRequestId) return null;
      _verifiedRecipient = null;
      if (e.code == 'USER_NOT_FOUND' || e.statusCode == 404) {
        _verificationError = 'Recipient user ID does not exist. Please check the ID.';
      } else if (e.code == 'RECIPIENT_NOT_ACTIVE') {
        _verificationError = 'Recipient account is suspended or inactive.';
      } else {
        _verificationError = e.message.isNotEmpty ? e.message : 'Verification failed. Please try again.';
      }
      return null;
    } catch (e) {
      if (requestId != _verificationRequestId) return null;
      _verifiedRecipient = null;
      _verificationError = 'Network connection error. Please check your internet.';
      return null;
    } finally {
      if (requestId == _verificationRequestId) {
        _isVerifyingRecipient = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> _fetchVerifiedRecipient(String identifier) async {
    try {
      final res = await ApiClient.instance.get(
        '/v1/sellers/recharge/verify-recipient',
        queryParameters: {'identifier': identifier},
      );
      if (res.data is Map<String, dynamic>) {
        return res.data as Map<String, dynamic>;
      }
      throw ApiException(message: 'Invalid response format from server');
    } on ApiException catch (e) {
      // Fallback route if mounted directly under /v1/sellers/verify-recipient
      if (e.statusCode == 404 && e.message.contains('Cannot GET')) {
        final res = await ApiClient.instance.get(
          '/v1/sellers/verify-recipient',
          queryParameters: {'identifier': identifier},
        );
        if (res.data is Map<String, dynamic>) {
          return res.data as Map<String, dynamic>;
        }
      }
      rethrow;
    }
  }

  @visibleForTesting
  void setVerifiedRecipientForTesting(VerifiedRecipientModel? recipient) {
    _verifiedRecipient = recipient;
    _verificationError = null;
    _isVerifyingRecipient = false;
    notifyListeners();
  }

  /// Real Backend Transfer: POST /v1/sellers/recharge/transfer
  Future<SellerRechargeResult> executeRechargeTransfer({
    required String recipientIdentifier,
    required int coins,
    required String pin,
    String? notes,
  }) async {
    if (_isExecutingTransfer) {
      throw ApiException(
        message: 'A transfer request is already in progress. Please wait.',
        code: 'TRANSFER_IN_PROGRESS',
      );
    }

    if (coins <= 0) {
      throw ApiException(
        message: 'Please enter a valid coin amount greater than 0.',
        code: 'INVALID_AMOUNT',
      );
    }

    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      throw ApiException(
        message: 'Security PIN is required.',
        code: 'PIN_REQUIRED',
      );
    }

    _isExecutingTransfer = true;
    _transferError = null;
    _transferErrorCode = null;
    notifyListeners();

    final idempotencyKey = const Uuid().v4();

    try {
      final payload = {
        'recipientUserId': recipientIdentifier,
        'recipientIdentifier': recipientIdentifier,
        'amountCoins': coins,
        'pin': cleanPin,
        'securityPin': cleanPin,
        'idempotencyKey': idempotencyKey,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

      final response = await ApiClient.instance.post(
        '/v1/sellers/recharge/transfer',
        data: payload,
        options: Options(
          headers: {
            'Idempotency-Key': idempotencyKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      final Map<String, dynamic> rawData = (response.data is Map<String, dynamic>)
          ? response.data as Map<String, dynamic>
          : {};

      final Map<String, dynamic> data = (rawData['data'] is Map<String, dynamic>)
          ? rawData['data'] as Map<String, dynamic>
          : rawData;

      final result = SellerRechargeResult.fromJson(data);
      _lastTransferResult = result;

      // Authoritative server-confirmed balances
      if (result.remainingSellerBalanceCoins >= 0) {
        _availableCoins = result.remainingSellerBalanceCoins;
      }
      if (result.todayRechargedCoins >= 0) {
        _todaysRechargeTotal = result.todayRechargedCoins;
      }
      _totalCoinsRecharged += result.coins;

      // Create server-confirmed transaction record
      final serverTx = SellerRechargeTransactionModel(
        transactionId: result.referenceId,
        sellerId: _sellerId,
        sellerName: _sellerName,
        recipientUserId: result.recipientPublicId.isNotEmpty ? result.recipientPublicId : recipientIdentifier,
        recipientName: result.recipientName.isNotEmpty ? result.recipientName : (_verifiedRecipient?.nickname ?? 'User'),
        recipientAvatarUrl: _verifiedRecipient?.profileImage ?? '',
        coins: result.coins,
        feeOrBonus: 0,
        sellerBalanceBefore: _availableCoins + result.coins,
        sellerBalanceAfter: _availableCoins,
        status: result.status,
        countryCode: _countryCode,
        timestamp: DateTime.now(),
      );

      _transactions.removeWhere((t) => t.transactionId == result.referenceId);
      _transactions.insert(0, serverTx);

      _logAudit(
        action: 'COIN_RECHARGE_SUCCESS',
        targetId: recipientIdentifier,
        reason: 'Recharged ${result.coins} coins (Ref: ${result.referenceId})',
      );

      return result;
    } on ApiException catch (e) {
      _transferError = e.message;
      _transferErrorCode = e.code ?? (e.statusCode != null ? 'HTTP_${e.statusCode}' : null);
      rethrow;
    } catch (e) {
      _transferError = 'Network connection failure. Please check your internet connection.';
      _transferErrorCode = 'NETWORK_ERROR';
      throw ApiException(
        message: _transferError!,
        code: 'NETWORK_ERROR',
      );
    } finally {
      _isExecutingTransfer = false;
      notifyListeners();
    }
  }

  // Synchronous compatibility wrapper
  String? executeRecharge({
    required String recipientUserId,
    required String recipientName,
    required String recipientAvatarUrl,
    required int coins,
    required String pin,
  }) {
    executeRechargeTransfer(
      recipientIdentifier: recipientUserId,
      coins: coins,
      pin: pin,
    );
    return null;
  }

  /// Paginated Agency History: GET /v1/sellers/recharge/history
  Future<void> fetchRechargeHistory({bool refresh = false}) async {
    if (refresh) {
      _historyCurrentPage = 1;
      _historyError = null;
      _isLoadingHistory = true;
      notifyListeners();
    } else {
      if (_isLoadingMoreHistory || _historyCurrentPage > _historyTotalPages) return;
      _isLoadingMoreHistory = true;
      notifyListeners();
    }

    try {
      final pageToFetch = refresh ? 1 : _historyCurrentPage;
      final res = await ApiClient.instance.get(
        '/v1/sellers/recharge/history',
        queryParameters: {
          'page': pageToFetch,
          'limit': 20,
          'status': 'all',
        },
      );

      final Map<String, dynamic> raw = (res.data is Map<String, dynamic>)
          ? res.data as Map<String, dynamic>
          : {};

      final Map<String, dynamic> data = (raw['data'] is Map<String, dynamic>)
          ? raw['data'] as Map<String, dynamic>
          : raw;

      final List itemsRaw = (data['transactions'] as List?) ?? (data['items'] as List?) ?? [];
      final List<SellerRechargeTransactionModel> parsed = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map((j) => SellerRechargeTransactionModel.fromJson(j))
          .toList();

      final pagination = (data['pagination'] is Map<String, dynamic>)
          ? data['pagination'] as Map<String, dynamic>
          : data;

      _historyTotalPages = int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
      _historyTotalCount = int.tryParse(pagination['total']?.toString() ?? '${parsed.length}') ?? parsed.length;

      if (refresh) {
        _transactions.clear();
        _transactions.addAll(parsed);
        _historyCurrentPage = 2;
      } else {
        for (final item in parsed) {
          final exists = _transactions.any((t) => t.transactionId == item.transactionId);
          if (!exists) {
            _transactions.add(item);
          }
        }
        _historyCurrentPage++;
      }

      if (data['todayRecharged'] != null || data['todayRechargedCoins'] != null) {
        final tr = int.tryParse((data['todayRecharged'] ?? data['todayRechargedCoins']).toString());
        if (tr != null) _todaysRechargeTotal = tr;
      }

      _historyError = null;
    } on ApiException catch (e) {
      _historyError = e.message.isNotEmpty ? e.message : 'Failed to load transaction history.';
    } catch (e) {
      _historyError = 'Network error loading history. Tap to retry.';
    } finally {
      _isLoadingHistory = false;
      _isLoadingMoreHistory = false;
      notifyListeners();
    }
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
