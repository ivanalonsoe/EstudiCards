import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A file the user picked, not read yet: its size comes first, so a file
/// that is too big is refused without loading it into memory.
class PickedDocument {
  const new({required this.name, required this.size, required this.read});

  /// The file name with its extension, e.g. `verbos.csv`.
  final String name;

  /// In bytes; null if the system does not say.
  final int? size;

  /// Reads the whole file.
  final Future<Uint8List> Function() read;
}

/// Where the user picks a file to import from: the system file dialog.
/// It is an interface so tests can pass a fake (see `ImageSource`).
abstract interface class DocumentPicker {
  /// The picked file, or null if the user cancelled. Only files with one
  /// of [extensions] (without the dot) can be picked.
  Future<PickedDocument?> pick(List<String> extensions);
}

/// The system file dialog on every platform (`file_picker`). It opens a
/// native dialog, so it is tried by hand and in the E2E tests.
class DeviceDocumentPicker implements DocumentPicker {
  const new();

  @override
  Future<PickedDocument?> pick(List<String> extensions) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (file == null) return null;
    return PickedDocument(
      name: file.name,
      size: await file.length(),
      read: file.readAsBytes,
    );
  }
}
