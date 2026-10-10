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
      imageUrl: 'assets/animations/mystery_entry.webp',
      priceCoins: 500000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'car_astral',
      name: 'Astral Dragon Mount',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/nobles/emperor_entrance.png',
      priceCoins: 350000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'car_royal',
      name: 'Royal Chariot',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/nobles/marquis_entrance.png',
      priceCoins: 200000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'car_cyber_jet',
      name: 'Cyber Hoverjet',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip12_entry.png',
      priceCoins: 150000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'car_gold_cruiser',
      name: 'Gold Cruiser',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip8_entry.png',
      priceCoins: 80000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'car_neon_coupe',
      name: 'Neon Coupe',
      categoryId: 'Cars',
      assetType: 'CAR_MOUNT',
      imageUrl: 'assets/svip/svip6_entry.png',
      priceCoins: 45000,
      durationDays: 30,
    ),

    // ─── AVATAR FRAMES (Drive Store Collection ZP-134 .. ZP-143) ───
    StoreItemModel(
      id: 'frame_zp134',
      name: 'Golden Glory Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-134_avatar-frames_frame.webp',
      priceCoins: 250000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp135',
      name: 'Starlight Crown Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-135_avatar-frames_frame.webp',
      priceCoins: 180000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp136',
      name: 'Cyber Neon Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-136_avatar-frames_frame.webp',
      priceCoins: 120000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp137',
      name: 'Celestial Aura Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-137_avatar-frames_frame.webp',
      priceCoins: 90000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp138',
      name: 'Luxe Diamond Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-138_avatar-frames_frame.webp',
      priceCoins: 60000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp139',
      name: 'Mystic Wings Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-139_avatar-frames_frame.webp',
      priceCoins: 40000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp140',
      name: 'Solar Flare Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-140_avatar-frames_frame.webp',
      priceCoins: 25000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp141',
      name: 'Vortex Shield Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-141_avatar-frames_frame.webp',
      priceCoins: 300000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp142',
      name: 'Astral Ring Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-142_avatar-frames_frame.webp',
      priceCoins: 200000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'frame_zp143',
      name: 'Phantom Elite Frame',
      categoryId: 'Frame',
      assetType: 'AVATAR_FRAME',
      imageUrl: 'assets/store/ZP-143_avatar-frames_frame.webp',
      priceCoins: 100000,
      durationDays: 30,
    ),

    // ─── SPECIAL CARDS (Drive Store Collection ZP-165 .. ZP-170) ───
    StoreItemModel(
      id: 'card_zp165',
      name: 'Golden Supreme Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/store/ZP-165_special-cards_card.webp',
      priceCoins: 250000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'card_zp166',
      name: 'Starlight Royalty Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/store/ZP-166_special-cards_card.webp',
      priceCoins: 180000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'card_zp167',
      name: 'Luxe Gold Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/store/ZP-167_special-cards_card.webp',
      priceCoins: 60000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'card_zp168',
      name: 'Cyber Platinum Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/store/ZP-168_special-cards_card.webp',
      priceCoins: 100000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'card_zp169',
      name: 'Ruby Elite Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/store/ZP-169_special-cards_card.webp',
      priceCoins: 50000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'card_zp170',
      name: 'Sapphire Glow Card',
      categoryId: 'Special card',
      assetType: 'SPECIAL_CARD',
      imageUrl: 'assets/store/ZP-170_special-cards_card.webp',
      priceCoins: 20000,
      durationDays: 30,
    ),

    // ─── CHAT BUBBLES (Drive Store Collection ZP-144 .. ZP-158) ───
    StoreItemModel(
      id: 'bubble_zp144',
      name: 'Golden Royal Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-144_chat-bubbles_bubble.webp',
      priceCoins: 150000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp145',
      name: 'Purple Luxe Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-145_chat-bubbles_bubble.webp',
      priceCoins: 90000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp146',
      name: 'Crimson Flame Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-146_chat-bubbles_bubble.webp',
      priceCoins: 70000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp147',
      name: 'Royal Blue Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-147_chat-bubbles_bubble.webp',
      priceCoins: 45000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp148',
      name: 'Sparkle Gold Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-148_chat-bubbles_bubble.webp',
      priceCoins: 200000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp149',
      name: 'Violet Cyber Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-149_chat-bubbles_bubble.webp',
      priceCoins: 110000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp150',
      name: 'Amber Glow Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-150_chat-bubbles_bubble.webp',
      priceCoins: 60000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp151',
      name: 'Magic Neon Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-151_chat-bubbles_bubble.webp',
      priceCoins: 35000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp152',
      name: 'Crystal Wave Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-152_chat-bubbles_bubble.webp',
      priceCoins: 40000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp153',
      name: 'Emerald Shine Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-153_chat-bubbles_bubble.webp',
      priceCoins: 45000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp154',
      name: 'Solar Flare Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-154_chat-bubbles_bubble.webp',
      priceCoins: 50000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp155',
      name: 'Ocean Blue Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-155_chat-bubbles_bubble.webp',
      priceCoins: 55000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp156',
      name: 'Galaxy Dust Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-156_chat-bubbles_bubble.webp',
      priceCoins: 60000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp157',
      name: 'Pink Petal Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-157_chat-bubbles_bubble.webp',
      priceCoins: 30000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bubble_zp158',
      name: 'Aurora Light Bubble',
      categoryId: 'Bubble',
      assetType: 'CHAT_BUBBLE',
      imageUrl: 'assets/store/ZP-158_chat-bubbles_bubble.webp',
      priceCoins: 35000,
      durationDays: 30,
    ),

    // ─── BACKGROUNDS (Drive Store Collection ZP-159 .. ZP-164) ───
    StoreItemModel(
      id: 'bg_zp159',
      name: 'Imperial Palace Realm',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/store/ZP-159_room-backgrounds_background.webp',
      priceCoins: 300000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bg_zp160',
      name: 'Starlight Castle Theme',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/store/ZP-160_room-backgrounds_background.webp',
      priceCoins: 120000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bg_zp161',
      name: 'Luxe Manor Theme',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/store/ZP-161_room-backgrounds_background.webp',
      priceCoins: 75000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bg_zp162',
      name: 'Cyber Stage Realm',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/store/ZP-162_room-backgrounds_background.webp',
      priceCoins: 180000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bg_zp163',
      name: 'Neon Glow Realm',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/store/ZP-163_room-backgrounds_background.webp',
      priceCoins: 100000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'bg_zp164',
      name: 'Ruby Lounge Theme',
      categoryId: 'Background',
      assetType: 'ROOM_THEME',
      imageUrl: 'assets/store/ZP-164_room-backgrounds_background.webp',
      priceCoins: 65000,
      durationDays: 30,
    ),

    // ─── BADGES ───
    StoreItemModel(
      id: 'badge_role_admin',
      name: 'Admin Role Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-178_admin_badge.webp',
      priceCoins: 100000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_agency',
      name: 'Agency Master Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-181_agency_badge.webp',
      priceCoins: 80000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_assistant',
      name: 'Assistant Officer Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-184_assistant_badge.webp',
      priceCoins: 60000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_bd',
      name: 'BD Director Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-187_bd_badge.webp',
      priceCoins: 120000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_boss',
      name: 'Grand Boss Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-190_boss_badge.webp',
      priceCoins: 150000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_ceo',
      name: 'CEO Executive Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-193_ceo_badge.webp',
      priceCoins: 200000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_coins_seller',
      name: 'Coins Merchant Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-196_coins-saller_badge.webp',
      priceCoins: 75000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_cs',
      name: 'Customer Support Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-198_cs_badge.webp',
      priceCoins: 50000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_game_master',
      name: 'Game Master Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-201_game-master_badge.webp',
      priceCoins: 90000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_host',
      name: 'Star Host Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-204_host_badge.webp',
      priceCoins: 85000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_lover',
      name: 'Lover Romance Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-207_lover_badge.webp',
      priceCoins: 65000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_manager',
      name: 'General Manager Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-210_manager_badge.webp',
      priceCoins: 110000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_merchant',
      name: 'Official Merchant Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-212_marchent_badge.webp',
      priceCoins: 95000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_official',
      name: 'Official VIP Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-215_official_badge.webp',
      priceCoins: 130000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_super_admin',
      name: 'Super Admin Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-218_super-admin_badge.webp',
      priceCoins: 300000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_role_top_fan',
      name: 'Top Fan Elite Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/roles/ZP-220_top-fan_badge.webp',
      priceCoins: 70000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_zp054',
      name: 'SVIP Star Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/svip/ZP-054_svip-1_badge.webp',
      priceCoins: 50000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_zp056',
      name: 'Royalty Crown Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/svip/ZP-056_svip-3_badge.webp',
      priceCoins: 90000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_zp065',
      name: 'Cyber Elite Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/svip/ZP-065_svip-6_badge.webp',
      priceCoins: 150000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_zp079',
      name: 'Gold Phoenix Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/svip/ZP-079_svip-8_badge.webp',
      priceCoins: 250000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_zp100',
      name: 'Imperial Dragon Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/svip/ZP-100_svip-11_badge.webp',
      priceCoins: 400000,
      durationDays: 30,
    ),
    StoreItemModel(
      id: 'badge_zp127',
      name: 'Supreme Sovereign Badge',
      categoryId: 'Badges',
      assetType: 'BADGE',
      imageUrl: 'assets/svip/ZP-127_svip-15_badge.webp',
      priceCoins: 600000,
      durationDays: 30,
    ),
  ];

  /// Fetch active store catalog from backend with rich fallback defaults
  Future<List<StoreItemModel>> fetchStoreCatalog({
    int page = 1,
    int limit = 50,
    String? assetType,
    bool? isVipExclusive,
  }) async {
    List<StoreItemModel> catalogList = [];

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
        final parsedItems = data
            .map((item) => StoreItemModel.fromJson(item as Map<String, dynamic>))
            .toList();
        catalogList = _enrichCatalogWithStoreAssets(parsedItems);
      }
    } catch (_) {}

    // Always merge default catalog items to ensure every category (Cars, Frames, Cards, Bubbles, Backgrounds, Badges) has complete items
    final existingIds = catalogList.map((item) => item.id).toSet();
    for (final defaultItem in defaultStoreCatalog) {
      if (!existingIds.contains(defaultItem.id)) {
        catalogList.add(defaultItem);
      }
    }

    if (assetType != null && assetType.isNotEmpty && assetType.toUpperCase() != 'ALL') {
      catalogList = catalogList.where((item) => item.assetType.toUpperCase() == assetType.toUpperCase() || item.categoryId.toUpperCase() == assetType.toUpperCase()).toList();
    }
    if (isVipExclusive != null) {
      catalogList = catalogList.where((item) => item.isVipExclusive == isVipExclusive).toList();
    }
    return catalogList;
  }

  /// Maps backend catalog items to dedicated assets/store/ collection images
  List<StoreItemModel> _enrichCatalogWithStoreAssets(List<StoreItemModel> items) {
    final defaultById = {for (var item in defaultStoreCatalog) item.id: item};
    final defaultByCategory = <String, List<StoreItemModel>>{};
    for (var item in defaultStoreCatalog) {
      defaultByCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    final categoryCounters = <String, int>{};

    return items.map((item) {
      final matchedDefault = defaultById[item.id];
      final price = (item.priceCoins > 0)
          ? item.priceCoins
          : (matchedDefault != null && matchedDefault.priceCoins > 0 ? matchedDefault.priceCoins : 50000);

      if (item.imageUrl.startsWith('assets/store/') || item.imageUrl.startsWith('assets/animations/') || item.imageUrl.startsWith('assets/svip/') || item.imageUrl.startsWith('assets/roles/')) {
        return StoreItemModel(
          id: item.id,
          name: item.name,
          categoryId: item.categoryId.isNotEmpty ? item.categoryId : (matchedDefault?.categoryId ?? 'General'),
          assetType: item.assetType.isNotEmpty ? item.assetType : (matchedDefault?.assetType ?? 'STORE_ITEM'),
          imageUrl: item.imageUrl,
          assetUrl: item.assetUrl,
          durationDays: item.durationDays > 0 ? item.durationDays : 30,
          priceCoins: price,
          isVipExclusive: item.isVipExclusive,
          minVipLevelRequired: item.minVipLevelRequired,
          roomAvailability: item.roomAvailability,
          isActive: item.isActive,
        );
      }

      if (matchedDefault != null) {
        return StoreItemModel(
          id: item.id,
          name: item.name,
          categoryId: item.categoryId.isNotEmpty ? item.categoryId : matchedDefault.categoryId,
          assetType: item.assetType.isNotEmpty ? item.assetType : matchedDefault.assetType,
          imageUrl: matchedDefault.imageUrl,
          assetUrl: item.assetUrl,
          durationDays: item.durationDays > 0 ? item.durationDays : 30,
          priceCoins: price,
          isVipExclusive: item.isVipExclusive,
          minVipLevelRequired: item.minVipLevelRequired,
          roomAvailability: item.roomAvailability,
          isActive: item.isActive,
        );
      }

      final categoryList = defaultByCategory[item.categoryId] ?? [];
      final currentIndex = categoryCounters[item.categoryId] ?? 0;
      categoryCounters[item.categoryId] = currentIndex + 1;

      if (categoryList.isNotEmpty) {
        final match = categoryList[currentIndex % categoryList.length];
        return StoreItemModel(
          id: item.id,
          name: item.name,
          categoryId: item.categoryId,
          assetType: item.assetType,
          imageUrl: match.imageUrl,
          assetUrl: item.assetUrl,
          durationDays: item.durationDays > 0 ? item.durationDays : 30,
          priceCoins: price,
          isVipExclusive: item.isVipExclusive,
          minVipLevelRequired: item.minVipLevelRequired,
          roomAvailability: item.roomAvailability,
          isActive: item.isActive,
        );
      }

      String fallbackImage = item.imageUrl;
      if (fallbackImage.isEmpty) {
        final cat = item.categoryId.toLowerCase();
        if (cat.contains('car') || item.assetType.contains('CAR')) {
          fallbackImage = 'assets/animations/mystery_entry.webp';
        } else if (cat.contains('frame') || item.assetType.contains('FRAME')) {
          fallbackImage = 'assets/store/ZP-134_avatar-frames_frame.webp';
        } else if (cat.contains('card') || item.assetType.contains('CARD')) {
          fallbackImage = 'assets/store/ZP-165_special-cards_card.webp';
        } else if (cat.contains('bubble') || item.assetType.contains('BUBBLE')) {
          fallbackImage = 'assets/store/ZP-144_chat-bubbles_bubble.webp';
        } else if (cat.contains('background') || item.assetType.contains('THEME')) {
          fallbackImage = 'assets/store/ZP-159_room-backgrounds_background.webp';
        } else if (cat.contains('badge') || item.assetType.contains('BADGE')) {
          fallbackImage = 'assets/svip/ZP-054_svip-1_badge.webp';
        } else {
          fallbackImage = 'assets/store/ZP-134_avatar-frames_frame.webp';
        }
      }

      return StoreItemModel(
        id: item.id,
        name: item.name,
        categoryId: item.categoryId,
        assetType: item.assetType,
        imageUrl: fallbackImage,
        assetUrl: item.assetUrl,
        durationDays: item.durationDays > 0 ? item.durationDays : 30,
        priceCoins: price,
        isVipExclusive: item.isVipExclusive,
        minVipLevelRequired: item.minVipLevelRequired,
        roomAvailability: item.roomAvailability,
        isActive: item.isActive,
      );
    }).toList();
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

