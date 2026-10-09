import 'dart:typed_data';

import 'package:estudicards/core/files/image_source.dart';

/// Hands out [next] as the picked image (null = the user cancelled) and
/// counts how many times the picker was opened.
class FakeImageSource implements ImageSource {
  new([this.next]);

  Uint8List? next;
  int opened = 0;

  @override
  Future<Uint8List?> pick() async {
    opened++;
    return next;
  }
}
