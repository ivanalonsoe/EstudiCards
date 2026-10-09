import 'dart:typed_data';

import 'package:estudicards/core/files/image_files.dart';

/// Records the image paths it is asked to delete.
class FakeImageFiles implements ImageFiles {
  final deleted = <String>[];

  @override
  Future<String?> save(Uint8List bytes) async => null;

  @override
  Future<void> delete(Iterable<String> relativePaths) async =>
      deleted.addAll(relativePaths);
}
