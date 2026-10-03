import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../engine/streak_engine.dart';

/// The hero card on the Today screen: daily streak, weekly/monthly chips and
/// today's progress.
class StreakHeader extends StatelessWidget {
  const StreakHeader({super.key, required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final progress = stats.todayRequired == 0
        ? 0.0
        : stats.todayDone / stats.todayRequired;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.white, AppColors.champagne],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY STREAK',
                      style: t.labelMedium?.copyWith(
                        color: AppColors.inkMuted,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${stats.dailyStreak}',
                          style: t.displayMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.goldDark,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stats.dailyStreak == 1 ? 'day' : 'days',
                          style: t.titleMedium
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Best ${stats.bestDailyStreak} · ${stats.perfectDays} perfect day${stats.perfectDays == 1 ? '' : 's'}',
                      style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const _Flame(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _PeriodChip(
                label: 'Weekly',
                value: stats.weeklyStreak,
                best: stats.bestWeeklyStreak,
              ),
              const SizedBox(width: 10),
              _PeriodChip(
                label: 'Monthly',
                value: stats.monthlyStreak,
                best: stats.bestMonthlyStreak,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  stats.todayRequired == 0
                      ? (stats.todayPerfect
                          ? 'Perfect day. Beautifully done.'
                          : 'Nothing due today')
                      : stats.todayPerfect
                          ? 'Perfect day. Beautifully done.'
                          : 'Required today',
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${stats.todayDone} of ${stats.todayRequired}',
                style: t.titleSmall?.copyWith(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.sand,
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Flame extends StatelessWidget {
  const _Flame();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_fire_department_rounded,
        color: AppColors.white,
        size: 34,
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.value,
    required this.best,
  });

  final String label;
  final int value;
  final int best;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.labelMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                  Text(
                    '$value',
                    style: t.titleLarge?.copyWith(
                      color: AppColors.goldDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'best $best',
              style: t.labelSmall?.copyWith(color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
