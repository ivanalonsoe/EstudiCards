import 'package:estudicards/core/voice/voice.dart';

/// A voice for tests: every language has a voice except those in
/// [missing], and what is read is recorded in [spoken] as (text, language).
class FakeVoice implements Voice {
  new({this.missing = const {}});

  final Set<String> missing;
  final spoken = <(String, String)>[];

  @override
  Future<bool> isAvailable(String language) async =>
      !missing.contains(language);

  @override
  Future<void> speak(String text, {required String language}) async =>
      spoken.add((text, language));
}
