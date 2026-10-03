import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/habit_controller.dart';
import '../engine/streak_engine.dart';
import '../widgets/exchange_sheet.dart';
import '../widgets/gold_widgets.dart';
import '../widgets/habit_tile.dart';
import '../widgets/repair_card.dart';
import '../widgets/streak_header.dart';
import 'habit_editor_sheet.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenRewards});

  final VoidCallback onOpenRewards;

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final s = c.stats;
    final t = Theme.of(context).textTheme;

    // Weekday habits scheduled today plus every weekly habit (any day works).
    // Open habits keep the order they were added (required ones first); done
    // habits sink to the bottom in the order they were ticked.
    final candidates =
        s.habitStats.where((h) => h.habit.isWeekly || h.requiredToday);
    final open = candidates.where((h) => !h.doneToday).toList();
    final done = candidates.where((h) => h.doneToday).toList()
      ..sort((a, b) {
        final at = a.doneTodayAt, bt = b.doneTodayAt;
        if (at == null && bt == null) return compareHabitOrder(a.habit, b.habit);
        if (at == null) return -1;
        if (bt == null) return 1;
        return at.compareTo(bt);
      });
    final listed = [
      ...open.where((h) => h.requiredToday),
      ...open.where((h) => !h.requiredToday),
      ...done,
    ];
    final resting = s.habitStats
        .where((h) => !h.habit.isWeekly && !h.requiredToday)
        .toList();

    // Group day repairs by date; week repairs stand alone.
    final dayGroups = <String, List<RepairOption>>{};
    final weekRepairs = <RepairOption>[];
    for (final o in s.repairOptions) {
      if (o.isWeek) {
        weekRepairs.add(o);
      } else {
        dayGroups.putIfAbsent(o.key, () => []).add(o);
      }
    }

    final grace = s.graceDayEval;
    final graceMissed = grace?.missed ?? const [];

    Future<void> doRepair(RepairOption o) async {
      final ok = await c.repair(o);
      if (!context.mounted) return;
      showSnack(context, ok ? 'Repaired. Streak kept.' : 'Not enough tokens yet.');
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today'),
            Text(
              DateFormat('EEEE, d MMMM').format(c.logicalToday),
              style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TokenPill(balance: s.sharedBalance, onTap: onOpenRewards),
          ),
        ],
      ),
      body: !c.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: [
                if (c.error != null) _ErrorBanner(error: c.error!),
                StreakHeader(stats: s),
                if (graceMissed.isNotEmpty && grace != null) ...[
                  const SectionTitle('Yesterday, still open'),
                  _GraceCard(
                    missed: graceMissed,
                    endsAt: c.graceEndsAt,
                    onTick: (habitId) async {
                      HapticFeedback.mediumImpact();
                      await c.markDone(habitId, grace.key);
                    },
                  ),
                ],
                if (s.repairOptions.isNotEmpty) ...[
                  const SectionTitle('Streaks at risk'),
                  for (final e in dayGroups.entries) ...[
                    DayRepairCard(
                      dateKey: e.key,
                      options: e.value,
                      sharedBalance: s.sharedBalance,
                      onRepair: doRepair,
                      onRepairAll: () async {
                        final n = await c.repairWholeDay(e.key);
                        if (!context.mounted) return;
                        showSnack(context, n == 0
                            ? 'Not enough tokens yet.'
                            : 'Repaired $n habit${n == 1 ? '' : 's'}.');
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  for (final o in weekRepairs) ...[
                    WeekRepairCard(
                      option: o,
                      sharedBalance: s.sharedBalance,
                      onRepair: doRepair,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                SectionTitle(
                  'Your habits',
                  trailing: TextButton.icon(
                    onPressed: () => HabitEditorSheet.show(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ),
                if (c.activeHabits.isEmpty)
                  EmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Start your first habit',
                    message:
                        'Pick something small you can do every day. Tokens '
                        'and streaks begin with the first check.',
                    action: SizedBox(
                      width: 220,
                      child: GoldButton(
                        label: 'Add a habit',
                        icon: Icons.add_rounded,
                        onPressed: () => HabitEditorSheet.show(context),
                      ),
                    ),
                  )
                else ...[
                  if (listed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'A rest day. Nothing is scheduled.',
                        textAlign: TextAlign.center,
                        style:
                            t.bodyMedium?.copyWith(color: AppColors.inkMuted),
                      ),
                    ),
                  for (final hs in listed) ...[
                    HabitTile(
                      stats: hs,
                      onToggle: () async {
                        if (hs.doneToday) {
                          HapticFeedback.selectionClick();
                        } else {
                          HapticFeedback.mediumImpact();
                        }
                        final ok = await c.toggleToday(hs.habit.id);
                        if (!ok && context.mounted) {
                          showSnack(
                            context,
                            'Those tokens were already exchanged or spent, '
                            'so this check-in cannot be undone.',
                          );
                        }
                      },
                      onLongPress: () =>
                          HabitEditorSheet.show(context, habit: hs.habit),
                      onWalletTap: () =>
                          ExchangeSheet.show(context, hs.habit.id),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (resting.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        'Resting today: '
                        '${resting.map((h) => '${h.habit.emoji} ${h.habit.name}').join(', ')}',
                        style: t.bodySmall?.copyWith(color: AppColors.inkFaint),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Yesterday's misses that can still be ticked for free during the grace
/// period.
class _GraceCard extends StatelessWidget {
  const _GraceCard({
    required this.missed,
    required this.endsAt,
    required this.onTick,
  });

  final List<dynamic> missed;
  final DateTime? endsAt;
  final Future<void> Function(String habitId) onTick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            endsAt == null
                ? 'Forgot to tick something? Mark it now, no tokens needed.'
                : 'Forgot to tick something? Free until ${DateFormat.jm().format(endsAt!)}.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 6),
          for (final h in missed)
            Row(
              children: [
                Text(h.emoji as String, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(h.name as String,
                      style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: () => onTick(h.id as String),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Did it'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE4E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Could not sync with Firestore: $error\n'
        'Check that the database exists and firestore.rules are published.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: const Color(0xFF5C1510)),
      ),
    );
  }
}
