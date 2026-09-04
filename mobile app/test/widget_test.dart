import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LiveStreamApp());
    expect(find.byType(LiveStreamApp), findsOneWidget);

    // Advance past the SplashScreen navigation timer (2 s) so that no
    // timer is left pending when the test framework tears down.
    await tester.pump(const Duration(seconds: 3));
  });
}
