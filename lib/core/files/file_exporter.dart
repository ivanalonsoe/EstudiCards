import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a file the app made to the user (SPEC §3.5): the native share
/// menu on mobile (WhatsApp, email, Drive…) and "Save as…" on desktop,
/// where sharing straight to an app does not work the same way. It is an
/// interface so tests can pass a fake instead of the system dialogs.
abstract interface class FileExporter {
  /// Whether the file is saved to disk ("Save as…") rather than shared.
  bool get savesToDisk;

  /// Shares or saves [bytes] as a file called [name]. Returns where the
  /// file was saved on desktop, or null when it was shared or the user
  /// cancelled. [origin] is the area the share menu points at on an iPad.
  Future<String?> export({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    Rect? origin,
  });
}

/// The real dialogs. They are native, so they are tried by hand and in
/// the E2E tests (E2E-07), not in unit tests.
class DeviceFileExporter implements FileExporter {
  const new();

  @override
  bool get savesToDisk => !(Platform.isAndroid || Platform.isIOS);

  @override
  Future<String?> export({
    required String name,
    required Uint8List bytes,
    required String mimeType,
    Rect? origin,
  }) async {
    if (!savesToDisk) {
      // `share_plus` writes the bytes to a temporary file with this name
      // and opens the system share menu with it.
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: mimeType, name: name)],
          fileNameOverrides: [name],
          sharePositionOrigin: origin,
        ),
      );
      return null;
    }
    final saved = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: mimeType,
    );
    return saved?.toFilePath();
  }
}
