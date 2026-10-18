// Restores a full backup (US-25, SPEC §8.4 rule 7).
//
// - Empty database: everything goes in as it is in the file.
// - "Reemplazar todo": an automatic backup of the current data is saved
//   first; then the data is deleted and the file's goes in as it is.
// - "Fusionar": rows are merged by ID. A project, deck or card that is in
//   both keeps the version with the most recent `updated_at`; sessions,
//   attempts and settings already here are kept and the missing ones are
//   added; `card_stats` is then recalculated from all the attempts.
//
// Either way the database part is one transaction (rule 8): all of it or
// nothing.
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/db/app_database.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/import_export/data/auto_backup_files.dart';
import 'package:estudicards/features/import_export/data/backup_dao.dart';
import 'package:estudicards/features/import_export/data/exchange_repository.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';

/// What to do with the current data when restoring (US-25).
enum RestoreMode { replaceAll, merge }

class RestoreResult {
  const new({this.autoBackup, this.imagesSkipped = 0});

  /// The automatic backup of the data that "Reemplazar todo" deleted; null
  /// when nothing was deleted.
  final AutoBackup? autoBackup;

  /// Images of the file that could not be stored; their cards came
  /// without them.
  final int imagesSkipped;
}

/// The stored image paths of one card, once its images are files.
typedef _CardImages = ({String? question, String? answer});

class BackupRepository {
  /// [encode] writes a backup file; in the app it runs in a background
  /// isolate, as a large backup takes a while.
  new(
    this._dao,
    this._clock,
    this._images,
    this._exchange,
    this._autoBackups, {
    required this.encode,
  });

  final BackupDao _dao;
  final Clock _clock;
  final ImageFiles _images;
  final ExchangeRepository _exchange;
  final AutoBackupFiles _autoBackups;
  final Future<Uint8List> Function(BackupDocument backup) encode;

  /// Whether there is nothing to lose: then the app restores without
  /// asking (§8.4 rule 7).
  Future<bool> isEmpty() => _dao.isEmpty();

  Future<RestoreResult> restore(BackupDocument backup, RestoreMode mode) =>
      switch (mode) {
        RestoreMode.replaceAll => _replaceAll(backup),
        RestoreMode.merge => _merge(backup),
      };

  Future<RestoreResult> _replaceAll(BackupDocument backup) async {
    // Before deleting anything, the current data goes to an automatic
    // backup (decided with the owner).
    AutoBackup? autoBackup;
    if (!await _dao.isEmpty()) {
      autoBackup = await _autoBackups.save(
        await encode(await _exchange.exportBackup()),
        _clock.now(),
      );
    }
    final oldImages = [
      for (final card in await _dao.allCards()) ...[
        ?card.questionImage,
        ?card.answerImage,
      ],
    ];
    final allCards = [
      for (final project in backup.projects)
        for (final deck in project.decks) ...deck.cards,
    ];
    final (images, skipped) = await _storeImages(allCards);
    try {
      await _dao.transaction(() async {
        await _dao.deleteAll();
        await _insertProjects(backup.projects, images, onlyNewer: null);
        await _insertHistory(backup);
        for (final stats in backup.cardStats) {
          await _dao.addCardStats(_cardStats(stats));
        }
      });
    } catch (_) {
      await _images.delete(images.values.expand(_paths));
      rethrow;
    }
    // Only after the transaction, so a failed restore never loses one.
    await _images.delete(oldImages);
    return RestoreResult(autoBackup: autoBackup, imagesSkipped: skipped);
  }

  Future<RestoreResult> _merge(BackupDocument backup) async {
    final projectUpdates = await _dao.projectUpdates();
    final deckUpdates = await _dao.deckUpdates();
    final localCards = {for (final c in await _dao.allCards()) c.id: c};
    final newer = _Newer(
      projects: projectUpdates,
      decks: deckUpdates,
      cards: {for (final c in localCards.values) c.id: c.updatedAt},
    );
    // Only the cards that win bring their images.
    final winners = [
      for (final project in backup.projects)
        for (final deck in project.decks)
          for (final card in deck.cards)
            if (newer.card(card)) card,
    ];
    final (images, skipped) = await _storeImages(winners);
    try {
      await _dao.transaction(() async {
        await _insertProjects(backup.projects, images, onlyNewer: newer);
        await _insertHistory(backup);
        // Statistics are derived: they are worked out again from every
        // attempt, the old ones and the restored ones (§8.4 rule 7).
        // Inside this transaction: drift runs the nested one as part of it.
        await _dao.attachedDatabase.recomputeCardStats();
      });
    } catch (_) {
      await _images.delete(images.values.expand(_paths));
      rethrow;
    }
    // The images of the local cards that the file's versions replaced.
    await _images.delete([
      for (final card in winners)
        if (localCards[card.id] case final old?) ...[
          ?old.questionImage,
          ?old.answerImage,
        ],
    ]);
    return RestoreResult(imagesSkipped: skipped);
  }

  /// Stores the images of [cards] as new files. Returns their paths by
  /// card, and how many could not be stored.
  Future<(Map<ExchangeCard, _CardImages>, int)> _storeImages(
    List<ExchangeCard> cards,
  ) async {
    final stored = Map<ExchangeCard, _CardImages>.identity();
    var skipped = 0;
    Future<String?> store(ExchangeImage? image) async {
      if (image == null) return null;
      final path = await _images.saveImported(image.bytes);
      if (path == null) skipped++;
      return path;
    }

    try {
      for (final card in cards) {
        stored[card] = (
          question: await store(card.questionImage),
          answer: await store(card.answerImage),
        );
      }
    } catch (_) {
      await _images.delete(stored.values.expand(_paths));
      rethrow;
    }
    return (stored, skipped);
  }

  static Iterable<String> _paths(_CardImages images) => [
    ?images.question,
    ?images.answer,
  ];

  /// Writes the projects, decks and cards of the file. When merging,
  /// [onlyNewer] says which ones win; null writes them all.
  Future<void> _insertProjects(
    List<ExchangeProject> projects,
    Map<ExchangeCard, _CardImages> images, {
    required _Newer? onlyNewer,
  }) async {
    final now = _clock.now();
    for (final project in projects) {
      if (onlyNewer?.project(project) ?? true) {
        await _dao.upsertProject(_project(project, now));
      }
      for (final deck in project.decks) {
        if (onlyNewer?.deck(deck) ?? true) {
          await _dao.upsertDeck(_deck(deck, project.id, now));
        }
        for (final card in deck.cards) {
          if (!(onlyNewer?.card(card) ?? true)) continue;
          final paths = images[card] ?? (question: null, answer: null);
          await _dao.upsertCard(_card(card, deck.id, paths, now));
          await _dao.replaceOptions(card.id, [
            for (final (position, option) in card.options.indexed)
              CardOptionsCompanion.insert(
                id: option.id,
                cardId: card.id,
                optionText: option.text,
                isCorrect: option.isCorrect,
                position: position,
              ),
          ]);
        }
      }
    }
  }

  /// Adds the sessions, attempts and settings that are not here yet.
  Future<void> _insertHistory(BackupDocument backup) async {
    for (final s in backup.sessions) {
      await _dao.addSession(
        StudySessionsCompanion.insert(
          id: s.id,
          projectId: s.projectId,
          mode: s.mode,
          direction: s.direction,
          requestedCount: Value(s.requestedCount),
          prioritizeFailed: s.prioritizeFailed,
          repeatFailed: s.repeatFailed,
          timerType: s.timerType,
          timerSeconds: Value(s.timerSeconds),
          status: s.status,
          startedAt: s.startedAt,
          endedAt: Value(s.endedAt),
          activeDurationMs: Value(s.activeDurationMs),
          correctTotal: Value(s.correctTotal),
          wrongTotal: Value(s.wrongTotal),
          unansweredTotal: Value(s.unansweredTotal),
        ),
      );
    }
    for (final s in backup.sessionDecks) {
      await _dao.addSessionDeck(
        SessionDecksCompanion.insert(sessionId: s.sessionId, deckId: s.deckId),
      );
    }
    for (final a in backup.attempts) {
      await _dao.addAttempt(
        AttemptsCompanion.insert(
          id: a.id,
          sessionId: a.sessionId,
          cardId: a.cardId,
          direction: a.direction,
          result: a.result,
          source: a.source,
          isFirstAttempt: a.isFirstAttempt,
          selectedOptionIds: Value(switch (a.selectedOptionIds) {
            final ids? => jsonEncode(ids),
            null => null,
          }),
          responseTimeMs: Value(a.responseTimeMs),
          answeredAt: a.answeredAt,
          // A file without local days gets them from this device's time
          // zone, as the schema version 4 migration did (assumption 45).
          localDay: Value(a.localDay ?? dayKey(_clock.localDay(a.answeredAt))),
        ),
      );
    }
    for (final MapEntry(:key, :value) in backup.settings.entries) {
      await _dao.addSetting(
        SettingsCompanion.insert(key: key, value: Value(value)),
      );
    }
  }

  // The rows of the file, as they were stored. A file always has the dates
  // (the reader requires them in a backup); [now] only covers a document
  // built in code without them.

  static ProjectsCompanion _project(ExchangeProject p, DateTime now) =>
      ProjectsCompanion.insert(
        id: p.id,
        name: p.name,
        description: Value(p.description),
        color: p.color,
        icon: p.icon,
        isFavorite: Value(p.isFavorite),
        isArchived: Value(p.isArchived),
        archivedAt: Value(p.archivedAt),
        deletedAt: Value(p.deletedAt),
        lastUsedAt: Value(p.lastUsedAt),
        createdAt: p.createdAt ?? now,
        updatedAt: p.updatedAt ?? now,
      );

  static DecksCompanion _deck(ExchangeDeck d, String projectId, DateTime now) =>
      DecksCompanion.insert(
        id: d.id,
        projectId: projectId,
        name: d.name,
        description: Value(d.description),
        color: Value(d.color),
        type: Value(d.type.name),
        sourceLang: Value(d.sourceLang),
        targetLang: Value(d.targetLang),
        deletedAt: Value(d.deletedAt),
        lastUsedAt: Value(d.lastUsedAt),
        createdAt: d.createdAt ?? now,
        updatedAt: d.updatedAt ?? now,
      );

  static CardsCompanion _card(
    ExchangeCard c,
    String deckId,
    _CardImages images,
    DateTime now,
  ) => CardsCompanion.insert(
    id: c.id,
    deckId: deckId,
    type: c.type.name,
    question: c.question,
    questionImage: Value(images.question),
    answer: Value(c.answer),
    answerImage: Value(images.answer),
    explanation: Value(c.explanation),
    allowMultiple: Value(c.allowMultiple),
    example: Value(c.example),
    notes: Value(c.notes),
    createdAt: c.createdAt ?? now,
    updatedAt: c.updatedAt ?? now,
  );

  static CardStatsCompanion _cardStats(ExchangeCardStats s) =>
      CardStatsCompanion.insert(
        cardId: s.cardId,
        direction: s.direction,
        correctCount: Value(s.correctCount),
        wrongCount: Value(s.wrongCount),
        consecutiveCorrect: Value(s.consecutiveCorrect),
        inErrorList: Value(s.inErrorList),
        lastResult: Value(s.lastResult),
        lastAttemptAt: Value(s.lastAttemptAt),
      );
}

/// Which rows of the file win a merge: those missing here, and those whose
/// `updated_at` is more recent than the stored one (§8.4 rule 7).
class _Newer {
  const new({required this.projects, required this.decks, required this.cards});

  final Map<String, DateTime> projects;
  final Map<String, DateTime> decks;
  final Map<String, DateTime> cards;

  bool project(ExchangeProject p) => _wins(projects[p.id], p.updatedAt);
  bool deck(ExchangeDeck d) => _wins(decks[d.id], d.updatedAt);
  bool card(ExchangeCard c) => _wins(cards[c.id], c.updatedAt);

  static bool _wins(DateTime? local, DateTime? file) =>
      local == null || (file != null && file.isAfter(local));
}
