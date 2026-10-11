// Text-to-speech with the voices installed on the system (SPEC §3.5,
// US-13). It is an interface so tests can pass a fake that records what is
// read; the app uses `SystemVoice` (the `flutter_tts` package).

/// A voice installed on the system: its name and its BCP-47 locale.
typedef VoiceInfo = ({String name, String locale});

abstract interface class Voice {
  /// Whether the system has a voice for [language] (a BCP-47 code such as
  /// `en-GB`).
  Future<bool> isAvailable(String language);

  /// Reads [text] aloud in [language], stopping what was being read.
  Future<void> speak(String text, {required String language});
}

/// The voice to read [language] with: one with the same language and
/// region, or else one with the same language (an `en-US` voice can read
/// `en-GB`). Null if no voice speaks the language.
VoiceInfo? bestVoice(String language, Iterable<VoiceInfo> voices) {
  // Systems write locales as `en-GB`, `en_GB` or `en-gb`.
  String normalize(String locale) => locale.replaceAll('_', '-').toLowerCase();
  String languagePart(String locale) => normalize(locale).split('-').first;

  final wanted = normalize(language);
  final sameLanguage = [
    for (final voice in voices)
      if (languagePart(voice.locale) == languagePart(wanted)) voice,
  ];
  return sameLanguage
          .where((voice) => normalize(voice.locale) == wanted)
          .firstOrNull ??
      sameLanguage.firstOrNull;
}
