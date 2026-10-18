// The automatic backups the app saves before "Reemplazar todo" deletes the
// current data (SPEC §8.4 rule 7). They live in the app's own folder, and
// Settings lists them so they can be restored or deleted on every platform.

/// How many automatic backups are kept; older ones are deleted.
const maxAutoBackups = 5;

/// `estudicards-auto-20261018-093005.json`: made at [time] in UTC. The name
/// sorts in time order, so the newest is the last one.
String autoBackupFileName(DateTime time) {
  final utc = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return 'estudicards-auto-${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}-'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}.json';
}

final _namePattern = RegExp(
  r'^estudicards-auto-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.json$',
);

/// When the backup called [name] was made, or null if the name is not one
/// the app writes (so a name with a path in it is never used).
DateTime? autoBackupTime(String name) {
  final match = _namePattern.firstMatch(name);
  if (match == null) return null;
  final [year, month, day, hour, minute, second] = [
    for (var i = 1; i <= 6; i++) int.parse(match.group(i)!),
  ];
  return DateTime.utc(year, month, day, hour, minute, second);
}

/// The automatic backups to delete so that only the newest
/// [maxAutoBackups] stay, newest first. Other files are left alone.
List<String> autoBackupsToDelete(Iterable<String> names) {
  final backups = [
    for (final name in names)
      if (autoBackupTime(name) != null) name,
  ]..sort((a, b) => b.compareTo(a));
  return backups.skip(maxAutoBackups).toList();
}
