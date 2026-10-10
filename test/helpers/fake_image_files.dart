import 'dart:typed_data';

import 'package:estudicards/core/files/image_files.dart';

/// Records the image paths it is asked to delete or copy. A copy of `a.jpg`
/// is named `copy-of-a.jpg`.
class FakeImageFiles implements ImageFiles {
  final deleted = <String>[];
  final copied = <String>[];

  @override
  Future<String?> save(Uint8List bytes) async => null;

  @override
  Future<String?> copy(String relativePath) async {
    copied.add(relativePath);
    return 'copy-of-$relativePath';
  }

  @override
  Future<void> delete(Iterable<String> relativePaths) async =>
      deleted.addAll(relativePaths);
}
