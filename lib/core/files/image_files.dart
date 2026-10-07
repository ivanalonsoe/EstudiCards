/// The card images stored in the app's images folder (SPEC §3.4).
///
/// It is an interface so the trash can delete images without knowing where
/// they live, and tests can pass a fake that records the paths.
abstract interface class ImageFiles {
  /// Deletes the images at these paths, relative to the images folder.
  /// Paths that do not exist are ignored.
  Future<void> delete(Iterable<String> relativePaths);
}

/// Cards cannot have images until T2.6, which replaces this with the real
/// images folder. Until then there is nothing to delete.
class NoImageFiles implements ImageFiles {
  const new();

  @override
  Future<void> delete(Iterable<String> relativePaths) async {}
}
