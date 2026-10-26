import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../models/recharge_plan_model.dart';

class WalletRepository {
  static final WalletRepository instance = WalletRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  WalletRepository._internal();

  /// Fetch user's authoritative wallet balance from PostgreSQL backend
  Future<WalletModel> fetchWallet() async {
    final response = await _apiClient.get('/v1/wallet/balance');
    final data = response.data?['data'] as Map<String, dynamic>;
    return WalletModel.fromJson(data);
  }

  /// Fetch user's paginated ledger history from backend
  Future<List<TransactionModel>> fetchLedger({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (type != null && type.isNotEmpty && type != 'All') {
      queryParams['type'] = type;
    }

    final response = await _apiClient.get(
      '/v1/wallet/ledger',
      queryParameters: queryParams,
    );

    final items = response.data?['data'] as List? ?? [];
    return items
        .map((item) => TransactionModel.fromLedgerJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Fetch user's authoritative coin records from GET /v1/wallet/coin-records
  Future<Map<String, dynamic>> fetchCoinRecords({
    int page = 1,
    int limit = 20,
    String? tab,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (tab != null && tab.isNotEmpty) 'tab': tab,
      if (type != null && type.isNotEmpty && type != 'All Types') 'type': type,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    };

    final response = await _apiClient.get(
      '/v1/wallet/coin-records',
      queryParameters: queryParams,
    );

    final raw = (response.data is Map<String, dynamic>)
        ? response.data as Map<String, dynamic>
        : {};
    final data = (raw['data'] is Map<String, dynamic>)
        ? raw['data'] as Map<String, dynamic>
        : raw;

    final itemsRaw = (data['items'] as List?) ?? (data['records'] as List?) ?? [];
    final items = itemsRaw
        .whereType<Map<String, dynamic>>()
        .map((item) => TransactionModel.fromLedgerJson(item))
        .toList();

    return {
      'items': items,
      'pagination': data['pagination'] ?? {},
      'tabs': data['tabs'] ?? [],
      'activeTab': data['activeTab'] ?? tab ?? 'ALL',
    };
  }

  /// Fetch active recharge packages configured by Admin
  Future<List<RechargePlanModel>> fetchRechargePlans() async {
    final response = await _apiClient.get('/v1/recharge/plans');
    final items = response.data?['data'] as List? ?? [];
    return items
        .map((item) => RechargePlanModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Create payment intent for online recharge gateway (Stripe, PayPal, Braintree, etc.)
  Future<Map<String, dynamic>> createPaymentIntent({
    required String planId,
    required String paymentProvider,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null) {
      headers['idempotency-key'] = idempotencyKey;
    }

    final response = await _apiClient.post(
      '/v1/recharge/online/create-intent',
      data: {
        'planId': planId,
        'paymentProvider': paymentProvider,
      },
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Submit manual offline deposit receipt for admin review
  Future<Map<String, dynamic>> submitOfflineRecharge({
    required double amountUSD,
    required String bankName,
    required String receiptPhotoUrl,
    required String transactionRef,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null) {
      headers['idempotency-key'] = idempotencyKey;
    }

    final response = await _apiClient.post(
      '/v1/recharge/offline',
      data: {
        'amountUSD': amountUSD,
        'bankName': bankName,
        'receiptPhotoUrl': receiptPhotoUrl,
        'transactionRef': transactionRef,
      },
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Fetch real eligible recipients from GET /v1/wallet/transfer-receivers
  Future<Map<String, dynamic>> fetchTransferReceivers({
    String type = 'ALL',
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'type': type,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    final response = await _apiClient.get(
      '/v1/wallet/transfer-receivers',
      queryParameters: queryParams,
    );

    return (response.data?['data'] is Map<String, dynamic>)
        ? response.data['data'] as Map<String, dynamic>
        : (response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {});
  }

  /// Execute Diamond Transfer via POST /v1/wallet/diamonds/transfer
  Future<Map<String, dynamic>> transferDiamonds({
    required String recipientUserId,
    required int diamondAmount,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['idempotency-key'] = idempotencyKey;
    }

    final response = await _apiClient.post(
      '/v1/wallet/diamonds/transfer',
      data: {
        'recipientUserId': recipientUserId,
        'diamondAmount': diamondAmount,
      },
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );

    return (response.data is Map<String, dynamic>)
        ? response.data as Map<String, dynamic>
        : {};
  }
}
