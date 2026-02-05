import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

/// Test driver for integration tests with screenshot capture
///
/// IMPORTANT: The SCREENSHOT_DIR environment variable can be set by the
/// calling script (e.g., fastlane) to specify where screenshots should be saved.
///
/// Usage:
///   SCREENSHOT_DIR=path/to/screenshots flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_test.dart
///
/// Fastlane sets SCREENSHOT_DIR automatically based on the target platform.
/// For manual runs without SCREENSHOT_DIR, screenshots go to 'screenshots/'.

Future<void> main() async {
  final screenshotDir = Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots';

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      final file = File('$screenshotDir/$screenshotName.png');

      print('[Driver] onScreenshot called: $screenshotName');
      print('[Driver] screenshotBytes length: ${screenshotBytes.length}');
      print('[Driver] Output path: ${file.path}');

      await file.create(recursive: true);
      await file.writeAsBytes(screenshotBytes);
      print('[Driver] Screenshot saved: ${file.path}');
      return true;
    },
  );
}
