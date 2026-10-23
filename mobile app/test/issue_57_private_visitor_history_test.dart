import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeparty/features/profile/visitors_screen.dart';
import 'package:zeparty/models/user_model.dart';
import 'package:zeparty/providers/auth_provider.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel _currentUser;
  bool _isAuthenticated;

  MockAuthProvider({
    required UserModel currentUser,
    bool isAuthenticated = true,
  })  : _currentUser = currentUser,
        _isAuthenticated = isAuthenticated;

  @override
  UserModel get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _isAuthenticated;

  void setUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  @override
  Future<void> logout() async {
    _isAuthenticated = false;
    _currentUser = const UserModel(id: '', username: '', name: '', avatarUrl: '');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Issue 57: Private Profile Visitor History Tests', () {
    testWidgets('VisitorsScreen displays private access denied when targetUserId is not the owner', (tester) async {
      const owner = UserModel(id: 'usr_owner_111', username: 'owner111', name: 'Owner User', avatarUrl: '');
      final mockAuth = MockAuthProvider(currentUser: owner, isAuthenticated: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuth,
            child: const VisitorsScreen(targetUserId: 'usr_stranger_999'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect access denied private message
      expect(find.text('Private Visitor History'), findsOneWidget);
      expect(
        find.text('Visitor history is strictly private and can only be accessed by the account owner.'),
        findsOneWidget,
      );
      // Tabs should NOT be visible
      expect(find.text("Who's seen me (0)"), findsNothing);
    });

    testWidgets('VisitorsScreen denies access when user is unauthenticated', (tester) async {
      const unauthUser = UserModel(id: '', username: '', name: '', avatarUrl: '');
      final mockAuth = MockAuthProvider(currentUser: unauthUser, isAuthenticated: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: mockAuth,
            child: const VisitorsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect access denied because unauthenticated
      expect(find.text('Private Visitor History'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    test('VisitRecord correctly deserializes standard and mystery visitor entries', () {
      final normalJson = {
        'id': 'rec_001',
        'visitorId': 'u_guest_42',
        'username': 'guest42',
        'name': 'Guest Forty-Two',
        'avatarUrl': 'https://example.com/avatar42.png',
        'visitedAt': '2026-10-21T10:00:00.000Z',
        'isMystery': false,
      };

      final normalRecord = VisitRecord.fromJson(normalJson);
      expect(normalRecord.id, equals('rec_001'));
      expect(normalRecord.user.id, equals('u_guest_42'));
      expect(normalRecord.user.name, equals('Guest Forty-Two'));
      expect(normalRecord.isMystery, isFalse);

      final mysteryJson = {
        'id': 'rec_002',
        'visitorId': 'u_vip_99',
        'username': 'hidden_vip',
        'name': 'Stealth User',
        'avatarUrl': '',
        'visitedAt': '2026-10-21T11:00:00.000Z',
        'isMystery': true,
      };

      final mysteryRecord = VisitRecord.fromJson(mysteryJson);
      expect(mysteryRecord.id, equals('rec_002'));
      expect(mysteryRecord.isMystery, isTrue);
    });
  });
}
