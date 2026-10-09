import 'dart:io';
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

  /// Deletes the images at these paths, relative to the images folder.
  /// Paths that do not exist are ignored.
  Future<void> delete(Iterable<String> relativePaths);
}

/// Stores nothing; for tests that do not care about images.
class NoImageFiles implements ImageFiles {
  const new();

  @override
  Future<String?> save(Uint8List bytes) async => null;

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
    if (prepared == null) return null;
    final folder = await _folder();
    final name = '${newId()}.jpg';
    // Synchronous file calls: the files are small, and they behave the
    // same inside widget tests, where asynchronous ones never finish.
    folder.createSync(recursive: true);
    File('${folder.path}/$name').writeAsBytesSync(prepared);
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
}
