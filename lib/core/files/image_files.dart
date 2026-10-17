import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:estudicards/core/files/card_image.dart';
import 'package:estudicards/core/ids.dart';

/// The card images stored in the app's images folder (SPEC §3.4).
///
/// It is an interface so the trash can delete images without knowing where
/// they live, and tests can pass a fake that records the paths.
abstract interface class ImageFiles {
  /// Prepares the picked image ([bytes] in any common format) and stores
  /// it. Returns its path relative to the images folder, or null if the
  /// bytes are not an image.
  Future<String?> save(Uint8List bytes);

  /// Stores a copy of the image at [relativePath] under a new name, for a
  /// copied card: each card owns its files, so deleting one card never
  /// removes the image of another. Null if the file does not exist.
  Future<String?> copy(String relativePath);

  /// Deletes the images at these paths, relative to the images folder.
  /// Paths that do not exist are ignored.
  Future<void> delete(Iterable<String> relativePaths);

  /// The bytes of the image at [relativePath], to export it. Null if the
  /// file does not exist.
  Future<Uint8List?> read(String relativePath);

  /// Stores a JPEG that came inside an imported file, always under a new
  /// name. Returns its path relative to the images folder, or null if the
  /// bytes are not a usable JPEG.
  Future<String?> saveImported(Uint8List jpeg);
}

/// Stores nothing; for tests that do not care about images.
class NoImageFiles implements ImageFiles {
  const new();

  @override
  Future<String?> save(Uint8List bytes) async => null;

  @override
  Future<String?> copy(String relativePath) async => null;

  @override
  Future<Uint8List?> read(String relativePath) async => null;

  @override
  Future<String?> saveImported(Uint8List jpeg) async => null;

  @override
  Future<void> delete(Iterable<String> relativePaths) async {}
}

/// The images folder on disk: `<app documents>/images/<uuid>.jpg` (SPEC
/// §3.4). The database stores only the file name, so the folder can move
/// (e.g. when restoring a backup on another device).
class DiskImageFiles implements ImageFiles {
  /// The first argument gives the images folder; it is a function because
  /// finding the app documents folder is asynchronous. `prepare` resizes
  /// and re-encodes the picked image; by default in a background isolate.
  new(this._folder, {this._prepare = prepareCardImageInBackground});

  final Future<Directory> Function() _folder;
  final Future<Uint8List?> Function(Uint8List bytes) _prepare;

  @override
  Future<String?> save(Uint8List bytes) async {
    final prepared = await _prepare(bytes);
    return prepared == null ? null : await _write(prepared);
  }

  @override
  Future<String?> copy(String relativePath) async {
    final folder = await _folder();
    final original = File('${folder.path}/$relativePath');
    if (!original.existsSync()) return null;
    final name = '${newId()}.jpg';
    original.copySync('${folder.path}/$name');
    return name;
  }

  @override
  Future<void> delete(Iterable<String> relativePaths) async {
    if (relativePaths.isEmpty) return;
    final folder = await _folder();
    for (final path in relativePaths) {
      final file = File('${folder.path}/$path');
      if (file.existsSync()) file.deleteSync();
    }
  }

  @override
  Future<Uint8List?> read(String relativePath) async {
    final file = File('${(await _folder()).path}/$relativePath');
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  /// The bytes come from a file the user picked, so they are checked: only
  /// a JPEG is accepted, its size is read from its header before decoding
  /// anything, and the name is always a new one in the images folder.
  ///
  /// A JPEG of up to 1600 px is what the app itself stores (every exported
  /// image is one), so it is kept byte for byte: decoding and encoding it
  /// again would take time and lose quality. A bigger one is prepared like
  /// a picked image.
  @override
  Future<String?> saveImported(Uint8List jpeg) async {
    final size = jpegSize(jpeg);
    if (size == null) return null;
    final longSide = math.max(size.width, size.height);
    if (longSide > importedImageMaxSide) return null;
    final bytes = longSide <= cardImageMaxSide ? jpeg : await _prepare(jpeg);
    return bytes == null ? null : await _write(bytes);
  }

  /// Writes [jpeg] under a new name and returns that name.
  Future<String> _write(Uint8List jpeg) async {
    final folder = await _folder();
    final name = '${newId()}.jpg';
    // Synchronous file calls: the files are small, and they behave the
    // same inside widget tests, where asynchronous ones never finish.
    folder.createSync(recursive: true);
    File('${folder.path}/$name').writeAsBytesSync(jpeg);
    return name;
  }
}
