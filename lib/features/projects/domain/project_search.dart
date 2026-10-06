/// Whether a project called [name] matches what the user typed in the
/// search box (US-05 AC3): the text can be anywhere in the name, and case
/// and accents are ignored, so "ingles" finds "Inglés B2".
bool matchesProjectSearch(String name, String query) {
  final normalizedQuery = _normalize(query.trim());
  return normalizedQuery.isEmpty || _normalize(name).contains(normalizedQuery);
}

/// Accented letters used in Spanish and the other languages of the app,
/// mapped to the plain letter.
const _plainLetters = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ñ': 'n', 'ç': 'c',
};

/// Lower case and without accents.
String _normalize(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_plainLetters[char] ?? char);
  }
  return buffer.toString();
}
