import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/providers/svip_provider.dart';
import 'package:zeparty/widgets/profile_status_strip.dart';

void main() {
  group('Profile Status Strip Tests - 5 Category Hierarchy', () {
    testWidgets('Renders all five status cards in exact required order (SVIP, WEALTH, CHARM, GAME, ACCOUNT)', (tester) async {
      final user = const UserModel(
        id: 'test_user_1',
        username: 'testuser',
        name: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        wealthLevel: 30,
        charmLevel: 15,
        gameLevel: 12,
        accountLevel: 24,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SVIPProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileStatusStrip(user: user),
            ),
          ),
        ),
      );

      expect(find.text('SVIP'), findsOneWidget);
      expect(find.text('WEALTH'), findsOneWidget);
      expect(find.text('CHARM'), findsOneWidget);
      expect(find.text('GAME'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      expect(find.text('Sending'), findsOneWidget);
      expect(find.text('Receiving'), findsOneWidget);
      expect(find.text('Game Level'), findsOneWidget);
      expect(find.text('Account Level'), findsOneWidget);

      expect(find.text('Lv. 30'), findsOneWidget);
      expect(find.text('Lv. 15'), findsOneWidget);
      expect(find.text('Lv. 12'), findsOneWidget);
      expect(find.text('Lv. 24'), findsOneWidget);
    });

    testWidgets('Renders Level 0 for empty levels without hiding cards', (tester) async {
      final zeroUser = const UserModel(
        id: 'zero_user',
        username: 'zerouser',
        name: 'Zero User',
        avatarUrl: 'https://example.com/avatar.jpg',
        wealthLevel: 0,
        charmLevel: 0,
        gameLevel: 0,
        accountLevel: 0,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SVIPProvider()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileStatusStrip(user: zeroUser),
            ),
          ),
        ),
      );

      expect(find.text('SVIP'), findsOneWidget);
      expect(find.text('WEALTH'), findsOneWidget);
      expect(find.text('CHARM'), findsOneWidget);
      expect(find.text('GAME'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      expect(find.text('Lv. 0'), findsNWidgets(4));
    });
  });
}
