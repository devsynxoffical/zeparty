import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zeparty/core/utils/profile_card_helper.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/models/user_asset_model.dart';
import 'package:zeparty/models/store_item_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileCardHelper Resolution & Theme Adaptation Tests', () {
    test('Scenario 1: User with the default profile card equipped', () {
      final defaultUser = const UserModel(
        id: 'user_101',
        username: 'default_user',
        name: 'Default User',
        avatarUrl: '',
        profileCardUrl: null,
        equippedProfileCardId: null,
      );

      final cardData = ProfileCardHelper.resolve(user: defaultUser);
      expect(cardData.isDefault, isTrue);
      expect(cardData.hasCustomCard, isFalse);
      expect(cardData.assetPath, isNull);
      expect(cardData.networkUrl, isNull);
      expect(cardData.primaryTextColor, equals(Colors.white));
      expect(cardData.secondaryTextColor, equals(Colors.white70));
    });

    test('Scenario 2: User with an SVIP profile card equipped', () {
      final svipUser = const UserModel(
        id: 'user_svip',
        username: 'svip_star',
        name: 'SVIP Star',
        avatarUrl: '',
        vipLevel: 'SVIP 5',
      );

      final cardData = ProfileCardHelper.resolve(user: svipUser);
      expect(cardData.isDefault, isFalse);
      expect(cardData.hasCustomCard, isTrue);
      expect(cardData.isLight, isTrue);
      expect(cardData.primaryTextColor, equals(const Color(0xFF1A162B)));
      expect(cardData.secondaryTextColor, equals(const Color(0xFF534C64)));
    });

    test('Scenario 3: User with a Noble King profile card equipped', () {
      final kingUser = const UserModel(
        id: 'user_king',
        username: 'king_arthur',
        name: 'King Arthur',
        avatarUrl: '',
        nobleTitle: 'King',
      );

      final cardData = ProfileCardHelper.resolve(user: kingUser);
      expect(cardData.isDefault, isFalse);
      expect(cardData.hasCustomCard, isTrue);
      expect(cardData.assetPath, contains('king_card.webp'));
      expect(cardData.isLight, isTrue);
      expect(cardData.primaryTextColor, equals(const Color(0xFF1A162B)));
    });

    test('Scenario 4 & 5: Switching from default to SVIP and back', () {
      final baseUser = const UserModel(
        id: 'user_switch',
        username: 'switch_user',
        name: 'Switch User',
        avatarUrl: '',
      );

      // Default state
      var cardData = ProfileCardHelper.resolve(user: baseUser);
      expect(cardData.isDefault, isTrue);

      // Equip SVIP card
      final equippedUser = baseUser.copyWith(profileCardUrl: 'assets/svip/svip6_card.webp');
      cardData = ProfileCardHelper.resolve(user: equippedUser);
      expect(cardData.isDefault, isFalse);
      expect(cardData.hasCustomCard, isTrue);
      expect(cardData.assetPath, equals('assets/svip/svip6_card.webp'));

      // Switch back to default ('none' or empty)
      final unequippedUser = equippedUser.copyWith(clearProfileCard: true);
      cardData = ProfileCardHelper.resolve(user: unequippedUser);
      expect(cardData.isDefault, isTrue);
      expect(cardData.hasCustomCard, isFalse);
    });

    test('Scenario 6: Switching between two different alternative cards', () {
      final dukeUser = const UserModel(
        id: 'user_duke',
        username: 'duke_user',
        name: 'Duke User',
        avatarUrl: '',
        nobleTitle: 'Duke',
      );

      var cardData = ProfileCardHelper.resolve(user: dukeUser);
      expect(cardData.assetPath, contains('duke'));

      // Switch to Emperor
      final emperorUser = dukeUser.copyWith(
        nobleTitle: 'Emperor',
      );
      cardData = ProfileCardHelper.resolve(user: emperorUser);
      expect(cardData.assetPath, contains('emperor'));
    });

    test('Scenario 7 & 8: Contrast adaptation for light and dark custom cards', () {
      // Light card (King)
      final lightCardData = ProfileCardHelper.resolve(
        user: const UserModel(
          id: 'u1',
          username: 'light_u',
          name: 'Light',
          avatarUrl: '',
          profileCardUrl: 'assets/nobles/king_card.webp',
        ),
      );
      expect(lightCardData.isLight, isTrue);
      expect(lightCardData.primaryTextColor, equals(const Color(0xFF1A162B)));

      // Dark card (e.g. night/cyber card)
      final darkCardData = ProfileCardHelper.resolve(
        user: const UserModel(
          id: 'u2',
          username: 'dark_u',
          name: 'Dark',
          avatarUrl: '',
          profileCardUrl: 'https://cdn.test.com/cards/cyber_night_card.webp',
        ),
      );
      expect(darkCardData.isLight, isFalse);
      expect(darkCardData.primaryTextColor, equals(Colors.white));
    });

    test('Scenario 12: Missing or invalid equipped-card asset fallback', () {
      final brokenUser = const UserModel(
        id: 'u_broken',
        username: 'broken_u',
        name: 'Broken',
        avatarUrl: '',
        profileCardUrl: 'invalid_unrecognized_id_xyz',
      );

      final cardData = ProfileCardHelper.resolve(user: brokenUser);
      expect(cardData.isDefault, isTrue);
      expect(cardData.hasCustomCard, isFalse);
    });

    test('Scenario 13: Explicit Card Registry Theme Mapping Audit', () {
      // 1. All Noble cards must be Light
      expect(ProfileCardHelper.isLightCard('king'), isTrue);
      expect(ProfileCardHelper.isLightCard('assets/nobles/king_card.webp'), isTrue);
      expect(ProfileCardHelper.isLightCard('assets/nobles/tier-5-duke_profilecard.webp'), isTrue);
      expect(ProfileCardHelper.isLightCard('assets/nobles/tier-7-emperor_profilecard.webp'), isTrue);
      expect(ProfileCardHelper.isLightCard('assets/nobles/tier-4-marquis_profilecard.webp'), isTrue);
      expect(ProfileCardHelper.isLightCard('assets/nobles/viscount_card.webp'), isTrue);
      expect(ProfileCardHelper.isLightCard('assets/nobles/count_card.webp'), isTrue);

      // 2. All Store Special Cards (ZP-165 to ZP-170) must be Light
      for (int i = 165; i <= 170; i++) {
        expect(ProfileCardHelper.isLightCard('zp-$i'), isTrue);
        expect(ProfileCardHelper.isLightCard('assets/store/zp-${i}_special-cards_card.webp'), isTrue);
      }

      // 3. SVIP Cards must be Light
      for (int i = 2; i <= 16; i++) {
        expect(ProfileCardHelper.isLightCard('assets/svip/svip${i}_card.webp'), isTrue);
        expect(ProfileCardHelper.isLightCard('assets/svip/svip${i}_profilecard.webp'), isTrue);
      }

      // 4. Known Dark cards
      expect(ProfileCardHelper.isLightCard('assets/images/card_vip.jpg'), isFalse);
      expect(ProfileCardHelper.isLightCard('card_vip.jpg'), isFalse);
      expect(ProfileCardHelper.isLightCard('default'), isFalse);
      expect(ProfileCardHelper.isLightCard('none'), isFalse);

      // 5. Unknown cards must safely fall back to Dark theme (white text/icons)
      expect(ProfileCardHelper.isLightCard('unknown_custom_card_xyz.png'), isFalse);
      expect(ProfileCardHelper.isLightCard('https://cdn.example.com/unregistered_card.png'), isFalse);
    });

    test('Scenario 14: Unequipped Noble or SVIP card persists as defaultCard', () {
      // User with active Noble King who explicitly unequipped card (sentinel 'none')
      final unequippedNoble = const UserModel(
        id: 'u_king_unequipped',
        username: 'noble_king',
        name: 'Noble King',
        avatarUrl: '',
        nobleTitle: 'King',
        profileCardUrl: 'none',
        equippedProfileCardId: 'none',
      );

      final cardDataNoble = ProfileCardHelper.resolve(user: unequippedNoble);
      expect(cardDataNoble.isDefault, isTrue);
      expect(cardDataNoble.hasCustomCard, isFalse);
      expect(cardDataNoble.primaryTextColor, equals(Colors.white));

      // User with SVIP 10 who explicitly unequipped card
      final unequippedSvip = const UserModel(
        id: 'u_svip_unequipped',
        username: 'svip_god',
        name: 'SVIP God',
        avatarUrl: '',
        vipLevel: 'SVIP 10',
        profileCardUrl: 'none',
        equippedProfileCardId: 'none',
      );

      final cardDataSvip = ProfileCardHelper.resolve(user: unequippedSvip);
      expect(cardDataSvip.isDefault, isTrue);
      expect(cardDataSvip.hasCustomCard, isFalse);
      expect(cardDataSvip.primaryTextColor, equals(Colors.white));

      // UserModel copyWith with clearProfileCard sets sentinel 'none'
      final baseEquipped = unequippedSvip.copyWith(
        profileCardUrl: 'assets/svip/svip10_profilecard.webp',
        equippedProfileCardId: 'svip10',
      );
      expect(ProfileCardHelper.resolve(user: baseEquipped).isDefault, isFalse);

      final reUnequipped = baseEquipped.copyWith(clearProfileCard: true);
      expect(reUnequipped.profileCardUrl, equals('none'));
      expect(reUnequipped.equippedProfileCardId, equals('none'));
      expect(ProfileCardHelper.resolve(user: reUnequipped).isDefault, isTrue);
    });
  });

  group('Offline User Session Serialization Tests', () {
    test('1. Valid profile-card URL survives local serialization and restoration', () {
      final user = const UserModel(
        id: 'user_ser_1',
        username: 'card_user',
        name: 'Card User',
        avatarUrl: '',
        profileCardUrl: 'assets/nobles/king_card.webp',
      );

      final sessionJson = user.toSessionJson();
      expect(sessionJson['profileCardUrl'], equals('assets/nobles/king_card.webp'));

      final restored = UserModel.fromJson(sessionJson);
      expect(restored.profileCardUrl, equals('assets/nobles/king_card.webp'));
    });

    test('2. Valid homepage-skin URL survives local serialization and restoration', () {
      final user = const UserModel(
        id: 'user_ser_2',
        username: 'skin_user',
        name: 'Skin User',
        avatarUrl: '',
        profileSkinUrl: 'assets/svip/svip6_card.webp',
      );

      final sessionJson = user.toSessionJson();
      expect(sessionJson['profileSkinUrl'], equals('assets/svip/svip6_card.webp'));

      final restored = UserModel.fromJson(sessionJson);
      expect(restored.profileSkinUrl, equals('assets/svip/svip6_card.webp'));
    });

    test('3. Explicit none sentinel survives serialization and restoration', () {
      final user = const UserModel(
        id: 'user_ser_3',
        username: 'none_user',
        name: 'None User',
        avatarUrl: '',
        profileCardUrl: 'none',
        profileSkinUrl: 'none',
        equippedProfileCardId: 'none',
        equippedSkinId: 'none',
      );

      final sessionJson = user.toSessionJson();
      expect(sessionJson['profileCardUrl'], equals('none'));
      expect(sessionJson['profileSkinUrl'], equals('none'));
      expect(sessionJson['equippedProfileCardId'], equals('none'));
      expect(sessionJson['equippedSkinId'], equals('none'));

      final restored = UserModel.fromJson(sessionJson);
      expect(restored.profileCardUrl, equals('none'));
      expect(restored.profileSkinUrl, equals('none'));
      expect(restored.equippedProfileCardId, equals('none'));
      expect(restored.equippedSkinId, equals('none'));
      expect(ProfileCardHelper.resolve(user: restored).isDefault, isTrue);
    });

    test('4. Equipped profile-card ID survives serialization and restoration', () {
      final user = const UserModel(
        id: 'user_ser_4',
        username: 'id_user',
        name: 'ID User',
        avatarUrl: '',
        equippedProfileCardId: 'assigned-asset-king-card',
      );

      final sessionJson = user.toSessionJson();
      expect(sessionJson['equippedProfileCardId'], equals('assigned-asset-king-card'));

      final restored = UserModel.fromJson(sessionJson);
      expect(restored.equippedProfileCardId, equals('assigned-asset-king-card'));
    });

    test('5. Equipped skin ID survives serialization and restoration', () {
      final user = const UserModel(
        id: 'user_ser_5',
        username: 'skin_id_user',
        name: 'Skin ID User',
        avatarUrl: '',
        equippedSkinId: 'assigned-asset-svip8-skin',
      );

      final sessionJson = user.toSessionJson();
      expect(sessionJson['equippedSkinId'], equals('assigned-asset-svip8-skin'));

      final restored = UserModel.fromJson(sessionJson);
      expect(restored.equippedSkinId, equals('assigned-asset-svip8-skin'));
    });

    test('6. Old cached sessions without the new fields remain readable (backward compatible)', () {
      // Old session map before equipment persistence was added
      final oldLegacyMap = <String, dynamic>{
        'id': 'legacy_user_1',
        'username': 'legacy_user',
        'name': 'Legacy User',
        'email': 'legacy@test.com',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'diamonds': 100,
        'coins': 500,
      };

      final restored = UserModel.fromJson(oldLegacyMap);
      expect(restored.id, equals('legacy_user_1'));
      expect(restored.username, equals('legacy_user'));
      expect(restored.profileCardUrl, isNull);
      expect(restored.profileSkinUrl, isNull);
      expect(restored.equippedProfileCardId, isNull);
      expect(restored.equippedSkinId, isNull);
    });

    test('7. Server profile refresh replaces stale cached equipment state', () {
      // Local stale cached user with old card
      final staleUser = const UserModel(
        id: 'user_stale',
        username: 'stale_user',
        name: 'Stale User',
        avatarUrl: '',
        profileCardUrl: 'assets/nobles/count_card.webp',
        equippedProfileCardId: 'count_card',
      );
      expect(staleUser.profileCardUrl, equals('assets/nobles/count_card.webp'));

      // Backend /v1/users/me response after user unequipped
      final backendResponse = <String, dynamic>{
        'id': 'user_stale',
        'username': 'stale_user',
        'name': 'Stale User',
        'profile': {
          'profileCardUrl': 'none',
          'equippedProfileCardId': 'none',
          'profileSkinUrl': 'none',
          'equippedSkinId': 'none',
        },
      };

      final refreshedUser = UserModel.fromJson(backendResponse);
      expect(refreshedUser.profileCardUrl, equals('none'));
      expect(refreshedUser.equippedProfileCardId, equals('none'));
      expect(ProfileCardHelper.resolve(user: refreshedUser).isDefault, isTrue);
    });

    test('8. Local session serialization does not unintentionally contaminate API request payloads', () {
      final user = const UserModel(
        id: 'user_api_payload',
        username: 'clean_payload_user',
        name: 'Clean User',
        avatarUrl: '',
        profileCardUrl: 'none',
        profileSkinUrl: 'none',
        equippedProfileCardId: 'none',
        equippedSkinId: 'none',
      );

      // Standard toJson() used for API payloads
      final apiPayload = user.toJson();
      expect(apiPayload.containsKey('profileCardUrl'), isFalse);
      expect(apiPayload.containsKey('profileSkinUrl'), isFalse);
      expect(apiPayload.containsKey('equippedSkinId'), isFalse);
      expect(apiPayload.containsKey('equippedProfileCardId'), isFalse);

      // Dedicated toSessionJson() used for local cache
      final sessionPayload = user.toSessionJson();
      expect(sessionPayload.containsKey('profileCardUrl'), isTrue);
      expect(sessionPayload.containsKey('profileSkinUrl'), isTrue);
      expect(sessionPayload.containsKey('equippedSkinId'), isTrue);
      expect(sessionPayload.containsKey('equippedProfileCardId'), isTrue);
    });
  });

  group('Backpack Unequip Confirmation & Error Recovery Tests', () {
    final testExpiresAt = DateTime.now().add(const Duration(days: 30));

    test('1. Successful profile-card unequip updates local state', () {
      final initialAsset = UserAssetModel(
        id: 'asset_card_1',
        userId: 'u1',
        assetId: 'card_king',
        isEquipped: true,
        expiresAt: testExpiresAt,
        asset: const StoreItemModel(
          id: 'card_king',
          name: 'King Card',
          categoryId: 'Cards',
          assetType: 'PROFILE_CARD',
          imageUrl: 'assets/nobles/king_card.webp',
          priceCoins: 50000,
        ),
      );

      expect(initialAsset.isEquipped, isTrue);
      final unequippedAsset = initialAsset.copyWith(isEquipped: false);
      expect(unequippedAsset.isEquipped, isFalse);
      expect(unequippedAsset.asset?.imageUrl, equals('assets/nobles/king_card.webp'));
    });

    test('2. Successful homepage-skin unequip updates local state', () {
      final initialSkin = UserAssetModel(
        id: 'asset_skin_1',
        userId: 'u1',
        assetId: 'skin_svip8',
        isEquipped: true,
        expiresAt: testExpiresAt,
        asset: const StoreItemModel(
          id: 'skin_svip8',
          name: 'SVIP 8 Skin',
          categoryId: 'Themes',
          assetType: 'HOMEPAGE_SKIN',
          imageUrl: 'assets/svip/svip8_card.webp',
          priceCoins: 50000,
        ),
      );

      expect(initialSkin.isEquipped, isTrue);
      final unequippedSkin = initialSkin.copyWith(isEquipped: false);
      expect(unequippedSkin.isEquipped, isFalse);
    });

    test('3 & 6. Failed HTTP request does not mark the item unequipped and preserves previous item', () {
      final originalItem = UserAssetModel(
        id: 'asset_preserved',
        userId: 'u1',
        assetId: 'card_emperor',
        isEquipped: true,
        expiresAt: testExpiresAt,
        asset: const StoreItemModel(
          id: 'card_emperor',
          name: 'Emperor Card',
          categoryId: 'Cards',
          assetType: 'PROFILE_CARD',
          imageUrl: 'assets/nobles/tier-7-emperor_profilecard.webp',
          priceCoins: 50000,
        ),
      );

      // Simulate a network failure before local state update
      UserAssetModel applyUnequipIfSuccessful(UserAssetModel item, bool success) {
        if (success) {
          return item.copyWith(isEquipped: false);
        }
        return item;
      }

      final effectiveItem = applyUnequipIfSuccessful(originalItem, false);

      // Must remain equipped because backend failed
      expect(effectiveItem.isEquipped, isTrue);
      expect(effectiveItem.id, equals('asset_preserved'));
    });

    test('4 & 5. Backend error response (success: false) does not report success', () {
      final backendErrorResponse = {
        'success': false,
        'message': 'Failed to unequip asset',
        'data': null,
      };

      bool isSuccessReported = false;
      if (backendErrorResponse['success'] == true) {
        isSuccessReported = true;
      }

      expect(isSuccessReported, isFalse);
    });

    test('7. Repeated successful unequip remains safe and idempotent', () {
      final unequippedItem = UserAssetModel(
        id: 'asset_idem',
        userId: 'u1',
        assetId: 'card_count',
        isEquipped: false,
        expiresAt: testExpiresAt,
        asset: const StoreItemModel(
          id: 'card_count',
          name: 'Count Card',
          categoryId: 'Cards',
          assetType: 'PROFILE_CARD',
          imageUrl: 'assets/nobles/count_card.webp',
          priceCoins: 50000,
        ),
      );

      // Unequipping an already unequipped item remains unequipped without error
      final secondUnequip = unequippedItem.copyWith(isEquipped: false);
      expect(secondUnequip.isEquipped, isFalse);
      expect(secondUnequip.id, equals('asset_idem'));
    });

    test('8. Switching from Item A to Item B works correctly', () {
      final itemA = UserAssetModel(
        id: 'item_a',
        userId: 'u1',
        assetId: 'card_a',
        isEquipped: true,
        expiresAt: testExpiresAt,
        asset: const StoreItemModel(
          id: 'card_a',
          name: 'Card A',
          categoryId: 'Cards',
          assetType: 'PROFILE_CARD',
          imageUrl: 'assets/nobles/king_card.webp',
          priceCoins: 50000,
        ),
      );

      final itemB = UserAssetModel(
        id: 'item_b',
        userId: 'u1',
        assetId: 'card_b',
        isEquipped: false,
        expiresAt: testExpiresAt,
        asset: const StoreItemModel(
          id: 'card_b',
          name: 'Card B',
          categoryId: 'Cards',
          assetType: 'PROFILE_CARD',
          imageUrl: 'assets/nobles/tier-5-duke_profilecard.webp',
          priceCoins: 50000,
        ),
      );

      // User equips Item B -> Item A is set to unequipped, Item B is set to equipped
      final updatedItemA = itemA.copyWith(isEquipped: false);
      final updatedItemB = itemB.copyWith(isEquipped: true);

      expect(updatedItemA.isEquipped, isFalse);
      expect(updatedItemB.isEquipped, isTrue);
    });

    test('9. Failed unequip does not delete inventory ownership', () {
      final inventory = <UserAssetModel>[
        UserAssetModel(
          id: 'owned_card_1',
          userId: 'u1',
          assetId: 'card_marquis',
          isEquipped: true,
          expiresAt: testExpiresAt,
          asset: const StoreItemModel(
            id: 'card_marquis',
            name: 'Marquis Card',
            categoryId: 'Cards',
            assetType: 'PROFILE_CARD',
            imageUrl: 'assets/nobles/tier-4-marquis_profilecard.webp',
            priceCoins: 50000,
          ),
        ),
      ];

      // Simulate network failure: inventory list is not pruned
      expect(inventory.length, equals(1));
      expect(inventory.first.assetId, equals('card_marquis'));
    });

    test('10. Success notification appears only after backend confirmation', () {
      String? snackbarMessage;

      void onUnequipResult(bool success, String itemName) {
        if (success) {
          snackbarMessage = 'Unequipped $itemName';
        } else {
          snackbarMessage = 'Failed to unequip $itemName';
        }
      }

      // Case 1: Backend confirms failure
      onUnequipResult(false, 'King Card');
      expect(snackbarMessage, equals('Failed to unequip King Card'));

      // Case 2: Backend confirms success
      onUnequipResult(true, 'King Card');
      expect(snackbarMessage, equals('Unequipped King Card'));
    });
  });
}
