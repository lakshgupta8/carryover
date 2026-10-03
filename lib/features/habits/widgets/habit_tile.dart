import 'package:flutter/material.dart';

import '../../../core/dates.dart';
import '../../../core/theme/app_theme.dart';
import '../engine/streak_engine.dart';
import 'gold_widgets.dart';

/// One habit row for the Today screen. Tap anywhere to toggle.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.stats,
    required this.onToggle,
    this.onLongPress,
    this.onWalletTap,
  });

  final HabitStats stats;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onWalletTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final habit = stats.habit;
    final done = stats.doneToday;
    final reminder = habit.reminderMinutes;
    final due = stats.requiredToday && !done && habit.isWeekly;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: done ? AppColors.champagne : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done
              ? AppColors.goldPale
              : due
                  ? AppColors.gold.withValues(alpha: 0.6)
                  : AppColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _EmojiBox(emoji: habit.emoji, done: done),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              habit.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: done ? AppColors.inkMuted : AppColors.ink,
                              ),
                            ),
                          ),
                          if (due) ...[
                            const SizedBox(width: 8),
                            const _DueBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 10,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (reminder != null)
                            _Meta(
                              icon: Icons.schedule_rounded,
                              iconColor: AppColors.inkFaint,
                              text: formatMinutes(reminder),
                            ),
                          _Meta(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: AppColors.goldDeep,
                            text: '${stats.current}',
                          ),
                          GestureDetector(
                            onTap: onWalletTap,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CoinIcon(size: 13, hollow: true),
                                const SizedBox(width: 4),
                                Text(
                                  '${stats.internalBalance}',
                                  style: t.bodySmall?.copyWith(
                                    color: AppColors.goldDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (habit.isWeekly)
                            Text(
                              _weekLabel(stats),
                              style: t.bodySmall
                                  ?.copyWith(color: AppColors.inkMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CheckCircle(done: done),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _weekLabel(HabitStats s) {
    final progress = '${s.weekDone + s.weekCredits}/${s.weekTarget} this week';
    if (s.weekTargetMet) return '$progress ✓';
    final skips = s.skipsLeftThisWeek;
    return '$progress · $skips skip${skips == 1 ? '' : 's'} left';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 3),
        Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _DueBadge extends StatelessWidget {
  const _DueBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'DUE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _EmojiBox extends StatelessWidget {
  const _EmojiBox({required this.emoji, required this.done});

  final String emoji;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: done ? AppColors.goldPale : AppColors.champagne,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? AppColors.goldGradient : null,
        border: done ? null : Border.all(color: AppColors.line, width: 2),
        boxShadow: done
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 20, color: AppColors.white)
          : null,
    );
  }
}
