// The system voices through the `flutter_tts` package. It only forwards to
// the platform, so it cannot run in unit tests (they use a fake `Voice`)
// and is left out of the coverage report; the choice of voice is
// `bestVoice`, which is tested.
// coverage:ignore-file
import 'package:estudicards/core/voice/voice.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SystemVoice implements Voice {
  final _tts = FlutterTts();

  /// The installed voices, asked once.
  late final Future<List<VoiceInfo>> _voices = _loadVoices();

  Future<List<VoiceInfo>> _loadVoices() async {
    try {
      final voices = await _tts.getVoices as List<Object?>? ?? const [];
      return [
        for (final voice in voices)
          if (voice case {'name': final String name, 'locale': final String l})
            (name: name, locale: l),
      ];
    } on Object {
      // A system without a speech engine: no voices.
      return const [];
    }
  }

  @override
  Future<bool> isAvailable(String language) async =>
      bestVoice(language, await _voices) != null;

  @override
  Future<void> speak(String text, {required String language}) async {
    final voice = bestVoice(language, await _voices);
    if (voice == null) return;
    await _tts.stop();
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    await _tts.speak(text);
  }
}
