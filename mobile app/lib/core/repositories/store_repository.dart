import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../../models/store_item_model.dart';

class StoreRepository {
  static final StoreRepository instance = StoreRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  StoreRepository._internal();

  /// Fetch active store catalog from backend
  Future<List<StoreItemModel>> fetchStoreCatalog({
    int page = 1,
    int limit = 50,
    String? assetType,
    bool? isVipExclusive,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (assetType != null && assetType.isNotEmpty && assetType.toUpperCase() != 'ALL') {
      queryParams['assetType'] = assetType.toUpperCase();
    }
    if (isVipExclusive != null) {
      queryParams['isVipExclusive'] = isVipExclusive;
    }

    final response = await _apiClient.get(
      '/v1/store/catalog',
      queryParameters: queryParams,
    );

    final data = response.data?['data'] as List? ?? [];
    return data
        .map((item) => StoreItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Purchase an asset using coins on the backend
  Future<Map<String, dynamic>> purchaseAsset({
    required String assetId,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['idempotency-key'] = idempotencyKey;
    }

    final response = await _apiClient.post(
      '/v1/store/purchase',
      data: {
        'assetId': assetId,
      },
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }
}
