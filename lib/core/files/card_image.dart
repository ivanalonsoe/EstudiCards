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

  // Phone photos often keep their rotation in the EXIF data; applying it
  // first keeps the photo upright once the EXIF data is gone.
  final upright = img.bakeOrientation(decoded);
  final longSide = math.max(upright.width, upright.height);
  final resized = longSide <= cardImageMaxSide
      ? upright
      : upright.width >= upright.height
      ? img.copyResize(upright, width: cardImageMaxSide)
      : img.copyResize(upright, height: cardImageMaxSide);
  // The EXIF data can say where the photo was taken (GPS), with which phone
  // and when, and it would travel with every shared deck: it is dropped.
  return img.encodeJpg(
    resized..exif = img.ExifData(),
    quality: cardImageQuality,
  );
}

/// Whether the JPEG in [bytes] must be rotated to be shown upright, as its
/// EXIF data says.
bool jpegIsRotated(Uint8List bytes) {
  try {
    final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation;
    return orientation != null && orientation != 1;
  } on Object {
    // Damaged EXIF data can make the decoder throw instead of returning null.
    return false;
  }
}

/// The JPEG in [jpeg] without its metadata segments, and the image data
/// untouched (it is not re-encoded). Null if its header cannot be read.
///
/// A JPEG is a list of segments, each starting with a marker; the image
/// data comes after the "start of scan" one. Metadata lives in APPn
/// segments (EXIF and XMP in APP1, Photoshop's IPTC in APP13…) and in
/// comments. Three APPn segments say how to show the colours, so they are
/// kept: APP0 (JFIF), APP2 (colour profile) and APP14 (Adobe).
Uint8List? removeJpegMetadata(Uint8List jpeg) {
  if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) return null;
  final result = BytesBuilder(copy: false)
    ..add(Uint8List.sublistView(jpeg, 0, 2));
  var i = 2;
  while (i + 4 <= jpeg.length) {
    if (jpeg[i] != 0xFF) return null;
    final marker = jpeg[i + 1];
    // 0xFF bytes may pad the space between segments.
    if (marker == 0xFF) {
      i++;
      continue;
    }
    // Start of scan: the rest is the image data, copied as it is.
    if (marker == 0xDA) {
      result.add(Uint8List.sublistView(jpeg, i));
      return result.takeBytes();
    }
    final end = i + 2 + (jpeg[i + 2] << 8 | jpeg[i + 3]);
    if (end > jpeg.length) return null;
    if (!_isMetadata(marker)) result.add(Uint8List.sublistView(jpeg, i, end));
    i = end;
  }
  return null;
}

bool _isMetadata(int marker) =>
    marker == 0xFE || // comment
    (marker >= 0xE1 && marker <= 0xEF && marker != 0xE2 && marker != 0xEE);

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
