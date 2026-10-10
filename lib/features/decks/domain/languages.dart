/// The languages offered for a language deck, as BCP-47 codes (stored in
/// `decks.source_lang` and `target_lang`). Their names are UI strings.
/// The list was chosen with the owner in T1.3 and can grow later.
const supportedLanguages = [
  'es-ES',
  'en-GB',
  'en-US',
  'fr-FR',
  'de-DE',
  'it-IT',
  'pt-PT',
  'pt-BR',
  'ca-ES',
  'gl-ES',
  'eu-ES',
  'nl-NL',
  'zh-CN',
  'ja-JP',
];

/// The short form of a BCP-47 [code] shown in the deck chips: its language
/// part in capitals, e.g. `EN` for `en-GB`.
String shortLanguageCode(String code) => code.split('-').first.toUpperCase();
