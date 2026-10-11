import 'package:estudicards/core/voice/voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bestVoice', () {
    const british = (name: 'Hazel', locale: 'en-GB');
    const american = (name: 'Zira', locale: 'en-US');
    const spanish = (name: 'Helena', locale: 'es_ES');

    test('prefers a voice of the same language and region', () {
      expect(bestVoice('en-GB', [american, british]), british);
    });

    test('falls back to a voice of the same language', () {
      expect(bestVoice('en-GB', [spanish, american]), american);
    });

    test('ignores case and "_" or "-" in the locale', () {
      expect(bestVoice('es-ES', [american, spanish]), spanish);
      expect(bestVoice('ES-es', [spanish]), spanish);
    });

    test('is null when no voice speaks the language', () {
      expect(bestVoice('ja-JP', [british, spanish]), isNull);
      expect(bestVoice('en-GB', []), isNull);
    });
  });
}
