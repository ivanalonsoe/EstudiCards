import 'dart:io';

import 'package:estudicards/features/settings/data/data_folder_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_images.dart';

void main() {
  late Directory config;
  late Directory root;

  setUp(() {
    config = createTempFolder();
    root = createTempFolder();
  });

  Directory folder(String name) => Directory('${root.path}/$name');

  group('the chosen folder', () {
    test('is not chosen on the first start', () {
      expect(DataFolderStore(config).load(), isA<NoDataFolder>());
    });

    test('is remembered', () {
      final data = folder('EstudiCards')..createSync();
      DataFolderStore(config).save(data);

      final state = DataFolderStore(config).load();

      expect((state as ReadyDataFolder).folder.path, data.path);
    });

    test('is reported as missing if it no longer exists', () {
      final data = folder('EstudiCards')..createSync();
      DataFolderStore(config).save(data);
      data.deleteSync();

      final state = DataFolderStore(config).load();

      expect((state as MissingDataFolder).path, data.path);
    });

    test('a damaged setting counts as not chosen', () {
      File('${config.path}/data_folder.json').writeAsStringSync('{oops');

      expect(DataFolderStore(config).load(), isA<NoDataFolder>());
    });
  });

  test('a folder has data when it holds the database', () {
    final data = folder('EstudiCards')..createSync();
    expect(DataFolderStore.hasData(data), isFalse);

    File('${data.path}/estudicards.sqlite').writeAsStringSync('db');

    expect(DataFolderStore.hasData(data), isTrue);
    expect(DataFolderStore.hasData(folder('missing')), isFalse);
  });

  test('the data of earlier versions is moved without losing anything', () {
    // Earlier versions kept everything loose in Documents.
    final documents = folder('Documents')..createSync();
    File('${documents.path}/estudicards.sqlite').writeAsStringSync('db');
    File('${documents.path}/estudicards.sqlite-wal').writeAsStringSync('wal');
    Directory('${documents.path}/images').createSync();
    File('${documents.path}/images/a.jpg').writeAsStringSync('jpg');
    Directory('${documents.path}/backups').createSync();
    File('${documents.path}/backups/estudicards-auto-20261018-093005.json')
        .writeAsStringSync('{}');
    // Other files of the user stay where they are.
    File('${documents.path}/cv.pdf').writeAsStringSync('pdf');
    final data = folder('Documents/EstudiCards');

    DataFolderStore.moveData(from: documents, to: data);

    expect(File('${data.path}/estudicards.sqlite').readAsStringSync(), 'db');
    expect(
      File('${data.path}/estudicards.sqlite-wal').readAsStringSync(),
      'wal',
    );
    expect(File('${data.path}/images/a.jpg').readAsStringSync(), 'jpg');
    expect(
      File('${data.path}/backups/estudicards-auto-20261018-093005.json')
          .existsSync(),
      isTrue,
    );
    expect(File('${documents.path}/estudicards.sqlite').existsSync(), isFalse);
    expect(Directory('${documents.path}/images').existsSync(), isFalse);
    expect(File('${documents.path}/cv.pdf').existsSync(), isTrue);
  });
}
