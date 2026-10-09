import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// `image_picker` has its own `ImageSource` (gallery or camera), so it is
// imported with a prefix to avoid a clash with ours.
import 'package:image_picker/image_picker.dart' as picker;

/// Where the user picks an image from: the gallery on mobile and a file
/// on desktop. It is an interface so tests can pass a fake instead of the
/// system dialogs.
abstract interface class ImageSource {
  /// The bytes of the picked image, or null if the user cancelled.
  Future<Uint8List?> pick();
}

/// The real dialogs: the system photo picker on Android and iOS
/// (`image_picker`), and the file dialog on Windows and macOS
/// (`file_picker`).
///
/// It opens native dialogs, so it is tried by hand and in the E2E tests,
/// not in unit tests.
class DeviceImageSource implements ImageSource {
  const new();

  @override
  Future<Uint8List?> pick() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final photo = await picker.ImagePicker().pickImage(
        source: picker.ImageSource.gallery,
      );
      return photo == null ? null : await photo.readAsBytes();
    }
    final file = await FilePicker.pickFile(type: FileType.image);
    final path = file?.path;
    return path == null ? null : await File(path).readAsBytes();
  }
}
