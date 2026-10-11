// What the speaker buttons of a card read, and in which language (US-13).
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:estudicards/features/decks/domain/deck.dart';

/// The parts of a card that can be read aloud.
enum SpeechPart { question, answer, example }

/// A text to read and its BCP-47 language.
typedef Speech = ({String text, String language});

/// The two languages of a language deck.
typedef SpeechLanguages = ({String source, String target});

/// The languages to read [deck]'s cards in; null for a general deck, which
/// has no voice.
SpeechLanguages? speechLanguagesOf(Deck deck) => switch (deck) {
  Deck(isLanguage: true, :final sourceLang?, :final targetLang?) => (
    source: sourceLang,
    target: targetLang,
  ),
  _ => null,
};

/// What to read for [part] of [card]: the question and the example in the
/// source language, the answer in the target language, without the bold
/// and italic marks. Null when there is nothing to read (an empty text, or
/// the answer of a test card).
Speech? speechFor(Flashcard card, SpeechPart part, SpeechLanguages languages) {
  final (text, language) = switch (part) {
    SpeechPart.question => (card.question, languages.source),
    SpeechPart.answer =>
      card.type == CardType.test
          ? (null, languages.target)
          : (card.answer, languages.target),
    SpeechPart.example => (card.example, languages.source),
  };
  final plain = text == null ? '' : _withoutMarks(text).trim();
  return plain.isEmpty ? null : (text: plain, language: language);
}

/// [text] as it is shown: the `**` and `*` marks of bold and italic are not
/// read aloud.
String _withoutMarks(String text) => [
  for (final run in parseInlineFormat(text))
    if (!run.isMarker) run.text,
].join();
