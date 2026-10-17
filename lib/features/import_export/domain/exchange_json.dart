// Converts an EstudiCards file (SPEC §8.2) to and from JSON.
//
// Reading is strict, because a file comes from outside the app: everything
// is checked before the import engine touches the database, and the first
// problem stops the reading with an `ExchangeFormatException` that says what
// is wrong and where. Content rules that the preview reports card by card
// (e.g. a test card without a correct option) are left to the import engine.
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:estudicards/core/clock.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:estudicards/features/projects/domain/project_input.dart';
import 'package:estudicards/features/study/domain/attempt_record.dart';
import 'package:estudicards/features/study/domain/session_state.dart';
import 'package:estudicards/features/study/domain/study_options.dart';

/// The value of `format` in every EstudiCards file.
const exchangeFormat = 'estudicards';

/// The version of the file format this app writes and reads. A change to
/// the format that older apps cannot read bumps it.
const exchangeVersion = 1;

/// Why a file cannot be read as an EstudiCards JSON file.
enum ExchangeError {
  /// Bigger than [maxJsonFileBytes].
  tooLarge,

  /// Not UTF-8 text, not JSON, or not a JSON object.
  notJson,

  /// JSON, but `format` is not `estudicards`.
  notEstudiCards,

  /// A `version` this app does not know, e.g. from a newer app.
  unsupportedVersion,

  /// A `kind` other than `backup`, `project` or `deck`.
  unknownKind,

  /// A field is missing, has the wrong type or an impossible value.
  invalidData,

  /// An image is not a base64 JPEG.
  invalidImage,

  /// An image is bigger than [maxImageBytes].
  imageTooLarge,
}

/// Thrown when a file is not a valid EstudiCards JSON file. Nothing has been
/// written when it is thrown.
class ExchangeFormatException implements Exception {
  const new(this.error, [this.path]);

  final ExchangeError error;

  /// Where in the file the problem is, e.g. `data.deck.cards[3].question`.
  final String? path;

  @override
  String toString() => 'ExchangeFormatException($error, $path)';
}

/// The file for [document]: UTF-8 JSON, without a BOM.
///
/// A shared project or deck (US-26) carries only content: no dates, no
/// favourite or archived state and no statistics. A backup (US-24) carries
/// everything.
Uint8List encodeExchange(ExchangeDocument document) {
  final full = document is BackupDocument;
  final data = switch (document) {
    DeckDocument(:final deck) => {'deck': _deckJson(deck, full: full)},
    ProjectDocument(:final project) => {
      'project': _projectJson(project, full: full),
    },
    BackupDocument() => {
      'projects': [
        for (final p in document.projects) _projectJson(p, full: full),
      ],
      'sessions': [for (final s in document.sessions) _sessionJson(s)],
      'sessionDecks': [
        for (final s in document.sessionDecks)
          {'sessionId': s.sessionId, 'deckId': s.deckId},
      ],
      'attempts': [for (final a in document.attempts) _attemptJson(a)],
      'cardStats': [for (final s in document.cardStats) _cardStatsJson(s)],
      'settings': document.settings,
    },
  };
  return utf8.encode(
    jsonEncode({
      'format': exchangeFormat,
      'version': exchangeVersion,
      'kind': document.kind.name,
      'exportedAt': _date(document.exportedAt),
      'appVersion': document.appVersion,
      'data': data,
    }),
  );
}

/// Reads a file. Throws [ExchangeFormatException] if it is not a valid
/// EstudiCards file.
ExchangeDocument decodeExchange(Uint8List bytes) {
  // The size is checked first, before reading anything.
  if (bytes.length > maxJsonFileBytes) {
    throw const ExchangeFormatException(.tooLarge);
  }
  final Object? json;
  try {
    // Some editors save a UTF-8 BOM (three marker bytes) at the start.
    final hasBom =
        bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF;
    json = jsonDecode(utf8.decode(hasBom ? bytes.sublist(3) : bytes));
  } on FormatException {
    throw const ExchangeFormatException(.notJson);
  }
  if (json is! Map<String, dynamic>) {
    throw const ExchangeFormatException(.notJson);
  }
  if (json['format'] != exchangeFormat) {
    throw const ExchangeFormatException(.notEstudiCards, 'format');
  }
  if (json['version'] != exchangeVersion) {
    throw const ExchangeFormatException(.unsupportedVersion, 'version');
  }
  final kind = ExchangeKind.values.asNameMap()[json['kind']];
  if (kind == null) throw const ExchangeFormatException(.unknownKind, 'kind');

  final root = _Json(json, '');
  final exportedAt = root.date('exportedAt');
  final appVersion = root.string('appVersion');
  final data = root.object('data');
  final reader = _Reader(full: kind == .backup);
  return switch (kind) {
    .deck => DeckDocument(
      exportedAt: exportedAt,
      appVersion: appVersion,
      deck: reader.deck(data.object('deck')),
    ),
    .project => ProjectDocument(
      exportedAt: exportedAt,
      appVersion: appVersion,
      project: reader.project(data.object('project')),
    ),
    .backup => reader.backup(data, exportedAt, appVersion),
  };
}

/// [encodeExchange] in a background isolate.
///
/// An isolate is a separate thread with its own memory. A backup with many
/// images is tens of megabytes of JSON, and converting it on the main
/// isolate, which also draws the screen, would freeze the app meanwhile.
/// `Isolate.run` sends the document to a new isolate, runs the function
/// there and hands the result back (moved, not copied).
Future<Uint8List> encodeExchangeInBackground(ExchangeDocument document) =>
    Isolate.run(() => encodeExchange(document));

/// [decodeExchange] in a background isolate (see
/// [encodeExchangeInBackground]). An [ExchangeFormatException] thrown there
/// comes back as is.
Future<ExchangeDocument> decodeExchangeInBackground(Uint8List bytes) =>
    Isolate.run(() => decodeExchange(bytes));

// ---------------------------------------------------------------- writing

String _date(DateTime time) => time.toUtc().toIso8601String();

String? _optionalDate(DateTime? time) => time == null ? null : _date(time);

Map<String, Object?>? _imageJson(ExchangeImage? image) => image == null
    ? null
    : {'mime': ExchangeImage.mime, 'data': base64Encode(image.bytes)};

Map<String, Object?> _projectJson(
  ExchangeProject project, {
  required bool full,
}) => {
  'id': project.id,
  'name': project.name,
  'description': project.description,
  'color': project.color,
  'icon': project.icon,
  if (full) ...{
    'isFavorite': project.isFavorite,
    'isArchived': project.isArchived,
    'archivedAt': _optionalDate(project.archivedAt),
    'deletedAt': _optionalDate(project.deletedAt),
    'lastUsedAt': _optionalDate(project.lastUsedAt),
    'createdAt': _optionalDate(project.createdAt),
    'updatedAt': _optionalDate(project.updatedAt),
  },
  'decks': [for (final deck in project.decks) _deckJson(deck, full: full)],
};

Map<String, Object?> _deckJson(ExchangeDeck deck, {required bool full}) => {
  'id': deck.id,
  'name': deck.name,
  'description': deck.description,
  'color': deck.color,
  'type': deck.type.name,
  'sourceLang': deck.sourceLang,
  'targetLang': deck.targetLang,
  if (full) ...{
    'deletedAt': _optionalDate(deck.deletedAt),
    'lastUsedAt': _optionalDate(deck.lastUsedAt),
    'createdAt': _optionalDate(deck.createdAt),
    'updatedAt': _optionalDate(deck.updatedAt),
  },
  'cards': [for (final card in deck.cards) _cardJson(card, full: full)],
};

Map<String, Object?> _cardJson(ExchangeCard card, {required bool full}) => {
  'id': card.id,
  'type': card.type.name,
  'question': card.question,
  // Each type writes only its own fields, as the database stores them.
  if (card.type == CardType.simple)
    'answer': card.answer
  else ...{
    'allowMultiple': card.allowMultiple,
    'explanation': card.explanation,
    'options': [
      for (final option in card.options)
        {'id': option.id, 'text': option.text, 'isCorrect': option.isCorrect},
    ],
  },
  'example': card.example,
  'notes': card.notes,
  'questionImage': _imageJson(card.questionImage),
  'answerImage': _imageJson(card.answerImage),
  if (full) ...{
    'createdAt': _optionalDate(card.createdAt),
    'updatedAt': _optionalDate(card.updatedAt),
  },
};

Map<String, Object?> _sessionJson(ExchangeSession session) => {
  'id': session.id,
  'projectId': session.projectId,
  'mode': session.mode,
  'direction': session.direction,
  'requestedCount': session.requestedCount,
  'prioritizeFailed': session.prioritizeFailed,
  'repeatFailed': session.repeatFailed,
  'timerType': session.timerType,
  'timerSeconds': session.timerSeconds,
  'status': session.status,
  'startedAt': _date(session.startedAt),
  'endedAt': _optionalDate(session.endedAt),
  'activeDurationMs': session.activeDurationMs,
  'correctTotal': session.correctTotal,
  'wrongTotal': session.wrongTotal,
  'unansweredTotal': session.unansweredTotal,
};

Map<String, Object?> _attemptJson(ExchangeAttempt attempt) => {
  'id': attempt.id,
  'sessionId': attempt.sessionId,
  'cardId': attempt.cardId,
  'direction': attempt.direction,
  'result': attempt.result,
  'source': attempt.source,
  'isFirstAttempt': attempt.isFirstAttempt,
  'selectedOptionIds': attempt.selectedOptionIds,
  'responseTimeMs': attempt.responseTimeMs,
  'answeredAt': _date(attempt.answeredAt),
  'localDay': attempt.localDay,
};

Map<String, Object?> _cardStatsJson(ExchangeCardStats stats) => {
  'cardId': stats.cardId,
  'direction': stats.direction,
  'correctCount': stats.correctCount,
  'wrongCount': stats.wrongCount,
  'consecutiveCorrect': stats.consecutiveCorrect,
  'inErrorList': stats.inErrorList,
  'lastResult': stats.lastResult,
  'lastAttemptAt': _optionalDate(stats.lastAttemptAt),
};

// ---------------------------------------------------------------- reading

// The values the database accepts in each text column with a fixed set of
// values (SPEC §4.2), taken from the enums that the app saves.
final Set<String> _modes = {for (final m in StudyMode.values) m.name};
final Set<String> _directions = {for (final d in StudyDirection.values) d.name};
final Set<String> _timerTypes = {for (final t in TimerType.values) t.stored};
final Set<String> _statuses = {
  'in_progress',
  for (final s in SessionStatus.values) s.stored,
};
final Set<String> _results = {for (final r in AttemptResult.values) r.name};
final Set<String> _sources = {for (final s in AttemptSource.values) s.stored};
const _lastResults = {'correct', 'wrong'};

/// Longest ID accepted. The app writes UUIDs (36 characters).
const _maxIdLength = 64;

/// The first bytes of every JPEG file.
const _jpegStart = [0xFF, 0xD8, 0xFF];

/// One JSON object of the file and where it is, so every error can say
/// exactly which field is wrong. Its methods return the field with the
/// right type, or throw [ExchangeFormatException] at that field.
class _Json {
  const new(this._map, this.path);

  final Map<String, dynamic> _map;

  /// E.g. `data.deck.cards[3]`; empty for the root of the file.
  final String path;

  String pathOf(String key) => path.isEmpty ? key : '$path.$key';

  Never fail(String key, [ExchangeError error = .invalidData]) =>
      throw ExchangeFormatException(error, pathOf(key));

  Object? operator [](String key) => _map[key];

  /// A text with something more than spaces.
  String string(String key, {int? maxLength}) {
    final value = _map[key];
    if (value is! String || value.trim().isEmpty) fail(key);
    if (maxLength != null && value.trim().length > maxLength) fail(key);
    return value;
  }

  String? optionalString(String key, {int? maxLength}) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! String) fail(key);
    if (maxLength != null && value.trim().length > maxLength) fail(key);
    return value;
  }

  String id(String key) => string(key, maxLength: _maxIdLength);

  /// One of [allowed].
  String choice(String key, Set<String> allowed) {
    final value = _map[key];
    if (value is! String || !allowed.contains(value)) fail(key);
    return value;
  }

  bool boolean(String key) {
    final value = _map[key];
    if (value is! bool) fail(key);
    return value;
  }

  /// A whole number, 0 or more.
  int count(String key) => optionalCount(key) ?? fail(key);

  int? optionalCount(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! int || value < 0) fail(key);
    return value;
  }

  /// An ISO 8601 date and time, in UTC.
  DateTime date(String key) => optionalDate(key) ?? fail(key);

  DateTime? optionalDate(String key) {
    final value = _map[key];
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed?.toUtc() ?? fail(key);
  }

  _Json object(String key) {
    final value = _map[key];
    if (value is! Map<String, dynamic>) fail(key);
    return _Json(value, pathOf(key));
  }

  /// A list of objects; its items are at `key[0]`, `key[1]`…
  List<_Json> objects(String key) {
    final value = _map[key];
    if (value is! List) fail(key);
    return [
      for (final (i, item) in value.indexed)
        if (item is Map<String, dynamic>)
          _Json(item, '${pathOf(key)}[$i]')
        else
          throw ExchangeFormatException(.invalidData, '${pathOf(key)}[$i]'),
    ];
  }

  /// A card image: `{"mime": "image/jpeg", "data": "<base64>"}`, or null.
  ExchangeImage? image(String key) {
    final value = _map[key];
    if (value == null) return null;
    if (value is! Map ||
        value['mime'] != ExchangeImage.mime ||
        value['data'] is! String) {
      fail(key, .invalidImage);
    }
    final data = value['data'] as String;
    // Base64 turns 3 bytes into 4 characters: the size is known before
    // decoding, so a huge image is refused without decoding it.
    if (data.length ~/ 4 * 3 > maxImageBytes) fail(key, .imageTooLarge);
    final Uint8List bytes;
    try {
      bytes = base64Decode(data);
    } on FormatException {
      fail(key, .invalidImage);
    }
    if (bytes.length > maxImageBytes) fail(key, .imageTooLarge);
    // Whatever `mime` says, the bytes themselves must be a JPEG.
    if (bytes.length < _jpegStart.length ||
        !_jpegStart.indexed.every((e) => bytes[e.$1] == e.$2)) {
      fail(key, .invalidImage);
    }
    return ExchangeImage(bytes);
  }
}

/// Reads the `data` of a file. In a backup ([full]) the dates and the
/// owner's state are required; a shared file has none, and they are not
/// read even if present.
class _Reader {
  new({required this.full});

  final bool full;

  // Every ID read so far, per table, to refuse repeated IDs and, in a
  // backup, links to rows that are not in the file.
  final _projectIds = <String>{};
  final _deckIds = <String>{};
  final _cardIds = <String>{};
  final _optionIds = <String>{};
  final _sessionIds = <String>{};

  /// Reads the ID at [key] and adds it to [seen]; a repeated ID fails.
  String _newId(_Json json, String key, Set<String> seen) {
    final id = json.id(key);
    if (!seen.add(id)) json.fail(key);
    return id;
  }

  /// Reads the ID at [key], which must be one of [existing].
  String _link(_Json json, String key, Set<String> existing) {
    final id = json.id(key);
    if (!existing.contains(id)) json.fail(key);
    return id;
  }

  DateTime? _fullDate(_Json json, String key) => full ? json.date(key) : null;

  DateTime? _fullOptionalDate(_Json json, String key) =>
      full ? json.optionalDate(key) : null;

  ExchangeProject project(_Json json) => ExchangeProject(
    id: _newId(json, 'id', _projectIds),
    name: json.string('name', maxLength: ProjectInput.maxNameLength),
    description: json.optionalString(
      'description',
      maxLength: ProjectInput.maxDescriptionLength,
    ),
    color: json.string('color'),
    icon: json.string('icon'),
    isFavorite: full && json.boolean('isFavorite'),
    isArchived: full && json.boolean('isArchived'),
    archivedAt: _fullOptionalDate(json, 'archivedAt'),
    deletedAt: _fullOptionalDate(json, 'deletedAt'),
    lastUsedAt: _fullOptionalDate(json, 'lastUsedAt'),
    createdAt: _fullDate(json, 'createdAt'),
    updatedAt: _fullDate(json, 'updatedAt'),
    decks: [for (final deck in json.objects('decks')) this.deck(deck)],
  );

  ExchangeDeck deck(_Json json) => ExchangeDeck(
    id: _newId(json, 'id', _deckIds),
    name: json.string('name', maxLength: DeckInput.maxNameLength),
    description: json.optionalString('description'),
    color: json.optionalString('color'),
    type: DeckType.values.asNameMap()[json['type']] ?? json.fail('type'),
    sourceLang: json.optionalString('sourceLang'),
    targetLang: json.optionalString('targetLang'),
    deletedAt: _fullOptionalDate(json, 'deletedAt'),
    lastUsedAt: _fullOptionalDate(json, 'lastUsedAt'),
    createdAt: _fullDate(json, 'createdAt'),
    updatedAt: _fullDate(json, 'updatedAt'),
    cards: [for (final card in json.objects('cards')) this.card(card)],
  );

  ExchangeCard card(_Json json) {
    final id = _newId(json, 'id', _cardIds);
    final type = CardType.values.asNameMap()[json['type']] ?? json.fail('type');
    final isTest = type == CardType.test;
    return ExchangeCard(
      id: id,
      type: type,
      question: json.string('question'),
      answer: isTest ? null : json.optionalString('answer'),
      explanation: isTest ? json.optionalString('explanation') : null,
      allowMultiple:
          isTest &&
          json['allowMultiple'] != null &&
          json.boolean('allowMultiple'),
      options: isTest
          ? [
              for (final option in json.objects('options'))
                ExchangeOption(
                  id: _newId(option, 'id', _optionIds),
                  text: option.optionalString('text') ?? '',
                  isCorrect: option.boolean('isCorrect'),
                ),
            ]
          : const [],
      example: json.optionalString('example'),
      notes: json.optionalString('notes'),
      questionImage: json.image('questionImage'),
      answerImage: json.image('answerImage'),
      createdAt: _fullDate(json, 'createdAt'),
      updatedAt: _fullDate(json, 'updatedAt'),
    );
  }

  /// The `data` of a backup. Projects come first, so sessions, attempts
  /// and statistics can only point at projects, decks and cards in the file.
  BackupDocument backup(_Json data, DateTime exportedAt, String appVersion) {
    final projects = [for (final p in data.objects('projects')) project(p)];
    final sessions = [
      for (final s in data.objects('sessions'))
        ExchangeSession(
          id: _newId(s, 'id', _sessionIds),
          projectId: _link(s, 'projectId', _projectIds),
          mode: s.choice('mode', _modes),
          direction: s.choice('direction', _directions),
          requestedCount: s.optionalCount('requestedCount'),
          prioritizeFailed: s.boolean('prioritizeFailed'),
          repeatFailed: s.boolean('repeatFailed'),
          timerType: s.choice('timerType', _timerTypes),
          timerSeconds: s.optionalCount('timerSeconds'),
          status: s.choice('status', _statuses),
          startedAt: s.date('startedAt'),
          endedAt: s.optionalDate('endedAt'),
          activeDurationMs: s.count('activeDurationMs'),
          correctTotal: s.count('correctTotal'),
          wrongTotal: s.count('wrongTotal'),
          unansweredTotal: s.count('unansweredTotal'),
        ),
    ];
    final attemptIds = <String>{};
    return BackupDocument(
      exportedAt: exportedAt,
      appVersion: appVersion,
      projects: projects,
      sessions: sessions,
      sessionDecks: [
        for (final s in data.objects('sessionDecks'))
          ExchangeSessionDeck(
            sessionId: _link(s, 'sessionId', _sessionIds),
            deckId: _link(s, 'deckId', _deckIds),
          ),
      ],
      attempts: [
        for (final a in data.objects('attempts'))
          ExchangeAttempt(
            id: _newId(a, 'id', attemptIds),
            sessionId: _link(a, 'sessionId', _sessionIds),
            cardId: _link(a, 'cardId', _cardIds),
            direction: a.choice('direction', _directions),
            result: a.choice('result', _results),
            source: a.choice('source', _sources),
            isFirstAttempt: a.boolean('isFirstAttempt'),
            selectedOptionIds: _optionIdList(a, 'selectedOptionIds'),
            responseTimeMs: a.optionalCount('responseTimeMs'),
            answeredAt: a.date('answeredAt'),
            localDay: _localDay(a, 'localDay'),
          ),
      ],
      cardStats: [
        for (final s in data.objects('cardStats'))
          ExchangeCardStats(
            cardId: _link(s, 'cardId', _cardIds),
            direction: s.choice('direction', _directions),
            correctCount: s.count('correctCount'),
            wrongCount: s.count('wrongCount'),
            consecutiveCorrect: s.count('consecutiveCorrect'),
            inErrorList: s.boolean('inErrorList'),
            lastResult: s['lastResult'] == null
                ? null
                : s.choice('lastResult', _lastResults),
            lastAttemptAt: s.optionalDate('lastAttemptAt'),
          ),
      ],
      settings: _settings(data.object('settings')),
    );
  }

  /// The ticked options of an attempt: a list of IDs, or null.
  static List<String>? _optionIdList(_Json json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! List ||
        value.any((id) => id is! String || id.length > _maxIdLength)) {
      json.fail(key);
    }
    return value.cast<String>();
  }

  /// A `YYYY-MM-DD` day that exists, or null.
  static String? _localDay(_Json json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      json.fail(key);
    }
    // `DateTime` moves an impossible day (e.g. 31 February) to the next
    // month, so it would not give the same text back.
    final day = DateTime.tryParse('${value}T00:00:00Z');
    if (day == null || dayKey(day) != value) json.fail(key);
    return value;
  }

  /// Key → value, where each value is a text or null.
  static Map<String, String?> _settings(_Json json) => {
    for (final MapEntry(:key) in json._map.entries)
      key: json.optionalString(key),
  };
}
