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
}
