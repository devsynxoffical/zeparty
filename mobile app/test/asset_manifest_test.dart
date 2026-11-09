import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('every asset declared by pubspec exists and loads', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    var count = 0;
    final failures = <String>[];
    for (final key in manifest.listAssets()) {
      if (!key.startsWith('assets/')) continue;
      count++;
      try {
        final data = await rootBundle.load(key);
        if (data.lengthInBytes == 0) failures.add('$key is empty');
      } catch (e) {
        failures.add('$key: $e');
      }
    }
    // ignore: avoid_print
    print('manifest assets checked: $count, failures: ${failures.length}');
    for (final f in failures) {
      // ignore: avoid_print
      print('  $f');
    }
    expect(failures, isEmpty);
    expect(count, greaterThan(500));
  });
}
