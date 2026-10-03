import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../data/habit_controller.dart';
import '../engine/streak_engine.dart';
import '../models/habit.dart';
import '../widgets/exchange_sheet.dart';
import '../widgets/gold_widgets.dart';
import 'habit_editor_sheet.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final s = c.stats;
    final archived = c.archivedHabits;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TokenPill(balance: s.sharedBalance),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => HabitEditorSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New habit'),
      ),
      body: s.habitStats.isEmpty && archived.isEmpty
          ? const EmptyState(
              icon: Icons.checklist_rounded,
              title: 'No habits yet',
              message: 'Tap "New habit" to add one. Keep it small and daily.',
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                elevation: 6,
                shadowColor: AppColors.gold.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                child: child,
              ),
              header: s.habitStats.length > 1
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Text(
                        'Hold the handle to reorder.',
                        style: t.labelSmall?.copyWith(color: AppColors.inkFaint),
                      ),
                    )
                  : null,
              footer: archived.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Archived'),
                        for (final h in archived) ...[
                          _ArchivedTile(habit: h),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
              itemCount: s.habitStats.length,
              onReorder: (oldIndex, newIndex) =>
                  c.reorderHabits(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final hs = s.habitStats[index];
                return Padding(
                  key: ValueKey(hs.habit.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HabitCard(stats: hs, index: index),
                );
              },
            ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.stats, required this.index});

  final HabitStats stats;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = stats.habit;
    final reminder = h.reminderMinutes;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(6, 14, 10, 14),
      onTap: () => HabitEditorSheet.show(context, habit: h),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              child: Icon(Icons.drag_indicator_rounded, color: AppColors.inkFaint),
            ),
          ),
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.champagne,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(h.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${h.scheduleLabel} · '
                  '${reminder == null ? 'No reminder' : formatMinutes(reminder)}',
                  style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    _Stat(icon: Icons.local_fire_department_rounded, value: '${stats.current}', label: 'streak'),
                    _Stat(icon: Icons.emoji_events_outlined, value: '${stats.best}', label: 'best'),
                    _Stat(icon: Icons.check_rounded, value: '${stats.totalDone}', label: 'done'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              WalletChip(
                balance: stats.internalBalance,
                onTap: () => ExchangeSheet.show(context, h.id),
              ),
              const SizedBox(height: 4),
              Text('wallet', style: t.labelSmall?.copyWith(color: AppColors.inkFaint)),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.goldDeep),
        const SizedBox(width: 3),
        Text(value, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 3),
        Text(label, style: t.labelSmall?.copyWith(color: AppColors.inkFaint)),
      ],
    );
  }
}

class _ArchivedTile extends StatelessWidget {
  const _ArchivedTile({required this.habit});

  final Habit habit;

  Future<void> _confirmDelete(BuildContext context) async {
    final c = ControllerScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete forever?'),
        content: Text(
          'This removes "${habit.name}" and its streak history, including its '
          'wallet. Shared tokens you already earned stay with you.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await c.deleteHabit(habit.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.champagne.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(habit.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              habit.name,
              style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => c.restoreHabit(habit.id),
            child: const Text('Restore'),
          ),
          IconButton(
            tooltip: 'Delete forever',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
