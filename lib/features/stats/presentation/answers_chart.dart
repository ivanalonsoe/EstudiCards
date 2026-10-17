// The 30-day chart of correct and wrong answers (P12, P13), drawn with
// `fl_chart`: one stacked bar per day, correct at the bottom and wrong on
// top, with the brief's chart colours (DESIGN_BRIEF.md §3.1).
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/app_colors.dart';
import 'package:estudicards/app/theme/dimensions.dart';
import 'package:estudicards/features/stats/domain/metrics.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The bars, their axes and the legend with the totals. Screen readers get
/// the totals and each day with answers instead of the bars.
class AnswersChart extends StatelessWidget {
  const new({
    required this.series,
    required this.title,
    this.height = 220,
    super.key,
  });

  final DailySeries series;

  /// The heading of the card, which screen readers say before the data.
  final String title;

  /// The height of the bars and axes, without the legend.
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final totals = series.totals;
    return Column(
      key: const Key('answersChart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: const Key('answersChart.data'),
          container: true,
          label: _semanticsLabel(context),
          // The bars say nothing; the label above carries their data.
          excludeSemantics: true,
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  _Bars(series: series, size: constraints.biggest),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // The legend repeats the totals with ✓ and ✗, so colour is not the
        // only cue (DESIGN_BRIEF.md §3.1).
        ExcludeSemantics(
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _LegendItem(
                key: const Key('answersChart.legend.correct'),
                color: colors.chartCorrect,
                icon: Icons.check_rounded,
                text: l10n.chartLegendCorrect(totals.correct),
              ),
              _LegendItem(
                key: const Key('answersChart.legend.wrong'),
                color: colors.chartWrong,
                icon: Icons.close_rounded,
                text: l10n.chartLegendWrong(totals.wrong),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Últimos 30 días: 421 aciertos y 114 fallos. 1 sept: 11 aciertos,
  /// 4 fallos. …", leaving out the days without answers.
  String _semanticsLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totals = series.totals;
    return [
      l10n.chartSummary(
        title,
        l10n.correctAnswers(totals.correct),
        l10n.wrongAnswers(totals.wrong),
      ),
      for (final day in series.days)
        if (day.answers.total > 0) '${_dayText(context, day)}.',
    ].join(' ');
  }
}

/// "6 oct: 2 aciertos, 1 fallo", for screen readers and the tooltip.
String _dayText(BuildContext context, DayAnswers day) {
  final l10n = AppLocalizations.of(context);
  return l10n.chartDay(
    shortDate(context, day.day),
    l10n.correctAnswers(day.answers.correct),
    l10n.wrongAnswers(day.answers.wrong),
  );
}

/// "6 oct": day and short month in the app's language. Local days are
/// midnight UTC of the local date, so they are formatted as they are.
String shortDate(BuildContext context, DateTime day) =>
    DateFormat.MMMd(Localizations.localeOf(context).toString()).format(day);

/// The gap between the wrong and the correct part of a bar, in pixels
/// (DESIGN_BRIEF.md §3.1).
const double _segmentGap = 2;

/// Room under the bars for the dates, and left of them for the numbers.
const double _bottomAxis = 28;
const double _leftAxis = 32;

class _Bars extends StatelessWidget {
  const new({required this.series, required this.size});

  final DailySeries series;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final axisStyle = text.labelSmall?.copyWith(color: colors.textMuted);
    final days = series.days;

    final interval = chartInterval(series.busiestDay);
    final maxY = interval * 2;
    // `fl_chart` works in data units, so the 2 px gap becomes the number of
    // cards that 2 px stand for at this height.
    final plotHeight = size.height - _bottomAxis;
    final gap = plotHeight > 0 ? _segmentGap * maxY / plotHeight : 0.0;
    final slot = (size.width - _leftAxis) / days.length;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (final (i, day) in days.indexed)
            BarChartGroupData(
              x: i,
              barRods: [
                _rod(day.answers, gap: gap, width: slot * 0.7, colors: colors),
              ],
            ),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.border,
            strokeWidth: 1,
            dashArray: value == 0 ? null : [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: _leftAxis,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(meta.formattedValue, style: axisStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _bottomAxis,
              getTitlesWidget: (value, meta) {
                // The first day, the middle one and today, as in the design.
                final index = value.toInt();
                final label = index == days.length - 1
                    ? l10n.reviewedToday
                    : index == 0 || index == days.length ~/ 2
                    ? shortDate(context, days[index].day)
                    : null;
                if (label == null) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  // Keeps the first and last labels inside the chart.
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(label, style: axisStyle),
                );
              },
            ),
          ),
        ),
        // The value of a day on tap (mobile) or hover (desktop).
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => colors.text,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x];
              if (day.answers.total == 0) return null;
              return BarTooltipItem(
                _dayText(context, day),
                text.labelMedium!.copyWith(color: colors.background),
              );
            },
          ),
        ),
      ),
    );
  }

  /// One day's bar: correct from 0, then the gap, then wrong. The rod
  /// itself is transparent; its two stacked parts are what shows.
  BarChartRodData _rod(
    AnswerCounts answers, {
    required double gap,
    required double width,
    required AppColors colors,
  }) {
    final correct = answers.correct.toDouble();
    final wrongFrom = answers.correct > 0 ? correct + gap : 0.0;
    final top = answers.wrong > 0 ? wrongFrom + answers.wrong : correct;
    return BarChartRodData(
      toY: top,
      width: width,
      color: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      rodStackItems: [
        if (answers.correct > 0)
          BarChartRodStackItem(0, correct, colors.chartCorrect),
        if (answers.wrong > 0)
          BarChartRodStackItem(wrongFrom, top, colors.chartWrong),
      ],
    );
  }
}

/// The step between the grid lines: the smallest of 1, 2, 5, 10, 20, 50…
/// that reaches [busiestDay] in two steps, so the chart shows 0, the step
/// and twice the step (0, 20, 40 in the design).
double chartInterval(int busiestDay) {
  for (var magnitude = 1; ; magnitude *= 10) {
    for (final step in const [1, 2, 5]) {
      final interval = step * magnitude;
      if (interval * 2 >= busiestDay) return interval.toDouble();
    }
  }
}

class _LegendItem extends StatelessWidget {
  const new({
    required this.color,
    required this.icon,
    required this.text,
    super.key,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Icon(icon, size: 16, color: AppColors.of(context).text),
        const SizedBox(width: AppSpacing.xs),
        Text(text, style: style),
      ],
    );
  }
}
