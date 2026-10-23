import 'dart:math' as math;

import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/layout/breakpoints.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/app/theme/motion.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/cards/domain/card_speech.dart';
import 'package:estudicards/features/cards/domain/flashcard.dart';
import 'package:estudicards/features/cards/domain/inline_format.dart';
import 'package:estudicards/features/cards/presentation/formatted_text.dart';
import 'package:flutter/material.dart';

/// Which side of a card is up.
enum CardFace { front, back }

/// The card as it is studied (`docs/design/tarjetas/`): a `surface` box with
/// radius 24, a band in the project colour, a small label (project · deck)
/// and the card type at the top, and the content centred.
///
/// The editor uses it as the preview; the study session (phase 3) will use
/// it too, which is why it takes the selected options and the result.
/// Changing [face] turns the card over with a 3D flip.
class StudyCard extends StatelessWidget {
  const new({
    required this.card,
    required this.label,
    required this.color,
    required this.face,
    this.languagePair,
    this.selectedOptionIds = const {},
    this.checked = false,
    this.answeredCorrectly,
    this.showFlipHint = true,
    this.onTap,
    this.questionImage,
    this.answerImage,
    this.speechLanguages,
    this.speaker,
    this.options,
    this.onOptionTap,
    this.reversed = false,
    this.textScale = 1.0,
    super.key,
  });

  final Flashcard card;

  /// The card text size from Settings (80–160%, SPEC §9), on top of the
  /// system's text size. It enlarges the card's content: the question,
  /// answer, options and explanation, not the label at the top.
  final double textScale;

  /// Test cards: the options in the order to show them. The session
  /// shuffles them every time it shows the card (R 7.2); null keeps the
  /// card's own order, as in the editor preview.
  final List<CardOption>? options;

  /// Test cards: called with an option's ID when it is tapped, until the
  /// solution is shown. Null makes the options read-only.
  final ValueChanged<String>? onOptionTap;

  /// A simple card studied in reverse (R 7.3): the front shows the answer
  /// and the back shows the question, the one to guess, under it.
  final bool reversed;

  /// The languages of a language deck, to read the card aloud (US-13); null
  /// in a general deck, which has no speaker buttons.
  final SpeechLanguages? speechLanguages;

  /// Builds the speaker button for a text to read (`SpeakerButton` in the
  /// app). Null shows no speakers, e.g. in tests of the card alone.
  final Widget Function(Speech speech)? speaker;

  /// The card's images, already found on disk by the caller. The question
  /// image goes above the question; the answer image above the answer, or
  /// with the explanation on a test card (SPEC §4.2).
  final ImageProvider? questionImage;
  final ImageProvider? answerImage;

  /// "Proyecto · Baraja" at the top.
  final String label;

  /// Palette key of the top band (the deck's colour).
  final String color;
  final CardFace face;

  /// "Inglés → Español" for a language project; it replaces the type label.
  /// Null in a general project, which then shows no example or notes.
  final String? languagePair;

  /// Test cards: the options the user ticked.
  final Set<String> selectedOptionIds;

  /// Test cards: the answer was checked, so the correct options are marked.
  /// The back of a test card always shows them (the solution).
  final bool checked;

  /// Test cards, once checked: shows "¡Correcto!" or "Incorrecto" and
  /// colours the border. Null shows neither.
  final bool? answeredCorrectly;

  /// "Toca para girar" / "Toca para volver" at the bottom.
  final bool showFlipHint;
  final VoidCallback? onTap;

  /// The speaker for [part] of the card on [face], or null when there is
  /// nothing to read.
  Widget? _speakerFor(CardFace face, SpeechPart part) {
    final languages = speechLanguages;
    final build = speaker;
    if (languages == null || build == null) return null;
    final speech = speechFor(card, part, languages);
    if (speech == null) return null;
    return KeyedSubtree(
      key: Key('studyCard.${face.name}.speak.${part.name}'),
      child: build(speech),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget side(CardFace face) => _CardFrame(
      key: Key('studyCard.${face.name}'),
      textScale: textScale,
      color: color,
      borderColor: _borderColor(context, face),
      header: _Header(label: label, badge: _badge(context, face)),
      hint: showFlipHint ? _hint(context, face) : null,
      child: card.type == CardType.test
          ? _TestContent(
              card: card,
              options: options ?? card.options,
              onOptionTap: checked || face == CardFace.back
                  ? null
                  : onOptionTap,
              selectedOptionIds: selectedOptionIds,
              showSolution: checked || face == CardFace.back,
              answeredCorrectly: face == CardFace.front
                  ? answeredCorrectly
                  : null,
              questionImage: questionImage,
              answerImage: answerImage,
              questionSpeaker: _speakerFor(face, SpeechPart.question),
            )
          : face == CardFace.front
          ? _SimpleFront(
              text: reversed ? card.answer ?? '' : card.question,
              image: reversed ? answerImage : questionImage,
              speaker: _speakerFor(
                face,
                reversed ? SpeechPart.answer : SpeechPart.question,
              ),
            )
          : _SimpleBack(
              card: card,
              // In reverse the answer was shown, and the question is the
              // solution.
              prompt: reversed ? card.answer ?? '' : card.question,
              solution: reversed ? card.question : card.answer ?? '',
              isLanguage: languagePair != null,
              image: reversed ? questionImage : answerImage,
              promptSpeaker: _speakerFor(
                face,
                reversed ? SpeechPart.answer : SpeechPart.question,
              ),
              solutionSpeaker: _speakerFor(
                face,
                reversed ? SpeechPart.question : SpeechPart.answer,
              ),
              exampleSpeaker: _speakerFor(face, SpeechPart.example),
            ),
    );

    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        key: const Key('studyCard'),
        onTap: onTap,
        child: _FlipCardView(
          face: face,
          front: side(CardFace.front),
          back: side(CardFace.back),
        ),
      ),
    );
  }

  String _badge(BuildContext context, CardFace face) {
    final l10n = AppLocalizations.of(context);
    return languagePair ??
        switch ((card.type, face)) {
          (CardType.test, _) => l10n.cardTypeTest,
          (CardType.simple, CardFace.front) => l10n.cardTypeSimple,
          (CardType.simple, CardFace.back) => l10n.cardBackLabel,
        };
  }

  String _hint(BuildContext context, CardFace face) {
    final l10n = AppLocalizations.of(context);
    return face == CardFace.front ? l10n.tapToFlip : l10n.tapToFlipBack;
  }

  /// A checked test card is framed in green or red (variants 4 and 5).
  Color? _borderColor(BuildContext context, CardFace face) {
    if (face != CardFace.front || !checked) return null;
    final colors = AppColors.of(context);
    return switch (answeredCorrectly) {
      true => colors.success,
      false => colors.error,
      null => null,
    };
  }
}

/// Turns from [front] to [back] around the vertical axis (brief §8). With
/// the system's "reduce motion" on, one face fades into the other instead.
class _FlipCardView extends StatefulWidget {
  const new({required this.face, required this.front, required this.back});

  final CardFace face;
  final Widget front;
  final Widget back;

  @override
  State<_FlipCardView> createState() => _FlipCardViewState();
}

class _FlipCardViewState extends State<_FlipCardView>
    with SingleTickerProviderStateMixin {
  /// How far the card has turned: 0 is the front up, 1 the back. A card
  /// shown for the first time starts on its face, without turning.
  ///
  /// `preserve` keeps the duration with "reduce motion" on, which Flutter
  /// would otherwise cut 20 times, so the fade can be seen.
  late final AnimationController _turn = AnimationController(
    vsync: this,
    value: _target,
    animationBehavior: AnimationBehavior.preserve,
  );

  double get _target => widget.face == CardFace.back ? 1 : 0;

  @override
  void didUpdateWidget(_FlipCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.face != oldWidget.face) {
      _turn.animateTo(
        _target,
        duration: AppMotion.reduced(context) ? AppMotion.fade : AppMotion.flip,
      );
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) =>
          reduced ? _fade(_turn.value) : _flip(_turn.value),
    );
  }

  /// Both faces on top of each other, the back showing through as [t]
  /// grows. A face that cannot be seen is not built.
  Widget _fade(double t) => Stack(
    fit: StackFit.expand,
    children: [
      // Keys keep each face's state when the other one comes or goes.
      if (t < 1)
        Opacity(
          key: const ValueKey(CardFace.front),
          opacity: 1 - t,
          child: widget.front,
        ),
      if (t > 0)
        Opacity(
          key: const ValueKey(CardFace.back),
          opacity: t,
          child: widget.back,
        ),
    ],
  );

  /// The card turned by [t] × 180° around its vertical axis.
  Widget _flip(double t) {
    final angle = AppMotion.flipCurve.transform(t) * math.pi;
    final showBack = angle > math.pi / 2;
    return Transform(
      alignment: Alignment.center,
      // The perspective entry makes the near edge look bigger, so the turn
      // looks 3D instead of a squash.
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      child: showBack
          // The back is drawn mirrored, so it reads the right way round once
          // the card has turned.
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: widget.back,
            )
          : widget.front,
    );
  }
}

/// The box of one side: band, header, content and hint.
class _CardFrame extends StatelessWidget {
  const new({
    required this.color,
    required this.header,
    required this.child,
    required this.textScale,
    this.borderColor,
    this.hint,
    super.key,
  });

  final double textScale;
  final String color;
  final Widget header;
  final Widget child;
  final Color? borderColor;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final brightness = Theme.of(context).brightness;
    final hint = this.hint;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.studyCard),
        border: Border.all(
          color: borderColor ?? colors.border,
          width: borderColor == null ? 1 : 2,
        ),
        // A very soft shadow in light mode; dark mode relies on the
        // lighter surface (brief §3.3).
        boxShadow: brightness == Brightness.light
            ? [
                BoxShadow(
                  color: colors.text.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.studyCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 6,
              color: ProjectColor.fromKey(color).resolve(brightness),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      // `MediaQuery` tells the widgets below how big to draw
                      // text; here, the system's size times the card's.
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: _CardTextScaler(
                            MediaQuery.textScalerOf(context),
                            textScale,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _Hint(hint),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The system's text size ([system]) with the card text size ([factor]) on
/// top. It keeps the system's own rule, which on some phones enlarges big
/// text less than small text.
class _CardTextScaler extends TextScaler {
  const new(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  // Flutter still asks for this old single number in a few places.
  @override
  double get textScaleFactor => scale(14) / 14;

  @override
  bool operator ==(Object other) =>
      other is _CardTextScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}

class _Header extends StatelessWidget {
  const new({required this.label, required this.badge});

  final String label;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelMedium?.copyWith(color: colors.textMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // The badge keeps its text and the label gives way, as in the
        // design; a very long badge is cut with "…".
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Text(
              badge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(color: colors.textMuted),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.of(context).textMuted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.refresh_rounded, size: 16, color: muted),
        const SizedBox(width: AppSpacing.xs),
        // Wraps instead of overflowing with large system text.
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Content that is centred when short and scrolls inside the card when it
/// is long (variant 11).
class _Scrolling extends StatelessWidget {
  const new({required this.children, this.centered = true});

  final List<Widget> children;
  final bool centered;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Column(
          mainAxisAlignment: centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

/// The large text of the front and the answer: the shorter, the larger, as
/// in the design (`movil-claro/estudio.png`, T6.6). A short text is on one
/// line and shrinks if it does not fit the card's width (e.g. one long
/// word); longer texts wrap.
class _BigText extends StatelessWidget {
  const new(this.text, {this.color, this.smaller = false});

  final String text;

  /// The theme's text colour when null.
  final Color? color;

  /// One size smaller: the question above the answer on a phone, so the
  /// answer still fits.
  final bool smaller;

  /// Up to this many characters a text counts as short or medium.
  static const _short = 20;
  static const _medium = 60;

  /// Sizes for short, medium and long texts, and one more for [smaller].
  static const _sizes = [40.0, 30.0, 26.0, 22.0];

  @override
  Widget build(BuildContext context) {
    final length = withoutFormatMarks(text).length;
    final step = length <= _short
        ? 0
        : length <= _medium
        ? 1
        : 2;
    final formatted = FormattedText(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontSize: _sizes[smaller ? step + 1 : step],
        fontWeight: FontWeight.w800,
        color: color,
      ),
    );
    if (length > _short) return formatted;
    // `FittedBox` lays the text out on one line and scales it down only
    // when it is wider than the card.
    return FittedBox(fit: BoxFit.scaleDown, child: formatted);
  }
}

/// A card image (variant 8): up to 160 px high, whole and centred on a
/// `surface-variant` box. A missing file shows an icon instead.
class _CardImage extends StatelessWidget {
  const new(this.image, {required this.semanticLabel});

  final ImageProvider image;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Container(
          height: 160,
          color: colors.surfaceVariant,
          child: Image(
            image: image,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.broken_image_outlined, color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// The front of a simple card: its question, or its answer in reverse.
class _SimpleFront extends StatelessWidget {
  const new({required this.text, this.image, this.speaker});

  final String text;
  final ImageProvider? image;

  /// Under the text in a language deck (variant 9).
  final Widget? speaker;

  @override
  Widget build(BuildContext context) => _Scrolling(
    children: [
      if (image case final image?)
        _CardImage(
          image,
          semanticLabel: AppLocalizations.of(context).questionImageLabel,
        ),
      _BigText(text),
      if (speaker case final speaker?) ...[
        const SizedBox(height: AppSpacing.md),
        Center(child: speaker),
      ],
    ],
  );
}

/// [text] with [speaker] at its right, as the language back of the design
/// (variant 7); just [text] without a speaker.
Widget _withSpeaker(Widget text, Widget? speaker) => speaker == null
    ? text
    : Row(
        children: [
          Expanded(child: text),
          const SizedBox(width: AppSpacing.sm),
          speaker,
        ],
      );

/// Characters from which an answer is shown as a paragraph.
const _longAnswer = 120;

/// The [solution] under a large, muted copy of the [prompt] at the top
/// (small above a long answer): the answer under the question, or the other
/// way round in reverse. In a language project, also
/// the example sentence and the notes (variants 2 and 7).
class _SimpleBack extends StatelessWidget {
  const new({
    required this.card,
    required this.prompt,
    required this.solution,
    required this.isLanguage,
    this.image,
    this.promptSpeaker,
    this.solutionSpeaker,
    this.exampleSpeaker,
  });

  final Flashcard card;
  final String prompt;
  final String solution;
  final bool isLanguage;
  final ImageProvider? image;

  /// In a language deck: next to the prompt and the example, as in the
  /// design, and under the solution, which US-13 also reads.
  final Widget? promptSpeaker;
  final Widget? solutionSpeaker;
  final Widget? exampleSpeaker;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final example = isLanguage ? card.example : null;
    final notes = isLanguage ? card.notes : null;
    final answer = solution;
    // A long answer is read like a paragraph: smaller and aligned to the
    // left, with the question above it (variant 11).
    final isLong = answer.length > _longAnswer;
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        title.toUpperCase(),
        style: text.labelSmall?.copyWith(
          color: colors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );

    return _Scrolling(
      // The large question starts at the top, with the answer under it.
      centered: isLong,
      children: [
        if (isLong)
          _withSpeaker(
            FormattedText(
              prompt,
              textAlign: TextAlign.start,
              style: text.titleSmall?.copyWith(color: colors.textMuted),
            ),
            promptSpeaker,
          )
        else ...[
          _BigText(
            prompt,
            color: colors.textMuted,
            smaller:
                FormFactor.fromWidth(MediaQuery.sizeOf(context).width) ==
                FormFactor.mobile,
          ),
          if (promptSpeaker case final speaker?) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(child: speaker),
          ],
        ],
        SizedBox(height: isLong ? AppSpacing.lg : AppSpacing.xl),
        if (image case final image?)
          _CardImage(image, semanticLabel: l10n.answerImageLabel),
        if (isLong)
          FormattedText(
            answer,
            style: text.titleMedium?.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          )
        else
          _BigText(answer),
        if (solutionSpeaker case final speaker?) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(child: speaker),
        ],
        if (example != null || notes != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Divider(color: colors.border),
        ],
        if (example != null) ...[
          heading(l10n.exampleHeading),
          _withSpeaker(
            FormattedText(
              example,
              style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
            ),
            exampleSpeaker,
          ),
        ],
        if (notes != null) ...[
          heading(l10n.notesHeading),
          Text(notes, style: text.bodyLarge),
        ],
      ],
    );
  }
}

/// A test card: the question, the options and, once the solution is shown,
/// the result and the explanation (variants 3 to 6).
class _TestContent extends StatelessWidget {
  const new({
    required this.card,
    required this.options,
    required this.onOptionTap,
    required this.selectedOptionIds,
    required this.showSolution,
    required this.answeredCorrectly,
    this.questionImage,
    this.answerImage,
    this.questionSpeaker,
  });

  final Flashcard card;
  final List<CardOption> options;
  final ValueChanged<String>? onOptionTap;

  /// Next to the question in a language deck.
  final Widget? questionSpeaker;
  final Set<String> selectedOptionIds;
  final bool showSolution;
  final bool? answeredCorrectly;
  final ImageProvider? questionImage;

  /// Shown with the explanation, once the solution is shown.
  final ImageProvider? answerImage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final result = showSolution ? answeredCorrectly : null;
    final explanation = card.explanation;
    final questionImage = this.questionImage;
    final answerImage = showSolution ? this.answerImage : null;

    return _Scrolling(
      centered: false,
      children: [
        if (result != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  result ? Icons.check_rounded : Icons.close_rounded,
                  size: 18,
                  color: result ? colors.success : colors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  result ? l10n.answerCorrect : l10n.answerWrong,
                  style: text.labelLarge?.copyWith(
                    color: result ? colors.success : colors.error,
                  ),
                ),
              ],
            ),
          ),
        if (questionImage != null)
          _CardImage(questionImage, semanticLabel: l10n.questionImageLabel),
        _withSpeaker(
          FormattedText(
            card.question,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          questionSpeaker,
        ),
        if (card.allowMultiple) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 14, color: colors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  // Wraps instead of overflowing with large system text.
                  Flexible(
                    child: Text(
                      l10n.multipleCorrectChip,
                      style: text.labelSmall?.copyWith(
                        color: colors.primaryStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final (i, option) in options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _OptionTile(
              key: Key('studyCard.option.$i'),
              option: option,
              allowMultiple: card.allowMultiple,
              selected: selectedOptionIds.contains(option.id),
              showSolution: showSolution,
              anySelected: selectedOptionIds.isNotEmpty,
              onTap: onOptionTap == null
                  ? null
                  : () => onOptionTap?.call(option.id),
            ),
          ),
        if (answerImage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          _CardImage(answerImage, semanticLabel: l10n.answerImageLabel),
        ],
        if (showSolution && explanation != null && explanation.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${l10n.explanationLead} ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: explanation),
                ],
              ),
              style: text.bodySmall?.copyWith(color: colors.text),
            ),
          ),
      ],
    );
  }
}

/// One option: before checking it shows whether it is ticked; once the
/// solution is shown, correct options are green with ✓ and wrongly ticked
/// ones red with ✗ (always an icon as well as the colour).
class _OptionTile extends StatelessWidget {
  const new({
    required this.option,
    required this.allowMultiple,
    required this.selected,
    required this.showSolution,
    required this.anySelected,
    this.onTap,
    super.key,
  });

  final CardOption option;
  final bool allowMultiple;
  final bool selected;
  final bool showSolution;

  /// Ticks or unticks the option in a session; null when read-only.
  final VoidCallback? onTap;

  /// Whether the user answered at all: only then "Correcta" is added to a
  /// correct option they missed.
  final bool anySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    final unticked = allowMultiple
        ? Icons.check_box_outline_blank_rounded
        : Icons.radio_button_unchecked_rounded;
    final (IconData icon, Color? tint, String? note) = switch ((
      showSolution,
      option.isCorrect,
      selected,
    )) {
      (false, _, true) => (
        allowMultiple
            ? Icons.check_box_rounded
            : Icons.radio_button_checked_rounded,
        colors.primaryStrong,
        null,
      ),
      (true, true, _) => (
        allowMultiple ? Icons.check_box_rounded : Icons.check_circle_rounded,
        colors.success,
        selected
            ? l10n.yourAnswer
            : anySelected
            ? l10n.correctOptionLabel
            : null,
      ),
      (true, false, true) => (
        Icons.cancel_rounded,
        colors.error,
        l10n.yourAnswer,
      ),
      _ => (unticked, null, null),
    };

    final tile = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tint == null
            ? colors.surface
            : tint == colors.primaryStrong
            ? colors.primarySoft
            : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(
          color: tint ?? colors.border,
          width: tint == null ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: tint ?? colors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: FormattedText(option.text, style: text.labelLarge)),
          if (note != null)
            Text(
              note,
              style: text.labelSmall?.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return tile;
    // A radio or checkbox for screen readers, with the tile as its target.
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: !allowMultiple,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: tile,
      ),
    );
  }
}
