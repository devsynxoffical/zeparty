import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../../models/gift_model.dart';

class GiftRepository {
  static final GiftRepository instance = GiftRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  GiftRepository._internal();

  /// Fetch public active gifts catalog from backend
  Future<List<GiftModel>> fetchGifts({
    String? category,
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (category != null && category.isNotEmpty && category.toUpperCase() != 'ALL') {
      final cat = category.toUpperCase();
      if (cat.contains('POPULAR') || cat.contains('CLASSIC')) {
        queryParams['giftCategory'] = 'POPULAR';
      } else if (cat.contains('LUXURY') || cat.contains('EVENT') || cat.contains('SPECIAL')) {
        queryParams['giftCategory'] = 'LUXURY';
      } else if (cat.contains('VIP') || cat.contains('PRIVILEGE')) {
        queryParams['giftCategory'] = 'VIP';
      } else if (cat.contains('AUDIO')) {
        queryParams['giftCategory'] = 'AUDIO';
      } else {
        queryParams['giftCategory'] = cat;
      }
    }

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.get(
      '/v1/gifts',
      queryParameters: queryParams,
    );

    final data = response.data?['data'] as List? ?? [];
    return data
        .map((item) => GiftModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Send gift to host/participant atomically via backend
  Future<Map<String, dynamic>> sendGift({
    required String giftId,
    required String recipientUserId,
    int quantity = 1,
    String? roomId,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{};
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['idempotency-key'] = idempotencyKey;
    }

    final response = await _apiClient.post(
      '/v1/gifts/send',
      data: {
        'giftId': giftId,
        'recipientUserId': recipientUserId,
        'quantity': quantity,
        if (roomId != null && roomId.isNotEmpty) 'roomId': roomId,
      },
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );

    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }
}
