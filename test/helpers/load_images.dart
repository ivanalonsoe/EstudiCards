import 'package:flutter_test/flutter_test.dart';

/// Lets the images on screen finish reading their files, then draws again.
///
/// Widget tests run on fake time, which never waits for a real file read;
/// `runAsync` gives the real reads a moment to finish (or to fail, for a
/// missing file).
Future<void> loadImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}
