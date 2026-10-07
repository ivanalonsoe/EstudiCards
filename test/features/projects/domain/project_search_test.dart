import 'package:estudicards/features/projects/domain/project_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matchesProjectSearch', () {
    test('ignores case and accents', () {
      expect(matchesProjectSearch('Inglés B2', 'ingles'), isTrue);
      expect(matchesProjectSearch('Inglés B2', 'INGLÉS'), isTrue);
      expect(matchesProjectSearch('Biología 2º Bach.', 'biologia'), isTrue);
      expect(matchesProjectSearch('Alemán A1', 'ALEMAN'), isTrue);
      expect(matchesProjectSearch('Español', 'espanol'), isTrue);
      expect(matchesProjectSearch('Ciències', 'ciencies'), isTrue);
      expect(matchesProjectSearch('Pingüino', 'pinguino'), isTrue);
    });

    test('finds the text anywhere in the name', () {
      expect(matchesProjectSearch('Oposiciones · Tema 3', 'tema'), isTrue);
      expect(matchesProjectSearch('Inglés B2', 'b2'), isTrue);
    });

    test('does not match a name without the text', () {
      expect(matchesProjectSearch('Inglés B2', 'francés'), isFalse);
    });

    test('an empty or blank search matches everything', () {
      expect(matchesProjectSearch('Inglés B2', ''), isTrue);
      expect(matchesProjectSearch('Inglés B2', '   '), isTrue);
    });

    test('ignores spaces around the search', () {
      expect(matchesProjectSearch('Inglés B2', '  ingles '), isTrue);
    });
  });
}
