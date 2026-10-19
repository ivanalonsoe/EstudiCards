// Remembers the data folder the user chose on Windows (T5.11), and moves
// the data that earlier versions left loose in Documents.
//
// The choice cannot live in the database, since it says where the database
// is: it is a small JSON file in the app's own settings folder
// (`getApplicationSupportDirectory`, under AppData on Windows).
import 'dart:convert';
import 'dart:io';

import 'package:estudicards/features/settings/domain/data_folder.dart';

/// Whether a data folder was chosen and is still there.
sealed class DataFolderState {
  const new();
}

/// The first start: nothing chosen yet.
class NoDataFolder extends DataFolderState {
  const new();
}

/// A folder was chosen but is gone (deleted, renamed, a removed drive).
class MissingDataFolder extends DataFolderState {
  const new(this.path);

  final String path;
}

class ReadyDataFolder extends DataFolderState {
  const new(this.folder);

  final Directory folder;
}

class DataFolderStore {
  /// [_configFolder] is where the choice is saved.
  new(this._configFolder);

  final Directory _configFolder;

  File get _file => File('${_configFolder.path}/data_folder.json');

  /// The folder chosen before, if it still exists. Synchronous: it runs once,
  /// before the app starts.
  DataFolderState load() {
    final String? path;
    try {
      if (!_file.existsSync()) return const NoDataFolder();
      final json = jsonDecode(_file.readAsStringSync());
      path = json is Map<String, dynamic> ? json['path'] as String? : null;
    } on Object {
      // A damaged setting: the user is asked again.
      return const NoDataFolder();
    }
    if (path == null) return const NoDataFolder();
    final folder = Directory(path);
    return folder.existsSync()
        ? ReadyDataFolder(folder)
        : MissingDataFolder(path);
  }

  void save(Directory folder) {
    _configFolder.createSync(recursive: true);
    _file.writeAsStringSync(jsonEncode({'path': folder.path}));
  }

  /// Whether [folder] holds a database of the app.
  static bool hasData(Directory folder) =>
      File('${folder.path}/$databaseFileName').existsSync();

  /// The files of the app: the database (with the files SQLite keeps next
  /// to it while it is open) and the images and backups folders.
  static const List<String> _files = [
    databaseFileName,
    '$databaseFileName-wal',
    '$databaseFileName-shm',
    '$databaseFileName-journal',
  ];
  static const List<String> _folders = ['images', 'backups'];

  /// Moves the app's files from [from] to [to]; nothing else in [from] is
  /// touched. A rename when both are on the same drive; otherwise a copy,
  /// and the originals are deleted only once everything is copied.
  static void moveData({required Directory from, required Directory to}) {
    to.createSync(recursive: true);
    for (final name in _files) {
      final file = File('${from.path}/$name');
      if (!file.existsSync()) continue;
      final target = '${to.path}/$name';
      try {
        file.renameSync(target);
      } on FileSystemException {
        file
          ..copySync(target)
          ..deleteSync();
      }
    }
    for (final name in _folders) {
      final folder = Directory('${from.path}/$name');
      if (!folder.existsSync()) continue;
      final target = Directory('${to.path}/$name');
      try {
        folder.renameSync(target.path);
      } on FileSystemException {
        _copyFolder(folder, target);
        folder.deleteSync(recursive: true);
      }
    }
  }

  static void _copyFolder(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final entity in from.listSync()) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      switch (entity) {
        case File():
          entity.copySync('${to.path}/$name');
        case Directory():
          _copyFolder(entity, Directory('${to.path}/$name'));
        default:
          break;
      }
    }
  }
}
