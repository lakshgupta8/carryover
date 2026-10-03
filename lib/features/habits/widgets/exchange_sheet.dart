import 'package:flutter/material.dart';

import '../../../core/rewards.dart';
import '../../../core/theme/app_theme.dart';
import '../data/habit_controller.dart';
import '../engine/streak_engine.dart';
import 'gold_widgets.dart';

/// Converts a habit's tokens into shared tokens.
class ExchangeSheet extends StatefulWidget {
  const ExchangeSheet({super.key, required this.habitId});

  final String habitId;

  static Future<void> show(BuildContext context, String habitId) {
    final controller = ControllerScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => ControllerScope(
        controller: controller,
        child: ExchangeSheet(habitId: habitId),
      ),
    );
  }

  @override
  State<ExchangeSheet> createState() => _ExchangeSheetState();
}

class _ExchangeSheetState extends State<ExchangeSheet> {
  int _amount = RewardRules.exchangeRate;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = ControllerScope.of(context);
    final t = Theme.of(context).textTheme;
    final HabitStats? hs = c.stats.habitStat(widget.habitId);
    final balance = hs?.internalBalance ?? 0;
    final shared = c.stats.sharedBalance;
    const rate = RewardRules.exchangeRate;
    final max = balance - balance.remainder(rate);
    final amount = _amount.clamp(0, max);
    final minted = amount ~/ rate;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Exchange tokens', style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '${hs?.habit.emoji ?? ''} ${hs?.habit.name ?? ''} wallet: $balance. '
            'Every $rate habit tokens become 1 shared token, usable for any habit. '
            'Exchanges cannot be undone.',
            style: t.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Step(
                icon: Icons.remove_rounded,
                onTap: amount - rate >= rate
                    ? () => setState(() => _amount = amount - rate)
                    : null,
              ),
              const SizedBox(width: 18),
              Column(
                children: [
                  TokenAmount(amount, size: 26, signed: false, hollow: true),
                  const SizedBox(height: 4),
                  Text('habit tokens',
                      style: t.labelSmall?.copyWith(color: AppColors.inkFaint)),
                ],
              ),
              const SizedBox(width: 18),
              _Step(
                icon: Icons.add_rounded,
                onTap: amount + rate <= max
                    ? () => setState(() => _amount = amount + rate)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: max > 0 ? () => setState(() => _amount = max) : null,
              child: const Text('Use all'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_downward_rounded, color: AppColors.inkFaint),
                const SizedBox(width: 10),
                TokenAmount(minted, size: 22, signed: false),
                const SizedBox(width: 6),
                Text('shared', style: t.bodyMedium?.copyWith(color: AppColors.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Shared balance: $shared → ${shared + minted}'
              '${shared + minted >= RewardRules.repairCostPerDay && shared < RewardRules.repairCostPerDay ? '  (enough for a repair)' : ''}',
              style: t.labelMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          const SizedBox(height: 22),
          GoldButton(
            label: minted > 0 ? 'Exchange for $minted shared' : 'Nothing to exchange',
            loading: _busy,
            onPressed: minted > 0
                ? () async {
                    setState(() => _busy = true);
                    final got = await c.exchange(widget.habitId, amount);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    showSnack(context, got > 0
                        ? 'Minted $got shared token${got == 1 ? '' : 's'}.'
                        : 'Exchange did not go through.');
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.sand : AppColors.goldPale,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon,
              color: onTap == null ? AppColors.inkFaint : AppColors.goldDark),
        ),
      ),
    );
  }
}
