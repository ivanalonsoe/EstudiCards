import 'package:estudicards/features/cards/domain/card_input.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';
import 'package:estudicards/features/decks/domain/deck_input.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';

/// What the user is importing, already read from the file (P07 step 1).
sealed class ImportSource {
  const new();
}

class CsvSource extends ImportSource {
  const new(this.csv);

  final CsvImport csv;
}

/// A shared deck (`kind: deck`).
class DeckFileSource extends ImportSource {
  const new(this.deck);

  final ExchangeDeck deck;
}

/// A shared project (`kind: project`).
class ProjectFileSource extends ImportSource {
  const new(this.project);

  final ExchangeProject project;
}

/// The type and languages the user picks for the decks a CSV creates
/// (SPEC §8.4 rule 6).
class DeckSettings {
  const new({this.type = DeckType.general, this.sourceLang, this.targetLang});

  final DeckType type;
  final String? sourceLang;
  final String? targetLang;
}

/// Where the cards go (P07 step 2), which depends on where the import was
/// opened (US-27).
sealed class ImportDestination {
  const new();
}

/// From the dashboard. [settings] is used only for a CSV.
class NewProjectDestination extends ImportDestination {
  const new({required this.name, this.settings = const DeckSettings()});

  final String name;
  final DeckSettings settings;
}

/// From a project. [settings] is used only for a CSV.
class NewDeckDestination extends ImportDestination {
  const new({
    required this.projectId,
    required this.name,
    this.settings = const DeckSettings(),
  });

  final String projectId;
  final String name;
  final DeckSettings settings;
}

/// From a deck: the cards are added to it and it keeps its type.
class ExistingDeckDestination extends ImportDestination {
  const new(this.deckId);

  final String deckId;
}

/// Why a card of the file is not imported.
enum ImportProblem {
  questionMissing,
  answerMissing,
  tooFewOptions,
  tooManyOptions,
  noCorrectOption,
  tooManyCorrectOptions,

  /// CSV only: a wrong `correct` column.
  invalidCorrect,
}

/// A card of the file that is skipped, for the preview's "Avisos".
class ImportIssue {
  const new({this.row, this.question, this.problem});

  /// The CSV row; null for a JSON file.
  final int? row;

  /// The card's question, without surrounding spaces, if it has one.
  final String? question;

  /// Why it has an error; null for a duplicate.
  final ImportProblem? problem;
}

class PlannedCard {
  const new({
    required this.input,
    this.id,
    this.row,
    this.questionImage,
    this.answerImage,
  });

  final CardInput input;

  /// The file's ID, kept when adding to a deck (SPEC §8.4 rule 3); null
  /// means a new one is generated.
  final String? id;

  /// The CSV row, to name the card in the preview.
  final int? row;
  final ExchangeImage? questionImage;
  final ExchangeImage? answerImage;
}

class PlannedDeck {
  const new({
    required this.name,
    required this.cards,
    this.existingId,
    this.description,
    this.color,
    this.settings = const DeckSettings(),
  });

  /// The deck the cards are added to; null for a deck to create.
  final String? existingId;
  final String name;
  final String? description;
  final String? color;
  final DeckSettings settings;
  final List<PlannedCard> cards;
}

class PlannedProject {
  const new({
    required this.name,
    required this.color,
    required this.icon,
    this.description,
  });

  final String name;
  final String? description;
  final String color;
  final String icon;
}

/// What an import will do, shown in the preview (P07 step 3) before the
/// user confirms (SPEC §8.4 rule 2).
class ImportPlan {
  const new({
    required this.decks,
    this.project,
    this.projectId,
    this.errors = const [],
    this.duplicates = const [],
  });

  /// The project to create; null when importing into an existing one.
  final PlannedProject? project;

  /// The existing project of a new deck; null otherwise.
  final String? projectId;
  final List<PlannedDeck> decks;
  final List<ImportIssue> errors;
  final List<ImportIssue> duplicates;

  int get newCards => decks.fold(0, (sum, deck) => sum + deck.cards.length);
}

/// Works out what importing [source] into [destination] will do.
///
/// [defaultDeckName] names the deck of CSV rows without a `deck` column
/// when importing as a new project ("Importadas"). When adding to a deck,
/// [deckCards] are the cards it already has and [takenCardIds] the IDs of
/// the file's cards that already exist anywhere in the database.
///
/// Rules (SPEC §8.4):
/// - Cards that break the editor's rules are skipped and listed (rule 2).
/// - As a new project or deck everything gets new IDs; adding to a deck
///   keeps a card's ID unless it already exists (rule 3).
/// - Only when adding to a deck, a card is a duplicate if the deck has one
///   with its ID or with the same normalised content (rule 4).
/// - A JSON deck keeps its type and languages; a CSV takes the ones the
///   user chose; an existing deck keeps its own (rule 6).
///
/// Throws [ArgumentError] for a JSON project going into a project or a
/// deck: §8.1 only imports a project as a new project.
ImportPlan planImport({
  required ImportSource source,
  required ImportDestination destination,
  required String defaultDeckName,
  List<Flashcard> deckCards = const [],
  Set<String> takenCardIds = const {},
}) {
  if (source is ProjectFileSource && destination is! NewProjectDestination) {
    throw ArgumentError.value(
      source,
      'source',
      'a project can only be imported as a new project',
    );
  }
  final errors = <ImportIssue>[];
  final decks = _decksOf(source, errors);
  return switch (destination) {
    NewProjectDestination() => _asNewProject(
      source,
      decks,
      destination,
      defaultDeckName,
      errors,
    ),
    NewDeckDestination() => _asNewDeck(source, decks, destination, errors),
    ExistingDeckDestination(:final deckId) => _intoDeck(
      decks.single,
      deckId,
      deckCards,
      takenCardIds,
      errors,
    ),
  };
}

ImportPlan _asNewProject(
  ImportSource source,
  List<_IncomingDeck> decks,
  NewProjectDestination destination,
  String defaultDeckName,
  List<ImportIssue> errors,
) => ImportPlan(
  project: switch (source) {
    ProjectFileSource(:final project) => PlannedProject(
      name: destination.name,
      description: project.description,
      color: project.color,
      icon: project.icon,
    ),
    // The defaults of a project created by hand (assumption 17).
    _ => PlannedProject(name: destination.name, color: 'orange', icon: 'book'),
  },
  decks: source is CsvSource
      ? _groupByDeck(decks.single, defaultDeckName, destination.settings)
      : [for (final deck in decks) deck.planned(keepIds: false)],
  errors: errors,
);

/// A CSV takes the name and type the user chose; a JSON deck takes the
/// name and keeps its own type and languages.
ImportPlan _asNewDeck(
  ImportSource source,
  List<_IncomingDeck> decks,
  NewDeckDestination destination,
  List<ImportIssue> errors,
) {
  final deck = decks.single.planned(keepIds: false);
  return ImportPlan(
    projectId: destination.projectId,
    decks: [
      PlannedDeck(
        name: destination.name,
        description: deck.description,
        color: deck.color,
        settings: source is CsvSource ? destination.settings : deck.settings,
        cards: deck.cards,
      ),
    ],
    errors: errors,
  );
}

/// Adds the cards to an existing deck, which keeps its type, skipping the
/// duplicates of [deckCards] (rule 4).
ImportPlan _intoDeck(
  _IncomingDeck incoming,
  String deckId,
  List<Flashcard> deckCards,
  Set<String> takenCardIds,
  List<ImportIssue> errors,
) {
  final deckIds = {for (final card in deckCards) card.id};
  final contents = {for (final card in deckCards) _contentKey(card)};
  final duplicates = <ImportIssue>[];
  final cards = <PlannedCard>[];
  for (final card in incoming.cards) {
    if (deckIds.contains(card.fileId) ||
        contents.contains(_inputKey(card.input))) {
      duplicates.add(card.issue());
    } else {
      final id = card.fileId;
      cards.add(card.planned(keepId: id != null && !takenCardIds.contains(id)));
    }
  }
  return ImportPlan(
    decks: [PlannedDeck(existingId: deckId, name: '', cards: cards)],
    errors: errors,
    duplicates: duplicates,
  );
}

/// A card read from the file, before deciding where it goes.
class _IncomingCard {
  const new({
    required this.input,
    this.fileId,
    this.row,
    this.deckName,
    this.questionImage,
    this.answerImage,
  });

  final CardInput input;

  /// The card's ID in a JSON file.
  final String? fileId;

  /// The row in a CSV file.
  final int? row;

  /// The CSV `deck` column.
  final String? deckName;
  final ExchangeImage? questionImage;
  final ExchangeImage? answerImage;

  PlannedCard planned({required bool keepId}) => PlannedCard(
    input: input,
    id: keepId ? fileId : null,
    row: row,
    questionImage: questionImage,
    answerImage: answerImage,
  );

  ImportIssue issue([ImportProblem? problem]) => ImportIssue(
    row: row,
    question: _questionOf(input.question),
    problem: problem,
  );
}

/// A deck read from the file, before deciding where it goes. A CSV gives
/// one with every row.
class _IncomingDeck {
  const new({required this.cards, this.file});

  /// The deck of a JSON file, for its name, look and type.
  final ExchangeDeck? file;
  final List<_IncomingCard> cards;

  PlannedDeck planned({required bool keepIds}) => PlannedDeck(
    name: file?.name.trim() ?? '',
    description: file?.description,
    color: file?.color,
    settings: DeckSettings(
      type: file?.type ?? DeckType.general,
      sourceLang: file?.sourceLang,
      targetLang: file?.targetLang,
    ),
    cards: [for (final card in cards) card.planned(keepId: keepIds)],
  );
}

/// The decks of [source], with valid cards only; the invalid ones are
/// added to [errors].
List<_IncomingDeck> _decksOf(ImportSource source, List<ImportIssue> errors) {
  switch (source) {
    case CsvSource(:final csv):
      errors.addAll([
        for (final error in csv.errors)
          ImportIssue(
            row: error.row,
            question: error.question,
            problem: _csvProblems[error.problem],
          ),
      ]);
      return [
        _IncomingDeck(
          cards: [
            for (final card in csv.cards)
              _IncomingCard(
                input: card.input,
                row: card.row,
                deckName: card.deck,
              ),
          ],
        ),
      ];
    case DeckFileSource(:final deck):
      return [_fileDeck(deck, errors)];
    case ProjectFileSource(:final project):
      return [for (final deck in project.decks) _fileDeck(deck, errors)];
  }
}

_IncomingDeck _fileDeck(ExchangeDeck deck, List<ImportIssue> errors) {
  final cards = <_IncomingCard>[];
  for (final card in deck.cards) {
    final incoming = _IncomingCard(
      fileId: card.id,
      input: CardInput(
        type: card.type,
        question: card.question,
        answer: card.answer,
        explanation: card.explanation,
        allowMultiple: card.allowMultiple,
        example: card.example,
        notes: card.notes,
        options: [
          for (final option in card.options)
            CardOptionInput(text: option.text, isCorrect: option.isCorrect),
        ],
      ),
      questionImage: card.questionImage,
      answerImage: card.answerImage,
    );
    final problems = incoming.input.validate();
    if (problems.isEmpty) {
      cards.add(incoming);
    } else {
      errors.add(incoming.issue(_cardProblems[problems.first]));
    }
  }
  return _IncomingDeck(file: deck, cards: cards);
}

/// CSV rows go to the deck named in their `deck` column, or to
/// [defaultName]; decks keep the order in which the file first names them.
/// Every deck gets the [settings] the user chose once (rule 6).
List<PlannedDeck> _groupByDeck(
  _IncomingDeck csv,
  String defaultName,
  DeckSettings settings,
) {
  final groups = <String, List<PlannedCard>>{};
  for (final card in csv.cards) {
    final name = _deckName(card.deckName) ?? defaultName;
    groups.putIfAbsent(name, () => []).add(card.planned(keepId: false));
  }
  return [
    for (final MapEntry(key: name, value: cards) in groups.entries)
      PlannedDeck(name: name, settings: settings, cards: cards),
  ];
}

/// A `deck` cell as a deck name: trimmed and cut to the longest name a
/// deck can have; null if empty.
String? _deckName(String? cell) {
  final name = cell?.trim() ?? '';
  if (name.isEmpty) return null;
  return name.length <= DeckInput.maxNameLength
      ? name
      : name.substring(0, DeckInput.maxNameLength).trim();
}

String? _questionOf(String question) {
  final trimmed = question.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// What makes two cards the same for rule 4: their type, question and
/// answer (or options in order), trimmed and ignoring case.
String _key(CardType type, String question, Iterable<String> answers) => [
  type.name,
  question,
  ...answers,
].map((text) => text.trim().toLowerCase()).join('\u0000');

String _inputKey(CardInput input) => _key(
  input.type,
  input.question,
  input.type == CardType.test
      ? [for (final option in input.filledOptions) option.text]
      : [input.answer ?? ''],
);

String _contentKey(Flashcard card) => _key(
  card.type,
  card.question,
  card.type == CardType.test
      ? [for (final option in card.options) option.text]
      : [card.answer ?? ''],
);

const Map<CsvRowProblem, ImportProblem> _csvProblems = {
  CsvRowProblem.questionMissing: ImportProblem.questionMissing,
  CsvRowProblem.answerMissing: ImportProblem.answerMissing,
  CsvRowProblem.tooFewOptions: ImportProblem.tooFewOptions,
  CsvRowProblem.noCorrectOption: ImportProblem.noCorrectOption,
  CsvRowProblem.invalidCorrect: ImportProblem.invalidCorrect,
};

const Map<CardInputError, ImportProblem> _cardProblems = {
  CardInputError.questionMissing: ImportProblem.questionMissing,
  CardInputError.answerMissing: ImportProblem.answerMissing,
  CardInputError.tooFewOptions: ImportProblem.tooFewOptions,
  CardInputError.tooManyOptions: ImportProblem.tooManyOptions,
  CardInputError.noCorrectOption: ImportProblem.noCorrectOption,
  CardInputError.tooManyCorrectOptions: ImportProblem.tooManyCorrectOptions,
};
