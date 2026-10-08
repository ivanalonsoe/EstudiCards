// Text helpers shared by the searches and sorts of projects and cards.

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

/// [text] in lower case and without accents, so "Inglés" and "ingles"
/// compare as equal.
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_plainLetters[char] ?? char);
  }
  return buffer.toString();
}
