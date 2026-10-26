import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A PNG of [width] × [height] pixels, as a user might pick.
Uint8List pngBytes(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

/// A JPEG of [width] × [height] pixels, as the app stores images.
Uint8List jpegBytes(int width, int height) =>
    img.encodeJpg(img.Image(width: width, height: height));

/// A JPEG as a phone camera saves it: its EXIF data says where it was taken
/// (GPS), with which phone, and how to rotate it to show it upright. The
/// pixels are a pattern, so a test can tell whether they changed.
Uint8List phonePhotoBytes(int width, int height, {int orientation = 1}) {
  final image = img.Image(width: width, height: height);
  for (final pixel in image) {
    pixel
      ..r = pixel.x % 256
      ..g = pixel.y % 256
      ..b = (pixel.x + pixel.y) % 256;
  }
  image.exif.imageIfd
    ..make = 'PhoneMaker'
    ..model = 'Phone 12'
    ..orientation = orientation;
  image.exif.gpsIfd.setGpsLocation(latitude: 40.4168, longitude: -3.7038);
  return img.encodeJpg(image);
}

/// The markers of the segments before the image data of the JPEG in
/// [bytes]. EXIF data lives in an APP1 segment (marker 0xE1).
List<int> jpegHeaderMarkers(Uint8List bytes) {
  final markers = <int>[];
  var i = 2; // after the start-of-image marker
  while (i + 4 <= bytes.length && bytes[i] == 0xFF) {
    final marker = bytes[i + 1];
    markers.add(marker);
    if (marker == 0xDA) break; // start of scan: the image data follows
    i += 2 + (bytes[i + 2] << 8 | bytes[i + 3]);
  }
  return markers;
}

/// The marker of the APP1 segment, where EXIF data is stored.
const exifMarker = 0xE1;

/// A new empty folder, deleted when the test ends.
Directory createTempFolder() {
  final folder = Directory.systemTemp.createTempSync('estudicards_images_');
  addTearDown(() {
    if (folder.existsSync()) folder.deleteSync(recursive: true);
  });
  return folder;
}
