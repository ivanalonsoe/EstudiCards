import 'dart:convert';
import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/exchange_json.dart';
import 'package:estudicards/features/import_export/domain/import_limits.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first bytes of every JPEG file, followed by a few more.
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);
final _otherJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB, 9, 8, 7]);
final _exportedAt = DateTime.utc(2026, 9, 30, 10);
final _created = DateTime.utc(2026, 9, 1, 8, 30, 15, 123);
final _updated = DateTime.utc(2026, 9, 2, 18);

const _simpleId = '11111111-1111-4111-8111-111111111111';
const _testId = '22222222-2222-4222-8222-222222222222';
const _deckId = '33333333-3333-4333-8333-333333333333';
const _generalDeckId = '44444444-4444-4444-8444-444444444444';
const _projectId = '55555555-5555-4555-8555-555555555555';
const _sessionId = '66666666-6666-4666-8666-666666666666';
const _attemptId = '77777777-7777-4777-8777-777777777777';

ExchangeCard _simpleCard({bool withDates = false}) => ExchangeCard(
  id: _simpleId,
  type: CardType.simple,
  question: 'to bring',
  answer: 'traer (brought, brought)',
  example: 'Can you **bring** me some water?',
  notes: 'Verbo irregular',
  questionImage: ExchangeImage(_jpeg),
  answerImage: ExchangeImage(_otherJpeg),
  createdAt: withDates ? _created : null,
  updatedAt: withDates ? _updated : null,
);

ExchangeCard _testCard({bool withDates = false}) => ExchangeCard(
  id: _testId,
  type: CardType.test,
  question: '¿Qué verbos son irregulares?',
  explanation: '*Walk* y *play* son regulares.',
  allowMultiple: true,
  options: const [
    ExchangeOption(id: 'o1', text: 'go', isCorrect: true),
    ExchangeOption(id: 'o2', text: 'walk', isCorrect: false),
    ExchangeOption(id: 'o3', text: 'eat', isCorrect: true),
  ],
  createdAt: withDates ? _created : null,
  updatedAt: withDates ? _updated : null,
);

ExchangeDeck _languageDeck({bool withDates = false}) => ExchangeDeck(
  id: _deckId,
  name: 'Verbos irregulares',
  description: 'Los 100 más comunes',
  type: DeckType.language,
  sourceLang: 'en-GB',
  targetLang: 'es-ES',
  cards: [
    _simpleCard(withDates: withDates),
    _testCard(withDates: withDates),
  ],
  lastUsedAt: withDates ? _updated : null,
  createdAt: withDates ? _created : null,
  updatedAt: withDates ? _updated : null,
);

/// A general deck that kept the languages it had as a language deck.
ExchangeDeck _generalDeck({bool withDates = false}) => ExchangeDeck(
  id: _generalDeckId,
  name: 'Notas de clase',
  color: 'blue',
  sourceLang: 'en-GB',
  targetLang: 'en-GB',
  deletedAt: withDates ? _updated : null,
  createdAt: withDates ? _created : null,
  updatedAt: withDates ? _updated : null,
);

ExchangeProject _project({bool withDates = false}) => ExchangeProject(
  id: _projectId,
  name: 'Inglés B2',
  description: 'Preparación del examen',
  color: 'orange',
  icon: 'globe',
  decks: [
    _languageDeck(withDates: withDates),
    _generalDeck(withDates: withDates),
  ],
  isFavorite: withDates,
  isArchived: withDates,
  archivedAt: withDates ? _updated : null,
  lastUsedAt: withDates ? _updated : null,
  createdAt: withDates ? _created : null,
  updatedAt: withDates ? _updated : null,
);

BackupDocument _backup() => BackupDocument(
  exportedAt: _exportedAt,
  appVersion: '1.0.0',
  projects: [_project(withDates: true)],
  sessions: [
    ExchangeSession(
      id: _sessionId,
      projectId: _projectId,
      mode: 'errors',
      direction: 'reverse',
      requestedCount: 20,
      prioritizeFailed: true,
      repeatFailed: true,
      timerType: 'per_card',
      timerSeconds: 30,
      status: 'time_up',
      startedAt: _created,
      endedAt: _updated,
      activeDurationMs: 61000,
      correctTotal: 3,
      wrongTotal: 1,
      unansweredTotal: 2,
    ),
  ],
  sessionDecks: const [
    ExchangeSessionDeck(sessionId: _sessionId, deckId: _deckId),
  ],
  attempts: [
    ExchangeAttempt(
      id: _attemptId,
      sessionId: _sessionId,
      cardId: _testId,
      direction: 'normal',
      result: 'wrong',
      source: 'test_check',
      isFirstAttempt: true,
      selectedOptionIds: const ['o1'],
      responseTimeMs: 4200,
      answeredAt: DateTime.utc(2026, 9, 1, 23, 30),
      localDay: '2026-09-02',
    ),
  ],
  cardStats: [
    ExchangeCardStats(
      cardId: _testId,
      direction: 'normal',
      correctCount: 0,
      wrongCount: 1,
      consecutiveCorrect: 0,
      inErrorList: true,
      lastResult: 'wrong',
      lastAttemptAt: DateTime.utc(2026, 9, 1, 23, 30),
    ),
  ],
  settings: const {'theme_mode': 'dark', 'daily_goal': null},
);

DeckDocument _deckDocument() => DeckDocument(
  exportedAt: _exportedAt,
  appVersion: '1.0.0',
  deck: _languageDeck(),
);

/// The document after a trip through a file.
T _roundTrip<T extends ExchangeDocument>(T document) =>
    decodeExchange(encodeExchange(document)) as T;

/// The JSON text of a document, as a map.
Map<String, dynamic> _json(ExchangeDocument document) =>
    jsonDecode(utf8.decode(encodeExchange(document))) as Map<String, dynamic>;

/// The object at [path] in [json]: keys and list indexes separated by dots,
/// e.g. `data.deck.cards.1`.
Map<String, dynamic> _at(Map<String, dynamic> json, String path) {
  Object? value = json;
  for (final key in path.split('.')) {
    value = value is List ? value[int.parse(key)] : (value! as Map)[key];
  }
  return value! as Map<String, dynamic>;
}

/// A file with these contents.
Uint8List _file(Object? json) => utf8.encode(jsonEncode(json));

Matcher _failsWith(ExchangeError error, {String? path}) => throwsA(
  isA<ExchangeFormatException>()
      .having((e) => e.error, 'error', error)
      .having((e) => e.path, 'path', path ?? anything),
);

/// Checks that the file fails with [error] at [path] once [breakIt]
/// changes a valid [json].
void _expectRejected(
  Map<String, dynamic> json,
  void Function(Map<String, dynamic> json) breakIt,
  ExchangeError error, {
  String? path,
  String? reason,
}) {
  breakIt(json);
  expect(
    () => decodeExchange(_file(json)),
    _failsWith(error, path: path),
    reason: reason ?? path,
  );
}

void main() {
  group('round trip', () {
    test('a deck comes back with the same content', () {
      final document = _deckDocument();

      final back = _roundTrip(document);

      expect(back.kind, ExchangeKind.deck);
      expect(back.exportedAt, _exportedAt);
      expect(back.appVersion, '1.0.0');
      final deck = back.deck;
      expect(deck.id, _deckId);
      expect(deck.name, 'Verbos irregulares');
      expect(deck.description, 'Los 100 más comunes');
      expect(deck.color, isNull);
      final [simple, test] = deck.cards;
      expect(simple.id, _simpleId);
      expect(simple.type, CardType.simple);
      expect(simple.question, 'to bring');
      expect(simple.answer, 'traer (brought, brought)');
      expect(simple.example, 'Can you **bring** me some water?');
      expect(simple.notes, 'Verbo irregular');
      expect(simple.options, isEmpty);
      expect(test.type, CardType.test);
      expect(test.question, '¿Qué verbos son irregulares?');
      expect(test.explanation, '*Walk* y *play* son regulares.');
      expect(test.allowMultiple, isTrue);
      expect(test.answer, isNull);
      expect(
        [for (final o in test.options) (o.id, o.text, o.isCorrect)],
        [('o1', 'go', true), ('o2', 'walk', false), ('o3', 'eat', true)],
      );
      // Writing it again gives exactly the same file.
      expect(encodeExchange(back), encodeExchange(document));
    });

    test('images travel as base64 JPEG and come back as the same bytes', () {
      final json = _json(_deckDocument());

      final card = _at(json, 'data.deck.cards.0');
      expect(card['questionImage'], {
        'mime': 'image/jpeg',
        'data': base64Encode(_jpeg),
      });
      expect(card['answerImage'], {
        'mime': 'image/jpeg',
        'data': base64Encode(_otherJpeg),
      });
      final back = decodeExchange(_file(json)) as DeckDocument;
      expect(back.deck.cards.first.questionImage!.bytes, _jpeg);
      expect(back.deck.cards.first.answerImage!.bytes, _otherJpeg);
      expect(back.deck.cards.last.questionImage, isNull);
    });

    test("each deck's type and languages survive the round trip", () {
      final back = _roundTrip(
        ProjectDocument(
          exportedAt: _exportedAt,
          appVersion: '1.0.0',
          project: _project(),
        ),
      );

      final [language, general] = back.project.decks;
      expect(language.type, DeckType.language);
      expect(language.sourceLang, 'en-GB');
      expect(language.targetLang, 'es-ES');
      expect(general.type, DeckType.general);
      expect(general.color, 'blue');
      // A general deck keeps the languages it had, hidden (US-06 AC3).
      expect(general.sourceLang, 'en-GB');
      expect(general.targetLang, 'en-GB');
    });

    test('a shared project leaves out dates and personal state', () {
      final json = _json(
        ProjectDocument(
          exportedAt: _exportedAt,
          appVersion: '1.0.0',
          project: _project(withDates: true),
        ),
      );

      expect(
        _at(json, 'data.project').keys,
        isNot(anyOf(contains('isFavorite'), contains('createdAt'))),
      );
      expect(
        _at(json, 'data.project.decks.0').keys,
        isNot(contains('lastUsedAt')),
      );
      expect(
        _at(json, 'data.project.decks.0.cards.0').keys,
        isNot(contains('updatedAt')),
      );
    });

    test('a backup keeps every field, including local days', () {
      final back = _roundTrip(_backup());

      final project = back.projects.single;
      expect(project.isFavorite, isTrue);
      expect(project.isArchived, isTrue);
      expect(project.archivedAt, _updated);
      expect(project.createdAt, _created);
      expect(project.updatedAt, _updated);
      expect(project.lastUsedAt, _updated);
      final [deck, trashed] = project.decks;
      expect(deck.createdAt, _created);
      expect(deck.lastUsedAt, _updated);
      expect(trashed.deletedAt, _updated);
      expect(deck.cards.first.createdAt, _created);
      expect(deck.cards.first.updatedAt, _updated);

      final session = back.sessions.single;
      expect(session.mode, 'errors');
      expect(session.direction, 'reverse');
      expect(session.requestedCount, 20);
      expect(session.prioritizeFailed, isTrue);
      expect(session.timerType, 'per_card');
      expect(session.timerSeconds, 30);
      expect(session.status, 'time_up');
      expect(session.endedAt, _updated);
      expect(session.activeDurationMs, 61000);
      expect(
        (session.correctTotal, session.wrongTotal, session.unansweredTotal),
        (3, 1, 2),
      );
      expect(back.sessionDecks.single.deckId, _deckId);

      final attempt = back.attempts.single;
      expect(attempt.cardId, _testId);
      expect(attempt.result, 'wrong');
      expect(attempt.source, 'test_check');
      expect(attempt.isFirstAttempt, isTrue);
      expect(attempt.selectedOptionIds, ['o1']);
      expect(attempt.responseTimeMs, 4200);
      expect(attempt.answeredAt, DateTime.utc(2026, 9, 1, 23, 30));
      expect(attempt.localDay, '2026-09-02');

      final stats = back.cardStats.single;
      expect(stats.inErrorList, isTrue);
      expect(stats.wrongCount, 1);
      expect(stats.lastResult, 'wrong');
      expect(back.settings, {'theme_mode': 'dark', 'daily_goal': null});
      expect(encodeExchange(back), encodeExchange(_backup()));
    });

    test('the header has format, version and dates in UTC ISO 8601', () {
      final json = _json(_backup());

      expect(json['format'], 'estudicards');
      expect(json['version'], 1);
      expect(json['kind'], 'backup');
      expect(json['exportedAt'], '2026-09-30T10:00:00.000Z');
      expect(json['appVersion'], '1.0.0');
    });

    test('a file that starts with a UTF-8 BOM is read', () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...encodeExchange(_deckDocument()),
      ]);

      expect(decodeExchange(bytes), isA<DeckDocument>());
    });

    test('a backup without local days is accepted', () {
      final json = _json(_backup());
      _at(json, 'data.attempts.0').remove('localDay');

      final back = decodeExchange(_file(json)) as BackupDocument;

      expect(back.attempts.single.localDay, isNull);
    });
  });

  group('in a background isolate', () {
    test('writing and reading give the same file', () async {
      final bytes = await encodeExchangeInBackground(_backup());
      final back = await decodeExchangeInBackground(bytes);

      expect(bytes, encodeExchange(_backup()));
      expect(encodeExchange(back), bytes);
    });

    test('a file that cannot be read fails with its reason', () {
      expect(
        decodeExchangeInBackground(utf8.encode('not json')),
        _failsWith(ExchangeError.notJson),
      );
    });
  });

  group('rejects', () {
    test('a JSON without "format" or of another app', () {
      _expectRejected(
        _json(_deckDocument()),
        (json) => json.remove('format'),
        ExchangeError.notEstudiCards,
        reason: 'no format',
      );
      _expectRejected(
        _json(_deckDocument()),
        (json) => json['format'] = 'anki',
        ExchangeError.notEstudiCards,
        reason: 'another format',
      );
    });

    test('an unknown version', () {
      for (final version in [2, 0, '1', null]) {
        _expectRejected(
          _json(_deckDocument()),
          (json) => json['version'] = version,
          ExchangeError.unsupportedVersion,
          reason: 'version $version',
        );
      }
    });

    test('an unknown kind', () {
      _expectRejected(
        _json(_deckDocument()),
        (json) => json['kind'] = 'card',
        ExchangeError.unknownKind,
      );
    });

    test('a file that is not JSON', () {
      for (final bytes in [
        utf8.encode('question;answer\nto bring;traer'),
        utf8.encode('[1, 2, 3]'),
        Uint8List.fromList([0xFF, 0xFE, 0x00]),
      ]) {
        expect(() => decodeExchange(bytes), _failsWith(ExchangeError.notJson));
      }
    });

    test('a file over the size limit, before reading it', () {
      expect(
        () => decodeExchange(Uint8List(maxJsonFileBytes + 1)),
        _failsWith(ExchangeError.tooLarge),
      );
    });

    test('missing or mistyped fields, saying where they are', () {
      final breakers = <String, void Function(Map<String, dynamic>)>{
        'data.deck': (json) => _at(json, 'data').remove('deck'),
        'data.deck.name': (json) => _at(json, 'data.deck')['name'] = '  ',
        'data.deck.type': (json) => _at(json, 'data.deck')['type'] = 'maths',
        'data.deck.cards[0].question': (json) =>
            _at(json, 'data.deck.cards.0')['question'] = 12,
        'data.deck.cards[1].type': (json) =>
            _at(json, 'data.deck.cards.1')['type'] = 'essay',
        'data.deck.cards[1].options[0].isCorrect': (json) =>
            _at(json, 'data.deck.cards.1.options.0')['isCorrect'] = 'yes',
      };
      for (final MapEntry(key: path, value: breakIt) in breakers.entries) {
        _expectRejected(
          _json(_deckDocument()),
          breakIt,
          ExchangeError.invalidData,
          path: path,
        );
      }
    });

    test('a deck name longer than the app allows', () {
      _expectRejected(
        _json(_deckDocument()),
        (json) => _at(json, 'data.deck')['name'] = 'x' * 61,
        ExchangeError.invalidData,
        path: 'data.deck.name',
      );
    });

    test('two cards with the same ID', () {
      _expectRejected(
        _json(_deckDocument()),
        (json) => _at(json, 'data.deck.cards.1')['id'] = _simpleId,
        ExchangeError.invalidData,
        path: 'data.deck.cards[1].id',
      );
    });

    test('an image that is not base64', () {
      _expectRejected(
        _json(_deckDocument()),
        (json) => _at(json, 'data.deck.cards.0')['questionImage'] = {
          'mime': 'image/jpeg',
          'data': 'not base64!',
        },
        ExchangeError.invalidImage,
        path: 'data.deck.cards[0].questionImage',
      );
    });

    test('an image that is not a JPEG, whatever its "mime" says', () {
      final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      for (final image in [
        {'mime': 'image/png', 'data': base64Encode(_jpeg)},
        {'mime': 'image/jpeg', 'data': base64Encode(png)},
        {'mime': 'image/jpeg', 'data': ''},
      ]) {
        _expectRejected(
          _json(_deckDocument()),
          (json) => _at(json, 'data.deck.cards.0')['answerImage'] = image,
          ExchangeError.invalidImage,
          reason: '$image',
        );
      }
    });

    test('an image over the size limit', () {
      final huge = Uint8List(maxImageBytes + 1)..setAll(0, _jpeg);

      _expectRejected(
        _json(_deckDocument()),
        (json) => _at(json, 'data.deck.cards.0')['questionImage'] = {
          'mime': 'image/jpeg',
          'data': base64Encode(huge),
        },
        ExchangeError.imageTooLarge,
      );
    });

    test('a backup whose attempts point at a card that is not in it', () {
      _expectRejected(
        _json(_backup()),
        (json) => _at(json, 'data.attempts.0')['cardId'] =
            '99999999-9999-4999-8999-999999999999',
        ExchangeError.invalidData,
        path: 'data.attempts[0].cardId',
      );
    });

    test('a backup with a wrong stored value or a missing date', () {
      final breakers = <String, void Function(Map<String, dynamic>)>{
        'data.sessions[0].status': (json) =>
            _at(json, 'data.sessions.0')['status'] = 'paused',
        'data.attempts[0].localDay': (json) =>
            _at(json, 'data.attempts.0')['localDay'] = '2/9/2026',
        'data.attempts[0].answeredAt': (json) =>
            _at(json, 'data.attempts.0')['answeredAt'] = 'yesterday',
        'data.projects[0].createdAt': (json) =>
            _at(json, 'data.projects.0').remove('createdAt'),
        'data.settings.theme_mode': (json) =>
            _at(json, 'data.settings')['theme_mode'] = 3,
      };
      for (final MapEntry(key: path, value: breakIt) in breakers.entries) {
        _expectRejected(
          _json(_backup()),
          breakIt,
          ExchangeError.invalidData,
          path: path,
        );
      }
    });
  });
}
