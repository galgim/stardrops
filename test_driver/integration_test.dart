import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

// Writes whatever integration_test/screenshots_test.dart captures. Run with:
//   flutter drive --driver test_driver/integration_test.dart \
//     --target integration_test/screenshots_test.dart -d <simulator id>
// SHOT_DIR picks the output folder, so each device size lands in its own one.
Future<void> main() async {
  final dir = Platform.environment['SHOT_DIR'] ?? 'screenshots/iphone-6.5';
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
