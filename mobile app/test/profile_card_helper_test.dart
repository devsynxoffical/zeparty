import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zeparty/core/utils/profile_card_helper.dart';
import 'package:zeparty/models/user_model.dart';

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
}
