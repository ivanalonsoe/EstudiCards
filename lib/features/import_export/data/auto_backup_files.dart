// The folder with the automatic backups that "Reemplazar todo" saves before
// deleting anything (SPEC §8.4 rule 7): `<app documents>/backups`. On
// Android and iOS that folder cannot be opened from outside the app, so
// Settings lists the backups to restore or delete them.
import 'dart:io';
import 'dart:typed_data';

import 'package:estudicards/features/import_export/domain/auto_backups.dart';

/// One automatic backup in the folder.
class AutoBackup {
  const new({required this.name, required this.time, required this.path});

  final String name;

  /// When it was made, in UTC.
  final DateTime time;

  /// Its full path, to tell the user where it is.
  final String path;
}

class AutoBackupFiles {
  /// [_folder] gives the folder; it is a function because finding the app
  /// documents folder is asynchronous (see `DiskImageFiles`).
  new(this._folder);

  final Future<Directory> Function() _folder;

  /// Writes [bytes] as the backup made [now] and deletes the oldest ones
  /// beyond [maxAutoBackups].
  Future<AutoBackup> save(Uint8List bytes, DateTime now) async {
    final folder = await _folder();
    // Synchronous file calls, as in `DiskImageFiles`: they behave the same
    // inside widget tests, where asynchronous ones never finish.
    folder.createSync(recursive: true);
    final name = autoBackupFileName(now);
    final file = File('${folder.path}/$name')..writeAsBytesSync(bytes);
    for (final old in autoBackupsToDelete(_names(folder))) {
      File('${folder.path}/$old').deleteSync();
    }
    return AutoBackup(name: name, time: autoBackupTime(name)!, path: file.path);
  }

  /// The automatic backups, newest first. Other files are ignored.
  Future<List<AutoBackup>> list() async {
    final folder = await _folder();
    if (!folder.existsSync()) return const [];
    return [
      for (final name in _names(folder)..sort((a, b) => b.compareTo(a)))
        if (autoBackupTime(name) case final time?)
          AutoBackup(name: name, time: time, path: '${folder.path}/$name'),
    ];
  }

  Future<Uint8List> read(AutoBackup backup) async =>
      (await _file(backup)).readAsBytesSync();

  Future<void> delete(AutoBackup backup) async {
    final file = await _file(backup);
    if (file.existsSync()) file.deleteSync();
  }

  /// The file of [backup], only if its name is one the app writes: never a
  /// path that leaves the folder.
  Future<File> _file(AutoBackup backup) async {
    if (autoBackupTime(backup.name) == null) {
      throw ArgumentError.value(backup.name, 'backup', 'not a backup name');
    }
    return File('${(await _folder()).path}/${backup.name}');
  }

  static List<String> _names(Directory folder) => [
    for (final entity in folder.listSync())
      if (entity is File) entity.uri.pathSegments.last,
  ];
}
