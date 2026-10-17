// The contents of an EstudiCards JSON file (SPEC §8.2), as plain Dart.
//
// These classes are what a file holds, not what the database holds: images
// travel as bytes instead of paths, options are in their editing order and a
// shared file has no statistics. `exchange_json.dart` converts them to and
// from JSON; the import engine (T5.3) and the backup (T5.7, T5.8) turn them
// into database rows.
import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/decks/domain/deck.dart';

/// What a file holds (SPEC §8.1). The enum name is the value in the file.
enum ExchangeKind { backup, project, deck }

/// A card image inside a file: the JPEG itself, not a path (SPEC §8.2).
class ExchangeImage {
  const new(this.bytes);

  /// The only type the app writes and accepts: every stored card image is
  /// a JPEG (SPEC §3.4).
  static const mime = 'image/jpeg';

  final Uint8List bytes;
}

class ExchangeOption {
  const new({required this.id, required this.text, required this.isCorrect});

  final String id;
  final String text;
  final bool isCorrect;
}

class ExchangeCard {
  const new({
    required this.id,
    required this.type,
    required this.question,
    this.answer,
    this.explanation,
    this.allowMultiple = false,
    this.example,
    this.notes,
    this.questionImage,
    this.answerImage,
    this.options = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final CardType type;
  final String question;
  final String? answer;
  final String? explanation;
  final bool allowMultiple;
  final String? example;
  final String? notes;
  final ExchangeImage? questionImage;
  final ExchangeImage? answerImage;

  /// In their editing order (`card_options.position`).
  final List<ExchangeOption> options;

  /// Only in a backup; a shared file leaves them out.
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class ExchangeDeck {
  const new({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.type = DeckType.general,
    this.sourceLang,
    this.targetLang,
    this.cards = const [],
    this.deletedAt,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;

  /// Null = inherits the project colour, as in the database.
  final String? color;
  final DeckType type;
  final String? sourceLang;
  final String? targetLang;
  final List<ExchangeCard> cards;

  // Only in a backup.
  final DateTime? deletedAt;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class ExchangeProject {
  const new({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.description,
    this.decks = const [],
    this.isFavorite = false,
    this.isArchived = false,
    this.archivedAt,
    this.deletedAt,
    this.lastUsedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final List<ExchangeDeck> decks;

  // Only in a backup: they are the owner's own state, not content to share.
  final bool isFavorite;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// A `study_sessions` row (SPEC §4.2). Text fields keep their stored values
/// (`per_card`, `time_up`…).
class ExchangeSession {
  const new({
    required this.id,
    required this.projectId,
    required this.mode,
    required this.direction,
    required this.prioritizeFailed,
    required this.repeatFailed,
    required this.timerType,
    required this.status,
    required this.startedAt,
    required this.activeDurationMs,
    required this.correctTotal,
    required this.wrongTotal,
    required this.unansweredTotal,
    this.requestedCount,
    this.timerSeconds,
    this.endedAt,
  });

  final String id;
  final String projectId;
  final String mode;
  final String direction;
  final int? requestedCount;
  final bool prioritizeFailed;
  final bool repeatFailed;
  final String timerType;
  final int? timerSeconds;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int activeDurationMs;
  final int correctTotal;
  final int wrongTotal;
  final int unansweredTotal;
}

class ExchangeSessionDeck {
  const new({required this.sessionId, required this.deckId});

  final String sessionId;
  final String deckId;
}

class ExchangeAttempt {
  const new({
    required this.id,
    required this.sessionId,
    required this.cardId,
    required this.direction,
    required this.result,
    required this.source,
    required this.isFirstAttempt,
    required this.answeredAt,
    this.selectedOptionIds,
    this.responseTimeMs,
    this.localDay,
  });

  final String id;
  final String sessionId;
  final String cardId;
  final String direction;
  final String result;
  final String source;
  final bool isFirstAttempt;

  /// The ticked options of a test card; null for a simple card.
  final List<String>? selectedOptionIds;
  final int? responseTimeMs;
  final DateTime answeredAt;

  /// `YYYY-MM-DD`, the day the user answered in their own time zone
  /// (`attempts.local_day`). Null only in a file that lacks it; restoring
  /// works it out again from [answeredAt].
  final String? localDay;
}

class ExchangeCardStats {
  const new({
    required this.cardId,
    required this.direction,
    required this.correctCount,
    required this.wrongCount,
    required this.consecutiveCorrect,
    required this.inErrorList,
    this.lastResult,
    this.lastAttemptAt,
  });

  final String cardId;
  final String direction;
  final int correctCount;
  final int wrongCount;
  final int consecutiveCorrect;
  final bool inErrorList;
  final String? lastResult;
  final DateTime? lastAttemptAt;
}

/// A whole file: the common header and what `data` holds for its kind.
///
/// `sealed` means these three subclasses are the only ones, so a `switch`
/// over a document must handle each kind and the compiler checks it.
sealed class ExchangeDocument {
  const new({required this.exportedAt, required this.appVersion});

  final DateTime exportedAt;

  /// The app version that wrote the file, for diagnosis only.
  final String appVersion;

  ExchangeKind get kind;
}

/// A shared deck, with no statistics (US-26).
class DeckDocument extends ExchangeDocument {
  const new({
    required super.exportedAt,
    required super.appVersion,
    required this.deck,
  });

  final ExchangeDeck deck;

  @override
  ExchangeKind get kind => ExchangeKind.deck;
}

/// A shared project with its decks and cards, with no statistics (US-26).
class ProjectDocument extends ExchangeDocument {
  const new({
    required super.exportedAt,
    required super.appVersion,
    required this.project,
  });

  final ExchangeProject project;

  @override
  ExchangeKind get kind => ExchangeKind.project;
}

/// Everything in the database (US-24), including archived projects and
/// projects in the trash.
class BackupDocument extends ExchangeDocument {
  const new({
    required super.exportedAt,
    required super.appVersion,
    this.projects = const [],
    this.sessions = const [],
    this.sessionDecks = const [],
    this.attempts = const [],
    this.cardStats = const [],
    this.settings = const {},
  });

  final List<ExchangeProject> projects;
  final List<ExchangeSession> sessions;
  final List<ExchangeSessionDeck> sessionDecks;
  final List<ExchangeAttempt> attempts;
  final List<ExchangeCardStats> cardStats;

  /// The `settings` table as key → value.
  final Map<String, String?> settings;

  @override
  ExchangeKind get kind => ExchangeKind.backup;
}
