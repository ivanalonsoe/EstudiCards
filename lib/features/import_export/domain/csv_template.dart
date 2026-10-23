// "Descargar plantilla" and "Prompt para IA" (US-28, SPEC §8.3 and §8.5).
// Both are part of the file format: the column names are always in English,
// and the prompts are not in the ARB file (there is one in Spanish and one
// in English, whatever the UI language). The prompts keep each line whole,
// so they can be read and compared at a glance.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:typed_data';

import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/import_export/domain/cards_csv.dart';
import 'package:estudicards/features/import_export/domain/exchange_document.dart';
import 'package:estudicards/features/import_export/domain/export_names.dart';

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

/// What the AI is asked to do ("Prompt para IA", SPEC §8.5).
enum AiPromptMode {
  /// Turn the data the user pastes (e.g. a vocabulary list) into cards,
  /// adding nothing else.
  fromData,

  /// Write new cards about a topic.
  newContent,
}

/// The language the prompt is written in. The column names stay in English
/// in both, since they are part of the file format.
enum AiPromptLanguage { spanish, english }

/// The languages of a language deck, as BCP-47 codes (`en-GB`).
typedef DeckLanguages = ({String source, String target});

/// The text "Prompt para IA" copies (SPEC §8.5) for a deck called
/// [deckName]: [deckLanguages] for a language deck, null for a general one.
/// The user replaces the square brackets. Its header row is the template's
/// ([csvColumns]); a test checks it.
String aiPrompt({
  required AiPromptMode mode,
  required AiPromptLanguage language,
  required String deckName,
  DeckLanguages? deckLanguages,
}) {
  final file = exportFileName([deckName], 'csv');
  final lines = switch (language) {
    .english => _englishPrompt(mode, file, deckLanguages),
    .spanish => _spanishPrompt(mode, file, deckLanguages),
  };
  return lines.join('\n');
}

List<String> _englishPrompt(
  AiPromptMode mode,
  String file,
  DeckLanguages? languages,
) => [
  if (mode == .newContent)
    'Generate [NUMBER] flashcards about [TOPIC] in CSV format to import into the EstudiCards app.'
  else ...[
    'Create flashcards in CSV format to import into the EstudiCards app, using only the information I give you at the end of this message.',
    'Do not add anything that is not in my data. Make one card for each item.',
  ],
  switch ((languages, mode)) {
    (null, .newContent) => 'This is a general deck: write the cards in [LANGUAGE] and leave "example" and "notes" empty.',
    (null, .fromData) => 'This is a general deck: keep the language of my data and leave "example" and "notes" empty.',
    (final pair?, .newContent) =>
      'This is a language deck: write the questions in ${pair.source} and the answers in ${pair.target}. Add a sentence that uses the word in "example", and anything useful (irregular forms, usage) in "notes".',
    (final pair?, .fromData) =>
      'This is a language deck: the questions are in ${pair.source} and the answers in ${pair.target}. Fill in "example" and "notes" only with what my data has.',
  },
  '',
  'Format rules:',
  '- Separator: semicolon (;). Encoding: UTF-8.',
  '- First row, exactly this header:',
  '  question;answer;option1;option2;option3;option4;option5;option6;correct;explanation;example;notes',
  '- Simple card: fill in "question" and "answer"; leave the options and "correct" empty.',
  '- Multiple-choice card: fill in "question", 2 to 6 options, and in "correct" the number(s) of the correct options separated by | (for example: 2 or 1|3). Leave "answer" empty. "explanation" is optional.',
  '- If a text contains a semicolon or a line break, wrap it in double quotes.',
  '- You may use **bold** and *italic*.',
  '',
  if (mode == .newContent)
    'I want about [PERCENTAGE]% multiple-choice cards. Level: [LEVEL].'
  else
    'Make simple cards, unless my data has options to choose from.',
  'Return a file named "$file" with only the CSV. If you cannot create files, return only the CSV, with no explanations and no code blocks.',
  if (mode == .fromData) ...['', 'My data:', '[PASTE YOUR DATA HERE]'],
];

List<String> _spanishPrompt(
  AiPromptMode mode,
  String file,
  DeckLanguages? languages,
) => [
  if (mode == .newContent)
    'Genera [NÚMERO] tarjetas sobre [TEMA] en formato CSV para importarlas en la app EstudiCards.'
  else ...[
    'Crea tarjetas en formato CSV para importarlas en la app EstudiCards, usando solo la información que te doy al final de este mensaje.',
    'No añadas nada que no esté en mis datos. Haz una tarjeta por cada elemento.',
  ],
  switch ((languages, mode)) {
    (null, .newContent) => 'Es una baraja general: escribe las tarjetas en [IDIOMA] y deja vacíos "example" y "notes".',
    (null, .fromData) => 'Es una baraja general: mantén el idioma de mis datos y deja vacíos "example" y "notes".',
    (final pair?, .newContent) =>
      'Es una baraja de idiomas: escribe las preguntas en ${pair.source} y las respuestas en ${pair.target}. Pon en "example" una frase que use la palabra, y en "notes" lo que sea útil (formas irregulares, uso).',
    (final pair?, .fromData) =>
      'Es una baraja de idiomas: las preguntas están en ${pair.source} y las respuestas en ${pair.target}. Rellena "example" y "notes" solo con lo que tengan mis datos.',
  },
  '',
  'Reglas de formato:',
  '- Separador: punto y coma (;). Codificación: UTF-8.',
  '- Primera fila, exactamente esta cabecera:',
  '  question;answer;option1;option2;option3;option4;option5;option6;correct;explanation;example;notes',
  '- Tarjeta simple: rellena "question" y "answer"; deja vacías las opciones y "correct".',
  '- Tarjeta tipo test: rellena "question", de 2 a 6 opciones y, en "correct", el número o números de las opciones correctas separados por | (por ejemplo: 2 o 1|3). Deja "answer" vacío. "explanation" es opcional.',
  '- Si un texto contiene un punto y coma o un salto de línea, ponlo entre comillas dobles.',
  '- Puedes usar **negrita** y *cursiva*.',
  '',
  if (mode == .newContent)
    'Quiero alrededor de un [PORCENTAJE]% de tarjetas tipo test. Nivel: [NIVEL].'
  else
    'Haz tarjetas simples, salvo que mis datos tengan opciones para elegir.',
  'Devuelve un fichero llamado "$file" solo con el CSV. Si no puedes crear ficheros, devuelve solo el CSV, sin explicaciones ni bloques de código.',
  if (mode == .fromData) ...['', 'Mis datos:', '[PEGA AQUÍ TUS DATOS]'],
];
