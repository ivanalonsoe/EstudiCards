import 'package:estudicards/core/clock.dart';

/// The longest file name written, without the extension.
const _maxLength = 80;

/// The name of an exported file: [parts] joined with `-` (SPEC §8.1), e.g.
/// `Inglés B2-Verbos irregulares.csv`. The names come from the user, so
/// characters that Windows, macOS or Android do not allow in a file name
/// are dropped, and a name with nothing left is `estudicards`.
String exportFileName(List<String> parts, String extension) {
  final cleaned = [
    for (final part in parts)
      if (_clean(part) case final name when name.isNotEmpty) name,
  ];
  var name = cleaned.join('-');
  if (name.length > _maxLength) name = _clean(name.substring(0, _maxLength));
  return '${name.isEmpty ? 'estudicards' : name}.$extension';
}

/// The name of a full backup made on [day] (the user's local day, as
/// `Clock.localDay` gives it): `estudicards-backup-2026-09-30.json`
/// (SPEC §8.1).
String backupFileName(DateTime day) => 'estudicards-backup-${dayKey(day)}.json';

/// [text] without the characters a file name cannot have, with single
/// spaces, and without the spaces and dots Windows refuses at the end.
String _clean(String text) => text
    .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .replaceAll(RegExp(r'[. ]+$'), '');
