import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../engine/streak_engine.dart';
import '../models/habit.dart';
import 'gold_widgets.dart';

/// What happened on one day, opened from the heatmap.
class DayDetailsSheet extends StatelessWidget {
  const DayDetailsSheet({
    super.key,
    required this.date,
    required this.eval,
    required this.resolve,
  });

  final DateTime date;
  final DayEval? eval;
  final Habit? Function(String id) resolve;

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required DayEval? eval,
    required Habit? Function(String id) resolve,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => DayDetailsSheet(date: date, eval: eval, resolve: resolve),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final e = eval;

    String headline;
    if (e == null) {
      headline = 'Before your first habit';
    } else {
      switch (e.status) {
        case DayStatus.neutral:
          headline = e.activity > 0 ? 'Bonus check-ins' : 'Rest day';
        case DayStatus.kept:
          headline = e.perfect ? 'Perfect day' : 'Kept with a repair';
        case DayStatus.pending:
          headline = 'Still open';
        case DayStatus.missed:
          headline = 'Missed';
      }
    }

    // Every habit that existed that day, done ones first.
    final rows = <({Habit habit, String label, IconData icon, Color color})>[];
    if (e != null) {
      for (final entry in e.habitStatus.entries) {
        final h = resolve(entry.key);
        if (h == null || !h.isActiveOn(date)) continue;
        final didIt = e.done.contains(h.id);
        final required = e.required.any((r) => r.id == h.id);
        if (didIt) {
          rows.add((habit: h, label: 'Done', icon: Icons.check_circle_rounded, color: AppColors.goldDeep));
        } else if (entry.value == DayStatus.kept) {
          rows.add((habit: h, label: 'Repaired', icon: Icons.build_circle_outlined, color: AppColors.goldDark));
        } else if (entry.value == DayStatus.missed) {
          rows.add((habit: h, label: 'Missed', icon: Icons.cancel_outlined, color: AppColors.error));
        } else if (entry.value == DayStatus.pending) {
          rows.add((habit: h, label: 'Open', icon: Icons.radio_button_unchecked, color: AppColors.inkFaint));
        } else {
          rows.add((habit: h, label: required ? 'Skipped' : 'Not scheduled', icon: Icons.remove_circle_outline, color: AppColors.inkFaint));
        }
      }
      rows.sort((a, b) => a.label == 'Done' ? -1 : (b.label == 'Done' ? 1 : 0));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEEE, d MMMM yyyy').format(date), style: t.headlineSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(headline, style: t.bodyMedium?.copyWith(color: AppColors.inkMuted)),
              if (e != null && e.perfect) ...[
                const SizedBox(width: 10),
                const TokenAmount(5),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text('No habits existed yet.',
                style: t.bodySmall?.copyWith(color: AppColors.inkFaint))
          else
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(r.habit.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.habit.name,
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Icon(r.icon, size: 18, color: r.color),
                    const SizedBox(width: 6),
                    Text(r.label, style: t.labelMedium?.copyWith(color: r.color)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
