import 'package:estudicards/core/text_search.dart';

/// Whether a project called [name] matches what the user typed in the
/// search box (US-05 AC3): the text can be anywhere in the name, and case
/// and accents are ignored, so "ingles" finds "Inglés B2".
bool matchesProjectSearch(String name, String query) {
  final normalizedQuery = normalizeForSearch(query.trim());
  return normalizedQuery.isEmpty ||
      normalizeForSearch(name).contains(normalizedQuery);
}
