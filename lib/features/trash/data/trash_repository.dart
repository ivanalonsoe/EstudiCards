// The trash (SPEC §7.1, US-03, US-04): projects and decks marked with
// `deleted_at` stay 15 days before they are deleted for good.
import 'package:estudicards/core/clock.dart';
import 'package:estudicards/core/files/image_files.dart';
import 'package:estudicards/features/trash/data/trash_dao.dart';
import 'package:estudicards/features/trash/domain/trash_item.dart';
import 'package:estudicards/features/trash/domain/trash_rules.dart';

class TrashRepository {
  new(this._dao, this._clock, this._images);

  final TrashDao _dao;
  final Clock _clock;
  final ImageFiles _images;

  /// Hides the project, with its decks and cards, from everywhere except
  /// the trash.
  Future<void> moveProjectToTrash(String id) =>
      _dao.setProjectDeletedAt(id, _clock.now());

  Future<void> moveDeckToTrash(String id) =>
      _dao.setDeckDeletedAt(id, _clock.now());

  /// Puts the project back where it was, with its decks. Also undoes a
  /// deletion within the 5 seconds of "Deshacer".
  Future<void> restoreProject(String id) => _dao.setProjectDeletedAt(id, null);

  /// Puts the deck back; if its project is in the trash too, the project
  /// comes back with it (SPEC §7.1).
  Future<void> restoreDeck(String id) => _dao.transaction(() async {
    final deck = await _dao.findDeck(id);
    if (deck == null) return;
    await _dao.setDeckDeletedAt(id, null);
    await _dao.setProjectDeletedAt(deck.projectId, null);
  });

  Future<void> deleteProjectPermanently(String id) =>
      _deleteForGood(projectIds: [id]);

  Future<void> deleteDeckPermanently(String id) =>
      _deleteForGood(deckIds: [id]);

  /// "Vaciar papelera": deletes every project and deck in the trash.
  Future<void> emptyTrash() async {
    await _deleteForGood(
      projectIds: await _dao.trashedProjectIds(),
      deckIds: await _dao.trashedDeckIds(),
    );
  }

  /// Deletes for good the items that have spent 15 days in the trash and
  /// returns how many there were. Called when the app starts and when the
  /// Trash screen opens.
  Future<int> purgeExpired() async {
    final cutoff = _clock.now().subtract(trashRetention);
    final projectIds = await _dao.trashedProjectIds(deletedUpTo: cutoff);
    final deckIds = await _dao.trashedDeckIds(deletedUpTo: cutoff);
    await _deleteForGood(projectIds: projectIds, deckIds: deckIds);
    return projectIds.length + deckIds.length;
  }

  /// The projects and decks in the trash, the most recently deleted first,
  /// read again whenever projects, decks or cards change.
  ///
  /// `async*` makes a stream function: each `yield` emits one value.
  Stream<List<TrashItem>> watchTrash() async* {
    yield await _readTrash();
    await for (final _ in _dao.watchChanges()) {
      yield await _readTrash();
    }
  }

  Future<List<TrashItem>> _readTrash() async => [
    for (final row in await _dao.trashedProjects())
      TrashItem(
        type: TrashItemType.project,
        id: row.project.id,
        name: row.project.name,
        color: row.project.color,
        icon: row.project.icon,
        deckCount: row.deckCount,
        cardCount: row.cardCount,
        deletedAt: row.project.deletedAt!,
      ),
    for (final row in await _dao.trashedDecks())
      TrashItem(
        type: TrashItemType.deck,
        id: row.deck.id,
        name: row.deck.name,
        color: row.deck.color ?? row.project.color,
        cardCount: row.cardCount,
        projectName: row.project.name,
        deletedAt: row.deck.deletedAt!,
      ),
  ]..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));

  /// Deletes the rows in one transaction, then the image files: if the
  /// database write fails, no image is lost.
  Future<void> _deleteForGood({
    Iterable<String> projectIds = const [],
    Iterable<String> deckIds = const [],
  }) async {
    if (projectIds.isEmpty && deckIds.isEmpty) return;
    final images = await _dao.transaction(() async {
      final paths = await _dao.imagePaths(
        projectIds: projectIds,
        deckIds: deckIds,
      );
      await _dao.deleteProjects(projectIds);
      await _dao.deleteDecks(deckIds);
      return paths;
    });
    await _images.delete(images);
  }
}
