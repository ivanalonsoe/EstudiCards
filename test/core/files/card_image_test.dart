import 'dart:typed_data';

import 'package:estudicards/core/files/card_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../helpers/test_images.dart';

/// The size of the JPEG in [bytes]; fails if it is not a JPEG.
(int, int) jpegSize(Uint8List bytes) {
  final image = img.JpegDecoder().decode(bytes);
  expect(image, isNotNull, reason: 'not a JPEG');
  return (image!.width, image.height);
}

void main() {
  test('a 4000 px image is stored with its long side at 1600 px', () {
    final prepared = prepareCardImage(pngBytes(4000, 3000));

    expect(jpegSize(prepared!), (1600, 1200));
  });

  test('a portrait image is limited by its height', () {
    final prepared = prepareCardImage(pngBytes(1000, 4000));

    expect(jpegSize(prepared!), (400, 1600));
  });

  test('a small image keeps its size but becomes a JPEG', () {
    final prepared = prepareCardImage(pngBytes(800, 600));

    expect(jpegSize(prepared!), (800, 600));
  });

  test('bytes that are not an image give null', () {
    expect(prepareCardImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
