import 'package:flutter_test/flutter_test.dart';
import 'package:zeparty/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rocket Game Level Targets & Formatting Tests', () {
    test('Verify required default Rocket targets and display formats', () {
      final targets = GameProvider.defaultRocketTargets;

      expect(targets.length, equals(5));

      // Rocket 1: 100,000 -> 100K
      expect(targets[0], equals(100000));
      expect(GameProvider.formatRocketTarget(targets[0]), equals('100K'));

      // Rocket 2: 300,000 -> 300K
      expect(targets[1], equals(300000));
      expect(GameProvider.formatRocketTarget(targets[1]), equals('300K'));

      // Rocket 3: 400,000 -> 400K
      expect(targets[2], equals(400000));
      expect(GameProvider.formatRocketTarget(targets[2]), equals('400K'));

      // Rocket 4: 500,000 -> 500K
      expect(targets[3], equals(500000));
      expect(GameProvider.formatRocketTarget(targets[3]), equals('500K'));

      // Rocket 5: 1,000,000 -> 1M
      expect(targets[4], equals(1000000));
      expect(GameProvider.formatRocketTarget(targets[4]), equals('1M'));
    });

    test('Verify validation rules for Rocket targets', () {
      // Must have exactly 5 targets
      expect(GameProvider.validateRocketTargets([100000, 200000]), isNotNull);

      // Must be greater than zero
      expect(GameProvider.validateRocketTargets([100000, 200000, 0, 400000, 500000]), isNotNull);

      // Must be ordered sequentially
      expect(GameProvider.validateRocketTargets([300000, 100000, 400000, 500000, 1000000]), isNotNull);

      // Valid configuration returns null error
      expect(GameProvider.validateRocketTargets([100000, 300000, 400000, 500000, 1000000]), isNull);
    });

    test('Verify progress percentage formula against active level target', () {
      const activeTarget = 300000;
      const currentProgress = 150000;
      final progressPercent = (currentProgress / activeTarget * 100).clamp(0, 100);

      expect(progressPercent, equals(50.0));
    });
  });
}
