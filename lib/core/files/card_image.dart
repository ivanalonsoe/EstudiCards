import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The long side of a stored card image, in pixels (SPEC §3.4).
const cardImageMaxSide = 1600;

/// JPEG quality of a stored card image (SPEC §3.4).
const cardImageQuality = 80;

/// The longest side an imported image may have, in pixels. Bigger ones are
/// refused before decoding them: a 20,000 × 20,000 JPEG can be a small file
/// that needs gigabytes of memory once decoded.
const importedImageMaxSide = 8000;

/// Turns a picked image (PNG, JPEG, WebP…) into what the app stores: a JPEG
/// at quality 80 whose long side is at most 1600 px. Returns null if the
/// bytes are not an image.
///
/// It uses the `image` package, written in pure Dart, so it works the same
/// on the four platforms.
Uint8List? prepareCardImage(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    // A damaged or unknown file can make a decoder throw instead of
    // returning null.
    return null;
  }
  if (decoded == null) return null;

  // Phone photos often keep their rotation in the EXIF data, which JPEG
  // re-encoding drops; applying it first keeps the photo upright.
  final upright = img.bakeOrientation(decoded);
  final longSide = math.max(upright.width, upright.height);
  final resized = longSide <= cardImageMaxSide
      ? upright
      : upright.width >= upright.height
      ? img.copyResize(upright, width: cardImageMaxSide)
      : img.copyResize(upright, height: cardImageMaxSide);
  return img.encodeJpg(resized, quality: cardImageQuality);
}

/// The size of a JPEG, read from its header without decoding the image.
/// Null if [bytes] are not a JPEG.
({int width, int height})? jpegSize(Uint8List bytes) {
  try {
    final info = img.JpegDecoder().startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (width: info.width, height: info.height);
  } on Object {
    // Damaged bytes can make the decoder throw instead of returning null.
    return null;
  }
}

/// [prepareCardImage] in a background isolate. A 4000 px photo takes a
/// couple of seconds in pure Dart; an isolate is a separate thread with its
/// own memory, so the screen keeps responding meanwhile.
Future<Uint8List?> prepareCardImageInBackground(Uint8List bytes) =>
    Isolate.run(() => prepareCardImage(bytes));
