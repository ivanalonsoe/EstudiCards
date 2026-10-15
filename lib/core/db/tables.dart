// Drift tables: every class here becomes one SQLite table (SPEC §4.2).
//
// Drift turns each getter into a column, converting the Dart name to
// snake_case (`deletedAt` → `deleted_at`). From these classes `build_runner`
// generates `app_database.g.dart` with:
//   - a row class per table (`ProjectRow`…), with one field per column;
//   - a "companion" per table (`ProjectsCompanion`), used to insert or update
//     rows when only some columns are given.
//
// Row classes end in `Row` so they do not clash with Flutter widgets (`Card`)
// or with the domain models that later tasks add.
//
// Fields with a fixed set of values (`type`, `status`…) are stored as TEXT
// with the values listed in SPEC §4.2.
//
// This file is only read by the generator and never runs in the app, so it is
// left out of the coverage report:
// coverage:ignore-file
import 'package:drift/drift.dart';

@DataClassName('ProjectRow')
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get description => text().withLength(max: 300).nullable()();

  /// Key from the project palette, e.g. `orange`.
  TextColumn get color => text()();

  /// Emoji or icon key.
  TextColumn get icon => text()();

  // `type`, `source_lang` and `target_lang` were here until schema version 3
  // moved them to `decks`.

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// When the project was archived; null if it is not archived, or if it
  /// was archived before schema version 2 added this column.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Not null = in the trash (SPEC §7.1).
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DeckRow')
@TableIndex(name: 'decks_project_deleted', columns: {#projectId, #deletedAt})
class Decks extends Table {
  TextColumn get id => text()();

  // `references` creates a foreign key: SQLite rejects a deck whose project
  // does not exist, and `cascade` deletes the decks when the project is
  // deleted permanently.
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  TextColumn get description => text().nullable()();

  /// Null = inherits the project colour.
  TextColumn get color => text().nullable()();

  /// `general` | `language`. Moved here from `projects` in schema version 3:
  /// one project can mix both types.
  TextColumn get type => text().withDefault(const Constant('general'))();

  /// BCP-47 codes, e.g. `en-GB`. Required for a language deck; they can be
  /// the same (word → definition).
  TextColumn get sourceLang => text().nullable()();
  TextColumn get targetLang => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CardRow')
@TableIndex(name: 'cards_deck', columns: {#deckId})
class Cards extends Table {
  TextColumn get id => text()();
  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();

  /// `simple` | `test`.
  TextColumn get type => text()();
  TextColumn get question => text()();

  /// Relative paths inside the app's images folder (SPEC §3.4).
  TextColumn get questionImage => text().nullable()();
  TextColumn get answer => text().nullable()();
  TextColumn get answerImage => text().nullable()();
  TextColumn get explanation => text().nullable()();
  BoolColumn get allowMultiple =>
      boolean().withDefault(const Constant(false))();
  TextColumn get example => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CardOptionRow')
class CardOptions extends Table {
  TextColumn get id => text()();
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();
  // Named `text` in SQLite; in Dart `text` is already Drift's column builder.
  TextColumn get optionText => text().named('text')();
  BoolColumn get isCorrect => boolean()();

  /// Order while editing; options are shuffled when studying.
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per card and direction. Derived from `attempts` (SPEC §4.2).
@DataClassName('CardStatsRow')
@TableIndex(name: 'card_stats_in_error_list', columns: {#inErrorList})
class CardStats extends Table {
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();

  /// `normal` | `reverse`.
  TextColumn get direction => text()();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get consecutiveCorrect =>
      integer().withDefault(const Constant(0))();
  BoolColumn get inErrorList => boolean().withDefault(const Constant(false))();

  /// `correct` | `wrong`.
  TextColumn get lastResult => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {cardId, direction};
}

@DataClassName('StudySessionRow')
class StudySessions extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// `normal` | `errors`.
  TextColumn get mode => text()();

  /// `normal` | `reverse`.
  TextColumn get direction => text()();

  /// Null = all cards.
  IntColumn get requestedCount => integer().nullable()();
  BoolColumn get prioritizeFailed => boolean()();
  BoolColumn get repeatFailed => boolean()();

  /// `none` | `per_card` | `global`.
  TextColumn get timerType => text()();
  IntColumn get timerSeconds => integer().nullable()();

  /// `in_progress` | `completed` | `abandoned` | `time_up`.
  TextColumn get status => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// Excludes paused time.
  IntColumn get activeDurationMs => integer().withDefault(const Constant(0))();
  IntColumn get correctTotal => integer().withDefault(const Constant(0))();
  IntColumn get wrongTotal => integer().withDefault(const Constant(0))();
  IntColumn get unansweredTotal => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Decks included in a study session.
@DataClassName('SessionDeckRow')
class SessionDecks extends Table {
  TextColumn get sessionId =>
      text().references(StudySessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get deckId =>
      text().references(Decks, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {sessionId, deckId};
}

@DataClassName('AttemptRow')
@TableIndex(
  name: 'attempts_card_direction_answered',
  columns: {#cardId, #direction, #answeredAt},
)
@TableIndex(name: 'attempts_session', columns: {#sessionId})
@TableIndex(name: 'attempts_local_day', columns: {#localDay})
class Attempts extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(StudySessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get cardId =>
      text().references(Cards, #id, onDelete: KeyAction.cascade)();

  /// `normal` | `reverse`.
  TextColumn get direction => text()();

  /// `correct` | `wrong` | `unanswered`.
  TextColumn get result => text()();

  /// `self_eval` | `test_check` | `timeout` | `revealed` | `session_end`.
  TextColumn get source => text()();

  /// `false` for the repeats of "Repetir falladas al final".
  BoolColumn get isFirstAttempt => boolean()();

  /// JSON list with the ticked option IDs (test cards only).
  TextColumn get selectedOptionIds => text().nullable()();
  IntColumn get responseTimeMs => integer().nullable()();
  DateTimeColumn get answeredAt => dateTime()();

  /// The calendar day of [answeredAt] in the user's local time, as
  /// `YYYY-MM-DD` text (schema version 4). Streaks and "per day" statistics
  /// group by it. The app always fills it; it is nullable only because
  /// SQLite cannot add a required column to a table that has rows.
  TextColumn get localDay => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key–value settings, e.g. `theme_mode` → `system` (SPEC §4.2).
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
