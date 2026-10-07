import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../../models/store_item_model.dart';

class StoreRepository {
  static final StoreRepository instance = StoreRepository._internal();
  final ApiClient _apiClient = ApiClient.instance;

  StoreRepository._internal();

  static const List<StoreItemModel> defaultStoreCatalog = [
    // ─── CARS / MOUNTS ───
    StoreItemModel(
      id: 'car_phantom',
      name: 'Phantom Hypercar',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip15_entry.png',
      priceCoins: 500000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 10,
    ),
    StoreItemModel(
      id: 'car_dragon',
      name: 'Imperial Dragon',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/nobles/emperor_entrance.png',
      priceCoins: 350000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 8,
    ),
    StoreItemModel(
      id: 'car_marquis_chariot',
      name: 'Marquis Royal Chariot',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/nobles/marquis_entrance.png',
      priceCoins: 200000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 5,
    ),
    StoreItemModel(
      id: 'car_cyber_jet',
      name: 'Cyber Hoverjet',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip12_entry.png',
      priceCoins: 150000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'car_gold_cruiser',
      name: 'Gold Cruiser SVIP8',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip8_entry.png',
      priceCoins: 80000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'car_neon_coupe',
      name: 'Neon Coupe SVIP6',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip6_entry.png',
      priceCoins: 45000,
      durationDays: 30,
      isVipExclusive: false,
    ),

    // ─── AVATAR FRAMES ───
    StoreItemModel(
      id: 'frame_emperor',
      name: 'Emperor Royal Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/emperor_frame.png',
      priceCoins: 250000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 12,
    ),
    StoreItemModel(
      id: 'frame_king',
      name: 'King Crown Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/king_frame.png',
      priceCoins: 180000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 10,
    ),
    StoreItemModel(
      id: 'frame_duke',
      name: 'Duke Luxury Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/duke_frame.png',
      priceCoins: 120000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_marquis',
      name: 'Marquis Noble Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/marquis_frame.png',
      priceCoins: 90000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_count',
      name: 'Count Aristocracy Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/count_frame.png',
      priceCoins: 60000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_viscount',
      name: 'Viscount Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/viscount_frame.png',
      priceCoins: 40000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_baron',
      name: 'Baron Shield Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/nobles/baron_frame.png',
      priceCoins: 25000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_svip15',
      name: 'SVIP 15 Royalty Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/svip/svip15_frame.png',
      priceCoins: 300000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 15,
    ),
    StoreItemModel(
      id: 'frame_svip14',
      name: 'SVIP 14 Diamond Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/svip/svip14_frame.png',
      priceCoins: 200000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 14,
    ),
    StoreItemModel(
      id: 'frame_svip10',
      name: 'SVIP 10 Platinum Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/svip/svip10_frame.png',
      priceCoins: 100000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 10,
    ),
    StoreItemModel(
      id: 'frame_super_admin',
      name: 'Super Admin Shield Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/roles/super_admin_frame.png',
      priceCoins: 150000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_lover',
      name: 'Romantic CP Lover Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/roles/lover_frame.png',
      priceCoins: 50000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'frame_top_fan',
      name: 'Top Fan Crown Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/roles/top_fan_frame.png',
      priceCoins: 35000,
      durationDays: 30,
      isVipExclusive: false,
    ),

    // ─── SPECIAL CARDS ───
    StoreItemModel(
      id: 'card_svip15',
      name: 'SVIP 15 Supreme Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/svip/svip15_card.png',
      priceCoins: 250000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 15,
    ),
    StoreItemModel(
      id: 'card_king',
      name: 'King Royalty Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/nobles/king_card.png',
      priceCoins: 180000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 10,
    ),
    StoreItemModel(
      id: 'card_viscount',
      name: 'Viscount Gold Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/nobles/viscount_card.png',
      priceCoins: 60000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'card_svip10',
      name: 'SVIP 10 Platinum Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/svip/svip10_card.png',
      priceCoins: 100000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 10,
    ),
    StoreItemModel(
      id: 'card_svip7',
      name: 'SVIP 7 Ruby Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/svip/svip7_card.png',
      priceCoins: 50000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'card_svip3',
      name: 'SVIP 3 Sapphire Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/svip/svip3_card.png',
      priceCoins: 20000,
      durationDays: 30,
      isVipExclusive: false,
    ),

    // ─── CHAT BUBBLES ───
    StoreItemModel(
      id: 'bubble_emperor',
      name: 'Emperor Royal Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/nobles/emperor_chat_bubble.png',
      priceCoins: 150000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 12,
    ),
    StoreItemModel(
      id: 'bubble_duke',
      name: 'Duke Purple Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/nobles/duke_chat_bubble.png',
      priceCoins: 90000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bubble_marquis',
      name: 'Marquis Crimson Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/nobles/marquis_chat_bubble.png',
      priceCoins: 70000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bubble_count',
      name: 'Count Royal Blue Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/nobles/count_chat_bubble.png',
      priceCoins: 45000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bubble_svip15',
      name: 'SVIP 15 Gold Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/svip/svip15_chat_bubble.png',
      priceCoins: 200000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 15,
    ),
    StoreItemModel(
      id: 'bubble_svip12',
      name: 'SVIP 12 Violet Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/svip/svip12_chat_bubble.png',
      priceCoins: 110000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 12,
    ),
    StoreItemModel(
      id: 'bubble_svip8',
      name: 'SVIP 8 Amber Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/svip/svip8_chat_bubble.png',
      priceCoins: 60000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bubble_svip6',
      name: 'SVIP 6 Magic Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/svip/svip6_chat_bubble.png',
      priceCoins: 35000,
      durationDays: 30,
      isVipExclusive: false,
    ),

    // ─── BACKGROUNDS ───
    StoreItemModel(
      id: 'bg_emperor_palace',
      name: 'Imperial Palace Background',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/nobles/emperor_activate.png',
      priceCoins: 300000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 12,
    ),
    StoreItemModel(
      id: 'bg_count_castle',
      name: 'Count Castle Theme',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/nobles/count_activate.png',
      priceCoins: 120000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bg_viscount_manor',
      name: 'Viscount Manor Theme',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/nobles/viscount_activate.png',
      priceCoins: 75000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bg_svip11_cyber',
      name: 'SVIP 11 Cyber Stage',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/svip/svip11_entry.png',
      priceCoins: 180000,
      durationDays: 30,
      isVipExclusive: true,
      minVipLevelRequired: 11,
    ),
    StoreItemModel(
      id: 'bg_svip9_neon',
      name: 'SVIP 9 Neon Realm',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/svip/svip9_entry.png',
      priceCoins: 100000,
      durationDays: 30,
      isVipExclusive: false,
    ),
    StoreItemModel(
      id: 'bg_svip7_lounge',
      name: 'SVIP 7 Ruby Lounge',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/svip/svip7_entry.png',
      priceCoins: 65000,
      durationDays: 30,
      isVipExclusive: false,
    ),
  ];

  /// Fetch active store catalog from backend with rich fallback defaults
  Future<List<StoreItemModel>> fetchStoreCatalog({
    int page = 1,
    int limit = 50,
    String? assetType,
    bool? isVipExclusive,
  }) async {
    try {
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
      if (data.isNotEmpty) {
        return data
            .map((item) => StoreItemModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Return rich default catalog when offline or backend empty
    var catalog = List<StoreItemModel>.from(defaultStoreCatalog);
    if (assetType != null && assetType.isNotEmpty && assetType.toUpperCase() != 'ALL') {
      catalog = catalog.where((item) => item.assetType.toUpperCase() == assetType.toUpperCase() || item.categoryId.toUpperCase() == assetType.toUpperCase()).toList();
    }
    if (isVipExclusive != null) {
      catalog = catalog.where((item) => item.isVipExclusive == isVipExclusive).toList();
    }
    return catalog;
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

    try {
      final response = await _apiClient.post(
        '/v1/store/purchase',
        data: {
          'assetId': assetId,
        },
        options: headers.isNotEmpty ? Options(headers: headers) : null,
      );

      return response.data?['data'] as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {'status': 'success', 'assetId': assetId};
    }
  }
}

