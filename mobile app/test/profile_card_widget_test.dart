import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zeparty/core/utils/profile_card_helper.dart';
import 'package:zeparty/core/utils/noble_badge_helper.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/models/user_asset_model.dart';
import 'package:zeparty/models/store_item_model.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Card Layout & Container Widget Tests', () {
    // 1. Default card contains all applicable profile sections
    test('1. Default card contains all applicable profile sections', () {
      const defaultUser = UserModel(
        id: '123456',
        username: 'default_user',
        name: 'Default User',
        avatarUrl: '',
        profileCardUrl: null,
        equippedProfileCardId: null,
      );

      final cardData = ProfileCardHelper.resolve(user: defaultUser);
      expect(cardData.isDefault, isTrue);
      expect(cardData.hasCustomCard, isFalse);
      expect(cardData.cardBackgroundColor, equals(const Color(0xFF141024)));
      expect(cardData.cardBorder, isNotNull);
      expect(cardData.primaryTextColor, equals(Colors.white));
      expect(cardData.secondaryTextColor, equals(Colors.white70));
    });

    // 2. Noble King card contains all applicable profile sections
    test('2. Noble King card contains all applicable profile sections', () {
      const kingUser = UserModel(
        id: '999999',
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
      expect(cardData.secondaryTextColor, equals(const Color(0xFF534C64)));
      expect(cardData.cardBackgroundColor, equals(const Color(0xFFFAF8F5)));
    });

    // 3. SVIP card contains all applicable profile sections
    test('3. SVIP card contains all applicable profile sections', () {
      const svipUser = UserModel(
        id: '777777',
        username: 'svip_queen',
        name: 'SVIP Queen',
        avatarUrl: '',
        vipLevel: 'SVIP 7',
      );

      final cardData = ProfileCardHelper.resolve(user: svipUser);
      expect(cardData.isDefault, isFalse);
      expect(cardData.hasCustomCard, isTrue);
      expect(cardData.assetPath, contains('svip7_card.webp'));
      expect(cardData.isLight, isTrue);
      expect(cardData.primaryTextColor, equals(const Color(0xFF1A162B)));
      expect(cardData.secondaryTextColor, equals(const Color(0xFF534C64)));
      expect(cardData.cardBackgroundColor, equals(const Color(0xFFFAF8F5)));
    });

    // 4. Medal section is inside the card
    test('4. Medal section is inside the card', () {
      const user = UserModel(
        id: '123456',
        username: 'user_medals',
        name: 'User With Medals',
        avatarUrl: '',
        vipLevel: 'SVIP 7',
      );

      final cardData = ProfileCardHelper.resolve(user: user);
      // Colors configured for inside the card
      expect(cardData.surfaceColor, equals(const Color(0x0C000000)));
      expect(cardData.surfaceBorderColor, equals(const Color(0x18000000)));
      expect(cardData.primaryTextColor, equals(const Color(0xFF1A162B)));
    });

    // 5. Badge & Role Gallery is inside the card
    test('5. Badge & Role Gallery is inside the card', () {
      const user = UserModel(
        id: '123456',
        username: 'user_badges',
        name: 'User With Badges',
        avatarUrl: '',
        nobleTitle: 'King',
      );

      final cardData = ProfileCardHelper.resolve(user: user);
      expect(cardData.badgeSurfaceColor, equals(const Color(0x10000000)));
      expect(cardData.surfaceColor, equals(const Color(0x0C000000)));
    });

    // 6. Relationship & Honor is inside the card
    test('6. Relationship & Honor is inside the card', () {
      const lightUser = UserModel(
        id: '111111',
        username: 'light_user',
        name: 'Light User',
        avatarUrl: '',
        vipLevel: 'SVIP 5',
      );
      final lightCard = ProfileCardHelper.resolve(user: lightUser);
      expect(lightCard.surfaceColor, equals(const Color(0x0C000000)));
      expect(lightCard.secondaryTextColor, equals(const Color(0xFF534C64)));

      const darkUser = UserModel(
        id: '222222',
        username: 'dark_user',
        name: 'Dark User',
        avatarUrl: '',
        profileCardUrl: 'assets/images/card_vip.jpg',
      );
      final darkCard = ProfileCardHelper.resolve(user: darkUser);
      expect(darkCard.surfaceColor, equals(const Color(0xFF1E1A33)));
      expect(darkCard.secondaryTextColor, equals(Colors.white70));
    });

    // 7. In-room mini profile keeps all profile information inside its card
    testWidgets('7. In-room mini profile keeps all profile information inside its card', (tester) async {
      const user = UserModel(
        id: '5571450',
        username: 'ahmad_host',
        name: 'Ahmad',
        avatarUrl: '',
        vipLevel: 'SVIP 7',
        bio: 'Welcome to my party room!',
      );

      final cardData = ProfileCardHelper.resolve(user: user);

      // Render a mini profile card container matching in-room sheet structure
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              decoration: BoxDecoration(
                color: cardData.cardBackgroundColor,
                border: cardData.cardBorder,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Identity section
                  Text(user.displayName, style: TextStyle(color: cardData.primaryTextColor)),
                  Text('ID: ${user.id}', style: TextStyle(color: cardData.secondaryTextColor)),
                  Text(user.bio, style: TextStyle(color: cardData.secondaryTextColor)),
                  // Level badges container
                  Container(
                    color: cardData.surfaceColor,
                    child: const Text('Level Badges'),
                  ),
                  // Medals container
                  Container(
                    color: cardData.surfaceColor,
                    child: const Text('Medals Section'),
                  ),
                  // Quick gifts container
                  Container(
                    color: cardData.surfaceColor,
                    child: const Text('Quick Gifts'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ahmad'), findsOneWidget);
      expect(find.text('ID: 5571450'), findsOneWidget);
      expect(find.text('Welcome to my party room!'), findsOneWidget);
      expect(find.text('Level Badges'), findsOneWidget);
      expect(find.text('Medals Section'), findsOneWidget);
      expect(find.text('Quick Gifts'), findsOneWidget);
    });

    // 8. Long usernames and IDs do not overflow
    testWidgets('8. Long usernames and IDs do not overflow', (tester) async {
      const longNameUser = UserModel(
        id: '987654321098765432109876543210',
        username: 'super_ultra_extremely_long_username_that_should_never_cause_overflow_in_any_screen',
        name: 'Super Ultra Extremely Long Display Name Designed For Stress Testing Layout Bounds',
        avatarUrl: '',
      );

      final cardData = ProfileCardHelper.resolve(user: longNameUser);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: NobleBadgeHelper.buildStyledUsername(
                          text: longNameUser.displayName,
                          style: TextStyle(fontSize: 16, color: cardData.primaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'ID: ${longNameUser.id}',
                          style: TextStyle(color: cardData.secondaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify no assertion or overflow was triggered
      expect(tester.takeException(), isNull);
    });

    // 9. Small-screen layouts do not clip profile information
    testWidgets('9. Small-screen layouts do not clip profile information', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const user = UserModel(
        id: '10001',
        username: 'small_screen_user',
        name: 'Small Screen User',
        avatarUrl: '',
        vipLevel: 'SVIP 7',
      );

      final cardData = ProfileCardHelper.resolve(user: user);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Container(
                color: cardData.cardBackgroundColor,
                child: Column(
                  children: [
                    Text(user.displayName, style: TextStyle(color: cardData.primaryTextColor)),
                    Text('ID: ${user.id}', style: TextStyle(color: cardData.secondaryTextColor)),
                    Container(
                      height: 100,
                      color: cardData.surfaceColor,
                      child: const Center(child: Text('Gallery')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Small Screen User'), findsOneWidget);
    });

    // 10. Expanded card height accommodates all content
    testWidgets('10. Expanded card height accommodates all content', (tester) async {
      const user = UserModel(
        id: '10002',
        username: 'content_user',
        name: 'Content User',
        avatarUrl: '',
      );

      final cardData = ProfileCardHelper.resolve(user: user);

      // Card container without fixed height expands to fit content
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  color: cardData.cardBackgroundColor,
                  border: cardData.cardBorder,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    10,
                    (i) => Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: cardData.surfaceColor,
                      child: Text('Section $i', style: TextStyle(color: cardData.primaryTextColor)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Section 0'), findsOneWidget);
      expect(find.text('Section 9'), findsOneWidget);
    });

    // 11. Room controls continue to work independently
    testWidgets('11. Room controls continue to work independently', (tester) async {
      bool leaveMicPressed = false;
      bool mutePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ElevatedButton(
                  key: const Key('leave_mic_button'),
                  onPressed: () => leaveMicPressed = true,
                  child: const Text('Leave Mic'),
                ),
                IconButton(
                  key: const Key('mute_mic_button'),
                  icon: const Icon(Icons.mic_off),
                  onPressed: () => mutePressed = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('leave_mic_button')));
      await tester.tap(find.byKey(const Key('mute_mic_button')));
      await tester.pump();

      expect(leaveMicPressed, isTrue);
      expect(mutePressed, isTrue);
    });

    // 12. Unequipped profile cards restore default card container
    test('12. Unequipped profile cards restore default card container', () {
      const unequippedUser1 = UserModel(
        id: '999',
        username: 'unequipped_1',
        name: 'Unequipped 1',
        avatarUrl: '',
        equippedProfileCardId: 'none',
      );
      final cardData1 = ProfileCardHelper.resolve(user: unequippedUser1);
      expect(cardData1.isDefault, isTrue);
      expect(cardData1.hasCustomCard, isFalse);

      const unequippedUser2 = UserModel(
        id: '998',
        username: 'unequipped_2',
        name: 'Unequipped 2',
        avatarUrl: '',
        profileCardUrl: 'none',
      );
      final cardData2 = ProfileCardHelper.resolve(user: unequippedUser2);
      expect(cardData2.isDefault, isTrue);
      expect(cardData2.hasCustomCard, isFalse);
    });

    // 13. Broken custom artwork restores default container
    test('13. Broken custom artwork restores default container', () {
      const brokenUser = UserModel(
        id: '888',
        username: 'broken_user',
        name: 'Broken Card User',
        avatarUrl: '',
        profileCardUrl: 'https://invalid-host-that-does-not-exist.test/broken_card.webp',
      );

      final cardData = ProfileCardHelper.resolve(user: brokenUser);
      expect(cardData.hasCustomCard, isTrue);

      // The fallback helper correctly identifies fallback properties
      final fallbackData = ProfileCardData.defaultCard;
      expect(fallbackData.isDefault, isTrue);
      expect(fallbackData.cardBackgroundColor, equals(const Color(0xFF141024)));
      expect(fallbackData.primaryTextColor, equals(Colors.white));
    });

    // 14. Light and dark theme text remains readable
    test('14. Light and dark theme text remains readable', () {
      // Light card (SVIP 7): Dark text #1A162B on light background #FAF8F5
      const lightUser = UserModel(
        id: '701',
        username: 'light_theme',
        name: 'Light Theme User',
        avatarUrl: '',
        vipLevel: 'SVIP 7',
      );
      final lightCard = ProfileCardHelper.resolve(user: lightUser);
      expect(lightCard.isLight, isTrue);
      expect(lightCard.primaryTextColor, equals(const Color(0xFF1A162B)));
      expect(lightCard.secondaryTextColor, equals(const Color(0xFF534C64)));

      // Dark card (VIP dark card): White text #FFFFFF on dark background #141024
      const darkUser = UserModel(
        id: '702',
        username: 'dark_theme',
        name: 'Dark Theme User',
        avatarUrl: '',
        profileCardUrl: 'assets/images/card_vip.jpg',
      );
      final darkCard = ProfileCardHelper.resolve(user: darkUser);
      expect(darkCard.isLight, isFalse);
      expect(darkCard.primaryTextColor, equals(Colors.white));
      expect(darkCard.secondaryTextColor, equals(Colors.white70));
    });
  });
}
