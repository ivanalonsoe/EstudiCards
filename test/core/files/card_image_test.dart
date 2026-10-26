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

  test('a photo loses its EXIF data and stays upright', () {
    // Orientation 6: the camera was turned, so the photo must be rotated
    // 90° to be shown upright.
    final photo = phonePhotoBytes(40, 20, orientation: 6);
    expect(jpegHeaderMarkers(photo), contains(exifMarker));

    final prepared = prepareCardImage(photo)!;

    expect(jpegHeaderMarkers(prepared), isNot(contains(exifMarker)));
    expect(jpegSize(prepared), (20, 40));
  });

  test('bytes that are not an image give null', () {
    expect(prepareCardImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });

  group('removeJpegMetadata', () {
    /// [jpeg] with these segments added right after its first marker.
    Uint8List withSegments(Uint8List jpeg, List<List<int>> segments) =>
        Uint8List.fromList([
          ...jpeg.take(2),
          for (final segment in segments) ...segment,
          ...jpeg.skip(2),
        ]);

    const comment = [0xFF, 0xFE, 0, 5, 0x47, 0x50, 0x53]; // "GPS"
    const colourProfile = [0xFF, 0xE2, 0, 3, 0];
    const adobe = [0xFF, 0xEE, 0, 3, 0];
    const padding = [0xFF];

    test('drops EXIF and comments, and keeps the colour segments', () {
      final photo = withSegments(phonePhotoBytes(10, 10), [
        comment,
        padding,
        colourProfile,
        adobe,
      ]);

      final clean = removeJpegMetadata(photo)!;

      // The added segments come first, then the photo's own minus APP1.
      expect(jpegHeaderMarkers(clean), [
        0xE2,
        0xEE,
        0xE0,
        0xDB,
        0xC0,
        0xC4,
        0xDA,
      ]);
      expect(
        img.decodeJpg(clean)!.getBytes(),
        img.decodeJpg(photo)!.getBytes(),
      );
    });

    test('gives null when the header cannot be read', () {
      final jpeg = jpegBytes(10, 10);

      expect(removeJpegMetadata(pngBytes(10, 10)), isNull);
      expect(removeJpegMetadata(Uint8List.sublistView(jpeg, 0, 30)), isNull);
      expect(
        removeJpegMetadata(
          withSegments(jpeg, [
            [0x00, 0x01],
          ]),
        ),
        isNull,
      );
    });
  });

  test('jpegIsRotated reads the orientation in the EXIF data', () {
    expect(jpegIsRotated(phonePhotoBytes(10, 10, orientation: 6)), isTrue);
    expect(jpegIsRotated(phonePhotoBytes(10, 10)), isFalse);
    expect(jpegIsRotated(jpegBytes(10, 10)), isFalse);
  });
}
