import 'dart:typed_data';
import 'dart:ui';

import 'package:estudicards/core/files/file_exporter.dart';

/// One file handed to the [FakeFileExporter].
typedef ExportedFile = ({String name, Uint8List bytes, String mimeType});

/// Records the files it is asked to share or save. On "desktop"
/// ([savesToDisk]) it answers that they were saved at [savedPath].
class FakeFileExporter implements FileExporter {
  new({this.savesToDisk = false, this.savedPath});

  @override
  final bool savesToDisk;

  /// Null = the user cancelled "Save as…".
  final String? savedPath;

  final exported = <ExportedFile>[];

  @override
  Future<String?> export({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    Rect? origin,
  }) async {
    exported.add((name: name, bytes: bytes, mimeType: mimeType));
    return savesToDisk ? savedPath : null;
  }
}
