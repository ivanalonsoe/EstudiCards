import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/core/files/card_image.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../helpers/test_images.dart';

void main() {
  late Directory folder;
  late DiskImageFiles images;

  setUp(() {
    folder = createTempFolder();
    images = DiskImageFiles(
      () async => folder,
      prepare: (bytes) async => prepareCardImage(bytes),
    );
  });

  File stored(String relativePath) => File('${folder.path}/$relativePath');

  test(
    'save stores a prepared JPEG and returns its name in the folder',
    () async {
      final path = await images.save(pngBytes(4000, 3000));

      expect(path, matches(RegExp(r'^[0-9a-f-]{36}\.jpg$')));
      final image = img.JpegDecoder().decode(stored(path!).readAsBytesSync());
      expect(image!.width, 1600);
    },
  );

  test('two saves get different names', () async {
    final first = await images.save(pngBytes(10, 10));
    final second = await images.save(pngBytes(10, 10));

    expect(first, isNot(second));
  });

  test('save creates the folder if it is missing', () async {
    folder.deleteSync(recursive: true);

    final path = await images.save(pngBytes(10, 10));

    expect(stored(path!).existsSync(), isTrue);
  });

  test(
    'save gives null and stores nothing for bytes that are not an image',
    () async {
      expect(await images.save(Uint8List.fromList([1, 2, 3])), isNull);
      expect(folder.listSync(), isEmpty);
    },
  );

  test('copy stores the same image under a new name', () async {
    final original = await images.save(pngBytes(10, 10));

    final copy = await images.copy(original!);

    expect(copy, matches(RegExp(r'^[0-9a-f-]{36}\.jpg$')));
    expect(copy, isNot(original));
    expect(stored(copy!).readAsBytesSync(), stored(original).readAsBytesSync());
  });

  test('copy gives null for a missing file', () async {
    expect(await images.copy('missing.jpg'), isNull);
  });

  test('delete removes the files and ignores missing ones', () async {
    final kept = await images.save(pngBytes(10, 10));
    final deleted = await images.save(pngBytes(10, 10));

    await images.delete([deleted!, 'missing.jpg']);

    expect(stored(deleted).existsSync(), isFalse);
    expect(stored(kept!).existsSync(), isTrue);
  });
}
