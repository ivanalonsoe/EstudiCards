import 'dart:convert';
import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:flutter_test/flutter_test.dart';

const _header =
    'question;answer;option1;option2;option3;option4;option5;option6;'
    'correct;explanation;example;notes';

const _bring = ExchangeCard(
  id: 'c1',
  type: CardType.simple,
  question: 'to **bring**',
  answer: 'traer (brought, brought)',
  example: 'Can you bring me some water?',
  notes: 'Verbo irregular',
);

const _primes = ExchangeCard(
  id: 'c2',
  type: CardType.test,
  question: '¿Qué números son primos?',
  allowMultiple: true,
  explanation: 'El 4 y el 9 tienen más divisores; también "1".',
  options: [
    ExchangeOption(id: 'o1', text: '2', isCorrect: true),
    ExchangeOption(id: 'o2', text: '4', isCorrect: false),
    ExchangeOption(id: 'o3', text: '7', isCorrect: true),
  ],
);

const _verbs = ExchangeDeck(id: 'd1', name: 'Verbos', cards: [_bring]);
const _maths = ExchangeDeck(id: 'd2', name: 'Mates', cards: [_primes]);

/// The text of an exported file, without its BOM, one line per row.
List<String> _lines(Uint8List bytes) =>
    utf8.decode(bytes.sublist(3)).split('\r\n');

void main() {
  test('the exported CSV uses ";" and a BOM', () {
    final bytes = encodeCardsCsv([_verbs]);

    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(_lines(bytes).first, _header);
    expect(
      _lines(bytes)[1],
      [
        'to **bring**',
        'traer (brought, brought)',
        ...List.filled(8, ''),
        'Can you bring me some water?',
        'Verbo irregular',
      ].join(';'),
    );
  });

  test('rows end in CRLF, as Excel writes them', () {
    final text = utf8.decode(encodeCardsCsv([_verbs]).sublist(3));

    expect(text, endsWith('\r\n'));
    expect(text.split('\r\n'), hasLength(3));
  });

  test('a test card writes its options and "correct" numbers', () {
    final [_, row, _] = _lines(encodeCardsCsv([_maths]));

    expect(
      row,
      [
        '¿Qué números son primos?',
        '',
        '2',
        '4',
        '7',
        ...List.filled(3, ''),
        '1|3',
        '"El 4 y el 9 tienen más divisores; también ""1""."',
        '',
        '',
      ].join(';'),
    );
  });

  test('a project file starts with the "deck" column', () {
    final lines = _lines(
      encodeCardsCsv([_verbs, _maths], withDeckColumn: true),
    );

    expect(lines.first, 'deck;$_header');
    expect(lines[1], startsWith('Verbos;to **bring**;'));
    expect(lines[2], startsWith('Mates;¿Qué números son primos?;'));
  });

  test('a line break inside a text is quoted', () {
    const card = ExchangeCard(
      id: 'c',
      type: CardType.simple,
      question: 'one\ntwo',
      answer: 'a',
    );

    final text = utf8.decode(
      encodeCardsCsv([
        const ExchangeDeck(id: 'd', name: 'D', cards: [card]),
      ]).sublist(3),
    );

    expect(text, contains('"one\ntwo";a;'));
  });

  group('cells that Excel would run as formulas', () {
    const risky = ['=1+1', '+34 600', '-ar verbs', '@SUM(A1)'];

    test('start with an apostrophe, so they stay text', () {
      for (final text in risky) {
        final card = ExchangeCard(
          id: 'c',
          type: CardType.simple,
          question: text,
          answer: 'a',
        );

        final [_, row, _] = _lines(
          encodeCardsCsv([
            ExchangeDeck(id: 'd', name: 'D', cards: [card]),
          ]),
        );

        expect(row, startsWith("'$text;"), reason: text);
      }
    });

    test('are read back by the app without the apostrophe', () {
      final cards = [
        for (final (i, text) in risky.indexed)
          ExchangeCard(
            id: 'c$i',
            type: CardType.simple,
            question: text,
            answer: text,
          ),
      ];

      final csv = parseCardsCsv(
        encodeCardsCsv([ExchangeDeck(id: 'd', name: 'D', cards: cards)]),
      );

      expect([for (final c in csv.cards) c.input.question], risky);
      expect([for (final c in csv.cards) c.input.answer], risky);
    });

    test('a deck name is guarded too', () {
      final lines = _lines(
        encodeCardsCsv([
          const ExchangeDeck(id: 'd', name: '=Mates', cards: [_bring]),
        ], withDeckColumn: true),
      );

      expect(lines[1], startsWith("'=Mates;"));
    });
  });

  test('an exported deck is read back as the same cards', () {
    final csv = parseCardsCsv(encodeCardsCsv([_verbs, _maths]));

    expect(csv.errors, isEmpty);
    final [bring, primes] = [for (final c in csv.cards) c.input];
    expect(bring.question, _bring.question);
    expect(bring.answer, _bring.answer);
    expect(bring.example, _bring.example);
    expect(bring.notes, _bring.notes);
    expect(primes.type, CardType.test);
    expect(primes.allowMultiple, isTrue);
    expect(primes.explanation, _primes.explanation);
    expect(
      [for (final o in primes.options) (o.text, o.isCorrect)],
      [('2', true), ('4', false), ('7', true)],
    );
  });

  test('a project file keeps each card in its deck', () {
    final csv = parseCardsCsv(
      encodeCardsCsv([_verbs, _maths], withDeckColumn: true),
    );

    expect([for (final c in csv.cards) c.deck], ['Verbos', 'Mates']);
  });

  test('images are left out: CSV has no images', () {
    final withImage = ExchangeCard(
      id: 'c',
      type: CardType.simple,
      question: 'q',
      answer: 'a',
      questionImage: ExchangeImage(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
    );

    final csv = parseCardsCsv(
      encodeCardsCsv([
        ExchangeDeck(id: 'd', name: 'D', cards: [withImage]),
      ]),
    );

    expect(csv.cards.single.input, isA<CardInput>());
  });
}
