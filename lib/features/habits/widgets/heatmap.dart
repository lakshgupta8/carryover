import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../engine/streak_engine.dart';

/// Twelve weeks of days, Monday at the top, most recent week on the right.
/// Tap a day to see its details.
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.stats,
    this.weeks = 12,
    this.onDayTap,
  });

  final Stats stats;
  final int weeks;
  final void Function(DateTime date, DayEval? eval)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final today = parseDateKey(stats.todayKey);
    final thisMonday = startOfWeek(today);
    final t = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        const labelWidth = 22.0;
        final cell =
            ((constraints.maxWidth - labelWidth - gap * (weeks - 1)) / weeks)
                .clamp(8.0, 28.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var row = 0; row < 7; row++) ...[
              Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      row.isEven ? weekdayLetter[row] : '',
                      style: t.labelSmall?.copyWith(color: AppColors.inkFaint),
                    ),
                  ),
                  for (var col = 0; col < weeks; col++) ...[
                    _Cell(
                      size: cell,
                      date: addDays(thisMonday, -(weeks - 1 - col) * 7 + row),
                      today: today,
                      stats: stats,
                      onTap: onDayTap,
                    ),
                    if (col < weeks - 1) const SizedBox(width: gap),
                  ],
                ],
              ),
              if (row < 6) const SizedBox(height: gap),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: const [
                _Legend(color: AppColors.gold, label: 'Perfect'),
                _Legend(color: AppColors.goldPale, label: 'Partial'),
                _Legend(color: AppColors.goldPale, label: 'Repaired', outlined: true),
                _Legend(color: Color(0xFFEFE4D8), label: 'Missed'),
                _Legend(color: AppColors.champagne, label: 'Rest day'),
              ],
            ),
            if (onDayTap != null) ...[
              const SizedBox(height: 6),
              Text('Tap a day for details.',
                  style: t.labelSmall?.copyWith(color: AppColors.inkFaint)),
            ],
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.size,
    required this.date,
    required this.today,
    required this.stats,
    required this.onTap,
  });

  final double size;
  final DateTime date;
  final DateTime today;
  final Stats stats;
  final void Function(DateTime date, DayEval? eval)? onTap;

  @override
  Widget build(BuildContext context) {
    final future = date.isAfter(today);
    final eval = stats.days[dateKey(date)];
    Color color;
    Border? border;
    if (future) {
      color = Colors.transparent;
      border = Border.all(color: AppColors.line.withValues(alpha: 0.7));
    } else if (eval == null || eval.status == DayStatus.neutral) {
      color = AppColors.champagne;
    } else if (eval.perfect) {
      color = AppColors.gold;
    } else if (eval.status == DayStatus.kept) {
      // Kept thanks to a repair.
      color = AppColors.goldPale;
      border = Border.all(color: AppColors.gold, width: 1.5);
    } else if (eval.status == DayStatus.pending) {
      color = eval.activity > 0 ? AppColors.goldPale : AppColors.sand;
    } else if (eval.activity > 0) {
      color = AppColors.goldPale;
    } else {
      color = const Color(0xFFEFE4D8);
    }
    final isToday = date == today;
    final cell = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: isToday ? Border.all(color: AppColors.goldDark, width: 1.5) : border,
      ),
    );
    if (onTap == null || future) return cell;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap!(date, eval),
      child: cell,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined ? Border.all(color: AppColors.gold, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}
