import 'dart:convert';
import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/import_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const _header =
    'question;answer;option1;option2;option3;option4;option5;option6;'
    'correct;explanation;example;notes';

CsvSource _csv(String text) => CsvSource(parseCardsCsv(utf8.encode(text)));

ImportPlan _plan(ImportSource source, ImportDestination destination) =>
    planImport(
      source: source,
      destination: destination,
      defaultDeckName: 'Importadas',
    );

const _languageDeck = ExchangeDeck(
  id: 'd1',
  name: 'Verbos',
  description: 'Del fichero',
  color: 'blue',
  type: DeckType.language,
  sourceLang: 'en-GB',
  targetLang: 'es-ES',
  cards: [
    ExchangeCard(
      id: 'c1',
      type: CardType.simple,
      question: 'to bring',
      answer: 'traer',
    ),
    // A test card without a correct option: an error in the preview.
    ExchangeCard(
      id: 'c2',
      type: CardType.test,
      question: '¿Cuál?',
      options: [
        ExchangeOption(id: 'o1', text: 'a', isCorrect: false),
        ExchangeOption(id: 'o2', text: 'b', isCorrect: false),
      ],
    ),
  ],
);

void main() {
  group('a CSV as a new project', () {
    test('groups rows by the "deck" column in the order they appear', () {
      final plan = _plan(
        _csv(
          'deck;question;answer\n'
          'B;q1;a1\nA;q2;a2\nB;q3;a3\n;q4;a4\n',
        ),
        const NewProjectDestination(name: 'P'),
      );

      expect(
        [for (final d in plan.decks) (d.name, d.cards.length)],
        [('B', 2), ('A', 1), ('Importadas', 1)],
      );
      expect(plan.project!.name, 'P');
    });

    test('cuts a deck name to the 60 characters a deck allows', () {
      final plan = _plan(
        _csv('deck;question;answer\n${'x' * 70};q;a\n'),
        const NewProjectDestination(name: 'P'),
      );

      expect(plan.decks.single.name, 'x' * 60);
    });

    test('rows with errors are listed with their row number', () {
      final plan = _plan(
        _csv('$_header\nok;yes;;;;;;;;;;\nno answer;;;;;;;;;;;\n'),
        const NewProjectDestination(name: 'P'),
      );

      expect(plan.newCards, 1);
      expect(
        [for (final e in plan.errors) (e.row, e.question, e.problem)],
        [(3, 'no answer', ImportProblem.answerMissing)],
      );
    });
  });

  test('a CSV as a new deck ignores the "deck" column', () {
    final plan = _plan(
      _csv('deck;question;answer\nA;q1;a1\nB;q2;a2\n'),
      const NewDeckDestination(
        projectId: 'p',
        name: 'Nueva',
        settings: DeckSettings(type: DeckType.language, sourceLang: 'en'),
      ),
    );

    final deck = plan.decks.single;
    expect((deck.name, deck.cards.length), ('Nueva', 2));
    expect(deck.settings.type, DeckType.language);
    expect(plan.projectId, 'p');
    expect(plan.project, isNull);
  });

  group('a JSON deck', () {
    test('as a new deck keeps its type, languages and colour', () {
      final plan = _plan(
        const DeckFileSource(_languageDeck),
        const NewDeckDestination(projectId: 'p', name: 'Renombrada'),
      );

      final deck = plan.decks.single;
      expect(deck.name, 'Renombrada');
      expect(deck.description, 'Del fichero');
      expect(deck.color, 'blue');
      expect(
        (
          deck.settings.type,
          deck.settings.sourceLang,
          deck.settings.targetLang,
        ),
        (DeckType.language, 'en-GB', 'es-ES'),
      );
      // New IDs for everything (rule 3).
      expect(deck.cards.single.id, isNull);
    });

    test('reports invalid cards by their question', () {
      final plan = _plan(
        const DeckFileSource(_languageDeck),
        const NewProjectDestination(name: 'P'),
      );

      expect(
        [for (final e in plan.errors) (e.row, e.question, e.problem)],
        [(null, '¿Cuál?', ImportProblem.noCorrectOption)],
      );
      expect(plan.decks.single.name, 'Verbos');
    });

    test('carries its images to the planned card', () {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]);
      final plan = _plan(
        DeckFileSource(
          ExchangeDeck(
            id: 'd',
            name: 'D',
            cards: [
              ExchangeCard(
                id: 'c',
                type: CardType.simple,
                question: 'q',
                answer: 'a',
                questionImage: ExchangeImage(jpeg),
              ),
            ],
          ),
        ),
        const ExistingDeckDestination('target'),
      );

      final card = plan.decks.single.cards.single;
      expect(card.questionImage!.bytes, jpeg);
      expect(card.id, 'c');
      expect(plan.decks.single.existingId, 'target');
    });
  });

  test('a JSON project as a new project keeps its look and decks', () {
    final plan = _plan(
      const ProjectFileSource(
        ExchangeProject(
          id: 'p',
          name: 'Del fichero',
          description: 'Notas',
          color: 'green',
          icon: 'flask',
          decks: [
            _languageDeck,
            ExchangeDeck(id: 'd2', name: 'Vacía'),
          ],
        ),
      ),
      const NewProjectDestination(name: 'Renombrado'),
    );

    final project = plan.project!;
    expect(
      (project.name, project.description, project.color, project.icon),
      ('Renombrado', 'Notas', 'green', 'flask'),
    );
    expect([for (final d in plan.decks) d.name], ['Verbos', 'Vacía']);
  });

  test('a JSON project cannot go into a project or a deck', () {
    const source = ProjectFileSource(
      ExchangeProject(id: 'p', name: 'P', color: 'orange', icon: 'book'),
    );

    expect(
      () => _plan(source, const NewDeckDestination(projectId: 'p', name: 'D')),
      throwsArgumentError,
    );
    expect(
      () => _plan(source, const ExistingDeckDestination('d')),
      throwsArgumentError,
    );
  });

  test('a duplicate inside the deck is matched on the type, too', () {
    final existing = Flashcard(
      id: 'e',
      deckId: 'target',
      type: CardType.simple,
      question: 'Pregunta',
      answer: 'a',
      allowMultiple: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final plan = planImport(
      source: _csv('$_header\npregunta;A;;;;;;;;;;\npregunta;;a;b;;;;;1;;;\n'),
      destination: const ExistingDeckDestination('target'),
      defaultDeckName: 'Importadas',
      deckCards: [existing],
    );

    expect(plan.duplicates.map((d) => d.row), [2]);
    expect(plan.newCards, 1);
  });
}
