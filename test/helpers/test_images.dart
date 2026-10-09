import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A PNG of [width] × [height] pixels, as a user might pick.
Uint8List pngBytes(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

/// A new empty folder, deleted when the test ends.
Directory createTempFolder() {
  final folder = Directory.systemTemp.createTempSync('estudicards_images_');
  addTearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });
  return folder;
}
