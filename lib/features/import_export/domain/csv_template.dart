// "Descargar plantilla" and "Copiar prompt para IA" (US-28, SPEC §8.3 and
// §8.5). Both are part of the file format, so they are in English (the
// column names) or Spanish sample content, and never translated with the UI.
// The prompt keeps each line whole, as in SPEC §8.5, so the two can be
// compared at a glance.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';

/// The name of the downloaded template (SPEC §8.3).
const csvTemplateFileName = 'estudicards_template.csv';

/// The sample rows of SPEC §8.3: a simple card with an example and notes, a
/// test card with one correct option and one with two.
const _templateCards = [
  ExchangeCard(
    id: 'template-1',
    type: CardType.simple,
    question: 'to bring',
    answer: 'traer (brought, brought)',
    example: 'Can you bring me some water?',
    notes: 'Verbo irregular',
  ),
  ExchangeCard(
    id: 'template-2',
    type: CardType.test,
    question: '¿Capital de Australia?',
    explanation: 'Canberra es la capital desde 1913.',
    options: [
      ExchangeOption(id: 'o1', text: 'Sídney', isCorrect: false),
      ExchangeOption(id: 'o2', text: 'Canberra', isCorrect: true),
      ExchangeOption(id: 'o3', text: 'Melbourne', isCorrect: false),
    ],
  ),
  ExchangeCard(
    id: 'template-3',
    type: CardType.test,
    question: '¿Qué números son primos?',
    allowMultiple: true,
    explanation: 'El 4 y el 9 tienen divisores distintos de 1 y de sí mismos.',
    options: [
      ExchangeOption(id: 'o4', text: '2', isCorrect: true),
      ExchangeOption(id: 'o5', text: '4', isCorrect: false),
      ExchangeOption(id: 'o6', text: '7', isCorrect: true),
      ExchangeOption(id: 'o7', text: '9', isCorrect: false),
    ],
  ),
];

/// The template "Descargar plantilla" saves (US-28): the same format as a
/// shared deck (BOM, `;`, the English column names), so it opens well in
/// Spanish Excel and imports with no errors.
Uint8List csvTemplate() => encodeCardsCsv([
  const ExchangeDeck(id: 'template', name: 'Plantilla', cards: _templateCards),
]);

/// The text "Copiar prompt para IA" copies (SPEC §8.5). It is in English so
/// it works with any AI; the user replaces the square brackets. Its header
/// row is the template's ([csvColumns]); a test checks it.
final String aiPrompt = _aiPromptLines.join('\n');

const _aiPromptLines = [
  'Generate [NUMBER] flashcards about [TOPIC] in CSV format to import into the EstudiCards app.',
  'Write the content of the cards in [LANGUAGE].',
  '',
  'Format rules:',
  '- Separator: semicolon (;). Encoding: UTF-8.',
  '- First row, exactly this header:',
  '  question;answer;option1;option2;option3;option4;option5;option6;correct;explanation;example;notes',
  '- Simple card: fill in "question" and "answer"; leave the options and "correct" empty.',
  '- Multiple-choice card: fill in "question", 2 to 6 options, and in "correct" the number(s) of the correct options separated by | (for example: 2 or 1|3). Leave "answer" empty. "explanation" is optional.',
  '- "example" and "notes" are optional (useful for language learning).',
  '- If a text contains a semicolon or a line break, wrap it in double quotes.',
  '- You may use **bold** and *italic*.',
  '',
  'I want about [PERCENTAGE]% multiple-choice cards. Level: [LEVEL].',
  'Return only the CSV, with no explanations and no code blocks.',
];
