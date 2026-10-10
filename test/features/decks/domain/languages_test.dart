import 'package:estudicards/features/decks/domain/languages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shortLanguageCode', () {
    test('is the language part of the code, in capitals', () {
      expect(shortLanguageCode('en-GB'), 'EN');
      expect(shortLanguageCode('es-ES'), 'ES');
      expect(shortLanguageCode('zh-CN'), 'ZH');
    });

    test('keeps a code without a region whole', () {
      expect(shortLanguageCode('fil'), 'FIL');
    });
  });
}
