import 'package:flutter/material.dart';

import '../../../core/rewards.dart';
import '../../../core/theme/app_theme.dart';
import '../data/habit_controller.dart';
import '../engine/streak_engine.dart';
import '../widgets/day_details_sheet.dart';
import '../widgets/exchange_sheet.dart';
import '../widgets/gold_widgets.dart';
import '../widgets/heatmap.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final s = c.stats;
    final claimed = c.profile.claimed.keys.toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _SharedCard(stats: s),
          const SectionTitle('Habit wallets'),
          if (s.habitStats.isEmpty)
            SoftCard(
              child: Text(
                'Each habit keeps its own wallet. Check-ins pay into it; it '
                'repairs that habit only, or converts into shared tokens.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            )
          else
            SoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < s.habitStats.length; i++) ...[
                    _WalletRow(stats: s.habitStats[i]),
                    if (i < s.habitStats.length - 1)
                      const Divider(indent: 56, endIndent: 10),
                  ],
                ],
              ),
            ),
          const SectionTitle('Last 12 weeks'),
          SoftCard(
            child: Heatmap(
              stats: s,
              onDayTap: (date, eval) => DayDetailsSheet.show(
                context,
                date: date,
                eval: eval,
                resolve: c.habitById,
              ),
            ),
          ),
          const SectionTitle('Lifetime'),
          Row(
            children: [
              _LifetimeStat(label: 'Check-ins', value: s.totalCompletions),
              const SizedBox(width: 10),
              _LifetimeStat(label: 'Perfect days', value: s.perfectDays),
              const SizedBox(width: 10),
              _LifetimeStat(label: 'Best streak', value: s.bestDailyStreak),
            ],
          ),
          _MilestoneSection(
            title: 'Daily streak milestones',
            milestones: Milestones.daily,
            stats: s,
            claimed: claimed,
          ),
          _MilestoneSection(
            title: 'Weekly streak milestones',
            milestones: Milestones.weekly,
            stats: s,
            claimed: claimed,
          ),
          _MilestoneSection(
            title: 'Monthly streak milestones',
            milestones: Milestones.monthly,
            stats: s,
            claimed: claimed,
          ),
          _MilestoneSection(
            title: 'Check-in milestones',
            milestones: Milestones.completions,
            stats: s,
            claimed: claimed,
          ),
          for (final hs in s.habitStats)
            _MilestoneSection(
              title: '${hs.habit.emoji} ${hs.habit.name} · pays its wallet',
              milestones: [
                for (final tier in Milestones.habitTiers)
                  Milestones.habitMilestone(hs.habit.id, hs.habit.name, tier),
              ],
              stats: s,
              claimed: claimed,
              habitId: hs.habit.id,
              compactTitles: true,
            ),
        ],
      ),
    );
  }
}

class _SharedCard extends StatelessWidget {
  const _SharedCard({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
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
          Text(
            'SHARED TOKENS',
            style: t.labelMedium?.copyWith(
              color: AppColors.inkMuted,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const CoinIcon(size: 40),
              const SizedBox(width: 12),
              Text(
                '${stats.sharedBalance}',
                style: t.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldDark,
                  height: 1,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TokenAmount(stats.totalHabitTokens, signed: false, hollow: true, size: 16),
                  Text('in habit wallets',
                      style: t.labelSmall?.copyWith(color: AppColors.inkFaint)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Line('Perfect days', '${stats.perfectDays} × ${RewardRules.perPerfectDay}', stats.sharedFromPerfectDays),
          _Line('Milestone bonuses', '', stats.sharedFromMilestones),
          _Line('Exchanged in', '${RewardRules.exchangeRate} : 1', stats.sharedFromExchanges),
          _Line('Spent on repairs', '', -stats.sharedSpent),
          const SizedBox(height: 8),
          Text(
            'Shared tokens repair any habit. A repair costs '
            '${RewardRules.repairCostPerDay} per missed day and is paid from the '
            'habit\'s own wallet first.',
            style: t.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.stats});

  final HabitStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = stats.habit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.champagne,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(h.emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name,
                    style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(
                  'earned ${stats.internalEarned + stats.internalFromMilestones}'
                  ' · spent ${stats.internalSpent}'
                  ' · exchanged ${stats.exchanged}',
                  style: t.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TokenAmount(stats.internalBalance, signed: false, hollow: true, size: 15),
          IconButton(
            tooltip: 'Exchange',
            onPressed: stats.internalBalance >= RewardRules.exchangeRate
                ? () => ExchangeSheet.show(context, h.id)
                : null,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.detail, this.amount);

  final String label;
  final String detail;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.bodyMedium)),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(detail, style: t.bodySmall?.copyWith(color: AppColors.inkFaint)),
            ),
          Text(
            amount >= 0 ? '+$amount' : '$amount',
            style: t.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: amount >= 0 ? AppColors.goldDark : AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifetimeStat extends StatelessWidget {
  const _LifetimeStat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value',
                style: t.headlineSmall?.copyWith(color: AppColors.goldDark)),
            const SizedBox(height: 2),
            Text(label, style: t.labelSmall?.copyWith(color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _MilestoneSection extends StatelessWidget {
  const _MilestoneSection({
    required this.title,
    required this.milestones,
    required this.stats,
    required this.claimed,
    this.habitId,
    this.compactTitles = false,
  });

  final String title;
  final List<Milestone> milestones;
  final Stats stats;
  final Set<String> claimed;
  final String? habitId;
  final bool compactTitles;

  bool _isClaimed(Milestone m) =>
      claimed.contains(m.key) || stats.reached.containsKey(m.key);

  @override
  Widget build(BuildContext context) {
    String? nextKey;
    for (final m in milestones) {
      if (!_isClaimed(m)) {
        nextKey = m.key;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < milestones.length; i++)
                _MilestoneRow(
                  milestone: milestones[i],
                  claimed: _isClaimed(milestones[i]),
                  progress: milestones[i].key == nextKey
                      ? stats.progressFor(milestones[i], habitId: habitId) /
                          milestones[i].threshold
                      : null,
                  current: stats.progressFor(milestones[i], habitId: habitId),
                  title: compactTitles
                      ? '${milestones[i].threshold}-day streak'
                      : milestones[i].title,
                  hollow: habitId != null,
                  showDivider: i < milestones.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.claimed,
    required this.progress,
    required this.current,
    required this.title,
    required this.hollow,
    required this.showDivider,
  });

  final Milestone milestone;
  final bool claimed;
  final double? progress;
  final int current;
  final String title;
  final bool hollow;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final locked = !claimed && progress == null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: claimed ? AppColors.goldGradient : null,
                  color: claimed ? null : AppColors.champagne,
                ),
                child: Icon(
                  claimed
                      ? Icons.check_rounded
                      : locked
                          ? Icons.lock_outline_rounded
                          : Icons.flag_outlined,
                  size: 18,
                  color: claimed ? AppColors.white : AppColors.inkFaint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: locked ? AppColors.inkFaint : AppColors.ink,
                      ),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0, 1),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$current of ${milestone.threshold}',
                        style: t.labelSmall?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Opacity(
                opacity: locked ? 0.5 : 1,
                child: TokenAmount(milestone.reward, hollow: hollow),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(indent: 56, endIndent: 10),
      ],
    );
  }
}
