import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/core/files/document_picker.dart';

/// Hands out [next] as the picked file (null = the user cancelled) and
/// records the extensions it was asked for.
class FakeDocumentPicker implements DocumentPicker {
  new([this.next]);

  PickedDocument? next;
  List<String>? extensions;

  @override
  Future<PickedDocument?> pick(List<String> extensions) async {
    this.extensions = extensions;
    return next;
  }
}

/// A picked file with these [bytes].
PickedDocument pickedBytes(String name, Uint8List bytes, {int? size}) =>
    PickedDocument(
      name: name,
      size: size ?? bytes.length,
      read: () async => bytes,
    );

/// A picked file from `test/fixtures/`.
PickedDocument pickedFixture(String name) =>
    pickedBytes(name, File('test/fixtures/$name').readAsBytesSync());
