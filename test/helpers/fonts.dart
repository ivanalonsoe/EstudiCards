import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's font (Plus Jakarta Sans, from `assets/fonts/`).
///
/// Widget tests draw text with a test font whose letters are all squares,
/// wider than real ones. A test that checks where text sits, or whether it
/// fits on one line, needs the real widths, so it calls this first (once,
/// in `setUpAll`).
Future<void> loadAppFonts() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final style in [
    'Regular',
    'Italic',
    'Medium',
    'SemiBold',
    'Bold',
    'BoldItalic',
    'ExtraBold',
  ]) {
    loader.addFont(
      File('assets/fonts/PlusJakartaSans-$style.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.view(bytes.buffer)),
    );
  }
  await loader.load();
}
